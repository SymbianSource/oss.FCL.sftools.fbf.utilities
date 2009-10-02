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
# Map the SFL license to the EPL license, keeping a copy of the original file
# in a parallel tree 

use strict;
use File::Copy;
use File::Path;

if (scalar @ARGV != 2)
  {
	print <<'EOF';
Incorrect number of arguments

Usage: perl convert_to_epl.pl workdir savedir

Recursively processes workdir to examine all of the text files and convert
all perfectly formed instances of the SFL copyright notice into EPL notices.

If a file is modified, the original is first copied to the corresponding place
under savedir. 

It is safe to rerun this script if it stopped for any reason, as no converted 
SFL notice will ever match on the second run through.
EOF
  exit 1;
  }

my $work_root = $ARGV[0];
my $saved_root = $ARGV[1];

$work_root =~ s/\\/\//g;    # convert to Unix separators please
$saved_root =~ s/\\/\//g;

print "* Processing $work_root, leaving the original of any modified file in $saved_root\n";

my $debug = 0;

my @oldtext = (
  'terms of the License "Symbian Foundation License v1.0"',
  'the URL "http://www.symbianfoundation.org/legal/sfl-v10.html"'
);
my @newtext = (
  'terms of the License "Eclipse Public License v1.0"',
  'the URL "http://www.eclipse.org/legal/epl-v10.html"'
);

my @errorfiles = ();
my @multinoticefiles = ();

sub map_epl($$$)
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
      my $midline = shift @lines;
      my $urlline = shift @lines;
      my $pos2 = index $urlline, $oldtext[1];
      if ($pos2 >= 0)
        {
        # Found it - assume that there's only one instance
        substr $line, $pos1, length($oldtext[0]), $newtext[0];
        substr $urlline, $pos2, length($oldtext[1]), $newtext[1];
        push @newlines, $line, $midline, $urlline;
        $updated += 1;
        next;
        }
      else
        {
        if(!$updated)
          {
          my $lineno = 1 + (scalar @newlines);
          print STDERR "Problem in $file at $lineno: incorrectly formatted >\n$line$midline$urlline\n";
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
    
    map_epl($newpath, $shadow, $file);
    }
  }

scan_directory($work_root, $saved_root);

printf "%d problem files\n", scalar @errorfiles;
print "\t", join("\n\t", @errorfiles), "\n";

printf "%d files with multiple notices\n", scalar @multinoticefiles;
print "\t", join("\n\t", @multinoticefiles), "\n";

