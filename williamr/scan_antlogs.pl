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
# Parse "ant" logs from SBS build to determine missing source files

my $pdk_src = "../.."; # path to sf tree - correct from "build/output"

my %missing_files;
my %damaged_components;
my %excluded_things;
my %damaged_bldinfs;

sub canonical_path($)
  {
  my ($path) = @_;
  my @bits = split /\//, $path;
  my @newbits = ();
  
  foreach my $bit (@bits)
    {
    next if ($bit eq ".");
    if ($bit eq "..")
      {
      pop @newbits;
      next;
      }
      push @newbits, $bit;
    }
  return join("/", @newbits);
  }

sub excluded_thing($$$)
  {
  my ($path, $missing, $reason) = @_;
  if (!defined $excluded_things{$path})
    {
    @{$excluded_things{$path}} = ();
    }
  push @{$excluded_things{$path}}, $missing;
  # print "Missing $missing from excluded $path ($reason)\n";
  }

sub do_missing_file($$$)
  {
  my ($missing, $missing_from, $reason) = @_;
  
  $missing = canonical_path($missing);
  $missing_from = canonical_path($missing_from);
  
  my $component = "??";
  if ($missing_from ne "??")
    {
    my @dirs = split /\//, $missing_from;
    shift @dirs if ($dirs[0] eq "sf");
    
    $path = $pdk_src . "/sf/$dirs[0]/$dirs[1]";
    if (!-e $path)
      {
      # no sign of the package
      excluded_thing($path, $missing, $reason);
      return;
      }
    $path .= "/$dirs[2]";
    if (!-e $path)
      {
      # no sign of the collection
      excluded_thing($path, $missing, $reason);
      return;
      }
    $path .= "/$dirs[3]";
    if (!-e $path)
      {
      # no sign of the component
      excluded_thing($path, $missing, $reason);
      return;
      }
    $component = join("/", $dirs[0], $dirs[1], $dirs[2], $dirs[3]);
    }
  
  $missing_files{$missing} = $reason if ($missing ne "??");
  
  if (!defined $damaged_components{$component})
    {
    @{$damaged_components{$component}} = ();
    }
  push @{$damaged_components{$component}}, $missing;
  }

sub scan_logfile($)
{
  my ($logfile) = @_;
  
  open FILE, "<$logfile" or print "Error: cannot open $logfile: $!\n" and return;
  
  my $line;
  while ($line = <FILE>)
    {
    # Source of export does not exist:  s:/sf/mw/messagingmw/messagingfw/msgtests/group/msgerr.ra
    # Source zip for export does not exist: s:/sf/os/deviceplatformrelease/S60LocFiles/data/96.zip
    if ($line =~ /Source (of|zip for) export does not exist.\s+.*\/(sf\/.*)$/)
      {
      do_missing_file($2, "??", "source of export");
      next;
      }
    # No bld.inf found at sf/os/buildtools/toolsandutils/burtestserver/Group in s:/output/build/canonical_system_definition_GT_tb91sf.xml
    # No bld.inf found at s:/sf/adaptation/stubs/licensee_tsy_stub/group in s:/output/build/canonical_system_definition_S60_5_1_clean.xml
    if ($line =~ /No bld.inf found at (.*\/)?(sf\/.*) in /i)
      {
      my $bldinf = "$2/bld.inf";
  
      do_missing_file($bldinf, $bldinf, "no bld.inf");
      $damaged_bldinfs{"$bldinf\t(missing)"} = 1;
      next;
      }
    # Can't find mmp file 'm:/sf/mw/mmmw/mmmiddlewarefws/mmfw/SoundDev/PlatSec/MMPFiles/Sounddevice/advancedaacencodesettingsci.mmp' referred to by 'm:/sf/mw/mmmw/mmmiddlewarefws/mmfw/SoundDev/group_pluginsupport/bld.inf'
    if ($line =~ /Can.t find mmp file .*(sf\/.*)' referred to by .*(sf\/.*)'/i)
      {
      my $mmpfile = $1;
      my $bldinf = $2;
  
      do_missing_file($mmpfile, $bldinf, "no mmp file");
      next;
      }
    # D:/Symbian/Tools/PDT_1.0/raptor/win32/mingw/bin/cpp.exe: s:/sf/os/networkingsrv/networksecurity/ipsec/group/bld.inf:19:42: ../eventmediator/group/bld.inf: No such file or directory
    if ($line =~ /cpp.exe: .*\/(sf\/[^:]*):.*\s+([^:]+): No such file/)
      {
      my $parent = $1;
      my $relative = $2;
  
      if ($parent =~ /\.inf$/i)
        {
        my $parent = canonical_path($parent);
        $damaged_bldinfs{"$parent\t$relative"} = 1;
        }
      do_missing_file("$parent/../$relative", $parent, "#include");
      next;  
      }
    # make.exe: *** No rule to make target `m:/sf/os/security/crypto/weakcrypto/source/symmetric/des.cpp', needed by `m:/epoc32/build/weakcrypto/c_126994d895f12d1a/weak_cryptography_dll/winscw/udeb/des.o'.
    if ($line =~ /No rule to make target .*(sf\/.*)', needed by .*(epoc32\/.*)'/)
      {
      my $missing = $1;
      my $impact = "building $2";
      # epoc32/build/weakcrypto/c_126994d895f12d1a/weak_cryptography_dll
      if ($impact =~ /epoc32\/build\/[^\/]+\/[^\/]+\/([^\/]+)\//)
        {
        $impact = "building $1";
        }
      do_missing_file($missing, "??", $impact);
      next;
      }
    }
    close FILE;
  }
  
  my @logfiles = map(glob,@ARGV);
  foreach my $logfile (@logfiles)
    {
    print "Scanning $logfile...\n";
    scan_logfile($logfile);
    }
  
  printf "%d Excluded things\n", scalar keys %excluded_things;
  foreach my $component (sort keys %excluded_things)
    {
    my @list = @{$excluded_things{$component}};
    my %hash;
    foreach my $missing (@list)
      {
      $hash{$missing} = 1;
      }
    printf "%s\t%d\n", $component, scalar keys %hash;
    print "\t", join("\n\t", sort keys %hash), "\n";
    }
  print "\nDamaged components\n";
  foreach my $component (sort keys %damaged_components)
    {
    my @list = @{$damaged_components{$component}};
    my %hash;
    foreach my $missing (@list)
      {
      $hash{$missing} = 1;
      }
    printf "%s\t%d\n", $component, scalar keys %hash;
    print "\t", join("\n\t", sort keys %hash), "\n";
    }
  print "\nMissing files\n";
  foreach my $missing (sort keys %missing_files)
    {
    my $reason = $missing_files{$missing};
    my @dirs = split /\//, $missing;
    my $path = shift @dirs;
    my $dir;
    
    while ($dir = shift @dirs)
      {
      if (-e "$pdk_src/$path/$dir")
        {
        # still exists at this point
        $path .= "/$dir";
        next;
        }
      print "\t$reason\t$path\t\t", join("/", $dir,@dirs), "\n";
      last;
      }    
    }
  
  print "\nDamaged bld.infs\n";
  print join("\n", sort keys %damaged_bldinfs, "");
  
  print "\n\n";
  printf "%d files missing from ", scalar keys %missing_files;
  printf "%d damaged components\n", scalar keys %damaged_components;
 