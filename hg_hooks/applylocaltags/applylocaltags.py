#! /usr/bin/python
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
# applytag.py - apply local mercurial tag based on one or more csv files
#                which contain a list of repos and changesets
#                for any <name>.csv file use the <name> is used as the tag name
#

repo_root='c:/sf'
debugfile = "debug.out"

import re
import StringIO
import os
import sys

from mercurial import util
from mercurial.i18n import _

import subprocess

sourceline = re.compile('(.*?)(oss|sfl)/(FCL|MCL)/(.*)',re.I)
MCL = re.compile('^MCL$',re.I)
re_csvfile = re.compile(r"(.*?)\.csv$",re.I)
csvfields = re.compile(r"(.*?),(.*?),(.*?),(.*?),.*")
verbose = True


def debug_info(str):
    hgui.debug(_(str))
    dbgfile.write(str)

def debug_warn(str):
    hgui.write(_(str))
    dbgfile.write(str)

def debug_verbose(str):
    if verbose:
        hgui.debug(_(str))
        dbgfile.write(str)

def commit_hook(ui, repo, hooktype, node=None, source=None, **kwargs):
    # iterate over all the files in added changeset
    global hgui
    global dbgfile
    hgui = ui
    ctx = repo[node]
    dbgfile = file(debugfile,'w')  #open file f for write
    for f in ctx.files():
        debug_info(('file %s \n') % (f))
        csvname = re_csvfile.match(f)
        if (csvname):
            debug_info(('csv file %s\n') % f)
            fctx = ctx.filectx(f)
            filecontent = fctx.data()
            tagname = csvname.group(1).upper()
            debug_info(('tag to use : %s\n')% tagname)
            csvfp = StringIO.StringIO(filecontent)
            parse_csv(ui,csvfp,tagname)
            csvfp.close()
    dbgfile.close()
    # return False meand "don't block"
    return False

def walk_repos(ui,rootpath):
    p = util.pconvert(rootpath)
    for path in util.walkrepos(p, followsym=True):
        debug_info(('repo %s\n') % path)




def parse_csv(ui,fp,tagname):
    '''
        Take a list of repositories (from csv file)
        For each repository apply a local tag
        to the local copy of the repo using the
        specified changeset
    '''
    global verbose
    for line in fp.readlines():
        # check it is basic csv and extract repo url and changeset
        cline = csvfields.match(line)
        if(cline):
            reposrc = cline.group(1)
            changeset = cline.group(4)
        else:
            debug_warn(('ignoring : %s\n' %line))

        # now check the repo url looks valid
        m = sourceline.match(reposrc)
        if (m):
            # construct local path
            applytag(ui,repo_root,m.group(2),m.group(3),m.group(4),changeset,tagname)
            #if we have just tagged the MCL then tag the FCL as well
            if(MCL.match(m.group(3))):
                applytag(ui,repo_root,m.group(2),"FCL",m.group(4),changeset,tagname)
        else:
            debug_warn(('Ignoring Source Line: %s\n' %reposrc))

def applytag(ui,path_root,p_license,p_branch,p_repo,rev,tagname):
    repoabs = '/'.join([path_root,p_license,p_branch,p_repo])
    repoabs.replace("\\","/")
    tagcmd = ['hg','-R',repoabs,'tag','--local','--force','-r',rev,tagname]
    #print tagcmd
    run(ui,tagcmd)

def run(ui,cmd):
    debug_verbose(('cmd %s\n' % ' '.join(cmd)))
    try:
        p = subprocess.Popen(args=cmd, bufsize=1024, shell = False, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)
	cmdout, errtxt = p.communicate()
        debug_warn((cmdout))
    except IOError as err:
        debug_warn(("IOError : ",err))
    except OSError as err:
        debug_warn(("OSError : ",err))
    except:
        debug_warn(("Error %s : Could not run %s\n" % (sys.exc_info()[0],cmd)))
        return -1

