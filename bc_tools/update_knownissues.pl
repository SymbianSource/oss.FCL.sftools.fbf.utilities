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
my $n;
my $m;
my $file_name;
my $check_sum;
my $comment = "Issue closed as invalid by the PkO (Not a BC break)."; # This is a default comment that will be added to Known Issues list with each header file.
my $header_found;
my $status;
my $line;
my @lines;
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
	print "OK\n";
}

if ($lib_report) {
	print "Warning: Automatic update of the Known Issues file based on a libraries report is not available in the current version of the script.\n"
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
