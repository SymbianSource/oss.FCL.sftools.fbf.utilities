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
    for module in args:
      dosmoketest(module)
  else:
    print sys.argv[0]
    modules = os.listdir(os.path.join(os.path.dirname(sys.argv[0]),'dbr'))
    for module in sorted(modules):
      modname = re.match('(.+)\.py$',module)
      if(modname):
        module = modname.group(1)
        dosmoketest(module)
    

def dosmoketest(module):
  print "\nTesting %s:" % module
  try:
    tool = __import__(module)
    tool.smoketest()
  except ImportError:
    print "Error: Could not load %s" % module
  except AttributeError:
    print "Warning: No Smoketest found in %s" % module
  except SyntaxError:
    print "Error: Syntax error in %s" % module
  except NameError:
    print "Error: Name error in %s" % module
  

def help():
  print "Usage:"
  print "\tdbr smoketest\t- runs the smoketests"

def summary():
  return "Runs smoketests"