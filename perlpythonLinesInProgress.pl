#!/usr/bin/perl -w

use strict;

while (my $line = <>) {

	#NOTE: Deal with semicolons on a line by line basis

#	&whitespaceStack(&stateStack); #I think that this works?

# translate #! line 
	if ($line =~ /^#!/ && $. == 1) {
		print "#!/usr/bin/python2.7 -u\n";

 # Blank & comment lines (unchanged)
	} elsif ($line =~ /^\s*#/ || $line =~ /^\s*$/) {
		print $line;

 #print statement with newline
	} elsif ($line =~ /^\s*print\s*"(.*)\\n"[\s;]*$/) {
		my $printInput = $1;
		if ($printInput =~ /^(.*)\s*\$(.*)*$/) { #there is ONE variable
			$printInput =~ s/\$//; #removes variable signal
			print "print $printInput\n";
		} else { #there is no variable (or many, which currently kill everything)
			print "print \"$printInput\"\n";
		}

#print statment with no newline
	} elsif ($line =~ /^\s*print\s*"(.*)"[\s;]*$/) { 
		my $printInput = $1;
		if ($printInput =~ /^(.*)\s*\$(.*)*$/) { #there is ONE variable
			$printInput =~ s/\$//; #removes variable signal
			print "sys.stdout.write($printInput)\n";
		} else { #there is no variable (or many, which currently kill everything)
			print "sys.stdout.write(\"$printInput\")\n";
		}

#arithmetic operations
	} elsif ($line =~ /^\s*[^\s]*\s*=(.*);$/) {
#		print $line;
		&arithmeticLines($line);
#		print "$lineToPrint\n";

#break/continue	
	} elsif ($line =~ /^\s*[^\s]*\s*(break)(.*);$/ || $line =~ /^\s*[^\s]*\s*(continue)(.*);$/) {
		print "$1"

#for loops

#while loops

#if statements
	} elsif ($line =~ /^\s*(.*)\s*if\s*\((.*)\)(.*)\s*$/) {
		my $condition = $2;
		print "if ";
		&arithmeticLines($condition);
		print ":\n";

# elsif 

#else
#	} elsif ($line =~ /^$/

#end curly brace needs removal
	} elsif ($line =~ /^\s*(.*)\s*\}\s*\((.*)\)(.*);$/) {
		$line =~ s/\}//;

# Lines we can't translate are turned into comments
	} else { 
		print "#$line\n";
	}

}
sub arithmeticLines { 
#things for non interesting lines; to be called as a sub just before the untranslatables
	#removes $ before variables
	$_[0] =~ s/\$//g;
	# change ++ and -- to python equivalents
	$_[0] =~ s/\+\+/\+\=1/g;
	$_[0] =~ s/\-\-/\-\=1/g;
	#and/or/not
	$_[0] =~ s/\&\&/and/g;
	$_[0] =~ s/\|\|/or/g;
	$_[0] =~ s/!\s/not/g;

	$_[0] =~ s/\;//;
	print $_[0];
}

#WHERE IN THE PROCESS DO I DO THESE? Before every line needs an update, yeah?

sub stateStack {
	if ($_[0] =~ /^\s*[^\s]*\s*if(.*)/ || $_[0] =~ /^\s*[^\s]*\s*for(.*)/ || $_[0] =~ /^\s*[^\s]*\s*while(.*)/) {
		#push onto the stack
	} elsif ($_[0] =~  /^\s*\}(.*)$/) {
		#pop from the stack
	}
}

sub whitespaceStack {
	#prints size of stack in whitespace

}

