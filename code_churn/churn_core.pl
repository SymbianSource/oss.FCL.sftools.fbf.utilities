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
#
# Description:
#

use strict;
use File::Find;
use File::Copy;
use Cwd;

sub diffstat();

my $Logs_Dir = $ARGV[0];
my $dir_left = $ARGV[1];
my $dir_right = $ARGV[2];
my $dir_tmp_left = $ARGV[0].'\\'.$ARGV[1];
my $dir_tmp_right = $ARGV[0].'\\'.$ARGV[2];

print "left changeset $dir_left\n";
print "right chnageset $dir_right\n";
mkdir $dir_tmp_left;
mkdir $dir_tmp_right;

# default inclusions from churn.pl are "*.cpp", "*.c", "*.cxx", "*.h", "*.hpp", "*.inl" 
my @file_pattern=('\.cpp$','\.c$','\.hpp$','\.h$','\.inl$','\.cxx$','\.hrh$');
my $totallinecount=0;
my $countcomments=0;

if (! -d $Logs_Dir)
{
    die("$Logs_Dir does not exist \n");
}

#$dir_left =~ m/^(\w+)\.[0-9a-fA-F]+/;
$dir_right =~ m/^(\w+)\.[0-9a-fA-F]+/;
my $package_name = $1;

$dir_left =~ m/^\w+\.([0-9a-fA-F]+)/;
my $changeset_left = $1;

$dir_right =~ m/^\w+\.([0-9a-fA-F]+)/;
my $changeset_right = $1;

print "\nWorking on package: $package_name\n";
print "\nProcessing $dir_left\n";
find(\&process_files, $dir_left);
#DEBUG INFO:
print "\nTotal linecount for changed files in $dir_left is $totallinecount\n";
my $code_size_left = $totallinecount;

$totallinecount=0;
print "\nProcessing $dir_right\n";
find(\&process_files, $dir_right);
#DEBUG INFO:
print "\nTotal linecount for changed files in $dir_right is $totallinecount\n";    
my $code_size_right = $totallinecount;

my @diffs;

if (-d $dir_tmp_left && -d $dir_tmp_left)
{
	@diffs = `diff -r -N $dir_tmp_left $dir_tmp_right`;
}

my $changed_lines=@diffs;
my $diffsfile = $Logs_Dir.'\\'."dirdiffs.out";
open (DIFFS, ">$diffsfile");
print DIFFS @diffs;
close (DIFFS);

diffstat();

$dir_tmp_left =~ s{/}{\\}g;
$dir_tmp_right =~ s{/}{\\}g;

if (-d $dir_tmp_left)
{
	system("rmdir /S /Q $dir_tmp_left");
}

if (-d $dir_tmp_right)
{
system("rmdir /S /Q $dir_tmp_right");
}

unlink $diffsfile;
unlink "$Logs_Dir\\line_count_newdir.txt";

print "\n** Finished processing $package_name **\n\n\n\n\n";

exit(0);

sub diffstat()
{
open (DIFFSFILE,"$diffsfile");

my $curfile = "";
my %changes = ();

while (<DIFFSFILE>)
{
	my $line = $_;
				# diff -r -N D:/mirror\fbf_churn_output\commsfw.000000000000\serialserver\c32serialserver\Test\te_C32Performance\USB PC Side Code\resource.h 
				# diff -r <anything><changeset(12 chars)><slash><full_filename><optional_whitespace><EOL>
	if ($line =~ m/^diff -r.*\.[A-Fa-f0-9]{12}[\/\\](.*)\s*$/)
	{
		$curfile = $1;
		#DEBUG INFO:
		#print "\t$curfile\n";
		if (!defined $changes{$curfile})
		{
			$changes{$curfile} = {'a'=>0,'c'=>0,'d'=>0,'filetype'=>'unknown'};
		}
		
		$curfile =~ m/\.(\w+)$/g;
				
		#if filetype known...
		my $filetype = $+;
		
		$changes{$curfile}->{'filetype'}=uc($filetype);
	}
	elsif ($line =~ m/^(\d+)(,(\d+))?(d)\d+(,\d+)?/)
	{	
		if (defined $3)
		{
			$changes{$curfile}->{$4} += ($3-$1)+1;
		}
		else
		{
			$changes{$curfile}->{$4}++;
		}
	}
	elsif ($line =~ m/^\d+(,\d+)?([ac])(\d+)(,(\d+))?/)
	{	
		if (defined $5)
		{
			$changes{$curfile}->{$2} += ($5-$3)+1;
		}
		else
		{
			$changes{$curfile}->{$2}++;
		}	
	}
}

close (DIFFSFILE);

my %package_changes = ("CPP"=>0, "H"=>0, "HPP"=>0, "INL"=>0, "C"=>0, "CXX"=>0,"HRH"=>0,);
my %package_deletions = ("CPP"=>0, "H"=>0, "HPP"=>0, "INL"=>0, "C"=>0, "CXX"=>0,"HRH"=>0,);
my %package_additions = ("CPP"=>0, "H"=>0, "HPP"=>0, "INL"=>0, "C"=>0, "CXX"=>0,"HRH"=>0,);
my $package_churn = 0;

for my $file (keys %changes)
{
	$package_changes{$changes{$file}->{'filetype'}} += $changes{$file}->{'c'};
	$package_deletions{$changes{$file}->{'filetype'}} += $changes{$file}->{'d'};
	$package_additions{$changes{$file}->{'filetype'}} += $changes{$file}->{'a'};
}


#DEBUG INFO: For printing contents of hashes containing per filetype summary
#print "\n\n\n\n";
#print "package_changes:\n";
#print map { "$_ => $package_changes{$_}\n" } keys %package_changes;
#print "\n\n\n\n";
#print "package_deletions:\n";
#print map { "$_ => $package_deletions{$_}\n" } keys %package_deletions;
#print "\n\n\n\n";
#print "package_additions:\n";
#print map { "$_ => $package_additions{$_}\n" } keys %package_additions;



my $overall_changes = 0;
for my $filetype (keys %package_changes)
{
	$overall_changes += $package_changes{$filetype};
}

my $overall_deletions = 0;
for my $filetype (keys %package_deletions)
{
	$overall_deletions += $package_deletions{$filetype};
}

my $overall_additions = 0;
for my $filetype (keys %package_additions)
{
	$overall_additions += $package_additions{$filetype};
}


$package_churn = $overall_changes + $overall_additions;

print "\n\n\n\nSummary for Package: $package_name\n";
print "-------------------\n";
print "Changesets Compared: $dir_left and $dir_right\n";
#print "Code Size for $dir_left = $code_size_left lines\n";
#print "Code Size for $dir_right = $code_size_right lines\n";
print "Total Lines Changed = $overall_changes\n";
print "Total Lines Added = $overall_additions\n";
print "Total Lines Deleted = $overall_deletions\n";
print "Package Churn = $package_churn lines\n";

my @header = qw(filetype a c d);

my $outputfile = $Logs_Dir.'\\'."$package_name\_diffstat.csv";
open(PKGSTATCSV, ">$outputfile") or die "Coudln't open $outputfile";



print PKGSTATCSV " SF CODE-CHURN SUMMARY\n";
print PKGSTATCSV "Package: $package_name\n";
print PKGSTATCSV "Changesets Compared: $dir_left and $dir_right\n";
#print PKGSTATCSV "Code Size for $dir_left = $code_size_left lines\n";
#print PKGSTATCSV "Code Size for $dir_right = $code_size_right lines\n";
print PKGSTATCSV "Total Lines Changed = $overall_changes\n";
print PKGSTATCSV "Total Lines Added = $overall_additions\n";
print PKGSTATCSV "Total Lines Deleted = $overall_deletions\n";
print PKGSTATCSV "Package Churn = $package_churn lines\n\n\n\n\n";




# print the header
print PKGSTATCSV "FILENAME,";

foreach my $name (@header)
{
  if ($name eq 'filetype')
  {
	print PKGSTATCSV uc($name).",";
  }  
  elsif ($name eq 'a')
 {
	print PKGSTATCSV "LINES_ADDED,";
 }
  elsif ($name eq 'c')
 {
	print PKGSTATCSV "LINES_CHANGED,";
 }
  elsif ($name eq 'd')
 {
	print PKGSTATCSV "LINES_DELETED,";
 }
    
}

print PKGSTATCSV "\n";

foreach my $file (sort keys %changes)
{
  print PKGSTATCSV $file.",";
  foreach my $key (@header)
  {
    if(defined $changes{$file}->{$key})
    {
      print PKGSTATCSV $changes{$file}->{$key};
    }
    print PKGSTATCSV ",";
  }
  print PKGSTATCSV "\n";
}

close (PKGSTATCSV);



my $diffstat_summary = $Logs_Dir.'\\'."diffstat_summary.csv";

if (-e $diffstat_summary)
{ 
	open(DIFFSTATCSV, ">>$diffstat_summary") or die "Coudln't open $outputfile";
	print DIFFSTATCSV "$package_name,";
	print DIFFSTATCSV "$changeset_left,";
	print DIFFSTATCSV "$changeset_right,";
	
	#print DIFFSTATCSV ",";

	foreach my $filetype (sort keys %package_changes)
	{
		if(defined $package_changes{$filetype})
		{
		  print DIFFSTATCSV $package_changes{$filetype}.",";
		}
	}

	#print DIFFSTATCSV ",";
	
	foreach my $filetype (sort keys %package_additions)
	{
		if(defined $package_additions{$filetype})
		{
		  print DIFFSTATCSV $package_additions{$filetype}.",";
		  
		}
	}
	
	#print DIFFSTATCSV ",";
	
	foreach my $filetype (sort keys %package_deletions)
	{
		if(defined $package_deletions{$filetype})
		{
		  print DIFFSTATCSV $package_deletions{$filetype}.",";
		  #print DIFFSTATCSV ",";
		}
	}
	
	#print DIFFSTATCSV ",";
	print DIFFSTATCSV "$overall_changes,";
	print DIFFSTATCSV "$overall_additions,";
	print DIFFSTATCSV "$overall_deletions,";
	print DIFFSTATCSV "$package_churn,";

	print DIFFSTATCSV "\n";
	
	close (DIFFSTATCSV);
}
else
{
	open(DIFFSTATCSV, ">$diffstat_summary") or die "Couldn't open $outputfile";

	# print the header
	print DIFFSTATCSV "PACKAGE_NAME,";
	print DIFFSTATCSV "LEFT_CHANGESET,";
	print DIFFSTATCSV "RIGHT_CHANGESET,";

	#print DIFFSTATCSV ",";

	foreach my $name (sort keys %package_changes)
	{
		print DIFFSTATCSV $name." CHANGES,";    
	}
	#print DIFFSTATCSV ",";


	foreach my $name (sort keys %package_additions)
	{
		print DIFFSTATCSV $name." ADDITIONS,";    
	}
	#print DIFFSTATCSV ",";


	foreach my $name (sort keys %package_deletions)
	{
		print DIFFSTATCSV $name." DELETIONS,";    
	}
	#print DIFFSTATCSV ",";
	
	print DIFFSTATCSV "PACKAGE_CHANGES,";
	print DIFFSTATCSV "PACKAGE_ADDITIONS,";
	print DIFFSTATCSV "PACKAGE_DELETIONS,";
	print DIFFSTATCSV "PACKAGE_CHURN,";
	print DIFFSTATCSV "\n";
	
	
	print DIFFSTATCSV "$package_name,";
	
	print DIFFSTATCSV "$changeset_left,";
	print DIFFSTATCSV "$changeset_right,";
	
	#print DIFFSTATCSV ",";

	foreach my $filetype (sort keys %package_changes)
	{
		if(defined $package_changes{$filetype})
		{
		  print DIFFSTATCSV $package_changes{$filetype}.",";
		}
	}

	#print DIFFSTATCSV ",";
	
	foreach my $filetype (sort keys %package_additions)
	{
		if(defined $package_additions{$filetype})
		{
		  print DIFFSTATCSV $package_additions{$filetype}.",";
		  
		}
	}
	
	#print DIFFSTATCSV ",";
	
	foreach my $filetype (sort keys %package_deletions)
	{
		if(defined $package_deletions{$filetype})
		{
		  print DIFFSTATCSV $package_deletions{$filetype}.",";
		}
	}

	#print DIFFSTATCSV ",";
	print DIFFSTATCSV "$overall_changes,";
	print DIFFSTATCSV "$overall_additions,";
	print DIFFSTATCSV "$overall_deletions,";
	print DIFFSTATCSV "$package_churn,";
	
	print DIFFSTATCSV "\n";
	
	close (DIFFSTATCSV);
}



}

sub process_files() 
{
    my $lfile = $_;
    my $lfile_fullpath=$File::Find::name;
    $lfile_fullpath =~ s#\/#\\#g;
    #print "$lfile\t\tFull path $lfile_fullpath\n" ;
    if (-f $lfile)
    { 
        foreach my $regpat (@file_pattern)
        {
            if (lc($lfile) =~ m/$regpat/)
            {
                $lfile  =~ s#\/#\\#g;
                #print "Processing file $lfile (Matched $regpat) \n"; #ck
                #print `type $lfile`;
                # We copy mathching files to a separate temp directory
                # so that the final diff can simply diff the full dir
                # Note :  RemoveNoneLOC routine edits the file in-situ.
                my $lfile_abs = cwd().'\\'.$lfile;
                my $lfile_local = $Logs_Dir.'\\'.$lfile_fullpath;
                makepath($lfile_local);
                print "%";
                copy($lfile_abs,$lfile_local);
				$totallinecount += RemoveNonLOC( $lfile, $lfile_local, "newdir" );
            }
        }
    }   
}


sub makepath()
{
    my $absfile = shift; 
    $absfile =~ s#\\#\/#g;
    my @dirs = split /\//, $absfile;
    pop @dirs;  # throw away the filename
    my $path = "";
    foreach my $dir (@dirs)
    {
        $path = ($path eq "") ? $dir : "$path/$dir";
        if (!-d $path)
        {
#          print "making $path \n";
          mkdir $path;
        }
    }
}


sub RemoveNonLOC($$$) {

    # Gather arguments
    my $file = shift;
    my $original_file  = shift;
    my $type_of_dir = shift;
    
#    print("\nDebug: in ProcessFile, file is $file, full file + path is $original_file \n");
     
	# Remove comments...
	
    # Set up the temporary files that will be used to perform the processing steps
    my $temp1File = $original_file."temp1";
    my $temp2File = $original_file."temp2";
	
    open(TEMP1, "+>$temp1File");
    
    if (!($countcomments)) {
    
     	# Remove any comments from the file
		my $original_file_string;
     	open INPUT, "<", $original_file;
		{
			local $/ = undef;
			$original_file_string = <INPUT>;
		}
		close INPUT;
 
     	my $dbl = qr/"[^"\\]*(?:\\.[^"\\]*)*"/s;
        my $sgl = qr/'[^'\\]*(?:\\.[^'\\]*)*'/s;

        my $C   = qr{/\*.*?\*/}s; # C style comments /*  */
        my $CPP = qr{//.*}; # C+ style comments //
        my $com = qr{$C|$CPP};
        my $other = qr{.[^/"'\\]*}s; # all other '"
        my $keep = qr{$sgl|$dbl|$other};
     
     	#Remove the comments (need to turn off warnings on the next regexp for unititialised variable)
no warnings 'uninitialized';

        $original_file_string=~ s/$com|($keep)/$1/gom;  
        print TEMP1 "$original_file_string";

use warnings 'uninitialized';
    }
    else {
    
        print("\n option --CountComments specified so comments will be included in the count\n");
        #Just copy over original with comments still in it
		copy($original_file,$temp1File); 
    }
   	 
    close(TEMP1);
   	
 	  
    # Remove blank lines...
#   print("\nDebug: Getting rid of blank lines in \n$temp1File to produce \n$temp2File \n");
    open (TEMP1, "+<$temp1File"); # include lines + pre-processed code
    open (TEMP2, "+>$temp2File"); 
    
    while (<TEMP1>) {
		
        if (!(/^\s*\n$/)) { # if line isn't blank write it to the new file 
        print TEMP2 $_;
	}
    }
    close(TEMP1);
    close(TEMP2);
     
    #Copy the final file to the original file. This updated file will form the input to diff later.
    #todo dont need chmod now?
    chmod(oct("0777"), $original_file) or warn "\nCannot chmod $original_file : $!\n";
#   print("\nCopying $temp2File\n to \n$original_file\n");
    
    #system("copy /Y \"$temp2File\" \"$original_file\"") == 0
    #or print "\nERROR: Copy of $temp2File to $original_file failed\n";
    copy($temp2File,$original_file);
  	 
    # Store original file size
    
    open(LINECOUNT, ">>$Logs_Dir\\line_count_$type_of_dir.txt");
    open(SOURCEFILE, "<$original_file");
    
    my @source_code = <SOURCEFILE>;
    print  LINECOUNT "\n$original_file   ";
    my $linecount = scalar(@source_code);
#	print  LINECOUNT scalar(@source_code);
    print  LINECOUNT $linecount; 
     
    close(LINECOUNT);
    close(SOURCEFILE);
    
    #system("del /F /Q $Logs_Dir\\line_count_$type_of_dir.txt");

    #Delete the temporary files
    unlink($temp1File);
    unlink($temp2File);
       
    return $linecount;   
}