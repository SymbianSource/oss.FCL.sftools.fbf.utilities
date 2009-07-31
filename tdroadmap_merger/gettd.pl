#!/usr/bin/perl

 

use IO::Socket; 
use Getopt::Long;


my $target_url; #target url for the roadmap
my $tdomain; #tag for the domain to be use in csv file
my $csvfile; #output csv file name
my $authon= '';	 #does it require authorisation? default is false

my $ispackage;

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
	($infile,$outfile)=@_;
	$mypkg=loadfile $infile;
	open ( outputfile, ">>".$outfile);
	open ( soutputfile, ">>"."summary_".$outfile);
	
	if ($mypkg =~ m/index\.php\/(.*?) HTTP/sg) {

		$pagename = $1;
		print "INFO -Processing Package $pagename \n";
		$i=0;
		#while ($mypkg =~ m/\<tr\>\<td\>(.*?)\<\/td\>/g) {
		while ($mypkg =~ m/\<tr\>(.*?)\<\/tr/sg) {
			$i++;
			$myfeat= $1;
			$myfeat =~ s/\<\/td\>/\t/sg;
			$myfeat =~ s/\<.*?\>//sg;
			$myfeat =~ s/\n//sg;
			print outputfile "$pagename\t$myfeat\n";
			
		}

	print soutputfile "$pagename\t$i\n";
	
	}




}

#help print
sub printhelp
{

	print "\n\n version 0.3 
	\ngettd.pl -t=url -d=domain \nrequired parameters:\n\t -t url containing the technology domain roadmap\n\t -d the technology domain name
	\n Optional parameters\n\t-o filename ,the output is logged into the output.csv file by default\n\t-h for help
	\n\t-a setup authorisation by cookie follow instructions in http://developer.symbian.org/wiki/index.php/Roadmap_merger_script#Cookies";
	exit;
}


#process command line options
sub cmd_options
{

  my $help;


  GetOptions('h' => \$help,'t=s'=> \$target_url, 'd=s' => \$tdomain , 'o=s' => \$csvfile, 'a' => \$authon , 'p' => \$ispackage);

  if ($help) {
    printhelp;
  }

 if ($ispackage) {

 	$tdomain =" ";
	$target_url = "http://developer.symbian.org/wiki/index.php/Category:Package_Backlog";
	
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
	$i=0;
	foreach (@bklog) {
		getpage("http://".$host1.$_, $host1, $auth, "pkg".$i.".txt");
		parse_bklog ("pkg".$i.".txt",$csvfile);
		$i++;
		
	

	}

} else {

	#foundation releases - add as required
	@releases=("Symbian\\^2","Symbian\\^3","Symbian\\^4");

	getpage($target_url, $host1, $auth, "debug.txt");
	td_roadmap("debug.txt" , $csvfile, $tdomain ,@releases);
}