#!/usr/bin/perl -w

use strict;

while (my $line = <>) {

	#individual cases, to be weeded out first in their entirety

	if ($line =~ /^#!/ && $. == 1) { # translate #! line 
		print "#!/usr/bin/python2.7 -u\n";
	} elsif ($line =~ /^\s*#/ || $line =~ /^\s*$/) { # Blank & comment lines (unchanged)
		print $line;
	#loops, if and while statments are special cases
	} elsif ($line =~ /^\s*print/ && $. == 1) { #line is a print statement
		#normal print statements with newlines (no variables)
			print $line;
		#print statements without newlines (no variables)
		#print statements with newlines and variables
			#variables go from $n => str(n)
		#print statments with no newlines and variables
	} else { # Lines we can't translate are turned into comments
		print "#$line\n";
	}


	#removes $ before variables
	$line =~ s/\$//g;
	# change ++ and -- to python equivalents
	$line =~ s/\+\+/\+\=1/g;
	$line =~ s/\-\-/\-\=1/g;
	#and/or/not
	$line =~ s/\&\&/and/g;
	$line =~ s/\|\|/or/g;
	$line =~ s/!\s/not/g;


}

