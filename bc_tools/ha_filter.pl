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
#   This is a tool for filtering static BC header reports.
#

use strict;
use Getopt::Long;
use XML::Simple;
use Tie::File;

my $report;
my $header_list;
my $destfile;
my $pkg_destfile;
my $del_ok_issues = 1; # This variable determines whether to delete OK issues first.
my $del_comp_issues = 1; # This variable determines whether to delete Compilation errors.
my $del_boost_issues = 0; # This variable determines whether to delete issues for Boost API headers.
my $tsv_file; # If defined then sub-reports per package will be generated.
my $n;
my $m;
my $p;
my $file_name;
my $type_id;
my $identity_description;
my $delete_node;
my @lines;
my $line;
my @pkgs;
my $nopkg;
my $pkgs_num;
my ($hdr_to_pkg, $package);
my $pkg_found;
my $add_pkg;
my $temp_report;
my $current_pkg;
my $help;

sub usage($);
sub help();
sub usage_error();

my %optmap = (  'headers-report' => \$report,
			    'public-api-list' => \$header_list,
			    'xref-file' => \$tsv_file,
				'help' => \$help);

GetOptions(\%optmap,
          'headers-report=s',
          'public-api-list=s',
          'xref-file=s',
		  'help!') 
          or usage_error();

if ($help) {
	help();
}

# --headers-report is mandatory.
usage_error(), unless (defined($report));

# --public-headers is mandatory.
usage_error(), unless (defined($header_list));

# Define output file based on the headers report name.
$destfile = "filtered_" . $report;

# Parse the input XML into hashrefs.
print "Parsing " . $report . "... ";
my $current_report = XMLin("./$report", keeproot => 1,
    forcearray => [ 'header', 'baselineversion', 'currentversion', 'timestamp', 'day', 'month', 'year', 'hour', 'minute', 'second', #
	'haversion', 'formatversion', 'cmdlineparms', 'parm', 'pname', 'pvalue', 'knownissuesversion', 'os', 'version', 'buildweek', 'issuelist',#
	'headerfile', 'filename', 'comparefilename', 'status', 'comment', 'issue', 'checksum', 'shortname', 'issueid', 'typeid', 'identityid', #
	'identitydescription', 'typestring', 'cause', 'documentation', 'ignoreinformation', 'linenumber', 'severity', 'scseverity', 'compilationerror'], keyattr => [] );
print "complete \n";

# Get number of header files.
my $header_num = @{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'headerfile'}};
print "Number of all header files with issues: $header_num \n";

# Delete known issues.
if ($del_ok_issues) {
	$n = 0;
	while ($n < $header_num) {
		$file_name = $current_report->{'bbcresults'}->{'issuelist'}->[0]->{'headerfile'}->[$n]->{'shortname'}->[0];
		# Delete the node if known issue.
		if ($current_report->{'bbcresults'}->{'issuelist'}->[0]->{'headerfile'}->[$n]->{'status'}->[0] eq "OK") {
			print "Known issue: $file_name ...deleted\n";
			splice(@{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'headerfile'}},$n, 1);
			$header_num--;
		} else {
#			print "Unknown issue: $file_name \n";
			$n++;
		}
	}
	# Get number of header files again.
	$header_num = @{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'headerfile'}};
	print "Number of remaining header files with issues: $header_num \n";
}

# Delete compilation issues.
# Assumption: Compilation issue is always the top issue (and probably the only one)
if ($del_comp_issues) {
	$n = 0;
	while ($n < $header_num) {
		$file_name = $current_report->{'bbcresults'}->{'issuelist'}->[0]->{'headerfile'}->[$n]->{'shortname'}->[0];
		if (($current_report->{'bbcresults'}->{'issuelist'}->[0]->{'headerfile'}->[$n]->{'issue'}->[0]->{'typestring'}->[0] eq "has compilation errors") && #
			($current_report->{'bbcresults'}->{'issuelist'}->[0]->{'headerfile'}->[$n]->{'status'}->[0] ne "OK")) { # Delete the node if compilation error.
			print "$file_name has compilation errors \n";
			splice(@{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'headerfile'}},$n, 1);
			$header_num--;
		} else {
			$n++;
		}
	}
	# Get number of header files again
	$header_num = @{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'headerfile'}};
	print "Number of header files with non-compilation issues: $header_num \n";
}

# Delete Boost API related issues (Boost API headers are not present in any of the Public SDK!).
if ($del_boost_issues) {
	$n = 0;
	while ($n < $header_num) {
		$file_name = $current_report->{'bbcresults'}->{'issuelist'}->[0]->{'headerfile'}->[$n]->{'shortname'}->[0];
		# Delete the node if Boost API header.
		if ($file_name =~ m/\\boost/) {
			print "Boost API: $file_name \n";
			splice(@{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'headerfile'}},$n, 1);
			$header_num--;
		} else {
			$n++;
		}
	}
	# Get number of header files again.
	$header_num = @{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'headerfile'}};
	print "Number of non-Boost API header files: $header_num \n";
}

# Delete non-public API issues.
$n = 0;
while ($n < $header_num) {
	$file_name = $current_report->{'bbcresults'}->{'issuelist'}->[0]->{'headerfile'}->[$n]->{'shortname'}->[0];
	$delete_node = 1;
	# Load Public API definitions.
	open FILE, "<$header_list" or die("Failed to read $header_list: $!\n");
	while ($line = <FILE>) { # Check against header list.
		chomp $line;
		if (lc($file_name) eq lc($line)) {	# Mark the node to NOT be deleted.
			$delete_node = 0;
			last;
		}
	}
	# Close Public API definition file.
	close FILE;
	# Delete the node if non-public issue.
	if ($delete_node) {
		print "Header file: $file_name not found in Public API definition file... deleted\n";
		splice(@{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'headerfile'}},$n, 1);
		$header_num--;
	} else {
		$n++;
	}
}

# Get number of header files again.
$header_num = @{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'headerfile'}};
print "Final number of header files with issues: $header_num \n";

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

if (defined($tsv_file)) { # Generate sub-reports per package.
	# Create the list of packages that link to remaining header files and generate sub-report for Removed header files.
	$nopkg = 0;
	$n = 0;
	while ($n < $header_num) {
		$file_name = $current_report->{'bbcresults'}->{'issuelist'}->[0]->{'headerfile'}->[$n]->{'shortname'}->[0];
		$type_id = $current_report->{'bbcresults'}->{'issuelist'}->[0]->{'headerfile'}->[$n]->{'issue'}->[0]->{'typeid'}->[0];
		$identity_description = $current_report->{'bbcresults'}->{'issuelist'}->[0]->{'headerfile'}->[$n]->{'issue'}->[0]->{'identitydescription'}->[0];
		$pkg_found = 0;
		open FILE, "<$tsv_file" or die("Failed to read $tsv_file: $!\n");
		while ($line = <FILE>)
		{
			chomp $line;
			($hdr_to_pkg,$package) = split /\t/,$line;
			$hdr_to_pkg =~ s/\//\\/g;
			$hdr_to_pkg =~ s/\\epoc32\\include\\//;
			if ((lc($file_name) eq lc($hdr_to_pkg)) && (!(($type_id eq "0") && ($identity_description eq "File")))) {
				print "Package found: $package for header file: $file_name \n";
				$pkg_found = 1;
				$pkgs_num = @pkgs;
				if ($pkgs_num == 0) { # Add the first package name by default.
					push @pkgs, $package;
				} else {
					$add_pkg = 1;
					$p = 0;
					while ($p < $pkgs_num) {
						if ($package eq @pkgs[$p]) { # Do not add a new package name.
							$add_pkg = 0; 
						}
						$p++;
					}
					if ($add_pkg) { # Add the new package name.
						push @pkgs, $package;
					}
				}
				last;
			}
		}
		close FILE;
		if ($pkg_found == 0) {
			print "Removed header file: $file_name \n";
			$nopkg++;
			$n++;
		} else { # Delete the node.
			splice(@{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'headerfile'}},$n, 1);
			$header_num--;				
		}
	}
	print "Number of removed header files: " . $nopkg . "\n";
	if ($nopkg > 0) { # Save sub-report for removed header files.
		# Write new XML to dest file.
		$pkg_destfile = "removed_" . $report;
		open OUT,">$pkg_destfile" or die("Cannot open file \"$pkg_destfile\" for writing. $!\n");
		print OUT XMLout($current_report, keeproot => 1);
		close OUT;
		# Insert:	<?xml version="1.0" encoding="ASCII" standalone="no" ?>
		#			<?xml-stylesheet type="text/xsl" href="BBCResults.xsl"?>
		tie @lines, 'Tie::File', $pkg_destfile or die ("Cannot tie file \"$pkg_destfile\". $!\n");
		unshift @lines, "<?xml-stylesheet type=\"text/xsl\" href=\"BBCResults.xsl\"?>";
		unshift @lines, "<?xml version=\"1.0\" encoding=\"ASCII\" standalone=\"no\" ?>";
		untie @lines;
	}
	print "Number of packages: " . @pkgs . "\n";
	# Generate sub reports for all packages.
	foreach $current_pkg (@pkgs) {
		# Parse the stripped input XML into hashrefs.
		print "Parsing " . $destfile . "... ";
		$temp_report = XMLin("./$destfile", keeproot => 1,
		 forcearray => [ 'header', 'baselineversion', 'currentversion', 'timestamp', 'day', 'month', 'year', 'hour', 'minute', 'second', #
		 'haversion', 'formatversion', 'cmdlineparms', 'parm', 'pname', 'pvalue', 'knownissuesversion', 'os', 'version', 'buildweek', 'issuelist',#
		 'headerfile', 'filename', 'comparefilename', 'status', 'comment', 'issue', 'checksum', 'shortname', 'issueid', 'typeid', 'identityid', #
		 'identitydescription', 'typestring', 'cause', 'documentation', 'ignoreinformation', 'linenumber', 'severity', 'scseverity', 'compilationerror'], keyattr => [] );
		print "complete \n";
		$n = 0;
		$header_num = @{$temp_report->{'bbcresults'}->{'issuelist'}->[0]->{'headerfile'}};
		print "Processing header files for $current_pkg... \n";
		while ($n < $header_num) {
			$file_name = $temp_report->{'bbcresults'}->{'issuelist'}->[0]->{'headerfile'}->[$n]->{'shortname'}->[0];
			$type_id = $temp_report->{'bbcresults'}->{'issuelist'}->[0]->{'headerfile'}->[$n]->{'issue'}->[0]->{'typeid'}->[0];
			$identity_description = $temp_report->{'bbcresults'}->{'issuelist'}->[0]->{'headerfile'}->[$n]->{'issue'}->[0]->{'identitydescription'}->[0];
			$pkg_found = 0;
			open FILE, "<$tsv_file" or die("Failed to read $tsv_file: $!\n");
			while ($line = <FILE>)
			{
				chomp $line;
				($hdr_to_pkg,$package) = split /\t/,$line;
				$hdr_to_pkg =~ s/\//\\/g;
				$hdr_to_pkg =~ s/\\epoc32\\include\\//;	
				if ((lc($file_name) eq lc($hdr_to_pkg)) && ($current_pkg eq $package) && (!(($type_id eq "0") && ($identity_description eq "File")))) {
					$pkg_found = 1;
					print "$file_name added to $package \n";
				}
			}
			close FILE;
			if ($pkg_found == 0) {
				splice(@{$temp_report->{'bbcresults'}->{'issuelist'}->[0]->{'headerfile'}},$n, 1);
				$header_num--;		
			} else {
				$n++
			}
		}
		$header_num = @{$temp_report->{'bbcresults'}->{'issuelist'}->[0]->{'headerfile'}};
		print "Number of header files for $current_pkg: $header_num \n";
		# Write new XML to dest file.
		$pkg_destfile = $current_pkg . "_" . $report;
		open OUT,">$pkg_destfile" or die("Cannot open file \"$pkg_destfile\" for writing. $!\n");
		print OUT XMLout($temp_report, keeproot => 1);
		close OUT;
		# Insert:	<?xml version="1.0" encoding="ASCII" standalone="no" ?>
		#			<?xml-stylesheet type="text/xsl" href="BBCResults.xsl"?>
		tie @lines, 'Tie::File', $pkg_destfile or die ("Cannot tie file \"$pkg_destfile\". $!\n");
		unshift @lines, "<?xml-stylesheet type=\"text/xsl\" href=\"BBCResults.xsl\"?>";
		unshift @lines, "<?xml version=\"1.0\" encoding=\"ASCII\" standalone=\"no\" ?>";
		untie @lines;
	}
}

exit 0;

sub usage($)
{
    my $error = shift;
    my $fh = $error == 0 ? *STDOUT : *STDERR;
    print $fh "ha_filter.pl\n" .
            "Specify the headers report and public API list\n" .
            "synopsis:\n" .
            "  ha_filter.pl --help\n" .
            "  ha_filter.pl [--headers-report=XML_FILE] [--public-api-list=TXT_FILE] [--xref-file=TSV_FILE] \n" .
            "options:\n" .
            "  --help                        Display this help and exit.\n" .
            "  --headers-report=XML_FILE     XML_FILE is the name of the headers report xml file.\n" .
            "  --public-api-list=TXT_FILE    TXT_FILE is the file containing the list of public header files.\n" .
            "  --xref-file=TSV_FILE          TSV_FILE is the file containing the index of header files linked to packages generated by summarise_tsv.pl.\n";
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
