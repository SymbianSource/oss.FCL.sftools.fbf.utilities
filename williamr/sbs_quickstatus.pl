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
# Filter an SBSv2 log to keep only status lines, with added target and recipe names

use strict;

my $line;
my $current_target = "";
my $recipe_name = "";

@ARGV = map {glob} @ARGV;

while ($line =<>)
  {
  my $prefix = substr($line,0,8);
  if ($prefix eq "<recipe ")
    {
    $current_target = "";
    if ($line =~ /(name='[^']+').*(target='[^']+')/)
      {
      $recipe_name = $1;
      $current_target = $2;
      }
    next;
    }
  if ($prefix eq "+ EXTMAK")
    {
    if ($line =~ / (EXTMAKEFILENAME=.*)$/)
      {
      $current_target = "comment='$1'";  # target for EXTMAKEFILE is not interesting
      }
    next;
    }
  if ($prefix eq "+ TEMPLA") 
    {
    if ($line =~ / (TEMPLATE_EXTENSION_MAKEFILE=.*)$/)
      {
      $current_target = "comment='$1'";  # target for templated extensions is not interesting
      }
    next;
    }
  if ($prefix eq "<status ")
    {
    substr($line,-3) = "$recipe_name $current_target />\n";
    print $line;
    next;
    }
  }