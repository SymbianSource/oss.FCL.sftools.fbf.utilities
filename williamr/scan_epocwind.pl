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
# Summarise epocwind.out to identify repetitious and uninteresting comments

use strict;

my %count_by_word;
my %unique_message;

my $line;
while ($line = <>)
  {
  chomp $line;
  
  #    494.390	CTouchFeedbackImpl::SetFeedbackArea - Begin
  my $message = substr($line, 10);  # ignore the timestamp & the tab character
  if (!defined $unique_message{$message})
    {
    $unique_message{$message} = 0;
    }
  $unique_message{$message} ++;
  
  my ($junk,$count,$word) = split /\s+|:/, $line;
  $word = $message if (!defined $word);   # no spaces in the line at all

  if (!defined $count_by_word{$word})
    {
    $count_by_word{$word} = 0;
    }
  $count_by_word{$word} ++;
  
  }

my @repeated_lines;
foreach my $message (keys %unique_message)
  {
  my $count = $unique_message{$message};
  next if ($count < 10);
  push @repeated_lines, sprintf "%7d\t%s\n", $count, $message;
  }

print "Repeated lines\n", reverse sort @repeated_lines, "\n";

my @repeated_words;
foreach my $word (keys %count_by_word)
  {
  my $count = $count_by_word{$word};
  next if ($count < 10);
  push @repeated_words, sprintf "%7d\t%s\n", $count, $word;
  }

print "Repeated words (rest of the line may vary\n", reverse sort @repeated_words, "\n";

