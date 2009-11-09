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
use XML::Parser;

my $sourcesCsv = shift or die "First argument must be sources.csv file for build being built/released\n";
my $sysDef = shift or die  "Second argument must be system definition file\n";
my $previousPdkLabel = shift or die "Third argument must be hg tag to compare against\n";
defined shift and die "No more than three arguments please\n";

my $packages = { current => {}, previous => {} };

# Load current manifest
open(my $manifest, "<", $sourcesCsv) or die;
my @manifest = <$manifest>;
close $manifest;
populate($packages->{current}, @manifest);

# Load prev manifest
@manifest = `hg cat -r $previousPdkLabel $sourcesCsv`;
populate($packages->{previous}, @manifest);

my $xml = XML::Parser->new(Style => "Objects") or die;
# Load current names from current system definition
my $tree = $xml->parsefile($sysDef);
populateNames($packages->{current}, $tree);
# Load previous names from previous system definition
eval { $tree = $xml->parsestring(scalar `hg cat -r $previousPdkLabel $sysDef`) } or die $!;
populateNames($packages->{previous}, $tree);

# Output release note info...

my $currPackageCount = scalar keys %{$packages->{current}};
my $prevPackageCount = scalar keys %{$packages->{previous}};
print <<EOT;
== Packages ==

This section provides general information on the packages included in this PDK release compared to '''$previousPdkLabel'''.

Number total of packages in this PDK release is: '''$currPackageCount'''

Number total of packages in $previousPdkLabel is: '''$prevPackageCount'''

EOT

my @addedPackages = sort { packageSort($packages->{current}) } grep { !exists $packages->{previous}->{$_} } keys %{$packages->{current}};
my $addedPackageCount = scalar @addedPackages;
print <<EOT;
=== Packages added ===

Number total of packages added is: '''$addedPackageCount'''

EOT
foreach (@addedPackages)
{
	print "==== $packages->{current}->{$_}->{name} ([$packages->{current}->{$_}->{url} $packages->{current}->{$_}->{path}]) ====\n";
}
print "\n" if @addedPackages;

my @removedPackages = sort { packageSort($packages->{previous}) } grep { !exists $packages->{current}->{$_} } keys %{$packages->{previous}};
my $removedPackageCount = scalar @removedPackages;
print <<EOT;
=== Packages removed ===

Number total of packages removed is: '''$removedPackageCount'''

EOT
foreach (@removedPackages)
{
	print "==== $packages->{previous}->{$_}->{name} ([$packages->{previous}->{$_}->{url} $packages->{previous}->{$_}->{path}]) ====\n";
}
print "\n" if @removedPackages;

my @movedPackages = sort { packageSort($packages->{current}) } grep { inPrev($_) && $packages->{current}->{$_}->{path} ne $packages->{previous}->{$_}->{path} } keys %{$packages->{current}};
my $movedPackageCount = scalar @movedPackages;
print <<EOT;
=== Packages moved ===

Number total of packages moved is: '''$movedPackageCount'''

EOT
foreach (@movedPackages)
{
	print "==== $packages->{current}->{$_}->{name} ([$packages->{previous}->{$_}->{url} $packages->{previous}->{$_}->{path}] to [$packages->{current}->{$_}->{url} $packages->{current}->{$_}->{path}]) ====\n";
}
print "\n" if @movedPackages;

my @openedPackages = sort { packageSort($packages->{current}) } grep { inPrev($_) && $packages->{current}->{$_}->{license} eq "oss" && $packages->{previous}->{$_}->{license} eq "sfl" } keys %{$packages->{current}};
my $openedPackageCount = scalar @openedPackages;
if ($openedPackageCount)
{
	print <<EOT;
=== Packages newly released under a fully Open license ===

Number total of packages relicensed is: '''$openedPackageCount'''

EOT
	foreach (@openedPackages)
	{
		print "==== $packages->{current}->{$_}->{name} ([$packages->{current}->{$_}->{url} $packages->{current}->{$_}->{path}]) ====\n";
	}
	print "\n";
}

print <<EOT;
== FCLs ==

This PDK was built using the FCL versions of the packages listed below: for each one we list the changes in the FCL which are not in the MCL.

The previous PDK also involved some FCLs, so we indicate which problems are now fixed in the MCL, and which FCLs are new to this build.

Cloning the source from Mercurial is made more awkward by using a mixture of MCLs and FCLs, but we provide a tool to help - see [[How to build the Platform]] for details.

EOT
# Newly from FCL
foreach (sort { packageSort($packages->{current}) } grep { inPrev($_) && $packages->{previous}->{$_}->{codeline} eq "MCL" && $packages->{current}->{$_}->{codeline} eq "FCL" } keys %{$packages->{current}})
{
	print "==== $packages->{current}->{$_}->{name} ([$packages->{current}->{$_}->{url} $packages->{current}->{$_}->{path}]) -- NEW ====\n";
}
# Still from FCL
foreach (sort { packageSort($packages->{current}) } grep {inPrev($_) && $packages->{previous}->{$_}->{codeline} eq "FCL" && $packages->{current}->{$_}->{codeline} eq "FCL"} keys %{$packages->{current}})
{
	print "==== $packages->{current}->{$_}->{name} ([$packages->{current}->{$_}->{url} $packages->{current}->{$_}->{path}]) ====\n";
}

print "\n=== FCLs used in PDK_2.0.0 but no longer needed ===\n\n";
my @revertedToMCL = sort { packageSort($packages->{current}) } grep { inPrev($_) && $packages->{previous}->{$_}->{codeline} eq "FCL" && $packages->{current}->{$_}->{codeline} eq "MCL" } keys %{$packages->{current}};
print "(none)\n" unless @revertedToMCL;
foreach (@revertedToMCL)
{
	print "==== $packages->{current}->{$_}->{name} ([$packages->{current}->{$_}->{url} $packages->{current}->{$_}->{path}]) ====\n";
}
print "\n";
exit(0);

sub populate
{
	my $hash = shift;
	my @entries = @_;

	# Discard the column headings
	shift @entries;
	
	foreach my $entry (@entries)
	{
		chomp $entry;
		my ($repo) = $entry =~ m{^(.*?),};
		my ($packageId) = $repo =~ m{/(\w+)/?$};
		my ($codeline) = $repo =~ m{/(MCL|FCL)/};
		# Skip the RnD repos and other complications
		next unless $codeline;
		my ($license, $path) = $repo =~ m{/([^/\\]*)/$codeline/(.+?)/?$};
		my $url = "http://developer.symbian.org/$license/$codeline/$path";
		$hash->{$packageId} = {license => $license, codeline => $codeline, path => $path, name => "''$packageId''", url => $url, sortKey => lc $packageId};
	}
}

sub populateNames
{
	my $packages = shift;
	my $itemsUnderThisElement = shift;
	foreach (@$itemsUnderThisElement)
	{
		if (ref $_)
		{
			if (ref $_ eq "main::block" || ref $_ eq "main::package")
			{
				if (exists $packages->{$_->{name}})
				{
					$packages->{$_->{name}}->{name} = $_->{"long-name"};
					$packages->{$_->{name}}->{sortKey} = lc $_->{"long-name"};
				}
			}
			else
			{
				populateNames($packages, $_->{Kids});
			}
		}
	}
}

sub inPrev
{
	my $id = shift;
	exists $packages->{previous}->{$id};
}

sub packageSort
{
	my $details = shift;
	$details->{$a}->{sortKey} cmp $details->{$b}->{sortKey};
}


