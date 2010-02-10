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
import time
from BeautifulSoup import BeautifulSoup
from optparse import OptionParser
import hashlib
import xml.etree.ElementTree as ET 

user_agent = 'downloadkit.py script'
headers = { 'User-Agent' : user_agent }
top_level_url = "http://developer.symbian.org"
download_list = []
unzip_list = []

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

threadlist = []
def schedule_unzip(filename, unziplevel, deletelevel):
	global options
	if options.nounzip :
		return
	if options.nodelete :
		deletelevel = 0
	if options.dryrun :
		global unzip_list
		if unziplevel > 0:
			unzip_list.append("7z x -y %s" % filename)
			if unziplevel > 1:
				unzip_list.append("# unzip recursively %d more times" % unziplevel-1)
		if deletelevel > 0:
			unzip_list.append("# delete %s" % filename)
			if deletelevel > 1:
				unzip_list.append("# delete zip files recursively %d more times" % deletelevel-1)
		return
		
	unzipthread = unzipfile(filename, unziplevel, deletelevel)
	global threadlist
	threadlist.append(unzipthread)
	unzipthread.start()

def complete_outstanding_unzips():
	global options
	if options.dryrun or options.nounzip:
		return
	print "Waiting for outstanding commands to finish..."
	for thread in threadlist:
		thread.join()  

def check_unzip_environment():
	global options
	if options.nounzip:
		return True		# if we aren't unzipping, no need to have 7z installed
	help = os.popen("7z -h")
	for line in help.readlines():
		if re.match('7-Zip', line) :
			help.close()
			return True
	help.close()
	return False

def orderResults(x,y) :
	def ranking(name) :
		# 0th = release_metadata
		if re.match(r"release_metadata", name):
			return 0000;
		# 1st = release_metadata, build_BOM.zip (both small things!)
		if re.match(r"build_BOM", name):
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

def md5_checksum(filename):
	MD5_BLOCK_SIZE = 128 * 1024
	md5 = hashlib.md5()
	try:
		file = open(filename,"rb")
	except IOError:
		print "Terminating script: Unable to open %S" % filename
		sys.exit()
	while True:
		data = file.read(MD5_BLOCK_SIZE)
		if not data:
			break
		md5.update(data)
	file.close()
	return md5.hexdigest().upper()

checksums = {}
def parse_release_metadata(filename):
	if os.path.exists(filename):
		tree = ET.parse(filename)
		iter = tree.getiterator('package')
		for element in iter:
			if element.keys():
				file = element.get("name")
				md5 = element.get("md5checksum")
				checksums[file] = md5.upper()

def download_file(filename,url):
	global options
	global checksums
	if os.path.exists(filename):
		if filename in checksums:
			print 'Checking existing ' + filename
			file_checksum = md5_checksum(filename)
			if file_checksum == checksums[filename]:
				if options.progress:
					print '- OK ' + filename
				return True

	if options.dryrun and not re.match(r"release_metadata", filename):
		global download_list
		download_info = "download %s %s" % (filename, url)
		download_list.append(download_info)
		return True

	print 'Downloading ' + filename
	global headers
	req = urllib2.Request(url, None, headers)
	
	CHUNK = 128 * 1024
	size = 0
	filesize = -1
	start_time = time.time()
	last_time = start_time
	last_size = size
	try:
		response = urllib2.urlopen(req)
		chunk = response.read(CHUNK)
		if chunk.find('<div id="sign_in_box">') != -1:
			# our urllib2 cookies have gone awol - login again
			login(False)
			req = urllib2.Request(url, None, headers)
			response = urllib2.urlopen(req)
			chunk = response.read(CHUNK)
			if chunk.find('<div id="sign_in_box">') != -1:
				# still broken - give up on this one
				print "*** ERROR trying to download %s" % (filename)
				return False
		info = response.info()
		if 'Content-Length' in info:
			filesize = int(info['Content-Length'])
		else:
			print "*** HTTP response did not contain 'Content-Length' when expected"
			print info
			return False

	except urllib2.HTTPError, e:
		print "HTTP Error:",e.code , url
		return False
	except urllib2.URLError, e:
		print "URL Error:",e.reason , url
		return False

	# we are now up and running, and chunk contains the start of the download
	
	try:
		fp = open(filename, 'wb')
		md5 = hashlib.md5()
		while True:
			fp.write(chunk)
			md5.update(chunk)
			size += len(chunk)
			now = time.time()
			if options.progress and now-last_time > 20:
				rate = (size-last_size)/(now-last_time)
				estimate = ""
				if filesize > 0 and rate > 0:
					remaining_seconds = (filesize-size)/rate
					if remaining_seconds > 110:
						remaining = "%d minutes" % (remaining_seconds/60)
					else:
						remaining = "%d seconds" % remaining_seconds
					estimate = "- %d%% est. %s" % ((100*size/filesize), remaining)
				print "- %d Kb (%d Kb/s) %s" % (size/1024, (rate/1024)+0.5, estimate)
				last_time = now
				last_size = size
			chunk = response.read(CHUNK)
			if not chunk: break

		fp.close()
		if options.progress:
			now = time.time()
			print "- Completed %s - %d Kb in %d seconds" % (filename, (filesize/1024)+0.5, now-start_time)

	#handle errors
	except urllib2.HTTPError, e:
		print "HTTP Error:",e.code , url
		return False
	except urllib2.URLError, e:
		print "URL Error:",e.reason , url
		return False

	if filename in checksums:
		download_checksum = md5.hexdigest().upper()
		if download_checksum != checksums[filename]:
			print '- WARNING: %s checksum does not match' % filename

	return True

def downloadkit(version):	
	global headers
	global options
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

		if options.nosrc and re.match(r"(src_sfl|src_oss)", filename) :
			continue 	# no snapshots of Mercurial source thanks...

		if download_file(filename, downloadurl) != True :
			continue # download failed

		# unzip the file (if desired)
		if re.match(r"patch", filename):
			complete_outstanding_unzips()	# ensure that the thing we are patching is completed first
			
		if re.match(r"release_metadata", filename):
			parse_release_metadata(filename)	# read the md5 checksums etc
		elif re.match(r"(bin|tools).*\.zip", filename):
			schedule_unzip(filename, 1, 0)   # unzip once, don't delete
		elif re.match(r"src_.*\.zip", filename):
			schedule_unzip(filename, 1, 1)   # zip of zips, delete top level
		elif re.match(r"build_BOM.zip", filename):
			schedule_unzip(filename, 1, 1)   # unpack then delete zip as it's not needed again

	# wait for the unzipping threads to complete
	complete_outstanding_unzips()  

	return 1

parser = OptionParser(version="%prog 0.7", usage="Usage: %prog [options] version")
parser.add_option("-n", "--dryrun", action="store_true", dest="dryrun",
	help="print the files to be downloaded, the 7z commands, and the recommended deletions")
parser.add_option("--nosrc", action="store_true", dest="nosrc",
	help="Don't download any of the source code available directly from Mercurial")
parser.add_option("--nounzip", action="store_true", dest="nounzip",
	help="Just download, don't unzip or delete any files")
parser.add_option("--nodelete", action="store_true", dest="nodelete",
	help="Do not delete files after unzipping")
parser.add_option("--progress", action="store_true", dest="progress",
	help="Report download progress")
parser.set_defaults(dryrun=False, nosrc=False, nounzip=False, nodelete=False, progress=False)

(options, args) = parser.parse_args()
if len(args) != 1:
	parser.error("Must supply a PDK version, e.g. 3.0.f")
if not check_unzip_environment() :
	parser.error("Unable to execute 7z command")

login(True)
downloadkit(args[0])

if options.dryrun:
	print "# instructions for downloading kit " + args[0]
	for download in download_list:
		print download
	for command in unzip_list:
		print command

