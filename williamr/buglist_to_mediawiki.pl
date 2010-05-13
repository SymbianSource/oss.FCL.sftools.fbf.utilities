#! perl -w

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

print "{|\n";   # start of table

while (my $line = <>)
  {
  chomp $line;
  my @columns = split /\t/, $line;
  
  next if scalar @columns < 2;    # skip dubious looking lines
  
  if ($. == 1)
    {
    # First line of file = table headings
    my %preferredHeadings =
      (
      bug_id => "ID",
      bug_severity => "Severity",
      reporter => "Reporter",
      bug_status => "Status",
      product => "Package",
      short_desc => "Title",
      );
    @columns = map { $preferredHeadings{$_} || $_ } @columns;
    print "! ", join(" !! ", @columns), "\n";
    next;
    }

  # row with a bug id

  $columns[0] = "[http://developer.symbian.org/bugs/show_bug.cgi?id=$columns[0] Bug$columns[0]]";
  
  print "|-\n"; # row separator
  print "| ", join(" || ", @columns), "\n";
  }

print "|}\n";
