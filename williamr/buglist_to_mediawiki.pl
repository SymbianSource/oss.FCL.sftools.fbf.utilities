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
# Convert tab-separated buglist into Mediawiki table

use strict;

my $line;
my $header = 1;

while ($line =<>)
  {
  chomp $line;
  my @columns = split /\t/, $line;
  
  next if scalar @columns < 2;    # skip dubious looking lines
  
  if ($header)
    {
    print "{|\n";   # start of table
    print "! ", join(" !! ", @columns), "\n";
    $header = 0;
    next;
    }

  # row with a bug id
  my $id = shift @columns;
  $id = sprintf "[http://developer.symbian.org/bugs/show_bug.cgi?id=%s Bug %s]", $id, $id;
  unshift @columns, $id;   
  
  print "|-\n"; # row separator
  print "| ", join(" || ", @columns), "\n";
  }

print "|}\n";
