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
# A quick and dirty perl script to take the generated 'changes.txt' from the BOM and wikify the FCL changes.



use strict;

my $file = shift @ARGV;
open(FILE, "<$file") or die "Coudln't open $file\n";
my $fcl = undef;
my $changeset = undef;
my $user = undef;
my $tag = "";
while(my $line = <FILE>)
{
  if($line =~ m/(\S+)(\/FCL\/\S+)/i)
  {
    my $codeline = $1;
    my $location = $2;
    my $root;
    $tag = "";

    if ($codeline =~ m/oss/i)
    {
      $root = "http://developer.symbian.org/oss" 
    }
    elsif($codeline =~ m/sfl/i)
    {
      $root = "https://developer.symbian.org/sfl" 
    }
    if (defined $fcl)
    {
      print "|}\n";
    }
    $fcl = $root.$location;

    my @bits = split ("\/",$location);
    my $packagename = pop @bits;
    $line = <FILE>; #grab next line 'cos it has the write location
    $line =~ s/\n//;
    $line =~ s/\///; #just the first one...
    
    print "==== ".$packagename." ([".$fcl." ".$line."]) ====\n";
    print "{|\n";
  }
  elsif($line =~ m/(\S+)(\/MCL\/\S+)/i)
  {
    if (defined $fcl)
    {
      print "|}\n";
    }
    undef $fcl;
  }
  elsif($line =~ m/^changeset:\s+\S+:(\S+)/)
  {
    #changeset:   118:c5817fd289ec
    $changeset = $1;
  }
  elsif($line =~ m/^user:\s+(\S.+)$/)
  {
    #changeset:   118:c5817fd289ec
    $user = $1;
  }
  elsif($line =~ m/^tag:\s+(\S+)/)
  {
    #changeset:   118:c5817fd289ec
    my $preprocessed = $1;
    $preprocessed =~ s/^tip$//g;
    if($preprocessed =~ m/\S+/)
    {
      $tag = $tag."\'\'\'".$preprocessed."\'\'\' ";
    }  
    
#    $tag = $1." ";
  }
  elsif( defined $fcl)
  {
    if($line =~ s/^summary:\s+//)
    {
      $line =~ s/\n//;
      my $bugzilla = "http:\/\/developer.symbian.org\/bugs\/show_bug.cgi?id=";
      $line =~ s/(bug\s*)(\d+)/\[$bugzilla$2 $1$2\]/gi;
      print "|[".$fcl."rev\/".$changeset." ".$changeset."]\n|".$tag.$line."\n|-\n";
#      print "|[".$fcl."rev\/".$changeset." ".$changeset."]\n|".$user."\n|".$line."\n|-\n";
    }
    #abort: unknown revision 'PDK_3.0.c'!
    elsif($line =~ m/^abort:\sunknown\srevision/i)
    {
      print "|\'\'\'TODO New FCL - fill in manually!!!\'\'\'\n";
    }
  }    
}
close FILE;