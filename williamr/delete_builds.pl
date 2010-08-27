#! perl

# Copyright (c) 2010 Symbian Foundation Ltd
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
# Delete a directory full of builds, making space as quickly as possible by
# deleting known regions of massive files first

use strict;

# List directory subtrees containing mostly big files, biggest first
my @rich_pickings = (
  'output/zips',
  'output/logs',
  'epoc32/release/winscw/udeb'
  );
  
if (scalar @ARGV == 0)
  {
  print <<'EOF';
Usage: perl delete_builds.pl dir1 [dir2 ...]

Delete one or more builds, making free space as quickly as possible
by deleting a few selected directories first

You can use wildcards in the directory names, and they can be either
individual builds or directories of builds. A build is identified by
the present of an "output" subdirectory. 
EOF
  exit(1);
  }

my @builds = ();

@ARGV = map {glob} @ARGV;
foreach my $dir (@ARGV)
  {
  $dir =~ s/\\/\//g;  # unix separators
  $dir =~ s/\/+$//;   # remove trailing /
  if (!-d $dir)
    {
    print "Ignoring $dir - not a directory\n";
    next;
    }
  if (!-d "$dir/output")
    {
    print "Ignoring $dir - not a build\n";
    next;
    }
  push @builds, $dir;
  }

foreach my $subdir (@rich_pickings)
  {
  foreach my $build (@builds)
    {
    my $victim = "$build/$subdir";
    next if (!-d $victim);  # nothing to delete
    $victim =~ s/\//\\/g;   # windows separators again (sigh!)
    print "* rmdir /s/q $victim\n";
    system("rmdir","/s/q",$victim);
    }
  }

foreach my $build (@builds)
  {
  $build =~ s/\//\\/g;
  print "* rmdir /s/q $build";
  system("rmdir","/s/q",$build);   
  }
