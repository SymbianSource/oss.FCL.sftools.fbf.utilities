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
# Perl script to summarise the R&D binaries listing

use strict;

my %grouped_by_basename;
my $line;

while ($line=<>)
  {
  # 2009-04-30 11:26:58 D....            0            0  epoc32\cshlpcmp_template
  # 2009-03-20 22:22:18 .....        72192        16307  epoc32\cshlpcmp_template\cshelp2000.dot
  
  next if (length($line) < 54);
  
  my $dir_attribute = substr($line, 20, 1);  
  if ($dir_attribute eq ".")
    {
    chomp $line;
    my $fullpath = substr($line, 53);
    my $filename = substr($fullpath, rindex($fullpath,"\\")+1);
    my $basename = lc substr($filename, 0, index($filename,"."));
    
    if ($basename =~ /^(.*){[0-9a-f]+}$/)
      {
      # import library
      $basename = $1;
      }
    elsif ($basename =~ /^(.*)_\d+$/)
      {
      # language variant in basename rather than extension
      $basename = $1;
      }
    elsif ($basename =~ /^(.*)_(aif|reg)$/)
      {
      # Uikon file grouping
      $basename = $1;
      }

    if (!defined $grouped_by_basename{$basename})
      {
      $grouped_by_basename{$basename} = ();
      }
    push @{$grouped_by_basename{$basename}}, $fullpath;
    next;
    }
  }

sub summarise_extensions(@)
  {
  my @files = @_;
  my $resources = 0;
  my $exes = 0;
  my $dlls = 0;
  my $libs = 0;
  my $maps = 0;
  my $headers = 0;
  my $others = 0;
  my %what_others;
  
  foreach my $file (@files)
    {
    my $extension = substr($file,rindex($file, "."));

    if ($extension =~ /^.r\d+$/io)
      {
      $what_others{".rNN"} += 1;
      next;
      }
    if ($extension =~ /^.o\d+$/io)
      {
      $what_others{".oNNNN"} += 1;
      next;
      }
    $what_others{$extension} += 1;
    }
  foreach my $extension (sort keys %what_others)
    {
    printf "%d %s, ", $what_others{$extension}, $extension;
    }
  print "\n";
  }

my $count = 0;
foreach my $basename (sort keys %grouped_by_basename)
  {
  my @files = @{$grouped_by_basename{$basename}};
  next if (! grep /winscw|tools/, @files);  # ignore ARMV5 only for now...
  printf "%6d\t%s\t", scalar @files, $basename;
  summarise_extensions(@files);
  $count++;
  }
printf "%d distinct missing basenames (from %d total)\n", $count, scalar keys %grouped_by_basename;
