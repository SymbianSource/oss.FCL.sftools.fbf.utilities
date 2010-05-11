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
# Extract, analyzes and dumps raptor info text i.e. content of <info> tags from a raptor log file

package RaptorInfo;

use strict;
use RaptorCommon;

our $reset_status = {};
my $buildlog_status = {};
my $buildlog_info_status = {};

$reset_status->{name} = 'reset_status';
$reset_status->{next_status} = {buildlog=>$buildlog_status};

$buildlog_status->{name} = 'buildlog_status';
$buildlog_status->{next_status} = {info=>$buildlog_info_status};

$buildlog_info_status->{name} = 'buildlog_info_status';
$buildlog_info_status->{next_status} = {};
$buildlog_info_status->{on_start} = 'RaptorInfo::on_start_buildlog_info';
$buildlog_info_status->{on_end} = 'RaptorInfo::on_end_buildlog_info';
$buildlog_info_status->{on_chars} = 'RaptorInfo::on_chars_buildlog_info';

my $characters = '';

my $category = $RaptorCommon::CATEGORY_RAPTORINFO;

sub process
{
	my ($text) = @_;
	
	if ($text =~ m,Buildable configuration '(.*)',)
	{
		$::allconfigs->{$1}=1;	
	}
}

sub on_start_buildlog_info
{
	my $filename = "$::raptorbitsdir/info.txt";
	print "Writing info file $filename\n" if (!-f$filename);
	open(FILE, ">>$filename");
}

sub on_chars_buildlog_info
{
	my ($ch) = @_;
	
	#print "on_chars_buildlog_info\n";
	
	$characters .= $ch->{Data};
	
	#print "characters is now -->$characters<--\n";
}

sub on_end_buildlog_info
{
	#print "on_end_buildlog_info\n";
	
	process($characters);
	
	print FILE $characters if ($characters =~ m,[^\s^\r^\n],);
	print FILE "\n" if ($characters !~ m,[\r\n]$, );
	
	$characters = '';
	
	close(FILE);
}


1;