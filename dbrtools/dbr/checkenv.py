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
# DBR checkenv - Checks your environment against what was installed

import dbrbaseline
import dbrpatch
import dbrutils
import glob

import os.path

def main():
    dbfilename = dbrutils.defaultdb()

    baseline = dbrbaseline.readdb(dbfilename)
    if(len(baseline ) > 0):
        patches = dbrpatch.loadpatches(dbrpatch.dbrutils.patchpath())
        db = dbrpatch.createpatchedbaseline(baseline,patches)
        env = dbrutils.scanenv()
        dbrpatch.newupdatedb(db,env)
        baseline = dbrpatch.updatebaseline(baseline, db)
        patches = dbrpatch.updatepatches(patches, db)

        dbrpatch.savepatches(patches)        
    else:
        baseline = createdb()
    dbrbaseline.writedb(baseline,dbfilename)

def createdb():
    print 'creating db...Move CreateDB into dbrutils!!!'
    env = dbrutils.scanenv()
    hashes = glob.glob(os.path.join(dbrutils.patchpath(),'*.md5'))
    for file in hashes:
        print 'Reading: %s\n' % file
        dbrutils.gethashes(env, file)
    return env

def run(args):  
  main()

def help():
  print "Shows the current state of the environment"
  print "Usage\n\tdbr checkenv"