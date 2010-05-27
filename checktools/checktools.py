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

import os
import re

def test_command(label, command, output):
  print label,
  out = os.popen(command)
  for line in out.readlines():
    if re.match(output, line) :
      out.close()
      print '\t\t[OK]'
      return 0
  out.close()
  print '\t\t[MISSING]'
  return 1

print 'Symbian checktools version 0.1'
print 'Checking for existance of needed Symbian tools\n'
error_count = 0
error_count += test_command('7-zip','7z -h', 'Usage:')
error_count += test_command('PERL','perl -h', 'Usage:')
error_count += test_command('Python','python -h', 'usage:')
error_count += test_command('hg','hg -h', 'Mercurial')

print

if error_count > 0:
  print 'ERROR: One or more tools missing'
else:
  print 'All tools OK'