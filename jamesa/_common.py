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
# Data structure code used by dependency analysis scripts.

"""Common data structure code for build_graph.py and tools.
"""

__author__ = 'James Aley'
__email__ = 'jamesa@symbian.org'
__version__ = '1.0'

class Node:
    """Node objects are similar to the Symbian notion of a Component, but
    they are defined in a practical way for ROM building with less intuitive meaning.

    A Node object is identified by:
      - the path to bld.inf
      where by:
        - the bld.inf file contains a PRJ_MMPFILES section with a least one MMP file.
    """
 
    def __str__(self):
        """Represent node as string, using node_path
        """
        return self.node_path

    def __init__(self, path):
        """Initialize new Node with given path to bld.inf
        """
        # path to the bld.inf file associating these mmp components
        self.node_path = ''

        # list of node_path values for Node objects owning referenced from
        # the MMP files
        self.dependencies = []

        # contents of this Node, likely not used algorithmically but might
        # be useful later for reporting.
        self.mmp_components = []

        # the following are nodes that also satisfy the dependencies (in part), and may
        # be of interest when building a ROM.
        self.interesting = []

        # dependencies that were not linked to another component in the source tree
        self.unresolved = []

        self.node_path = path

    def add_deps(self, deps):
        """Add dependencies to the list, filtering duplicates
        """
        self.dependencies.extend(filter(lambda x: x not in self.dependencies, deps))

