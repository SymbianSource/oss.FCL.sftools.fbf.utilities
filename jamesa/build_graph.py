# Copyright (c) 2009 Symbian Foundation Ltd
# This component and the accompanying materials are made available
# under the terms of the License "Eclipse Public License v1.0"
# which accompanies this distribution, and is available
# at the URL "http://www.eclipse.org/legal/epl-v10.html".
#
# Initial Contributors:
# Symbian Foundation Ltd - initial contribution.
# 
# Contributors:
#
# Description:
# Generates a dependency graph of the Symbian source tree.

"""Build a graph of component dependencies from Symbian OS source code.
The graph is serialized to a file, which can then be used by other scripts to extract data.

The script works by recursing over the directory structure from the specified root and then
analyzing all bld.inf files to locate referenced production MMP files. These are then processed
for target and dependency information.

You can use the supplementary scripts to then extract useful information from the generated graph
file.
"""

from optparse import OptionParser
from _common import Node

import re
import os
import sys
import pickle
import logging

__author__ = 'James Aley'
__email__ = 'jamesa@symbian.org'
__version__ = '1.0'

# Constants for various default config
_LOG_FORMAT = '%(levelname)s: %(message)s'
_MAX_PATH = 260

# Precompile regexes for better performance
# - Comment filtering
_RE_CLEAN_INLINE = '^(.*)//.*$'
_RE_MULTILINE_OPEN = '^(.*)/\\*.*$'
_RE_MULTILINE_CLOSE = '^.*\\*/(.*)$'
_p_clean_inline = re.compile(_RE_CLEAN_INLINE)
_p_multiline_open = re.compile(_RE_MULTILINE_OPEN)
_p_multiline_close = re.compile(_RE_MULTILINE_CLOSE)

# - MMP file Parsing
_RE_TARGET = '^\\s*TARGET\\s+([^\\s]+).*$'
_RE_PLAIN_TARGET = '^\\s*([^\\s\\.]+)\\.?[^\\s]?\\s*'
_RE_COMPLEX_TARGET = '.*\\((.+),.+\\).*'
_RE_LIBRARY = '^\\s*[^\\s]*LIBRARY.*\\s+([^\\s]+.*)$'
_RE_START = '^\\s*START.*$'
_RE_END = '\\s*END.*$'
_p_target = re.compile(_RE_TARGET, re.I)
_p_plain_target = re.compile(_RE_PLAIN_TARGET)
_p_complex_target = re.compile(_RE_COMPLEX_TARGET)
_p_library = re.compile(_RE_LIBRARY, re.I)
_p_start = re.compile(_RE_START)
_p_end = re.compile(_RE_END)

# - BLD.INF file parsing
_RE_PRJ_MMPFILES = '^\\s*PRJ_MMPFILES\\s*$'
_RE_OTHER_SECTION = '^\\s*PRJ_[a-z]+\\s*$'
_p_prj_mmpfiles = re.compile(_RE_PRJ_MMPFILES, re.I)
_p_other_section = re.compile(_RE_OTHER_SECTION, re.I)

# Set up a logging instance for output
logging.basicConfig(format=_LOG_FORMAT, level=logging.WARNING, stream=sys.stdout)

# Cache dictionary to marry Nodes to eachother
node_cache = {}

# Dictionary representing the dependency graph.
# Each key identifies the node in the graph, where the value is the node
# object itself including the arcs to other node_path keys that it requires.
graph = {}

def rstrip(string, suffix):
    """Like Python's __str__.rstrip(chars), but it treats the chars as
    a contiguous string and only strips that complete ending.
    """
    if string.endswith(suffix):
        string = string[:len(string) - len(suffix)]
    return string

def clean_binary_name(binary_name):
    """Strips the extension off of binary names so that references to .lib
    are associated with the correct binaries.
    """
    match_complex_target = _p_complex_target.match(binary_name)
    if match_complex_target:
        binary_name = match_complex_target.groups()[0].lower().strip()
    else:
        match_plain_target = _p_plain_target.match(binary_name)
        if match_plain_target:
            binary_name = match_plain_target.groups()[0].lower().strip()
    return binary_name

def looks_like_test(path):
    """Returns true if a path looks like it refers to test components.
    The script does its best to filter test components, as many are missing
    from the source tree and they're not interesting with respect to building
    production ROM images anyway.
    """
    conventions = ['tsrc', 'test']
    for convention in conventions:
        # Iterate through likely test component conventions, if
        # we match one, return True now
        if os.path.sep + convention + os.path.sep in path.lower():
            return True
    # Otherwise, nothing found, so return False
    return False

def without_comments(source_file):
    """Generator function, will yield lines of the source_file object (iterable)
    with commented regions removed.
    """
    multiline_region = False
    for line in source_file:
        match_multiline_close = _p_multiline_close.match(line)
        if match_multiline_close:
            # Close Comments, strip to the left of the comment
            multiline_region = False
            line = match_multiline_close.groups()[0]
        if multiline_region:
            # Skip the line if we're in a commented region
            continue
        match_multiline_open = _p_multiline_open.match(line)
        if match_multiline_open:
            # Open comments, strip to the right of the comment
            multiline_region = True
            line = match_multiline_open.groups()[0]
        match_inline = _p_clean_inline.match(line)
        if match_inline:
            # Strip the line to only the left of the comment
            line = match_inline.groups()[0]
        if line:
            yield line

def parse_mmp(mmp_path):
    """Read an mmp file, return a tuple of the form:
        (target, required_target_list)
    """
    logging.debug('parse_mmp(%s)' % (mmp_path, ))
    
    mmp_file = None
    try:
        mmp_file = open(mmp_path)
    except IOError, e:
        logging.error('Unable to open: %s' % (mmp_path, ))
        return

    # Iterate through MMP file lines to find the TARGET and LIBRARY statements
    # Note that Symbian projects can compile to different TARGET objects depending on
    # precompiler macros, so we must index all possible target names.
    targets = []
    libs = []
    resource_block = False
    for line in without_comments(mmp_file):
        match_start = _p_start.match(line)
        if match_start:
            resource_block = True
        match_end = _p_end.match(line)
        if match_end:
            resource_block = False
        if resource_block:
            # need to avoid resource target sections
            continue
        match_target = _p_target.match(line)
        match_library = _p_library.match(line)
        if match_target:
            clean_target = clean_binary_name(match_target.groups()[0])
            targets.append(clean_target)
        elif match_library:
            libs_on_line = match_library.groups()[0].split()
            for lib in libs_on_line:
                clean_lib = clean_binary_name(lib)
                libs.append(clean_lib)
    mmp_file.close()

    return (targets, libs)

def new_node(path, ref_mmps, ref_testmmps):
    """Construct a new node in the graph with the provided content.
    """
    logging.debug('new_node(%s, ref_mmps(%d), ref_testmmps(%d))' % (path, len(ref_mmps), len(ref_testmmps)))
    node = Node(path)
    
    # Iterate the MMPs, read dependency and target information
    for mmp in ref_mmps:
        (targets, dependencies) = parse_mmp(mmp)
        if len(targets) > 0:
            for target in targets:
                node.mmp_components.append(target)
            node.add_deps(dependencies)

    # Register the components in the cache, as later we will
    # join the graph nodes by referring to this cache
    for c in node.mmp_components:
        if c in node_cache.keys():
            existing = node_cache[c]
            node_cache[c] = existing + [path]
        else:
            node_cache[c] = [path]

    # Add this node to the graph
    graph[path] = node

def parse_bld_inf(path):
    """Parse a bld.inf file to check to see if references MMP files.
    For those MMP files included, parse them to build the node object.
    """
    logging.debug('parse_bld_inf(%s)' % (path, ))
    
    # List the files referenced from this bld.inf
    ref_mmp = []
    ref_testmmp = []
    
    bld_inf = None
    try:
        bld_inf = open(path, 'r')
    except IOError, e:
        logging.error('Unable to open: %s' % (path, ))
        return

    # Parse the bld_inf file, adding references MMP files to appropriate lists
    projects_flag = False
    for line in without_comments(bld_inf):
        match_projects = _p_prj_mmpfiles.match(line)
        match_other_section = _p_other_section.match(line)
        if match_projects:
            projects_flag = True
        elif match_other_section:
            projects_flag = False
        if projects_flag and len(line) <= _MAX_PATH:
            rel_name = rstrip(line.lower().strip(), '.mmp')
            bld_inf_path = os.path.dirname(path)
            test_path = os.path.join(bld_inf_path, rel_name + '.mmp')
            test_path = os.path.realpath(test_path)
            if os.path.exists(test_path):
                ref_mmp.append(test_path)
            else:
                logging.warning('%s refers to %s but it does not exist!' % (path, test_path))
    bld_inf.close()

    # If we found some MMP files, then this is a new node
    if len(ref_mmp) > 0:
        new_node(path, ref_mmp, ref_testmmp)

def make_nodes(not_used, dir_name, file_names):
    """Call back function for os.path.walk: will analyse the file names, if
    there are any bld.inf files, it will open them to see if they identify a
    Node object and create them as appropriate
    """
    logging.debug('make_nodes(%s, %s)' % (dir_name, file_names))
    if looks_like_test(dir_name):
        return
    for file_name in file_names:
        if file_name.lower().endswith('.inf'):
            abs_path = os.path.join(dir_name, file_name)
            assert(os.path.exists(abs_path))
            parse_bld_inf(abs_path)

def connect_nodes():
    """Walk through the graph and substute the contents of the dependency
    list members at each node with references to the node_path of that which
    builds the referenced component.

    There will be instances where multiple graph nodes build overlapping
    components. This will, in practice, mean that there are many ways of
    building a suitable ROM for dependencies of one of these nodes.
    """
    unresolved_deps = []
    for node_path in graph.keys():
        node = graph[node_path]
        resolved = []
        for dep in node.dependencies:
            if dep not in node_cache.keys():
                logging.warning('Could not resolve %s for %s' % (dep, node.node_path))
                if dep not in unresolved_deps:
                    unresolved_deps.append(dep)
                node.unresolved.append(dep)
            else:
                solutions = node_cache[dep]
                proposed = solutions[0]
                if proposed not in resolved:
                    resolved.append(proposed)
                node.interesting += filter(lambda x: x not in node.interesting, solutions[1:])
        node.dependencies = resolved
        graph[node_path] = node
    if len(unresolved_deps) > 0:
        logging.warning('There were %d unresolved dependencies.' % (len(unresolved_deps), ))

def build_graph(root):
    """Walk nodes from the directory root provided looking for bld.inf files.
    Graph will be built from the referened production MMP files.
    """
    if not os.path.isdir(root):
        logging.fatal('%s is not a directory, aborting...' % (root, ))
        exit(1)
    os.path.walk(root, make_nodes, None)
    connect_nodes()

def save_graph(path):
    """Serialize the graph object to path. This will be a Python object pickle at
    the highest available protocol version for this Python install.
    """
    graph_file = None
    try:
        graph_file = open(path, 'wb')
    except IOError, e:
        logging.error('Could not write graph to file: %s' % (repr(e), ))
        exit(1)
    pickle.dump(graph, graph_file, pickle.HIGHEST_PROTOCOL)
    graph_file.close()

# Main:
if __name__ == '__main__':
    parser = OptionParser()
    parser.set_description(__doc__)
    parser.add_option('-g', '--graph', dest='graph_file', 
                      help='File name to write the graph to.', 
                      metavar='GRAPH_FILE', default='dependencies.graph')
    parser.add_option('-r', '--root', dest='graph_root',
                      help='Directory to recursively build a graph from, usually root of source tree.',
                      metavar='SOURCE_ROOT', default='.')
    parser.add_option('-v', '--verbose', dest='verbose',
                      help='Verbose logging, will show all warnings as graph is generated. Recommend redirect!',
                      action='store_true', default=False)
    (options, args) = parser.parse_args()
    if not options.verbose:
        logging.disable(logging.ERROR)
    print 'Walking source from "%s"\nThis can take some time with large source trees...' % (options.graph_root, )
    build_graph(options.graph_root)
    print 'Found %d components consisting of %d binaries.' % (len(graph), len(node_cache))
    print 'Wriing graph to %s' % (options.graph_file)
    save_graph(options.graph_file)
    print '...done!'
