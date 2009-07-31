#!/usr/bin/perl

 

use IO::Socket; 
use Getopt::Long;


my $target_url;
my $tdomain;
my $csvfile;

sub getpage
{
	#arguments
	($page,$host,$auth,$myfile)=@_;
	
	
	#output file
	open ( outputfile, ">".$myfile);
	
	
	$port = "http(80)";
	$getmess = "GET " . $page ." HTTP/1.1\n" . $auth;

	print "sending message - $getmess\n";
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
	
	$release =~ s/\\//sg;	
	print $myfile " $release, $domain, $package, $myfeat, $mysubfeat\n";
	
	$mysubfeat = "";	
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



	foreach (@releases) {
		
		$exp="\\<h2\\>.*?\\>".$_;
		
		if ($roadmap =~ m /($exp)/sg) { 
			print "Found entry for $_ \n";
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
	
	

	close (outputfile);


}


#help print
sub printhelp
{

	print "\n\n version 0.2 
	\ngettd.pl -t=url -d=domain \nrequired parameters:\n\t -t url containing the technology domain roadmap\n\t -d the technology domain name
	\n Optional parameters\n\t-o filename ,the output is logged into the output.csv file by default\n\t-h for help";
	exit;
}


#process command line options
sub cmd_options
{


  my $help;


  GetOptions('h' => \$help,'t=s'=> \$target_url, 'd=s' => \$tdomain , 'o=s' => \$csvfile);

  if ($help) {
    printhelp;
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
	$csvfile="output.csv";
 }
 print "\nINFO-output recorded in $csvfile \n";
        



}
#main
$/ = " ";

#file containing login details from http cookie
$mycookie = loadfile("mycookie.txt");

#$auth ="Authorization: Basic Zm91bmRhdGlvbjp0ZXN0MA==";
$auth = "Cookie: " . $mycookie ;

#foundation releases - add as required
@releases=("Symbian\\^2","Symbian\\^3","Symbian\\^4");


$host1 = "developer.symbian.org";


cmd_options();

getpage($target_url, $host1, $auth, "debug.txt");
td_roadmap("debug.txt" , $csvfile, $tdomain ,@releases);
