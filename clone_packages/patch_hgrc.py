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
# Description:
# Python script to manipulate the hgrc files

from ConfigParser import *
import optparse
import os
import sys
import re

verbose = False;
credentials= re.compile(r"//.*?@")

def strip_credentials(hgrc):
    """  Remove the user credentials from the default path in hgrc file"""
    # e.g.
    # before http://user:pass@prod.foundationhost.org/sfl/MCL/sf/os/boardsupport/
    # after  http://prod.foundationhost.org/sfl/MCL/sf/os/boardsupport/
    if hgrc.has_section('paths'):
        if (verbose): print hgrc.items('paths')
        defpath = hgrc.get('paths', 'default')
        newpath = credentials.sub(r"//",defpath)
        #print "new path ", newpath
        hgrc.set('paths', 'default',newpath)
    elif (verbose):
        if (verbose): print "No [paths] section\n"

def add_hooks(hgrc):
    if (hgrc.has_section('hooks')):
        # unpdate
        if (verbose) : print 'updating existing hooks section'
    else:
        if (verbose) : print 'adding hooks section'
        hgrc.add_section('hooks')
    # add example (windows only) hook to block local commit to the repo
    hgrc.set('hooks', 'pretxncommit.abort', 'exit /b 1')
    hgrc.set('hooks', 'pretxncommit.message', 'ERROR: This is a read only repo')
    
    
def write_hgrcfile(hgrc,fout):
    fnewini = file(fout,'w')
    hgrc.write(fnewini)
    fnewini.close()

def main():
    global verbose
    usage = "usage: %prog [options]"
    try:
        parser = optparse.OptionParser(usage)
        parser.set_defaults(filename=".hg/hgrc")
        parser.add_option("-f","--file", dest="filename", default=".hg/hgrc",metavar="FILE" , help='file to be patched')
        parser.add_option("-v", action="store_true",dest="verbose",default=False, help='Verbose trace information')
        (options, args) = parser.parse_args()
    except:
        parser.print_help()
        sys.exit(1)

    f = os.path.abspath(options.filename)
    if(options.verbose):
        verbose = True
        print f
    if(os.path.isfile(f)):
        try:
            #conff = file(f,'w')  #open file f for read/write
            hgrcfile = RawConfigParser()
            hgrcfile.read(f)
            if (verbose):
                print hgrcfile.sections()
        except:
            print 'Something failed opening the configuration file'
            sys.exit(2)
    else:
        print "Configuration file does not exist? ",f
        sys.exit(2)

    strip_credentials(hgrcfile)
    add_hooks(hgrcfile)
    write_hgrcfile(hgrcfile,f)


if __name__ == "__main__":
    main()
