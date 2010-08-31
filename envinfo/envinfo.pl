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
# Dumps environment info such as tools version to cmdline and/or to a file.
# Compare environment info with a baseline

use strict;

use Getopt::Long;

my $report;
my $output = "$ENV{'EPOCROOT'}\\output\\logs\\envinfo.txt";
$output =~ s/^\\+/\\/;
my $compare;
my $baseline = "$ENV{'EPOCROOT'}\\build_info\\logs\\envinfo.txt";
$baseline =~ s/^\\+/\\/;
my $help = 0;
GetOptions((
	'report:s' => \$report,
	'compare:s' => \$compare,
	'help!' => \$help
));

$output = $report if ($report);
$baseline = $compare if ($compare);

if ($help)
{
print <<_EOH;
envinfo
Dumps environment info such as tools version to cmdline and/or to a file
Compare info with a baseline

Usage: envinfo.pl [options]

Options:
  -h, --help            Show this help message and exit
  -r,--report [FILE]    Write report to FILE (default %EPOCROOT%\\output\\logs\\envinfo.txt)
  -c,--compare [LOCATION]
                        Compare environment with info at LOCATION
                        (default %EPOCROOT%\\build_info\\logs\\envinfo.txt)
_EOH
	exit(0);
}

my $baseline_environment_info = {};
if (defined $compare)
{
	my $target = '';
	my $tmp_file = '';
	# understand where we should get the info from
	$target = $baseline if (-f $baseline);
	$target = "$baseline\\envinfo.txt" if (!$target && -f "$baseline\\envinfo.txt");
	$target = "$baseline\\build_info\\logs\\envinfo.txt" if (!$target && -f "$baseline\\build_info\\logs\\envinfo.txt");
	$target = "$baseline\\build_BOM.zip" if (!$target && -f "$baseline\\build_BOM.zip");
	$target = "$baseline\\output\\logs\\envinfo.txt" if (!$target && -f "$baseline\\output\\logs\\envinfo.txt");
	$target = "$baseline\\output\\zips\\release\\build_BOM.zip" if (!$target && -f "$baseline\\output\\zips\\release\\build_BOM.zip");
	if (!$target)
	{
		warn "WARNING: Can't find envinfo.txt from location '$baseline'\n";
	}
	elsif ($target =~ /\.zip$/)
	{
		print "Extracting envinfo.txt from $target\n";
		my $cmd = "7z e -y $target build_info\\logs\\BOM\\envinfo.txt";
		my $output = `$cmd 2>&1`;
		if ($output =~ /is not recognized as an internal or external command/)
		{
			$target = '';
			warn "WARNING: You need to have 7z in the PATH if you want to do comparison against a compressed baseline\n";
		}
		elsif ($output =~ /No files to process/)
		{
			$target = '';
			warn "WARNING: The compressed baseline doesn't seem to contain an envinfo.txt file\n";
		}
		else
		{
			$tmp_file = "tmp$$.txt";
			system("ren envinfo.txt $tmp_file"); 
			$target = $tmp_file;
		}
	}
	
	if (!$target)
	{
		warn "WARNING: Will not do comparison\n";
		$compare = undef; 
	}
	else
	{
		print "Will compare environment info to $target\n";
		
		if (open(BASEINFO, $target))
		{
			for my $line (<BASEINFO>)
			{
				if ($line =~ /([^\t]*)\t([^\t]*)/)
				{
					my $name = $1;
					my $version = $2;
					chomp $name;
					chomp $version;
					$baseline_environment_info->{$name}=$version;
				}
			}
			close(BASEINFO);
			unlink $tmp_file if ($tmp_file);
		}
		else
		{
			warn "WARNING: Could not open file $target for reading. Will not do comparison\n";
			$compare = undef;
		}
	}
	
}


my @environment_info = ();

# Machine name
push @environment_info, {name=>'Machine', version=>$ENV{'COMPUTERNAME'}};

# OS Name and Version
my $os_name = 'N.A.';
my $os_ver = 'N.A.';
my $os_out = `systeminfo`;
$os_name = $1 if ($os_out =~ /^OS Name:\s+(.*)/m);
$os_ver = $1 if ($os_out =~ /^OS Version:\s+(.*)/m);
push @environment_info, {name=>'OS Name', version=>$os_name};
push @environment_info, {name=>'OS Version', version=>$os_ver};

# Perl
my $perl_ver = 'N.A.';
my $perl_out = `perl -v`;

# match: 
#match This is perl, v5.10.0 built for darwin-thread-multi-2level
if($perl_out =~ /This is perl, v(\S+)/m)
{
	$perl_ver = $1;
}
# match:
# This is perl 5, version 12, subversion 1 (v5.12.1) built for MSWin32-x64-multi-thread
elsif($perl_out =~ /This is perl.*? \(v(\S+)\)/m)
{
	$perl_ver = $1;
}

push @environment_info, {name=>'Perl', version=>$perl_ver};

# Python
my $python_ver = 'N.A.';
my $python_out = `python -V 2>&1`;
$python_ver = $1 if ($python_out =~ /^Python\s+(\S+)/m);
push @environment_info, {name=>'Python', version=>$python_ver};

# Mercurial
my $hg_ver = 'N.A.';
my $hg_out = `hg --version`;
$hg_ver = $1 if ($hg_out =~ /^Mercurial Distributed SCM \(version ([^)]+)\)/m);
push @environment_info, {name=>'Mercurial', version=>$hg_ver};

# 7-Zip
my $zip_ver = 'N.A.';
my $zip_out = `7z`;
$zip_ver = $1 if ($zip_out =~ /^7-Zip\s+(\S+)\s+Copyright/m);
push @environment_info, {name=>'7-Zip', version=>$zip_ver};

# EPOCROOT
my $epocroot_ver = 'N.A.';
my $epocroot_out = `echo %EPOCROOT%`;
chomp $epocroot_out;
$epocroot_ver = $epocroot_out if ($epocroot_out ne '%EPOCROOT%');
push @environment_info, {name=>'EPOCROOT', version=>$epocroot_ver};

# Raptor
my $sbs_ver = 'N.A.';
my $sbs_out = `sbs -v`;
$sbs_ver = $1 if ($sbs_out =~ /^sbs version (.*)/m);
push @environment_info, {name=>'sbs', version=>$sbs_ver};

# Metrowerk Compiler
my $mwcc_ver = 'N.A.';
my $mwcc_out = `mwccsym2 -version`;
$mwcc_ver = $1 if ($mwcc_out =~ /^Version (.*)/m);
push @environment_info, {name=>'mwccsym2', version=>$mwcc_ver};

# RVCT 2.2
my $rvct22_ver = 'N.A.';
my $rvct22_path = '';
if (defined $ENV{'SBS_RVCT22BIN'})
{
	$rvct22_path = $ENV{'SBS_RVCT22BIN'};
}
elsif (defined $ENV{'RVCT22BIN'})
{
	$rvct22_path = $ENV{'RVCT22BIN'};
}
my $rvct22_cmd = 'armcc 2>&1';
$rvct22_cmd = "$rvct22_path\\$rvct22_cmd" if ($rvct22_path);
my $rvct22_out = `$rvct22_cmd`;
$rvct22_ver = $1 if ($rvct22_out =~ m#ARM/Thumb C/C\+\+ Compiler, RVCT2.2 (.*)#m);
push @environment_info, {name=>'RVCT2.2', version=>$rvct22_ver};

# RVCT 4.0
my $rvct40_ver = 'N.A.';
my $rvct40_path = '';
if (defined $ENV{'SBS_RVCT40BIN'})
{
	$rvct40_path = $ENV{'SBS_RVCT40BIN'};
}
elsif (defined $ENV{'RVCT40BIN'})
{
	$rvct40_path = $ENV{'RVCT40BIN'};
}
my $rvct40_cmd = 'armcc 2>&1';
$rvct40_cmd = "$rvct40_path\\$rvct40_cmd" if ($rvct40_path);
my $rvct40_out = `$rvct40_cmd`;
$rvct40_ver = $1 if ($rvct40_out =~ m#ARM C/C\+\+ Compiler, RVCT4.0 (.*)#m);
push @environment_info, {name=>'RVCT4.0', version=>$rvct40_ver};

# GCCE 4.4.1
my $gcc441_ver = 'N.A.';
my $gcc441_path = '';
if (defined $ENV{'SBS_GCCE441BIN'})
{
	$gcc441_path = $ENV{'SBS_GCCE441BIN'};
}
elsif (defined $ENV{'GCCE441BIN'})
{
	$gcc441_path = $ENV{'GCCE441BIN'};
}
if ($gcc441_path)
{
	my $gcc441_cmd = "$gcc441_path\\arm-none-symbianelf-g++ --version";
	my $gcc441_out = `$gcc441_cmd`;
	$gcc441_ver = $1 if ($gcc441_out =~ /arm-none-symbianelf-g\+\+\ (.*)/);
}
push @environment_info, {name=>'GCC4.4.1', version=>$gcc441_ver};

# Helium
my $helium_ver = 'N.A.';
if ($ENV{'HELIUM_HOME'} && -f "$ENV{'HELIUM_HOME'}\\config\\version.txt")
{
	open(VERSION, "$ENV{'HELIUM_HOME'}\\config\\version.txt");
	my $line = '';
	while ($line = <VERSION>)
	{
		$helium_ver = $1 if ($line =~ /^helium\.version=(.*)/);
	}
	close(VERSION);
}
push @environment_info, {name=>'helium', version=>$helium_ver};

# java
my $java_ver = 'N.A.';
my $java_out = `java -version 2>&1`;
$java_ver = $1 if ($java_out =~ /^java version (.*)/m);
push @environment_info, {name=>'java', version=>$java_ver};

# change tabs to spaces
for my $tool_info (@environment_info)
{
	$tool_info->{name} =~ s/\t/ /g;
	$tool_info->{version} =~ s/\t/ /g;
}

print "\nEnvironment Information:\n";

my $cmp_notpresent = 0;
my $cmp_diffver = 0;
for my $tool_info (@environment_info)
{
	print " " . $tool_info->{name} . ": " . $tool_info->{version};
	
	if (defined $compare &&
		$tool_info->{name} ne 'Machine' &&
		$tool_info->{name} ne 'OS Name' &&
    $tool_info->{name} ne 'EPOCROOT')
	{
		print "\t";
		if (defined $baseline_environment_info->{$tool_info->{name}})
		{
			my $baselineversion = $baseline_environment_info->{$tool_info->{name}};
			if ($tool_info->{version} eq 'N.A.' && $baselineversion ne 'N.A.')
			{
				print "[ERROR: tool not present]";
				$cmp_notpresent++;
			}
			elsif ($tool_info->{version} eq $baselineversion || $baselineversion eq 'N.A.')
			{
				print "[OK]";
			}
			elsif (($tool_info->{version} cmp $baselineversion) < 0)
			{
				print "[WARNING: less recent than baseline]";
				$cmp_diffver++;
			}
			elsif (($tool_info->{version} cmp $baselineversion) > 0)
			{
				print "[WARNING: more recent than baseline]";
				$cmp_diffver++;
			}
		}
	}
	print "\n";
}

print "\n";

if (defined $compare)
{
	print "Summary of comparison to baseline:\n";
	if ($cmp_notpresent || $cmp_diffver)
	{
		print " Tools not present or not found in the expected location: $cmp_notpresent\n";
		print " Tools at different version: $cmp_diffver\n";
	}
	else
	{
		print " All tools seem to match the baseline :-)\n";
	}
	print "\n";
}

# write report file
if (defined $report)
{
	if (open(ENVINFO, ">$output"))
	{
		for my $tool_info (@environment_info)
		{
			print ENVINFO "$tool_info->{name}\t$tool_info->{version}\n";
		}
		close(ENVINFO);
		print "Wrote report file: $output\n";
	}
	else
	{
		warn "WARNING: Could not write to file: $output\n";
	}
}
