# Copyright (c) 2010 Symbian Foundation Ltd
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
# new checkenv - uses OO interface.

import dbrenv

def run(args):
  location = '/'
#needs a fix to scanenv for this to work...  
#  if(len(args)):
#    location = args[0]
  db = dbrenv.CreateDB(location)
  local = dbrenv.DBRLocalEnv(location)
  results = db.compare(local)
  local.verify(results.unknown)
  results2 = db.compare(local)
  results2.printdetail()
  results2.printsummary()
  db.update(local, results2.touched)
  db.save()
    
def help():
  print "Checks the status of the current environment"
  print "Usage:"
  print "\tdbr checkenv"
    
  

