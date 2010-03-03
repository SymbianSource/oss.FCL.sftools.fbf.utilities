UH PARSER for Raptor

This parser reads one or more Raptor log files, extracts the interesting bits
and puts them into a set of HTML files, making it easy to spot the failures and
see the related log snippets.

Use as shown below:

perl uh.pl FILE1 FILE2 ...

where the FILEs are the output of a Raptor build i.e. sbs <your args> -f FILE

After running the tool the summary HTML file will be located at html/index.html

More information on the tools can be obtained with the --help option.
