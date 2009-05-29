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
# Skeleton Perl script to synchronise a branch in an SCM system with a Mercurial repository
# It's synch_hg_p4.pl with the Perforce-specific details removed.

use strict;
use Getopt::Long;
use File::Temp qw/ tempfile tempdir /;	# for tempfile()

my $verbose;
my $debug = 0;
my $rootdir;
my $help;
my $remoterepo;
my $hgbranch;
my $sync_prefix = "sync_";

# abandon_sync, all ye who enter here
# This should send a notification to someone, as it will probably mean manual repair
#
sub abandon_sync(@)
	{
	print "ERROR - synchronisation of $rootdir abandoned\n\n";
	print @_;
	print "\n\n";
	exit(1);
	}
	
# utility to run an external command
#
sub run_cmd($;$)
	{
	my ($cmd,$failurematch) = @_;
	print "--- $cmd\n" if ($verbose || $debug);
	my @output = `$cmd`;
	print @output,"\n---\n" if ($debug);
	
	if (defined $failurematch)
		{
		if (grep /$failurematch/, @output)
			{
			abandon_sync("COMMAND FAILED: $cmd\n", @output,"\n\n",
				"Output matched $failurematch\n");
			}
		else
			{
			print "CMD OK - Didn't match /$failurematch/\n" if ($debug);
			}
		}
	if ($?)
		{
		print @output,"\n---\n" if ($verbose);
		abandon_sync("COMMAND FAILED: exit status = $?\n",$cmd,"\n");
		}
	
	return @output;
	}
	

# -------------- hg section -------------
#
# Code relating to other SCM system is abstracted into 
# functions to do relatively simple actions. This section
# contains the driving logic for the script, and all of the
# manipulations of Mercurial
#

sub scm_usage();		# forward declarations
sub scm_options();
sub scm_init($@);
sub scm_checkout($);	# non-destructive, i.e. leave untouched any workspace files not managed in SCM
sub scm_checkin($$$$$$);

sub Usage(;$)
	{
	my ($errmsg) = @_;
	print "\nERROR: $errmsg\n" if (defined $errmsg);
	scm_usage();
	print <<'EOF';

General options:

-root rootdir       root of the Mercurial gateway repository
-v                  verbose
-h                  print this usage information

Setting up a new synchronisation:

-clone remoterepo   clones gateway from remote repository 
-branch hgbranch    Mercurial branch name (if needed)

EOF
	exit 1;
	}

Usage() if !GetOptions(
	'root=s' => \$rootdir,
	'h' => \$help,
	'v' => \$verbose,
	'debug' => \$debug,
	'clone=s' => \$remoterepo,
	'branch=s' => \$hgbranch,
	scm_options()
	);

Usage() if ($help);

Usage("Must specify root directory for Mercurial gateway") if (!defined $rootdir);
Usage("-branch is only used with -clone") if (defined $hgbranch && !defined $remoterepo);

if ($verbose)
	{
	my @hgversion = run_cmd("hg --version");
	print @hgversion;
	}

# utility to return the heads descended from a particular point
#
sub hg_heads($)
	{
	my ($rev_on_branch) = @_;
	my @heads = run_cmd("hg heads --template {rev}\\t{tags}\\n $rev_on_branch");
	return @heads;
	}

# return an unsorted list of synchronisation points, identified by
# tags beginning with "sync_"
# 
sub hg_syncpoints(;$)
	{
	my ($tip_rev) = @_;
	my @tags = run_cmd("hg tags");
	my @syncpoints;
	foreach my $tag (@tags)
		{
		if ($tag =~ /^tip\s+(\d+):\S+$/)
			{
			$$tip_rev = $1 if (defined $tip_rev);
			next;
			}
		if ($tag =~ /^$sync_prefix(.*\S)\s+\S+$/)
			{
			push @syncpoints, $1;
			next
			}
		}
	if ($debug)
		{
		printf "Found %d syncpoints in %d tags:", scalar @syncpoints, scalar @tags;
		print join("\n * ", "",@syncpoints), "\n";
		}
	return @syncpoints;
	}

my $hg_updated = 0;

# Update the Mercurial workspace to a given sync point
#
sub hg_checkout($)
	{
	my ($scmref) = @_;
	
	my $tag = $sync_prefix.$scmref;
	my @output = run_cmd("hg update --clean --rev $tag", "^abort:");
	$hg_updated = 1;	# could check the output in case it didn't change anything
	}

# 0. Create the gateway repository, if -clone is specified

if (defined $remoterepo)
	{
	Usage("Cannot create gateway because $rootdir already exists") if (-d $rootdir);

	my $clonecmd = "clone";
	$clonecmd .= " --rev $hgbranch" if (defined $hgbranch);
	my @output = run_cmd("hg $clonecmd $remoterepo $rootdir");
	$hg_updated = 1;
	}

chdir $rootdir;
Usage("$rootdir is not a Mercurial repository") if (!-d ".hg");

my $something_to_push = 0;

# 1. Prime the SCM system, and get the ordered list of changes available to 
# convert into Mercurial commits

my $first_sync;		# is this the first synchronisation?
my $scm_tip_only;	# can we process a series of changes in the SCM system?

my $tip_rev = -1;
my @syncpoints = hg_syncpoints(\$tip_rev);

if (scalar @syncpoints != 0)
	{
	$first_sync = 0;	# no - it's already synchronised
	$scm_tip_only = 0;	# so can allow sequence of SCM changes
	}
else
	{
	print "First synchronisation through this gateway\n" if ($verbose);
 	$first_sync = 1;
	if ($tip_rev != -1)
		{
 		$scm_tip_only = 1;	# because there's already something in the repository
 		}
 	else
 		{
		print "Mercurial repository is empty\n" if ($verbose);
		$scm_tip_only = 0;	# allow multiple SCM changes, because there's nothing to merge with
		}
	}

my $opening_scmtag;	# ancestor by which we judge the headcount of the result
my $latest_scmtag;

my @scmrefs = scm_init($scm_tip_only, @syncpoints);

if (scalar @scmrefs == 0)
	{
	print "No changes to process in local SCM\n";
	$opening_scmtag = $tip_rev;
	}
else
	{
	$opening_scmtag = $sync_prefix.$scmrefs[0];
	}
$latest_scmtag = $opening_scmtag;

if ($scm_tip_only && scalar @scmrefs > 1)
	{
	print "ERROR - cannot handle multiple SCM changes in this situation\n";
	exit(1);
	}

# 2. Process the SCM changes, turning them into Mercurial commits and marking with tags
# - we guarantee that there is at most one change, if this is the first synchronisation

foreach my $scmref (@scmrefs)
	{
	my ($user,$date,@description) = scm_checkout($scmref);
	
	# commit the result

	my ($fh,$filename) = tempfile();
	print $fh join("\n",@description), "\n";
	close $fh;
	
	run_cmd("hg commit --addremove --date \"$date\" --user \"$user\" --logfile  $filename", "^abort\:");
	$something_to_push = 1;
	
	unlink($filename);	# remove temporary file

	my $tag = $sync_prefix.$scmref;
	run_cmd("hg tag --local $tag");
	$latest_scmtag = $tag;
	print "Synchronised $scmref into Mercurial gateway repository\n";
	}

# 3. Put the full Mercurial state into the SCM, if this is the first synchronisation

if ($first_sync)
	{
	my @traceback = run_cmd("hg log --limit 1 --template {rev}\\t{node}\\t{tags}\\n");
	my $line = shift @traceback;

	chomp $line;
	my ($rev,$node,$tags) = split /\t/,$line;
	
	if ($rev != 0)
		{
		# repository was not empty, so need to commit the current state back into Perforce
	
		my @description = run_cmd("hg log --rev $rev --template \"{author}\\n{date|isodate}\\n{desc}\"");
		chomp @description;
		my $author = shift @description;
		my $date = shift @description;
		my @changes = run_cmd("hg status --clean");	# include info on unmodified files
		@changes = sort @changes;

		# Deliver changes to SCM
		my $scmref = scm_checkin($node,$author,$date,\@changes,\@description,$tags);
		
		my $tag = $sync_prefix.$scmref;
		run_cmd("hg tag --local $tag");
		$latest_scmtag = $tag;
		print "Synchronised $scmref from Mercurial gateway, to initialise the synchronisation\n";
		}
	
	$opening_scmtag = $latest_scmtag;	# don't consider history before this point
	}


# 3. pull from Mercurial default path, deal with new stuff

my @pull_output = run_cmd("hg pull --update");
$hg_updated = 1;

my @heads = hg_heads($opening_scmtag);

if (scalar @heads > 1)
	{
	# more than one head - try a safe merge
	print "WARNING: multiple heads\n",@heads,"\nMerge is needed\n\n\n" if ($verbose);
	
	my @merge_output = run_cmd("hg --config \"ui.merge=internal:fail\" merge");	# which head?
	if ($merge_output[0] =~ / 0 files unresolved/)
		{
		# successful merge - commit it.
		run_cmd("hg commit --message \"Automatic merge\"");
		$something_to_push = 1;
		}
	else
		{
		# clean up any partially merged files
		run_cmd("hg update -C");
		}
	}

# 4. Identify the sequence of Mercurial changes on the trunk and put them into the SCM
# - Do only the head revision if this is the first synchronisation, to avoid copying ancient history

my $options = "--follow-first";
$options .= " --prune $latest_scmtag";

my @traceback = run_cmd("hg log $options --template {rev}\\t{node}\\t{tags}\\n");
foreach my $line (reverse @traceback)
	{
	chomp $line;
	my ($rev,$node,$tags) = split /\t/,$line;
	if ($tags =~ /$sync_prefix/)
		{
		# shouldn't happen - it would mean that tip goes back to an ancestor
		# of the latest sync point
		abandon_sync("Cannot handle this structure\n",@traceback);
		}
	
	# Read commit information and update workspace from Mercurial
	
	my @description = run_cmd("hg log --rev $rev --template \"{author}\\n{date|isodate}\\n{desc}\"");
	chomp @description;
	my $author = shift @description;
	my $date = shift @description;
	my @changes = run_cmd("hg status --rev $latest_scmtag --rev $rev");
	@changes = sort @changes;

	run_cmd("hg update -C --rev $rev");
	$hg_updated = 1;
	
	# Deliver changes to SCM
	my $scmref = scm_checkin($node,$author,$date,\@changes,\@description,$tags);
	
	# Tag as the latest sync point
	my $tag = $sync_prefix.$scmref;
	run_cmd("hg tag --local $tag");
	$latest_scmtag = $tag;
	print "Synchronised $scmref from Mercurial gateway\n";
	}

# 3. push changes to the destination gateway

if ($something_to_push)
	{
	my @output = run_cmd("hg -v push --force --rev $latest_scmtag");
	print "\n",@output,"\n" if ($verbose);
	print "Destination Mercurial repository has been updated\n"; 
	}
else
	{
	print "Nothing to push to destination Mercurial repository\n";
	}

# 4. Check to see if we are in a clean state

@heads = hg_heads($opening_scmtag);
if (scalar @heads > 1)
	{
	print "\n------------------\n";
	print "WARNING: Mercurial repository has multiple heads - manual merge recommended\n";
	}

exit(0);


# -------------- SCM section -------------
#
# Code relating to non-Mercurial SCM system.
# This version implements the sync with XXX
#

# Utility functions you might want to call are:
#
# run_cmd($cmd)
# - Function which runs the specified command in a subshell and returns the stdout output as a list
#   of strings. The whole script will terminate if the command returns with a non-zero exit status.
#
# abandon_sync(@messagelines)
# - Terminate the synchronisation script and pass on the message to someone who might care...
#
# $hg_updated
# - Global variable set to 1 if Mercurial changes the content of the workspace. This can be used to
#   optimise the XXX system processing during initialisation, because it indicates when the workspace
#   can be considered "clean" by the XXX system. Should be set to 0 whenever the XXX system knows the
#   state of the workspace.
#
# hg_checkout($scmref)
# - Function to call "hg update" to the sync label associated with $scmref. Used during the scm_init
#   function as part of getting the workspaces in harmony before transferring changes. Will set
#   $hg_updated to 1.


# scm_usage()
#
# This function is called to supply the main "usage" statement for the script, as the
# interesting description is all about the interaction between Mercurial and XXX. It takes no
# arguments and should return nothing.
#
sub scm_usage()
	{
	print <<'EOF';

perl sync_hg_xxx.pl -root rootdir [options]
version 0.7
 
Synchronise a branch in XXX with a branch in Mercurial.

The branch starts at rootdir, which is a local Mercurial repository.
The Perforce clientspec is assumed to exist, to specify modtime & rmdir, 
and to exclude the .hg directory from the rootdir.

The tool will sync rootdir/... to the specified changelist, and
then reflect all changes affecting this part of the directory tree into
Mercurial.

The -first option is used to specify the first sync point if the gateway
has not been previously synchronised, e.g. when -clone is specified.

Perforce-related options:

-m maxchangelist    highest changelist to consider
                    defaults to #head

EOF
	}

my $max_changelist;			# put XXX-specific global variables here

sub scm_options()
	{
	# set defaults
	
	$max_changelist = "#head";		# initialise the XXX global variables here, otherwise it doesn't happen
	
	# return the GetOpt specification
	return (
		'm|max=s' => \$max_changelist,		# add your own bits of GetOpt arguments
		);
	}


# scm_init ($tip_only, @syncpoints)
#
# The main code calls this routine once, passing two arguments, and expects to get a 
# list of identifiers to XXX changes which could be synchronised as individual Mercurial
# commits. These references can be anything which can be used as part of a Mercurial tag name,
# and the main code will call back into this routine supplying the references one at a time
# in the list order.
#
# If $tip_only is true, then the synchronisation can only handle the most recent version
# of the code in the XXX system, and will not be able to sync intermediate steps. This usually
# means that this is the first synchronisation of this branch with Mercurial. At most one identifier
# should be returned.
#
# @syncpoints contains a list of identifiers extracted from the local sync_* tags which mark a change
# that was synchronised with Mercurial in some previous run. This information allows the XXX system
# to ignore changes which have previously been processed, and to set itself into a state where
# the workspace corresponds to the contents of the XXX system at that point.
#
# The function returns the list of change identifiers for changes to be taken out of XXX and applied
# to Mercurial. This list can be empty if there are no new changes since the last synchronisation point,
# or if there is no content in the branch.

sub scm_init($@)
	{
	my ($tip_only, @syncpoints) = @_;
	
	my $first_changelist;
	
	if ($tip_only)
		{
		# Script says we must synchronise from the XXX tip revision
		
		# Find the first changelist

		if (!defined $first_changelist)
			{
			print "XXX branch contains no changes\n";
			return ();
			}
		print "Synchronisation from tip ($first_changelist)\n" if ($verbose);
		# fall through to complete the initialisation
		}
	else
		{
		# deduce the last synchronisation point from the @syncpoints list

		$first_changelist = some_function_of(@syncpoints);
		
		# Get Mercurial & XXX into the synchronised state

		hg_checkout($first_changelist);		# call back to Mercurial to update from hg repository
		
		# get XXX into state associated with $first_changelist

		## NB this is a bit Perforce specific - you might prefer to separate tip_only processing
		## from the normal "changes since last synchronisation" processing
		##
		$first_changelist += 1;		# we've already synched that one
		##
		}
	
	# enumerate the changelists available from the XXX system & return as an ordered list

	my @scmrefs = some_function($first_changelist);

	if ($verbose)
		{
		printf "Found %d new changelists to process\n", scalar @scmrefs;
		print join(", ", @scmrefs), "\n";
		}
	
	return @scmrefs;
	}

# scm_checkout($scmref)
#
# Update the workspace to reflect the given SCM reference
#
# This update should not change files which are not currently managed by the XXX system, but
# should delete workspace files if the XX change involved deleting files. It is useful, but not essential,
# for empty directories to be removed if they become empty due to deletions recorded in the XXX change.
#
# The function returns a list containing three things:
# 
# $change_user - the username to be recorded for the Mercurial commit
# $change_date - the date to be recorded for the Mercurial commit (yyyy-mm-dd hh:mm:ss format)
# @change_description - the commit message to be used in Mercurial, as a list of lines of text
#
# The lines in the change description should not contain end of line markers, as these will be supplied
# by the main code.
#
sub scm_checkout($)
	{
	my ($scmref) = @_;
	
	my @change_description;
	my $change_date;
	my $change_user;
	
	# obtain the user , date and description for the given change identifier
	
	# apply the change to the workspace, ready for Mercurial to deduce with "hg commit --addremove"
	
	return ($change_user,$change_date,@change_description);
	}


# scm_checkin($hgnode,$author,$date,$changes,$description,$tags)
#
# Describe the changes to the workspace as an SCM change, and return the new identifier (for use in a tag)
#
# The function receives 6 parameters, all of which are associated with the Mercurial commit
#
# $hgnode      - Mercurial commit reference, as a globally unique hexadecimal identifier
# $author      - the author recorded in the commit
# $date        - the date recorded in the commit, in ISO date format (yyyy-mm-dd hh:mm:ss)
# $changes     - Perl reference to the list of file changes (more information below)
# $description - Perl reference to the list of lines in the commit message
# $tags        - Perl reference to the list of (non-local) tags associated with this commit
#
# The changes come from the Mercurial "hg status" command, and consist of a filename relative to the
# root of the repository, prefixed by a single letter code and a space. The codes that this routine
# must handle are M = modify, R = remove, A = add, and C = clean. The C codes are only used for the
# first synchronisation, and so should be handled as "add if not already in XXX". All of the implied 
# changes have already been applied to the files in the workspace - the R files have been deleted, 
# the A files have been added and the M files contain the desired content.
#
# The $hgnode should be recorded in the description in the XXX system, as should the $author and $date if
# they can't be used directly. 
#
# The function returns the identifier for the completed change, which will be tagged in the Mercurial
# repository and reported to scm_init() in future synchronisation runs.
#
# WARNING: The tag information isn't currently filtered properly, and it is likely that there will
# need to be a separate scm_tag() function to handle the important Mercurial tags explicitly. Don't try
# to do much with the tag information just yet.
#
sub scm_checkin($$$$$$)
	{
	my ($hgnode,$author,$date,$changes,$description,$tags) = @_;
	
	my @hg_tags = grep !/^tip$/, split /\s+/, $tags;
	my @xxx_modify;
	my @xxx_remove;
	my @xxx_add;
	
	# Separate the changes into lists of files for modify/add/remove
	
	foreach my $line (@$changes)
		{
		my $type = substr($line,0,2,"");	# removes type as well as extracting it
		if ($type eq "M ")
			{
			push @xxx_modify, $line;
			next;
			}
		if ($type eq "A " || $type eq "C ")
			{
			push @xxx_add, $line;
			next;
			}		
		if ($type eq "R ")
			{
			push @xxx_remove, $line;
			next;
			}
		
		abandon_sync("Unexpected hg status line: $type$line");
		}
	
	# Create an XXX system change object to record the changes (if necessary)
	# process the lists of files
	
	if (scalar @xxx_add)
		{
		# add the files in the xxx_add list
		}
	
	if (scalar @xxx_modify)
		{
		# process the list of modified files
		}
		
	if (scalar @xxx_remove)
		{
		# remove the files in the xxx_remove list
		}
	
	# Create the change description from the @$description list
	
	# Include the $hgnode as part of the description
	# Use the $author and $date if possible (by might just have to be more descriptive text
	# TODO: Do something with the interesting tags?
	
	my $scmref = some_function();
	
	return $scmref;
	}
