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
# Extract, analyzes and dumps raptor errors i.e. content of <error> tags from a raptor log file

package RaptorError;

use strict;
use RaptorCommon;

our $reset_status = {};
my $buildlog_status = {};
my $buildlog_error_status = {};

$reset_status->{name} = 'reset_status';
$reset_status->{next_status} = {buildlog=>$buildlog_status};

$buildlog_status->{name} = 'buildlog_status';
$buildlog_status->{next_status} = {error=>$buildlog_error_status};
$buildlog_status->{on_start} = 'RaptorError::on_start_buildlog';

$buildlog_error_status->{name} = 'buildlog_error_status';
$buildlog_error_status->{next_status} = {};
$buildlog_error_status->{on_start} = 'RaptorError::on_start_buildlog_error';
$buildlog_error_status->{on_end} = 'RaptorError::on_end_buildlog_error';
$buildlog_error_status->{on_chars} = 'RaptorError::on_chars_buildlog_error';

my $filename = '';
my $failure_item = 0;

my $characters = '';

my $CATEGORY_RAPTORERROR = 'raptor_error';
my $CATEGORY_RAPTORERROR_CANNOTPROCESSSCHEMAVERSION = 'cannot_process_schema_version';
my $CATEGORY_RAPTORERROR_NOBLDINFFOUND = 'no_bld_inf_found';
my $CATEGORY_RAPTORERROR_CANTFINDMMPFILE = 'cant_find_mmp_file';
my $CATEGORY_RAPTORERROR_MAKEEXITEDWITHERRORS = 'make_exited_with_errors';
my $CATEGORY_RAPTORERROR_TOOLDIDNOTRETURNVERSION = 'tool_didnot_return_version';
my $CATEGORY_RAPTORERROR_UNKNOWNBUILDCONFIG = 'unknown_build_config';
my $CATEGORY_RAPTORERROR_NOBUILDCONFIGSGIVEN = 'no_build_configs_given';

sub process
{
	my ($text, $logfile, $component, $mmp, $phase, $recipe, $file, $line) = @_;
	
	my $category = $CATEGORY_RAPTORERROR;
	my $severity = '';
	my $subcategory = '';
	
	if ($text =~ m,Cannot process schema version .* of file,)
	{
		$severity = $RaptorCommon::SEVERITY_CRITICAL;
		$subcategory = $CATEGORY_RAPTORERROR_CANNOTPROCESSSCHEMAVERSION;
		RaptorCommon::dump_fault($category, $subcategory, $severity, $logfile, $component, $mmp, $phase, $recipe, $file, $line);
	}
	elsif ($text =~ m,No bld\.inf found at,)
	{
		$severity = $RaptorCommon::SEVERITY_MAJOR;
		$subcategory = $CATEGORY_RAPTORERROR_NOBLDINFFOUND;
		RaptorCommon::dump_fault($category, $subcategory, $severity, $logfile, $component, $mmp, $phase, $recipe, $file, $line);
	}
	elsif ($text =~ m,Can't find mmp file,)
	{
		$severity = $RaptorCommon::SEVERITY_MINOR;
		$subcategory = $CATEGORY_RAPTORERROR_CANTFINDMMPFILE;
		RaptorCommon::dump_fault($category, $subcategory, $severity, $logfile, $component, $mmp, $phase, $recipe, $file, $line);
	}
	elsif ($text =~ m,The make-engine exited with errors,)
	{
		$severity = $RaptorCommon::SEVERITY_CRITICAL;
		$subcategory = $CATEGORY_RAPTORERROR_MAKEEXITEDWITHERRORS;
		RaptorCommon::dump_fault($category, $subcategory, $severity, $logfile, $component, $mmp, $phase, $recipe, $file, $line);
	}
	elsif ($text =~ m,tool .* from config .* did not return version .* as required,)
	{
		$severity = $RaptorCommon::SEVERITY_CRITICAL;
		$subcategory = $CATEGORY_RAPTORERROR_TOOLDIDNOTRETURNVERSION;
		RaptorCommon::dump_fault($category, $subcategory, $severity, $logfile, $component, $mmp, $phase, $recipe, $file, $line);
	}
	elsif ($text =~ m,Unknown build configuration '.*',)
	{
		$severity = $RaptorCommon::SEVERITY_CRITICAL;
		$subcategory = $CATEGORY_RAPTORERROR_UNKNOWNBUILDCONFIG;
		RaptorCommon::dump_fault($category, $subcategory, $severity, $logfile, $component, $mmp, $phase, $recipe, $file, $line);
	}
	elsif ($text =~ m,No build configurations given,)
	{
		$severity = $RaptorCommon::SEVERITY_CRITICAL;
		$subcategory = $CATEGORY_RAPTORERROR_NOBUILDCONFIGSGIVEN;
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
	
	$filename = "$::raptorbitsdir/raptor_error.txt";
	if (!-f$filename)
	{
		print "Writing errors file $filename\n";
		open(FILE, ">$filename");
		close(FILE);
	}
}

sub on_start_buildlog_error
{
}

sub on_chars_buildlog_error
{
	my ($ch) = @_;
	
	#print "on_chars_buildlog_error\n";
	
	$characters .= $ch->{Data};
	
	#print "characters is now -->$characters<--\n";
}

sub on_end_buildlog_error
{
	#print "on_end_buildlog_error\n";
	
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
		
		process($characters, $::current_log_file, '', '', '', '', "raptor_error.txt", $failure_item);
	}
	
	$characters = '';
}


1;