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
# DBR installpatch - installs a patch in the current environment

import sys
import os.path
#import shutils
import dbrutils



def run(args):
  if(len(args)):
    patch = args[0]
    if(patch):
      if(os.path.exists(patch)):
        patchname = os.path.basename(patch)
        if(not os.path.exists(os.path.join(dbrutils.patchpath(),patchname))):
          shutils.copyfile(patch, os.path.join(dbrutils.patchpath(),patchname))
        files = set();
        files.add('*')
        dbrutils.extractfromzip(files,os.path.join(dbrutils.patchpath(),patchname))
        print 'Should probably run checkenv now...'
      else:
        print 'Cannot find patch zip: %s\n' %patch
        help()
    else:
        help()
  else:
   help()
      
def help():
  print 'usage: Createpatch <patchname>'
