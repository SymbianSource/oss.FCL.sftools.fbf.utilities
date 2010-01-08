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
# Script to download and unpack a Symbian PDK - assumes "7z" installed to unzip the files

import urllib2
import urllib
import os.path
import cookielib
import sys
import getpass
import re
from BeautifulSoup import BeautifulSoup

user_agent = 'downloadkit.py script'
headers = { 'User-Agent' : user_agent }
top_level_url = "http://developer.symbian.org"

username = ''
password = ''

COOKIEFILE = 'cookies.lwp'
# the path and filename to save your cookies in

# importing cookielib worked
urlopen = urllib2.urlopen
Request = urllib2.Request
cj = cookielib.LWPCookieJar()

# This is a subclass of FileCookieJar
# that has useful load and save methods
if os.path.isfile(COOKIEFILE):
	cj.load(COOKIEFILE)
	
# Now we need to get our Cookie Jar
# installed in the opener;
# for fetching URLs
opener = urllib2.build_opener(urllib2.HTTPCookieProcessor(cj))
urllib2.install_opener(opener)

def login(prompt):
	global username
	global password
	loginurl = 'https://developer.symbian.org/main/user_profile/login.php'
	
	if prompt:
		print >> sys.stderr, 'username: ',
		username=sys.stdin.readline().strip()
		password=getpass.getpass()
	
	values = {'username' : username,
	          'password' : password,
	          'submit': 'Login'}
	          
	headers = { 'User-Agent' : user_agent }
	
	
	data = urllib.urlencode(values)
	req = urllib2.Request(loginurl, data, headers)

	response = urllib2.urlopen(req)
	doc=response.read()      

	if doc.find('Please try again') != -1:
		print >> sys.stderr, 'Login failed'
		return False
	
	cj.save(COOKIEFILE) 
	return True

from threading import Thread

class unzipfile(Thread):
	def __init__ (self,filename,levels=1,deletelevels=0):
		Thread.__init__(self)
		self.filename = filename
		self.levels = levels
		self.deletelevels = deletelevels
		self.status = -1
		
	def unzip(self,filename,unziplevel,deletelevel):
		if unziplevel < 1:
			return 0   # do nothing

		print "  Unzipping " + filename
		filelist = os.popen("7z x -y "+self.filename)
		subzips = []
		for line in filelist.readlines():
			# Extracting  src_oss_app_webuis.zip
			match = re.match(r"^Extracting\s+(\S+.zip)$", line)
			if match is None: continue
			subzips.append(match.group(1))
		topstatus = filelist.close()

		if deletelevel > 0:
			print "  Deleting " + filename
			os.remove(filename)
		if unziplevel > 1 and len(subzips) > 0:
			print "  Expanding %d zip files from %s" % (len(subzips), filename)
			for subzip in subzips:
				self.unzip(subzip, unziplevel-1, deletelevel-1)
		return topstatus
	def run(self):
		self.status = self.unzip(self.filename, self.levels, self.deletelevels)

def orderResults(x,y) :
	def ranking(name) :
		# 1st = release_metadata, build_BOM.zip (both small things!)
		if re.match(r"(build_BOM|release_metadata)", name):
			return 1000;
		# 2nd = tools, binaries (required for execution and compilation)
		elif re.match(r"(binaries_|tools_)", name):
			return 2000;
		# 3rd = rnd binaries, binary patches
		elif re.match(r"(bin_)", name):
			return 3000;
		# 4th = sources
		elif re.match(r"(src_sfl|src_oss)", name):
			return 4000;
		# 5rd = rnd sources, source patches (not sure we'd ever have those)
		elif re.match(r"(src_)", name):
			return 5000;
		# Last, anything else
		return 10000;
	xtitle = x['title']
	ytitle = y['title']
	return cmp(ranking(xtitle)+cmp(xtitle,ytitle), ranking(ytitle))

def downloadkit(version):
	headers = { 'User-Agent' : user_agent }
	urlbase = 'http://developer.symbian.org/main/tools_and_kits/downloads/'

	viewid = 5   # default to Symbian^3
	if version[0] == 2:
		viewid= 1  # Symbian^2
	if version[0] == 3:
		viewid= 5  # Symbian^3
	url = urlbase + ('view.php?id=%d'% viewid) + 'vId=' + version

	req = urllib2.Request(url, None, headers)
	response = urllib2.urlopen(req)
	doc=response.read()
	
	# BeatifulSoup chokes on some javascript, so we cut away everything before the <body>
	try:
		bodystart=doc.find('<body>')
		doc = doc[bodystart:]
	except:
		pass

	threadlist = []
	# let's hope the HTML format never changes...
	# <a href='download.php?id=27&cid=60&iid=270' title='src_oss_mw.zip'> ...</a> 

	soup=BeautifulSoup(doc)
	results=soup.findAll('a', href=re.compile("^download"), title=re.compile("\.(zip|xml)$"))
	results.sort(orderResults)
	for result in results:
		downloadurl = urlbase + result['href']
		filename = result['title']
		print 'Downloading ' + filename
		req = urllib2.Request(downloadurl, None, headers)
		
		try:
			response = urllib2.urlopen(req)
			CHUNK = 128 * 1024
			first_chunk = True
			fp = open(filename, 'wb')
			while True:
				chunk = response.read(CHUNK)
				if not chunk: break
				if first_chunk and chunk.find('<div id="sign_in_box">') != -1:
					# our urllib2 cookies have gone awol - login again
					login(False)
					req = urllib2.Request(downloadurl, None, headers)
					response = urllib2.urlopen(req)
					chunk = response.read(CHUNK)	  
				fp.write(chunk)
				first_chunk = False
			fp.close()

		#handle errors
		except urllib2.HTTPError, e:
			print "HTTP Error:",e.code , downloadurl
		except urllib2.URLError, e:
			print "URL Error:",e.reason , downloadurl

		# unzip the file (if desired)
		if re.match(r"(bin|tools).*\.zip", filename):
			unzipthread = unzipfile(filename, 1, 0)   # unzip once, don't delete
			threadlist.append(unzipthread)
			unzipthread.start()
		elif re.match(r"src_.*\.zip", filename):
			unzipthread = unzipfile(filename, 1, 1)   # zip of zips, delete top level
			threadlist.append(unzipthread)
			unzipthread.start()
		elif re.match(r"build_BOM.zip", filename):
			unzipthread = unzipfile(filename, 1, 1)   # unpack then delete zip as it's not needed again
			threadlist.append(unzipthread)
			unzipthread.start()

	# wait for the unzipping threads to complete
	print "Waiting for unzipping to finish..."
	for thread in threadlist:
		thread.join()  

	return 1


login(True)
downloadkit(sys.argv[1])
