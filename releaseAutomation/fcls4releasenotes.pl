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
# Arnaud Lenoir
#
# Description:
# Task 243 - Generate FCLs details between 2 PDKs to be included as part of the release notes

# Here is the location for the naming convention for the PDKs: http://developer.symbian.org/wiki/index.php/Build_and_Integration

#
# Configuration data and constants for the script
#
print "\n";
my $default_pdk_loc='\\\\bishare\\releases\\';
print "default_pdk_loc=$default_pdk_loc\n";

# Nb of arguments to be passed to the script to work. If that need to change, just modify nb_arg_to_pass!
my $nb_arg_to_pass=2;
print "nb_arg_to_pass=$nb_arg_to_pass\n";

# Name of the file that contains the data we need to extract for this script
my $name_zip_file_to_extract="build_BOM\.zip";

# Pattern used to search for PDKs
my $pdk_start_pattern="PDK_";

# Pattern used to extract info from the xml file
my $starting_pattern_for_xml_extraction="<name>Sources</name>";
my $ending_pattern_for_xml_extraction="</project>";
# Pattern to extract data from the line in the file
# Branch type. If not a branch type, we are not interested
my $branch_type_extraction_pattern="(MCL|FCL)";

my $mcl_cste="MCL";
my $fcl_cste="FCL";

# package name
#/imgeditor/#:86a88f39b644</baseline>
# # is used to define the changeset number for mercurial.
# Therefore if we have a look what is before "/#", we should always find the package name!!
my $package_extraction_pattern = "([^/]+)/?#";

# When that "boolean value is set to 1 or true, then the line we read in the file can be search for the information we want to extract
# If $starting_pattern_for_xml_extraction true, then set extraction_from_xml_is_allowed to true/1
# If $ending_pattern_for_xml_extraction false, then reset extraction_from_xml_is_allowed to false/0
# $ending_pattern_for_xml_extraction is called several times in the program, but this is not a problem as we don't set it to false/0 and therefore do nothing!
my $extraction_from_xml_is_allowed=0;

# Temporary location used to do the work
my $working_drive="c:";
my $working_directory="temp";
my $working_sub_directory="fcl_extraction";
my $working_pdk1_directory="pdk1";
my $working_pdk2_directory="pdk2";

# Name of the file we need to work on to extract the data necessary for the Release Notes
my $name_of_file_to_compare="build-info.xml";

# Name of the file that we are creating to hold the information necessary for the Release Notes
my $name_of_file_to_publish="fcl_info.txt";
#Location for that file
my $location_of_file_to_publish="c:\\temp";
my $file_path="$location_of_file_to_publish\\$name_of_file_to_publish";

#
# End configuration data for the script
#


# Get parameters passed to the script. Save only the 2 first parameters as we need only 2 parameters for the script
print "\n";
my $nb_arg_passed = scalar(@ARGV);
print "nb_arg_passed=$nb_arg_passed\n"; # Find out the number of arguement passed
print "@ARGV\n\n";
if ($nb_arg_passed != $nb_arg_to_pass)
{
	helpme();
}

# Needs to be done here, otherwise lost if try to recover them later on. Why?
my $arg1_passed = $ARGV[0];
my $arg2_passed = $ARGV[1];
print "arg1_passed= $arg1_passed \t arg2_passed=$arg2_passed\n";

# Modules necessary to run this script
use Getopt::Long;
use strict;


# Arguments / Data used for the script
my $pdknb1 = '';
my $pdknb2 = '';
my $pdkloc1 = '';
my $pdkloc2 = '';
my $pdkname1 = '';
my $pdkname2 = '';

my $help = 0;

GetOptions((
	'pdknb1=s' => \$pdknb1,
	'pdknb2=s' => \$pdknb2,
	'pdkname1=s' => \$pdkname1,
	'pdkname2=s' => \$pdkname2,
	'pdkloc1=s' => \$pdkloc1,
	'pdkloc2=s' => \$pdkloc2,
	'help!' => \$help
));

print "\$pdknb1=$pdknb1\n";
print "\$pdknb2=$pdknb2\n";
print "\$pdkname1=$pdkname1\n";
print "\$pdkname2=$pdkname2\n";
print "\$pdkloc1=$pdkloc1\n";
print "\$pdkloc2=$pdkloc2\n";

my $count_arg=0; # Caculate the number of arguments we need for the script to work and that we know are correct (help doesn't count)

# First PDK to check
my $pdk_path1="";
my $pdk_complete_name1=0;
my $pdk_complete_path1=0;
my $pdk_path1_now_in_use=0;
my $pdk_values_to_search1=""; # Not necessary
my $pdk_path1_exist=0;
my $pdk_zip1_exit=0; # Not necessary
my $pdk1_correct_name_to_use="";
my $loc1_contains_the_zip_file_we_need=0;

# Second PDK to check
my $pdk_path2="";
my $pdk_complete_name2=0;
my $pdk_complete_path2=0;
my $pdk_path2_now_in_use=0;
my $pdk_values_to_search2=""; # Not necessary
my $pdk_path2_exist=0;
my $pdk_zip2_exist=0; # Not necessary
my $pdk2_correct_name_to_use="";
my $loc2_contains_the_zip_file_we_need=0;


# Default directory management
my @directories_list_default_location=();
my $nb_dir_in_default_loc;
my @pdk_dir_list_in_default_location=();
my $nb_pdks_in_default_loc=0;
my @pdks_with_valid_zip_in_default_loc=();
my $nb_pdks_with_valid_zip_in_default_loc=0;
my @find_pdk_for_corresponding_nb1=();
my $nb_of_pdk_for_corresponding_nb1=0;
my @find_pdk_for_corresponding_nb2=();
my $nb_of_pdk_for_corresponding_nb2=0;
my @find_pdk_for_corresponding_name1=();
my $nb_of_pdk_for_corresponding_name1=0;
my @find_pdk_for_corresponding_name2=();
my $nb_of_pdk_for_corresponding_name2=0;
my @read_files_in_loc=();

# Data / statistics to be displayed in the release notes
# We consider that pdk1 is the old version and pdk2 is the new version.
# Note that for the moment, the scripts is not able to make sure that the old version of the pdk is set as pdk1 and the new version of the pdk is set as pdk2!!!!!
# Can be done for pdknb and pdkname but not for pdkloc as for the moment, no way to find out the pdk version from the build-info.xmL!!!!
# Totals
my $total_packages_pdk1=0;		# Nb of packages included in the pdk1
my $total_packages_pdk2=0;		# Nb of packages included in the pdk2
my $total_packages_added=0;		# Nb of packages added in the pdk2
my $total_packages_removed=0;	# Nb of packages removed from the pdk2
my $total_new_fcl=0;			# Nb of packages that are now on fcl in pdk2 (means were mcl in pdk1 and are now fcl in pdk2)
my $total_no_more_fcl=0;		# Nb of packages that are no more on fcl in pdk2 (means were fcl in pdk1 and are now mcl in pdk2)
my $total_still_fcl=0;			# Nb of packages that are still on fcl in pdk2 (means were fcl in pdk1 and are still fcl in pdk2)
my $total_very_good_mcl=0;		# Nb of packages that are very good on mcl in pdk1 and pdk2 (means were on mcl in pdk1 and are still mcl in pdk2)
# Tables
my @pdk1_sorting_table;			# Table for pdk1 that is used to sort out and compare the 2 pdks
my @pdk2_sorting_table;			# Table for pdk2 that is used to sort out and compare the 2 pdks
my @packages_added_table;		# Table that contains the packages that have been added to pdk2
my @packages_removed_table;		# Table that contains the packages that have been deleted from pdk2
my @new_fcl_table;				# Table containing the packages that are now on fcl in pdk2 (means were mcl in pdk1 and are now fcl in pdk2)
my @no_more_fcl_table;			# Table containing the packages that are no more on fcl in pdk2 (means were fcl in pdk1 and are now mcl in pdk2)
my @still_fcl_table;			# Table containing the packages that are still on fcl in pdk2 (means were fcl in pdk1 and are still fcl in pdk2)
my @very_good_mcl_table;		# Table containing the packages that are very good on mcl in pdk1 and pdk2 (means were on mcl in pdk1 and are still mcl in pdk2)


# Check that we have only 2 values for the PDKs. If not 2, then not good!


# Script code start here!
if($pdknb1)
{
	$count_arg++;
	
	# Get data for first pdk used for the comparison
	$pdk_path1 = $default_pdk_loc;
	$pdk_complete_name1=1;
	$pdk_complete_path1=1;
	$pdk_path1_now_in_use=1;
	$pdk_values_to_search1=$pdknb1; # Not necessary
}
if($pdknb2)
{
	$count_arg++;
	
	# Get data for first pdk used for the comparison
	$pdk_path2 = $default_pdk_loc;
	$pdk_complete_name2=1;
	$pdk_complete_path2=1;
	$pdk_path2_now_in_use=1;
	$pdk_values_to_search2=$pdknb2; # Not necessary
}
if($pdkname1)
{
	$count_arg++;
	
	if(!$pdk_path1_now_in_use)
	{
		# Get data for first pdk used for the comparison
		$pdk_path1 = $default_pdk_loc;	
		$pdk_complete_path1=1;	
		$pdk_path1_now_in_use=1;
		$pdk_values_to_search1=$pdkname1; # Not necessary
	}
	else
	{
		if(!$pdk_path2_now_in_use)
		{
			# Get data for first pdk used for the comparison
			$pdk_path2 = $default_pdk_loc;	
			$pdk_complete_path2=1;
			$pdk_path2_now_in_use=1;
			$pdk_values_to_search2=$pdkname1; # Not necessary
		}
	}
}
if($pdkname2)
{
	$count_arg++;

	if(!$pdk_path2_now_in_use)
	{
		# Get data for first pdk used for the comparison
		$pdk_path2 = $default_pdk_loc;	
		$pdk_complete_path2=1;
		$pdk_path2_now_in_use=1;
		$pdk_values_to_search2=$pdkname2; # Not necessary
	}
	else
	{
		if(!$pdk_path1_now_in_use)
		{
			# Get data for first pdk used for the comparison
			$pdk_path1 = $default_pdk_loc;	
			$pdk_complete_path1=1;	
			$pdk_path1_now_in_use=1;
			$pdk_values_to_search1=$pdkname2; # Not necessary
		}
	}
}
if($pdkloc1)
{
	$count_arg++;
	
	if(!$pdk_path1_now_in_use)
	{
		# Get data for first pdk used for the comparison
		$pdk_path1 = $pdkloc1;
		$pdk_path1_now_in_use=1;
	}
	else
	{
		if(!$pdk_path2_now_in_use)
		{
			# Get data for first pdk used for the comparison
			$pdk_path2 = $pdkloc1;
			$pdk_path2_now_in_use=1;
		}
	}
}

if($pdkloc2)
{
	$count_arg++;

	if(!$pdk_path2_now_in_use)
	{
		# Get data for first pdk used for the comparison
		$pdk_path2 = $pdkloc2;
		$pdk_path2_now_in_use=1;
	}
	else
	{
		if(!$pdk_path1_now_in_use)
		{
			# Get data for first pdk used for the comparison
			$pdk_path1 = $pdkloc2;
			$pdk_path1_now_in_use=1;
		}
	}
}

print "count_arg=$count_arg\n";


# If no parameters entered or help selected, display help
if ($count_arg != $nb_arg_to_pass)
{
	#$help = 1;
	helpme();
	print"\nThe script accepts $nb_arg_to_pass parameters only!\n\n";
}


#
# If we reach this point, this means that we have the right numbers of arguments passed to the script.
#
print "\nWe are on the right path!!!!\n";

print "pdk_path1=$pdk_path1\n";
print "pdk_complete_name1=$pdk_complete_name1\n";
print "pdk_complete_path1=$pdk_complete_path1\n";
print "pdk_values_to_search1=$pdk_values_to_search1\n"; # Not necessary
print "\n";
print "pdk_path2=$pdk_path2\n";
print "pdk_complete_name2=$pdk_complete_name2\n";
print "pdk_complete_path2=$pdk_complete_path2\n";
print "pdk_values_to_search2=$pdk_values_to_search2\n"; # Not necessary
print "\n\n";

# Get directory listing of all directories in the default location $default_pdk_loc
extract_dir_default_loc();
extract_pdk_in_default_loc();
extract_pdk_with_valid_zip_in_default_loc();

# Compose path if necessary.
print "\n";

my $find_val=0;

if ($pdk_complete_path1)
{
	if ($pdk_complete_name1)
	{
		print "We have the PDK number, we need to define if possible the PDK name and therefore the path to the PDK\n";
		# Have a look in the default directory if there is a PDK with that number. If none or more than one with the same id, returns the list of PDKs with that same number
		foreach $find_val (@pdks_with_valid_zip_in_default_loc)
		{
			#print $find_val, "\n";
			if($find_val =~ /$pdknb1/i)
			{
				$find_pdk_for_corresponding_nb1[$nb_of_pdk_for_corresponding_nb1++]=$find_val;
			}
		}
		print "Table find_pdk_for_corresponding_nb1 is:\n";
		display_array_one_line_at_the_time(@find_pdk_for_corresponding_nb1);
		
		if($nb_of_pdk_for_corresponding_nb1==1)
		{
			print "There is only $nb_of_pdk_for_corresponding_nb1 PDK with the name corresponding to the PDK number given, we can keep going!\n";
		}
		else
		{
			print "There is $nb_of_pdk_for_corresponding_nb1 PDKs with the same name, please select one in the list above and run the perl script again with the right PDK name\n";
			exit(0);
		}
		
		#extract PDK name if only one
		$pdk1_correct_name_to_use = $find_pdk_for_corresponding_nb1[0];
		$pdk_path1 .= $find_pdk_for_corresponding_nb1[0];
		print "pdknb1 = $pdknb1\n";
	}
	else
	{
		print "We have the PDK Name therefore we can define the path to the PDK\n";

		# Have a look in the default directory if there is a PDK with that number. If none or more than one with the same id, returns the list of PDKs with that same number
		foreach $find_val (@pdks_with_valid_zip_in_default_loc)
		{
			#print $find_val, "\n";
			if($find_val =~ /$pdkname1/i)
			{
				$find_pdk_for_corresponding_name1[$nb_of_pdk_for_corresponding_name1++]=$find_val;
			}
		}
		print "Table find_pdk_for_corresponding_name1 is: \n";
		display_array_one_line_at_the_time(@find_pdk_for_corresponding_name1);
		
		if($nb_of_pdk_for_corresponding_name1==1)
		{
			print "There is only $nb_of_pdk_for_corresponding_name1 PDK with the name corresponding to the PDK name given, we can keep going!\n";
		}
		else
		{
			print "There is $nb_of_pdk_for_corresponding_name1 PDKs with the same name, please select one in the list above and run the perl script again with the right PDK name\n";
			exit(0);
		}
		
		#extract PDK name if only one
		$pdk1_correct_name_to_use = $find_pdk_for_corresponding_name1[0];
		$pdk_path1 .= @find_pdk_for_corresponding_name1[0];
		print "pdkname1 = $pdkname1\n";
	}
	print "The PDK used is: $pdk1_correct_name_to_use\n";
	print "pdk_path1 = $pdk_path1\n";
}

$find_val=0;

if ($pdk_complete_path2)
{
	if ($pdk_complete_name2)
	{
		print "We have the PDK number, we need to define if possible the PDK name and therefore the path to the PDK\n";
		# Have a look in the default directory if there is a PDK with that number. If none or more than one with the same id, returns the list of PDKs with that same number
		foreach $find_val (@pdks_with_valid_zip_in_default_loc)
		{
			#print $find_val, "\n";
			if($find_val =~ /$pdknb2/i)
			{
				$find_pdk_for_corresponding_nb2[$nb_of_pdk_for_corresponding_nb2++]=$find_val;
			}
		}
		print "Table find_pdk_for_corresponding_nb is:\n";
		display_array_one_line_at_the_time(@find_pdk_for_corresponding_nb2);
		
		if($nb_of_pdk_for_corresponding_nb2==1)
		{
			print "There is only $nb_of_pdk_for_corresponding_nb2 PDK with the name corresponding to the PDK number given, we can keep going!\n";
		}
		else
		{
			print "There is $nb_of_pdk_for_corresponding_nb2 PDKs with the same name, please select one in the list above and run the perl script again with the right PDK name\n";
			exit(0);
		}
		
		#extract PDK name if only one
		$pdk2_correct_name_to_use = $find_pdk_for_corresponding_nb2[0];
		$pdk_path2 .= $find_pdk_for_corresponding_nb2[0];
		print "pdknb2 = $pdknb2\n";
	}
	else
	{
		print "We have the PDK Name therefore we can define the path to the PDK\n";
	
		# Have a look in the default directory if there is a PDK with that number. If none or more than one with the same id, returns the list of PDKs with that same number
		foreach $find_val (@pdks_with_valid_zip_in_default_loc)
		{
			#print $find_val, "\n";
			if($find_val =~ /$pdkname2/i)
			{
				$find_pdk_for_corresponding_name2[$nb_of_pdk_for_corresponding_name2++]=$find_val;
			}
		}
		print "Table find_pdk_for_corresponding_name2 is:\n";
		display_array_one_line_at_the_time(@find_pdk_for_corresponding_name2);
		
		if($nb_of_pdk_for_corresponding_name2==1)
		{
			print "There is only $nb_of_pdk_for_corresponding_name2 PDK with the name corresponding to the PDK name given, we can keep going!\n";
		}
		else
		{
			print "There is $nb_of_pdk_for_corresponding_name2 PDKs with the same name, please select one in the list above and run the perl script again with the right PDK name\n";
			exit(0);
		}
		
		#extract PDK name if only one
		$pdk2_correct_name_to_use = $find_pdk_for_corresponding_name2[0];
		$pdk_path2 .= @find_pdk_for_corresponding_name2[0];
		print "pdkname2 = $pdkname2\n";		
	}
	print "The PDK used is: $pdk2_correct_name_to_use\n";
	print "pdk_path2 = $pdk_path2\n";
}

# Find out if the locations are correct or not. We just need to make sure that the location contains the build_BOM.zip, if it's the case, then bingo! If not, exit the program.
my $loc_var;

if($pdkloc1)
{
	# Get the list of file in the location choosen.
	opendir(LOC1_DIR, $pdkloc1);
	@read_files_in_loc = readdir(LOC1_DIR);
	close(LOC1_DIR);
	
	#print "List of files in the directory: @read_files_in_loc\n";
	
	foreach $loc_var (@read_files_in_loc)
	{
		#if($loc_var =~ /$name_zip_file_to_extract[^.\w]/)
		if($loc_var =~ /$name_zip_file_to_extract$/)
		{
			print "We found the file: $loc_var\n";
			
			$pdk1_correct_name_to_use = "PDK1";
			$pdk_path1 = $pdkloc1;
			
			print "The PDK used is: $pdk1_correct_name_to_use\n";
			print "pdk_path1 = $pdk_path1\n";
			$loc1_contains_the_zip_file_we_need=1;
			
			# As we have found the file, we can probably break!
		}
	}
	if(!$loc1_contains_the_zip_file_we_need)
	{
		print "We can't find the file $name_zip_file_to_extract in the location $pdkloc2 and therefore we can't go any further!!\n";
		exit(0);
	}
}
print "\n";

if($pdkloc2)
{
	# Get the list of file in the location choosen.
	opendir(LOC2_DIR, $pdkloc2);
	@read_files_in_loc = readdir(LOC2_DIR);
	close(LOC2_DIR);
	
	#print "List of files in the directory: @read_files_in_loc\n";
	
	foreach $loc_var (@read_files_in_loc)
	{
		#if($loc_var =~ /$name_zip_file_to_extract[^.\w]/)
		if($loc_var =~ /$name_zip_file_to_extract$/)
		{
			print "We found the file: $loc_var\n";
			
			$pdk2_correct_name_to_use = "PDK2";
			$pdk_path2 = $pdkloc2;
			
			print "The PDK used is: $pdk2_correct_name_to_use\n";
			print "pdk_path2 = $pdk_path2\n";
			$loc2_contains_the_zip_file_we_need=1;
			
			# As we have found the file, we can probably break!
		}
	}
	if(!$loc2_contains_the_zip_file_we_need)
	{
		print "We can't find the file $name_zip_file_to_extract in the location $pdkloc2 and therefore we can't go any further!!\n";
		exit(0);
	}
}

print "\n";
print "If we are here, this means that both $name_zip_file_to_extract have been found and we can start the real work to compare the 2 files to extract what we need!\n";
print "This is the value for the path we are looking at for pdk_path1: $pdk_path1\n";
print "This is the value for the path we are looking at for pdk_path2: $pdk_path2\n";

# When we are at this point, we know we have 2 build_BOM.zip files that we can compare them!!!!

my $system_cmd = "";

my $working_dir="$working_drive\\$working_directory\\$working_sub_directory";
my $working_dir1="$working_drive\\$working_directory\\$working_sub_directory\\$working_pdk1_directory";
my $working_dir2="$working_drive\\$working_directory\\$working_sub_directory\\$working_pdk2_directory";

# 1st step is to extract the 2 zip files to allow us to have access to build-info.xml

# Extract just one file from the zip file using "7z e -r -oOutput_Directory"
#7z e -r build_BOM.zip build-info.xml
# Where 7z is the unzip program
# Where e is for extraction of a file
# Where -r is for recursive to make sure we have a look in the subdirectories
# Where -oOutput_Directory is the directory where we want the files to be unzipped
#
# Where $working_sub_directory is the directory where we will be carry the work to be done for the script.
# Where $working_pdk1_directory is the subdirectory destination for the PDK1
# Where $name_zip_file_to_extract is the name of the zip file (in our case: build_BOM.zip)
# Where $pdk_path1 is the place where the zip file to unzip is
# where $name_of_file_to_compare is the name of the file we want to extract from the zip file (in our case: build-info.xml)
# Example: 7z e -r -oc:\temp\fcl_extraction\pdk1 C:\temp\Task243Test\PDK_1\build_BOM.zip build-info.xml

# Extract file from 1st PDK
$system_cmd = "7z e -r -o$working_dir1 $pdk_path1\\$name_zip_file_to_extract $name_of_file_to_compare";
print "Exec: $system_cmd\n";
system($system_cmd);

print "\n";

# Extract file from 2nd PDK
$system_cmd = "7z e -r -o$working_dir2 $pdk_path2\\$name_zip_file_to_extract $name_of_file_to_compare";
print "Exec: $system_cmd\n";
system($system_cmd);

# 2nd step is to extract the information we need from the 2 files build-info.xml

# Create 2 hash arrays that will contain the name of the package as key and the value associated as MCL or FCL
my %build_info_xml1;
my %build_info_xml2;
my @sorting_build_info_xml1;
my @sorting_build_info_xml2;

#my @display_hash_array;
my $key;
# Define the path for the files to work on
my $path_to_pdk1_file_to_work_on="$working_dir1\\$name_of_file_to_compare";
my $path_to_pdk2_file_to_work_on="$working_dir2\\$name_of_file_to_compare";

print "\n";

my $count_packages=0;
my @not_sorted_table;

# Keep only what we need and keep it safe somewhere.
# pdk1
%build_info_xml1 = extract_packages_and_branch_type_from_file($path_to_pdk1_file_to_work_on);

print "%build_info_xml1:\n";
# Define the number of packages for pdk1
$total_packages_pdk1 = keys %build_info_xml1;
print "\nThere is $total_packages_pdk1 packages for $pdk1_correct_name_to_use\n";

# 3rd a) step is to sort out the 2 files / table
# Sort out the tables to facilitate the checking of the different packages
@not_sorted_table = keys %build_info_xml1;

#print "\nnot_sorted_table:\n @not_sorted_table\n";

# ascendant alphabetical sort
@pdk1_sorting_table = sort { lc($a) cmp lc($b) } @not_sorted_table;

#print "\npdk1_sorting_table :\n @pdk1_sorting_table\n";

print "\n";

# pdk2
%build_info_xml2 = extract_packages_and_branch_type_from_file($path_to_pdk2_file_to_work_on);
print "%build_info_xml2:\n";
# Define the number of packages for pdk2
$total_packages_pdk2 = keys %build_info_xml2;
print "\nThere is $total_packages_pdk2 packages for $pdk2_correct_name_to_use\n";

# 3rd b) step is to sort out the 2 files / table
# Sort out the tables to facilitate the checking of the different packages
@not_sorted_table = keys %build_info_xml2;

#print "\nnot_sorted_table:\n @not_sorted_table\n";

# ascendant alphabetical sort
@pdk2_sorting_table = sort { lc($a) cmp lc($b) } @not_sorted_table;

#print "\npdk2_sorting_table :\n @pdk2_sorting_table\n";

print "\n";

# 4th step is to compare both data and export it to a file or something similar that is good for media wiki.
# Compare both files to find out the difference between each packages FCL, MCL, added or deleted packages

my $tab_counter1=0;
my $tab_counter2=0;
my $compare_2_tables;
my $value_package_pdk1;
my $value_package_pdk2;

while (($tab_counter1 < $total_packages_pdk1) && ($tab_counter2 < $total_packages_pdk2)) # or should it be ||
{
	#print "tab_counter1=$tab_counter1, total_packages_pdk1=$total_packages_pdk1\ntab_counter2=$tab_counter2, total_packages_pdk2=$total_packages_pdk2\n";
	#print "packages in pdk1 is $pdk1_sorting_table[$tab_counter1] and in pdk2 is $pdk2_sorting_table[$tab_counter2]\n";
	
	# $a cmp $b
	# if $a > $b value returned is 1
	# if $a = $b value returned is 0
	# if $a < $b value returned is -1
	
	$compare_2_tables = ( $pdk1_sorting_table[$tab_counter1] cmp $pdk2_sorting_table[$tab_counter2] );
	#print "compare_2_tables=$compare_2_tables\n";
	
	if(!$compare_2_tables)	# Compare if the the packages in the tables(index) are the same or not, if $compare_2_tables=0, then equal
	{
		#print "the package is the same in pdk1_sorting_table and pdk2_sorting_table\n";
		
		$value_package_pdk1 = $build_info_xml1{$pdk1_sorting_table[$tab_counter1]};
		$value_package_pdk2 = $build_info_xml2{$pdk2_sorting_table[$tab_counter2]};
		#print "value_package_pdk1=$value_package_pdk1\n";
		#print "value_package_pdk2=$value_package_pdk2\n";
		
		if(($value_package_pdk1 eq $mcl_cste) && ($value_package_pdk2 eq $fcl_cste))
		{
			#print "the package was MCL and is now FCL - NEW\n";
			$new_fcl_table[$total_new_fcl++] = $pdk1_sorting_table[$tab_counter1];
		}
		else
		{
			if(($value_package_pdk1 eq $fcl_cste) && ($value_package_pdk2 eq $mcl_cste))
			{
				#print "the package was FCL and is now MCL - NO MORE\n";
				$no_more_fcl_table[$total_no_more_fcl++] = $pdk1_sorting_table[$tab_counter1];
			}
			else
			{
				if(($value_package_pdk1 eq $fcl_cste) && ($value_package_pdk2 eq $fcl_cste))
				{
					#print "the package was FCL and is still FCL - STILL\n";
					$still_fcl_table[$total_still_fcl++] = $pdk1_sorting_table[$tab_counter1];
				}
				else
				{
					#print "the package was MCL and is still MCL - VERY GOOD\n";
					$very_good_mcl_table[$total_very_good_mcl++] = $pdk1_sorting_table[$tab_counter1];
				}
			}
		}
		
		$tab_counter1++;
		$tab_counter2++;
	}
	else
	{
		# The values are not the same, therefore it must be an added or deleted package
		if($compare_2_tables<0)	# If $compare_2_tables=-1, then pdk1 is smaller than pdk2, which means that it has been deleted from pdk2
		{
			#print "the package $pdk1_sorting_table[$tab_counter1] has been deleted from pdk2\n";
			$packages_removed_table[$total_packages_removed++]=$pdk1_sorting_table[$tab_counter1++];
		}
		else
		{
			# If $compare_2_tables=1, then pdk1 is bigger than pdk2, which means that it has been added to pdk2
			#print "the package $pdk2_sorting_table[$tab_counter2] has been added to pdk2\n";
			$packages_added_table[$total_packages_added++]=$pdk2_sorting_table[$tab_counter2++];
		}
	}
}


print "\nPrint all the values related to our calculations\n";
print "total_packages_pdk1=$total_packages_pdk1\n";
print "total_packages_pdk2=$total_packages_pdk2\n";
print "\n";
print "total_packages_added=$total_packages_added\n";
print "packages_added_table=\n";
display_array_one_line_at_the_time(@packages_added_table);
print "\n";
print "total_packages_removed=$total_packages_removed\n";
print "packages_removed_table=\n";
display_array_one_line_at_the_time(@packages_removed_table);
print "\n";
print "total_new_fcl=$total_new_fcl\n";
print "new_fcl_table=\n";
display_array_one_line_at_the_time(@new_fcl_table);
print "\n";
print "total_no_more_fcl=$total_no_more_fcl\n";
print "no_more_fcl_table=\n";
display_array_one_line_at_the_time(@no_more_fcl_table);
print "\n";
print "total_still_fcl=$total_still_fcl\n";
print "still_fcl_table=\n";
display_array_one_line_at_the_time(@still_fcl_table);
print "\n";
print "total_very_good_mcl=$total_very_good_mcl\n";
print "very_good_mcl_table=\n";
display_array_one_line_at_the_time(@very_good_mcl_table);
print "\n";
# Checking that the packages have been assigned properly.
# !!!! Need to verify the formula. Not sure that is correct!!!!!!
print "Verification for the total packages between the 2 pdks\n";
print "Formula used is: total_packages_pdk2 = total_packages_pdk1 + total_packages_added - total_packages_removed\n";
print "$total_packages_pdk2 = $total_packages_pdk1 + $total_packages_added - $total_packages_removed\n";
print "\n";
print "Formula used is: total_packages_pdk1 = total_very_good_mcl + total_new_fcl + total_no_more_fcl + total_still_fcl= total\n";
print "$total_packages_pdk1 = $total_very_good_mcl + $total_new_fcl + $total_no_more_fcl + $total_still_fcl = ", ($total_very_good_mcl + $total_new_fcl + $total_no_more_fcl + $total_still_fcl), "\n";
print "\n";
print "Formula used is: total_packages_pdk2 = total_very_good_mcl + total_new_fcl + total_no_more_fcl + total_still_fcl + total_packages_added = total\n";
print "$total_packages_pdk2 = $total_very_good_mcl + $total_new_fcl + $total_no_more_fcl + $total_still_fcl + $total_packages_added - $total_packages_removed= ", ($total_very_good_mcl + $total_new_fcl + $total_no_more_fcl + $total_still_fcl + $total_packages_added - $total_packages_removed), "\n";
print "\n";

# 5th step is to create a txt file ready to be used for the release notes in a media wiki format.
open(FCLCOMPARISONFILE, ">$file_path");	# !!!!! First time we are accessing the file, therefore create it or replace it, AFTR THAT WE NEED TO APPEND IT ONLY!!!!!

my $val;

# Enter the beginning of the section for general information about the pdk and it's predecessor.
print FCLCOMPARISONFILE <<"EOT";
== Packages ==

This sectin is about general information on the packages included in the platfrom.\n
This is an analysis between '''$pdk2_correct_name_to_use''' and '''$pdk1_correct_name_to_use'''
EOT


print FCLCOMPARISONFILE "\n Number total of packages in $pdk1_correct_name_to_use is: '''$total_packages_pdk1'''\n";
print FCLCOMPARISONFILE "\n Number total of packages in $pdk2_correct_name_to_use is: '''$total_packages_pdk2'''\n";

print FCLCOMPARISONFILE "=== Packages added ===\n\n";
print FCLCOMPARISONFILE "\n Number total of packages added in $pdk2_correct_name_to_use is: '''$total_packages_added'''\n\n";
foreach $val (@packages_added_table)
{
	print FCLCOMPARISONFILE "''' $val (sf/app/contacts) '''\n\n";
}

print FCLCOMPARISONFILE "=== Packages removed ===\n\n\n";
print FCLCOMPARISONFILE "''' Number total of packages removed in $pdk2_correct_name_to_use is: $total_packages_removed'''\n\n";
foreach $val (@packages_removed_table)
{
	print FCLCOMPARISONFILE "''' $val (sf/app/contacts) '''\n\n\n";
}

# Enter the beginning of the section for the FCL
print FCLCOMPARISONFILE <<"EOT";
== FCLs ==

'''$pdk2_correct_name_to_use''' was built using the FCL versions of the packages listed below: for each one we list the changes in the FCL which are not in the MCL.
The previous PDK also involved some FCLs, so we indicate which problems are now fixed in the MCL, and which FCLs are new to this build

Cloning the source from Mercurial is made more awkward by using a mixture of MCLs and FCLs, but we provide a tool to help - see [[How_to_build_the_Platform#Automatic_Mercurial_Clone]] for details.

EOT

# Packages that were on MCL and that are now on FCL
foreach $val (@new_fcl_table)
{
	print FCLCOMPARISONFILE "=== $val (sf/app/contacts) -- NEW ===\n\n\n";
	# Needs to be recovered from Mercurial. How????
	#[http://developer.symbian.org/bugs/show_bug.cgi?id=156 Bug 156]: Add a missing bld.inf, to renable compilation of the package
	#[http://developer.symbian.org/bugs/show_bug.cgi?id=197 Bug 197]: PSAlgorithmInternalCRKeys.h is missing

}

# Packages that were on FCL and that are now on FCL
foreach $val (@still_fcl_table)
{
	print FCLCOMPARISONFILE "=== $val (sf/app/contacts) ===\n\n\n";
}

print FCLCOMPARISONFILE "=== FCLs used in $pdk1_correct_name_to_use but not needed in $pdk2_correct_name_to_use ===\n";

foreach $val (@no_more_fcl_table)
{
	print FCLCOMPARISONFILE "''' $val (sf/app/contacts) '''\n\n";
}

# Packages were on MCL and they are still on MCL.
foreach $val (@very_good_mcl_table)
{
	#print FCLCOMPARISONFILE "=== $val (sf/app/contacts) -- VERY GOOD ===\n";
}


close(FCLCOMPARISONFILE);


# 6th step is to export that txt file the appropriate location.
# That could be the location from where we launched the script!
print "\nYou will find the file with all the informatin you need for the releases note, here: $file_path\n\n";

# Cleanup the mess!!!
#pause_script(); # Temporary until script is finished!!!!!!

$system_cmd = "rmdir /S /Q $working_dir";
print "Exec: $system_cmd\n";
system($system_cmd);

##
### End of the program!!!
##


#
# Functions section!!!!!
#


# If no parameters entered or help selected, display help
sub helpme
{
	print "\nfct: helpme\n";
	
	print "Generate FCLs details between 2 PDKs to be included as part of the release notes\n";	
	print "Default location for PDKs is: $default_pdk_loc\n";
	print "Usage: perl fcls4releasenotes.pl --input_data1=x --input_data2=y\n";
	print "Where input_data1 and input_data2 could be pdknb1 or pdknb2 or pdkloc1 or pdkloc2 or pdkname1 or pdkname2\n";
	print "Where pdknb is the PDK number, for example 2.0.e\n";
	print "Where pdkloc is the root location where your file $name_zip_file_to_extract is. For ex: \\\\bishare\\releases\\PDK_2.0.e\\ or c:\\temp\\myPDK\\\n";
	print "Where pdkname is the full name of the PDK, like for ex PDK_candidate_2.0.d_flat\n";
	print "\nTypical command lines from script location:\n";
	print "\t<perl fcls4releasenotes.pl --pdknb1=2.0.e --pdkloc1=c:\\temp\\myPDK\\>\n";
	print "\t<perl fcls4releasenotes.pl --pdkname1=PDK_2.0.e --pdknb1=2.0.e>\n";
	print "\t<perl fcls4releasenotes.pl --pdknb1=2.0.d --pdknb2=2.0.e>\n";
	print "\t<perl fcls4releasenotes.pl help>\n";
	#print "\t<perl fcls4releasenotes.pl validpdks>\n";
	
	list_pdks_at_default_location();
	
	exit(0);
}
# End section related to help

# Extract list of PDKs that are in the default location.
sub list_pdks_at_default_location
{
	print "\nfct: list_pdks_at_default_location\n";
	
	# Do a dir of the default location
	print "List of directories in the default location $default_pdk_loc\n";
	extract_dir_default_loc();
	
	# Extract all the PDKs that have the pattern PDK_
	print "All available PDKS in the default location $default_pdk_loc that have the pattern $pdk_start_pattern\n";
	extract_pdk_in_default_loc();
	
	# Extract all the PDKs that have the file build_BOM.zip
	print "All available PDKS in the default location $default_pdk_loc that contains the zip file $name_zip_file_to_extract\n";
	extract_pdk_with_valid_zip_in_default_loc();
	
}

# Generates list of directories in the default location used for the storage of the PDKs
sub extract_dir_default_loc
{
	print "\nfct: extract_dir_default_loc\n";
	
	# Get the list of directories in the default location
	opendir(DEFAULT_DIR, $default_pdk_loc);
	@directories_list_default_location = readdir(DEFAULT_DIR);
	close(DEFAULT_DIR);
	
	$nb_dir_in_default_loc = scalar(@directories_list_default_location);
	
	print "nb_dir_in_default_loc=$nb_dir_in_default_loc\n";
	#display_array_one_line_at_the_time(@directories_list_default_location);
}

# Establish the list of directories that are an actual PDK
sub extract_pdk_in_default_loc
{
	print "\nfct: extract_pdk_in_default_loc\n";
	
	my $var;
	$nb_pdks_in_default_loc=0;
	print "pdk_start_pattern = $pdk_start_pattern\n";
	
	foreach $var (@directories_list_default_location)
	{
		if($var =~ /^$pdk_start_pattern+/)
		{
			#print "$var\n";
			$pdk_dir_list_in_default_location[$nb_pdks_in_default_loc++] = $var;
		}
		#else
		#{
			#print "Not a PDK!!!!\n";
		#}
	}
	print "There is $nb_pdks_in_default_loc PDKs in the default location $default_pdk_loc\n";	
	
	print "This is the list of PDKs that are in the default location $default_pdk_loc\n";
	#display_array_one_line_at_the_time(@pdk_dir_list_in_default_location);
}

# Establish the list of PDK directories with a valid zip file to do the test
sub extract_pdk_with_valid_zip_in_default_loc
{
	print "\nfct: extract_pdk_with_valid_zip_in_default_loc\n";
	
	my $var1;
	my $var2;
	my $path_to_find_zip = "";
	my @read_pdk_directory=();
	
	$nb_pdks_with_valid_zip_in_default_loc=0;
	
	print "name_zip_file_to_extract=$name_zip_file_to_extract\n";
	
	foreach $var1 (@pdk_dir_list_in_default_location)
	{
		$path_to_find_zip=$default_pdk_loc;
		
		$path_to_find_zip .= $var1;
		#print "path_to_find_zip=$path_to_find_zip\n";
				
		# Get the list of directories in the default location
		opendir(PDK_DIR, $path_to_find_zip);
		@read_pdk_directory = readdir(PDK_DIR);
		close(PDK_DIR);
	
		foreach $var2 (@read_pdk_directory)
		{
			if($var2 =~ /$name_zip_file_to_extract$/)
			{
				#print "$var2\n";
				$pdks_with_valid_zip_in_default_loc[$nb_pdks_with_valid_zip_in_default_loc++] = $var1;
			}
			#else
			#{
				#print "Doesn't contain $name_zip_file_to_extract!!!!\n";
			#}
		}
	}
	print "There is $nb_pdks_with_valid_zip_in_default_loc PDKs with a valid $name_zip_file_to_extract zip in the default location $default_pdk_loc\n";	
	
	print "This is the list of PDKs that have a zip file called $name_zip_file_to_extract in the default location $default_pdk_loc\n";
	display_array_one_line_at_the_time(@pdks_with_valid_zip_in_default_loc);
}

# Function created to pause the script to allow analysis and debug of the script.
# Will require the user to press enter to carry on the execution of the script.
sub pause_script
{
	print "\nfct: pause_script\n";
	my $local_system_cmd = "pause";
	print "Exec: $local_system_cmd\n";
	system($local_system_cmd);
}


# This function is used to extract the name of the package and the type
sub extract_packages_and_branch_type_from_file
{
	# 1 Parameters passed, the path to the file to be viewed
	my ($file_to_work_on) = @_;
	
	print "\nfct: extract_packages_and_branch_type_from_file\n";
	
	print "$file_to_work_on\n";
	
	my %local_hash_array;
	#my @hash_array_to_display;
	my $local_key;
	
	my $package="";
	my $type_of_branch="";
	
	#@hash_array_to_display = %local_hash_array;
	#print "%local_hash_array before starting = @hash_array_to_display\n";
	
	# Open file
	open(FILETOWORKON , $file_to_work_on);

	# Extract data from file
	my @local_array = <FILETOWORKON>;
	#print "local_array= @local_array\n";

	# Close file
	close(FILETOWORKON);
	
	my $extracted_line;
	
	# Go line by line
	foreach  $extracted_line (@local_array)
	{
		#print "\nextracted_line is: $extracted_line"; # no need to add \\n as it's part of the line displayed.
		
		if ($extracted_line =~ /$starting_pattern_for_xml_extraction/)
		{
			#print "The line extracted is our starting pattern $starting_pattern_for_xml_extraction\n";
			$extraction_from_xml_is_allowed=1;
		}
		else
		{
		if ($extracted_line =~ /$ending_pattern_for_xml_extraction/)
			{
				#print "The line extracted is our ending pattern $ending_pattern_for_xml_extraction\n";
				$extraction_from_xml_is_allowed=0;
			}
		}
		#print "extraction_from_xml_is_allowed=$extraction_from_xml_is_allowed\n";

		if($extraction_from_xml_is_allowed)
		{
			#print "We are looking to extract the package and branch type from the line extracted\n";
			
			# Decode the line			
			
			# Decode the branch type			
			if($extracted_line =~ /$branch_type_extraction_pattern/)
			{
				$type_of_branch=$1;

				# Decode the package because there is a branch type in the line extracted!
				if ($extracted_line =~ m,$package_extraction_pattern,)
				{
					$package=$1;					
				}
					#print "package is $package and type_of_branch is $type_of_branch\n";
					$local_hash_array{$package}=$type_of_branch;
			}
			else
			{
				#print "The extracted line doesn't contain $look_for_mcl or $look_for_fcl, therefore we need to skip it!\n";
			}
		}
	}

	# Check the contain of the hash array to make sure that we have extracted the data as expected. To check against the actual file.

	# Option 1: Display all in one line
	#@hash_array_to_display = %local_hash_array;
	# Print "%local_hash_array when extraction is finished = @hash_array_to_display\n";
	
	# Option 2: Print 1 key with 1 value by line
	#foreach $local_key (keys(%local_hash_array))
	#{
	#	print "$local_key = $local_hash_array{$local_key}\n";
	#}
	
	# Return hash array containing all the packages and branch type associated
	return (%local_hash_array);
}

sub display_array_one_line_at_the_time
{
	my (@table_to_display_one_line_at_the_time) = @_;
	
	#print "\nfct: display_array_one_line_at_the_time\n"; # Not displayed because you could think that is part of the table. As well it's easier to copy the name of the table and the contain wihtout the need to remove something.
	
	my $line_to_display;	
	
	foreach $line_to_display (@table_to_display_one_line_at_the_time)
	{
		print "$line_to_display\n";
	}
}

# PDKs with build_bom.zip file in the default PDKs location 14-09-2009
#Z:\Releases\PDK_2.0.e
#Z:\Releases\PDK_candidate_2.0.d_flat
#Z:\Releases\PDK_candidate_2.0e_FCL_27.78
