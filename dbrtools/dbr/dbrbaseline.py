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
# DBRbaseline - module for handling vanilla baselines
#


import re
import os
import string
from os.path import join, isfile, stat
from stat import *
import dbrutils
                


def readdb(dbfile):
    db = dict()
    if(isfile(dbfile)):
        file = open(dbfile,'r')
#        regex = re.compile('(\S+)\s+(\S+)\s+(\S+)\s+(.+)\n')
        for line in file:
            #file structure 'timestamp size hash filename' avoids the problems of spaces in names, etc...
            results = re.split(':|\n',line)
            if(len(results) > 3):
              entry = dict()
              entry['time'] = results[0]
              entry['size'] = results[1]
              entry['md5'] = results[2]
              if(results[4]):
                entry['archive'] = results[4] 
                print entry['archive'] 
              db[results[3]] = entry
#            db[results[3]] = [results[0],results[1],results[2]]
#            bits = regex.match(line)
#            if(bits):
#                db[bits.group(3)] = [bits.group(0), bits.group(1), bits.group(2)]
        file.close()
    return db

def writedb(db, dbfile):
#    print 'Writing db to', dbfile
    file = open(dbfile,'w')
    for filename in sorted(db):
        if (len(db[filename]) < 3):
            db[filename].append('')
        str = "%s:%s:%s:%s" %( db[filename]['time'],db[filename]['size'],db[filename]['md5'], filename)
        if('archive' in db[filename]):
          str = "%s:%s" %(str,db[filename]['archive'])          
#        if(db[filename]['md5'] == 'xxx'):
#            print 'Warning: no MD5 for %s' % filename
#        str = "%s:%s:%s:%s\n" %( db[filename][0],db[filename][1],db[filename][2], filename)
        file.write('%s\n' % str)
    file.close()

def md5test(db, md5testset):
    changed = set()
    md5s = dbrutils.generateMD5s(md5testset)
    for file in md5testset:
        if(db[file]['md5'] != md5s[file]['md5']):
            changed.add(file)
    return changed


def updatedb(db1, db2):
  compareupdatedb(db1, db2, 1)
  
def comparedb(db1, db2):
  compareupdatedb(db1, db2, 0)

def compareupdatedb(db1, db2, update):
    print "compareupdatedb() is deprecated"
    db1files = set(db1.keys())
    db2files = set(db2.keys())
    removed = db1files - db2files
    added = db2files - db1files
    common = db1files & db2files

    touched = set()
    for file in common:
        if(db1[file]['time'] != db2[file]['time']):
            touched.add(file)

    sizechanged = set()
    for file in common:
        if(db1[file]['size'] != db2[file]['size']):
            sizechanged.add(file)

    #pobably won't bother with size changed... we know they're different...
#    md5testset = touched - sizechanged
    md5testset = touched
                
    changed = md5test(db1,md5testset)

    #remove the ones we know are changed
    touched = touched - changed
    
    print 'Comparing dbs/n'
    for file in sorted(added):
        print 'added:', file
    for file in sorted(removed):
        print 'removed:', file
    for file in sorted(touched):
        print 'touched:', file
    for file in sorted(changed):
        print 'changed:', file

    #update the touched...
    if(update):
      for file in sorted(touched):
          print 'Updating timestamp for: ',file
          db1[file]['time'] = db2[file]['time']
