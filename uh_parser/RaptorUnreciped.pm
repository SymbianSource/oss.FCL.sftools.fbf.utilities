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
# Extract, analyzes and dumps text in <buildlog> context which doesn't belong to any <recipe> tags

package RaptorUnreciped;

use strict;
use RaptorCommon;

our $reset_status = {};
my $buildlog_status = {};
my $buildlog_subtag_status = {};

$reset_status->{name} = 'reset_status';
$reset_status->{next_status} = {buildlog=>$buildlog_status};

$buildlog_status->{name} = 'buildlog_status';
$buildlog_status->{next_status} = {'?default?'=>$buildlog_subtag_status};
$buildlog_status->{on_start} = 'RaptorUnreciped::on_start_buildlog';
$buildlog_status->{on_end} = 'RaptorUnreciped::on_end_buildlog';
$buildlog_status->{on_chars} = 'RaptorUnreciped::on_chars_buildlog';

$buildlog_subtag_status->{name} = 'buildlog_subtag_status';
$buildlog_subtag_status->{next_status} = {};
$buildlog_subtag_status->{on_start} = 'RaptorUnreciped::on_start_buildlog_subtag';
$buildlog_subtag_status->{on_end} = 'RaptorUnreciped::on_end_buildlog_subtag';

my $filename = '';

my $characters = '';
my $store_chars = 1;

my $CATEGORY_RAPTORUNRECIPED = 'raptor_unreciped';
my $CATEGORY_RAPTORUNRECIPED_IGNORINGOLDCOMMANDSFORTARGET = 'ignoring_old_commands_for_target';
my $CATEGORY_RAPTORUNRECIPED_OVERRIDINGCOMMANDSFORTARGET = 'overriding_commands_for_target';
my $CATEGORY_RAPTORUNRECIPED_MAKE_TARGETNOTREMADEBECAUSEOFERRORS = 'make_target_not_remade_because_of_errors';
my $CATEGORY_RAPTORUNRECIPED_MAKE_NORULETOMAKETARGETNEEDEDBY = 'make_no_rule_to_make_target_needed_by';
my $CATEGORY_RAPTORUNRECIPED_MAKE_NORULETOMAKETARGET = 'make_no_rule_to_make_target';

sub process
{
	my ($text, $logfile, $component, $mmp, $phase, $recipe, $file) = @_;
	
	my $dumped = 1;

	my $category = $CATEGORY_RAPTORUNRECIPED;	
	my $severity = '';
	my $subcategory = '';
	
	if ($text =~ m,: warning: ignoring old commands for target,)
	{
		# don't dump
		$dumped = 0;
	}
	elsif ($text =~ m,: warning: overriding commands for target,)
	{
		$severity = $RaptorCommon::SEVERITY_MINOR;
		my $subcategory = $CATEGORY_RAPTORUNRECIPED_OVERRIDINGCOMMANDSFORTARGET;
		RaptorCommon::dump_fault($category, $subcategory, $severity, $logfile, $component, $mmp, $phase, $recipe, $file);
	}
	elsif ($text =~ m,^make(\.exe)?: \*\*\* No rule to make target .* needed by .*,)
	{
		$severity = $RaptorCommon::SEVERITY_MAJOR;
		my $subcategory = $CATEGORY_RAPTORUNRECIPED_MAKE_NORULETOMAKETARGETNEEDEDBY;
		RaptorCommon::dump_fault($category, $subcategory, $severity, $logfile, $component, $mmp, $phase, $recipe, $file);
	}
	elsif ($text =~ m,^make(\.exe)?: \*\*\* No rule to make target .*,)
	{
		$severity = $RaptorCommon::SEVERITY_MAJOR;
		my $subcategory = $CATEGORY_RAPTORUNRECIPED_MAKE_NORULETOMAKETARGET;
		RaptorCommon::dump_fault($category, $subcategory, $severity, $logfile, $component, $mmp, $phase, $recipe, $file);
	}
	elsif ($text =~ m,^make(\.exe)?: \*\*\* .* Error \d,)
	{
		# don't dump
		$dumped = 0;
	}
	elsif ($text =~ m,^make(\.exe)?: Target .* not remade because of errors,)
	{
		# don't dump
		$dumped = 0;
	}
	elsif ($text =~ m,^make(\.exe)?: Nothing to be done for .*,)
	{
		# don't dump
		$dumped = 0;
	}
	elsif ($text =~ m,^(true|false)$,)
	{
		# don't dump
		$dumped = 0;
	}
	elsif ($text =~ m,win32/cygwin/bin/cp\.exe,)
	{
		# don't dump
		$dumped = 0;
	}
	elsif ($text =~ m,epoc32/tools/svgtbinencode\.exe,)
	{
		# don't dump
		$dumped = 0;
	}
	elsif ($text =~ m,win32/cygwin/bin/chmod\.exe a\+rw,)
	{
		# don't dump
		$dumped = 0;
	}
	elsif ($text =~ m,^make(\.exe)?: \*\*\* Waiting for unfinished jobs\.\.\.\.,)
	{
		# don't dump
		$dumped = 0;
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

sub on_chars_buildlog
{
	my ($ch) = @_;
	
	#print "on_chars_buildlog\n";
	
	if ($store_chars)
	{
		$characters .= $ch->{Data};
		
		#print "characters is now -->$characters<--\n";
	}
}

sub on_end_buildlog_subtag
{
	$store_chars = 1;
}

sub process_characters
{
	#print "process_characters\n";
	
	$characters =~ s,^[\r\n]*,,;
	$characters =~ s,[\r\n]*$,,;
	
	#print "characters is -->$characters<--\n";
	
	my @lines = split(/[\r\n]/, $characters);
	for my $line (@lines)
	{
		my $package = '';
		my $guessed_bldinf = '';
		# if bldinf attribute is not available then heuristically attempt to determine the package
		if ($line =~ m,.*?([/\\]sf[/\\](os|mw|app|tools|ostools|adaptation|adapt)[/\\][a-zA-Z]+[/\\]?),s)
		{
			$guessed_bldinf = "$1... (guessed)";
		}
		
		if ($guessed_bldinf)
		{
			$::allbldinfs->{$guessed_bldinf} = 1;
			
			RaptorCommon::normalize_bldinf_path(\$guessed_bldinf);
			
			$package = RaptorCommon::get_package_subpath($guessed_bldinf);
			$package =~ s,/,_,g;
		}
			
		if ($line =~ m,[^\s^\r^\n],)
		{
			$filename = "$::raptorbitsdir/raptor_unreciped.txt";
			$filename = "$::raptorbitsdir/$package.txt" if ($package);
			my $filenamewnopath = "raptor_unreciped.txt";
			$filenamewnopath = "$package.txt" if ($package);
			
			if (!-f$filename)
			{
				print "Writing file $filename\n";
				open(FILE, ">$filename");
				close(FILE);
			}
		
			my $dumped = process($line, $::current_log_file, $guessed_bldinf, '', '', '', $filenamewnopath);
			
			if ($dumped)
			{
				open(FILE, ">>$filename");
				print FILE "---failure_item_$::failure_item_number\---\n";
				print FILE "$line\n\n";
				close(FILE);
			}
		}
	}
	
	$characters = '';
	$store_chars = 0;
}

sub on_start_buildlog_subtag
{
	#print "on_start_buildlog_subtag\n";
	
	process_characters();
}

sub on_end_buildlog
{
	process_characters();
}


1;
