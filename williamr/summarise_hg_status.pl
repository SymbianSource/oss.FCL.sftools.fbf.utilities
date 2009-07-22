#! perl

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
# Summarise the "clone_all_packages.pl -exec -- hg status --rev a --rev b" output

use strict;

my %listings;
my $current_repo = "";
my @filelist = ();
my %all_repos;

sub record_file($$)
  {
  my ($file, $change) = @_;
  
  next if ($file eq ".hgtags");
  push @filelist, "$file$change";
  return;
  }

sub finished_repo()
  {
  if ($current_repo ne "")
    {
    $current_repo =~ s/^.*CL\/sf/sf/; # remove leading MCL or FCL stuff
    $all_repos{$current_repo} = 1;
    if (scalar @filelist > 0)
      {
      @{$listings{$current_repo}} = sort @filelist;
      # printf STDERR "* %s %d\n", $current_repo, scalar @filelist;
      }
    }
  @filelist = ();
  $current_repo = "";
  }
  
my $line;
while ($line = <>)
  {
  # Processing sfl/MCL/sf/app/imgvieweruis...
  if ($line =~ /^Processing (.*)\.\.\./)
    {
    finished_repo();
    $current_repo = $1;
    next;
    }
  # abort: unknown revision 'PDK_2.0.c'!
  if ($line =~ /^abort/)
    {
    # ignore the current repo, as it probably didn't have the right tag
    # $current_repo = "";
    next;
    }
  if ($line =~ /^([MARC]) (\S.*\S)\s*$/)
    {
    my $change = $1;
    my $file = $2;
    record_file($file, $change);
    next;
    }
  }

finished_repo();

foreach my $repo (sort keys %all_repos)
  {
  next if (defined $listings{$repo});
  print STDERR "No valid comparison for $repo\n";
  }

print "Package\tChange\tComponent\tFilename\tCount\n";
foreach my $repo (sort keys %listings)
  {
  my @filelist = @{$listings{$repo}};
  
  my $last_component = "";
  my @component_files = ();
  my @clean_files = ();
  my $clean_count = 0;
  my $component = "";
  
  foreach my $item (@filelist, ":boo:/:hoo:/:for:/:you:M")
    {
    my $change = substr($item,-1);
    my $file = substr($item,0,-1);
    my @names = split /\\/, $file;
    $component = "";
    if (scalar @names > 2)
      {
      my $collection = shift @names;
      $component = shift @names;
      $component = $collection . "/" . $component;
      }
    $file = join("/", @names);
    
    if ($component ne $last_component)
      {
      if (scalar @component_files > 0)
        {
        # previous component contained some A, M or R files
        print @component_files;
        } 
      if ($clean_count > 0)
        {
        print "$repo\tsame\t$last_component\t...\t$clean_count\n";
        }
      # reset, ready for next component;
      $last_component = $component;
      $clean_count = 0;
      @component_files = ();
      @clean_files = ();
      }
    if ($change eq "C")
      {
      $clean_count += 1;
      push @clean_files, "$repo\tsame\t$component\t$file\t1\n";
      }
    else
      {
      push @component_files, "$repo\t$change\t$component\t$file\t1\n";
      }
    } 
  }