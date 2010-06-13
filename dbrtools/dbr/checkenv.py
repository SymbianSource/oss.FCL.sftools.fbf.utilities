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
import dbrfilter

def run(args):
  location = '/'
  filtertype = ''
#using arg for filter...not for other env  

  db = dbrenv.CreateDB(location)
  local = dbrenv.DBRLocalEnv(location)
  results = db.compare(local)
  local.verify(results.unknown)
  results2 = db.compare(local)
  filter = dbrfilter.CreateFilter(args)
  filteredresults = filter.filter(results2)
  filteredresults.printdetail()
  filteredresults.printsummary()
  db.update(local, results2.touched)
  db.save()
    
def help():
  print "Checks the status of the current environment"
  print "Usage:"
  print "\tdbr checkenv"
    
def summary():
  return "Checks the status of the current environment"

