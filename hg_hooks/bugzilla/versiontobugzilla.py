#
# Copyright (c) 2009 Symbian Foundation.
# All rights reserved.
# This component and the accompanying materials are made available
# under the terms of the License "Eclipse Public License v1.0"
# which accompanies this distribution, and is available
# at the URL "http://www.eclipse.org/legal/epl-v10.html".
#
# Initial Contributors:
# Symbian Foundation - Initial contribution
# 
# Contributors:
# {Name/Company} - {Description of contribution}
# 
# Description:
# Mercurial hook to turn hg tags into package versions in Bugzilla
# 

'''Bugzilla integration for adding versions from tags

The hook updates the Bugzilla database directly. Only Bugzilla installations
using MySQL are supported.

This hook uses the same .hgrc parameters as the default Bugzilla hook. There
is no need for configuring the same stuff twice. (connection, etc.)

Configuring the extension: (same as Bugzilla -hook)

    [bugzilla]
    host       Hostname of the MySQL server holding the Bugzilla database.
    db         Name of the Bugzilla database in MySQL. Default 'bugs'.
    user       Username to use to access MySQL server. Default 'bugs'.
    password   Password to use to access MySQL server.
    timeout    Database connection timeout (seconds). Default 5.

Additional elements under Bugzilla -section: (new items)
    [bugzilla]
    product    The name on the Bugzilla product that is used for adding 
               the new versions.

Activating the extension:

    [extensions]
    hgext.versiontobugzilla =

    [hooks]
    incoming.versiontobugzilla = python:hgext.versiontobugzilla.hook

Example configuration in hgrc:
    [bugzilla]
    host = localhost
    user = bugs
    password = password
    product = my_product

    [extensions]
    hgext.versiontobugzilla =

    [hooks]
    incoming.versiontobugzilla = python:hgext.versiontobugzilla.hook
'''

from mercurial import util
import re

MySQLdb = None

class BugzillaClient:
    
    def __init__(self, ui, repo, node):
        self.tag = None
        self.ui = ui
        self.repo = repo
        self.node = node
        self.product = ui.config('bugzilla', 'product')
        self.host = ui.config('bugzilla', 'host', 'localhost')
        self.user = ui.config('bugzilla', 'user', 'bugs')
        self.passwd = ui.config('bugzilla', 'password')
        self.db = ui.config('bugzilla', 'db', 'bugs')
        self.timeout = int(ui.config('bugzilla', 'timeout', 10))
        self.connection = MySQLdb.connect(host=self.host, user=self.user, passwd=self.passwd,
                                    db=self.db, connect_timeout=self.timeout)
        self.cursor = self.connection.cursor()

    def printMessageInVerboseMode(self, message):
        '''Prints a message to console if hg has been executed with -v option.'''
        self.ui.note(message)

    def executeDatabaseQuery(self, *args, **kwargs):
        self.printMessageInVerboseMode('Bugzilla: query: %s %s\n' % (args, kwargs))
        try:
            self.cursor.execute(*args, **kwargs)
        except MySQLdb.MySQLError:
            self.printMessageInVerboseMode('Bugzilla: failed query: %s %s\n' % (args, kwargs))
            raise

    def commitContainsTag(self):
        self.parseTagFromCommitMessage()
        if self.tag:
            return True
        else:
            return False

    def parseTagFromCommitMessage(self):
        ctx = self.repo[self.node]
        version_re = re.compile(('Added tag (.+) for changeset [0-9a-h]+'), re.IGNORECASE)
        m = version_re.search(ctx.description())
        if m:
            self.tag = m.group(1)

    def insertTagIntoDatabase(self):
        self.makeSureThatProductExists()
        if not self.doesVersionAlreadyExist():
            self.printMessageInVerboseMode("Bugzilla: adding version '%s' to product '%s' in database.\n" % (self.tag, self.product))
            self.insertNewVersionIntoDatabase()
        else:
            self.printMessageInVerboseMode("Bugzilla: product '%s' already has a version '%s' in database. Not trying to add it again." % (self.product, self.tag))

    def makeSureThatProductExists(self):
        self.executeDatabaseQuery('select id from products where name = %s', (self.product,))
        ids = self.cursor.fetchall()
        if len(ids) != 1:
            raise util.Abort("Product '%s' does not exist in database, please check the [bugzilla] -section in hgrc." % self.product)

    def doesVersionAlreadyExist(self):
        self.executeDatabaseQuery('select * from versions where value = %s and product_id in (select id from products where name=%s )', (self.tag, self.product))
        ids = self.cursor.fetchall()
        if len(ids) == 1:
            return True
        else:
            return False

    def insertNewVersionIntoDatabase(self):
        self.executeDatabaseQuery('insert into versions (value, product_id) values (%s, (select id from products where name=%s ))', (self.tag, self.product))
        self.connection.commit()

def hook(ui, repo, hooktype, node=None, **kwargs):

    try:
        import MySQLdb as mysql
        global MySQLdb
        MySQLdb = mysql
    except ImportError, err:
        raise util.Abort('MySQL driver not installed: %s' % err)

    if node is None:
        raise util.Abort('Only hooks that have changesetid''s can be used.')

    try: 
        bzClient = BugzillaClient(ui, repo, node)
        if bzClient.commitContainsTag():
            bzClient.insertTagIntoDatabase()
    except MySQLdb.MySQLError, err:
        raise util.Abort('Database error: %s' % err[1])
