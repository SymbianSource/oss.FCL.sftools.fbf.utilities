#!/usr/bin/python
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
# Description:
# Map the SFL license to the EULA license, keeping a copy of the original file
# in a parallel tree for creation of a "repair" kit to reinstate the SFL

import os
import os.path
import re
import codecs

oldtext0 = re.compile('terms of the License "Symbian Foundation License v1.0"(to Symbian Foundation)?')
oldtext1 = re.compile('the URL "http:..www.symbianfoundation.org/legal/sfl-v10.html"')

newtext = [
  'terms of the License "Symbian Foundation License v1.0" to Symbian Foundation members and "Symbian Foundation End User License Agreement v1.0" to non-members',
  'the URL "http://www.symbianfoundation.org/legal/licencesv10.html"'
]

errorfiles = []
multinoticefiles = []
shadowroot = 'shadow_epoc32'

def file_type(file) :
	f = open(file, 'r')
	data = f.read(256)
	f.close()
	if len(data) < 2:
		return None # too short to be worth bothering about anyway
	if data[0] == chr(255) and data[1] == chr(254) :
		return 'utf_16_le'
	if data.find(chr(0)) >= 0 : 
		return None	# zero byte implies binary file
	return 'text'
	
def map_eula(dir, name, encoded) :
	global oldtext0
	global newtext1
	global newtext
	file = os.path.join(dir, name)
	if encoded == 'text':
		f = open(file, 'r')
	else:
		f = codecs.open(file, 'r', encoding=encoded)
	lines = f.readlines()
	# print ">> %s encoded as %s" % (file, f.encoding)
	f.close()
	
	updated = 0
	newlines = []
	while len(lines) > 0:
		line = lines.pop(0)
		pos1 = oldtext0.search(line)
		if pos1 != None:
			# be careful - oldtext is a prefix of newtext
			if pos1.group(1) != None:
				# line already converted - nothing to do
				newlines.append(line)
				continue
			midlines = []
			midlinecount = 1
			while len(lines) > 0:
				nextline = lines.pop(0)
				if not re.match('^\s$', nextline):
					# non-blank line
					if midlinecount == 0:
						break
					midlinecount -= 1
				midlines.append(nextline)
			urlline = nextline
			pos2 = oldtext1.search(urlline)
			if pos2 != None:
				# found it - assume that there's only one instance
				newline = oldtext0.sub(newtext[0], line)
				newurl  = oldtext1.sub(newtext[1], urlline)
				newlines.append(newline)
				newlines.extend(midlines)
				newlines.append(newurl)
				updated += 1
				continue
			else:
			  if updated != 0:
			  	lineno = 1 + len(newlines)
			  	print "Problem in " + file + " at " + lineno + ": incorrectly formatted >"
			  	print line
			  	print midlines
			  	print urlline
			  	global errorfiles
			  	errorfiles.append(file)
			  break
		newlines.append(line)
	
	if updated == 0:
		print " = no change to " + file
		return
	
	if updated > 1:
	  global multinoticefiles
	  multinoticefiles.append(file)
	  print '! found %d SFL notices in %s' % (updated, file)
	
	global shadowroot
	shadowdir = os.path.join(shadowroot, dir)
	if not os.path.exists(shadowdir) :
		os.makedirs(shadowdir)
	newfile = os.path.join(shadowroot,file)
	os.rename(file, newfile)
	if encoded == 'text':
		f = open(file, 'w')
	else:
		f = codecs.open(file, 'w', encoding=encoded)
	f.writelines(newlines)
	f.close()
	print "* updated %s (encoding %s)" % (file, f.encoding)

# process tree

for root, dirs, files in os.walk('epoc32', topdown=True):
	if re.compile('epoc32$').match(root) >= 0:
		if 'build' in dirs:
			dirs.remove('build') # don't recurse into the epoc32/build subtree
	for name in files:
		encoding = file_type(os.path.join(root, name))
		if encoding:
			map_eula(root, name, encoding)
	
print '%d problem files' % len(errorfiles)
print errorfiles

print '%d files with multiple notices' % len(multinoticefiles)
print multinoticefiles

	
