#! perl

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
# Perl script to summarise output from clone_all_package.pl


@all = <>;

my $repo;
my $newrepo = 0;
my $errors = 0;
my $summary = 0;
my $retries = 0;
foreach my $line (@all)
{
  if($summary)
  {
    # if we are in the summary section then just echo all lines out
    # this should be a list of all the packages with errors
    print "$line\n";
  }
	#save package name
	# e.g new package "Cloning compatanaapps from sfl/MCL/sftools/ana/compatanaapps..."
	# e.g. existing package "Updating helix from sfl/MCL/sf/mw/helix..."
	# e.g. with -exec option "Processing sfl/FCL/interim/auxiliary_tools/AgileBrowser."
	elsif ($line =~ m/Cloning (.*?)from(.*)$/)
	{
		$repo = $2;
		$newrepo = 1;
		$retries =0;
    }
    elsif ($line =~ m/Updating (.*?)from(.*)$/)
    {
		$repo = $2;
		$newrepo = 0;
		$retries =0;
    }

    #
    # Capture number of changes, should be line like one of the following
	# e.g. "added 4 changesets with 718 changes to 690 files"
	# e.g. "no changes found"
	elsif ($line =~ m/added (.*?)changesets with(.*)$/)
	{
		print "\n$repo\t added $1 chamgesets";
		print "\t retries $retries";
		print "\t** NEW" if ($newrepo);
    }

  if($line =~ m/abort:/)
  {
    $retries++;
  }

	# Process the summary section
	# e.g. "------------"
	# e.g. "Processed 22 packages, of which 0 reported errors"
	if ($line =~ m/Processed (.*?)packages, of which(.*?)reported errors/)
	{
		print "\n-------------------------------\n";
		print "\n Summary: Processed $1 : Errors $2\n";
		$errors= $2;
		$summary = 1;
	}

}
if ($errors > 0)
{
	print "\nexit with error\n";
	exit 1;
}
else
{
  print "\nexit success\n";
	exit 0;
}
