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
# Approximate "abld -what" from SBS Makefile.default and Makefile.export

use strict;
my $component = "";
my $mmp = "";
my $linkpath = "";
my $target = "";
my $targettype = "";
my $exports = "";

sub completed
  {
  if ($component ne "")
    {
    if ($exports eq "")
      {
      # Compilation makefile target
      print "$component\t$mmp\t$linkpath/$target.$targettype\n";
      }
    else
      {
      # export makefile
      my @exportpairs = split / /, $exports;
      foreach my $pair (@exportpairs)
        {
        my ($dest,$src) = split /<-/, $pair;
        $dest =~ s/^.:\///;
        print "$component\texport\t$dest\n";
        }
      }
    }
  $component = "";
  $mmp = "";
  $linkpath = "";
  $target = "";
  $targettype = "";
  $exports = "";
  }

sub scan_logfile($)
  {
  my ($logfile) = @_;
  
  open FILE, "<$logfile" or print "Error: cannot open $logfile: $!\n" and return;
  
  my $line;
  while ($line = <FILE>)
    {
    # COMPONENT_META:=s:/sf/os/boardsupport/emulator/emulatorbsp/bld.inf
    # PROJECT_META:=s:/sf/os/boardsupport/emulator/emulatorbsp/cakdwins.mmp
    # LINKPATH:=winscw/udeb
    # TARGET:=ekdata
    # TARGETTYPE:=dll
    # EXPORT:=s:/epoc32/tools/scanlog.pl<-s:/sf/os/buildtools/bldsystemtools/buildsystemtools/scanlog/scanlog.pl more...
    # MAKEFILE_LIST:=
    
    if ($line =~ /^(COMPONENT_META|PROJECT_META|LINKPATH|TARGET|REQUESTEDTARGETEXT|EXPORT|MAKEFILE_LIST):=(.*)$/o)
      {
      my $variable = $1;
      my $value = $2;
      
      if ($variable eq "MAKEFILE_LIST")
        {
        completed();
        next;
        }
      if ($variable eq "COMPONENT_META")
        {
        $component = $value;
        next;
        }
      if ($variable eq "PROJECT_META")
        {
        $mmp = $value;
        next;
        }
      if ($variable eq "LINKPATH")
        {
        $linkpath = $value;
        next;
        }
      if ($variable eq "TARGET")
        {
        $target = $value;
        next;
        }
      if ($variable eq "REQUESTEDTARGETEXT")
        {
        $targettype = $value;
        next;
        }
      if ($variable eq "EXPORT")
        {
        $exports = $value;
        next;
        }
      }
    }
    close FILE;
  }

  my @logfiles = map(glob,@ARGV);
  foreach my $logfile (@logfiles)
    {
    # print "Scanning $logfile...\n";
    scan_logfile($logfile);
    }
