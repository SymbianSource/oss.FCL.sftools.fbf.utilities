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
# mattd <mattd@symbian.org>
#
# Description:
# DBR help - displays the DBR help

import sys

def main():
  args = sys.argv
  run(args)

def run(args):
    if(len(args)):
      try:
        tool = __import__(args[0])
        tool.help()
      except ImportError:
        print "No help on %s\n" % args[0]
        usage()
    else:
      usage()
    
def usage():    
    print "Usage:"
    print "\tdbr intro\t- basic introduction\n"

    print "\tdbr getenv\t- installs a baseline NOT IMPLEMENTED"
    print "\tdbr checkenv\t- Checks current environment"
#    print "\tdbr diffbaseline\t- Compares baselines"
    print "\tdbr diffenv\t- Compares environments"
    print "\tdbr cleanenv\t- cleans the environment"
    print ""
    print "\tdbr installpatch\t- installs a patch"
    print "\tdbr createpatch\t- creates a patch"
    print "\tdbr removepatch\t- removes a patch"
    print "\tdbr listpatches\t- lists patches"
    print ""
    print "\tdbr help - help"
    
def help():
  print "No help available!"    