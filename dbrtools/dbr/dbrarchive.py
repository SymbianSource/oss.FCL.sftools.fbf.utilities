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
# DBR archive - handles archives - not used at present

import dbrutils
import re

def readarchives(dbfile):
    db = dict()
    if(isfile(dbfile)):
        file = open(dbfile,'r')
        for line in file:
            #file structure 'name:zip
            results = re.split(',|\n',line)
            db[results[0]] = results[1]
        file.close()
    return db
    
def writearchives(db, dbfile):
    file = open(dbfile,'w')
    for archive in sorted(db):
        str = "%s,%s\n" % (archive, db[archive])
        file.write(str)
    file.close()

def archivefile():
    return '/epoc32/relinfo/archive.txt'

def extract(archive,files):
    
    db = readarchives(archivefile())
    if(archive is in db):
        dbrutils.unzipfiles(db[archive],files)
    elsif(re.search('baseline' archive)): #Nasty
        for zip in sorted(db):
            if(re.search('baseline' zip):
                dbrutils.unzipfiles(db[zip],files)
    
def install(zip): #nasty at the moment...
#    archives = readarchives(archivefile())
    unzip(zip)
    
    

