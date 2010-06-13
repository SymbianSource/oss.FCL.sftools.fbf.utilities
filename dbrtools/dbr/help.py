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
import os
import re

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
        getsummary()
    else:
      getsummary()

def getsummary():
  debug = 0

  print "Usage:"
  modules = os.listdir(os.path.join(os.path.dirname(sys.argv[0]),'dbr'))
  for module in sorted(modules):
    modname = re.match('(.+)\.py$',module)
    if(modname):
      module = modname.group(1)
      try:
        tool = __import__(module)
        str = tool.summary()
        print "\tdbr %s\t- %s" %(module, str)
      except ImportError:
        if(debug):
          print "Couldn't import %s" % module
      except AttributeError:
        if(debug):
          print "Couldn't find summary in %s" % module
      except NameError: #if it doesn't work...
        if(debug):
          print "%s looks broken" % module
      except SyntaxError: #if it doesn't work...
        if(debug):
          print "%s looks broken" % module

      



def oldusage():
    
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
    

def summary():
  return "Displays the help"

def help():
  getsummary()