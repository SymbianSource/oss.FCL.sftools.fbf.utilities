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
# DBRResults - DBR Comparison results classes  



class DBRResults:
  added = set()
  removed = set()
  touched = set()
  changed = set()
  unknown = set()

  def __init__(self, added, removed, touched, changed, unknown):
    #Should probably assert that these are disjoint.
    self.added = added
    self.removed = removed
    self.touched = touched
    self.changed = changed
    self.unknown = unknown
    
  def __rand__(self, other):
    return DBRResults(self.added & other.added, self.removed & other.removed, self.touched & other.touched, self.changed & other.changed, self.unknown & other.unknown)

  def __iand__(self, other):
    self.added &= other.added
    self.removed &= other.removed
    self.touched &= other.touched
    self.changed &= other.changed
    self.unknown &= other.unknown  
    return self

  def __ror__(self, other):
    return DBRResults(self.added | other.added, self.removed | other.removed, self.touched | other.touched, self.changed | other.changed, self.unknown | other.unknown)

  def __ior__(self, other):
    self.added |= other.added
    self.removed |= other.removed
    self.touched |= other.touched
    self.changed |= other.changed
    self.unknown |= other.unknown
    return self
  
  def __sub__(self, other):
    return DBRResults(self.added - other.added, self.removed - other.removed, self.touched - other.touched, self.changed - other.changed, self.unknown - other.unknown)
         
  def printdetail(self):
    for file in sorted(self.added):
      print 'added:', file
    for file in sorted(self.removed):
      print 'removed:', file
    for file in sorted(self.changed):
      print 'changed:', file
    for file in sorted(self.unknown):
      print 'unknown:', file
    
  def printsummary(self):
    if(len(self.added | self.removed | self.changed | self.unknown)):
      print 'status: dirty'
    else:
      print 'status: clean' 
