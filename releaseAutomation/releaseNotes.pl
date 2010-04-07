#!perl -w

use strict;

use FindBin;
use Text::CSV;

my $sourcesCSV = shift or die "First arg must be sources.csv to process\n";

# Load CSV
open my $csvText, "<", $sourcesCSV or die "Unable to open sources.csv from $sourcesCSV";
my $csv = Text::CSV->new();
my @keys;

while (my $line = <$csvText>)
{
	chomp $line;
	next unless $line;
	unless ($csv->parse($line))
	{
		my $err = $csv->error_input();
		die "Failed to parse line '$line': $err";
	}

	if (! @keys)
	{
		# First line - note the column names
		@keys =  $csv->fields();
		next;
	}
	my %package;
	# Read into a hash slice
	@package{@keys} = $csv->fields();

	die "sources.csv should specify revisions by changeset" unless $package{type} eq "changeset";
	die "sources.csv should specify changesets with a global ID" unless $package{pattern} =~ m{^[0-9a-z]{12}$}i;

	$package{source} =~ s{[\\/]$}{};

	# Work out MCL for an FCL
	# (Ignore package if it's coming from an MCL anyway)
	my $packageMCL = $package{source};
	next unless $packageMCL =~ s{(oss|sfl)/FCL/}{$1/MCL/};

	# Work out package short name (leaf of path)
	my ($packageShortName) = $packageMCL =~ m{([^\\/]*)[\\/]?$};
	# Work out package path (local path without preceeding /)
	my $packagePath = $package{dst};
	$packagePath =~ s{^[\\/]}{};

	# Heading for this package
	print "==== $packageShortName ([$package{source}/ $packagePath]) ====\n\n";

	# List all the changesets needed from the FCL
	my $fclOnly = `hg -R $package{dst} out $packageMCL -r $package{pattern} -n -q -M --style $FindBin::Bin/hg.style.mediawiki`;
	if ($fclOnly)
	{
		# Substitute in the source URL
		$fclOnly =~ s[\${sf\.package\.URL}][$package{source}]g;
		# Turn bug references into links
		$fclOnly =~ s{\b(bug) (\d+)}{[http://developer.symbian.org/bugs/show_bug.cgi?id=$2 $1 $2]}gi;
		print "{|\n";
		print $fclOnly;
		print "|}\n\n";
	}
	else
	{
		# Nothing needed that's not already in MCL - package need not be taken from FCL!
		print "'''Could use MCL!'''\n\n";
	}
}

