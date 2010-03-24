# Copyright (c) 2009-2010 Symbian Foundation Ltd
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


import dbrutils
import dbrenv

import re #temporary for dealing with patches
import os

def run(args):  
  zippath = '/'
  if(len(args)):
    zippath = args[0]
  #This block is a cut'n'paste from checkenv...we call call that instead... 
      
  location = '/'
#needs a fix to scanenv for this to work...  
#  if(len(args)):
#    location = args[0]
  db = dbrenv.CreateDB(location)
  local = dbrenv.DBRLocalEnv(location)
  results = db.compare(local)
  local.verify(results.unknown)
  results2 = db.compare(local)
  db.update(local, results2.touched)
  #cleaning
  dbrutils.deletefiles(sorted(results2.added))
  required = results2.changed | results2.removed
  dbrutils.extractfiles(required, zippath)
  #do something about the patches here...
  print 'Need to extract the patches in a nicer manner!!!'
  dbrutils.extractfiles(required, os.path.join(location,dbrutils.patch_path_internal()))
  
  #scan again...create a new 'local'   
  local = dbrenv.DBRLocalEnv(location)
  local.verify(required)
  results3 = db.compare(local)
  db.update(local, results3.touched)
  db.save()
  results3.printdetail()
  results3.printsummary()  
        
    


def help():
  print "Cleans the current environment"
  print "Usage\n\tdbr cleanenv (<baseline_zip_path>)"
  print "\nDefault behaviour presumes baselie zips exist at the root"
  