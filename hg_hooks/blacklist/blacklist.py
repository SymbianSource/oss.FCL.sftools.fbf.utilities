#!/usr/bin/env python
#
# Copyright (C) 2010 Mozilla Foundation
# Copyright (C) 2010 Symbian Foundation
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

# Initial Contributors:
#  Pat Downey <patd@symbian.org>
# 
# Contributors:
#  Your name here?
#
# Description:
#
# An extension to mercurial that adds the ability to specify a blacklist for 
# a repository. That is to deny a changeset from being pushed/pulled/unbundled
# if it matches one of a set of patterns.
#
# At present it can deny nodes based on their changeset id, a regular expression
# matched against the user field, or a regular expression matched against the
# changeset's file list.
#
# Note: With the regular expression rules, if you want to match a string anywhere
# with in a string, e.g. create a rule against files within directories called 
# 'internal' the rule would need to be ..*/internal/.*'. That is you need to be 
# explicit in specifying a set of any characters otherwise it will perform a
# direct string comparison. #
#
# Requires sqlite extension (included in python 2.5 onwards)
#  * Available for python 2.4 in python-sqlite2 package on RHEL5.2+
#
# Ideas for implementation came strongly from:
# http://hg.mozilla.org/users/bsmedberg_mozilla.com/hghooks/file/tip/mozhghooks/pushlog.py
#
#

'''manage repository changeset blacklist

'''

from mercurial import demandimport

demandimport.disable()
try:
    import sqlite3 as sqlite
except ImportError:
    from pysqlite2 import dbapi2 as sqlite
demandimport.enable()

import binascii
import os
import os.path
import re
import stat
import sys
import time
from datetime import datetime


# changeset identifier 12-40 hex chars 
NODE_RE='^[0-9|a-f]{12,40}'




def blacklist(ui,repo,*args,**opts):
  '''manage repository changeset blacklist
  
  This extension is used to manage a blacklist for the repository.
  Can blacklist changesets by changeset id, and regular expressions against
  the user field of a changeset and also a changesets file list.
  
  Current rules can be viewed using the [-l|--list] operation.
  
  Each modification to a blacklist is logged. These can be viewed using the 
  --auditlog operation.
  
  Each time a changeset is blocked/denied it's logged. These can be viewed
  using the --blocklog operation.
  
  Types of changeset blacklist rules can be defined implicitly or explicitly:
  
    If a rule definition contains between 12 and 40 hexadecimal characters 
    it is assumed to be a rule matched against changeset id. Can be set 
    explicitly set with the -n flag to the --add operation.
  
    If a rule definition contains a '@' it is assumed to be a rule matched 
    against a changeset's user property. Can be set explicitly with 
    the -u flag to the --add operation.
  
    Otherwise the rule is assumed to be matched against a changeset's file 
    list. Can be set explicitly with the -f flag to the --add operation.
  
    When this extension is enabled a hook is also added to the 
    'pretxnchangegroup' action that will block any incoming changesets 
    (via pull/push/unbundle) if they are blacklisted.
    It won't block any local commits.
  '''
  conn = openconn(ui, repo )      
  if 'list' in opts and opts['list'] :
    listblacklistrule(ui,conn,args,opts)
  elif 'blocklog' in opts and opts['blocklog'] :
    listblacklistblocklog(ui,conn,args,opts)
  elif 'auditlog' in opts and opts['auditlog'] :
    listblacklistauditlog(ui,conn,args,opts)
  elif 'enable' in opts and opts['enable'] :
    enableblacklistrule(ui,conn,args,opts) 
  elif 'disable' in opts and opts['disable'] :
    disableblacklistrule(ui,conn,args,opts)
  elif 'remove' in opts and opts['remove'] :
    removeblacklistrule(ui,conn,args,opts)
  elif 'add' in opts and opts['add'] :
    addblacklistrule(ui,conn,args,opts)
  else :
    ui.warn( 'invalid operation specified\n' )
    
  conn.close( )  
 
####### Database setup methods
# this part derived from mozilla's pushlog.py hook
def openconn(ui,repo):
  blacklistdb = os.path.join(repo.path, 'blacklist.db')
  createdb = False
  if not os.path.exists(blacklistdb):
    createdb = True
  conn = sqlite.connect(blacklistdb)
  if not createdb and not schemaexists(conn):
    createdb = True
  if createdb:
    createblacklistdb(ui,conn)
    st = os.stat(blacklistdb)
    os.chmod(blacklistdb, st.st_mode | stat.S_IWGRP)

  return conn

# Derived from mozilla's pushlog hook
def schemaexists(conn):
    return 3 == conn.execute("SELECT COUNT(*) FROM SQLITE_MASTER WHERE name IN ( ?, ?, ?)" , ['blacklist_rule','blacklist_auditlog','blacklist_blocklog']).fetchone()[0]

# Derived from mozilla's pushlog hook
def createblacklistdb(ui,conn):
    # record of different blacklist rule, type should be either 'node' or 'file' or 'user'
    # 'node' - compare pattern with changeset identifier
    # 'file' - used as regular expression against changeset file manifest
    # 'user' - used as regular expression against changeset author/user
    # (id,pattern,type,enabled)
    conn.execute("CREATE TABLE IF NOT EXISTS blacklist_rule (id INTEGER PRIMARY KEY AUTOINCREMENT, pattern TEXT, type TEXT, enabled INTEGER,comment TEXT)")
    conn.execute("CREATE UNIQUE INDEX IF NOT EXISTS blacklist_rule_idx ON blacklist_rule (pattern,type)" )
 
    # records additions and modifications to the blacklist_rule table
    # (id, operation, rule_id, user, date, comment)
    conn.execute("CREATE TABLE IF NOT EXISTS blacklist_auditlog (id INTEGER PRIMARY KEY AUTOINCREMENT, operation TEXT, rule_id INTEGER, user TEXT, date INTEGER, comment TEXT)")
    conn.execute("CREATE INDEX IF NOT EXISTS blacklist_auditlog_rule_idx ON blacklist_auditlog (rule_id)" )

    # log attempted pushes and the http users trying to push a blocked changeset
    # (id,rule_id,cset_id, cset_user, cset_desc, user,date)
    conn.execute("CREATE TABLE IF NOT EXISTS blacklist_blocklog (id INTEGER PRIMARY KEY AUTOINCREMENT, rule_id INTEGER, cset_id TEXT, cset_user TEXT, cset_desc TEXT, user TEXT, date INTEGER)")
    conn.execute("CREATE INDEX IF NOT EXISTS blacklist_blocklog_rule_idx ON blacklist_blocklog (rule_id)" )

    conn.commit()

      
# Methods for extension commands      
def __getblacklistruletype( ui, pattern, opts ):
  type=None
    
  if opts['nodeType'] :
    type = 'node'
  elif opts['fileType'] :
    type = 'file'
  elif opts['userType'] :
    type = 'user'

  # try and work out type of blacklist if none specified
  # default to regexp
  if type == None :
    if re.match( NODE_RE, pattern ) :
      type = 'node'
    elif '@' in pattern :
      type = 'user'
    else :
      type = 'file'
    ui.note( 'type implicitly set to \'%s\'\n' % type )  

  return type

def addblacklistrule(ui,conn,args,opts):
  ret = 1
  if len(args) == 1 :
    createrule = True
    pattern = args[0]

    type = __getblacklistruletype( ui, pattern, opts )

    if type == 'node' :
      # if pattern has been specified as a node type
      # check that pattern is a valid node
      if not re.match( NODE_RE, pattern ) :
        ui.warn( 'node should be 12 or 40 characters.\n' )
        createrule = False 
    
    if createrule :
      comment = None
      
      if 'desc' in opts and opts['desc'] :
        if opts['desc'] != '' :
          comment = opts['desc']
      
      insertblacklistrule(ui,conn,pattern,type, comment=comment)
  else :
    ui.warn( 'missing pattern argument.\n' )
    
  return ret      
    
def removeblacklistrule(ui,conn,args,opts):
  if len(args) == 1 :
    deleteblacklistrule(ui,conn,args[0])
  else :
    ui.warn( 'rule id argument required.\n' )
  
  return 0
    
def disableblacklistrule(ui,conn,args,opts):
  if len(args) == 1 :
    updateblacklistrule(ui,conn,args[0],False)
  else :
    ui.warn( 'rule id argument required.\n' )
  
  return 0    
    
def enableblacklistrule(ui,conn,args,opts):
  if len(args) == 1 :
    updateblacklistrule(ui,conn,args[0],True)
  else :
    ui.warn( 'rule id argument required.\n' )
  
  return 0    
    
def listblacklistrule(ui,conn,args,opts):
  if len(args) in (0,1) :
    res = selectblacklistrule(ui,conn,args)
    
    printblacklist(ui,res)
  else :
    ui.warn( 'too many arguments.\n' )
    
  return 0

def listblacklistauditlog(ui,conn,args,opts):
  if len(args) in (0,1) :
    res = selectblacklistauditlog(ui, conn, args )
        
    printauditlog(ui,res)
  else :
    ui.warn( 'too many arguments.\n' )
    
  return 0

def listblacklistblocklog(ui,conn,args,opts):
  if len(args) in (0,1) :
    res = selectblacklistblocklog(ui, conn, args )
        
    printblocklog(ui,res)
  else :
    ui.warn( 'too many arguments.\n' )
    
  return 0

def insertblacklistaudit(ui, conn, operation, rule_id, comment=None ):
  user = __getenvuser( )
  audit_date = int(time.time())

  audit_sql = 'INSERT INTO blacklist_auditlog ( operation, rule_id, user, date, comment ) VALUES ( ?, ?, ?, ?, ? )'
  conn.execute( audit_sql, (operation, rule_id, user, audit_date, comment ) )

def insertblacklistrule(ui, conn, pattern, type, enabled=True, comment=None):
  rule_sql = 'INSERT INTO blacklist_rule ( pattern, type, enabled,comment ) VALUES ( ?, ?, ?, ? )'
  
  res = conn.execute( rule_sql, (pattern,type,enabled,comment) )
  rule_id= res.lastrowid
  
  insertblacklistaudit(ui, conn, 'add', rule_id,comment=comment )
                     
  conn.commit( )

def __getenvuser( ):
  # look at REMOTE_USER first  
  # then look at LOGUSER
  # then look at USER
  for e in ['REMOTE_USER','SUDO_USER','LOGUSER','USER'] :
    if e in os.environ :
      user = '%s:%s' %( e, os.environ.get( e ) )
      break

  return user

def insertblacklistblocklog( ui, conn, rule, ctx ):
  # (id, rule_id, user, date)
  rule_id=rule[0]

  log_user = __getenvuser( )
  audit_date = int(time.time())
  
  ctx_node = binascii.hexlify(ctx.node())
  ctx_user = ctx.user()
  ctx_desc = ctx.description()
  
  log_sql = 'INSERT INTO blacklist_blocklog (rule_id,user,date,cset_id,cset_user,cset_desc) VALUES (?,?,?,?,?,?)'
  conn.execute( log_sql, (rule_id,log_user,audit_date, ctx_node, ctx_user, ctx_desc))
  conn.commit()    

def updateblacklistrule(ui, conn, rule_id, enabled):
  rule_sql = 'UPDATE blacklist_rule SET enabled=? WHERE id=?'
  
  conn.execute( rule_sql, [enabled, rule_id] )
  
  insertblacklistaudit(ui, conn, 'update', rule_id, 'enabled=%s' % enabled )
  
  conn.commit( )
  
def deleteblacklistrule(ui, conn, rule_id ):
  if rule_id != None :
    res = selectblacklistrule(ui, conn, rule_id )
    processed = False
    for (id,pattern,type,enabled,comment) in res :
      comment = 'deleted: pattern=%s, type=%s, enabled=%s' % (pattern, type, enabled)
  
      rule_sql = 'DELETE FROM blacklist_rule WHERE id=?'
      conn.execute( rule_sql, [rule_id] )
  
      insertblacklistaudit(ui, conn, 'delete', rule_id, comment)      

      conn.commit( )
      processed = True
      
    if not processed :
      ui.warn( 'no matching blacklist rule found with id %s\n' % rule_id )
  else :
    ui.warn( 'no rule id specified\n' )

def selectblacklistrule(ui, conn, rule_id ):
  # (id, operation, rule_id, user, date, comment)
  if rule_id :
    rule_sql = 'SELECT id,pattern,type,enabled,comment FROM blacklist_rule WHERE id=? ORDER BY id ASC'
    res = conn.execute( rule_sql, rule_id )
  else :
    rule_sql = 'SELECT id,pattern,type,enabled,comment FROM blacklist_rule ORDER BY id ASC'
    res = conn.execute( rule_sql )

  return res  
  
def selectblacklistauditlog(ui,conn,rule_id=None) :
  # (id, operation, rule_id, user, date, comment)
  if rule_id :
    rule_sql = 'SELECT id,operation,rule_id,user,date,comment FROM blacklist_auditlog WHERE rule_id=? ORDER BY date ASC'
    res = conn.execute( rule_sql, rule_id )
  else :
    rule_sql = 'SELECT id,operation,rule_id,user,date,comment FROM blacklist_auditlog ORDER BY date ASC'
    res = conn.execute( rule_sql )

  return res

def selectblacklistblocklog(ui,conn,rule_id=None) :
  # (id, rule_id, node, user, date)
  if rule_id :
    rule_sql = 'SELECT id,rule_id,cset_id,cset_user,cset_desc,user,date FROM blacklist_blocklog WHERE rule_id=? ORDER BY date ASC'
    res = conn.execute( rule_sql, rule_id )
  else :
    rule_sql = 'SELECT id,rule_id,cset_id,cset_user,cset_desc,user,date FROM blacklist_blocklog ORDER BY date ASC'
    res = conn.execute( rule_sql )

  return res  
  
def printblacklist(ui,res):
  for r in res :
    (id,pattern,type,enabled,comment) = r  
  
    if enabled == 1 :
      enabled = True
    elif enabled == 0 :
      enabled = False

    ui.write( 'rule:     %d:%s\n' % (id,type) )
    ui.write( 'pattern:  %s\n' % pattern )
    ui.write( 'enabled:  %s\n' % enabled )
    if comment :
      ui.write( 'comment:  %s\n' % comment )
    ui.write( '\n' )

def printauditlog(ui,res):
  for r in res :
    (id, operation, rule_id, user, date, comment) = r
     
    date = datetime.utcfromtimestamp(date).isoformat()  
     
    if not comment :
      comment = '' 
     
    ui.write( 'date:      %s\n' % date )
    ui.write( 'operation: %s\n' % operation )
    ui.write( 'user:      %s\n' % user )
    ui.write( 'rule:      %s\n' % rule_id )
    ui.write( 'comment:   %s\n' % comment )
    ui.write( '\n' )

def printblocklog(ui,res):
  for r in res :
    (id, rule_id, cset_id, cset_user, cset_desc, user, date) = r
     
    date = datetime.utcfromtimestamp(date).isoformat()  
     
    ui.write( 'cset:      %s\n' % cset_id )
    ui.write( 'cset-user: %s\n' % cset_user)
    ui.write( 'cset-desc: %s\n' % cset_desc )
    ui.write( 'rule:      %s\n' % rule_id )
    ui.write( 'date:      %s\n' % date )
    ui.write( 'user:      %s\n' % user )

    ui.write( '\n' )


# Hook specific functions follow

def excludecsetbyfile(ctx,pattern):
  exclude = False
  
  file_re = re.compile( '%s' % pattern, re.I )
  for f in ctx.files() :
    if file_re.match( f ) :
      exclude = True
      break

  return exclude

def excludecsetbynode(ctx,pattern):
  exclude = False
  
  node = binascii.hexlify(ctx.node())
  
  if node.startswith( pattern ) :
    exclude = True

  return exclude

def excludecsetbyuser(ctx,pattern):
  exclude = False
  userStr = ctx.user()
  
  user_re = re.compile( '^.*%s.*$' % pattern, re.I )
  if user_re.match( userStr ) :
    exclude = True
 
  return exclude  

def excludeblacklistcset(ui,conn,ctx):

  bl_sql = 'SELECT id,pattern,type FROM blacklist_rule WHERE enabled=1'
  res = conn.execute( bl_sql )
  
  (exclude,rule) = (False,None)
  
  for (id,pattern,type) in res :
    if type == 'node' :
      exclude = excludecsetbynode(ctx,pattern)
    elif type == 'user' :
      exclude = excludecsetbyuser(ctx,pattern)
    elif type == 'file' :
      exclude = excludecsetbyfile(ctx,pattern)
    else :
      ui.warn('unrecognised rule type \'%s\'' % type )

    if exclude :
      rule = (id,pattern,type)
      break

  return (exclude,rule)

# The hook method that is used to block bad changesets from being introduced 
# to the current repository
def pretxnchangegroup(ui,repo,hooktype,node,**args):
  start = repo[node].rev()
  end = len(repo)

  conn = openconn(ui, repo )

  blocked = False

  for rev in xrange(start, end):
    ctx = repo[rev]
    (blocked,rule) = excludeblacklistcset( ui, conn, ctx)

    if blocked :
      insertblacklistblocklog( ui, conn, rule, ctx )
      (id,pattern,type) = rule
      ui.write( 'blocked: cset %s in changegroup blocked by blacklist\n' % str(ctx) )
      ui.write( 'blocked-reason: %s matched against \'%s\'\n' % ( type,pattern ))
      break
  
  conn.close( )    
  
  return blocked

def setupblacklisthook(ui):
  ui.setconfig('hooks', 'pretxnchangegroup.blacklist', pretxnchangegroup)

def reposetup(ui,repo):
  # print 'in blacklist reposetup'
  setupblacklisthook( ui )

def uisetup(ui):
  # print 'in blacklist uisetup'
  setupblacklisthook( ui )

cmdtable = {
            'blacklist': (blacklist,
                          [
                           ('l','list',None,'list blacklist entries'),
                           ('','blocklog',None,'list blocked changesets'),
                           ('','auditlog',None,'show audit log for blacklist'),
                           ('a','add',None,'add node to blacklist'),
                           ('d','disable',None,'disable blacklist rule'),
                           ('e','enable',None,'enable blacklist rule'),
                           ('r','remove',None,'remove node from blacklist'),
                           ('n','nodeType',False,'parse argument as node to blacklist'),
                           ('f','fileType',False,'parse argument as file path to blacklist'),
                           ('u','userType',False,'parse argument as user regexp to blacklist'),
                           ('','desc','','comment to attach to rule')],
                          "")
            }
