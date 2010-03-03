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
# mattd <mattd@symbian.org>
#
# Description:
# DBR intro - displays some introductory information

def run(args):
  help()

def help():  
  l1 ='\nDBR tools are simply a way of checking what has been changed in the build you are using.' 
  l2 ='\n\nUnlike CBRs, they intentionally make no attempt at understanding components,'
  l3 ='and subsequently they do not have the restrictions that CBRs require.'
  l4 ='\n\nGenerally speaking all developers work from builds of the whole platform,'
  l5 ='and developers want to change the build, and know what they have changed,'
  l6 ='what has changed between builds, or what they have different to other developers'
  l7 ='with as little hastle as possible.'
  
  l8 ='\nThere is a patching mechanism for developer providing patches to eachother for the short-term,'
  l9 ='but the idea is that patches are short-lived, unlike CBRs where they can live forever.'
  l10 ='\n\nIn short, you get most of the benefits of CBRs without the hastle.'  
  print l1,l2,l3,l4,l5,l6,l7,l8,l9,l10  

  s1='\nHow To use\n\n'
  s2='Starting Method 1:\n'
  s3='\t1. Unpack all your zips on to a clean drive\n'
  s4='\t2. Ensure you\'ve extracted the MD5s into epoc32/relinfo\n'
  s5='\t3. Run \'dbr checkenv\' to generate a database\n\n'
  s6='Starting Method 2:\n'
  s7='\t1. Run \'dbr getenv <build_location>\' to install a full build and configure the database\n\n'
  s8='If you want to know what you\'ve changed, run \'dbr checkenv\'\n'
  s9='If you want to clean the environment run \'dbr cleanenv\'\n'
  s10='If you want to compare two baselines run \'dbr diffenv <env1> <env2>\'\n'
  
  
  print s1,s2,s3,s4,s5,s6,s7,s8,s9, s10
  
