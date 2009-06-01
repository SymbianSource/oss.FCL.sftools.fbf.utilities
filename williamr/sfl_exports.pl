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
# Match list of "sfl" files in epoc32 tree with whatlog information

use strict;

my %sfl_files;
my $line;

while ($line = <>)
  {
  chomp $line;
  
  # output of findstr /m /s /C:"www.symbianfoundation.org/legal/sfl-v" epoc32\*
  # epoc32\data\z\private\101f7989\backup_registration.xml
  if ($line =~ /^epoc32/)
    {
    $line =~ s/\\/\//g;   # Unix directory separators please
    $sfl_files{$line} = "unknown";
    next;
    }
  
  # ..\/platform_MCL.PDK-3.8__winscw.whatlog_armv5.whatlog_multiple_threadWHAT_GT_tb91sf_compile.log(6824),
  # sf/os/boardsupport/emulator/emulatorbsp/bld.inf,
  # sf/os/boardsupport/emulator/emulatorbsp/specific/winscomm.h,
  # export,
  # epoc32/include/wins/winscomm.h,
  # h
  my ($log, $bldinf, $srcfile, $type, $epocfile, $extn) = split /,/, $line;

  if (defined $sfl_files{$epocfile})
    {
    if ($type eq "export")
      {
      # direct export - should be easy to fix
      $sfl_files{$epocfile} = $srcfile;
      next;
      }
    $sfl_files{$epocfile} = "generated - $type";
    next;
    }
  }

foreach my $epocfile (sort keys %sfl_files)
  {
  print "$epocfile\t$sfl_files{$epocfile}\n";
  }
