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
# DBR - the root DBR script that farms out the jobs to the other scripts

import sys
import os.path

def main():
    print 'MattD: Need to fix the import path properly!'
    dbrpath = os.path.join(os.path.dirname(sys.argv[0]),'dbr')
    sys.path.append(dbrpath)
    args = sys.argv
    if(len(sys.argv)>1):
      cmd = sys.argv[1]
      args.pop(0)
      args.pop(0)
  
      if(cmd):
        try:
            command = __import__ (cmd)
            command.run(args)        
        except ImportError:
          help(args)
    else:
      help(args)
      
def help(args):
  try:
    command = __import__ ('help')
    command.run(args)        
  except ImportError:
    print "error: Cannot find DBR tools help in %s" % dbrpath
                    
main()
  
