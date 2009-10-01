#!/usr/bin/perl

 

use IO::Socket; 
use Getopt::Long;


my $target_url; #target url for the roadmap
my $tdomain; #tag for the domain to be use in csv file
my $csvfile; #output csv file name
my $authon= '';	 #does it require authorisation? default is false

my $ispackage;
my $summaryheader="ID\tPackage\tFeatures\tFormat\tHttp\n" ;
my $newtdformat = 0;

sub getpage
{
	#arguments
	($page,$host,$auth,$myfile)=@_;
	
	
	#output file
	open ( outputfile, ">".$myfile);
	
	
	$port = "http(80)";
	$getmess = "GET " . $page ." HTTP/1.1\n" . $auth;

	print "INFO - sending message - $getmess\n";
	print outputfile "$getmess\n\n";

	$sock = IO::Socket::INET->new 	
		(
		 PeerAddr => $host,   PeerPort => $port,  Proto => 'tcp', 
		) ;

 
	print $sock "$getmess\n\n";

 
	while(<$sock>) {
 
	  print outputfile $_;
 
	}	
  	
	close ($sock);
	close (outputfile);
}

sub prntfeatures 
{

	($release,$package,$features,$myfile,$domain)=@_;
	
  $release =~ s/\\//sg;	
	
 if ($newtdformat) {
  $package =~ s/backlog//sgi;
  print $myfile " $release, $domain, $package, $myfeat\n";
  
 } else {
		
	$features = $features."<dt";

	

	while ( $features =~ /dt\>(.*?)\<\/dt(.*?)\<dt/sg  ){
		$myfeat = $1;
		$subfeat =$2;
		
		$myfeat =~ s/\n/ /sg;
		
		pos($features) = pos($features) -2;
		
		$mystr="";
		while ( $subfeat =~ /\<dd\>(.*?)\<\/dd\>/sg) {
			$mysubfeat = $mysubfeat.$mystr.$1;
			$mystr = " & ";
		}
		undef $mystr;
	$mysubfeat =~ s/,/ /sg;
	$mysubfeat =~ s/\n//sg;
	$mysubfeat =~ s/\<.*?\>//sg;
	

	print $myfile " $release, $domain, $package, $myfeat, $mysubfeat\n";
	
	$mysubfeat = "";	
	}
		
 }
}
	
sub loadfile
{

	$/ = " ";
	#arguments
	($myfile)=@_;
	open ( inputfile, "<".$myfile);
	my $contents = do { local $/;  <inputfile> };
	close(inputfile);
	return $contents;

}

sub td_roadmap
{


	#arguments
	($infile,$outfile,$domain,@releases)=@_;

	
	$roadmap=loadfile $infile;
	open ( outputfile, ">>".$outfile);


  if ($newtdformat) {
       print "Processing new TD roadmap format\n";
         if ($roadmap =~ m /Contents\<\/h2\>.*?\<\/table/sg) { $roadmap =$';}
         foreach (@releases) {
          $exp=$_." Roadmap";
		         
           if ($roadmap =~ m /($exp)/sg) { 
			     print "PASS - Found entry for $_ \n";
			     $relroad =$';	
			
			     if ($roadmap =~ m /table\>(.*?)\<\/table/sg) { $relroad =$1;}
			           
           while ($relroad =~ m/title\=\"(.*?)\"\>(.*)/g) {
                 $package=$1;
                 $myfeat=$2;
                 $myfeat=~ s/\<\/td\>\<td\>/-/sg;   #TODO change - to , when the old format is dead
                 $myfeat=~ s/\<.*?\>//sg;
                 prntfeatures($_,$package,$myfeat,outputfile,$domain);
                
                 }  		     
         }
        }
  } else {

	 foreach (@releases) {
		
	 	$exp="\\<h2\\>.*?\\>".$_;
		  
		if ($roadmap =~ m /($exp)/sg) { 
			print "PASS - Found entry for $_ \n";
			$relroad =$';	
			
			if ($relroad =~ m /(.*?)\<h2/sg) { $relroad =$1;}
			$i=0;	
			while ($relroad=~ m/\<h3\>.*\>(.*?)\<.*<\/h3/g) {
				$package = $1;		
				$ppos[$i]= pos($relroad);
				$pname[$i]= $package;
				$i++;
			}
			for ( $i=0;$i<($#ppos); $i++){
				$features= substr ($relroad, $ppos[$i],$ppos[$i+1]-$ppos[$i]);
				prntfeatures($_,$pname[$i],$features,outputfile,$domain);
			}
			$features= substr ($relroad, $ppos[$i]);
		
			prntfeatures($_,$pname[$i],$features,outputfile,$domain);
			@ppos ="";
			@pname ="";
			undef ($features);
		}
	}		 	

	}
	
	

	close (outputfile);


}


sub parse_category {

	#arguments
	($infile)=@_;

	my @mylink;

	$mypage=loadfile $infile;
	$i=0;	
	if ( $mypage =~ m/Pages in category(.*)\<\/table/sg) {
		print "INFO - Category page found\n";
		$mypage = $1;
		while ($mypage =~ m /\<a href\=\"(\/wiki\/index\.php\/.*?)\"/g) {
			
			$mylink[$i] = $1;	
			$i++;
			
		}
	print "INFO - Found $i items in the category page\n"
	}
	return @mylink;
}

sub parse_bklog {
	
	#arguments
	($infile,$outfile,$id)=@_;
	$mypkg=loadfile $infile;
	#list if the bklog has been ported to the new bugzilla based format
  $headerformat= "wiki_format";
	
	open ( outputfile, ">>".$outfile);
	open ( soutputfile, ">>"."summary_".$outfile);
	
	if ($mypkg =~ m/index\.php\/(.*?) HTTP/sg) {
  
		$pagename = $1;
		print "INFO -Processing Package $pagename \n";
		$i=0;
		if ($mypkg =~m/class\=\"bugzilla sortable\"/sg ) { $headerformat="autobug_format"; }
		
		while ($mypkg =~ m/\<tr.*?\>(.*?)\<\/tr/sg) { 
			$myheader= $&;
      if ($myheader =~ m/style=\"background-color\:/sg) {
        if ($myheader =~ m/Bug ID/sg) { $headerformat="bugzilla_format";}
        next;
      }
			$myfeat= $1;
			$myfeat =~ s/\<\/td\>/\t/sg;
			$myfeat =~ s/\<.*?\>//sg;
			$myfeat =~ s/\n//sg;
			
			
			if ($myfeat =~ m/[A-z]/sg and not $myfeat =~ m/\&lt\;etc/sg and 
			not $myfeat =~ m/\&lt\;Feature/sg and not $myfeat =~ m/Item not available/sg) {
				print outputfile "$pagename\t$myfeat\n";
				$i++;
			}
			
		}

	print soutputfile "$id\t$pagename\t$i\t$headerformat\thttp://developer.symbian.org/wiki/index.php/$pagename\n";
	

	}

	close (outputfile);
	close (soutputfile);


}




#help print
sub printhelp
{

	print "\n\n version 0.6
	\ngettd.pl -t=url -d=domain \n\nRequired parameters for Technology Roadmaps:\n\t -t url containing the technology domain roadmap\n\t -d the technology domain name
	\n\nOptional Parmeters for Technology Roadmaps\n\t-new if the roadmap has the new wiki format
  \n\nRequired Parameters for Package backlogs\n\t-p for package backlog analysis. just run gettd.pl -p
  \n\nOptional Pararmeters for Package backlogs\n\t -compare [f1] [f2] compares two package summary files for changes ignores order
  \n\nCommonOptional parameters\n\t-o filename ,the output is logged into the output.csv file by default\n\t-h for help
	\n\t recommend to run under cygwin environment and perl version v5.10.0 \n";
	exit;
}



#compare bklogs
sub compare_bklogs {
	#arguments
	(@bklogs)=@_;
	
	if (not $#bklogs == 1) { printhelp;}

	
	$cmd ="cut -f 2,3 ". $bklogs[0] . " | sort -u > tmp1.txt";
	
	system($cmd);
	
	$cmd ="cut -f 2,3 ". $bklogs[1] . " | sort -u > tmp2.txt";
	system($cmd);
	
	exec ("diff tmp1.txt tmp2.txt | grep '[<|>]'");
	system("rm temp*.txt");
	
	exit;

}




#process command line options
sub cmd_options
{

  my $help;
  my @compare;


  GetOptions('h' => \$help,'t=s'=> \$target_url, 'd=s' => \$tdomain , 'o=s' => \$csvfile, 
	'a' => \$authon , 'p' => \$ispackage, 'compare=s{2}' =>\@compare, 'new' => \$isnewformat);

  if (@compare) {
	compare_bklogs @compare;
	
  }

  if ($help) {
    printhelp;
  }


 if ($ispackage) {

 	$tdomain =" ";
	$target_url = "http://developer.symbian.org/wiki/index.php/Category:Package_Backlog";
	
 }  
 if ($isnewformat){
    $newtdformat = 1;
 
 }

 if ( not $target_url) {

	print "ERROR-missing arguments target url\n";
	printhelp;	
  } 


 if (not $tdomain){
	print "ERROR-missing arguments domain level\n";
	printhelp;
 }

 	print "\nINFO-downloading $target_url with label $tdomain\n";
  

 if (not $csvfile) {
	if (not $ispackage) { 
		$csvfile="output.csv";
		
	} else {
		$csvfile="output.txt";
		system ("rm *output.txt");
	
	}
 }
 print "\nINFO-output recorded in $csvfile \n";

                                      

}
#main
$/ = " ";
$host1 = "developer.symbian.org";

cmd_options();

if ($authon) {
	#file containing login details from http cookie
	$mycookie = loadfile("mycookie.txt");

	$auth = "Cookie: " . $mycookie ;
}


if ($ispackage) {
	getpage($target_url, $host1, $auth, "debug.txt");
	@bklog = parse_category("debug.txt");
	$j=0;
	
	foreach (@bklog) {
		getpage("http://".$host1.$_, $host1, $auth, "pkg".$j.".txt");
		parse_bklog ("pkg".$j.".txt",$csvfile, $j);
		$j++;
		
	

	}

} else {

	#foundation releases - add as required
	@releases=("Symbian\\^2","Symbian\\^3","Symbian\\^4");

	getpage($target_url, $host1, $auth, "debug.txt");
	td_roadmap("debug.txt" , $csvfile, $tdomain ,@releases);
}