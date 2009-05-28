#! perl

use strict;

# update_repos.pl

my %repos;

foreach my $layer ("os", "mw", "app", "ostools")
	{
	opendir DIR, $layer;
	my @packages = grep !/^\.\.?$/, readdir DIR;
	closedir DIR;
	foreach my $package (@packages)
		{
		next if (-f "$layer/$package");
		$repos{"$layer/$package"} = 1;
		}
	}

print join("\n",sort keys %repos,"","");

my $tree = "d:/Mercurial/";

foreach my $layer ("os", "mw", "app", "ostools")
	{
	opendir DIR, "$tree$layer";
	my @packages = grep !/^\.\.?$/, readdir DIR;
	closedir DIR;
	foreach my $package (@packages)
		{
		next if (-f "$tree$package");
		if (defined $repos{"$layer/$package"})
			{
			# this one is still relevant
			next;
			}
		# package name has changed, I expect
		print "Old package $layer/$package is now obsolete\n";
		rename "$tree$layer/$package", "$tree"."obsolete/".$package;
		}
	}

foreach my $repo (sort keys %repos)
	{
	print "\n\nProcessing $repo\n";
	my ($layer,$package) = split /\//, $repo;
	my $master = "$tree$repo/MCL_$package/.hg";
	
	if (-d $master)
		{
		# repo already exists - move it into place
		rename "$tree$repo/MCL_$package/.hg", "$repo/.hg";
		}
	else
		{
		# New repo
		print "New repository $repo\n";
		mkdir "$tree$layer";
		mkdir "$tree$layer/$package";
		mkdir "$tree$layer/$package/MCL_$package";
		}
		
	chdir $repo;
	system("hg init") if (!-d ".hg");
	system("hg", "commit", "--addremove", "-m", "add wk04 Nokia source");
	chdir "../..";
	rename "$repo/.hg", "$tree$repo/MCL_$package/.hg";
	}

	