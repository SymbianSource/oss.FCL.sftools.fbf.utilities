#! perl

# Read a Foundation system model, mapping file, and System_Definition.xml
# and generate a Perforce branchspec to reflect the code reorg

use strict;

use FindBin;
use lib ".";
use lib "./lib";
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/lib";
use XML::DOM;
#use XML::DOM::ValParser;

# produces the "Use of uninitialized value in concatenation (.) or string" warning
use XML::XQL;
use XML::XQL::DOM;

# Read the command line to get the filenames

sub Usage($)
	{
	my ($reason) = @_;

	print "Usage: $reason\n" if ($reason);
	print <<USAGE_EOF;

Usage: generate_branchspec.pl <params> [options]

params:
-s <system_definition>  XML version of Symbian System_definition
-m <foundation_model>   XML version of Foundation System Model

options:
-o <whats_left>     XML file showing unreferenced
                       parts of the System Model
-r                  Remove matched objects from -o output
-c <cbr_mapping>    Tab separated file showing the Schedule 12
                       component for each MRP file

USAGE_EOF
	exit(1);
	}
	
use Getopt::Long;

my $foundationmodel = "output_attr.xml";
my $foundationdirs = "foundation_dirs.xml";
my $systemdefinition = "variability/vp_data/templates/System_Definition_template.xml";
my $rootdir = ".";
my $remove = 0;
my $cbrmappingfile = "";

Usage("Bad arguments") unless GetOptions(
  	'm=s' => \$foundationmodel, 
  	's=s' => \$systemdefinition,
  	'o=s' => \$rootdir,
  	'c=s' => \$cbrmappingfile);

Usage("Too many arguments") if (scalar @ARGV > 0);
Usage("Cannot find $foundationmodel") if (!-f $foundationmodel);


my $xmlParser = new XML::DOM::Parser; 
XML::DOM::ignoreReadOnly(1);

my $foundationpath = ".";
my $sysdefpath = ".";
$foundationpath = $1 if ($foundationmodel  =~ /^(.+)\\[^\\]+$/);
$sysdefpath = $1 if ($systemdefinition =~ /^(.+)\\[^\\]+$/);
#$xmlParser->set_sgml_search_path($foundationpath, $sysdefpath);

my $foundationXML = $xmlParser->parsefile ($foundationmodel);
chdir($rootdir);

# Collect the Schedule12 entries, checking for duplicates

my %sch12refs;
my %componenttype;
my ($foundation) = $foundationXML->getElementsByTagName("SystemDefinition");
Usage("No <SystemDefinition> in $foundationmodel ?") if (!defined $foundation);

# Process the Foundation model to get the directory names

my %unique_names;
my %partnames;
my %dirnames;
my %component_dirs;
my %old_component_mapping;
my %component_object;	# reference to XML <component> objects
my %mrp_mapping;

sub process_foundation($$);		# declare the prototype for recursive call
sub process_foundation($$)
	{
	my ($node,$level) = @_;

	my @children = $node->getChildNodes;
	foreach my $child (@children)
		{
		if ($child->getNodeTypeName ne "ELEMENT_NODE")
			{
			# text and comments don't count
			next;
			}
		if ($level == 0)
			{
			process_foundation($child,1);
			next;
			}

		next if ($child->getAttribute("contribution") eq "excluded");

		my $tagname = $child->getTagName;
		my $name = $child->getAttribute("name");
		my $longname = $child->getAttribute("long-name");
		$longname = $name if ($longname eq "");
		
		if ($name ne "")
			{
			if (defined $unique_names{$name})
				{
				print "** duplicated name $name\n";
				}
			$unique_names{$name} = 1;
			}
		if ($name eq "")
			{
			printf "No name in %s\n", $child->toString();
			next;
			}
		
		my $dirname = $name;
		$dirname =~ s/\s+//g;		# remove the spaces
		$dirname =~ s/[\(\)]/_/g;	# map troublesome characters
		$dirname =~ s/[ \.]*$//g;	# trailing spaces or dots
		$partnames{$tagname} = $name;
		$dirnames{$tagname} = $dirname;
		
		print "making directory $dirname\n" if ($level <2);
		mkdir $dirname;	# create the directory
		
		if ($tagname eq "component")
			{
			$child->printToFile("$dirname/component.txt");
			next;
			}

		chdir $dirname;		
		if ($tagname eq "block")
			{
			# Create a fragment which describes this package
			open PACKAGE_MODEL, ">package_model.xml";
			print PACKAGE_MODEL "<!-- use XINCLUDE to put this fragment into a System_Model -->\n";
			print PACKAGE_MODEL $child->toString();
			print PACKAGE_MODEL "\n";
			close PACKAGE_MODEL;
			}

		process_foundation($child,$level+1);
		chdir "..";
		}
	}

my ($model) = $foundationXML->getElementsByTagName("SystemDefinition");
process_foundation($model,0);

exit 0;

# Dump the old component -> new component -> directory mapping

foreach my $component (sort keys %old_component_mapping)
	{
	my $new_component = $old_component_mapping{$component};
	printf "%s => %s => %s\n",
		$component, $new_component, $component_dirs{$new_component};
	}

# Find the old component entries in the XML file

my %branchspec;
my %reverse_branchspec;
my %primary_mrp;
my %otherroots;
my %ignoreme;

sub add_to_branchspec($$;$$);
sub add_to_branchspec($$;$$)
	{
	my ($olddir,$newdir,$primary,$noexpansion) = @_;
	$primary = "generate_branchspec.pl" if (!defined $primary);
	
	if (defined $ignoreme{$olddir} && $primary !~ /^extra root/)
		{
		print "Ignoring $olddir - $ignoreme{$olddir}\n";
		next;
		}
	if (defined $branchspec{$olddir})
		{
		if ($newdir eq $branchspec{$olddir})
			{
			# reasserting the previous branchspec - not a problem
			return;
			}
		# trying to change the old mapping
		print "$primary attempted to redefine $olddir mapping\n";
		print "Was $branchspec{$olddir} instead of $newdir\n";
		exit(1);
		}

	if (defined $reverse_branchspec{$newdir})
		{
		print "Branchspec collision from $primary into $newdir\n";
		print "Can't send $olddir and $reverse_branchspec{$newdir} to same place\n";
		exit(1);
		}
	
	if (defined $otherroots{$olddir} && !$noexpansion)
		{
		print "Adjusting branchspec for $primary to include the other roots\n";
		my $otherolddir = $olddir;
		$otherolddir =~ s/([^\/]+)\/$//;
		my $maindir = $1;
		add_to_branchspec("$olddir","$newdir$maindir/",$primary,1);	# avoid recursion

		foreach my $otherdir (split /\//, $otherroots{$olddir})
			{
			next if (length($otherdir) == 0);
			add_to_branchspec("$otherolddir$otherdir/","$newdir$otherdir/","extra root of $primary",1);
			}
		}
	else
		{
		$branchspec{$olddir} = $newdir;
		$reverse_branchspec{$newdir} = $olddir;
		$primary_mrp{$olddir} = $primary;
		}
	}

# Workaround for the common/product and cedar/product directories, which don't
# have associated CBR components

add_to_branchspec("common/product/", "ostools/toolsandutils/ToolsandUtils/product/");
add_to_branchspec("cedar/product/",  "ostools/toolsandutils/ToolsandUtils/cedarproduct/");

# Add catchall mappings to get all do the other odds and ends
# LHS must be more specific than a single directory, otherwise apply_branchspec hits too many things
# RHS must be short, to avoid blowing the Windows path limit when syncing TBAS builds
add_to_branchspec("common/generic/",   "os/unref/orphan/comgen/", "(Orphans)");
add_to_branchspec("common/techview/",  "os/unref/orphan/comtv/",  "(Orphans)");
add_to_branchspec("common/testtools/", "os/unref/orphan/comtt/",  "(Orphans)");
add_to_branchspec("common/connectqi/", "os/unref/orphan/comqi/",  "(Orphans)");
add_to_branchspec("cedar/generic/",    "os/unref/orphan/cedgen/", "(Orphans)");

my @clumps = (
	"cedar/generic/base/e32/",
	"cedar/generic/base/f32/",
	"common/generic/comms-infras/esock/",
	"common/generic/multimedia/ecam/",
	"common/generic/multimedia/icl/",
	"common/generic/multimedia/mmf/",
	"common/generic/j2me/",				# not really a clump, but must be called "j2me"
	"common/generic/telephony/trp/",
	"common/generic/security/caf2/test/",
	"common/generic/networking/dialog/",
	"common/generic/comms-infras/commsdat/",
	"common/generic/connectivity/legacy/PLP/",	# plpvariant shares PLPInc main PLP group
	"common/testtools/ResourceHandler/",	# entangled versions for Techview, UIQ and S60
);

# Force E32 into a faintly sensible place

add_to_branchspec("cedar/generic/base/e32/", "os/kernelhwsrv/kernel/eka/", "(Hand coded E32 location)");

# Force j2me to be called j2me

add_to_branchspec("common/generic/j2me/", "app/java/midpprofile/midpmidlet/j2me/", "(Hand coded J2ME location)");

# Peer relationships if x uses "..\y", then add this as $peers{"x"} = "y"

my %peers;
$peers{"cedar/generic/tools/e32toolp/"} = "cedar/generic/tools/buildsystem/";

# multirooted components, which own several trees that have no common root
# Add these to the branchspec automatically alongside the root containing the MRP file

$otherroots{"common/generic/networking/inhook6/"} = "inhook6example";
$otherroots{"common/generic/networking/examplecode/"} = "anvltest/cgi/ping/udpecho/udpsend/webserver";
$otherroots{"common/generic/networking/qos/"} = "qostest/QoSTesting";
$otherroots{"common/generic/wap-stack/wapstack/"} = "documentation/confidential";
$otherroots{"common/generic/bluetooth/latest/bluetooth/test/"} = "example/testui";


my %hasbldfile;

my %foundationrefs;
my %foundationbymrp;
my %modelnames;
sub match_names($);		# declare the prototype for recursive call
sub match_names($)
	{
	my ($node) = @_;

	my @children = $node->getChildNodes;
	foreach my $child (@children)
		{
		if ($child->getNodeTypeName ne "ELEMENT_NODE")
			{
			# text and comments don't count
			next;
			}
		my $tagname = $child->getTagName;
		if ($tagname eq "layer")
			{
			$partnames{"block"} = undef;
			$partnames{"subblock"} = undef;
			$partnames{"collection"} = undef;
			}
		if ($tagname eq "block")
			{
			$partnames{"subblock"} = undef;
			$partnames{"collection"} = undef;
			}
		if ($tagname eq "subblock")
			{
			$partnames{"collection"} = undef;
			}
		if ($tagname eq "unit")
			{
			# units are the payload

			my $mrp = $child->getAttribute("mrp");
			$mrp =~ s/\\/\//g;	# ensure that / separators are used
			$child->setAttribute("mrp",$mrp);

			my $blockname = $partnames{"subblock"};
			$blockname = $partnames{"block"} if (!defined $blockname);	# no subblock
			$blockname = "Misc" if (!defined $blockname);	# no block either
			my $old_component = join("::",
				$partnames{"layer"}, $blockname, 
				$partnames{"collection"},$partnames{"component"});

			# find corresponding new component
			
			my $new_component;
			
			if (defined $mrp_mapping{$mrp})
				{
				$new_component = $mrp_mapping{$mrp};
				my $othermapping = $old_component_mapping{$old_component};
				if (defined $othermapping && $othermapping eq $new_component)
					{
					# they agree - lovely.
					}
				else
					{
					print "MRP mapping $mrp -> $new_component, disagrees with $old_component mapping\n";
					}
				delete $component_object{$new_component};
				}
			if (!defined $new_component)
				{
				$new_component = $old_component_mapping{$old_component};
				}
			if (!defined $new_component)
				{
				# Some "old_package" information is incorrect - scan for a close match
				# Strategy 1 - match collection::component
				my $tail = join ("::", $partnames{"collection"},$partnames{"component"});
				my $len = 0-length($tail);
				
				foreach my $guess (keys %old_component_mapping)
					{
					if (substr($guess,$len) eq $tail)
						{
						print "Guessed that $old_component should be $guess\n";
						$new_component = $old_component_mapping{$guess};
						last;
						}
					}
				}
			if (!defined $new_component)
				{
				# Some "old_package" information is incorrect - scan for a close match
				# Strategy 2 - just match the component name, 
				# truncate after last / e.g. GPRS/UMTS QoS Framework => UMTS QoS Framework
				my $tail = "::".$partnames{"component"};
				$tail =~ s/^.*\/([^\/]*)$/$1/;
				my $len = 0-length($tail);
				
				foreach my $guess (keys %old_component_mapping)
					{
					if (substr($guess,$len) eq $tail)
						{
						print "Guessed that $old_component should be $guess\n";
						$new_component = $old_component_mapping{$guess};
						last;
						}
					}
				}
			if (!defined $new_component)
				{
				print "Rescuing unreferenced $old_component\n";
				# later we will infer the new_component directory from the mrp
				}
			else
				{
				if (!defined $mrp_mapping{$mrp})
					{
					# Copy the unit into the Foundation model (we'll fix it later)
					
					my $foundation_comp = $component_object{$new_component};
					$node->removeChild($child);
					$child->setOwnerDocument($foundation_comp->getOwnerDocument);
					$foundation_comp->addText("\n      ");
					$foundation_comp->appendChild($child);
					$foundation_comp->addText("\n     ");
					delete $component_object{$new_component};	# remove items after processing
					}
				}
			
			# determine the root of the component source tree from the mrp attribute
			
			if ($mrp =~ /^\//)
				{
				print "Skipping absolute MRP $mrp in $old_component\n";
				next;
				}
			
			my $current_dir = $mrp;
			$current_dir =~ s-/[^/]+$-/-;		# remove filename;

			# tree structure special cases
			$current_dir =~ s-/sms/multimode/Group/-/sms/-;
			$current_dir =~ s-/agendaserver/TestAgendaSrv/-/agendaserver/-;
			$current_dir =~ s-/alarmserver/TestAlarmSrv/-/alarmserver/-;
			$current_dir =~ s-/trace/ulogger/group/-/trace/-;
			$current_dir =~ s-/ucc/BuildScripts/group/-/ucc/-;
			$current_dir =~ s-/worldserver/TestWorldSrv/-/worldserver/-;
			$current_dir =~ s-/adapters/devman/Group/-/adapters/-;	# avoid collision with syncml/devman
			$current_dir =~ s-/mobiletv/hai/dvbh/group/-/mobiletv/-;
			$current_dir =~ s-/plpgrp/-/-i;		# connectivity/legacy/PLP/plpgrp
			$current_dir =~ s-/(h2|h4)/.*$-/-i;	# various baseports

			# more generic cases
			$current_dir =~ s-/group/.*$-/-i;	# group (& subdirs)
			$current_dir =~ s-/group[^/]+/.*$-/-i;	# groupsql, groupfuture (& subdirs) - cntmodel, s60 header compat
			$current_dir =~ s-/mmpfiles/-/-i;	# comp/mmpfiles
			
			# apply clumping rules
			
			foreach my $clump (@clumps)
				{
				if (substr($current_dir,0,length($clump)) eq $clump)
					{
					print "$mrp is part of the component group rooted at $clump\n";
					$current_dir = $clump;
					last;
					}
				}
			
			# check for inseparable components
			my $new_dir;
			my $primary;
			my $set_peer_directory = 0;
			
			if (defined $branchspec{$current_dir})
				{
				$primary = $primary_mrp{$current_dir};
				print "Cannot separate $mrp from $primary\n";
				$new_dir = $branchspec{$current_dir};	# use the directory for the other component
				}
			elsif (defined $peers{$current_dir})
				{
				# apply peering rules
				my $peer = $peers{$current_dir};
				
				if (defined $branchspec{$peer})
					{
					# peer already defined - adjust our mapping
					$new_dir = $branchspec{$peer};
					$new_dir =~ s/[^\/]+\/$//;
					$current_dir =~ m/([^\/]+\/)$/;
					$new_dir .= $1;
					print "Mapping $mrp to $new_dir to be next to peer $peer\n";
					$primary = $mrp;
					}
				else
					{
					# we are the first to appear, so we determine the directory
					$set_peer_directory = 1;
					}
				}
			
			if (!defined $new_dir)
				{
				if (defined $new_component)
					{
					$new_dir = $component_dirs{$new_component};
					}
				else
					{
					$new_dir = "os/unref/$current_dir";
					$new_dir =~ s/common\/generic/comgen/;
					$new_dir =~ s/common\/techview/comtv/;
					$new_dir =~ s/common\/testtools/comtt/;
					$new_dir =~ s/common\/connectqi/comqi/;
					$new_dir =~ s/common\/developerlibrary/devlib/;
					$new_dir =~ s/cedar\/generic/cedgen/;
					}
				$primary = $mrp;
				}
			
			# Update the mrp attribute
			
			substr($mrp,0,length($current_dir)) = $new_dir;
			# $child->setAttribute("mrp",$mrp);
			
			# update the bldFile attribute, if any
			my $bldFile = $child->getAttribute("bldFile");
			if ($bldFile)
				{
				$bldFile =~ s/\\/\//g;	# ensure that / separators are used
				$child->setAttribute("bldFile",$bldFile);
				$hasbldfile{$current_dir} = 1;
				my $saved_bldFile = $bldFile;
				$bldFile .= "/" if ($bldFile !~ /\/$/);	# add trailing /
				my $previous = substr($bldFile,0,length($current_dir),$new_dir);
				if ($previous ne $current_dir)
					{
					print "*** $old_component bldFile=$saved_bldFile not in $current_dir\n";
					}
				else
					{
					$bldFile =~ s/\/+$//;	# remove trailing /
					# $child->setAttribute("bldFile",$bldFile);
					}
				} 
			
			add_to_branchspec($current_dir, $new_dir, $primary);

			if ($set_peer_directory)
				{
				# peer mapping implied by our mapping
				my $peer = $peers{$current_dir};
				$new_dir =~ s/[^\/]+\/$//;
				$peer =~ m/([^\/]+\/)$/;
				$new_dir .= $1;
				print "Implied mapping $peer to $new_dir to be next to $mrp\n";
				add_to_branchspec($peer, $new_dir, "$mrp (peer)");
				}

			next;
			}
		my $name = $child->getAttribute("name");
		$partnames{$tagname} = $name;
		match_names($child);
		}
	}

foreach my $missing (sort keys %component_object)
	{
	print "No mapping found for Symbian-derived component $missing\n";
	}

# Output Perforce branchspec, taking care to "subtract" the
# places where a subtree is branched to a different place

my $from = "//epoc/release/9.4";
my $to = "//epoc/development/personal/williamro/seaside/31";
my %processed;

printf "\n\n========== branchspec with %d elements\n", scalar keys %branchspec;

foreach my $olddir (sort keys %branchspec)
	{
	my $comment = $hasbldfile{$olddir} ? "" : "\t# src";
	
	my $subtraction = "";
	my @parts = split /\//, $olddir;
	my $root = "";
	while (@parts)
		{
		my $part = shift @parts;
		$root .= "$part/";
		if (defined $processed{$root})
			{
			# Found a containing tree
			my $remainder = join("/",@parts);
			$subtraction = sprintf "\t-$from/%s%s/... $to/%s%s/...\n",
				$root, $remainder, $branchspec{$root}, $remainder;
			# continue in case there is a containing sub-subtree.
			}
		}
	print $subtraction;	# usually empty
	printf "\t$from/%s... $to/%s...%s\n", $olddir, $branchspec{$olddir},$comment;
	$processed{$olddir} = 1;
	}

exit(0);

# Report on the accuracy of Schedule 12
print STDERR "\n";
my @allnames = ();
my $unmatched = 0;
foreach my $name (sort keys %sch12refs)
	{
	next if (defined $modelnames{$name});
	push @allnames, "$name\t(Sch12 $foundationrefs{$name})\n";
	print STDERR "No match for $name (associated with $foundationrefs{$name})\n";
	$unmatched += 1;
	}
if ($unmatched == 0)
	{
	print STDERR "All Schedule 12 entries matched in System Model\n";
	}
else
	{
	printf STDERR "%d Schedule 12 entry references not matched (from a total of %d)\n", $unmatched, scalar keys %sch12refs; 
	}

# Remove the matched elements to leave the unmatched parts,
# and accumulate the MRP files for each Sch12 component

my %sch12bymrp;
my %locationbymrp;

sub list_mrps($$$);		# declare the prototype for recursive call
sub list_mrps($$$)
	{
	my ($node,$location,$foundationname) = @_;
	my @children = $node->getChildNodes;
	my $nodename = $node->getAttribute("name");

	my $sublocation = $nodename;
	$sublocation = "$location/$nodename" if ($location ne "");
	
	foreach my $child (@children)
		{
		if ($child->getNodeTypeName ne "ELEMENT_NODE")
			{
			# text and comments don't count
			next;
			}
		my $tagname = $child->getTagName;
		if ($tagname eq "unit" || $tagname eq "package" || $tagname eq "prebuilt")
			{
			# these elements have the mrp information, but no substructure
			my $mrp = $child->getAttribute("mrp");
			$mrp = $1 if ($mrp =~ /\\([^\\]+)\.mrp$/i);
			$foundationbymrp{$mrp} = $foundationname;
			$locationbymrp{$mrp} = "$location\t$nodename";
			next;
			}
		my $submatch = $child->getAttribute("MATCHED");
		if ($submatch)
			{
			list_mrps($child,$sublocation,$submatch);
			}
		else
			{
			list_mrps($child,$sublocation,$foundationname);
			}
		}
	}

sub delete_matched($$);		# declare the prototype for recursive call
sub delete_matched($$)
	{
	my ($node, $location) = @_;
	my $nodename = $node->getAttribute("name");

	my $sublocation = $nodename;
	$sublocation = "$location/$nodename" if ($location ne "");

	my @children = $node->getChildNodes;
	return 0 if (scalar @children == 0);
	my $now_empty = 1;
	foreach my $child (@children)
		{
		if ($child->getNodeTypeName ne "ELEMENT_NODE")
			{
			# text and comments don't count
			next;
			}
		my $foundationname = $child->getAttribute("MATCHED");
		if ($foundationname)
			{
			list_mrps($child, $sublocation, $foundationname);
			$node->removeChild($child) if ($remove);
			}
		else
			{
			if (delete_matched($child,$sublocation) == 1)
				{
				# Child was empty and can be removed
				$node->removeChild($child) if ($remove);
				}
			else
				{
				list_mrps($child, $sublocation, "*UNREFERENCED*");
				$now_empty = 0;		# something left in due to this child
				}
			}
		}
	return $now_empty;
	}

# scan the tagged model, recording various details as a side-effect

my $allgone = delete_matched($model,"");

if ($cbrmappingfile ne "")
	{
	$componenttype{"*UNREFERENCED*"} = "??";
	open CBRMAP, ">$cbrmappingfile" or die("Unable to write to $cbrmappingfile: $!\n");
	foreach my $mrp (sort keys %sch12bymrp)
		{
		my $component = $foundationbymrp{$mrp};
		my $comptype = $componenttype{$component};
		my $location = $locationbymrp{$mrp};
		print CBRMAP "$mrp\t$location\t$component\t$comptype\n";
		}
	close CBRMAP;
	print STDERR "MRP -> Schedule 12 mapping written to $cbrmappingfile\n";
	}

exit 0;
