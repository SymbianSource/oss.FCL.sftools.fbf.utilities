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
# Perl script to synchronise a Perforce branch with a Mercurial repository

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
# This version implements the sync with Perforce
#

sub scm_usage()
	{
	print <<'EOF';

perl sync_hg_p4.pl -root rootdir [options]
version 0.7
 
Synchronise a branch in Perforce with a branch in Mercurial.

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

my $max_changelist;

sub scm_options()
	{
	# set defaults
	
	$max_changelist = "#head";
	
	# return the GetOpt specification
	return (
		'm|max=s' => \$max_changelist,
		);
	}

sub p4_sync($)
	{
	my ($changelist)= @_;
	
	my $sync = $hg_updated? "sync -k":"sync";
	my @sync_output = run_cmd("p4 $sync ...\@$changelist 2>&1");

	$hg_updated = 0;	# avoid doing sync -f next time, if possible
	return @sync_output;
	}

sub scm_init($@)
	{
	my ($tip_only, @syncpoints) = @_;
	
	my $first_changelist;
	
	# decide on the range of changelists to process
	
	if ($tip_only)
		{
		# Script says we must synchronise from the Perforce tip revision
		my @changes = run_cmd("p4 changes -m2 ...");
		foreach my $change (@changes)
			{
			if ($change =~ /^(Change (\d+) on (\S+) by (\S+)@\S+) /)
				{
				$first_changelist = $2;
				last;
				}
			}
		if (!defined $first_changelist)
			{
			print "Perforce branch contains no changes\n";
			return ();
			}
		print "Synchronisation from tip ($first_changelist)\n" if ($verbose);
		$max_changelist = "#head";
		}
	else
		{
		# deduce the last synchronisation point from the tags
		@syncpoints = sort {$b <=> $a} @syncpoints;
		$first_changelist = shift @syncpoints;
		printf "%d changes previously synchronised, most recent is %s\n", 
				1+scalar @syncpoints, $first_changelist;
		
		# Get Mercurial & Perforce into the synchronised state
		run_cmd("p4 revert ... 2>&1");
		hg_checkout($first_changelist);
		p4_sync($first_changelist);
		$first_changelist += 1;		# we've already synched that one
		}
	
	# enumerate the changelists

	my @changes = run_cmd("p4 changes ...\@$first_changelist,$max_changelist");

	my @scmrefs;
	foreach my $change (reverse @changes)
		{
		# Change 297463 on 2003/09/24 by ErnestoG@LON-ERNESTOG02 'Initial MRP files for Component
		if ($change =~ /^(Change (\d+) on (\S+) by (\S+)@\S+) /)
			{
			my $scmref = $2;
			push @scmrefs, $2;
			}
		}

	if ($debug && scalar @scmrefs > 3)
		{
		print "DEBUG - Processing only the first 3 SCM changes\n";
		@scmrefs = ($scmrefs[0],$scmrefs[1],$scmrefs[2]);
		}

	if ($verbose)
		{
		printf "Found %d new changelists to process (range %d to %s)\n",
			scalar @scmrefs, $first_changelist, $max_changelist;
		print join(", ", @scmrefs), "\n";
		}
	
	return @scmrefs;
	}

# scm_checkout
# Update the workspace to reflect the given SCM reference
#
sub scm_checkout($)
	{
	my ($scmref) = @_;
	
	my @changelist = run_cmd("p4 describe -s $scmref 2>&1", "$scmref - no such changelist");
	
	my @change_description;
	my $change_date;
	my $change_user;
	
	my $change_summary = shift @changelist;
	if ($change_summary =~ /^Change (\d+) by (\S+)@\S+ on (\S+ \S+)/)
		{
		$change_user = $2;
		$change_date = $3;
		}
	else
		{
		print "Failed to parse change summary => $change_summary\n";
		exit(1);
		}
	
	# Extract the descriptive part of the change description, watching for
	# the Symbian XML format enforced by the submission checker
	#
	my $symbian_format = 0;
	foreach my $line (@changelist)
		{
		last if ($line =~ /^(Affected files|Jobs fixed)/);

		$line =~ s/^\t//;	# remove leading tab from description text
		if ($line =~ /^<EXTERNAL>/)
			{
			$symbian_format = 1;
			@change_description = ();
			next;
			}
		if ($line =~ /^<\/EXTERNAL>/)
			{
			$symbian_format = 2;
			next;
			}
		
		chomp $line;
		push @change_description, $line if ($symbian_format < 2);
		
		# <detail submitter=      "Sangamma VChandangoudar" />
		if ($line =~ /detail submitter=\s*\"([^\"]+)\"/)	# name in " marks
			{
			$change_user = $1;
			}
		}
	
	$change_date =~ s/\//-/g;	# convert to yyyy-mm-dd hh:mm::ss"
	
	p4_sync($scmref);
	
	return ($change_user,$change_date,@change_description);
	}

# scm_checkin
# Describe the changes to the workspace as an SCM change
# Return the new SCM reference
#
sub scm_checkin($$$$$$)
	{
	my ($hgnode,$author,$date,$changes,$description,$tags) = @_;
	
	my @hg_tags = grep !/^tip$/, split /\s+/, $tags;
	my @p4_edit;
	my @p4_delete;
	my @p4_add;
	
	foreach my $line (@$changes)
		{
		my $type = substr($line,0,2,"");	# removes type as well as extracting it
		if ($type eq "M ")
			{
			push @p4_edit, $line;
			next;
			}
		if ($type eq "A " || $type eq "C ")
			{
			push @p4_add, $line;
			next;
			}		
		if ($type eq "R ")
			{
			push @p4_delete, $line;
			next;
			}
		
		abandon_sync("Unexpected hg status line: $type$line");
		}
	
	if (scalar @p4_add)
		{
		open P4ADD, "|p4 -x - add";
		print P4ADD @p4_add;
		close P4ADD;
		abandon_sync("Perforce error on p4 add: $?\n") if ($?);
		}
	
	if (scalar @p4_edit)
		{
		open P4EDIT, "|p4 -x - edit";
		print P4EDIT @p4_edit;
		close P4EDIT;
		abandon_sync("Perforce error on p4 edit: $?\n") if ($?);
		}
	if (scalar @p4_delete)
		{
		open P4DELETE, "|p4 -x - delete";
		print P4DELETE @p4_delete;
		close P4DELETE;
		abandon_sync("Perforce error on p4 delete: $?\n") if ($?);
		}
	
	my @pending_change = run_cmd("p4 change -o");
	
	# Can't do anything with the author or date information?
	
	my ($fh,$filename) = tempfile();

	my $hasfiles = 0;
	foreach my $line (@pending_change)
		{
		if ($line =~ /<enter description here>/)
			{
			print $fh "\t(Synchronised from Mercurial commit $hgnode: $date $author)";
			print $fh "\t(Mercurial tags: ", join(", ",$tags),")" if (scalar @hg_tags != 0);
			print $fh join("\n\t", "", @$description), "\n";
			next;
			}
		$hasfiles = 1 if ($line =~/^Files:/);
		print $fh $line;
		}
	
	close $fh;
	
	abandon_sync("No files in Perforce submission? $filename\n", @pending_change) if (!$hasfiles);
	
	my @submission = run_cmd("p4 submit -i < $filename 2>&1");
	
	unlink($filename);	# remove temporary file
	
	# Change 1419488 renamed change 1419490 and submitted.
	# Change 1419487 submitted.
	foreach my $line (reverse @submission)
		{
		if ($line =~ /change (\d+)( and)? submitted/i)
			{
			return $1;
			}
		}
	
	abandon_sync("Failed to parse output of p4 submit:\n",@submission);
	}
