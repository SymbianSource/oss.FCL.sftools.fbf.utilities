# filecheck.py - changeset filename check for mercurial
#
# should be configured as pretxnchangegroup to vet incoming changesets
# and as pretxncommit to vet local commit
#
# will receive a group of changesets from provided node to tip

from mercurial import util
from mercurial.i18n import _
import re

badpatterns = ('.*\.ttt\s*$','c.ttf','.*\.ttf\s*$','.*\.bbb\s*$',
               '.*\.bbb\s*$','.*\.ccc\s*$','.*\.ddd\s*$','.*\.eee\s*$','.*\.fff\s*$','.*\.ggg\s*$')

badexpr=[]
runonce=0

def init():
    global badexpr
    for p in badpatterns:
        badexpr.append((re.compile((p),re.IGNORECASE)))

def deny(f):
    global runonce
    if (not runonce):
        init()
        runonce =1
      
    for pat in badexpr:
        if(pat.match(f)):
            return(1)
    
    return(0)

def push_hook(ui, repo, hooktype, node=None, source=None, **kwargs):
    if hooktype != 'pretxnchangegroup':
        raise util.Abort(_('config error - hook type "%s" cannot stop '
                           'incoming changesets') % hooktype)
    
    # iterate over all the added changesets between node and tip
    for rev in xrange(repo[node], len(repo)):
        ctx = repo[rev]
        for f in ctx.files():
            if deny(f):
                ui.debug(_('filecheck: file %s not allowed \n') % (f))
                raise util.Abort(_('filecheck: access denied for changeset %s file %s blocked') % (ctx,f))
        ui.debug(_('filecheck: allowing changeset %s\n') % ctx)

def commit_hook(ui, repo, hooktype, node=None, source=None, **kwargs):
    # iterate over all the files in added changeset
    ctx = repo[node]
    for f in ctx.files():
        if deny(f):
            ui.debug(_('filecheck: file %s not allowed \n') % (f))
            raise util.Abort(_('filecheck: access denied for changeset %s file %s blocked') % (ctx,f))
    ui.debug(_('filecheck: allowing changeset %s\n') % ctx)
