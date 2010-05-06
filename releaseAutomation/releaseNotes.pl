#!perl -w

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
# Automates the creation of parts of the PDK Release Notes

use strict;

use FindBin;
use Text::CSV;
use Getopt::Long;

my $sourcesCSV;		# sources.csv file for this build
my $previousPdkLabel;	# hg tag to compare against

GetOptions((
	'sources=s' => \$sourcesCSV,
	'baseline=s' => \$previousPdkLabel,
));

if (!$sourcesCSV ||!$previousPdkLabel)
{
	warn "Necessary argument(s) not supplied\n\n";
	usage();
	exit (1);
}

if (@ARGV)
{
	warn "Don't know what to do with these arguments: @ARGV\n\n";
	usage();
	exit (1);
}

# Load CSV
open my $csvText, "<", $sourcesCSV or die "Unable to open sources.csv from $sourcesCSV";
my $csv = Text::CSV->new();
my @keys;

print <<"EOT";
== FCLs ==

This PDK was built using FCL versions of the packages listed below: for each one we list all the changes in the FCL which are not in the MCL.

The previous PDK also involved some FCLs, so we indicate which FCLs are new to this build.

Cloning the source from Mercurial is made more awkward by using a mixture of MCLs and FCLs, but we provide a tool to help - see [[How to build the Platform]] for details.

EOT

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

	# See if previous PDK was built from MCL
	my $previousHash = `hg id -i -r $previousPdkLabel $packageMCL 2> nul:`;
	my $newMarker = $previousHash ? "'''NEW''' " : "";

	# Work out package short name (leaf of path)
	my ($packageShortName) = $packageMCL =~ m{([^\\/]*)[\\/]?$};
	# Work out package path (local path without preceeding /)
	my $packagePath = $package{dst};
	$packagePath =~ s{^[\\/]}{};

	# Heading for this package
	print "==== $packageShortName ([$package{source}/ $packagePath]) $newMarker====\n\n";

	# List all the changesets needed from the FCL
	my $fclOnly = `hg -R $package{dst} out $packageMCL -r $package{pattern} -n -q --style $FindBin::Bin/hg.style.mediawiki`;
	if ($fclOnly)
	{
		# Substitute in the source URL
		$fclOnly =~ s[\${sf\.package\.URL}][$package{source}]g;
		# Don't bother mentioning the tip revision
		$fclOnly =~ s['''tip''' ][]g;
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

sub usage
{
	warn <<EOT;
Generates release notes content

releaseNotes.pl -sources=<SOURCES.CSV> -baseline=<PDK RELEASE LABEL>

EOT
}
