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
use Getopt::Long;

my $sort_recipes = 0;
GetOptions(
  "s|sort" => \$sort_recipes,   # sort output by <recipe> line
  );

my $expression = shift @ARGV;
my $line;
my $skipping = 1;
my $current_target = "";
my @buffer = ();
my %recipes;

@ARGV = map {glob} @ARGV;

sub save_buffer
  {
  return if (scalar @buffer == 0);
  if ($sort_recipes)
    {
    my $recipe = shift @buffer;
    $recipes{$recipe} = join("",@buffer);
    }
  else
    {
    print @buffer;
    }
  @buffer = ();
  }
  
while ($line =<>)
  {
  if (substr($line,0,9) eq "</recipe>")
    {
    push @buffer, $line if ($skipping == 0);  
    $skipping = 1;    # set this to 0 to get the "between recipes" stuff
    next;
    }
  if (substr($line,0,8) eq "<recipe ")
    {
    save_buffer();
    if ($line =~ /$expression/io)
      {
      $skipping = 0;
      $current_target = "";
      if ($line =~ /(target='[^']+') /)
        {
        $current_target = $1;
        }
      }
    else
      {
      $skipping = 1;
      }
    }
  next if ($skipping == 1);  
  if (substr($line,0,8) eq "<status ")
    {
    substr($line,-3) = "$current_target />\n";
    }
  push @buffer, $line;
  }

save_buffer();

if ($sort_recipes)
  {
  foreach my $recipe (sort keys %recipes)
    {
    print $recipe, $recipes{$recipe};
    }
  }