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
# Clean environment by removing releaseable files based on info.tsv

use strict;
use Getopt::Long;

my $RELEASEABLES_DIR_DEFAULT = "\\build_info\\logs\\releaseables";

my $releaseablesdir = "";
my $packageexpr = '';
my $dryrun = 0;
my $help = 0;
GetOptions((
	'packageexpr:s' => \$packageexpr,
	'releaseablesdir:s' => \$releaseablesdir,
	'dryrun!' => \$dryrun,
	'help!' => \$help
));

$help = 1 if (!$packageexpr);

if ($help)
{
	print <<_EOH;
truclean
Performs a 'clean' build step, based on the releaseables information, i.e. the
list of artifacts produced during a PDK build.
This cleaning step ensures all the build artifacts produced by the build are
actually removed even if the source code has changed since the PDK build. 

Usage: truclean.pl -p PACKAGE_EXPR [-r RELEASABLES_DIR] [-d]

Options:
  -h, --help            Show this help message and exit
  -p PACKAGE_EXPR       Clean (remove) build artifacts belonging to the package
                        or packages indicated by PACKAGE_EXPR.
                        PACKAGE_EXPR is the path (wildcards allowed) of the
                        package, e.g. 'sf/app/camera' or 'sf/mw/*' or '*/*/*'.
                        If the first directory level is not specified then 'sf'
                        is assumed. 
  -r RELEASABLES_DIR    Use RELEASEABLES_DIR as root of the releaseable files
                        (default is $RELEASEABLES_DIR_DEFAULT).
  -d                    Dry run (Do not remove files for real)
_EOH
	exit(0);
}

$releaseablesdir = $RELEASEABLES_DIR_DEFAULT if (!$releaseablesdir);

$packageexpr =~ s,\\,/,g;
$packageexpr =~ s,//,/,g;
$packageexpr =~ s,^/,,;
if (-d "$releaseablesdir/sf")
{
	$packageexpr = "sf/$packageexpr" if ($packageexpr =~ m,^(adaptation|adapt|app|mw|os|tools),);
}

my @targetfiles = grep {-f$_} glob("$releaseablesdir/$packageexpr/info.tsv");
print join("\n", @targetfiles);

for my $targetfile (@targetfiles)
{
	print "Processing $targetfile...\n";

	open(FILE, $targetfile);
	while (<FILE>)
	{
		my $line = $_;
		
		if ($line =~ m,([^\t]*)\t([^\t]*)\t([^\t]*),)
		{
			my $file = $1;
			my $type = $2;
			my $config = $3;
			
			if (-f $file)
			{
				print "removing file: '$file'\n";
				unlink($file) if (!$dryrun);
			}
			else
			{
				print "WARNING: file '$file' doesn't exist.\n";
			}
		}
		else
		{
			print "WARNING: line '$line' doesn't match the expected tab-separated pattern\n";
		}
	}
	close(FILE);
}
