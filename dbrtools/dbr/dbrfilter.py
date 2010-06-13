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
# DBRFilter - DBR Filtering classes  

import dbrresults
import dbrutils
import re

from optparse import OptionParser

def CreateFilter(args):
#  print args
  
  parser = OptionParser()
  parser.add_option('-i', '--iregex', dest='iregex', action='append')
  parser.add_option('-x', '--xregex', dest='xregex', action='append')
  parser.add_option('-@', '--ifile', dest='ifile', action='append')
  parser.add_option('-!', '--xfile', dest='xfile', action='append')

#  if(os.path.isfile(arg)):
#    return DBRFileFilterInclude(args)
#  return DBRRegexFileFilterExclude(args)
  (options, args) = parser.parse_args(args)
#  print options
  filter = DBRComplexFilter()
  if options.iregex:
    for include in options.iregex:
      filter.addInclude(DBRRegexFileFilter(include))
  if options.ifile:
    for include in options.ifile:
      filter.addInclude(DBRFileFilter(include))
  if options.xregex:
    for exclude in options.xregex:
     filter.addExclude(DBRRegexFileFilter(exclude))
  if options.xfile:
    for exclude in options.xfile:
      filter.addExclude(DBRFileFilter(exclude))

  return filter     


class DBRFilter:
  info = ''
  def __init__(self):
    self.info = 'Null Filter'
  def filter(self, results):
    return results
  def include(self, results):
    return set()
  def exclude(self, results):
    return results

  
class DBRFileFilter (DBRFilter):
  filename = ''
  def __init__(self, filename):
    DBRFilter.__init__(self)
    self.filename = filename
    self.files = dbrutils.readfilenamesfromfile(self.filename)
#    for file in sorted(self.files):
#      print file

  def include(self, results):
    return dbrresults.DBRResults(results.added & self.files, results.removed & self.files, results.touched & self.files, results.changed & self.files, results.unknown & self.files)
  def exclude(self, results):
    return dbrresults.DBRResults(results.added - self.files, results.removed - self.files, results.touched - self.files, results.changed - self.files, results.unknown - self.files)

class DBRFileFilterInclude (DBRFileFilter):
  def __init__(self, filename):
    DBRFileFilter.__init__(self, filename)
  def filter(self, results):
    return self.include(results)

class DBRFileFilterExclude (DBRFileFilter):
  def __init__(self, filename):
    DBRFileFilter.__init__(self, filename)
  def filter(self, results):
    return self.exclude(results)
        
class DBRRegexFileFilter (DBRFilter):
  regex = ''
  def __init__(self, regex):
    DBRFilter.__init__(self)
    #This can throw a compiler error. It would be nicer to have this display help.
    try: 
      self.regex = re.compile(regex, re.IGNORECASE) # doing case-insensitive regexes at the moment
    except re.error:
      print 'WARNING: Bad Regular Expression:%s', regex
      self.regex = re.compile('')

  #might be able to do this nicer using 'itertools'
  def inc(self, files):
    results = set()
    for candidate in files:
      if self.regex.search(candidate):
        results.add(candidate)
    return results

  def exc(self, files):
    results = set()
    for candidate in files:
      if not self.regex.search(candidate):
        results.add(candidate)
    return results
    
  def include(self, results):
    return dbrresults.DBRResults(self.inc(results.added), self.inc(results.removed), self.inc(results.touched), self.inc(results.changed), self.inc(results.unknown))

  def exclude(self, results):
    return dbrresults.DBRResults(self.exc(results.added), self.exc(results.removed), self.exc(results.touched), self.exc(results.changed), self.exc(results.unknown))

class DBRRegexFileFilterInclude (DBRRegexFileFilter):
  def __init__(self, regex):
    DBRRegexFileFilter.__init__(self, regex)
  def filter(self, results):
    return self.include(results)
      
class DBRRegexFileFilterExclude (DBRRegexFileFilter):
  def __init__(self, regex):
    DBRRegexFileFilter.__init__(self, regex)
  def filter(self, results):
    return self.exclude(results)

class DBRComplexFilter (DBRFilter):
  exc = set()
  inc = set()
  def __init__(self):
    DBRFilter.__init__(self)
    self.exc = set()
    self.inc = set()
  
  def addInclude(self, filter):
    self.inc.add(filter)
  
  def addExclude(self, filter):
    self.exc.add(filter)

  def include(self, results):
    if self.inc:
      res = dbrresults.DBRResults(set(),set(),set(),set(),set())
      for filter in self.inc:  
        res |= filter.include(results)
        print 'including...'
      return res
    return results
    
  def exclude(self, results):
    res = dbrresults.DBRResults(set(),set(),set(),set(),set())
    for filter in self.exc:
      print 'excluding...'
      res |= filter.include(results)
    return results - res
  
  def filter(self, results):
    return self.include(results) & self.exclude(results)
     
                