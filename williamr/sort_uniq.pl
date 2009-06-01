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
# Make up for lack of "sort | uniq" on Windows

use strict;
my $line;

my %uniq;
while ($line = <>)
  {
  $uniq{$line} = 1;
  }

print sort keys %uniq;

