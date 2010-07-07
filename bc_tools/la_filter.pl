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
use Getopt::Long;
use XML::Simple;
use Tie::File;

my $report;
my $xref_file;
my $destfile;
my $missing_destfile;
my $pkg_destfile;
my @lines;
my $line;
my $n;
my $m;
my $counter;
my $short_name;
my $del_ok_issues = 1; # This variable determines whether to delete OK issues first.
my $del_non_public = 1; # This variable determines whether to delete non-public API issues.
my $gen_missing_report = 0; # This variable determines whether to produce report for missing libraries.
my $issues_num;
my $issue_name;
my ($xref_name, $xref_type, $xref_line, $xref_hdr, $xref_def);
my $delete_node;
my @non_public_list;
my $current_item;
my $check_against_xref;
my $temp_lib_num;
my $temp_counter;
my $sub_reports = 0; # This variable determines whether to generate sub-reports per package.
my @lines_to_ignore = ("\\\\build\\\\", "\\\\compsupp\\\\", "\\\\uc_dll."); # This is the list of key words based on which a line potentially containing a package name will be ignored (skipped).
my @pkgs;
my $baselinedlldir;
my $lib_name;
my $map_name;
my $map_found;
my ($layer_name, $package_name);
my $pkg_found;
my $pkgs_num;
my $add_pkg;
my $nomap;
my $help;

sub usage($);
sub help();
sub usage_error();

my %optmap = (  'libraries-report' => \$report,
			    'xref-file' => \$xref_file,
			    'baseline-dll-dir' => \$baselinedlldir,
				'help' => \$help);

GetOptions(\%optmap,
          'libraries-report=s',
          'xref-file=s',
          'baseline-dll-dir=s',
		  'help!') 
          or usage_error();

if ($help) {
	help();
}

# --libraries-report is mandatory.
usage_error(), unless (defined($report));

# --xref-file is mandatory.
usage_error(), unless ((defined($xref_file)) or (!($del_non_public)));

# Define output files based on the libraries report name.
$destfile = "filtered_" . $report;
$missing_destfile = "missing_" . $report;

# Parse the input XMLs into hashrefs.
print "Parsing " . $report . "... ";
my $current_report = XMLin("./$report", keeproot => 1,
    forcearray => [ 'header', 'baselineversion', 'currentversion', 'timestamp', 'day', 'month', 'year', 'hour', 'minute', 'second', #
	'laversion', 'formatversion', 'cmdlineparms', 'parm', 'pname', 'pvalue', 'knownissuesversion', 'os', 'version', 'buildweek', 'issuelist',#
	'library', 'name', 'comparefilename', 'shortname', 'baseplatform', 'currentplatform', 'issue', 'typeinfo', 'typeid', 'funcname', 'newfuncname', 'newfuncpos', #
	'bc_severity', 'sc_severity', 'status', 'comment', 'funcpos' ], keyattr => [] );
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
if ($del_non_public) {
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
#				print "newfuncname - $issue_name \n";
			} elsif ($current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}->[$n]->{'issue'}->[$m]->{'funcname'}->[0]) {
				$issue_name = $current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}->[$n]->{'issue'}->[$m]->{'funcname'}->[0];
#				print "funcname - $issue_name \n";
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
#				print $issue_name . "\n";
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
					open FILE, "<$xref_file" or die("Failed to read $xref_file: $!\n");
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
#				print "Unclassified issue in $current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}->[$n]->{'shortname'}->[0] \n";
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
}

# Write new XML to dest file.
open OUT,">$destfile" or die("Cannot open file \"$destfile\" for writing. $!\n");
print OUT XMLout($current_report, keeproot => 1);
close OUT;

# Free up memory resources.
$current_report = ();

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
		'bc_severity', 'sc_severity', 'status', 'comment', 'funcpos' ], keyattr => [] );
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

if (($sub_reports) && ($gen_missing_report)) { # Generate sub-reports per package.
	# Parse the input XMLs into hashrefs again.
	print "Parsing " . $missing_destfile . "... ";
	my $current_report = XMLin("./$missing_destfile", keeproot => 1,
		forcearray => [ 'header', 'baselineversion', 'currentversion', 'timestamp', 'day', 'month', 'year', 'hour', 'minute', 'second', #
		'laversion', 'formatversion', 'cmdlineparms', 'parm', 'pname', 'pvalue', 'knownissuesversion', 'os', 'version', 'buildweek', 'issuelist',#
		'library', 'name', 'comparefilename', 'shortname', 'baseplatform', 'currentplatform', 'issue', 'typeinfo', 'typeid', 'funcname', 'newfuncname', 'newfuncpos', #
		'bc_severity', 'sc_severity', 'status', 'comment', 'funcpos' ], keyattr => [] );
	print "complete \n";
	$lib_num = @{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}};
	if (!defined($baselinedlldir)) { # Define baselinedlldir.
		$n = 0;
		foreach (@{$current_report->{'bbcresults'}->{'header'}->[0]->{'cmdlineparms'}->[0]->{'parm'}}) { # Find baselinedlldir.
			if ($current_report->{'bbcresults'}->{'header'}->[0]->{'cmdlineparms'}->[0]->{'parm'}->[$n]->{'pname'}->[0] eq "baselinedlldir") {
				$baselinedlldir = $current_report->{'bbcresults'}->{'header'}->[0]->{'cmdlineparms'}->[0]->{'parm'}->[$n]->{'pvalue'}->[0];
				last;
			}
			$n++;
		}
	}
	print "baselinedlldir: $baselinedlldir\n";
	# Create the list of packages that link to missing libraries and generate sub-report for no-map file libraries.
	$nomap = 0;
	$n = 0;
	while ($n < $lib_num) {
		$lib_name = $current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}->[$n]->{'shortname'}->[0];
		$map_name = $baselinedlldir . "\\" . $lib_name . ".map";
		$map_found = 1;
		# Find and open corresponding map file (.map or .dll.map).
		open (FILE, "<$map_name") or $map_name = $baselinedlldir . "\\" . $lib_name . ".dll.map" and open (FILE, "<$map_name") or print "No map file found for $lib_name\n" and $map_found = 0;
		if ($map_found) { 
#			print "Found: $map_name for $lib_name\n";
			$pkg_found = 0;
			while ($line = <FILE>)
			{
				chomp $line;
				# Get rid of spaces at the beginning.
				$line =~ s/^\s+//;
				if ($line =~ m/\\sf\\/) {
					$pkg_found = 1; # Package potentially found.
					# Check against lines_to_ignore.
					foreach $current_item (@lines_to_ignore) {
						if ($line =~ m/($current_item)/) { # Skip the line.
							$pkg_found = 0; # Change it back to not found.
							last;
						}
					}
				}
				if ($pkg_found) {
					# Get rid of \sf\ and the part it follows.
					$line =~ s/^.*\\sf\\//;
					# Get only the package name (in between \ and \).
					($layer_name, $package_name) = split /\\/,$line;
					print "Package: $package_name found for: $lib_name (based on $map_name)\n";
					$pkgs_num = @pkgs;
					if ($pkgs_num == 0) { # Add the first package name by default.
						push @pkgs, $package_name;
					} else {
						$add_pkg = 1;
						$m = 0;
						while ($m < $pkgs_num) {
							if ($package_name eq @pkgs[$m]) { # Do not add a new package name.
								$add_pkg = 0;
							}
							$m++;
						}
						if ($add_pkg) { # Add the new package name.
							push @pkgs, $package_name;
						}
					}
					last;
				}
			}
			close FILE;
			# Delete the node (to generate sub-report for libraries with no map file.
			splice(@{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}},$n, 1);
			$lib_num--;					
		} else {
			$nomap++;
			$n++;
		}
	}
	print "Number of libraries with no map file (most likely not a part of Public API): " . $nomap . "\n";
	if ($nomap > 0) { # Save sub-report for no-map file libraries.
		# Write new XML to dest file.
		$pkg_destfile = "missing_with_no_map_file_" . $report;
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
	foreach $current_item (@pkgs) {
	# Parse the input XMLs into hashrefs again.
		print "Parsing " . $missing_destfile . "... ";
		my $current_report = XMLin("./$missing_destfile", keeproot => 1,
			forcearray => [ 'header', 'baselineversion', 'currentversion', 'timestamp', 'day', 'month', 'year', 'hour', 'minute', 'second', #
			'laversion', 'formatversion', 'cmdlineparms', 'parm', 'pname', 'pvalue', 'knownissuesversion', 'os', 'version', 'buildweek', 'issuelist',#
			'library', 'name', 'comparefilename', 'shortname', 'baseplatform', 'currentplatform', 'issue', 'typeinfo', 'typeid', 'funcname', 'newfuncname', 'newfuncpos', #
			'bc_severity', 'sc_severity', 'status', 'comment', 'funcpos' ], keyattr => [] );
		print "complete \n";
		$lib_num = @{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}};
		$n = 0;
		print "Processing libraries for $current_item... ";
		while ($n < $lib_num) {
			$lib_name = $current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}->[$n]->{'shortname'}->[0];
			$map_name = $baselinedlldir . "\\" . $lib_name . ".map";
			$map_found = 1;
			# Find and open corresponding map file (.map or .dll.map).
			open (FILE, "<$map_name") or $map_name = $baselinedlldir . "\\" . $lib_name . ".dll.map" and open (FILE, "<$map_name") or $map_found = 0;
			if ($map_found) { 
				$pkg_found = 0;
				while ($line = <FILE>)
				{
					chomp $line;
					# Get rid of spaces at the beginning.
					$line =~ s/^\s+//;
					if ($line =~ m/\\sf\\/) {
						$pkg_found = 1; # Package potentially found.
						# Check against lines_to_ignore.
						foreach $current_item (@lines_to_ignore) {
							if ($line =~ m/($current_item)/) { # Skip the line.
								$pkg_found = 0; # Change it back to not found.
								last;
							}
						}
					}
					if ($pkg_found) {
						# Get rid of \sf\ and the part it follows.
						$line =~ s/^.*\\sf\\//;
						# Get only the package name (in between \ and \).
						($layer_name, $package_name) = split /\\/,$line;
						last;
					}
				}
				close FILE;
				if ($package_name ne $current_item) { # Remove the node from the report for the current package.
					splice(@{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}},$n, 1);
					$lib_num--;					
				} else {
					$n++;
				}
			} else { # Delete the node (library with no-map file).
				splice(@{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}},$n, 1);
				$lib_num--;					
			}
		}
		# Write new XML to dest file.
		$pkg_destfile = $current_item . "_" . $missing_destfile;
		open OUT,">$pkg_destfile" or die("Cannot open file \"$pkg_destfile\" for writing. $!\n");
		print OUT XMLout($current_report, keeproot => 1);
		close OUT;
		# Insert:	<?xml version="1.0" encoding="ASCII" standalone="no" ?>
		#			<?xml-stylesheet type="text/xsl" href="BBCResults.xsl"?>
		tie @lines, 'Tie::File', $pkg_destfile or die ("Cannot tie file \"$pkg_destfile\". $!\n");
		unshift @lines, "<?xml-stylesheet type=\"text/xsl\" href=\"BBCResults.xsl\"?>";
		unshift @lines, "<?xml version=\"1.0\" encoding=\"ASCII\" standalone=\"no\" ?>";
		untie @lines;
		print "complete \n";
		$lib_num = @{$current_report->{'bbcresults'}->{'issuelist'}->[0]->{'library'}};
		print "Number of missing libraries in $current_item package: $lib_num\n";
	}
}

exit 0;

sub usage($)
{
    my $error = shift;
    my $fh = $error == 0 ? *STDOUT : *STDERR;
    print $fh "la_filter.pl\n" .
            "Specify the libraries report and xref file\n" .
            "synopsis:\n" .
            "  la_filter.pl --help\n" .
            "  la_filter.pl [--libraries-report=XML_FILE] [--xref-file=TXT_FILE] [--baseline-dll-dir=PATH] \n" .
            "options:\n" .
            "  --help                        Display this help and exit.\n" .
            "  --libraries-report=XML_FILE   XML_FILE is the name of the libraries report xml file.\n" .
            "  --xref-file=TXT_FILE          TXT_FILE is the file containing the index of source code definitions generated by Ctags.\n" .
            "  --baseline-dll-dir=PATH       PATH is the full path to the directory containing map files (e.g. \\epoc32\\release\\armv5\\urel).\n" .
			"                                If not specified then the baselinedlldir param from the libraries report will be used.\n";
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
