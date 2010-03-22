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
# new diffenv - uses OO interface and can have 

import dbrenv

def run(args):
    if(len(args)):
      filtertype = ''
      if(len(args) == 1):
        first = '/'
        second = args[0]
      else:
        first = args[0]
        second = args[1]
      if(len(args) == 3):
        filtertype = args[2]    
      db1=dbrenv.CreateDB(first)
      db2=dbrenv.CreateDB(second)
      results = db1.compare(db2)
      filter = dbrenv.CreateFilter(filtertype)
      filteredresults = filter.filter(results)
      filteredresults.printdetail()
      filteredresults.printsummary()
    else:
      help()
      
def help():
  print "Compares two environments"
  print "Usage:"
  print "\tdbr diffenv <drive1> (<drive2>)"
    
  

