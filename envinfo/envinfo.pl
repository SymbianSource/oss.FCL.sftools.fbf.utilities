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
# Dumps environment info such as tools version to cmdline or optionally to a Diamonds file

use strict;

use Getopt::Long;

my $output = "\\output\\logs\\diamonds_envinfo.xml";
my $diamonds = 0;
my $help = 0;
GetOptions((
	'diamonds!' => \$diamonds,
	'out=s' => \$output,
	'help!' => \$help
));

if ($help)
{
	print "Dumps environment info such as tools version to cmdline or optionally to a Diamonds file\n";
	print "Usage: perl envinfo.pl [-d [-o XMLFILE]]\n";
	print "\n";
	print "-d,--diamonds\tcreate Diamonds file with environment info\n";
	print "-o,--out XMLFILE Diamonds file to write to (default \\output\\logs\\diamonds_envinfo.xml)\n";
	exit(0);
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
$perl_ver = $1 if ($perl_out =~ /This is perl, v(\S+)/m);
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
	my $gcc441_cmd = "$gcc441_path\\arm-none-symbianelf-g++ -dumpversion";
	my $gcc441_out = `$gcc441_cmd`;
	$gcc441_ver = "4.4.1" if ($gcc441_out =~ /4.4.1/);
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

for my $tool_info (@environment_info)
{
	print $tool_info->{name} . ": " . $tool_info->{version} . "\n";
}


# write diamonds file
if ($diamonds)
{
	@environment_info = reverse(@environment_info);
	
	my $xml_content = <<_EOX;
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<diamonds-build>
 <schema>10</schema>
  <tools>        
_HERE_TOOLS_LINES_
  </tools>
</diamonds-build>
_EOX
	
	my $tools_lines = '';
	for my $tool_info (@environment_info)
	{
		$tools_lines .= "   <tool><name>$tool_info->{name}</name><version>$tool_info->{version}</version></tool>\n";
	}
	
	$xml_content =~ s/_HERE_TOOLS_LINES_/$tools_lines/;
	
	if (open(ENVINFO, ">$output"))
	{
		print ENVINFO $xml_content;
		close(ENVINFO);
		print "Wrote Diamonds file: $output\n";
	}
	else
	{
		warn "Could not write to file: $output\n";
	}
}