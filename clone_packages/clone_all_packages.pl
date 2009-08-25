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
# Perl script to clone or update all of the Foundation MCL repositories

use strict;
use Getopt::Long;

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
-retries       number of times to retry a failed operation (default 1)
-verbose       print the underlying "hg" commands before executing them
-n             do nothing - don't actually execute the commands
-help          print this help information
-exec          execute command on each repository
-filter <RE>   only process repository paths matching regular expression <RE>

The -exec option processes the rest of the command line, treating it as
a command to apply to each repository in turn. Some keywords are expanded
to repository-specific values, and "hg" is always expanded to "hg -R %REPO%"

%REPO%         relative path to the repository
%WREPO%        relative path to repository, with Windows path separators
%URL%          URL of the master repository
%PUSHURL%      URL suitable for pushing (always includes username & password)

It's often useful to use "--" to separate the exec command from the options
to this script, e.g. "-exec -- hg update -C tip"

EOF
  exit (1);  
  }

my @clone_options = (); # use ("--noupdate") to clone without extracting the source
my @pull_options  = (); # use ("--rebase") to rebase your changes when pulling
my $hostname = "developer.symbian.org";

my $username = "";
my $password = "";
my $mirror = 0; # set to 1 if you want to mirror the repository structure
my $retries = 1;  # number of times to retry problem repos
my $verbose = 0;  # turn on more tracing
my $do_nothing = 0; # print the hg commands, don't actually do them
my $help = 0;
my $exec = 0;
my $filter = "";

# Extract the path location of the program and locate package list files
my $program_path = $0;
$program_path =~ s#(^.*\\)[^\\]+$#$1#;
my $sf_pkg_list_file = $program_path."sf_mcl_packages.txt";
my $sftools_pkg_list_file = $program_path."sftools_mcl_packages.txt";
my $other_pkg_list_file = $program_path."other_packages.txt";

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
    ))
  {
  Usage("Invalid argument");
  }
  
Usage("Too many arguments") if (scalar @ARGV > 0 && !$exec);
Usage("Too few arguments for -exec") if (scalar @ARGV == 0 && $exec);
Usage("") if ($help);

open  SF_PKG_LIST, "<$sf_pkg_list_file" or die "Can't open $sf_pkg_list_file\n";
open  SFTOOLS_PKG_LIST, "<$sftools_pkg_list_file" or die "Can't open $sftools_pkg_list_file\n";
open  OTHER_PKG_LIST, "<$other_pkg_list_file" or die "Can't open $other_pkg_list_file\n";


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

my @sf_packages;
foreach my $pkg (<SF_PKG_LIST>)
{
	if ($pkg =~ s#^https://[^/]+/##)
	{
		chomp($pkg);
		push @sf_packages, $pkg;
	}
}

my @sftools_packages;
foreach my $pkg (<SFTOOLS_PKG_LIST>)
{
	if ($pkg =~ s#^https://[^/]+/##)
	{
		chomp($pkg);
		push @sftools_packages, $pkg;
	}
}

my @other_repos;
foreach my $pkg (<OTHER_PKG_LIST>)
{
	if ($pkg =~ s#^https://[^/]+/##)
	{
		chomp($pkg);
		push @other_repos, $pkg;
	}
}


my %export_control_special_case = (
  "oss/MCL/sf/os/security" => 1,
  "oss/FCL/sf/os/security" => 1,
  );

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

sub get_repo($)
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

  my $repo_url = "https://$username:$password\@$hostname/$package/";
  my $repo_push_url =$repo_url;
  if ($license ne "sfl" && !$export_control_special_case{$package})
    {
    # user registration is not required for reading public package repositories
    $repo_url = "http://developer.symbian.org/$package/";
    }
  
  if ($exec)
    {
    # iteration functionality - process the keywords
    my $wpath = $path;
    $wpath =~ s/\//\\/g;  # win32 path separator
    my @repo_cmd = ();
    foreach my $origcmd (@exec_cmd)
      {
      my $cmd = $origcmd; # avoid altering the original
      $cmd =~ s/%REPO%/$path/;
      $cmd =~ s/%WREPO%/$wpath/;
      $cmd =~ s/%URL%/$repo_url/;
      $cmd =~ s/%PUSHURL%/$repo_push_url/;
      push @repo_cmd, $cmd;
      }
    print "Processing $path...\n";
    return do_system(@repo_cmd);
    }
  elsif (-d "$path/.hg")
    {
    # The repository already exists, so just do an update
    
    print "Updating $destdir from $package...\n";
    return do_system("hg", "pull", @pull_options, "-R", $path, $repo_url);
    }
  else
    {
    # Clone the repository
    
    print "Cloning $destdir from $package...\n";
    return do_system("hg", "clone", @clone_options, $repo_url, $path);
    }
  
  }

my @all_packages;

@all_packages = (@sf_packages, @sftools_packages, @other_repos);

if ($mirror)
  {
  push @clone_options, "--noupdate";
  
  if (0)
    {
    # Prototype code to scrape the repository list from the website
    # Needs to have extra modules and executables installed to support https
    # so this would only work for the oss packages at present...
    
    # Create a user agent object
    use LWP::UserAgent;
    use HTTP::Request::Common;
    my $ua = LWP::UserAgent->new;
    $ua->agent("clone_all_packages.pl ");
  
    # Request the oss package list
    my $res = $ua->request(GET "http://$hostname/oss");
  
    # Check the outcome of the response
    if (! $res->is_success) 
      {
      print "Failed to read oss package list:\n\t", $res->status_line, "\n";
      }
    
    my @oss_packages = ($res->content =~ m/<td><a href="\/(oss\/[^"]+)\/?">/g);  # umatched "
    print join ("\n\t",@oss_packages), "\n";

    # Request the sfl package list
    $res = $ua->request(GET "https://$username:$password\@$hostname/sfl");
  
    # Check the outcome of the response
    if (! $res->is_success) 
      {
      print "Failed to read sfl package list:\n\t", $res->status_line, "\n";
      }
    
    my @sfl_packages = ($res->content =~ m/<td><a href="\/(sfl\/[^"]+)\/?">/g);  # umatched "
    print join ("\n\t",@sfl_packages), "\n";
    
    @all_packages = (@sfl_packages, @oss_packages);
    }
  else
    {
    # Assume that every MCL has a matching FCL
    my @list_with_fcls = ();
    foreach my $package (@all_packages)
      {
      push @list_with_fcls, $package;
      if ($package =~ /MCL/)
        {
        # If mirroring, get the matching FCLs as well as MCLs
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
  my $err = get_repo($package);
  $total_packages++;
  push @problem_packages, $package if ($err); 
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
    my $err = get_repo($package);
    push @problem_packages, $package if ($err); 
   }
  }

printf "\n------------\nProcessed %d packages, of which %d reported errors\n", 
  $total_packages, scalar @problem_packages;
if (scalar @problem_packages)
  {
  print join("\n", @problem_packages, "");
  }
