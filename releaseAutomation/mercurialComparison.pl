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
my @pkgErrors = `perl $FindBin::Bin\\..\\clone_packages\\clone_all_packages.pl -packagelist $bomInfoFile -exec -- hg status -A --rev $previousPdkLabel 2>&1 | perl $FindBin::Bin\\..\\williamr\\summarise_hg_status.pl 2>&1 > $detailsTsvFilename`;

# The redirection above means that we capture STDERR from summarise_hg_status,
# which lists packages for which it was unable to generate any data
# 
# It's captured because that happens either because it's a new package or has
# moved from SFL -> EPL or we've reverted to using the MCL instead of the FCL
# (in which case it's dealt with in another part of the release notes) or it
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
	# Accumulate the total number of files in the old revision of the pkg
	$cookedData{$datum->{Package}}->{totalFiles} += $datum->{Count} unless $datum->{Change} eq "A";
	$cookedData{$datum->{Package}}->{same} += $datum->{Count} if $datum->{Change} eq "same";
	$cookedData{$datum->{Package}}->{addRemove} += $datum->{Count} if $datum->{Change} =~ m{^[AR]$};
}
# Cut-off for "interesting" packages
foreach my $package (keys %cookedData)
{
	# Ensure items are defined
	$cookedData{$package}->{totalFiles} |= 1;
	$cookedData{$package}->{same} |= 0;
	$cookedData{$package}->{addRemove} |= 0;
	$cookedData{$package}->{percentChurn} = 100 * (1 - ($cookedData{$package}->{same} / $cookedData{$package}->{totalFiles}));
	
	# More than N files added + removed
	next if $cookedData{$package}->{addRemove} >= 400;
	# More than M% churn
	next if $cookedData{$package}->{percentChurn} > 30;
	# Nothing interesting about this package
	delete $cookedData{$package};
}

# Output
foreach my $package (sort keys %cookedData)
{
	print <<"EOT";
=== $package ===

* $cookedData{$package}->{addRemove} files added/removed
* $cookedData{$package}->{percentChurn}% of files churned

# Cause1
# etc

EOT
}

if (!keys %cookedData)
{
	print "'''No packages were identified with large changes.'''";
}

