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
# Unite and HTML-ize Raptor log files

use strict;
use FindBin;
use lib $FindBin::Bin;
use RaptorError;
use RaptorWarning;
use RaptorInfo;
use RaptorUnreciped;
use RaptorRecipe;

use XML::SAX;
use RaptorSAXHandler;
use Getopt::Long;

our $raptorbitsdir = 'raptorbits';
our $basedir = '';
my $outputdir = "html";
our $raptor_config = 'dummy_config';
our $current_log_file = '';
my $help = 0;
GetOptions((
	'basedir=s' => \$basedir,
	'help!' => \$help
));
my @logfiles = @ARGV;

$help = 1 if (!@logfiles);

if ($help)
{
	print "Unite and HTML-ize Raptor log files.\n";
	print "Usage: perl uh.pl [OPTIONS] FILE1 FILE2 ...\n";
	print "where OPTIONS are:\n";
	print "\t--basedir=DIR Generate output under DIR (defaults to current dir)\n";
	exit(0);
}

if ($basedir)
{
	$raptorbitsdir = "$basedir/raptorbits";
	$outputdir = "$basedir/html";
}
mkdir($basedir) if (!-d$basedir);

$raptorbitsdir =~ s,/,\\,g; # this is because rmdir doens't cope correctly with the forward slashes

system("rmdir /S /Q $raptorbitsdir") if (-d $raptorbitsdir);
mkdir($raptorbitsdir);
#print "Created dir $raptorbitsdir.\n";

# create empty summary file anyway
open(SUMMARY, ">$raptorbitsdir/summary.csv");
close(SUMMARY);

my $saxhandler = RaptorSAXHandler->new();
$saxhandler->add_observer('RaptorError', $RaptorError::reset_status);
$saxhandler->add_observer('RaptorWarning', $RaptorWarning::reset_status);
$saxhandler->add_observer('RaptorInfo', $RaptorInfo::reset_status);
$saxhandler->add_observer('RaptorUnreciped', $RaptorUnreciped::reset_status);
$saxhandler->add_observer('RaptorRecipe', $RaptorRecipe::reset_status);

our $allbldinfs = {};

my $parser = XML::SAX::ParserFactory->parser(Handler=>$saxhandler);
for (@logfiles)
{
	print "Reading file: $_\n";
	$current_log_file = $_;
	$parser->parse_uri($_);
}

my @allpackages = distinct_packages($allbldinfs);

print "Generating HTML...\n";

system("rd /S /Q $outputdir") if (-d $outputdir);
mkdir ($outputdir);

my $raptor_errors = {};
my $raptor_warnings = {};
my $raptor_unreciped = {};
my $general_failures_num_by_severity = {};
my $general_failures_by_category_severity = {};
my $recipe_failures_num_by_severity = {};
my $recipe_failures_by_package_severity = {};
#my $severities = {};
my @severities = ('critical', 'major', 'minor', 'unknown');

# READ SUMMARY.CSV FILE
my $csv_file = "$raptorbitsdir/summary.csv";
my $csv_linenum = 0;
open(CSV, $csv_file);
while(<CSV>)
{
	$csv_linenum ++;
	my $line = $_;
	
	if ($line =~ /([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*)/)
	{
		my $failure = {};
		$failure->{category} = $1;
		$failure->{subcategory} = $2;
		$failure->{severity} = $3;
		$failure->{config} = $4;
		$failure->{component} = $5;
		$failure->{mmp} = $6;
		$failure->{phase} = $7;
		$failure->{recipe} = $8;
		$failure->{file} = $9;
		$failure->{linenum} = $10;
		
		my $failure_package = '';
		
		if (!$failure->{category})
		{
			print "WARNING: summary line without a category at $csv_file line $csv_linenum. Skipping\n";
			next;
		}
		
		if ($failure->{category} =~ m,^recipe_failure$,i and !$failure->{component})
		{
			print "WARNING: recipe_failure with component field empty at $csv_file line $csv_linenum. Skipping\n";
			next;
		}
		if ($failure->{component})
		{
			if ($failure->{component} =~ m,/((os|mw|app|tools|ostools|adaptation)/[^/]*),)
			{
				$failure_package = $1;
			}
			else
			{
				print "WARNING: summary line with wrong component path at $csv_file line $csv_linenum. Skipping\n";
				next;
			}
		}
		
		$failure->{subcategory} = 'uncategorized' if (!$failure->{subcategory});
		$failure->{severity} = 'unknown' if (!$failure->{severity});
		$failure->{mmp} = '-' if (!$failure->{mmp});
		
		# populate severities dynamically.
		#$severities->{$failure->{severity}} = 1;
		
		# put failure items into their category container
		if ($failure->{category} =~ /^raptor_(error|warning|unreciped)$/i)
		{
			$general_failures_num_by_severity->{$failure->{category}} = {} if (!defined $general_failures_num_by_severity->{$failure->{category}});
			my $general_failure = $general_failures_num_by_severity->{$failure->{category}};
			
			if (!defined $general_failure->{$failure->{severity}})
			{
				$general_failure->{$failure->{severity}} = 1;
			}
			else
			{
				$general_failure->{$failure->{severity}} ++;
			}
			
			$general_failures_by_category_severity->{$failure->{category}} = {} if (!defined $general_failures_by_category_severity->{$failure->{category}});
			$general_failures_by_category_severity->{$failure->{category}}->{$failure->{severity}} = [] if (!defined $general_failures_by_category_severity->{$failure->{category}}->{$failure->{severity}});
			push(@{$general_failures_by_category_severity->{$failure->{category}}->{$failure->{severity}}}, $failure);
		}
		elsif ($failure->{category} =~ /^recipe_failure$/i)
		{
			$recipe_failures_num_by_severity->{$failure_package} = {} if (!defined $recipe_failures_num_by_severity->{$failure_package});
			my $package_failure = $recipe_failures_num_by_severity->{$failure_package};
			
			if (!defined $package_failure->{$failure->{severity}})
			{
				$package_failure->{$failure->{severity}} = 1;
			}
			else
			{
				$package_failure->{$failure->{severity}} ++;
			}
			
			$recipe_failures_by_package_severity->{$failure_package} = {} if (!defined $recipe_failures_by_package_severity->{$failure_package});
			$recipe_failures_by_package_severity->{$failure_package}->{$failure->{severity}} = [] if (!defined $recipe_failures_by_package_severity->{$failure_package}->{$failure->{severity}});
			push(@{$recipe_failures_by_package_severity->{$failure_package}->{$failure->{severity}}}, $failure);
		}
	}
	else
	{
		print "WARNING: line does not match expected format at $csv_file line $csv_linenum. Skipping\n";
	}
}
close(CSV);

# PRINT HTML SUMMARY
my $aggregated_html = "$outputdir/index.html";
open(AGGREGATED, ">$aggregated_html");
print AGGREGATED "RAPTOR BUILD SUMMARY<br/>\n";

print AGGREGATED "<br/>GENERAL FAILURES<br/>\n";
print AGGREGATED "<table border='1'>\n";
my $tableheader = "<tr><th>category</th>";
for (@severities) { $tableheader .= "<th>$_</th>"; }
$tableheader .= "</tr>";
print AGGREGATED "$tableheader\n";
for my $category (keys %{$general_failures_num_by_severity})
{
	print_category_specific_summary($category, $general_failures_by_category_severity->{$category});
	my $categoryline = "<tr><td><a href='$category.html'>$category</a></td>";
	for (@severities)
	{
		my $failuresbyseverity = 0;
		$failuresbyseverity = $general_failures_num_by_severity->{$category}->{$_} if (defined $general_failures_num_by_severity->{$category}->{$_});
		$categoryline .= "<td>$failuresbyseverity</td>";
	}
	$categoryline .= "</tr>";
	print AGGREGATED "$categoryline\n";
}
print AGGREGATED "</table>\n";
print AGGREGATED "<br/>\n";

print AGGREGATED "<br/>PACKAGE-SPECIFIC FAILURES<br/>\n";
print AGGREGATED "<table border='1'>\n";
$tableheader = "<tr><th>package</th>";
for (@severities) { $tableheader .= "<th>$_</th>"; }
$tableheader .= "</tr>";
print AGGREGATED "$tableheader\n";
for my $package (@allpackages)
{
	if (defined $recipe_failures_num_by_severity->{$package})
	{
		print_package_specific_summary($package, $recipe_failures_by_package_severity->{$package});
		my $packagesummaryhtml = $package;
		$packagesummaryhtml =~ s,/,_,;
		$packagesummaryhtml .= ".html";
		my $packageline = "<tr><td><a href='$packagesummaryhtml'>$package</a></td>";
		for (@severities)
		{
			my $failuresbyseverity = 0;
			$failuresbyseverity = $recipe_failures_num_by_severity->{$package}->{$_} if (defined $recipe_failures_num_by_severity->{$package}->{$_});
			$packageline .= "<td>$failuresbyseverity</td>";
		}
		$packageline .= "</tr>";
		print AGGREGATED "$packageline\n";
	}
	else
	{
		my $packageline = "<tr><td>$package</td>";
		for (@severities) { $packageline .= "<td>0</td>"; }
		$packageline .= "</tr>";
		print AGGREGATED "$packageline\n";
	}
}
print AGGREGATED "</table>\n";
close(AGGREGATED);

translate_detail_files_to_html();

print "OK, done. Please open $outputdir/index.html.\n";


sub print_category_specific_summary
{
	my ($category, $failures_by_severity) = @_;
	
	my $filenamebase = $category;
	$filenamebase =~ s,/,_,;
	
	open(SPECIFIC, ">$outputdir/$filenamebase.html");
	print SPECIFIC "FAILURES FOR CATEGORY $category<br/>\n";
		
	for my $severity (@severities)
	{
		if (defined $failures_by_severity->{$severity})
		{
			print SPECIFIC "<br/>".uc($severity)."<br/>\n";
			print SPECIFIC "<table border='1'>\n";
			# $subcategory, $severity, $mmp, $phase, $recipe, $file, $line
			my $tableheader = "<tr><th>category</th><th>log file</th><th>log snippet</th></tr>";
			print SPECIFIC "$tableheader\n";
			
			for my $failure (@{$failures_by_severity->{$severity}})
			{
				my $failureline = "<tr><td>$failure->{subcategory}</td>";
				$failureline .= "<td>$failure->{config}</td>";
				$failureline .= "<td><a href='$filenamebase\_failures.html#failure_item_$failure->{linenum}'>item $failure->{linenum}</a></td>";
				$failureline .= "</tr>";
				print SPECIFIC "$failureline\n";
			}
			
			print SPECIFIC "</table>\n";
			print SPECIFIC "<br/>\n";
		}
	}
	
	close(SPECIFIC);
}

sub print_package_specific_summary
{
	my ($package, $failures_by_severity) = @_;
	
	my $filenamebase = $package;
	$filenamebase =~ s,/,_,;
	
	open(SPECIFIC, ">$outputdir/$filenamebase.html");
	print SPECIFIC "FAILURES FOR PACKAGE $package<br/>\n";
		
	for my $severity (@severities)
	{
		if (defined $failures_by_severity->{$severity})
		{
			print SPECIFIC "<br/>".uc($severity)."<br/>\n";
			print SPECIFIC "<table border='1'>\n";
			# $subcategory, $severity, $mmp, $phase, $recipe, $file, $line
			my $tableheader = "<tr><th>category</th><th>configuration</th><th>mmp</th><th>phase</th><th>recipe</th><th>log snippet</th></tr>";
			print SPECIFIC "$tableheader\n";
			
			for my $failure (@{$failures_by_severity->{$severity}})
			{
				my $failureline = "<tr><td>$failure->{subcategory}</td>";
				$failureline .= "<td>$failure->{config}</td>";
				$failureline .= "<td>$failure->{mmp}</td>";
				$failureline .= "<td>$failure->{phase}</td>";
				$failureline .= "<td>$failure->{recipe}</td>";
				$failureline .= "<td><a href='$filenamebase\_failures.html#failure_item_$failure->{linenum}'>item $failure->{linenum}</a></td>";
				$failureline .= "</tr>";
				print SPECIFIC "$failureline\n";
			}
			
			print SPECIFIC "</table>\n";
			print SPECIFIC "<br/>\n";
		}
	}
	
	close(SPECIFIC);
}

sub translate_detail_files_to_html
{
	opendir(DIR, $raptorbitsdir);
	my @failurefiles = readdir(DIR);
	closedir(DIR);	
	@failurefiles = grep(/\.txt$/, @failurefiles);
	
	for my $file (@failurefiles)
	{
		$file =~ /(.*)\.txt$/;
		my $filenamebase = $1;
		
		my $filecontent = '';
		open(FILE, "$raptorbitsdir/$file");
		{
			local $/=undef;
			$filecontent = <FILE>;
		}
		close(FILE);
		
		$filecontent =~ s,---(failure_item_\d+)---,<a name="$1">---$1---</a>,g;
		$filecontent = "<pre>$filecontent</pre>";
		
		open(FILE, ">$outputdir/$filenamebase\_failures.html");
		print FILE $filecontent;
		close(FILE);
	}
}

sub distinct_packages
{
	my ($allbldinfs) = @_;
	
	my $allpackages = {};
	
	for my $bldinf (keys %{$allbldinfs})
	{
		# normalize bldinf path
		$bldinf = lc($bldinf);
		$bldinf =~ s,^[A-Za-z]:,,;
		$bldinf =~ s,[\\],/,g;
		
		my $package = '';
		if ($bldinf =~ m,/((os|mw|app|tools|ostools|adaptation)/[^/]*),)
		{
			$package = $1;
		}
		else
		{
			print "WARNING: can't understand bldinf attribute of recipe: $bldinf. Won't dump to failed recipes file.\n";
		}
		
		$allpackages->{$package} = 1;
	}
	
	return sort {$a cmp $b} keys %{$allpackages};
}