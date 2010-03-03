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
# Extracts output text in <buildlog> context which doesn't belong to <recipe>'s

use strict;
use Getopt::Long;

my $RELEASEABLES_DIR = "/releaseables";

my $releaseablesdir = "";
my $packageexpr = '';
my $help = 0;
GetOptions((
	'packageexpr:s' => \$packageexpr,
	'releaseablesdir:s' => \$RELEASEABLES_DIR,
	'help!' => \$help
));

$packageexpr =~ m,([^/^\\]+)[/\\]([^/^\\]+),;
my $layer_expr = $1;
my $package_expr = $2;
$help = 1 if (!$layer_expr or !$package_expr);

if ($help)
{
	print "Extracts text which doesn't belong to recipes from a raptor log file\n";
	print "Usage: perl truclean.pl --packageexpr=LAYER_EXPR/PACKAGE_EXPR [OPTIONS]\n";
	print "where:\n";
	print "\tLAYER_EXPR can be * or the name of a layer\n";
	print "\tPACKAGE_EXPR can be * or the name of a package\n";
	print "and OPTIONS are:\n";
	print "\t--releaseablesdir=DIR Use DIR as the root of the releaseables dir (default: $RELEASEABLES_DIR\n";
	exit(0);
}

$RELEASEABLES_DIR = $releaseablesdir if ($releaseablesdir);

my @layers = ();
if ($layer_expr eq '*')
{
	opendir(DIR, $RELEASEABLES_DIR);
	@layers = readdir(DIR);
	closedir(DIR);
	@layers = grep(!/^\.\.?$/, @layers);
}
else
{
	push(@layers, $layer_expr);
}
#for (@layers) {print "$_\n"};

for my $layer (@layers)
{
	my @packages = ();
	if ($package_expr eq '*')
	{
		opendir(DIR, "$RELEASEABLES_DIR/$layer");
		@packages = readdir(DIR);
		closedir(DIR);
		@packages = grep(!/^\.\.?$/, @packages);
	}
	else
	{
		push(@packages, $package_expr);
	}
	#for (@pacakges) {print "$_\n"};
	
	for my $package (@packages)
	{
		print "Processing package $layer/$package...\n";

		open(FILE, "$RELEASEABLES_DIR/$layer/$package/info.tsv");
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
					unlink($file);
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
}