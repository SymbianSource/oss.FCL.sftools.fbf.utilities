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
# Filter an SBSv2 log to keep only recipes which match a specified RE

use strict;

my $expression = shift @ARGV;
my $line;
my $skipping = 1;

@ARGV = map {glob} @ARGV;

while ($line =<>)
  {
  if (substr($line,0,9) eq "</recipe>")
    {
    print $line if ($skipping == 0);  
    $skipping = 1;    # set this to 0 to get the "between recipes" stuff
    next;
    }
  if (substr($line,0,8) eq "<recipe ")
    {
    if ($line =~ /$expression/io)
      {
      $skipping = 0;
      }
    else
      {
      $skipping = 1;
      }
    }
  print $line if ($skipping == 0);  
  }