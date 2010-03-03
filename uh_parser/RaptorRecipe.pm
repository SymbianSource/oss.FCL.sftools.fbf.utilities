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
# Raptor parser module.
# Extract, analyzes and dumps raptor recipes i.e. content of <recipe> tags from a raptor log file

package RaptorRecipe;

use strict;
use RaptorCommon;

our $reset_status = {};
my $buildlog_status = {};
my $buildlog_recipe_status = {};
my $buildlog_recipe_status_status = {};

$reset_status->{name} = 'reset_status';
$reset_status->{next_status} = {buildlog=>$buildlog_status};

$buildlog_status->{name} = 'buildlog_status';
$buildlog_status->{next_status} = {recipe=>$buildlog_recipe_status};
$buildlog_status->{on_start} = 'RaptorRecipe::on_start_buildlog';
$buildlog_status->{on_end} = 'RaptorRecipe::on_end_buildlog';

$buildlog_recipe_status->{name} = 'buildlog_recipe_status';
$buildlog_recipe_status->{next_status} = {status=>$buildlog_recipe_status_status};
$buildlog_recipe_status->{on_start} = 'RaptorRecipe::on_start_buildlog_recipe';
$buildlog_recipe_status->{on_end} = 'RaptorRecipe::on_end_buildlog_recipe';
$buildlog_recipe_status->{on_chars} = 'RaptorRecipe::on_chars_buildlog_recipe';

$buildlog_recipe_status_status->{name} = 'buildlog_recipe_status_status';
$buildlog_recipe_status_status->{next_status} = {};
$buildlog_recipe_status_status->{on_start} = 'RaptorRecipe::on_start_buildlog_recipe_status';


my $filename = '';
my $failure_item = 0;

my $recipe_info = {};

my $characters = '';

my $CATEGORY_RECIPEFAILURE = 'recipe_failure';
my $CATEGORY_RECIPEFAILURE_ARMCC_CANNOTOPENSOURCEINPUTFILE = 'armcc_cannot_open_source_input_file';
my $CATEGORY_RECIPEFAILURE_ARMLINK_COULDNOTOPENFILE = 'armlink_could_not_open_file';
my $CATEGORY_RECIPEFAILURE_ELF2E32_COULDNOTOPENFILE = 'elf2e32_could_not_open_file';
my $CATEGORY_RECIPEFAILURE_ARMAR_FILEDOESNOTEXIST = 'armar_file_does_not_exist';
my $CATEGORY_RECIPEFAILURE_ARMCC_CONTROLLINGEXPRESSIONISCONSTANT = 'armcc_controlling_expression_is_constant';
my $CATEGORY_RECIPEFAILURE_ARMCC_INTERNALFAULT = 'armcc_internal_fault';
my $CATEGORY_RECIPEFAILURE_ARMCC_MODIFIERNOTALLOWED = 'armcc_modifier_not_allowed';
my $CATEGORY_RECIPEFAILURE_ARMCC_GENERICWARNINGSERRORS = 'armcc_generic_warnings_errors';
my $CATEGORY_RECIPEFAILURE_ELF2E32_SYMBOLMISSINGFROMELFFILE = 'elf2e32_symbol_missing_from_elf_file';
my $CATEGORY_RECIPEFAILURE_MWCCSYM2_FILECANNOTBEOPENED = 'mwccsym2_file_cannot_be_opened';

my $mmp_with_issues = {};


sub process
{
	my ($text, $config, $component, $mmp, $phase, $recipe, $file, $line) = @_;
	
	my $category = $CATEGORY_RECIPEFAILURE;
	my $severity = '';
	my $subcategory = '';
	
	# if mmp is defined assign severity=MAJOR for the first failure
	# then severity=MINOR to all other (for each logfile)
	if ($mmp and defined $mmp_with_issues->{$::current_log_file}->{$mmp})
	{
		$severity = $RaptorCommon::SEVERITY_MINOR;
	}
	elsif ($mmp)
	{
		$mmp_with_issues->{$::current_log_file} = {} if (!defined $mmp_with_issues->{$::current_log_file});
		$mmp_with_issues->{$::current_log_file}->{$mmp} = 1;
		$severity = $RaptorCommon::SEVERITY_MAJOR;
	}
	else
	{
		$severity = $RaptorCommon::SEVERITY_MAJOR;
	}
	
	
	if ($text =~ m,Error:  #5: cannot open source input file .*: No such file or directory,)
	{
		my $subcategory = $CATEGORY_RECIPEFAILURE_ARMCC_CANNOTOPENSOURCEINPUTFILE;
		RaptorCommon::dump_fault($category, $subcategory, $severity, $config, $component, $mmp, $phase, $recipe, $file, $line);
	}
	elsif ($text =~ m,Fatal error: L6002U: Could not open file .*: No such file or directory,)
	{
		my $subcategory = $CATEGORY_RECIPEFAILURE_ARMLINK_COULDNOTOPENFILE;
		RaptorCommon::dump_fault($category, $subcategory, $severity, $config, $component, $mmp, $phase, $recipe, $file, $line);
	}
	elsif ($text =~ m,elf2e32 : Error: E1001: Could not open file : .*.,)
	{
		my $subcategory = $CATEGORY_RECIPEFAILURE_ELF2E32_COULDNOTOPENFILE;
		RaptorCommon::dump_fault($category, $subcategory, $severity, $config, $component, $mmp, $phase, $recipe, $file, $line);
	}
	elsif ($text =~ m,elf2e32 : Error: E1036: Symbol .* Missing from ELF File,)
	{
		my $subcategory = $CATEGORY_RECIPEFAILURE_ELF2E32_SYMBOLMISSINGFROMELFFILE;
		RaptorCommon::dump_fault($category, $subcategory, $severity, $config, $component, $mmp, $phase, $recipe, $file, $line);
	}
	elsif ($text =~ m,Error: L6833E: File '.*' does not exist,)
	{
		my $subcategory = $CATEGORY_RECIPEFAILURE_ARMAR_FILEDOESNOTEXIST;
		RaptorCommon::dump_fault($category, $subcategory, $severity, $config, $component, $mmp, $phase, $recipe, $file, $line);
	}
	elsif ($text =~ m,: Warning:  #236-D: controlling expression is constant,)
	{
		my $subcategory = $CATEGORY_RECIPEFAILURE_ARMCC_CONTROLLINGEXPRESSIONISCONSTANT;
		RaptorCommon::dump_fault($category, $subcategory, $severity, $config, $component, $mmp, $phase, $recipe, $file, $line);
	}
	elsif ($text =~ m,/armcc.exe , and $text =~ m,Internal fault: ,)
	{
		my $subcategory = $CATEGORY_RECIPEFAILURE_ARMCC_INTERNALFAULT;
		RaptorCommon::dump_fault($category, $subcategory, $severity, $config, $component, $mmp, $phase, $recipe, $file, $line);
	}
	elsif ($text =~ m,/armcc.exe , and $text =~ m,Error:  #655-D: the modifier ".*" is not allowed on this declaration,)
	{
		my $subcategory = $CATEGORY_RECIPEFAILURE_ARMCC_MODIFIERNOTALLOWED;
		RaptorCommon::dump_fault($category, $subcategory, $severity, $config, $component, $mmp, $phase, $recipe, $file, $line);
	}
	# the following captures generic armcc error/warnings, not captured by regexps above
	elsif ($text =~ m,/armcc.exe , and $text =~ m,: \d+ warnings\, \d+ errors$,)
	{
		my $subcategory = $CATEGORY_RECIPEFAILURE_ARMCC_GENERICWARNINGSERRORS;
		RaptorCommon::dump_fault($category, $subcategory, $severity, $config, $component, $mmp, $phase, $recipe, $file, $line);
	}
	elsif ($text =~ m,mwccsym2.exe , and $text =~ m,: the file '.*' cannot be opened,)
	{
		my $subcategory = $CATEGORY_RECIPEFAILURE_MWCCSYM2_FILECANNOTBEOPENED;
		RaptorCommon::dump_fault($category, $subcategory, $severity, $config, $component, $mmp, $phase, $recipe, $file, $line);
	}
	else # log everything by default
	{
		RaptorCommon::dump_fault($category, $subcategory, $severity, $config, $component, $mmp, $phase, $recipe, $file, $line);
	}
}

sub on_start_buildlog
{
	#print FILE "line,layer,component,name,armlicence,platform,phase,code,bldinf,mmp,target,source,\n";
	
	RaptorCommon::init();
}

sub on_start_buildlog_recipe
{
	my ($el) = @_;
	
	#print "on_start_buildlog_recipe\n";
	
	$recipe_info = {};
	
	my $attributes = $el->{Attributes};
	for (keys %{$attributes})
	{
		$recipe_info->{$attributes->{$_}->{'LocalName'}} = $attributes->{$_}->{'Value'};
		#print "$_ -> $attributes->{$_}->{'Value'}\n";
	}
}

sub on_chars_buildlog_recipe
{
	my ($ch) = @_;
	
	#print "on_chars_buildlog_recipe\n";
	
	$characters .= $ch->{Data};
	
	#print "characters is now -->$characters<--\n";
}

sub on_start_buildlog_recipe_status
{
	my ($el) = @_;
	
	my $attributes = $el->{Attributes};
	for (keys %{$attributes})
	{
		if ($attributes->{$_}->{'LocalName'} eq 'code')
		{
			$recipe_info->{$attributes->{$_}->{'LocalName'}} = $attributes->{$_}->{'Value'};
		}
		elsif ($attributes->{$_}->{'LocalName'} eq 'exit')
		{
			$recipe_info->{$attributes->{$_}->{'LocalName'}} = $attributes->{$_}->{'Value'};
		}
		elsif ($attributes->{$_}->{'LocalName'} eq 'attempt')
		{
			$recipe_info->{$attributes->{$_}->{'LocalName'}} = $attributes->{$_}->{'Value'};
		}
	}
}

sub on_end_buildlog_recipe
{
	$::allbldinfs->{$recipe_info->{bldinf}} = 1;
	
	if ($recipe_info->{exit} =~ /failed/)
	{
		# normalize bldinf path
		$recipe_info->{bldinf} = lc($recipe_info->{bldinf});
		$recipe_info->{bldinf} =~ s,^[A-Za-z]:,,;
		$recipe_info->{bldinf} =~ s,[\\],/,g;
		
		my $package = '';
		if ($recipe_info->{bldinf} =~ m,/((os|mw|app|tools|ostools|adaptation)/[^/]*),)
		{
			$package = $1;
			$package =~ s,/,_,;
		}
		else
		{
			print "WARNING: can't understand bldinf attribute of recipe: $recipe_info->{bldinf}. Won't dump to failed recipes file.\n";
		}
		
		# also normalize mmp path if this exists
		if ($recipe_info->{mmp})
		{
			$recipe_info->{mmp} = lc($recipe_info->{mmp});
			$recipe_info->{mmp} =~ s,^[A-Za-z]:,,;
			$recipe_info->{mmp} =~ s,[\\],/,g;
		}
		
		$characters =~ s,^[\r\n]*,,;
		$characters =~ s,[\r\n]*$,,;
		
		if ($package)
		{
			$filename = "$::raptorbitsdir/$package.txt";
			if (!-f$filename)
			{
				print "Writing recipe file $filename\n";
				open(FILE, ">$filename");
				close(FILE);
			}
			
			if ($failure_item == 0 and -f "$filename")
			{
				open(FILE, "$filename");
				{
					local $/ = undef;
					my $filecontent = <FILE>;
					$failure_item = $1 if ($filecontent =~ m/.*---failure_item_(\d+)/s);
				}
				close(FILE);
			}
			
			$failure_item++;
			
			open(FILE, ">>$filename");
			print FILE "---failure_item_$failure_item\---\n";
			print FILE "$characters\n\n";
			close(FILE);
		}
		
		process($characters, $recipe_info->{config}, $recipe_info->{bldinf}, $recipe_info->{mmp}, $recipe_info->{phase}, $recipe_info->{name}, "$package.txt", $failure_item);
	}

	$characters = '';
}

sub on_end_buildlog
{
}


1;