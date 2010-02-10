#!/usr/bin/perl

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
# Update sources.csv files in a subtree of interim/fbf/projects/packages,
# based on a sources.csv file from the corresponding interim/fbf/projects/platforms 
# definition. Will use "hg remove" to get rid of dirs for obsolete packages
#
# Stand in the root of the tree in packages, e.g. Symbian3, and run this script
# supplying the single model sources.csv file as input, e.g. 
# platforms/Symbian3/single/sources_fcl.csv

use strict;

my $headerline = <>;
my $line;

my %dirs;
while ($line =<>)
	{
	if ($line =~ /\/(oss|sfl)\/(MCL|FCL)\/sf\/([^,]+)\/,/)
		{
		my $license = $1;
		my $codeline = $2;
		my $path = $3;
		
		$dirs{$path} = $line;
		next;
		}
	}

sub update_csv_file($)
	{
	my ($path) = @_;
	open FILE, "<$path/sources.csv";
	my @lines = <FILE>;
	close FILE;
	
	# replace the existing lines with ones from the main sources.csv
	my @newlines;
	foreach my $line (@lines)
		{
		if ($line =~ /\/(oss|sfl)\/(MCL|FCL)\/sf\/([^,]+)\/,/)
			{
			my $license = $1;
			my $codeline = $2;
			my $package = $3;
			
			push @newlines, $dirs{$package};
			next;
			}
		push @newlines, $line;
		}
	
	open FILE, ">$path/sources.csv";
	print FILE @newlines;
	close FILE;
	}

my %found_dirs;
my @listing = `dir /s/b sources.csv`;
foreach $line (@listing)
	{
	# G:\system_model\packages\CompilerCompatibility\app\commonemail\sources.csv
	if ($line =~ /\\([^\\]+)\\([^\\]+)\\sources.csv/)
		{
		my $layer = $1;
		my $package = $2;
		my $path = "$layer/$package";
		
		if (defined $dirs{$path})
			{
			if (!-e "$path/package_definition.xml")
				{
				print "$path needs a package_definition.xml file\n";
				}
			update_csv_file($path);
			$found_dirs{$path} = 1;
			next;
			}
		else
			{
			system("hg", "remove", "$layer//$package");
			}
		}
	}

foreach my $path (sort keys %dirs)
	{
	next if $found_dirs{$path};
	
	mkdir $path;
	open FILE, ">$path/sources.csv";
	print FILE $headerline, $dirs{$path};
	close FILE;
	system("hg", "add", "$path/sources.csv");
	}