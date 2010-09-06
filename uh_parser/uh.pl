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
# Dario Sestito <darios@symbian.org>
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
use releaseables;

use XML::SAX;
use RaptorSAXHandler;
use Getopt::Long;

use CGI;

our $raptorbitsdir = 'raptorbits';
our $basedir = '';
my $outputdir = "html";
our $releaseablesdir = "releaseables";
our $raptor_config = 'dummy_config';
our $current_log_file = '';
our $missing = 0;
my $help = 0;
GetOptions((
	'missing!' => \$missing,
	'basedir=s' => \$basedir,
	'help!' => \$help
));
my @logfiles = ();
for my $logfilesarg (@ARGV)
{
	push(@logfiles, glob($logfilesarg));
}

if ($help)
{
print <<_EOH;
UH parser
Reads one or more Raptor log files, extracts the interesting bits and puts them
into a set of HTML files, making it easy to spot the failures and see the
related log snippets.

Usage: uh.pl [options] [files]

Options:
  -h, --help            Show this help message and exit
  -m, --missing         Add report on missing binaries. Check is done against
                        the epoc tree at the root of the current drive
                        (Note: it requires Raptor log to include whatlog info)
  -b OUTDIR, --basedir OUTDIR
                        Generate output under OUTDIR (defaults to current dir)
  
Files:
  Accepts one or a list of raptor log files (separated by a space).
  Shell wildcards are accepted in the file names.
  If no file argument is provided then take the most recent log under
  \\epoc32\\build
  
Examples:
  uh.pl -m              Launched from the build drive, parses the log file of
                        the last call to sbs. Also reports on missing files.
  uh.pl -m \\output\\logs\\*_compile.log
                        Parses all files ending in '_compile.log' under the
                        \\output\\logs directory. Also reports on missing files.
_EOH
	exit(0);
}

if (!@logfiles)
{
	if (-d "\\epoc32\\build")
	{
		opendir(BUILDDIR, "\\epoc32\\build");
		my @allfoundlogfiles = grep(/^Makefile.\d{4}-\d{2}-\d{2}-\d{2}-\d{2}-\d{2}\.log$/, readdir(BUILDDIR));
		@allfoundlogfiles = sort {$b cmp $a} @allfoundlogfiles;
		push @logfiles, "\\epoc32\\build\\" . shift @allfoundlogfiles;
	}
}

if (!@logfiles)
{
	print "No files to parse.\n";
	exit(0);
}

if ($basedir)
{
	$raptorbitsdir = "$basedir/raptorbits";
	$outputdir = "$basedir/html";
	$releaseablesdir = "$basedir/releaseables";
}
mkdir($basedir) if (!-d$basedir);

$raptorbitsdir =~ s,/,\\,g; # this is because rmdir doens't cope correctly with the forward slashes

system("rmdir /S /Q $raptorbitsdir") if (-d $raptorbitsdir);
mkdir($raptorbitsdir);
#print "Created dir $raptorbitsdir.\n";
system("rmdir /S /Q $releaseablesdir") if (-d $releaseablesdir);
mkdir("$releaseablesdir");

our $failure_item_number = 0;

# create empty summary file anyway
open(SUMMARY, ">$raptorbitsdir/summary.csv");
close(SUMMARY);


my $saxhandler = RaptorSAXHandler->new();
$saxhandler->add_observer('RaptorError', $RaptorError::reset_status);
$saxhandler->add_observer('RaptorWarning', $RaptorWarning::reset_status);
$saxhandler->add_observer('RaptorInfo', $RaptorInfo::reset_status);
$saxhandler->add_observer('RaptorUnreciped', $RaptorUnreciped::reset_status);
$saxhandler->add_observer('RaptorRecipe', $RaptorRecipe::reset_status);
$saxhandler->add_observer('releaseables', $releaseables::reset_status);

our $allbldinfs = {};
our $allconfigs = {};
our $releaseables_by_package = {};

my $parser = XML::SAX::ParserFactory->parser(Handler=>$saxhandler);
for (@logfiles)
{
	print "Reading file: $_\n";
	$current_log_file = $_;
	$parser->parse_uri($_);
}

print "Removing duplicates from missing files\n";
releaseables::remove_missing_duplicates();
print "Counting releasables\n";
releaseables::count_distinct();

my @allpackages = distinct_packages($allbldinfs);

print "Generating HTML\n";

$outputdir =~ s,/,\\,g;
system("rd /S /Q $outputdir") if (-d $outputdir);
mkdir ($outputdir);

my $raptor_errors = {};
my $raptor_warnings = {};
my $raptor_unreciped = {};
my $general_failures_num_by_severity = {};
my $general_failures_by_category_severity = {};
my $recipe_failures_num_by_severity = {};
my $recipe_failures_by_package_severity = {};
my $missing_by_package = {};
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
			$failure_package = RaptorCommon::get_package_subpath($failure->{component});
			if (!$failure_package)
			{
				print "WARNING: summary line with wrong component path at $csv_file line $csv_linenum. Skipping\n";
				next;
			}
		}
		
		$failure->{subcategory} = 'uncategorized' if (!$failure->{subcategory});
		$failure->{severity} = 'unknown' if (!$failure->{severity});
		$failure->{mmp} = '-' if (!$failure->{mmp});
		$failure->{phase} = '-' if (!$failure->{phase});
		$failure->{recipe} = '-' if (!$failure->{recipe});
		
		# populate severities dynamically.
		#$severities->{$failure->{severity}} = 1;
		
		# put failure items into their category container
		if ($failure->{category} =~ /^recipe_failure$/i || $failure->{category} =~ /^raptor_(error|warning|unreciped)$/i && $failure_package)
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
		elsif ($failure->{category} =~ /^raptor_(error|warning|unreciped)$/i)
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
print AGGREGATED "RAPTOR BUILD SUMMARY<br/><br/>\n";

my $allconfigsstring = '';
for my $raptorconfig (sort {$a cmp $b} keys %{$allconfigs}) { $allconfigsstring .= ", $raptorconfig"; }
$allconfigsstring =~ s/^, //;
print AGGREGATED "BUILT CONFIGS:<br/>$allconfigsstring<br/>\n";

print AGGREGATED "<br/>FLOATING FAILURES<br/>\n";
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

print AGGREGATED "PACKAGE-SPECIFIC FAILURES<br/>\n";
print AGGREGATED "<table border='1'>\n";
$tableheader = "<tr><th>package</th>";
for (@severities) { $tableheader .= "<th>$_</th>"; }
$tableheader .= "<th>missing</th>" if ($missing);
$tableheader .= "</tr>";
print AGGREGATED "$tableheader\n";
for my $package (@allpackages)
{
	my $mustlink = print_package_specific_summary($package);
	if ($mustlink)
	{
		my $packagesummaryhtml = $package;
		$packagesummaryhtml =~ s,/,_,g;
		$packagesummaryhtml .= ".html";
		my $packageline = "<tr><td><a href='$packagesummaryhtml'>$package</a></td>";
		for (@severities)
		{
			my $failuresbyseverity = 0;
			$failuresbyseverity = $recipe_failures_num_by_severity->{$package}->{$_} if (defined $recipe_failures_num_by_severity->{$package}->{$_});
			$packageline .= "<td>$failuresbyseverity</td>";
		}
		#print "package $package, releasables in this package: $releaseables_by_package->{$package}\n";
		$packageline .= "<td>".$missing_by_package->{$package}."/".$releaseables_by_package->{$package}."</td>" if ($missing);
		$packageline .= "</tr>\n";
		print AGGREGATED "$packageline\n";
	}
	# don't display the unknown/unknown package unless there are associated failures
	elsif ($package eq 'unknown/unknown') {}
	else
	{
		my $packageline = "<tr><td>$package</td>";
		for (@severities) { $packageline .= "<td>0</td>"; }
		$packageline .= "<td>0/$releaseables_by_package->{$package}</td>" if ($missing);
		$packageline .= "</tr>\n";
		print AGGREGATED "$packageline\n";
	}
}
print AGGREGATED "</table>\n";
print AGGREGATED "<br/>\n";

my $allfilesstring = '';
for my $raptorfile (sort {$a cmp $b} @logfiles) { $allfilesstring .= "<br/>$raptorfile"; }
print AGGREGATED "PARSED LOGS:$allfilesstring<br/>\n";

close(AGGREGATED);

translate_detail_files_to_html();

print "OK, done. Please open $outputdir/index.html.\n";


sub print_category_specific_summary
{
	my ($category, $failures_by_severity) = @_;
	
	my $filenamebase = $category; 
	$filenamebase =~ s,/,_,g;
	
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
	my ($package) = @_;
	
	my $anyfailures = 0;
	
	my $filenamebase = $package; 
	$filenamebase =~ s,/,_,g;
	
	if (defined $recipe_failures_by_package_severity->{$package})
	{
		$anyfailures = 1;
		
		my $failures_by_severity = $recipe_failures_by_package_severity->{$package};
	
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
	
	if ($missing)
	{
		$missing_by_package->{$package} = 0;
		
		my $missinglistfile = $package;
		$missinglistfile =~ s,/,_,g;
		$missinglistfile .= "_missing.txt";
		if (open(MISSINGLIST, "$::raptorbitsdir/$missinglistfile"))
		{
			my @list = ();
			while(<MISSINGLIST>)
			{
				my $missingfile = $_;
				chomp $missingfile;
				$missingfile =~ s,^\s+,,g;
				$missingfile =~ s,\s+$,,g;
				push(@list, $missingfile);
			}
			close(MISSINGLIST);
			
			$missing_by_package->{$package} = scalar(@list);
			
			if ($missing_by_package->{$package} > 0)
			{
				open(SPECIFIC, ">>$outputdir/$filenamebase.html");
				print SPECIFIC "FAILURES FOR PACKAGE $package<br/>\n" if(!$anyfailures);
				
				$anyfailures = 1;
				
				print SPECIFIC "<br/>MISSING<br/>\n";
				print SPECIFIC "<table border='1'>\n";
				# $subcategory, $severity, $mmp, $phase, $recipe, $file, $line
				my $tableheader = "<tr><th>file</th></tr>\n";
				print SPECIFIC "$tableheader\n";
				
				for my $missingfile (sort {$a cmp $b} @list)
				{
					$missingfile = CGI::escapeHTML($missingfile);
					print SPECIFIC "<tr><td>$missingfile</td></tr>\n";
				}
				
				print SPECIFIC "</table>\n";
				print SPECIFIC "<br/>\n";
				
				close(SPECIFIC);
			}
		}
	}
	
	return $anyfailures;
}

sub translate_detail_files_to_html
{
	opendir(DIR, $raptorbitsdir);
	my @failurefiles = readdir(DIR);
	closedir(DIR);	
	@failurefiles = grep($_ =~ /\.txt$/ && $_ !~ /_missing\.txt$/, @failurefiles);
	
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
		
		$filecontent = CGI::escapeHTML($filecontent);
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
		RaptorCommon::normalize_bldinf_path(\$bldinf);
		
		my $package = '';
		#print "bldinf: $bldinf\n";
		$package = RaptorCommon::get_package_subpath($bldinf);
		#print "package: $package\n";
		if (!$package)
		{
			print "WARNING: can't understand bldinf attribute of recipe: $bldinf. Won't dump to failed recipes file.\n";
		}
		
		$allpackages->{$package} = 1;
	}
	
	# sort packages, but set unknown first
	my @sorted = ();
	if (defined $allpackages->{'unknown/unknown'})
	{
		push @sorted, 'unknown/unknown';
		delete $allpackages->{'unknown/unknown'};
	}
	push @sorted, sort {$a cmp $b} keys %{$allpackages};
	
	return @sorted;
}
