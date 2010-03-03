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
# DBR createpatch - Creates a patch of the changes made to a patched baseline

import sys
import dbrbaseline
import dbrpatch
import dbrutils

def run(args):
    if(len(args)):
      dbfilename = dbrutils.defaultdb()
      patchname = args[0]
      if(patchname):
          print 'Creating Patch:%s\n' % patchname
          baseline = dbrbaseline.readdb(dbfilename)
          if(len(baseline) > 0):
              patches = dbrpatch.loadpatches(dbrpatch.dbrutils.patchpath())
              db = dbrpatch.createpatchedbaseline(baseline,patches)
              env = dbrutils.scanenv()
              db = dbrpatch.newcreatepatch(patchname,db,env)
              baseline = dbrpatch.updatebaseline(baseline, db)
              patches = dbrpatch.updatepatches(patches, db)
              dbrpatch.savepatches(patches)
              dbrbaseline.writedb(baseline,dbfilename)
      else:
          help()
    else:
      help()
      
def help():
  print 'usage: Createpatch <patchname>'
        

