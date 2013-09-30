#!/usr/bin/perl -w

use strict;

while (my $line = <>) {

	#NOTE: Deal with semicolons on a line by line basis

#	&whitespaceStack(&stateStack); #I think that this works?

	if ($line =~ /^#!/ && $. == 1) { # translate #! line 
		print "#!/usr/bin/python2.7 -u\n";

	} elsif ($line =~ /^\s*#/ || $line =~ /^\s*$/) { # Blank & comment lines (unchanged)
		print $line;

	} elsif ($line =~ /^\s*print\s*"(.*)\\n"[\s;]*$/) { #print statement with newline
			print "print \"$1\"\n";
			# "

	} elsif ($line =~ /^\s*print\s*"(.*)"[\s;]*$/) { #print statment with no newline
			print "sys.stdout.write(\"$1\")\n";
			# "

	} elsif ($line =~ /^\s*[^\s]*\s*=(.*);$/) { #arithmetic operations
#		print $line;
		&arithmeticLines($line);
	
	} elsif ($line =~ /^\s*[^\s]*\s*(break)(.*);$/ || $line =~ /^\s*[^\s]*\s*(continue)(.*);$/) { #break/continue
		print "$1"
	} else { # Lines we can't translate are turned into comments
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
	print "$_[0]\n";
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

