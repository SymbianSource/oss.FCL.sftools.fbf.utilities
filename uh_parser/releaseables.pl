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
# Extract releaseable (whatlog) information from Raptor log files

use strict;
use releaseables;
use FindBin;
use lib $FindBin::Bin;
use XML::SAX;
use RaptorSAXHandler;
use Getopt::Long;

our $basedir = '.';
my $help = 0;
GetOptions((
	'basedir=s' => \$basedir,
	'help!' => \$help
));
my @logfiles = @ARGV;

$help = 1 if (!@logfiles);

if ($help)
{
	print "Extract releaseable (whatlog) information from Raptor log files\n";
	print "Usage: perl releaseables.pl [OPTIONS] FILE1 FILE2 ...\n";
	print "where OPTIONS are:\n";
	print "\t--basedir=DIR Generate output under DIR (defaults to current dir)\n";
	exit(0);
}

my $releaseablesdir = "$::basedir/releaseables";
$releaseablesdir =~ s,/,\\,g; # this is because rmdir doens't cope correctly with the forward slashes
system("rmdir /S /Q $releaseablesdir") if (-d "$releaseablesdir");
mkdir("$releaseablesdir");

my $saxhandler = RaptorSAXHandler->new();
$saxhandler->add_observer('releaseables', $releaseables::reset_status);

my $parser = XML::SAX::ParserFactory->parser(Handler=>$saxhandler);
for (@logfiles)
{
	$parser->parse_uri($_);
}

