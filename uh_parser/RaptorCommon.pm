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
# Common constants for the raptor parser suite

package RaptorCommon;

our $SEVERITY_CRITICAL = 'critical';
our $SEVERITY_MAJOR = 'major';
our $SEVERITY_MINOR = 'minor';

sub init
{
	my $filename = "$::raptorbitsdir/summary.csv";
	if (!-f$filename)
	{
		print "Writing summary file $filename\n";
		open(SUMMARY, ">$filename");
		close(SUMMARY);
	}
}

sub dump_fault
{
	my ($category, $subcategory, $severity, $location, $component, $mmp, $phase, $recipe, $file) = @_;
	
	$::failure_item_number++;
	
	open(SUMMARY, ">>$::raptorbitsdir/summary.csv");
	print SUMMARY "$category,$subcategory,$severity,$location,$component,$mmp,$phase,$recipe,$file,$::failure_item_number\n";
	close(SUMMARY);
}

sub normalize_bldinf_path
{
	my ($bldinfref) = @_;
	
	${$bldinfref} = lc(${$bldinfref});
	${$bldinfref} =~ s,^[A-Za-z]:,,;
	${$bldinfref} =~ s,[\\],/,g;
}

sub get_package_subpath
{
	my ($bldinf) = @_;
	
	my $package = '';
	
	if ($bldinf =~ m,(unknown/unknown),)
	{
		$package = 'unknown/unknown';
	}
	elsif ($bldinf =~ m,^/+?([^/]*?/[^/]*?/[^/]*?)/,)
	{
		$package = $1;
	}
	#elsif ($bldinf =~ m,^/+?([^/]*?/[^/]*?)/,)
	#{
	#	$package = $1;
	#}
	#elsif ($bldinf =~ m,^/+?([^/]*?)/,)
	#{
	#	$package = $1;
	#}
	
	return $package;
}

1;
