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
# DBRpatch - module for handling patched baselines

import re
import os.path #used for 'listpatches' 
import string
import glob
import dbrutils
import dbrbaseline

def newcompare(db1, db2): 
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

    changed = set()

    genmd5 = 1 #I probably want to try to generate... add this as a third arg???

    if(len(touched)):
      if(genmd5):
        md5testset = set()
        for file in touched:
          if((db1[file]['md5'] != 'xxx' ) and (db2[file]['md5'] == 'xxx')): #no point geenrating an MD5 if we've nothing to compare it to...
#            print 'testing %s' % file
            md5testset.add(file)
        md5s = dbrutils.generateMD5s(md5testset)
        for file in md5testset:
          db2[file]['md5'] = md5s[file]['md5']
      for file in touched:
        if(db1[file]['md5'] != db2[file]['md5']):                    
          changed.add(file)
    touched = touched - changed

    untestable1 = set()
    untestable2 = set()
    for file in common:
        if(db1[file]['md5'] == "xxx"):
          untestable1.add(file)  
        if(db2[file]['md5'] == 'xxx'):
          untestable2.add(file)
          
    untestable = untestable1 & untestable2         
    changed = changed - untestable

    #remove the ones we know are changed
    touched = touched - changed
    touched = touched - untestable
 
    results = dict()
    results['added'] = dict()
    results['removed'] = dict()
    results['touched'] = dict()
    results['changed'] = dict()
    results['untestable'] = dict()
      
    for file in added:
      results['added'][file] = db2[file]  
    for file in removed:
      results['removed'][file] = 0
    for file in touched:
      results['touched'][file] = db2[file]  
    for file in changed:
      results['changed'][file] = db2[file]  
    for file in untestable:
      results['untestable'][file] = 0  
    return results

def printresults(results):
    for file in sorted (results['added']):
      print 'added:', file
    for file in sorted (results['removed']):
      print 'removed:', file              
    for file in sorted (results['touched']):   
      print 'touched:', file              
    for file in sorted (results['changed']):
      print 'changed:', file          
    for file in sorted (results['untestable']):
      print 'untestable:', file          
    if(len(results['added']) + len(results['removed']) + len(results['changed']) + len(results['untestable']) == 0):
      print '\nStatus:\tclean'
    else:
      print '\nStatus:\tdirty'
      
def newupdatedb(baseline,env):
    results = newcompare(baseline, env)
    printresults(results)
    for file in results['touched']:
      baseline[file]['time'] = env[file]['time']
    return results    
      
def newcreatepatch(name, db1, db2):
    results = newcompare(db1, db2)
    printresults(results)
    for file in results['touched']:
      db1[file]['time'] = db2[file]['time']
    
    patch = dict();
    patch['name'] = name
    patch['time'] = 'now!!!'   
    patch['removed'] = results['removed']
    added = results['added'].keys()
    md5sAdded = dbrutils.generateMD5s(added)
    for file in added:
      results['added'][file]['md5'] = md5sAdded[file]['md5']
    patch['added'] = results['added']
    print "Need to add in the untestable stuff here also!!!"
    patch['changed'] = results['changed']
    patchname = "%spatch_%s" %(dbrutils.patchpath(), name)
  
    createpatchzip(patch, patchname)

    #update the ownership 
    for file in patch['changed']:
        db1[file]['name'] = name

    return db1

def newcomparepatcheddbs(drive1, drive2):
    envdbroot = dbrutils.defaultdb()
    print "MattD: should move this function to a better location..."
    print 'Comparing %s with %s' % (drive2,drive1)
    print 'Loading %s' % drive1 
    baseline1 = dbrbaseline.readdb('%s%s' %(drive1,envdbroot))
    patches1 = loadpatches('%s/%s' %(drive1,dbrutils.patchpath()))
    db1 = createpatchedbaseline(baseline1,patches1)

    print 'Loading %s' % drive2 
    baseline2 = dbrbaseline.readdb('%s%s' %(drive2,envdbroot))
    patches2 = loadpatches('%s/%s' %(drive2,dbrutils.patchpath()))
    db2 = createpatchedbaseline(baseline2,patches2)

    results = newcompare(db1, db2)
    printresults(results)
 


def createpatchzip(patch, patchname):
    patchtext = '%s.txt' % patchname
    patchtext = os.path.join(dbrutils.patchpath(),patchtext)
    
    writepatch(patch, patchtext)    
    files = set()
    files.update(patch['added'])
    files.update(patch['changed'])
    files.add(re.sub('\\\\','',patchtext)) #remove leading slash - Nasty - need to fix the whole EPOCROOT thing.
    
    zipname = '%s.zip' % patchname
    dbrutils.createzip(files, zipname)         
    

def updatebaseline(baseline, db):
  for file in (db.keys()):
    origin = db[file]['name']
    if(origin == 'baseline'):
      if(baseline[file]['time'] != db[file]['time']):
         baseline[file]['time'] = db[file]['time']
         print 'Updating timestamp for %s in baseline' % file
  return baseline

def updatepatches(patches, db):
  for file in (db.keys()):
      origin = db[file]['name']
      for patch in patches.keys():
        if(patches[patch]['name'] == origin):                                        
            mod=0                    
            if(file in patches[patch]['added']):
               mod = 'added'
            if(file in patches[patch]['changed']):
                mod = 'changed'
            if(mod):
                if (patches[patch][mod][file]['time'] != db[file]['time']):
                  patches[patch][mod][file]['time'] = db[file]['time']
                  print 'Updating timestamp in %s for %s' %(patches[patch]['name'],file)
  return patches            
    

def createpatchedbaseline(baseline,patches):
    files = dict()
    files = addtodb(files,baseline,'baseline')
    for patch in sorted(patches.keys()):
#        print 'adding patch: %s' % patch
        files = addtodb(files,patches[patch]['added'],patches[patch]['name'])
        files = addtodb(files,patches[patch]['changed'],patches[patch]['name'])
        files = removefromdb(files,patches[patch]['removed'],patches[patch]['name'])
    return files    

def removefromdb(db,removed,name):
    for file in removed:
        if(file in db):
#            print '%s removing %s' %(name,file)
            del db[file]
    return db

def addtodb(db,new,name):
    for file in new:
        if(file not in db):
            db[file] = dict()
#        else:
#            print '%s overriding %s' % (name,file)
        db[file]['time'] = new[file]['time']
        db[file]['md5'] = new[file]['md5']
        db[file]['size'] = new[file]['size']
        db[file]['name'] = name
    return db

def listpatches():
    path = dbrutils.patchpath()
    patchfiles = glob.glob('%spatch*.txt' % path)
    print 'Installed patches'
    for file in patchfiles:
      print '\t%s' % re.sub('.txt','',os.path.basename(file))

def removepatch(patch):
    path = dbrutils.patchpath()
    file = '%s%s%s' %(path,patch,'.txt')
    files = set()
    files.add(file)
    dbrutils.deletefiles(files)
        

def loadpatches(path):
    patches = dict()
    patchfiles = glob.glob('%spatch*.txt' % path)

    for file in patchfiles:
        print 'Loading patch: %s' % re.sub('.txt','',os.path.basename(file))
#        print 'Reading: %s\n' % file
#        patchname = re.match('\S+patch(\S+)\.txt',file)
#        print 'patchname %s' % patchname.group(1);
        patch = readpatch(file)
#        patches[patchname.group(1)] = patch
#        print 'Read %s from %s' % (patch['name'],file)
        patches[file] = patch
    return patches


def savepatches(patches):
    for patch in sorted(patches.keys()):
 #       print 'writing %s to %s' % (patches[patch]['name'],patch)
        writepatch(patches[patch], patch)


def writepatch(patch, filename):
    file = open(filename,'w')
#    print 'saving patch to %s' %filename
    file.write("name=%s\n" % patch['name']);
    file.write("time=%s\n" % patch['time']);
    
    removed = patch['removed']
    for filename in sorted(removed):
        str = "removed=%s\n" % filename
        file.write(str)

    added = patch['added']    
    for filename in sorted(added):
        if (len(added[filename]) < 3):
            added[filename].append('')
        str = "added=%s:%s:%s:%s\n" %( added[filename]['time'],added[filename]['size'],added[filename]['md5'], filename)
        file.write(str)

    changed = patch['changed']    
    for filename in sorted(changed):
        if (len(changed[filename]) < 3):
            changed[filename].append('')
        str = "changed=%s:%s:%s:%s\n" %( changed[filename]['time'],changed[filename]['size'],changed[filename]['md5'], filename)
        file.write(str)
    file.close()
        

def readpatch(filename):
    file = open(filename,'r')
    #name=blah
    #time=blah
    #removed=file
    #added=time:size:md5:file
    #changed=time:size:md5:file
    patch = dict()
    removed = set()
    added = dict()
    changed = dict()
    for line in file:    
        results = re.split('=|\n',line)
        type = results[0]
        if( type == 'name'):
            patch['name'] = results[1]
        elif( type == 'time'):
            patch['time'] = results[1]
        elif( type == 'removed'):            
            removed.add(results[1]) 
        elif(( type == 'added') or (type == 'changed')):
            results2 = re.split(':|\n',results[1])
            entry = dict()
            entry['time'] = results2[0]
            entry['size'] = results2[1]
            entry['md5'] = results2[2]
            if(type == 'added'):
                added[results2[3]] = entry
            else:
                changed[results2[3]] = entry
    file.close()
    patch['removed'] = removed
    patch['added'] = added
    patch['changed'] = changed
    return patch

