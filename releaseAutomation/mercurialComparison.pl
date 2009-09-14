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
# Automates the creation of part of the PDK Release Notes: "Mercurial Comparison with PDK XXXXX"

use strict;

use FindBin;
$FindBin::Bin =~ s{/}{\\}g;;

my $bomInfoFile = shift or die "First argument must be BOM file for build being built/released\n";
my $previousPdkLabel = shift or die  "Second argument must be hg label to compare against\n";
my $detailsTsvFilename = shift or die "Third argument must be filename to write detailed TSV data into\n";
defined shift and die "No more than three arguments please\n";

# Use external scripts to get the raw data and produce the CSV summary (to go into Excel, etc)
system("perl $FindBin::Bin\\..\\clone_packages\\clone_all_packages.pl -packagelist $bomInfoFile -exec -- hg status -C --rev $previousPdkLabel 2>&1 | perl $FindBin::Bin\\..\\williamr\\summarise_hg_status.pl 2> nul: > $detailsTsvFilename");

# The redirection above means that we discard STDERR from summarise_hg_status,
# which lists packages for which it was unable to generate any data
# 
# It's discarded because that happens either because it's a new package or has
# moved from SFL -> EPL or we've reverted to using the MCL instead of the FCL
# (in which cases it's dealt with in another part of the release notes) or it
# just hasn't had any changes since the last release

# Input from TSV file
my @rawData;
open my $fh, "<", $detailsTsvFilename;
my @columns;
foreach my $line (<$fh>)
{
	chomp $line;
	my @values = split "\t", $line;
	if (!@columns)
	{
		@columns = @values;
	}
	else
	{
		my %lineData;
		@lineData{@columns} = @values;
		push @rawData, \%lineData;
	}
}
close $fh;

# Pivot
my %cookedData;
foreach my $datum (@rawData)
{
	next if $datum->{Change} =~ m{^(same|M)$};
	$cookedData{$datum->{Package}} += $datum->{Count};
}

# Cut-off for "interesting" packages
foreach my $package (keys %cookedData)
{
	delete $cookedData{$package} unless $cookedData{$package} >= 350;
}

# Output
print <<"EOT";
== Mercurial Comparison with $previousPdkLabel ==

The Mercurial changes from Nokia were delivered as a bulk update based on '''XXXXXXXXXXXXXXXXXXXXXX'''.

List of the Mercurial changes (files added/removed/modified) between $previousPdkLabel and PDK '''XXXXX''' - [[Media:XXXX.txt]].

A short study of the results which concentrated on the added and removed files has identified these significant package changes: 

EOT

foreach my $package (sort keys %cookedData)
{
	print <<"EOT";
=== $package ===

$cookedData{$package} files added/removed

* Cause1
* etc

EOT
}

if (!keys %cookedData)
{
	print "'''No packages were identified with large changes.'''";
}

