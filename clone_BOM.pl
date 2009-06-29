#!/usr/bin/perl -w
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
# Perl script to clone or update all Foundation repositories based on content of 
# BOM (bill of materials) file provided with a PDK release


use strict;

use XML::DOM ();
use Getopt::Long;


my ($help,$verbose,$build_info,$rincoming,$rstatus,$rclean);
my $username="";
my $password="";
my $rclone=1;

my $opts_err = GetOptions(
  "h|help" => \$help,			# print Usage
  "b|build-info=s" => \$build_info,		    # build info xml file
  "u|user=s" => \$username, # user name when pushing to foundation
  "p|password=s" => \$password, # password when pushing to foundation
  "status!"=> \$rstatus,     #flag to request hg status for each repo
  "incoming!"=>\$rincoming,   #flag to request incoming for each repo from sf repositories
  "clean!"=>\$rclean, # flag to request clean the working source tree
  "clone!"=>\$rclone, # flag to request clone   
  "verbose!" => \$verbose,		#verbosity, currently only on or off (verbose or noverbose)
) or die ("Error processing options\n\n" . Usage() );

# check if there were any extra parameters ignored by GetOptions
@ARGV and die ("Input not understood - unrecognised paramters : @ARGV \n\n" . Usage() );

if ($help)
{
    print Usage();
    exit;
}
if (! defined ($build_info))
{
    die ("Need to specify the BOM file, e.g. -b build-info.xml\n\n".Usage());
}
if (!-f $build_info) {die " Can't find build info file $build_info\n"}


if (defined($rincoming) || ($rclone))
{
  ## if you are going to try any operations on foundation host need password 
  if ($username eq "" || $password eq "")
  {
    print "Must supply your username and password to talk to Foundation host\n";
    exit 1;
  }
}

my ( $parser, $buildinfoxml );
eval
{
    $parser = XML::DOM::Parser->new();
    $buildinfoxml    = $parser->parsefile($build_info);
};
if ( $@ )
{
    print "Fatal XML error processing build info file: $@";
}
my @baseline_entries = $buildinfoxml->getElementsByTagName('baseline');

foreach my $repository (@baseline_entries)
{
#    print $repository->toString();

    my $baseline = $repository->getFirstChild->getNodeValue;
    # e.g. E:/hg_cache/mercurial_master_prod/sfl/MCL/sf/tools/swconfigtools/#2:fa09df6b7e6a
    $baseline =~ m/(.*?)#\d*:(.*)$/; 
    my $repo_path = $1;      # e.g. E:/hg_cache/mercurial_master_prod/sfl/MCL/sf/tools/swconfigtools/
    my $changeset = $2; # e.g fa09df6b7e6a

    $repo_path =~ m/.*?(oss|sfl).(MCL|FCL)(.*$)/;
    my $license = $1;
    my $codeline =$2;
    my $package =$3;
    my $sf_repo = "https://$username:$password\@developer.symbian.org/$1/$2$package";
    $sf_repo =~ s!\\!\/!g;
    my @dirs = split /\//, $package;
    my $destdir = pop @dirs;  # ignore the package name, because Mercurial will create that
    # Ensure the directories already exist as far as the parent of the repository
    my $local_path = "";
    foreach my $dir (@dirs)
    {
      $local_path = ($local_path eq "") ? $dir : "$local_path/$dir";
      if (!-d $local_path)
      {
        mkdir $local_path;
      }
    }
    $local_path .= "/$destdir";   # this is where the repository will go
    $local_path =~ s!\\!\/!g;

    if($rclone)
    {
       if (-d "$local_path/.hg")
       {
          # The repository already exists, so just do an update
          print "Updating $local_path from $sf_repo at changeset $changeset\n";
          system("hg", "pull", "-R", $local_path, $sf_repo);
          system("hg","-R", $local_path,"update",$changeset);
      }
      else
      {
          # hg clone -U    http://«user»:«password»@developer.symbian.org/sfl/MCL/adaptation/stubs/",
          print "Cloning $local_path from $sf_repo and update to changeset $changeset \n";
          # need to update the working directory otherwise the parent of the tag change create a new head
          system("hg", "clone", "--noupdate",$sf_repo, $local_path);
          system("hg","-R", $local_path,"update",$changeset);
      }
    }

    if (-d "$local_path/.hg")
    {
      if($rincoming)
      {
          system("hg","-R", $local_path,"incoming",$sf_repo);
      }
      if($rstatus)
      {
          print "Identify $local_path ";
          system("hg","-R", $local_path, "identify");
          system("hg","-R", $local_path, "status");
      }
      if($rclean)
      {
        print "Clean $local_path ";
        system("hg","-R", $local_path,"update","-C",$changeset);
        my @added =`hg -R $local_path status`;
        foreach my $addedfile (@added)
        {
          $addedfile =~ s/\?\s*/\.\/$local_path\//;
          $addedfile =~ s!\/!\\!g;
          print "del $addedfile\n";
       #   system("del", $addedfile);
          #unlink($addedfile);       
        }
      }
    }
    else
    {
        print "ERROR: No repository found at $local_path\n";
    }
}

sub Usage
{
  return <<"EOF";
Usage: clone_BOM.pl -b <build info file> [-status] [-incoming] [-u <user name> -p <password>] [-verbose]

Description:
	Clones repositories listed in the build BOM 
	Optionally can display status of local repositories
	and preview of incoming changes from Foundation repos

Arguments:
    -h -> Output this usage message;
    -b -> file containing the build info (xml BOM format)
    -u -> User name (required if accessing the Foundation repositories)
    -p -> Password (required if accessing the Foundation repositories)
    -status -> Query hg identify and hg status for each local repo
    -incoming -> Query any incoming changes from the Foundation host
    -clean -> clean the local source tree (n.b. removes local files not committed to mercurial)
    -noclone -> skip the clone repositories step
    -verbose -> more debug statements (optional, default off)
EOF
}