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
	my ($category, $subcategory, $severity, $location, $component, $mmp, $phase, $recipe, $file, $line) = @_;
	
	open(SUMMARY, ">>$::raptorbitsdir/summary.csv");
	print SUMMARY "$category,$subcategory,$severity,$location,$component,$mmp,$phase,$recipe,$file,$line\n";
	close(SUMMARY);
}

1;
