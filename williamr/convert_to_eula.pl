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
# Map the SFL license to the EULA license, keeping a copy of the original file
# in a parallel tree for creation of a "repair" kit to reinstate the SFL

use strict;
use File::Copy;
use File::Path;

my $debug = 0;

my @oldtext = (
  'terms of the License "Symbian Foundation License v1.0"',
  'the URL "http://www.symbianfoundation.org/legal/sfl-v10.html"'
);
my @newtext = (
  'terms of the License "Symbian Foundation License v1.0" to Symbian Foundation members and "Symbian Foundation End User License Agreement v1.0" to non-members',
  'the URL "http://www.symbianfoundation.org/legal/licencesv10.html"'
);

my @errorfiles = ();
my @multinoticefiles = ();

sub map_eula($$$)
  {
  my ($file,$shadowdir,$name) = @_;
  
  open FILE, "<$file" or print "ERROR: Cannot open $file: $!\n" and return "Cannot open";
  my @lines = <FILE>;
  close FILE;
  
  my $updated = 0;
  my @newlines = ();
  while (my $line = shift @lines)
    { 
    # under the terms of the License "Symbian Foundation License v1.0"
    # which accompanies this distribution, and is available
    # at the URL "http://www.symbianfoundation.org/legal/sfl-v10.html".
    my $pos1 = index $line, $oldtext[0];
    if ($pos1 >= 0)
      {
      # be careful - oldtext is a prefix of newtext!
      if (index($line, $newtext[0]) >= 0)
        {
        # line already converted - nothing to do
        push @newlines, $line;
        next;
        }
	  my @midlines = ();
      my $nextline;
	  my $midlinecount = 1;
	  while ($nextline = shift @lines)
		{
		if ($nextline !~ /^\s$/)
		  {
		  # non-blank line
		  last if ($midlinecount == 0);
		  $midlinecount -= 1;
		  # keep going
		  }
		push @midlines, $nextline;
		}
      my $urlline = $nextline;
      my $pos2 = index $urlline, $oldtext[1];
      if ($pos2 >= 0)
        {
        # Found it - assume that there's only one instance
        substr $line, $pos1, length($oldtext[0]), $newtext[0];
        substr $urlline, $pos2, length($oldtext[1]), $newtext[1];
        push @newlines, $line, @midlines, $urlline;
        $updated += 1;
        next;
        }
      else
        {
        if(!$updated)
          {
          my $lineno = 1 + (scalar @newlines);
          print STDERR "Problem in $file at $lineno: incorrectly formatted >\n$line", join("",@midlines), "$urlline\n";
          push @errorfiles, $file;
          }	
        last;
        }
      }
    push @newlines, $line;
    }

  return if (!$updated);
  
  if ($updated > 1)
    {
    push @multinoticefiles, $file;
    print "! found $updated SFL notices in $file\n";
    }
 
  mkpath($shadowdir, {verbose=>0});
  move($file, "$shadowdir/$name") or die("Cannot move $file to $shadowdir/$name: $!\n");
  open NEWFILE, ">$file" or die("Cannot overwrite $file: $!\n");
  print NEWFILE @newlines, @lines;
  close NEWFILE or die("Failed to update $file: $!\n");
  print "* updated $file\n";
  }

# Process tree

sub scan_directory($$)
  {
  my ($path, $shadow) = @_;
  
  return if lc $path eq "/epoc32/build";

  opendir DIR, $path;
  my @files = grep !/^\.\.?$/, readdir DIR;
  closedir DIR;
  
  foreach my $file (@files)
    {
    my $newpath = "$path/$file";
    my $newshadow = "$shadow/$file";
    
    if (-d $newpath)
      {
      scan_directory($newpath, $newshadow);
      next;
      }
    next if (-B $newpath);  # ignore binary files
    
    map_eula($newpath, $shadow, $file);
    }
  }

scan_directory("/epoc32", "/sfl_epoc32");

printf "%d problem files\n", scalar @errorfiles;
print "\t", join("\n\t", @errorfiles), "\n";

printf "%d files with multiple notices\n", scalar @multinoticefiles;
print "\t", join("\n\t", @multinoticefiles), "\n";

