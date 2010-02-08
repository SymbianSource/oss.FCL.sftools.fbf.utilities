#! perl -w

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
#

use strict;
use Getopt::Long;

use FindBin;
#my $churn_core = "D:\\mirror\\churn_core.pl";
my $churn_core = "$FindBin::Bin\\churn_core.pl";
my $churn_output_temp = "$FindBin::Bin\\fbf_churn_output";
mkdir $churn_output_temp;

my $path = $FindBin::Bin;
$path =~ s/\//\\/g;
my $clone_packages = "$path\\..\\clone_packages\\clone_all_packages.pl";


sub Usage($)
  {
  my ($msg) = @_;
  
  print "$msg\n\n" if ($msg ne "");
  
	print <<'EOF';

	
fbf_churn.pl - simple script for calculating code churn in between two revisions 
or labels for a package. This script can also be used to calculate code size for 
a package.

When used without a package name or filter, this script runs for all the packages
in the BOM (build-info.xml) file supplied to it. 

Important: 
  This script uses clone_all_packages.pl which clones all repositories listed in 
  the BOM or pull changes into a previously cloned repository.
  
  This script uses its accompayning script churn_core.pl - which should be
  present in the same directory as this script.

Limitations:
  If a BOM is not supplied to the script using the -bom option, then the script 
  runs on the package locations inside both MCL and FCL producing two results
  for a single package. For running the script for calculating code churn between 
  two release buils (using labels) or for calculating code size for a release build,
  it is essential that a BOM (preferably for the newer build) is passed as an 
  argument using the -bom option.
  

Options:

-o --old		old revision or label for a package/respoitory

-n --new		new revision or label for a package/respoitory

--rev			revision for package/respoitory - Use this while calculating code size for a single package
			
--label			revision tag for package or release build - Use this while calculating code size

-bom --bom		build-info.xml files supplied with Symbian PDKs

-verbose		print the underlying "clone_all_packages" & "hg" commands before executing them

-help			print this help information

-package <RE>   	only process repositories matching regular expression <RE>

-filter <RE>    	only process repositories matching regular expression <RE>

EOF
  exit (1);  
  }

print "\n\n==Symbian Foundation Code Churn Tool v1.0==\n\n";



my $old = "null";
my $new = "";
my $filter = "";
my $codeline = "";
my $package = "";
my $licence = "";
my $packagelist = "";
my $verbose = 0;
my $mirror = 0;
my $help = 0;

sub do_system
	{
	my (@args) = @_;
	print "* ", join(" ", @args), "\n" if ($verbose);
	return system(@args);
	}

# Analyse the command-line parameters
if (!GetOptions(
    "n|new-rev|new-label|label|rev=s" => \$new,
    "o|old-rev|old-label=s" => \$old,
    "f|filter=s" => \$filter,
    "p|package=s" => \$filter,
    "cl|codeline=s" => \$codeline,
    "li|licence=s" => \$licence,
	"bom|bom=s" => \$packagelist,
	"v|verbose" => \$verbose,
	"h|help" => \$help,
    ))
  {
  Usage("Invalid argument");
  }
  
Usage("") if ($help);
Usage("Too few arguments....use at least one from -n|new-rev|new-label|label|rev or -bom") if ($new eq "" && $packagelist eq "");
#Usage("Too many arguments") if ($new ne "" && $packagelist ne "");


if ($old eq 'null')
  {
    print "\nCode size calculation....\n";		  
  }
else
  {
    print "\nCode churn calculation....\n";		  
  }

  
my @packagelistopts = ();
@packagelistopts = ("-packagelist", $packagelist) if ($packagelist ne "");

my @verboseopt = ();
@verboseopt = "-v" if ($verbose);

my @mirroropt = ();
@mirroropt = "-mirror" if ($mirror);

my $new_rev = $new;
$new_rev = "%REV%" if ($new_rev eq "");

#TO_DO: Locate clone_all_packages relative to the location of this script.
#TO_DO: Remove references to absolute paths, change to relative paths.
do_system($clone_packages,@verboseopt,@mirroropt,"-filter","$licence.*$codeline.*$filter",@packagelistopts,"-exec","--",
   "hg","--config","\"extensions.hgext.extdiff=\"","extdiff","-p",$churn_core,"-o",$churn_output_temp,
   "-r","$old","-r","$new_rev");

exit(0);
