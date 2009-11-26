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
use Getopt::Long;

my $sourcesCsv;		# sources.csv file for this build
my @sysDef;		# system definition files to look in for this build
my $previousPdkLabel;	# hg tag to compare against
my $prevSourcesCsv;	# sources.csv file for baseline build, if different to this build
my $prevSysDef;		# system definition file for baseline build, if different to this build

GetOptions((
	'sources=s' => \$sourcesCsv,
	'sysdef=s' => \@sysDef,
	'baseline=s' => \$previousPdkLabel,
	'prevSources=s' => \$prevSourcesCsv,
	'prevSysdef=s' => \$prevSysDef,
));

if (!$sourcesCsv || !@sysDef || !$previousPdkLabel)
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

$prevSourcesCsv ||= $sourcesCsv;

my $packages = { current => {}, previous => {} };

# Load current manifest
open(my $manifest, "<", $sourcesCsv) or die "Unable to open $sourcesCsv";
my @manifest = <$manifest>;
close $manifest;
populate($packages->{current}, @manifest);

# Load prev manifest
@manifest = `hg cat -r $previousPdkLabel $prevSourcesCsv`;
populate($packages->{previous}, @manifest);

my $xml = XML::Parser->new(Style => "Objects") or die;
foreach my $sysDef (@sysDef)
{
	# Load current names from current system definition (fails silently)
	eval { populateNames($packages->{current}, $xml->parsefile($sysDef) ) };
	# Load previous names from current system definition at earlier revision (fails silently)
	eval { populateNames($packages->{previous}, $xml->parsestring(scalar `hg cat -r $previousPdkLabel $sysDef 2> nul:`) ) };
}

# Load previous names from previous system definition, if supplied
populateNames($packages->{previous}, $xml->parsestring(scalar `hg cat -r $previousPdkLabel $prevSysDef`) ) if $prevSysDef;

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

print "\n=== FCLs used in $previousPdkLabel but no longer needed ===\n\n";
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
			if (ref $_ eq "main::block" || ref $_ eq "main::package" || ref $_ eq "main::module")
			{
				if (exists $packages->{$_->{name}} && exists $_->{"long-name"})
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

sub usage
{
	warn <<EOT;
Generates release notes detail about packages and FCLs used.

packageComparison.pl -sources=<SOURCES.CSV> -sysdef=<SYSTEM_DEFINITION.XML> -baseline=<PDK RELEASE LABEL> [-prevSources=<PREV SOURCES.CSV>] [-prevSysdef=<PREV>]

EOT
}
