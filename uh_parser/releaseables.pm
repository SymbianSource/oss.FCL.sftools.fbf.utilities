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
# Extract releaseable (whatlog) information

package releaseables;

use File::Path;
use File::Find;

use strict;

our $reset_status = {};
my $buildlog_status = {};
my $whatlog_status = {};
my $bitmap_status = {};
my $resource_status = {};
my $build_status = {};
my $export_status = {};
my $stringtable_status = {};
my $archive_status = {};
my $archive_member_status = {};
my $whatlog_default_status = {};

$reset_status->{name} = 'reset_status';
$reset_status->{next_status} = {buildlog=>$buildlog_status};

$buildlog_status->{name} = 'buildlog_status';
$buildlog_status->{next_status} = {whatlog=>$whatlog_status};
$buildlog_status->{on_start} = 'releaseables::on_start_buildlog';

$whatlog_status->{name} = 'whatlog_status';
$whatlog_status->{next_status} = {bitmap=>$bitmap_status, resource=>$resource_status, build=>$build_status, export=>$export_status, stringtable=>$stringtable_status, archive=>$archive_status, '?default?'=>$whatlog_default_status};
$whatlog_status->{on_start} = 'releaseables::on_start_whatlog';
$whatlog_status->{on_end} = 'releaseables::on_end_whatlog';

$bitmap_status->{name} = 'bitmap_status';
$bitmap_status->{next_status} = {};
$bitmap_status->{on_start} = 'releaseables::on_start_bitmap';
$bitmap_status->{on_end} = 'releaseables::on_end_whatlog_subtag';
$bitmap_status->{on_chars} = 'releaseables::on_chars_whatlog_subtag';

$resource_status->{name} = 'resource_status';
$resource_status->{next_status} = {};
$resource_status->{on_start} = 'releaseables::on_start_resource';
$resource_status->{on_end} = 'releaseables::on_end_whatlog_subtag';
$resource_status->{on_chars} = 'releaseables::on_chars_whatlog_subtag';

$build_status->{name} = 'build_status';
$build_status->{next_status} = {};
$build_status->{on_start} = 'releaseables::on_start_build';
$build_status->{on_end} = 'releaseables::on_end_whatlog_subtag';
$build_status->{on_chars} = 'releaseables::on_chars_whatlog_subtag';

$stringtable_status->{name} = 'stringtable_status';
$stringtable_status->{next_status} = {};
$stringtable_status->{on_start} = 'releaseables::on_start_stringtable';
$stringtable_status->{on_end} = 'releaseables::on_end_whatlog_subtag';
$stringtable_status->{on_chars} = 'releaseables::on_chars_whatlog_subtag';

$archive_status->{name} = 'archive_status';
$archive_status->{next_status} = {member=>$archive_member_status};

$archive_member_status->{name} = 'archive_member_status';
$archive_member_status->{next_status} = {};
$archive_member_status->{on_start} = 'releaseables::on_start_archive_member';
$archive_member_status->{on_end} = 'releaseables::on_end_whatlog_subtag';
$archive_member_status->{on_chars} = 'releaseables::on_chars_whatlog_subtag';

$export_status->{name} = 'export_status';
$export_status->{next_status} = {};
$export_status->{on_start} = 'releaseables::on_start_export';

$whatlog_default_status->{name} = 'whatlog_default_status';
$whatlog_default_status->{next_status} = {};
$whatlog_default_status->{on_start} = 'releaseables::on_start_whatlog_default';

my $whatlog_info = {};
my $curbldinf = 'unknown';
my $curconfig = 'unknown';
my $curfiletype = 'unknown';
my $characters = '';

sub on_start_buildlog
{
	
}

sub on_start_whatlog
{
	my ($el) = @_;
	
	$whatlog_info = {};
	
	my $bldinf = '';
	my $config = '';
	my $attributes = $el->{Attributes};
	for (keys %{$attributes})
	{
		#print "reading attribute $_\n";
		if ($attributes->{$_}->{'LocalName'} eq 'bldinf')
		{
			$bldinf = $attributes->{$_}->{'Value'};
			#print "bldinf=$bldinf\n";
		}
		elsif ($attributes->{$_}->{'LocalName'} eq 'config')
		{
			$config = $attributes->{$_}->{'Value'};
			$config =~ s,\.whatlog$,,;
		}
	}
	
	if ($bldinf eq '')
	{
		print "WARNING: whatlog tag with no bldinf attribute. Skipping\n";
		return;
	}
	
	$curbldinf = $bldinf;
	$curconfig = $config;
	$whatlog_info->{$curbldinf} = {} if (!defined $whatlog_info->{$curbldinf});
	$whatlog_info->{$curbldinf}->{$curconfig} = {} if (!defined $whatlog_info->{$curbldinf}->{$curconfig});
}

sub on_start_whatlog_subtag
{
	my ($ft) = @_;
	
	$curfiletype = $ft;
	$characters = '';
	$whatlog_info->{$curbldinf}->{$curconfig}->{$curfiletype} = [] if (! defined $whatlog_info->{$curbldinf}->{$curconfig}->{$curfiletype});
}

sub on_chars_whatlog_subtag
{
	my ($ch) = @_;
	
	$characters .= $ch->{Data};
	
	#print "characters is now -->$characters<--\n";
}

sub on_end_whatlog_subtag
{
	$characters = normalize_filepath($characters);
	
	push(@{$whatlog_info->{$curbldinf}->{$curconfig}->{$curfiletype}}, $characters);
	
	$curfiletype = 'unknown';
	$characters = '';
}

sub on_start_bitmap
{
	on_start_whatlog_subtag('bitmap');
}

sub on_start_resource
{
	on_start_whatlog_subtag('resource');
}

sub on_start_build
{
	on_start_whatlog_subtag('build');
}

sub on_start_stringtable
{
	on_start_whatlog_subtag('stringtable');
}

sub on_start_archive_member
{
	on_start_whatlog_subtag('export');
}

sub on_start_export
{
	my ($el) = @_;
	
	$whatlog_info->{$curbldinf}->{$curconfig}->{export} = [] if (! defined $whatlog_info->{$curbldinf}->{$curconfig}->{export});
	
	my $destination = '';
	my $attributes = $el->{Attributes};
	for (keys %{$attributes})
	{
		#print "reading attribute $_\n";
		if ($attributes->{$_}->{'LocalName'} eq 'destination')
		{
			$destination = $attributes->{$_}->{'Value'};
			#print "destination=$destination\n";
			last;
		}
	}
	
	if ($destination eq '')
	{
		print "WARNING: export tag with no destination attribute. Skipping\n";
		return;
	}
	
	$destination = normalize_filepath($destination);
	
	push(@{$whatlog_info->{$curbldinf}->{$curconfig}->{export}}, $destination);
}

sub on_end_whatlog
{
	my $unknown_counter = 0;
	
	for my $bldinf (keys %{$whatlog_info})
	{
		for my $config (keys %{$whatlog_info->{$bldinf}})
		{
			my $normalized = $bldinf;
			RaptorCommon::normalize_bldinf_path(\$normalized);
			
			my $package = RaptorCommon::get_package_subpath($normalized);
			
			mkpath("$::releaseablesdir/$package");
			
			my $filename = "$::releaseablesdir/$package/info.tsv";
			$package =~ s,/,_,g;
			my $filenamemissing = "$::raptorbitsdir/$package\_missing.txt" if ($::missing);
			
			print "Writing info file $filename\n" if (!-f$filename);
			open(FILE, ">>$filename");
			
			for my $filetype (keys %{$whatlog_info->{$bldinf}->{$config}})
			{
				for (sort(@{$whatlog_info->{$bldinf}->{$config}->{$filetype}}))
				{
					print FILE "$_\t$filetype\t$config\n";
					my $file = $_;
					
					if($::missing && !-f $file)
					{
            open(MISSING, ">>$filenamemissing");
            print MISSING $file."\n";
            close(MISSING);
          }
				}
			}
			close(FILE);
		}
	}
}

sub count_distinct
{
	my @files;
    my $finder = sub {
        return if ! -f;
        return if ! /\.tsv$/;
        push @files, $File::Find::name;
    };
    find($finder, $::releaseablesdir);
	
	for my $file (@files)
	{
		#print "counting distinct releasables in file $file\n";
		my $escaped_releaseablesdir = quotemeta($::releaseablesdir);
		$file =~ m/$escaped_releaseablesdir[\\\/]*(.*)[\\\/]info\.tsv/;
		my $package = $1;
		$package =~ s,\\,/,g;
		
		my @releasables;
		open(FILE, $file);
		while (<FILE>)
		{
			my $line = $_;
			next if ($line !~ /^([^\t]*)\t[^\t]*\t[^\t]*$/);
			push @releasables, $1;
		}
		close(FILE);
		#for my $r (@releasables) {print "$r\n";}
		#print "\n\n\n\n";
		my $previous = '';
		my @distincts = grep {$_ ne $previous && ($previous = $_, 1) } sort @releasables;
		
		my $nd = scalar(@distincts);
		#print "adding $package -> $nd to releaseables_by_package\n";
		$::releaseables_by_package->{$package} = $nd;
	}
}

sub remove_missing_duplicates
{
	opendir(DIR, $::raptorbitsdir);
    my @files = grep((-f "$::raptorbitsdir/$_" && $_ !~ /^\.\.?$/ && $_ =~ /_missing\.txt$/), readdir(DIR));
    close(DIR);

	for my $file (@files)
	{
		open(FILE, "+<$::raptorbitsdir/$file");	
		#print "working on $file\n";	
	
		# Read it
		my @content = <FILE>;

		# Sort it, and grep to remove duplicates
		my $previous = "\n\n";
		@content = grep {$_ ne $previous && ($previous = $_, 1) } sort @content;

		# Write it
		seek(FILE, 0, 0);
		print FILE @content;
		truncate(FILE,tell(FILE));
	
		close(FILE);
	}
}

sub normalize_filepath
{
	my ($filepath) = @_;
	
	if ($filepath =~ m,[^\s^\r^\n]+(.*)[\r\n]+(.*)[^\s^\r^\n]+,)
	{
		print "WARNING: file path string extends over multiple line: $filepath. Removing all NL's and CR's\n";
	}
	
	# strip all CR's and NL's
	$filepath =~ s,[\r\n],,g;
	
	# strip all whitespaces at string start/end
	$filepath =~ s,^\s+,,g;
	$filepath =~ s,\s+$,,g;
	
	# remove drive letter and colon from the beginning of the string
	$filepath =~ s,^[A-Za-z]:,,;
	
	# normalize slashes
	$filepath =~ s,\\,/,g;
	$filepath =~ s,//,/,g;
	
	if ($filepath !~ m,^/epoc32/,i)
	{
		print "WARNING: file '$filepath' doesn't seem valid. Writing to info file anyway\n";
	}
	
	return $filepath;
}

sub on_start_whatlog_default
{
	my ($el) = @_;
	
	my $tagname = $el->{LocalName};
	
	print "WARNING: unsupported tag '$tagname' in <whatlog> context\n";
}

1;