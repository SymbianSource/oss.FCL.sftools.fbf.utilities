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

my @clone_options = (); # use ("--noupdate") to clone without extracting the source
my $hostname = "developer.symbian.org";

# Important: This script uses http access to the repositories, so
# the username and password will be stored as cleartext in the
# .hg/hgrc file in each repository.

my $username = "";
my $password = "";

if ($username eq "" || $password eq "")
  {
  print "Must edit this script to supply your username and password\n";
  exit 1;
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
"sfl/MCL/sf/mw/mobiletv",
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
"sfl/MCL/sf/os/osrndtools",   # added 7 Mar 09
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

foreach my $package (@sf_packages, @sftools_packages)
  {
  my @dirs = split /\//, $package;
  my $license = shift @dirs;
  my $repotree = shift @dirs; # remove the MCL or FCL repo tree information
  my $destdir = pop @dirs;  # ignore the package name, because Mercurial will create that
  
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
    system("hg", "pull", "-R", $path, $repo_url);
    }
  else
    {
    # Clone the repository
    
    print "Cloning $destdir from $package...\n";
    system("hg", "clone", @clone_options, $repo_url, $path);
    }
  
  }
