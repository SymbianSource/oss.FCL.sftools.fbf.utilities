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

import dbrpatch


def run(args):
  if(len(args) == 1):
    dbrpatch.removepatch(args[0]);
    print 'do cleanenv!!!'
    
def help():
  print "removes a patch"    