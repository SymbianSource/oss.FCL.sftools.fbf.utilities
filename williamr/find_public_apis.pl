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

sub analyse_api($$$)
  {
  my ($file,$name,$includelistref) = @_;
  
  if ($name =~ /^epoc32\/include\/platform\//)
    {
    # /epoc32/include/platform files are "Platform by export"
    return "Platform by export";
    }
  
  if ($name =~ /\./ && $name !~ /\.(h|rh|hrh|inl|c|hpp)$/i)
    {
    # Not a file which contains APIs anyway
    return "Non-API extension";
    }

  open FILE, "<$file" or print "ERROR: Cannot open $file: $!\n" and return "Cannot open";
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
      if ($extension =~ /mbg|rsg/i)
        {
        # generated file referenced by #include
        push @{$includelistref}, $filename; 
        print STDERR "** $file - $includeline";
        }
      }
    }
  
  my @apitaglines = grep /\@published|\@internal/, @lines;
  if (scalar @apitaglines == 0)
    {
    # no API classification tags - must be "Public by export" 
    return "Public by export";
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
      return "Platform by tag";
      }
    # contains at least one @publishedAll element - must be "Public by tag"
    return "Public by tag";
    }
  }

# Process epoc32\include tree

my %rationale;
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
    
    $ignoring_case{lc $newname} = $newname;
    
    my @includefiles = ();
    my $reason = analyse_api($newpath,$newname, \@includefiles);

    $rationale{$newname} = $reason;
 
    if ($reason =~ /Public/)
      {
      push @public_included, @includefiles;   # #included files are therefore also public
      }
    }
  }

scan_directory("/epoc32/include", "epoc32/include");

# Add the generated files which are included in public API files

foreach my $file (@public_included)
  {
  # print "PUBLIC\tepoc32/include/$file\tIncluded\n";
  my $newname = "epoc32/include/$file";
  $newname = $ignoring_case{lc $newname};
  $rationale{$newname} = "Public by Inclusion";
  }

print "Filename\tClassification\tReason\n";
foreach my $file (sort keys %rationale)
  {
  my $reason = $rationale{$file};
  my $classification = "Platform";
  $classification = "Public" if ($reason =~ /Public/);
  print "$file\t$classification\t$reason\n";
  }