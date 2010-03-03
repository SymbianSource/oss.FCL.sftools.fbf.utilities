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
# Raptor parser module.
# Extract, analyzes and dumps raptor warnings i.e. content of <warning> tags from a raptor log file

package RaptorWarning;

use strict;
use RaptorCommon;

our $reset_status = {};
my $buildlog_status = {};
my $buildlog_warning_status = {};

$reset_status->{name} = 'reset_status';
$reset_status->{next_status} = {buildlog=>$buildlog_status};

$buildlog_status->{name} = 'buildlog_status';
$buildlog_status->{next_status} = {warning=>$buildlog_warning_status};
$buildlog_status->{on_start} = 'RaptorWarning::on_start_buildlog';

$buildlog_warning_status->{name} = 'buildlog_warning_status';
$buildlog_warning_status->{next_status} = {};
$buildlog_warning_status->{on_start} = 'RaptorWarning::on_start_buildlog_warning';
$buildlog_warning_status->{on_end} = 'RaptorWarning::on_end_buildlog_warning';
$buildlog_warning_status->{on_chars} = 'RaptorWarning::on_chars_buildlog_warning';

my $filename = '';
my $failure_item = 0;

my $characters = '';

my $CATEGORY_RAPTORWARNING = 'raptor_warning';
my $CATEGORY_RAPTORWARNING_MISSINGFLAGABIV2 = 'missing_enable_abiv2_mode';

sub process
{
	my ($text, $logfile, $component, $mmp, $phase, $recipe, $file, $line) = @_;
	
	my $category = $CATEGORY_RAPTORWARNING;
	my $severity = '';
	my $subcategory = '';
	
	if ($text =~ m,missing flag ENABLE_ABIV2_MODE,)
	{
		$severity = $RaptorCommon::SEVERITY_MINOR;
		my $subcategory = $CATEGORY_RAPTORWARNING_MISSINGFLAGABIV2;
		RaptorCommon::dump_fault($category, $subcategory, $severity, $logfile, $component, $mmp, $phase, $recipe, $file, $line);
	}
	else # log everything by default
	{
		RaptorCommon::dump_fault($category, $subcategory, $severity, $logfile, $component, $mmp, $phase, $recipe, $file, $line);
	}
}

sub on_start_buildlog
{
	RaptorCommon::init();
	
	$filename = "$::raptorbitsdir/raptor_warning.txt";
	if (!-f$filename)
	{
		print "Writing warnings file $filename\n";
		open(FILE, ">$filename");
		close(FILE);
	}
}
sub on_start_buildlog_warning
{
	open(FILE, ">>$filename");
}

sub on_chars_buildlog_warning
{
	my ($ch) = @_;
	
	#print "on_chars_buildlog_warning\n";
	
	$characters .= $ch->{Data};
	
	#print "characters is now -->$characters<--\n";
}

sub on_end_buildlog_warning
{
	#print "on_end_buildlog_warning\n";
	
	$characters =~ s,^[\r\n]*,,;
	$characters =~ s,[\r\n]*$,,;
	
	if ($characters =~ m,[^\s^\r^\n],)
	{
		if ($failure_item == 0 and -f "$filename")
		{
			open(FILE, "$filename");
			{
				local $/ = undef;
				my $filecontent = <FILE>;
				$failure_item = $1 if ($filecontent =~ m/.*---failure_item_(\d+)/s);
			}
			close(FILE);
		}
		
		$failure_item++;
	
		open(FILE, ">>$filename");
		print FILE "---failure_item_$failure_item\---\n";
		print FILE "$characters\n\n";
		close(FILE);
		
		process($characters, $::current_log_file, '', '', '', '', "raptor_warning.txt", $failure_item);
	}
	
	$characters = '';
}


1;