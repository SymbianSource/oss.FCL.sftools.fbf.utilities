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
# Identify "Public APIs" - defined as
# 1. Files in epoc32\include which are not in epoc32\include\platform, 
# 2. And contain either no Symbian API classification doxygen tags (Public by export)
# 3. Or contain @publishedAll (Public by tag - now deprecated)

use strict;
my $debug = 0;

sub is_public_api($$)
  {
  my ($file,$name) = @_;
  
  if ($name =~ /^epoc32\/include\/platform\//)
    {
    # /epoc32/include/platform files are "Platform by export"
    return 0; # Not public
    }
  
  open FILE, "<$file" or print "ERROR: Cannot open $file: $!\n" and return 1; # assume Public
  my @lines = <FILE>; # they are all of a modest size
  close FILE;
  
  my @apitaglines = grep /\@published|\@internal/, @lines;
  if (scalar @apitaglines == 0)
    {
    # no API classification tags - must be "Public by export" 
    return 1; # Public API
    }
  
  if ($debug)
    {
    print join("\n\t", $file, @apitaglines), "\n";
    }
  my @publishedAll = grep /\@publishedAll/, @apitaglines;
  if (scalar @publishedAll == 0)
    {
    # the API classification tags are all @publishedPartner or @internal
    return 0; # not public
    }
  # contains at least one @publishedAll element - must be "Public by tag"
  return 1; # Public API
  }

sub scan_directory($$)
  {
  my ($path, $name) = @_;
  
  opendir DIR, $path;
  my @files = grep !/^\.\.?$/, readdir DIR;
  closedir DIR;
  
  foreach my $file (@files)
    {
    my $newpath = "$path/$file";
    my $newname = "$name/$file";
    
    if (-d $newpath)
      {
      scan_directory($newpath, $newname);
      next;
      }
    
    if (is_public_api($newpath,$newname))
      {
      print "$newname\n";
      }
    else
      {
      # print "PARTNER\t$newname\n";
      }
    }
  }

scan_directory("/epoc32/include", "epoc32/include");
