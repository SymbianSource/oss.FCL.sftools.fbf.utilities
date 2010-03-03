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
my $failure_item = 0;

my $characters = '';
my $store_chars = 1;

my $CATEGORY_RAPTORUNRECIPED = 'raptor_unreciped';
my $CATEGORY_RAPTORUNRECIPED_NORULETOMAKETARGET = 'no_rule_to_make_target';
my $CATEGORY_RAPTORUNRECIPED_TARGETNOTREMADEFORERRORS = 'target_not_remade_for_errors';
my $CATEGORY_RAPTORUNRECIPED_IGNORINGOLDCOMMANDSFORTARGET = 'ignoring_old_commands_for_target';
my $CATEGORY_RAPTORUNRECIPED_OVERRIDINGCOMMANDSFORTARGET = 'overriding_commands_for_target';

sub process
{
	my ($text, $logfile, $component, $mmp, $phase, $recipe, $file, $line) = @_;

	my $category = $CATEGORY_RAPTORUNRECIPED;	
	my $severity = '';
	my $subcategory = '';
	
	if ($text =~ m,make\.exe: \*\*\* No rule to make target,)
	{
		$severity = $RaptorCommon::SEVERITY_MAJOR;
		my $subcategory = $CATEGORY_RAPTORUNRECIPED_NORULETOMAKETARGET;
		RaptorCommon::dump_fault($category, $subcategory, $severity, $logfile, $component, $mmp, $phase, $recipe, $file, $line);
	}
	elsif ($text =~ m,make\.exe: Target .* not remade because of errors,)
	{
		$severity = $RaptorCommon::SEVERITY_MINOR;
		my $subcategory = $CATEGORY_RAPTORUNRECIPED_TARGETNOTREMADEFORERRORS;
		RaptorCommon::dump_fault($category, $subcategory, $severity, $logfile, $component, $mmp, $phase, $recipe, $file, $line);
	}
	elsif ($text =~ m,: warning: ignoring old commands for target,)
	{
		$severity = $RaptorCommon::SEVERITY_MINOR;
		my $subcategory = $CATEGORY_RAPTORUNRECIPED_IGNORINGOLDCOMMANDSFORTARGET;
		RaptorCommon::dump_fault($category, $subcategory, $severity, $logfile, $component, $mmp, $phase, $recipe, $file, $line);
	}
	elsif ($text =~ m,: warning: overriding commands for target,)
	{
		$severity = $RaptorCommon::SEVERITY_MINOR;
		my $subcategory = $CATEGORY_RAPTORUNRECIPED_OVERRIDINGCOMMANDSFORTARGET;
		RaptorCommon::dump_fault($category, $subcategory, $severity, $logfile, $component, $mmp, $phase, $recipe, $file, $line);
	}
	elsif ($text =~ m,make\.exe: Nothing to be done for .*,)
	{
		# don't dump
	}
	elsif ($text =~ m,^(true|false)$,)
	{
		# don't dump
	}
	else # log everything by default
	{
		RaptorCommon::dump_fault($category, $subcategory, $severity, $logfile, $component, $mmp, $phase, $recipe, $file, $line);
	}
}

sub on_start_buildlog
{
	RaptorCommon::init();
	
	$filename = "$::raptorbitsdir/raptor_unreciped.txt";
	if (!-f$filename)
	{
		print "Writing unreciped file $filename\n";
		open(FILE, ">$filename");
		close(FILE);
	}
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
		if ($line =~ m,[^\s^\r^\n],)
		{
			#print "dumping chars\n";
			
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
			print FILE "$line\n\n";
			close(FILE);
			
			process($line, $::current_log_file, '', '', '', '', "raptor_unreciped.txt", $failure_item);
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
