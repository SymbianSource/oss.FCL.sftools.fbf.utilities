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
# Convert comma-separated buglist into Mediawiki table
#
# Usage
# buglist_to_mediawiki bugreport.csv [--pdk=PDK_3.0.0] > bugs.mediawiki.txt

use strict;

use FindBin;
use lib "$FindBin::Bin\\..\\lib";
use Text::CSV;
use Getopt::Long;

my $PDK="PDK_???";

GetOptions((
	'pdk=s' => \$PDK,
));

my $csv = Text::CSV->new();

print "== Defects open at time of creation of $PDK ==\n\n";

print "{|\n";   # start of table

while (my $line = <>)
  {
  chomp $line;
  
  unless ($csv->parse($line))
  {
    my $err = $csv->error_input();
    warn "Failed to parse line '$line': $err\n";
    next;
  }

  my @columns = $csv->fields();
  
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
