#!/usr/bin/perl

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
#
# Description:
# Compare two 7z listings, looking for files present in both

use strict;

my %first_files;
my $line;
my $file_index = -1;

while ($line=<>)
  {
  
  if ($line =~ /^Listing archive/)
    {
    $file_index++;
    print "$file_index: Processing $line";
    next;
    }

  # 2009-04-30 11:26:58 D....            0            0  epoc32\cshlpcmp_template
  # 2009-03-20 22:22:18 .....        72192        16307  epoc32\cshlpcmp_template\cshelp2000.dot
  
  next if (length($line) < 54);
  
  my $dir_attribute = substr($line, 20, 1);  
  if ($dir_attribute eq ".")
    {
    chomp $line;
    my $fullpath = substr($line, 53);
    
    if ($file_index == 0)
      {
      # first file
      $first_files{$fullpath} = $line;
      next;
      }
    if (defined $first_files{$fullpath})
      {
      print "Duplicate filename: $fullpath\n";
      print "\t$first_files{$fullpath}\n\t$line\n";
      next
      }
    }
  }

