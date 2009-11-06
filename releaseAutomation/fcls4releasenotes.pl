#!perl -w
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

use strict;
use Getopt::Long;

#
# Configuration data and constants for the script
#
my $default_pdk_loc='//v800020/Publish/Releases/';
print "default_pdk_loc=$default_pdk_loc\n";

# Nb of arguments to be passed to the script to work. If that need to change, just modify nb_arg_to_pass!
my $nb_arg_to_pass=2;

# Name of the file that contains the data we need to extract for this script
my $build_bom_zip_file_to_extract="build_BOM.zip";
my $build_logs_zip_file_to_extract="build_logs.zip";

# Name of the file we need to work on to extract the data necessary for the Release Notes from build_BOM.zip
my $name_of_file_to_compare="build-info.xml";

# File used to extract path and component name for a package from build_logs.zip
my $pckg_extraction_data_file_name = "PkgComponentAnalysisSummary.csv";

# When using the script as part of the build system, we don't have access to the zip files yet, therefore we need to have a look for the file directly
# This is working only when using pdkloc2 only. In any other cases we are not bothered!!!!!
my $bom_dir="BOM";
my $analysis_dir="analysis";

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

# Name of the file that we are creating to hold the information necessary for the Release Notes
my $name_of_file_to_publish="releaseNotes.wiki.txt";
#Location for that file
# This values need to be overwritten!!!
my $location_of_file_to_publish="c:\\temp";

#
# End configuration data for the script
#

# Arguments / Data used for the script
my $help = 0;
my $publishDir;

my @PDK = ({}, {});

GetOptions((
	'pdknb1=s' => \$PDK[0]->{number},
	'pdknb2=s' => \$PDK[1]->{number},
	'pdkname1=s' => \$PDK[0]->{name},
	'pdkname2=s' => \$PDK[1]->{name},
	'pdkloc1=s' => \$PDK[0]->{loc},
	'pdkloc2=s' => \$PDK[1]->{loc},
	'publish=s' => \$publishDir,
	'help!' => \$help,
));

if ($help)
{
	helpme();
	exit(0);
}

foreach my $pdkCount (0 .. $#PDK)
{
	if (scalar (grep {defined} keys %{$PDK[$pdkCount]}) == 0)
	{
		print "No data provided to identify PDK", $pdkCount + 1, "\n";
		helpme();
		exit (1);
	}
	if (scalar (grep { defined $_ } values %{$PDK[$pdkCount]}) > 1)
	{
		print "Multiple data provided to identify PDK", $pdkCount + 1, "\n";
		print values %{$PDK[$pdkCount]};
		helpme();
		exit (1);
	}
}

my $pdknb1 = $PDK[0]->{number} || "";
my $pdkname1 = $PDK[0]->{name} || "";
my $pdkloc1 = $PDK[0]->{loc} || "";

my $pdknb2 = $PDK[1]->{number} || "";
my $pdkname2 = $PDK[1]->{name} || "";
my $pdkloc2 = $PDK[1]->{loc} || "";

print "pdknb1=$pdknb1\n";
print "pdknb2=$pdknb2\n";
print "pdkname1=$pdkname1\n";
print "pdkname2=$pdkname2\n";
print "pdkloc1=$pdkloc1\n";
print "pdkloc2=$pdkloc2\n";
print "help=$help\n";

# Use the specified release location if supplied
$default_pdk_loc = $publishDir || $default_pdk_loc;
$default_pdk_loc =~ s{([^/\\])$}{$1\\};

# First PDK to check
my $pdk_path1="";
my $pdk_complete_name1=0;
my $pdk_complete_path1=0;
my $pdk_path1_exist=0;
my $pdk_zip1_exit=0; # Not necessary
my $pdk1_correct_name_to_use="";
my $loc1_contains_the_zip_file_we_need=0;

# Second PDK to check
my $pdk_path2="";
my $pdk_complete_name2=0;
my $pdk_complete_path2=0;
my $pdk_path2_exist=0;
my $pdk_zip2_exist=0; # Not necessary
my $pdk2_correct_name_to_use="";
my $loc2_contains_the_zip_file_we_need=0;		# Used to indicate that we have found the build_BOM.zip file
my $loc2_contains_the_xml_csv_files_we_need=0;	# Used to indicate that we have found the build-info.xml and PkgComponentAnalysisSummary.csv
my $nb_of_xml_csv_files_we_need=2;	# Used to define the number of files we need to have a look at when we are not looking for zip files.
my $nb_of_zip_files_we_need=2;	# Used to define the number of files we need to have a look at when we are looking for zip files.

# Default directory management
my @directories_list_default_location=();
my $nb_dir_in_default_loc;
my @pdk_dir_list_in_default_location=();
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
my %pckg_path_name_array;		# Table containing the path for each packages
my %pckg_name_array;			# Table containing the real meaning name for each packages, not the name of the package in the directory structure

if($pdknb1)
{
	$pdk_path1 = $default_pdk_loc;
	$pdk_complete_name1=1;
	$pdk_complete_path1=1;
}
if($pdknb2)
{
	$pdk_path2 = $default_pdk_loc;
	$pdk_complete_name2=1;
	$pdk_complete_path2=1;
}
if($pdkname1)
{
	$pdk_path1 = $default_pdk_loc;	
	$pdk_complete_path1=1;	
}
if($pdkname2)
{
	$pdk_path2 = $default_pdk_loc;	
	$pdk_complete_path2=1;
}
if($pdkloc1)
{
	$pdk_path1 = $pdkloc1;
}
if($pdkloc2)
{
	$pdk_path2 = $pdkloc2;
}

#
# If we reach this point, this means that we have the right numbers of arguments passed to the script.
#
print "\nWe are on the right path!!!!\n";

print "pdk_path1=$pdk_path1\n";
print "pdk_complete_name1=$pdk_complete_name1\n";
print "pdk_complete_path1=$pdk_complete_path1\n";
print "\n";
print "pdk_path2=$pdk_path2\n";
print "pdk_complete_name2=$pdk_complete_name2\n";
print "pdk_complete_path2=$pdk_complete_path2\n";
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

		$pdk1_correct_name_to_use = $pdkname1;
		$pdk_path1 .= $pdkname1;
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
	
		$pdk2_correct_name_to_use = $pdkname2;
		$pdk_path2 .= $pdkname2;
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
	
	foreach $loc_var (@read_files_in_loc)
	{
		if($loc_var =~ /$build_bom_zip_file_to_extract$/)
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
		print "We can't find the file $build_bom_zip_file_to_extract in the location $pdkloc2 and therefore we can't go any further!!\n";
		exit(0);
	}
}
print "\n";

if($pdkloc2)
{
	# Have a look at the zip files in the location choosen.
	opendir(LOC2_DIR, $pdkloc2);
	@read_files_in_loc = readdir(LOC2_DIR);	# Need to have a look at the sub directories too!!!!!!
	close(LOC2_DIR);	
	print "List of files in the directory: @read_files_in_loc\n";
	
	foreach $loc_var (@read_files_in_loc)
	{
		# Have a look for build_bom.zip and build_logs.zip
		if( ($loc_var =~ /$build_bom_zip_file_to_extract$/) || ($loc_var =~ /$build_logs_zip_file_to_extract$/) )
		{
			print "We found the file: $loc_var\n";
			$loc2_contains_the_zip_file_we_need++;
		}
	}
	
	if(!$loc2_contains_the_zip_file_we_need) # If we have the zip file, no need to have a look for the csv and xml files!
	{
		my $local_var_path;
		
		print "We are checking for xml file\n";
		$local_var_path = "$pdkloc2\\$bom_dir";
		print "local_var_path = $local_var_path\n";
		
		opendir(LOCBOM_DIR, $local_var_path);
		@read_files_in_loc = readdir(LOCBOM_DIR);
		close(LOCBOM_DIR);
		
		print "List of files in the directory: @read_files_in_loc\n";
		
		foreach $loc_var (@read_files_in_loc)
		{			
			if($loc_var =~ /$name_of_file_to_compare$/)
			{
				print "We are in the case of the build and instead of looking for zip files, we need to have a look for $name_of_file_to_compare\n";
				
				print "We found the file: $loc_var\n";
				
				$loc2_contains_the_xml_csv_files_we_need++;
			}
		}

		print "We are checking for csv file\n";
		$local_var_path = "$pdkloc2\\$analysis_dir";
		print "local_var_path = $local_var_path\n";
		
		opendir(LOCANALYSIS_DIR, $local_var_path);
		@read_files_in_loc = readdir(LOCANALYSIS_DIR);
		close(LOCANALYSIS_DIR);
		
		print "List of files in the directory: @read_files_in_loc\n";
		
		foreach $loc_var (@read_files_in_loc)
		{
			if($loc_var =~ /$pckg_extraction_data_file_name$/)
			{
				print "We are in the case of the build and instead of looking for zip files, we need to have a look for $pckg_extraction_data_file_name\n";
				
				print "We found the file: $loc_var\n";
				
				$loc2_contains_the_xml_csv_files_we_need++;
			}
		}
	}
	if(($loc2_contains_the_zip_file_we_need==$nb_of_zip_files_we_need) || ($loc2_contains_the_xml_csv_files_we_need==$nb_of_xml_csv_files_we_need))
	{
		$pdk2_correct_name_to_use = "PDK2";
		$pdk_path2 = $pdkloc2;
		
		print "The PDK used is: $pdk2_correct_name_to_use\n";
		print "pdk_path2 = $pdk_path2\n";
		
		if($loc2_contains_the_xml_csv_files_we_need==$nb_of_xml_csv_files_we_need)
		{
			$location_of_file_to_publish=$pdkloc2;
			print "location_of_file_to_publish=$location_of_file_to_publish\n";
		}
	}
	else
	{
		if($loc2_contains_the_xml_csv_files_we_need<=$nb_of_xml_csv_files_we_need)
		{
			print "We can't find the files $name_of_file_to_compare and/or $pckg_extraction_data_file_name in the location $pdkloc2 and therefore we can't go any further!!\n";
		}
		else
		{
			print "We can't find the files $build_bom_zip_file_to_extract in the location $pdkloc2 and therefore we can't go any further!!\n";
		}
		exit(0);
	}
}

print "\n";
print "If we are here, this means that both $build_bom_zip_file_to_extract have been found and we can start the real work to compare the 2 files to extract what we need!\n";
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
# Where $build_bom_zip_file_to_extract is the name of the zip file (in our case: build_BOM.zip)
# Where $pdk_path1 is the place where the zip file to unzip is
# where $name_of_file_to_compare is the name of the file we want to extract from the zip file (in our case: build-info.xml)
# Example: 7z e -r -oc:\temp\fcl_extraction\pdk1 C:\temp\Task243Test\PDK_1\build_BOM.zip build-info.xml

# Extract file from 1st PDK
$system_cmd = "7z e -r -o$working_dir1 $pdk_path1\\$build_bom_zip_file_to_extract $name_of_file_to_compare";
print "Exec: $system_cmd\n";
system($system_cmd);

print "\n";

# Extract the information contained in PkgComponentAnalysisSummary.csv for path a nd package name used by PDK1.
$system_cmd = "7z e -r -o$working_dir1 $pdk_path1\\$build_logs_zip_file_to_extract $pckg_extraction_data_file_name";
print "Exec: $system_cmd\n";
system($system_cmd);

print "\n";

# Extract file from 2nd PDK
if($loc2_contains_the_xml_csv_files_we_need==$nb_of_xml_csv_files_we_need)
{
	my $local_file_path;
	print "We are copying the files $name_of_file_to_compare and $pckg_extraction_data_file_name from $pdk_path2 to $working_dir2\n";

	print "Create directory $working_dir2\n";
	$system_cmd = "mkdir $working_dir2";
	print "Exec: $system_cmd\n";
	system($system_cmd);
	
	print "We are going to copy $name_of_file_to_compare to $working_dir2\n";
	$local_file_path = "$pdk_path2\\$bom_dir\\$name_of_file_to_compare";
	$system_cmd = "xcopy $local_file_path $working_dir2 \/F";
	print "Exec: $system_cmd\n";
	system($system_cmd);

	print "\n";
	
	# Extract the information contained in PkgComponentAnalysisSummary.csv for path and package name used by PDK1.
	print "We are going to copy $pckg_extraction_data_file_name to $working_dir2\n";
	$local_file_path = "$pdk_path2\\$analysis_dir\\$pckg_extraction_data_file_name";
	$system_cmd = "xcopy $local_file_path $working_dir2 \/F";
	print "Exec: $system_cmd\n";
	system($system_cmd);
}
else
{
	print "We are looking for zip files, then we extract them\n";
	$system_cmd = "7z e -r -o$working_dir2 $pdk_path2\\$build_bom_zip_file_to_extract $name_of_file_to_compare";
	print "Exec: $system_cmd\n";
	system($system_cmd);
	
	print "\n";
	
	# Extract the information contained in PkgComponentAnalysisSummary.csv for path and package name used by PDK1.
	$system_cmd = "7z e -r -o$working_dir2 $pdk_path2\\$build_logs_zip_file_to_extract $pckg_extraction_data_file_name";
	print "Exec: $system_cmd\n";
	system($system_cmd);
}

# 2nd step is to extract the information we need from the 2 files build-info.xml

# Create 2 hash arrays that will contain the name of the package as key and the value associated as MCL or FCL
my %build_info_xml1;
my %build_info_xml2;
my @sorting_build_info_xml1;
my @sorting_build_info_xml2;

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

# ascendant alphabetical sort
@pdk1_sorting_table = sort { lc($a) cmp lc($b) } @not_sorted_table;

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

# ascendant alphabetical sort
@pdk2_sorting_table = sort { lc($a) cmp lc($b) } @not_sorted_table;

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
	# $a cmp $b
	# if $a > $b value returned is 1
	# if $a = $b value returned is 0
	# if $a < $b value returned is -1
	
	$compare_2_tables = ( $pdk1_sorting_table[$tab_counter1] cmp $pdk2_sorting_table[$tab_counter2] );
	
	if(!$compare_2_tables)	# Compare if the the packages in the tables(index) are the same or not, if $compare_2_tables=0, then equal
	{
		$value_package_pdk1 = $build_info_xml1{$pdk1_sorting_table[$tab_counter1]};
		$value_package_pdk2 = $build_info_xml2{$pdk2_sorting_table[$tab_counter2]};
		
		if(($value_package_pdk1 eq $mcl_cste) && ($value_package_pdk2 eq $fcl_cste))
		{
			$new_fcl_table[$total_new_fcl++] = $pdk1_sorting_table[$tab_counter1];
		}
		else
		{
			if(($value_package_pdk1 eq $fcl_cste) && ($value_package_pdk2 eq $mcl_cste))
			{
				$no_more_fcl_table[$total_no_more_fcl++] = $pdk1_sorting_table[$tab_counter1];
			}
			else
			{
				if(($value_package_pdk1 eq $fcl_cste) && ($value_package_pdk2 eq $fcl_cste))
				{
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
			$packages_removed_table[$total_packages_removed++]=$pdk1_sorting_table[$tab_counter1++];
		}
		else
		{
			# If $compare_2_tables=1, then pdk1 is bigger than pdk2, which means that it has been added to pdk2
			$packages_added_table[$total_packages_added++]=$pdk2_sorting_table[$tab_counter2++];
		}
	}
}

# Build list of files path and name based on csv file generated by the build system (analysis part)
extract_package_detail("$working_dir2\\$pckg_extraction_data_file_name");
extract_package_detail("$working_dir1\\$pckg_extraction_data_file_name");

print "\nPrint all the values related to our calculations\n";
print "total_packages_pdk1=$total_packages_pdk1\n";
print "total_packages_pdk2=$total_packages_pdk2\n";
print "\n";
print "total_packages_added=$total_packages_added\n";
print "total_packages_removed=$total_packages_removed\n";
print "total_new_fcl=$total_new_fcl\n";
print "total_no_more_fcl=$total_no_more_fcl\n";
print "total_still_fcl=$total_still_fcl\n";
print "total_very_good_mcl=$total_very_good_mcl\n";
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
my $path_to_file_to_publish="$location_of_file_to_publish/$name_of_file_to_publish";
open(FCLCOMPARISONFILE, ">$path_to_file_to_publish");	# !!!!! First time we are accessing the file, therefore create it or replace it, AFTR THAT WE NEED TO APPEND IT ONLY!!!!!

my $val;

# Enter the beginning of the section for general information about the pdk and it's predecessor.
print FCLCOMPARISONFILE <<"EOT";
== Packages ==

This section provides general information on the packages included in the platform.

This is an analysis of '''$pdk2_correct_name_to_use''' compared to the baseline of '''$pdk1_correct_name_to_use'''.

EOT


print FCLCOMPARISONFILE "Number total of packages in $pdk1_correct_name_to_use is: '''$total_packages_pdk1'''\n\n";
print FCLCOMPARISONFILE "Number total of packages in $pdk2_correct_name_to_use is: '''$total_packages_pdk2'''\n\n";

print FCLCOMPARISONFILE "=== Packages added ===\n\n";
print FCLCOMPARISONFILE "Number total of packages added in $pdk2_correct_name_to_use is: '''$total_packages_added'''\n\n";
foreach $val (@packages_added_table)
{
	if($pckg_name_array{$val})
	{
		print FCLCOMPARISONFILE "''' $pckg_name_array{$val} ($pckg_path_name_array{$val}) '''\n\n";
	}
	else
	{
		print FCLCOMPARISONFILE "''' $val ($pckg_path_name_array{$val}) '''\n\n";
	}
}

print FCLCOMPARISONFILE "=== Packages removed ===\n\n";
print FCLCOMPARISONFILE "Number total of packages removed in $pdk2_correct_name_to_use is: '''$total_packages_removed'''\n\n";
foreach $val (@packages_removed_table)
{
	if($pckg_name_array{$val})
	{
		print FCLCOMPARISONFILE "''' $pckg_name_array{$val} ($pckg_path_name_array{$val}) '''\n\n";
	}
	else
	{
		print FCLCOMPARISONFILE "''' $val ($pckg_path_name_array{$val}) '''\n\n";
	}
}

# Enter the beginning of the section for the FCL
print FCLCOMPARISONFILE <<"EOT";
== FCLs ==

'''$pdk2_correct_name_to_use''' was built using the FCL versions of the packages listed below: for each one we list the changes in the FCL which are not in the MCL.

The previous PDK also involved some FCLs, so we indicate which problems are now fixed in the MCL, and which FCLs are new to this build.

Cloning the source from Mercurial is made more awkward by using a mixture of MCLs and FCLs, but we provide a tool to help - see [[How to build the Platform#Automatic Mercurial Clone]] for details.

EOT

# Packages that were on MCL and that are now on FCL
foreach $val (@new_fcl_table)
{
	if($pckg_name_array{$val})
	{
		print FCLCOMPARISONFILE "=== $pckg_name_array{$val} ($pckg_path_name_array{$val}) -- NEW ===\n\n";
		# TO DO!!!!
		# Needs to be recovered from Mercurial. How????
		#[http://developer.symbian.org/bugs/show_bug.cgi?id=156 Bug 156]: Add a missing bld.inf, to renable compilation of the package
		#[http://developer.symbian.org/bugs/show_bug.cgi?id=197 Bug 197]: PSAlgorithmInternalCRKeys.h is missing
	}
	else
	{
		print FCLCOMPARISONFILE "=== $val ($pckg_path_name_array{$val}) -- NEW ===\n\n";
	}
}

# Packages that were on FCL and that are now on FCL
foreach $val (@still_fcl_table)
{
	if($pckg_name_array{$val})
	{
		print FCLCOMPARISONFILE "=== $pckg_name_array{$val} ($pckg_path_name_array{$val}) ===\n\n";
	}
	else
	{
		print FCLCOMPARISONFILE "=== $val ($pckg_path_name_array{$val}) ===\n\n";
	}
}

print FCLCOMPARISONFILE "=== FCLs used in $pdk1_correct_name_to_use but not needed in $pdk2_correct_name_to_use ===\n\n";

foreach $val (@no_more_fcl_table)
{
	if($pckg_name_array{$val})
	{
		print FCLCOMPARISONFILE "''' $pckg_name_array{$val} ($pckg_path_name_array{$val}) '''\n\n";
	}
	else
	{
		print FCLCOMPARISONFILE "''' $val ($pckg_path_name_array{$val}) '''\n\n";
	}
}

close(FCLCOMPARISONFILE);

print "\nYou will find the file with all the information you need for the releases note, here: $path_to_file_to_publish\n\n";

# Cleanup the mess!!!

$system_cmd = "rmdir /S /Q $working_dir";
print "Exec: $system_cmd\n";
system($system_cmd);

exit(0);

# If no parameters entered or help selected, display help
sub helpme
{
	print "\nfct: helpme\n";
	
	print "Generate FCLs details between 2 PDKs to be included as part of the release notes\n";	
	print "Default location for PDKs is: $default_pdk_loc\n";
	print "Usage: perl fcls4releasenotes.pl --input_data1=x --input_data2=y\n";
	print "Where input_data1 and input_data2 could be pdknb1 or pdknb2 or pdkloc1 or pdkloc2 or pdkname1 or pdkname2\n";
	print "Where pdknb is the PDK number, for example 2.0.e\n";
	print "Where pdkloc is the root location where your file $build_bom_zip_file_to_extract is. For ex: \\\\bishare\\releases\\PDK_2.0.e\\ or c:\\temp\\myPDK\\\n";
	print "Where pdkname is the full name of the PDK, like for ex PDK_candidate_2.0.d_flat\n";
	print "\nNotes:\n";
	print "\tParameter names with 1 at the end (pdknb1, pdkname1, pdkloc1) are set for the oldest PDK to use (PDK1)\n";
	print "\tParameter names with 2 at the end (pdknb2, pdkname2, pdkloc2) are set for the newest PDK to use (PDK2)\n";
	print "\tIf you try to use for example pdknb2 and pdkname2 or pdkloc1 and pdknb1 the result is not guaranted to be correct!!!! as one will be set as PDK1 and the other as PDK2, but which order????\n";
	print "\tThe difference is done as follow PDK2 - PDK1\n";
	print "\n";
	print "\nTypical command lines from script location:\n";
	print "\t<perl fcls4releasenotes.pl --pdknb1=2.0.e --pdkloc2=c:\\temp\\myPDK\\>\n";
	print "\t<perl fcls4releasenotes.pl --pdkname1=PDK_2.0.e --pdknb2=2.0.e>\n";
	print "\t<perl fcls4releasenotes.pl --pdknb2=2.0.d --pdknb1=2.0.e>\n";
	print "\t<perl fcls4releasenotes.pl help>\n";
	
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
	print "All available PDKS in the default location $default_pdk_loc that contains the zip file $build_bom_zip_file_to_extract\n";
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
}

# Establish the list of directories that are an actual PDK
sub extract_pdk_in_default_loc
{
	print "\nfct: extract_pdk_in_default_loc\n";
	
	my $nb_pdks_in_default_loc=0;
	print "pdk_start_pattern = $pdk_start_pattern\n";
	
	foreach my $var (@directories_list_default_location)
	{
		if($var =~ /^$pdk_start_pattern+/)
		{
			$pdk_dir_list_in_default_location[$nb_pdks_in_default_loc++] = $var;
		}
	}
	print "There are $nb_pdks_in_default_loc PDKs in the default location $default_pdk_loc\n";	
}

# Establish the list of PDK directories with a valid zip file to do the test
sub extract_pdk_with_valid_zip_in_default_loc
{
	print "\nfct: extract_pdk_with_valid_zip_in_default_loc\n";

	my $path_to_find_zip = "";
	my @read_pdk_directory=();
	
	$nb_pdks_with_valid_zip_in_default_loc=0;
	
	print "build_bom_zip_file_to_extract=$build_bom_zip_file_to_extract\n";
	
	foreach my $var1 (@pdk_dir_list_in_default_location)
	{
		$path_to_find_zip=$default_pdk_loc;
		
		$path_to_find_zip .= $var1;
				
		# Get the list of directories in the default location
		opendir(PDK_DIR, $path_to_find_zip);
		@read_pdk_directory = readdir(PDK_DIR);
		close(PDK_DIR);
	
		foreach my $var2 (@read_pdk_directory)
		{
			if($var2 =~ /$build_bom_zip_file_to_extract$/)
			{
				$pdks_with_valid_zip_in_default_loc[$nb_pdks_with_valid_zip_in_default_loc++] = $var1;
			}
		}
	}
	print "There are $nb_pdks_with_valid_zip_in_default_loc PDKs with a valid $build_bom_zip_file_to_extract zip in the default location $default_pdk_loc\n";	
	
	print "This is the list of PDKs that have a zip file called $build_bom_zip_file_to_extract in the default location $default_pdk_loc\n";
	display_array_one_line_at_the_time(@pdks_with_valid_zip_in_default_loc);
}

# This function is used to extract the name of the package and the type
sub extract_packages_and_branch_type_from_file
{
	# 1 Parameters passed, the path to the file to be viewed
	my ($file_to_work_on) = @_;
	
	print "\nfct: extract_packages_and_branch_type_from_file\n";
	
	print "$file_to_work_on\n";
	
	my %local_hash_array;
	my $local_key;
	
	my $package="";
	my $type_of_branch="";
	
	# Open file
	open(FILETOWORKON , $file_to_work_on);

	# Extract data from file
	my @local_array = <FILETOWORKON>;

	# Close file
	close(FILETOWORKON);


	my $extracted_line;
	
	# Go line by line
	foreach  $extracted_line (@local_array)
	{
		if ($extracted_line =~ /$starting_pattern_for_xml_extraction/)
		{
			$extraction_from_xml_is_allowed=1;
		}
		else
		{
			if ($extracted_line =~ /$ending_pattern_for_xml_extraction/)
			{
				$extraction_from_xml_is_allowed=0;
			}
		}

		if($extraction_from_xml_is_allowed)
		{
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
				$local_hash_array{$package}=$type_of_branch;
				
			}
		}
	}

	# Return hash array containing all the packages and branch type associated
	return (%local_hash_array);
}

# Function used to extract all the data from the csv file about the different packages (name, path and real name)
sub extract_package_detail
{
	# 1 Parameters passed, the path to the file to be viewed
	my ($file_to_work_on) = @_;
	
	print "\nfct: extract_package_detail\n";
	
	print "$file_to_work_on\n";
	
	# Open file
	open(FILETOWORKON , $file_to_work_on);
	my @local_array = <FILETOWORKON>;
	close(FILETOWORKON);

	# Create a table with the path for each package using a hash array
	my $pckg_name_extraction_pattern = "^sf\/[\\w]*\/([\\w]*)";
	my $pckg_path_extraction_pattern = "^([^,]+),";
	my $pckg_real_name_extraction_pattern = ",[\\s]+([\\w\\s]*),[\\s]+[\\w\\s]*\$";
	
	#Typical lines to decode
	#sf/app/helps,SFL,sf/app/helps/symhelp/helpmodel/group/bld.inf,OK, Help Apps, Help
	#sf/app/java,SFL,sf/app/java/java_plat/group/bld.inf,OK, , 
	#sf/app/helps,SFL,sf/app/helps/symhelp/helpmodel/group/bld.inf,OK, Help Apps, Help
	#sf/app/helps,
	#SFL,
	#sf/app/helps/symhelp/helpmodel/group/bld.inf,
	#OK,
	# Help Apps,
	# Help
	
	#sf/app/java,SFL,sf/app/java/java_plat/group/bld.inf,OK, , 
	#sf/app/java,
	#SFL,
	#sf/app/java/java_plat/group/bld.inf,
	#OK,
	# ,
	#
	
	# Go line by line
	foreach my $extracted_line (sort @local_array)
	{
		if($extracted_line =~ m;$pckg_name_extraction_pattern;)
		{
			my $pckg_name = $1;

			if(!$pckg_path_name_array{$pckg_name})	# Check if package is not already in the table to avoid duplicates
			{
				my $pckg_path="''nonstandard path''";
				my $pckg_real_name="";

				if($extracted_line =~ m;$pckg_path_extraction_pattern;)
				{
					$pckg_path = $1;
				}
				if($extracted_line =~ m;$pckg_real_name_extraction_pattern;)
				{
					$pckg_real_name = $1;
				}
				# fill the tables
				$pckg_path_name_array{$pckg_name} = $pckg_path;
				$pckg_name_array{$pckg_name} = $pckg_real_name;
			}
		}
	}
	
	my @local_array_sorted;
	
	@local_array=keys (%pckg_path_name_array);
	@local_array_sorted = sort { lc($a) cmp lc($b) } @local_array;
}

# Function used to display one line at the time for an array				
sub display_array_one_line_at_the_time
{
	foreach (@_)
	{
		print "$_\n";
	}
}

# Function used to display one line at the time for an hash array
sub display_hash_array_one_line_at_the_time
{
	my (%hash_array_to_display_one_line_at_the_time) = @_;
	
	my @local_keys_array;
	my @local_keys_array_sorted;
	
	my $line_to_display;
	
	@local_keys_array = keys (%hash_array_to_display_one_line_at_the_time);
	@local_keys_array_sorted = sort { lc($a) cmp lc($b) } @local_keys_array;
	
	foreach $line_to_display (@local_keys_array_sorted)
	{
		print "$line_to_display = $hash_array_to_display_one_line_at_the_time{$line_to_display}\n";
	}
}

# PDKs with build_bom.zip file in the default PDKs location 14-09-2009
#Z:\Releases\PDK_2.0.e
#Z:\Releases\PDK_candidate_2.0.d_flat
#Z:\Releases\PDK_candidate_2.0e_FCL_27.78
