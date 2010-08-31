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

my $raptor_warning_info = {};

my $characters = '';

my $CATEGORY_RAPTORWARNING = 'raptor_warning';
my $CATEGORY_RAPTORWARNING_MISSINGFLAGABIV2 = 'missing_enable_abiv2_mode';
my $CATEGORY_RAPTORWARNING_WHILESEARCHINGFORDEFFILEFILENOTFOUND = 'while_searching_for_deffile_file_not_found';
my $CATEGORY_RAPTORWARNING_EXPORTUNFROZENPRESENT = 'exportunfrozen_present';

sub process
{
	my ($text, $logfile, $component, $mmp, $phase, $recipe, $file) = @_;
	
	my $dumped = 1;
	
	my $category = $CATEGORY_RAPTORWARNING;
	my $severity = '';
	my $subcategory = '';
	
	if ($text =~ m,missing flag ENABLE_ABIV2_MODE,)
	{
		$severity = $RaptorCommon::SEVERITY_MINOR;
		my $subcategory = $CATEGORY_RAPTORWARNING_MISSINGFLAGABIV2;
		RaptorCommon::dump_fault($category, $subcategory, $severity, $logfile, $component, $mmp, $phase, $recipe, $file);
	}
	elsif ($text =~ m,While Searching for a SPECIFIED DEFFILE: file not found: .*,)
	{
		$severity = $RaptorCommon::SEVERITY_MINOR;
		my $subcategory = $CATEGORY_RAPTORWARNING_WHILESEARCHINGFORDEFFILEFILENOTFOUND;
		RaptorCommon::dump_fault($category, $subcategory, $severity, $logfile, $component, $mmp, $phase, $recipe, $file);
	}
	elsif ($text =~ m,EXPORTUNFROZEN present in .*,)
	{
		$severity = $RaptorCommon::SEVERITY_MAJOR;
		my $subcategory = $CATEGORY_RAPTORWARNING_EXPORTUNFROZENPRESENT;
		RaptorCommon::dump_fault($category, $subcategory, $severity, $logfile, $component, $mmp, $phase, $recipe, $file);
	}
	else # log everything by default
	{
		RaptorCommon::dump_fault($category, $subcategory, $severity, $logfile, $component, $mmp, $phase, $recipe, $file);
	}
	
	return $dumped;
}

sub on_start_buildlog
{
	RaptorCommon::init();
}

sub on_start_buildlog_warning
{
	my ($el) = @_;
	
	$raptor_warning_info = {};
	
	my $attributes = $el->{Attributes};
	for (keys %{$attributes})
	{
		$raptor_warning_info->{$attributes->{$_}->{'LocalName'}} = $attributes->{$_}->{'Value'};
		#print "$_ -> $attributes->{$_}->{'Value'}\n";
	}
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
	
	my $package = '';
	# if bldinf attribute is not available then heuristically attempt to determine the package
	if (!$raptor_warning_info->{bldinf} &&
		$characters =~ m,.*?([/\\]sf[/\\](os|mw|app|tools|ostools|adaptation|adapt)[/\\][a-zA-Z]+[/\\]?),s)
	{
		$raptor_warning_info->{bldinf} = "$1... (guessed)";
	}
	
	if ($raptor_warning_info->{bldinf})
	{
		$::allbldinfs->{$raptor_warning_info->{bldinf}} = 1;
		
		RaptorCommon::normalize_bldinf_path(\$raptor_warning_info->{bldinf});
		
		$package = RaptorCommon::get_package_subpath($raptor_warning_info->{bldinf});
		$package =~ s,/,_,g;
		if (!$package)
		{
			print "WARNING: can't understand bldinf attribute of raptor warning: $raptor_warning_info->{bldinf}. Won't associate to package.\n";
		}
	}
	
	if ($characters =~ m,[^\s^\r^\n],)
	{
		$filename = "$::raptorbitsdir/raptor_warning.txt";
		$filename = "$::raptorbitsdir/$package.txt" if ($package);
		my $filenamewnopath = "raptor_warning.txt";
		$filenamewnopath = "$package.txt" if ($package);
		
		if (!-f$filename)
		{
			print "Writing file $filename\n";
			open(FILE, ">$filename");
			close(FILE);
		}
		
		my $dumped = process($characters, $::current_log_file, $raptor_warning_info->{bldinf}, '', '', '', $filenamewnopath);
		
		if ($dumped)
		{
			open(FILE, ">>$filename");
			print FILE "---failure_item_$::failure_item_number\---\n";
			print FILE "$characters\n\n";
			close(FILE);
		}
	}
	
	$characters = '';
}


1;