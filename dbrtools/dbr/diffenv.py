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
# DBR diffenv - compares two environments

import sys
import dbrpatch

def run(args):
    if(len(args) == 2):
      first = args[0]
      second = args[1]      
      dbrpatch.newcomparepatcheddbs(first, second)
    else:
      help()
      
def help():
  print "Compares two environments"
  print "Usage:"
  print "\tdbr diffenv <drive1> <drive2>"
    


