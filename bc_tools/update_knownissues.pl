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
#   This is a tool for adding BC issues to Known Issues list.
#

use strict;
use Getopt::Long;
use XML::Simple;
use Tie::File;

my $hdr_report;
my $lib_report;
my $ki_file;
my $current_report;
my $header_num;
my $issues_num;
my $n;
my $m;
my $offset;
my $counter;
my $file_name;
my $check_sum;
my $comment = "Issue closed as invalid by the PkO (Not a BC break)."; # This is a default comment that will be added to Known Issues list with each header file.
my $header_found;
my $library_found;
my $issue_found;
my $status;
my $line;
my @lines;
my $temp_ref;
my $temp_line;
my $temp_issues_num;
my $my_issue;
my $help;

sub usage($);
sub help();
sub usage_error();

my %optmap = (  'headers-report' => \$hdr_report,
			    'libraries-report' => \$lib_report,
			    'knownissues-file' => \$ki_file,
				'help' => \$help);

GetOptions(\%optmap,
          'headers-report=s',
          'libraries-report=s',
          'knownissues-file=s',
		  'help!') 
          or usage_error();

if ($help) {
	help();
}

# --headers-report is mandatory.
usage_error(), unless (defined($hdr_report) || defined($lib_report));

# --knownissues-file is mandatory.
usage_error(), unless (defined($ki_file));

# Open Known Isses file.
tie @lines, 'Tie::File', $ki_file or die ("Cannot tie file \"$ki_file\". $!\n");

if ($hdr_report) {
	# Parse the input XML into hashrefs.
	print "Parsing " . $hdr_report . "... ";
	$current_report = XMLin("./$hdr_report", keeproot => 1,
		forcearray => [ 'header', 'baselineversion', 'currentversion', 'timestamp', 'day', 'month', 'year', 'hour', 'minute', 'second', #
		'haversion', 'formatversion', 'cmdlineparms', 'parm', 'pname', 'pvalue', 'knownissuesversion', 'os', 'version', 'buildweek', 'issuelist',#
		'headerfile', 'filename', 'comparefilename', 'status', 'comment', 'issue', 'checksum', 'shortname', 'issueid', 'typeid', 'identityid', #
		'identitydescription', 'typestring', 'cause', 'documentation', 'ignoreinformation', 'linenumber', 'severity', 'scseverity'], keyattr => [] );
	print "complete \n";
	# Get number of header files.
	my $header_num = @{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'headerfile'}};
	print "Number of header files in the report: $header_num \n";

	$n = 0;
	while ($n < $header_num) {
		$file_name = $current_report->{'bbcresults'}->{'issuelist'}->[0]->{'headerfile'}->[$n]->{'shortname'}->[0];
		$check_sum = $current_report->{'bbcresults'}->{'issuelist'}->[0]->{'headerfile'}->[$n]->{'checksum'}->[0];
		$m = 0;
		$header_found = 0;
		$status = 0;
		foreach (@lines) { 
			if (@lines[$m] =~ "\"$file_name\"") { # Mark header file as present in the Known Issues file.
				$header_found = 1;
				$line = $m;
				last;
			}
			$m++;
		}
		if ($header_found) { # Ensure there is no duplicate in the Known Issues file.
			$m = 0;
			foreach (@lines) { 
				if (@lines[$m] =~ "checksum=\"$check_sum\"") { 
					$status = 1; # Means OK issue (already known).
					print "Duplicate found ($check_sum) for header file: $file_name\n";
					last;
				}
				$m++;
			}
		}
		if (($header_found) && (!($status))) { # Insert new version of header file.
			splice @lines, $line+1, 0, "    <version checksum=\"$check_sum\">";
			splice @lines, $line+2, 0, "      <status>OK<\/status>";
			splice @lines, $line+3, 0, "      <comment>$comment<\/comment>";
			splice @lines, $line+4, 0, "    <\/version>";
			print "New version ($check_sum) of header file: $file_name added to Known Issues list\n";
		}
		if (!($header_found)) { # Insert new header file.
			# Find the first occurrence of <headerfile>. - ASSUMPTION: at least one entry exists.
			$m = 0;
			foreach (@lines) { 
				if (@lines[$m] =~ "<headerfile") { 
					last; }
				else {
					$m++;
				}
			}
			splice @lines, $m, 0, "  <headerfile name=\"$file_name\">";
			splice @lines, $m+1, 0, "    <version checksum=\"$check_sum\">";
			splice @lines, $m+2, 0, "      <status>OK<\/status>";
			splice @lines, $m+3, 0, "      <comment>$comment<\/comment>";
			splice @lines, $m+4, 0, "    <\/version>";
			splice @lines, $m+5, 0, "  <\/headerfile>";
			print "Header file: $file_name ($check_sum) added to Known Issues list\n";
		}
		$n++;
	}
	# Free up memory resources.
	$current_report = ();
	print "OK\n";
}

if ($lib_report) {
	# Parse the input XMLs into hashrefs.
	print "Parsing " . $lib_report . "... ";
	$current_report = XMLin("./$lib_report", keeproot => 1,
		forcearray => [ 'header', 'baselineversion', 'currentversion', 'timestamp', 'day', 'month', 'year', 'hour', 'minute', 'second', #
		'laversion', 'formatversion', 'cmdlineparms', 'parm', 'pname', 'pvalue', 'knownissuesversion', 'os', 'version', 'buildweek', 'issuelist',#
		'library', 'name', 'comparefilename', 'shortname', 'baseplatform', 'currentplatform', 'issue', 'typeinfo', 'typeid', 'funcname', 'newfuncname', 'newfuncpos', #
		'bc_severity', 'sc_severity', 'status', 'comment', 'funcpos' ], keyattr => [] );
	print "complete \n";
	# Get number of libraries.
	my $lib_num = @{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}};
	print "Number of libraries in the report: $lib_num \n";
	
	$n = 0;
	while ($n < $lib_num) {
		$file_name = $current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}->[$n]->{'shortname'}->[0];
		# Check if library present in the Known Issues file.
		$m = 0;
		$library_found = 0;
		foreach (@lines) { 
			if (@lines[$m] =~ "\"$file_name\"") { # Mark header file as present in the Known Issues file.
				$library_found = 1;
				$line = $m;
				last;
			}
			$m++;
		}
		if ($library_found) { # Some entries already persent in the Known Issues file for the current library.
			print "Found library: $file_name in line: $line\n";
			$issues_num = @{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}->[$n]->{'issue'}};
			# Get library with all issues to $temp_ref;
			$m = $line - 1;
			$temp_line = "";
			do {
				$m++;
				$temp_line = $temp_line . @lines[$m];
			} while (@lines[$m] !~ "<\/library>");
			$temp_ref = XMLin($temp_line, keeproot => 1,
			forcearray => [ 'library', 'issue', 'typeid', 'typeinfo', 'funcname', 'newfuncname', 'funcpos', #
			'newfuncpos', 'bc_severity', 'sc_severity', 'status', 'comment' ], keyattr => [] );
			$temp_issues_num = @{$temp_ref->{'library'}->[0]->{'issue'}};
			# For each issue related to the current library check for a matching issue in $temp_ref.
			foreach $my_issue (@{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}->[$n]->{'issue'}}) {
				$issue_found = 0;
				$m = 0;
				while ($m < $temp_issues_num) {
					# Compare all possible values.
					if (($my_issue->{'typeid'}->[0] eq $temp_ref->{'library'}->[0]->{'issue'}->[$m]->{'typeid'}->[0]) &&
						($my_issue->{'typeinfo'}->[0] eq $temp_ref->{'library'}->[0]->{'issue'}->[$m]->{'typeinfo'}->[0]) &&
						($my_issue->{'funcname'}->[0] eq $temp_ref->{'library'}->[0]->{'issue'}->[$m]->{'funcname'}->[0]) &&
						($my_issue->{'newfuncname'}->[0] eq $temp_ref->{'library'}->[0]->{'issue'}->[$m]->{'newfuncname'}->[0]) &&
						($my_issue->{'funcpos'}->[0] eq $temp_ref->{'library'}->[0]->{'issue'}->[$m]->{'funcpos'}->[0]) &&
						($my_issue->{'newfuncpos'}->[0] eq $temp_ref->{'library'}->[0]->{'issue'}->[$m]->{'newfuncpos'}->[0]) &&
						($my_issue->{'bc_severity'}->[0] eq $temp_ref->{'library'}->[0]->{'issue'}->[$m]->{'bc_severity'}->[0]) &&
						($my_issue->{'sc_severity'}->[0] eq $temp_ref->{'library'}->[0]->{'issue'}->[$m]->{'sc_severity'}->[0]) &&
						($temp_ref->{'library'}->[0]->{'issue'}->[$m]->{'status'}->[0]) =~ "OK") {
						print "Duplicated issue found for library: $file_name\n";
						$issue_found = 1; # Do not add this issue to the Known Issues file.
						last;
					}
					$m++;
				}
				if (!$issue_found) { # Add the issue to the Known Issues file for exising library entry (as the top one).
					$offset = 1; # Initial offset value.
					splice @lines, $line+$offset, 0, "    <issue>"; $offset++;
					if ($my_issue->{'typeid'}->[0]) { splice @lines, $line+$offset, 0, "      <typeid>$my_issue->{'typeid'}->[0]<\/typeid>"; $offset++; }
					if ($my_issue->{'typeinfo'}->[0]) { splice @lines, $line+$offset, 0, "      <typeinfo>$my_issue->{'typeinfo'}->[0]<\/typeinfo>"; $offset++; }
					if ($my_issue->{'funcname'}->[0]) { 
						# Fix ampersand, greater-than and less-than characters before saving.
						$my_issue->{'funcname'}->[0] =~ s/&/&amp;/g;
						$my_issue->{'funcname'}->[0] =~ s/</&lt;/g;
						$my_issue->{'funcname'}->[0] =~ s/>/&gt;/g;
						splice @lines, $line+$offset, 0, "      <funcname>$my_issue->{'funcname'}->[0]<\/funcname>"; 
						$offset++;
					}
					if ($my_issue->{'newfuncname'}->[0]) { 
						# Fix ampersand, greater-than and less-than characters before saving.
						$my_issue->{'newfuncname'}->[0] =~ s/&/&amp;/g;
						$my_issue->{'newfuncname'}->[0] =~ s/</&lt;/g;
						$my_issue->{'newfuncname'}->[0] =~ s/>/&gt;/g;
						splice @lines, $line+$offset, 0, "      <newfuncname>$my_issue->{'newfuncname'}->[0]<\/newfuncname>";
						$offset++;
					}
					if ($my_issue->{'funcpos'}->[0]) { splice @lines, $line+$offset, 0, "      <funcpos>$my_issue->{'funcpos'}->[0]<\/funcpos>"; $offset++; }
					if ($my_issue->{'newfuncpos'}->[0]) { splice @lines, $line+$offset, 0, "      <newfuncpos>$my_issue->{'newfuncpos'}->[0]<\/newfuncpos>"; $offset++; }
					if ($my_issue->{'bc_severity'}->[0]) { splice @lines, $line+$offset, 0, "      <bc_severity>$my_issue->{'bc_severity'}->[0]<\/bc_severity>"; $offset++; }
					if ($my_issue->{'sc_severity'}->[0]) { splice @lines, $line+$offset, 0, "      <sc_severity>$my_issue->{'sc_severity'}->[0]<\/sc_severity>"; $offset++; }
					splice @lines, $line+$offset, 0, "      <status>OK<\/status>"; $offset++;
					splice @lines, $line+$offset, 0, "      <comment>$comment<\/comment>"; $offset++;
					splice @lines, $line+$offset, 0, "    <\/issue>";
					print "New issue added to Known Issues list for library: $file_name\n";
				}
			}
			$temp_ref = ();
		} else { # Add the whole new entry for the current library.
			# Find the first occurrence of <library>. - ASSUMPTION: at least one entry exists.
			$m = 0;
			foreach (@lines) { 
				if (@lines[$m] =~ "<library") { 
					last; }
				else {
					$m++;
				}
			}
			$offset = 0; # Initial offset value.
			splice @lines, $m+$offset, 0, "  <library name=\"$file_name\">"; $offset++;
			print "Library: $file_name added to Known Issues list\n";
			$counter = 1;
			foreach $my_issue (@{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}->[$n]->{'issue'}}) {	
				print "Adding issue: $counter... ";
				splice @lines, $m+$offset, 0, "    <issue>"; $offset++;
				if ($my_issue->{'typeid'}->[0]) { splice @lines, $m+$offset, 0, "      <typeid>$my_issue->{'typeid'}->[0]<\/typeid>"; $offset++; }
				if ($my_issue->{'typeinfo'}->[0]) { splice @lines, $m+$offset, 0, "      <typeinfo>$my_issue->{'typeinfo'}->[0]<\/typeinfo>"; $offset++; }
				if ($my_issue->{'funcname'}->[0]) { 
					# Fix ampersand, greater-than and less-than characters before saving.
					$my_issue->{'funcname'}->[0] =~ s/&/&amp;/g;
					$my_issue->{'funcname'}->[0] =~ s/</&lt;/g;
					$my_issue->{'funcname'}->[0] =~ s/>/&gt;/g;
					splice @lines, $m+$offset, 0, "      <funcname>$my_issue->{'funcname'}->[0]<\/funcname>"; 
					$offset++;
				}
				if ($my_issue->{'newfuncname'}->[0]) { 
					# Fix ampersand, greater-than and less-than characters before saving.
					$my_issue->{'newfuncname'}->[0] =~ s/&/&amp;/g;
					$my_issue->{'newfuncname'}->[0] =~ s/</&lt;/g;
					$my_issue->{'newfuncname'}->[0] =~ s/>/&gt;/g;
					splice @lines, $m+$offset, 0, "      <newfuncname>$my_issue->{'newfuncname'}->[0]<\/newfuncname>";
					$offset++;
				}
				if ($my_issue->{'funcpos'}->[0]) { splice @lines, $m+$offset, 0, "      <funcpos>$my_issue->{'funcpos'}->[0]<\/funcpos>"; $offset++; }
				if ($my_issue->{'newfuncpos'}->[0]) { splice @lines, $m+$offset, 0, "      <newfuncpos>$my_issue->{'newfuncpos'}->[0]<\/newfuncpos>"; $offset++; }
				if ($my_issue->{'bc_severity'}->[0]) { splice @lines, $m+$offset, 0, "      <bc_severity>$my_issue->{'bc_severity'}->[0]<\/bc_severity>"; $offset++; }
				if ($my_issue->{'sc_severity'}->[0]) { splice @lines, $m+$offset, 0, "      <sc_severity>$my_issue->{'sc_severity'}->[0]<\/sc_severity>"; $offset++; }
				splice @lines, $m+$offset, 0, "      <status>OK<\/status>"; $offset++;
				splice @lines, $m+$offset, 0, "      <comment>$comment<\/comment>"; $offset++;
				splice @lines, $m+$offset, 0, "    <\/issue>"; $offset++;
				print "done\n";
				$counter++;
			}
			splice @lines, $m+$offset, 0, "  <\/library>";
		}
		$n++;
	}
	# Free up memory resources.
	$current_report = ();
	print "OK\n";
}

untie @lines;

exit 0;

sub usage($)
{
    my $error = shift;
    my $fh = $error == 0 ? *STDOUT : *STDERR;
    print $fh "update_knownissues.pl\n" .
            "Specify the headers report or\/and libraries report and the known issues file\n" .
            "synopsis:\n" .
            "  update_knownissues.pl --help\n" .
            "  update_knownissues.pl [--headers-report=FILENAME1] [--libraries-report=FILENAME2] [--knownissues-file=FILENAME3] \n" .
            "options:\n" .
            "  --help                        Display this help and exit\n" .
            "  --headers-report=FILENAME1    FILENAME1 is the name of the filtered headers (sub-)report.\n" .
            "  --libraries-report=FILENAME2  FILENAME2 is the name of the filtered libraries report. This option is not implemented yet.\n" .
            "  --knownissues-file=FILENAME3  FILENAME3 is the name of the known issues file which will be updated.\n";
    exit $error;            
}

sub help()
{
    usage(0);
}

sub usage_error()
{
    usage(1);
}
