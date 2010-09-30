#! perl

# Copyright (c) 2009-2010 Symbian Foundation Ltd
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
# Perl script to clone or update all of the Foundation MCL repositories

use strict;
use Getopt::Long;
use File::Basename;

sub Usage($)
  {
  my ($msg) = @_;
  
  print "$msg\n\n" if ($msg ne "");
  
	print <<'EOF';
clone_all_repositories - simple script for cloning Symbian repository tree
	
This script will clone repositories, or pull changes into a previously
cloned repository. The script will prompt for your username and
password, which will be needed to access the SFL repositories, or you can
supply them with command line arguments.

The list of packages can be supplied in a text file using the -packagelist
option, which is capable of reading the build-info.xml files supplied with 
Symbian PDKs. Supplying a build-info.xml file will cause the clone or update
operation to use the exact revision for each of the relevant repositories.

Important: 
  This script uses https access to the repositories, so the username and
  password will be stored as cleartext in the .hg/hgrc file for each repository.

Used with the "-mirror" option, the script will copy both MCL and FCL
repositories into the same directory layout as the Symbian website, and will
use the Mercurial "--noupdate" option when cloning.

Options:

-username      username at the Symbian website
-password      password to go with username
-mirror        create a "mirror" of the Symbian repository tree
-packagelist   file containing the URLs for the packages to be processed
-retries       number of times to retry a failed operation (default 1)
-verbose       print the underlying "hg" commands before executing them
-n             do nothing - don't actually execute the commands
-help          print this help information
-exec          execute command on each repository
-filter <RE>   only process repository paths matching regular expression <RE>
-dummyrun      Dummy Run, don't execute any Mercurial commands.
-webhost       Web Mercurial host (defaults to developer.symbian.org)
-norev         Ignore any revision information in packagelist

The -exec option processes the rest of the command line, treating it as
a command to apply to each repository in turn. Some keywords are expanded
to repository-specific values, and "hg" is always expanded to "hg -R %REPO%"

%REPO%         relative path to the repository
%WREPO%        relative path to repository, with Windows path separators
%HREPO%        path to the repository on the server
%WHREPO%       path to the repository on the server, with Windows separators
%URL%          URL of the master repository
%PUSHURL%      URL suitable for pushing (always includes username & password)
%REV%          revision associated with the repository (defaults to "tip")

It's often useful to use "--" to separate the exec command from the options
to this script, e.g. "-exec -- hg update -C tip"

EOF
  exit (1);  
  }

my @clone_options = (); # use ("--noupdate") to clone without extracting the source
my @pull_options  = (); # use ("--rebase") to rebase your changes when pulling
my $hostname = "developer.symbian.org";
my $pushhostname = "developer-secure.symbian.org";
my $webhost_option = "";

my $username = "";
my $password = "";
my $mirror = 0; # set to 1 if you want to mirror the repository structure
my $retries = 1;  # number of times to retry problem repos
my $verbose = 0;  # turn on more tracing
my $do_nothing = 0; # print the hg commands, don't actually do them
my $help = 0;
my $exec = 0;
my $filter = "";
my $norev = 0; # ignore revision information in packagelist files
my @packagelist_files = ();

# Analyse the rest of command-line parameters
if (!GetOptions(
    "u|username=s" => \$username,
    "p|password=s" => \$password,
    "m|mirror" => \$mirror, 
    "r|retries=i" => \$retries,
    "v|verbose" => \$verbose,
    "n" => \$do_nothing,
    "h|help" => \$help,
    "e|exec" => \$exec,
    "f|filter=s" => \$filter,
    "l|packagelist=s" => \@packagelist_files,
    "d|dummyrun" => \$do_nothing,
    "w|webhost=s" => \$webhost_option,
    "norev" => \$norev,
    ))
  {
  Usage("Invalid argument");
  }
  
Usage("Too many arguments") if (scalar @ARGV > 0 && !$exec);
Usage("Too few arguments for -exec") if (scalar @ARGV == 0 && $exec);
Usage("") if ($help);

if ($webhost_option)
	{
	$hostname = $webhost_option;
	$pushhostname = $webhost_option;
	}

# Important: This script uses http access to the repositories, so
# the username and password will be stored as cleartext in the
# .hg/hgrc file in each repository.

my $needs_id = 1; # assumed necessary for clone/pull

my @exec_cmd = @ARGV;
if ($exec)
  {
  if ($exec_cmd[0] eq "hg")
    {
    shift @exec_cmd;
    unshift @exec_cmd, "hg", "-R", "%REPO%";
    }
  if ($verbose)
    {
    print "* Exec template = >", join("<,>", @exec_cmd), "<\n";
    }
  $needs_id = grep /URL%/,@exec_cmd; # only need id if using %URL% or %PUSHURL%
  }

if ($needs_id && $username eq "" )
  {
  print "Username: ";
  $username = <STDIN>;
  chomp $username;
  }
if ($needs_id && $password eq "" )
  {
  print "Password: ";
  $password = <STDIN>;
  chomp $password;
  }

sub do_system(@)
  {
  my (@cmd) = @_;
  
  if ($verbose)
    {
    print "* ", join(" ", @cmd), "\n";
    }
  return 0 if ($do_nothing);
  
  return system(@cmd);
  }

my %revisions;

sub process_one_repo($)
  {
  my ($package) = @_;
  my @dirs = split /\//, $package;
  my $license = shift @dirs;
  my $repotree = shift @dirs; # remove the MCL or FCL repo tree information
  my $destdir = pop @dirs;  # ignore the package name, because Mercurial will create that
  
  if ($mirror)
    {
    # Mirror the full directory structure, so put back the license & repotree dirs
    unshift @dirs, $repotree;
    unshift @dirs, $license;
    }

  # Ensure the directories already exist as far as the parent of the repository
  my $path = "";
  foreach my $dir (@dirs)
    {
    $path = ($path eq "") ? $dir : "$path/$dir";
    if (!-d $path)
      {
      mkdir $path;
      }
    }
  
  $path .= "/$destdir";   # this is where the repository will go

  my $repo_push_url = "https://$username:$password\@$pushhostname/$package/";
  my $repo_url = $repo_push_url;
  if ($license ne "sfl")
    {
    # user registration is not required for reading public package repositories
    $repo_url = "http://$hostname/$package/";
    }
  
  my @rev_options = ();
  my $revision = $revisions{$package};
  if (defined($revision) && $norev == 0)
    {
    @rev_options = ("--rev", $revision);
    }
  else
    {
    $revision = "tip";
    # and leave the rev_options list empty
    }
  
  my $ret;
  if ($exec)
    {
    # iteration functionality - process the keywords
    my $wpath = $path;
    my $wpackage = $package;
    $wpath =~ s/\//\\/g;  # win32 path separator
    $wpackage =~ s/\//\\/g;  # win32 path separator
    my @repo_cmd = ();
    foreach my $origcmd (@exec_cmd)
      {
      my $cmd = $origcmd; # avoid altering the original
      $cmd =~ s/%REPO%/$path/;
      $cmd =~ s/%WREPO%/$wpath/;
      $cmd =~ s/%HREPO%/$package/;
      $cmd =~ s/%WHREPO%/$wpackage/;
      $cmd =~ s/%URL%/$repo_url/;
      $cmd =~ s/%PUSHURL%/$repo_push_url/;
      $cmd =~ s/%REV%/$revision/;
      push @repo_cmd, $cmd;
      }
    print "Processing $path...\n";
    $ret = do_system(@repo_cmd);
    }
  elsif (-d "$path/.hg")
    {
    # The repository already exists, so just do an update
    
    print "Updating $destdir from $package...\n";
    $ret = do_system("hg", "pull", @pull_options, @rev_options, "-R", $path, $repo_url);
    if ($ret == 0 && ! $mirror)
      {
      $ret = do_system("hg", "update", "-R", $path, @rev_options)
      }
    }
  else
    {
    # Clone the repository
    
    print "Cloning $destdir from $package...\n";
    $ret = do_system("hg", "clone", @clone_options, @rev_options, $repo_url, $path);
    }
  
  $ret = $ret >> 8;   # extract the exit status
  print "* Exit status $ret for $path\n\n" if ($verbose);
  return $ret;
  }

my $add_implied_FCL_repos = 0; 
if (scalar @packagelist_files == 0)
  {
  # Read the package list files alongside the script itself
  
  # Extract the path location of the program and locate package list files
  my ($program_name,$program_path) = &File::Basename::fileparse($0);
  
  foreach my $file ("sf_oss_mcl_packages.txt", "sftools_oss_mcl_packages.txt", "other_packages.txt")
    {
    if (! -e $program_path.$file)
    	{
    	print "Cannot find implied packagelist $program_path$file\n";
    	next;
			}
    push @packagelist_files, $program_path.$file;
    }
  $add_implied_FCL_repos = 1;   # lists only contain the MCL repo locations
  }

my @all_packages = ();

foreach my $file (@packagelist_files)
  {
  print "* reading package information from $file...\n" if ($verbose);
  open PKG_LIST, "<$file" or die "Can't open $file: $!\n";
  foreach my $line (<PKG_LIST>)
    {
    chomp($line);

    $line =~ s/\015//g; # remove CR, in case we are processing Windows text files on Linux
    
    my $revision; # set when processing build-info listings
    
    # build-info.xml format
    # <baseline>//v800008/Builds01/mercurial_master_prod/sfl/MCL/sf/adaptation/stubs/#7:e086c7f635d5</baseline>
    # <baseline>//v800008/Builds01/mercurial_master_prod/sfl/MCL/sf/adaptation/stubs/#:e086c7f635d5</baseline>
    # <baseline>//v800008/Builds01/mercurial_master_prod/sfl/MCL/sf/adaptation/stubs/#e086c7f635d5</baseline>
    if ($line =~ /<baseline>(.*)#(\d*:)?([0-9a-fA-F]+)<\/baseline>/i)
      {
      $line = $1;   # discard the wrapping
      $revision = $3;
      }
 
 		# sources.csv format
 		# http://developer.symbian.org/oss/FCL/sf/app/browserui/,/sf/app/browserui,tag,tip_bulk,layers.sysdef.xml
 		# http://developer.symbian.org/oss/FCL/sf/app/browserui/,/sf/app/browserui,changeset,e086c7f635d5,layers.sysdef.xml
		if ($line =~ /^(http[^,]+),([^,]+),[^,]+,([^,]+),.*$/)
			{
			$line = $1;
			$revision = $3;
			}

    # Look for the oss/MCL/ prefix to a path e.g.
    # https://developer.symbian.org/oss/FCL/interim/contrib/WidgetExamples
    if ($line =~ /((oss|sfl)\/(FCL|MCL)\/.*)\s*$/)
      {
      my $repo_path = $1;
      $repo_path =~ s/\/$//;  # remove trailing slash, if any

      push @all_packages, $repo_path;
      $revisions{$repo_path} = $revision if (defined $revision);
      next;
      }
    }
  close PKG_LIST;
  }

if ($mirror)
  {
  push @clone_options, "--noupdate";
  
  if ($add_implied_FCL_repos)
    {
    # Assume that every MCL has a matching FCL. As we are mirroring,
    # we can process both without them overlapping in the local filesystem
    my @list_with_fcls = ();
    foreach my $package (@all_packages)
      {
      push @list_with_fcls, $package;
      if ($package =~ /MCL/)
        {
        $package =~ s/MCL/FCL/;
        push @list_with_fcls, $package;
        }
      }
    @all_packages = @list_with_fcls;
    }
  }

my @problem_packages = ();
my $total_packages = 0;

foreach my $package (@all_packages)
  {
  if ($filter && $package !~ /$filter/)
    {
    next; # skip repos which don't match the filter
    }
  my $err = process_one_repo($package);
  $total_packages++;
  push @problem_packages, $package if ($err < 0 || $err > 127); 
  }
  
# retry problem packages

my $attempt = 0;
while ($attempt < $retries && scalar @problem_packages) 
  {
  $attempt++;
  printf "\n\n------------\nRetry attempt %d on %d packages\n",
    $attempt, scalar @problem_packages;
  print join("\n", @problem_packages, ""), "\n";
    
  my @list = @problem_packages;
  @problem_packages = ();
  foreach my $package (@list)
    {
    my $err = process_one_repo($package);
    push @problem_packages, $package if ($err < 0 || $err > 127); 
   }
  }

printf "\n------------\nProcessed %d packages, of which %d reported errors\n", 
  $total_packages, scalar @problem_packages;
if (scalar @problem_packages)
  {
  print join("\n", @problem_packages, "");
  exit(1);
  }
  else
  {
  exit(0);
  }
  