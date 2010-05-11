#!perl -w
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
# Preprocess a raptor log, trying to countermeasure a list of known anomalies

use strict;

use Getopt::Long;

my $help = 0;
GetOptions(
	'help!' => \$help,
);

if ($help)
{
	warn <<"EOF";
Preprocess a raptor log, trying to countermeasure a list of known anomalies

Usage: perl preprocess_log.pl < INFILE > OUTFILE
EOF
	exit(0);
}

while (my $line = <>)
{
	if ($line =~ m{<[^<^>]+>.*&.*</[^<^>]+>})
	{
		$line = escape_ampersand($line);
	}
	elsif ($line =~ m{<\?xml\s.*encoding=.*\".*\?>})
	{
		$line = set_encoding_utf8($line);
	}
	elsif ($line =~ m{<archive.*?[^/]>})
	{
		$line = unterminated_archive_tag($line, scalar <>, $.)
	}
	elsif ($line =~ m{make.exe: Circular .* <- .* dependency dropped.})
	{
		$line = escape_left_angle_bracket($line);
	}
	
	print $line;
}

sub escape_ampersand
{
	my ($line) = @_;
	
	warn "escape_ampersand\n";
	warn "in: $line";
	
	$line =~ s,&,&amp;,g;
	
	warn "out: $line";
	return $line;
}

sub set_encoding_utf8
{
	my ($line) = @_;
	
	warn "set_encoding_utf8\n";
	warn "in: $line";
	
	$line =~ s,encoding=".*",encoding="utf-8",;
	
	warn "out: $line";
	return $line;
}

sub unterminated_archive_tag
{
	my $line = shift;
	my $nextLine = shift;
	my $lineNum = shift;
	
	if ($nextLine !~ m{(<member>)|(</archive>)})
	{
		warn "unterminated_archive_tag\n";
		warn "in: $line";
		$line =~ s{>}{/>};
		warn "out: $line";
	}
	
	return $line . $nextLine;
}

sub escape_left_angle_bracket
{
	my ($line) = @_;
	
	warn "escape_left_angle_bracket\n";
	warn "in: $line";
	
	$line =~ s,<,&lt;,g;
	
	warn "out: $line";
	return $line;
}
