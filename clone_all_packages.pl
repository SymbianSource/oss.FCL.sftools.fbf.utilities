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
-n             do nothing - don't actually execute the hg commands
-help          print this help information

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

if (!GetOptions(
    "u|username" => \$username,
    "p|password" => \$password,
    "m|mirror" => \$mirror, 
    "r|retries=i" => \$retries,
    "v|verbose" => \$verbose,
    "n" => \$do_nothing,
    "h|help" => \$help,
    ))
  {
  Usage("Invalid argument");
  }
  
Usage("Too many arguments") if ($ARGV);
Usage("") if ($help);

# Important: This script uses http access to the repositories, so
# the username and password will be stored as cleartext in the
# .hg/hgrc file in each repository.

if ($username eq "" )
  {
  print "Username: ";
  $username = <STDIN>;
  chomp $username;
  }
if ($password eq "" )
  {
  print "Password: ";
  $password = <STDIN>;
  chomp $password;
  }

my @sf_packages = (
"sfl/MCL/sf/adaptation/stubs",
"sfl/MCL/sf/app/camera",
"sfl/MCL/sf/app/commonemail",
"sfl/MCL/sf/app/conntools",
"sfl/MCL/sf/app/contacts",
"sfl/MCL/sf/app/contentcontrol",
"sfl/MCL/sf/app/conversations",
"sfl/MCL/sf/app/devicecontrol",
"sfl/MCL/sf/app/dictionary",
"sfl/MCL/sf/app/files",
"sfl/MCL/sf/app/gallery",
"sfl/MCL/sf/app/graphicsuis",
"sfl/MCL/sf/app/helps",
"sfl/MCL/sf/app/homescreen",
"sfl/MCL/sf/app/im",
"sfl/MCL/sf/app/imgeditor",
"sfl/MCL/sf/app/imgvieweruis",
"sfl/MCL/sf/app/iptelephony",
"sfl/MCL/sf/app/java",
"sfl/MCL/sf/app/location",
"sfl/MCL/sf/app/messaging",
"sfl/MCL/sf/app/mmsharinguis",
"sfl/MCL/sf/app/musicplayer",
"sfl/MCL/sf/app/organizer",
"sfl/MCL/sf/app/phone",
"sfl/MCL/sf/app/photos",
"sfl/MCL/sf/app/poc",
"sfl/MCL/sf/app/printing",
"sfl/MCL/sf/app/profile",
"sfl/MCL/sf/app/radio",
"sfl/MCL/sf/app/screensaver",
"sfl/MCL/sf/app/settingsuis",
"sfl/MCL/sf/app/speechsrv",
"sfl/MCL/sf/app/techview",
# "sfl/MCL/sf/app/test",  - removed in 7 May 09 delivery
"sfl/MCL/sf/app/utils",
"sfl/MCL/sf/app/videocenter",
"sfl/MCL/sf/app/videoeditor",
"sfl/MCL/sf/app/videoplayer",
"sfl/MCL/sf/app/videotelephony",
"sfl/MCL/sf/app/voicerec",
  "oss/MCL/sf/app/webuis",
"sfl/MCL/sf/mw/accesssec",
"sfl/MCL/sf/mw/appinstall",
"sfl/MCL/sf/mw/appsupport",
"sfl/MCL/sf/mw/camerasrv",
"sfl/MCL/sf/mw/classicui",
"sfl/MCL/sf/mw/dlnasrv",
"sfl/MCL/sf/mw/drm",
"sfl/MCL/sf/mw/hapticsservices",
"sfl/MCL/sf/mw/homescreensrv",
"sfl/MCL/sf/mw/imghandling",
"sfl/MCL/sf/mw/imsrv",
"sfl/MCL/sf/mw/inputmethods",
"sfl/MCL/sf/mw/ipappprotocols",
"sfl/MCL/sf/mw/ipappsrv",
"sfl/MCL/sf/mw/ipconnmgmt",
"sfl/MCL/sf/mw/legacypresence",
"sfl/MCL/sf/mw/locationsrv",
"sfl/MCL/sf/mw/mds",
"sfl/MCL/sf/mw/messagingmw",
"sfl/MCL/sf/mw/metadatasrv",
"sfl/MCL/sf/mw/mmappfw",
"sfl/MCL/sf/mw/mmmw",
"sfl/MCL/sf/mw/mmuifw",
# "sfl/MCL/sf/mw/mobiletv", - empty package abandoned
"sfl/MCL/sf/mw/netprotocols",
"sfl/MCL/sf/mw/networkingdm",
"sfl/MCL/sf/mw/opensrv",
"sfl/MCL/sf/mw/phonesrv",
"sfl/MCL/sf/mw/remoteconn",
"sfl/MCL/sf/mw/remotemgmt",
"sfl/MCL/sf/mw/remotestorage",
"sfl/MCL/sf/mw/securitysrv",
  "oss/MCL/sf/mw/serviceapi",
  "oss/MCL/sf/mw/serviceapifw",
"sfl/MCL/sf/mw/shortlinkconn",
"sfl/MCL/sf/mw/svgt",
"sfl/MCL/sf/mw/uiaccelerator",
"sfl/MCL/sf/mw/uiresources",
"sfl/MCL/sf/mw/uitools",
"sfl/MCL/sf/mw/videoutils",
"sfl/MCL/sf/mw/vpnclient",
  "oss/MCL/sf/mw/web",
"sfl/MCL/sf/mw/websrv",
"sfl/MCL/sf/mw/wirelessacc",
"sfl/MCL/sf/os/boardsupport",
"sfl/MCL/sf/os/buildtools",
"sfl/MCL/sf/os/cellularsrv",
"sfl/MCL/sf/os/commsfw",
"sfl/MCL/sf/os/deviceplatformrelease",
"sfl/MCL/sf/os/devicesrv",
"sfl/MCL/sf/os/graphics",
"sfl/MCL/sf/os/imagingext",
"sfl/MCL/sf/os/kernelhwsrv",
"sfl/MCL/sf/os/lbs",
# "sfl/MCL/sf/os/misc",  - removed in 7 May 09 delivery
"sfl/MCL/sf/os/mm",
"sfl/MCL/sf/os/networkingsrv",
"sfl/MCL/sf/os/ossrv",
"sfl/MCL/sf/os/persistentdata",
"sfl/MCL/sf/os/security",
"sfl/MCL/sf/os/shortlinksrv",
"sfl/MCL/sf/os/textandloc",
"sfl/MCL/sf/os/unref",
"sfl/MCL/sf/os/wlan",
"sfl/MCL/sf/os/xmlsrv",
"sfl/MCL/sf/ostools/osrndtools",
"sfl/MCL/sf/tools/build_s60",
"sfl/MCL/sf/tools/buildplatforms",
"sfl/MCL/sf/tools/homescreentools",
"sfl/MCL/sf/tools/makefile_templates",
"sfl/MCL/sf/tools/platformtools",
"sfl/MCL/sf/tools/rndtools",
"sfl/MCL/sf/tools/swconfigtools",
);

my @sftools_packages = (
"sfl/MCL/sftools/ana/compatanaapps",
"sfl/MCL/sftools/ana/compatanamdw",
"sfl/MCL/sftools/ana/dynaanaapps",
"sfl/MCL/sftools/ana/dynaanactrlandcptr",
"sfl/MCL/sftools/ana/dynaanamdw/analysistools",
"sfl/MCL/sftools/ana/dynaanamdw/crashmdw",
"sfl/MCL/sftools/ana/staticanaapps",
"sfl/MCL/sftools/ana/staticanamdw",
"sfl/MCL/sftools/ana/testcreationandmgmt",
"sfl/MCL/sftools/ana/testexec",
"sfl/MCL/sftools/ana/testfw",
# "sfl/MCL/sftools/depl/sdkcreationapps",  - removed in 7 May 09 delivery
"sfl/MCL/sftools/depl/sdkcreationmdw/packaging",
# "sfl/MCL/sftools/depl/sdkcreationmdw/sdkbuild",  - removed in 7 May 09 delivery
# "sfl/MCL/sftools/depl/sdkcreationmdw/sdkdelivery",  - removed in 7 May 09 delivery
# "sfl/MCL/sftools/depl/sdkcreationmdw/sdktest",  - removed in 7 May 09 delivery
"sfl/MCL/sftools/depl/swconfigapps/configtools",
"sfl/MCL/sftools/depl/swconfigapps/swmgnttoolsguides",
"sfl/MCL/sftools/depl/swconfigapps/sysmodeltools",
"sfl/MCL/sftools/depl/swconfigmdw",
# "sfl/MCL/sftools/depl/sysdocapps",  - removed in 7 May 09 delivery
# "sfl/MCL/sftools/depl/sysdocmdw",  - removed in 7 May 09 delivery
# "sfl/MCL/sftools/depl/toolsplatrelease",  - removed in 7 May 09 delivery
"sfl/MCL/sftools/dev/build",
"sfl/MCL/sftools/dev/dbgsrvsmdw",
"sfl/MCL/sftools/dev/devicedbgsrvs",
  "oss/MCL/sftools/dev/eclipseenv/buildlayout34",
  "oss/MCL/sftools/dev/eclipseenv/eclipse",
  "oss/MCL/sftools/dev/hostenv/compilationtoolchains",
  "oss/MCL/sftools/dev/hostenv/cpptoolsplat",
  "oss/MCL/sftools/dev/hostenv/dist",
  "oss/MCL/sftools/dev/hostenv/javatoolsplat",
  "oss/MCL/sftools/dev/hostenv/makeng",
  "oss/MCL/sftools/dev/hostenv/pythontoolsplat",
  "oss/MCL/sftools/dev/ide/carbidecpp",
"sfl/MCL/sftools/dev/ide/carbidecppplugins",
"sfl/MCL/sftools/dev/iss",
"sfl/MCL/sftools/dev/ui",
);

my @other_repos = (
# Foundation build framework
"oss/FCL/interim/fbf/bootstrap",
"oss/FCL/interim/fbf/configs/default",
"oss/FCL/interim/fbf/configs/pkgbuild",
"oss/FCL/interim/fbf/projects/packages/serviceapi",
"oss/FCL/interim/fbf/projects/packages/serviceapifw",
"oss/FCL/interim/fbf/projects/packages/web",
"oss/FCL/interim/fbf/projects/packages/webuis",
"oss/FCL/interim/fbf/projects/platforms",
# Utilities
"oss/MCL/utilities",
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
  if ($license ne "sfl")
    {
    # user registration is not required for reading public package repositories
    $repo_url = "http://developer.symbian.org/$package/";
    }
  
  if (-d "$path/.hg")
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

    # Request the oss package list
    $res = $ua->request(GET "https://$username:$password\@$hostname/sfl");
  
    # Check the outcome of the response
    if (! $res->is_success) 
      {
      print "Failed to read sfl package list:\n\t", $res->status_line, "\n";
      }
    
    my @sfl_packages = ($res->content =~ m/<td><a href="\/(sfl\/[^"]+)\/?">/g);  # umatched "
    
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
