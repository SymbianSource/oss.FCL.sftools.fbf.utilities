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

my @public_included = ();
my $reason;

sub is_public_api($$)
  {
  my ($file,$name) = @_;
  
  if ($name =~ /^epoc32\/include\/platform\//)
    {
    # /epoc32/include/platform files are "Platform by export"
    $reason = "Platform by export";
    return 0; # Not public
    }
  
  if ($name =~ /\./ && $name !~ /\.(h|rh|hrh|inl|c|hpp)$/i)
    {
    # Not a file which contains APIs anyway
    $reason = "Wrong extension";
    return 0; # not public
    }

  open FILE, "<$file" or print "ERROR: Cannot open $file: $!\n" and return 1; # assume Public
  my @lines = <FILE>; # they are all of a modest size
  close FILE;
  
  my @includelines = grep /^\s*#include\s+/, @lines;
  my @includefiles = ();
  foreach my $includeline (@includelines)
    {
    if ($includeline =~ /^\s*#include\s+["<](.*\.([^.]+))[">]/)
      {
      my $filename = $1;
      my $extension = $2;
      
      # print "++ $filename ($extension)\n";
      if ($extension =~ /mbg|rsg|rls|ra/i)
        {
        # generated file referenced by #include
        push @includefiles, $filename; 
        print STDERR "** $file - $includeline";
        }
      }
    }
  
  my @apitaglines = grep /\@published|\@internal/, @lines;
  if (scalar @apitaglines == 0)
    {
    # no API classification tags - must be "Public by export" 
    $reason = "Public by export";
    }
  else
    {
    if ($debug)
      {
      print join("\n\t", $file, @apitaglines), "\n";
      }
    my @publishedAll = grep /\@publishedAll/, @apitaglines;
    if (scalar @publishedAll == 0)
      {
      # the API classification tags are all @publishedPartner or @internal
      $reason = "Platform by tag";
      return 0; # not public
      }
    # contains at least one @publishedAll element - must be "Public by tag"
    $reason = "Public by tag";
    }
  push @public_included, @includefiles;   # #included files are therefore also public
  return 1; # Public API
  }

my %classification;
my %origin;
my %ignoring_case;

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
      # print "PUBLIC\t$newname\t$reason\n";
      }
    else
      {
      # print "PARTNER\t$newname\t$reason\n";
      }
    $classification{$newname} = $reason;
    $origin{$newname} = "Symbian^2";
    $ignoring_case{lc $newname} = $newname;
    }
  }

scan_directory("/epoc32/include", "epoc32/include");

foreach my $file (@public_included)
  {
  # print "PUBLIC\tepoc32/include/$file\tIncluded\n";
  my $newname = "epoc32/include/$file";
  $newname = $ignoring_case{lc $newname};
  $classification{$newname} = "Public by Inclusion";
  }

# Read list of Symbian^1 files
my $line;
while ($line = <>)
  {
  chomp $line;
  $line =~ s/\\/\//g; # Unix separators please
  if ($line =~ /(epoc32\/include\/.*)\s*$/)
    {
    my $name = $1;
    $origin{$name} = "Symbian^1";
    if (!defined $ignoring_case{lc $name})
      {
      $classification{$name} = "Deleted";
      }
    }
  }

print "Filename\tClassification\tReason\tOrigin\n";
foreach my $file (sort keys %classification)
  {
  my $reason = $classification{$file};
  my $type = "Platform";
  $type = "Public" if ($reason =~ /Public/);
  print "$file\t$type\t$reason\t$origin{$file}\n";
  }