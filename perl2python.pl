#!/usr/bin/perl -w

use strict

my @stateStack;
my @whitespaceStack;

#things that are the same: arithmetic operators, comparisons e.g =, bitwise operators, break/continue

#read input
while (my $line = <>) {

	if ($line =~ /^#!/ && $. == 1) { # translate #! line 
		print "#!/usr/bin/python2.7 -u\n";
	} elsif ($line =~ /^\s*#/ || $line =~ /^\s*$/) { # Blank & comment lines (unchanged)
		print $line;
	} elsif ($line =~ /^\s*print\s*"(.*)\\n"[\s;]*$/) { #print with newline
		if ($line =~ /$/ || $line =~ /@/ || line = /%/) { #variables are being used in the statement
			#I DONT EVEN KNOW WHAT I NEED TO DO HERE
		} else {
		#delete \n; automatic in python
		print "print ("$1")";	
		}
	} elsif ($line =~ /^\s*print\s*"(.*)"[\s;]*$/) { #print without newline
		print "sys.stdout.write("$1")";
	} else { # Lines we can't translate are turned into comments
		print "#$line\n";
	}

	#These ones dont really need if statements, they should happen on top of the other things and regardless

	#removes $ before variables
	$line =~ s/\$//g;
	# change ++ and -- to python equivalents
	$line =~ s/\+\+/\+\=1/g
	$line =~ s/\-\-/\-\=1/g
}





sub stateStack {
	#if, else, while, for (any loops etc) are pushed on
#	if ($line =~ )
	#they call another sub 
	# if close } they are popped
	if ($line =~ /{/ == 1) { #there exists a close bracket
		pop @stack;
	}
}

sub whitespaceStack {
	#how big is the array? this tells us how many indents to go with
}
