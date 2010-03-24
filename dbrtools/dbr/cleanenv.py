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
# DBR cleanenv - cleans your environment

import dbrbaseline
import dbrpatch
import dbrutils

import re #temporary for dealing with patches

def main(args):
    zippath = '/'
    if(len(args)):
      zippath = args[0] 
    
    dbfilename = dbrutils.defaultdb()
    baseline = dbrbaseline.readdb(dbfilename)
    if(len(baseline ) > 0):
        env = dbrutils.scanenv()
        patches = dbrpatch.loadpatches(dbrpatch.dbrutils.patchpath())
        db = dbrpatch.createpatchedbaseline(baseline,patches)
        results = dbrpatch.newupdatedb(db,env)
        dbrutils.deletefiles(sorted(results['added']))
        required = set()
        required.update(results['removed'])
        required.update(results['changed'])
        required.update(results['untestable']) #untestable is going to be a problem...
        dbrutils.extractfiles(required, zippath)
        for name in sorted(patches):
          dbrutils.extractfromzip(required, re.sub('.txt','.zip',name))        

        env = dbrutils.scanenv()
        results2 = dbrpatch.newupdatedb(db,env)          
         
        baseline = dbrpatch.updatebaseline(baseline, db)
        patches = dbrpatch.updatepatches(patches, db)

        dbrpatch.savepatches(patches)        


def run(args):  
  main(args)

def help():
  print "Cleans the current environment"
  print "Usage\n\tdbr cleanenv (<baseline_zip_path>)"
  print "\nDefault behaviour presumes baseline zips exist at the root"
  