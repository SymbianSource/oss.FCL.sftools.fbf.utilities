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
# DBREnv - OO rewrite of the Environments  

#I'm using the existing stuff as helpers until things get relocated...
import os.path
import glob

import dbrutils
import dbrbaseline
import dbrpatch

import dbrresults
import dbrfilter

def CreateDB(location): #virtual constructor
  print location
#  print dbrutils.patch_path_internal()
  if(os.path.isfile(os.path.join(location,dbrutils.defaultdb()))):
#    print 'loading baseline environment'
#    return DBRBaselineEnv(location)
    print 'loading patched baseline environment'
    return DBRPatchedBaselineEnv(location)
  if(os.path.exists(os.path.join(location,'build_md5.zip'))):
    print 'loading zipped environment'
    return DBRZippedEnv(location)
  if(os.path.exists(os.path.join(location,dbrutils.patch_path_internal()))): #should do something more fun with creating a basleine if we have MD5s
    print 'loading new env...warning: this is only here for compatibility'
    return DBRNewLocalEnv(location)
  if(os.path.exists(os.path.join(location,'epoc32'))): 
    print 'loading localenv'
    return DBRLocalEnv(location)

  return DBREnv(location)

#Basic DBREnv definition
class DBREnv:
  db = dict()
  location = ''
  name = ''
  def __init__(self, location):
    self.location = location

  def compare(self, other):
    db1files = set(self.db.keys())
    db2files = set(other.db.keys())

    removed = db1files - db2files
    added = db2files - db1files
    common = db1files & db2files

    touched = set()
    for file in common:
      if(int(self.db[file]['time']) != int(other.db[file]['time'])):
        touched.add(file)
      if(int(self.db[file]['time']) ==0 or int(other.db[file]['time']) == 0): #workaround for zipped dbs
        touched.add(file)

    sizechanged = set()
    for file in common:
      if(int(self.db[file]['size']) != int(other.db[file]['size'])):
        sizechanged.add(file)
#can be funny with some zip files...suggest we don't use sizechanged...        
#    changed = sizechanged 
    changed = set()    
    touched = touched - changed
    unknown = set()
    for file in touched:
      if((self.db[file]['md5'] == "xxx") or (other.db[file]['md5'] == "xxx")):
        unknown.add(file)
#        if((self.db[file]['md5'] == "xxx")):
#          print 'unknown left: %s' % file
#        else:
#          print 'unknown right: %s' % file
      else:
        if(self.db[file]['md5'] != other.db[file]['md5']):
#          print '%s %s %s' % (file, self.db[file]['md5'], other.db[file]['md5'] )
          changed.add(file)
    touched = touched - unknown     
    touched = touched - changed     
          
    results = dbrresults.DBRResults(added, removed, touched, changed, unknown)   
    return results
    
  def verify(self, files):
    print 'this is a pure virtual...'

  def save(self):
    print 'this is a pure virtual...'

  def remove(self, files):
    for file in files:
      if(file in self.db):
        del self.db[file]
      else:
        print 'warning: del: %s isnt defined' % file  

  def add(self, other, files):
    for file in files:
      if(file in self.db):
        print 'warning: add: %s already defined' % file
      else:    
        if(other.db[file]['md5'] == 'xxx'): #don't update a null md5
          print 'warning: MD5: %s isnt defined' % file  
        else:
          self.db[file] = other.db[file]
              
  def update(self, other, files):
    for file in files:
      if(other.db[file]['md5'] != 'xxx'): #don't update a null md5 
        self.db[file]['md5'] = other.db[file]['md5']                           
      else:
        print 'warning: MD5: %s isnt defined' % file  

      self.db[file]['time'] = other.db[file]['time']              
      self.db[file]['size'] = other.db[file]['size']


#Database plus local filesystem access
class DBRLocalEnv (DBREnv):
  def __init__(self, location):
    DBREnv.__init__(self, location)
    #load up local files...        
    self.db = dbrutils.scanenv()

  def verify(self, files):
    #should assert that the files are in the local DB.
    localfiles = set(self.db.keys())
    if(localfiles.issuperset(files)):
      md5s = dbrutils.generateMD5s(files)
      for file in files:
        self.db[file]['md5'] = md5s[file]['md5']

#Creating a DBREnv from scratch...
class DBRNewLocalEnv (DBRLocalEnv):
  def __init__(self, location):
    DBRLocalEnv.__init__(self, location)
    #load up local files...            
    hashes = glob.glob(os.path.join(dbrutils.patchpath(),'*.md5'))
    for file in hashes:
      print 'Reading: %s\n' % file
      dbrutils.gethashes(self.db, file, False)

  def save(self):
    filename = os.path.join(self.location,dbrutils.defaultdb())
    print 'Saving %s' % filename 
    dbrbaseline.writedb(self.db,filename)

    
#zipped files, contains MD5s.   
class DBRZippedEnv (DBREnv):
  def __init__(self, location):
    DBREnv.__init__(self, location)
    #load up zip MD5 and stuff
    self.db = dbrutils.getzippedDB(self.location)        

      
#Database, but no filesystem access
class DBRBaselineEnv (DBREnv):
  def __init__(self, location):
    DBREnv.__init__(self, location)
    #load up database...        
    filename = os.path.join(self.location,dbrutils.defaultdb())
    print 'Loading %s' % filename 
    self.db = dbrbaseline.readdb(filename)

  def save(self):
    filename = os.path.join(self.location,dbrutils.defaultdb())
    print 'Saving %s' % filename 
    dbrbaseline.writedb(self.db,filename)


class DBRPatchedBaselineEnv (DBRBaselineEnv):
  patches = []
  baseline = []
  def __init__(self, location):
    DBRBaselineEnv.__init__(self, location)
    #load up patches...        
    if(len(self.db) > 0):
      self.baseline = self.db      
      self.patches = dbrpatch.loadpatches(os.path.join(self.location,dbrutils.patch_path_internal()))
      self.db = dbrpatch.createpatchedbaseline(self.baseline,self.patches)

  def save(self):
      self.baseline = dbrpatch.updatebaseline(self.baseline, self.db)
      self.patches = dbrpatch.updatepatches(self.patches, self.db)
      dbrpatch.savepatches(self.patches)
      self.db = self.baseline
      DBRBaselineEnv.save(self)
      
          
class CBREnv (DBREnv): # placeholder for handling CBR components...
  def __init__(self, location):
    DBREnv.__init__(self, location)
