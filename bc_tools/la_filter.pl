#!/usr/bin/perl

# Copyright (c) 2009 Symbian Foundation Ltd
# This component and the accompanying materials are made available
# under the terms of the License "Eclipse Public License v1.0"
# which accompanies this distribution, and is available
# at the URL "http://www.eclipse.org/legal/epl-v10.html".
#
# Initial Contributors:
# Symbian Foundation Ltd - initial contribution.
#	Maciej Seroka, maciejs@symbian.org
#
# Description:
#   This is a tool for filtering static BC libraries reports.

use strict;
use XML::Simple;
use File::Copy;
use Tie::File;
use Data::Dumper;

my $report;
my $xref_file;
my $destfile;
my $missing_destfile;
my @lines;
my $line;
my $n;
my $m;
my $counter;
my $short_name;
my $del_ok_issues = 1; # This variable determines whether to delete OK issues first.
my $gen_missing_report = 1; # This variable determines whether to produce report for missing libraries.
my $issues_num;
my $issue_name;
my $xref_name;
my $xref_type;
my $xref_line;
my $xref_hdr;
my $xref_def;
my $delete_node;
my @non_public_list;
my $current_item;
my $check_against_xref;
my $temp_lib_num;
my $temp_counter;

if ($ARGV[1]) {
	$report = $ARGV[0];
	$xref_file = $ARGV[1];
	$destfile = "filtered_" . $report;
	$missing_destfile = "missing_" . $report;
} else { 
	die "Missing parameter(s). For example: la_filter.pl libraries_report.xml my_xref_file.txt"; 
}

# Parse the input XMLs into hashrefs.
print "Parsing " . $report . "... ";
my $current_report = XMLin("./$report", keeproot => 1,
    forcearray => [ 'header', 'baselineversion', 'currentversion', 'timestamp', 'day', 'month', 'year', 'hour', 'minute', 'second', #
	'laversion', 'formatversion', 'cmdlineparms', 'parm', 'pname', 'pvalue', 'knownissuesversion', 'os', 'version', 'buildweek', 'issuelist',#
	'library', 'name', 'comparefilename', 'shortname', 'baseplatform', 'currentplatform', 'issue', 'typeinfo', 'typeid', 'funcname', 'newfuncname', 'newfuncpos', #
	'bc_severity', 'sc_severity', 'status', 'funcpos' ], keyattr => [] );
print "complete \n";

# Get number of libraries.
my $lib_num = @{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}};
print "Number of all libraries with issues: $lib_num \n";

# Delete known issues.
if ($del_ok_issues) {
	$n = 0;
	while ($n < $lib_num) {
		$issues_num = @{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}->[$n]->{'issue'}};
		$m = 0;
		while ($m < $issues_num) {
			if ($current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}->[$n]->{'issue'}->[$m]->{'status'}->[0]) { # I.e. if any status set (OK / _OK_).
				splice(@{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}->[$n]->{'issue'}},$m, 1);
				$issues_num--;
				print "Known issue in: $current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}->[$n]->{'shortname'}->[0] ...deleted\n";
			} else {
				$m++;
			}
		}
		if ($issues_num == 0) { # If all issues deleted - remove the whole entry.
			splice(@{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}},$n, 1);
			$lib_num--;
		} else {
			$n++;
		}	
	}
	# Get number of libraries again.
	$lib_num = @{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}};
	print "Number of remaining libraries with issues: $lib_num \n";
}

# Delete non-public API issues.
$n = 0;
$counter = 1;
$temp_counter = 0;
$temp_lib_num = $lib_num;
# Temporary variables - namespace fix.
my $count;
my $temp_issue;
while ($n < $lib_num) {
	print "Processing library: $current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}->[$n]->{'shortname'}->[0] ( $counter out of $temp_lib_num )\n";
	$issues_num = @{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}->[$n]->{'issue'}};
	$m = 0;
	while ($m < $issues_num) {
		$delete_node = 1;
		$issue_name = "";
		# Get issue name based on funcname or newfuncname (If both available get newfuncname).
		if ($current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}->[$n]->{'issue'}->[$m]->{'newfuncname'}->[0]) {
			$issue_name = $current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}->[$n]->{'issue'}->[$m]->{'newfuncname'}->[0];
#			print "newfuncname - $issue_name \n";
		} elsif ($current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}->[$n]->{'issue'}->[$m]->{'funcname'}->[0]) {
			$issue_name = $current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}->[$n]->{'issue'}->[$m]->{'funcname'}->[0];
#			print "funcname - $issue_name \n";
		}
		if ($issue_name) {
			# Leave only Class name - modified to fix namespace issue.
#			$issue_name =~ s/::.*//;
			# Find '(' and delete all characters following it.
			$issue_name =~ s/\(.*//;
			# Count the number of '::'.
			$count = () = $issue_name =~ /::/g;
			if ($count > 1) { # Means the following format: xx::yy::zz/
				# Get the 2nd part (yy).
				($temp_issue, $issue_name) = split /:+/,$issue_name;
			} else { # Means the following format: xx::yy
				# For 'non-virtual thunk to ' (always refering to a method) - 1st part should be left in.
				$issue_name =~ s/^non-virtual.* //; # Results in no more spaces left in the string.
				# For vtable/typeinfo issues like: typeinfo for CommsFW::TCFDeregisterHookSignal get rid of the 1st part.
				$issue_name =~ s/^.* .*:://; 
				# Leave only the 1st part (xx) for other issues.
				$issue_name =~ s/::.*//;
			}
			# Find '<' and delete all characters following it, e.g. TMeta<CommsDat
			$issue_name =~ s/<.*//;
			# Delete for example: 'typeinfo for ', 'vtable for ', etc. - will only be done for the likes of vtable for CTransportSelfSender (without '::').
			$issue_name =~ s/^.* //; 
#			print $issue_name . "\n";
			# Check if Class/Macro already on the internal non-public API list.
			$check_against_xref = 1;
			foreach $current_item (@non_public_list) {
				if (lc($issue_name) eq lc($current_item)) {	# Keep the node to be deleted and skip checking against the xref file.
					$check_against_xref = 0;
					last;
				}
			}
			if ($check_against_xref) {
				# Load xref file.
				open FILE, "<$xref_file" or print "Failed to read $xref_file: $!\n" and return;
				while ($line = <FILE>)
				{
					chomp $line;
					($xref_name, $xref_type, $xref_line, $xref_hdr, $xref_def) = split /\s+/,$line;
					if (lc($issue_name) eq lc($xref_name)) { # Mark the node to NOT be deleted.
						# Insert reference to header file.
						$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}->[$n]->{'issue'}->[$m]->{'refheaderfile'}->[0] = $xref_hdr;
						$delete_node = 0;
						print "Found issue: $issue_name in public header file: $xref_hdr\n";
						last;
					}
				}
				# Close xref file.
				close FILE;
			}
		} else { # No newfuncname/funcname available (e.g. typeinfo only for missing DLLs or typeid only for not shown ones).
#			print "Unclassified issue in $current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}->[$n]->{'shortname'}->[0] \n";
		}
		if ($delete_node) { # Delete the issue (Not public API-related).
			splice(@{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}->[$n]->{'issue'}},$m, 1);
			$issues_num--;
			if (($issue_name) && ($check_against_xref)) { # Looked for not found in the xref file - add the issue to the internal non-public API list.
				push @non_public_list, $issue_name;
			}
			$temp_counter++; # To count how many issues deleted.
		} else {
			$m++;
		}
	}
	if ($issues_num == 0) { # If all issues deleted - remove the whole entry.
		splice(@{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}},$n, 1);
		$lib_num--;
	} else {
		$n++;
	}
	$counter++;
}
print "$temp_counter issue(s) has been deleted \n";
# Get number of libraries again.
$lib_num = @{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}};
print "Final number of libraries with public API-related issues: $lib_num \n";

# Write new XML to dest file.
open OUT,">$destfile" or die("Cannot open file \"$destfile\" for writing. $!\n");
print OUT XMLout($current_report, keeproot => 1);
close OUT;

# Insert:	<?xml version="1.0" encoding="ASCII" standalone="no" ?>
#			<?xml-stylesheet type="text/xsl" href="BBCResults.xsl"?>
tie @lines, 'Tie::File', $destfile or die ("Cannot tie file \"$destfile\". $!\n");
unshift @lines, "<?xml-stylesheet type=\"text/xsl\" href=\"BBCResults.xsl\"?>";
unshift @lines, "<?xml version=\"1.0\" encoding=\"ASCII\" standalone=\"no\" ?>";
untie @lines;

# Produce report for missing libraries.
if ($gen_missing_report) {
	# Parse the input XMLs into hashrefs again.
	print "Parsing " . $report . "... ";
	my $current_report = XMLin("./$report", keeproot => 1,
		forcearray => [ 'header', 'baselineversion', 'currentversion', 'timestamp', 'day', 'month', 'year', 'hour', 'minute', 'second', #
		'laversion', 'formatversion', 'cmdlineparms', 'parm', 'pname', 'pvalue', 'knownissuesversion', 'os', 'version', 'buildweek', 'issuelist',#
		'library', 'name', 'comparefilename', 'shortname', 'baseplatform', 'currentplatform', 'issue', 'typeinfo', 'typeid', 'funcname', 'newfuncname', 'newfuncpos', #
		'bc_severity', 'sc_severity', 'status', 'funcpos' ], keyattr => [] );
	print "complete \n";
	print "Generating report for missing libraries... ";
	# Get number of libraries.
	$lib_num = @{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}};
	$n = 0;
	while ($n < $lib_num) {
		$issues_num = @{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}->[$n]->{'issue'}};
		$m = 0;
		$delete_node = 1;
		while ($m < $issues_num) {
			if (($current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}->[$n]->{'issue'}->[$m]->{'typeid'}->[0] eq "13") && #
				($current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}->[$n]->{'issue'}->[$m]->{'status'}->[0] ne "OK")) { 
					# If typeid=13 (DLL is missing in current SDK) and unknown issue - keep the node.
					$delete_node = 0;
					last;
				}
			$m++;
		}
		if ($delete_node) { # Remove the whole node (i.e. library).
			splice(@{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}},$n, 1);
			$lib_num--;
		} else {
			$n++;
		}
	}
	print "complete\n";
	# Get number of libraries again.
	$lib_num = @{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}};
	print "Number of missing libraries: $lib_num \n";

	# Write new XML to dest file.
	open OUT,">$missing_destfile" or die("Cannot open file \"$missing_destfile\" for writing. $!\n");
	print OUT XMLout($current_report, keeproot => 1);
	close OUT;

	# Insert:	<?xml version="1.0" encoding="ASCII" standalone="no" ?>
	#			<?xml-stylesheet type="text/xsl" href="BBCResults.xsl"?>
	tie @lines, 'Tie::File', $missing_destfile or die ("Cannot tie file \"$missing_destfile\". $!\n");
	unshift @lines, "<?xml-stylesheet type=\"text/xsl\" href=\"BBCResults.xsl\"?>";
	unshift @lines, "<?xml version=\"1.0\" encoding=\"ASCII\" standalone=\"no\" ?>";
	untie @lines;
}