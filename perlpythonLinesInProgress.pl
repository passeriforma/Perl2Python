#!/usr/bin/perl -w

use strict;

my $whitespaceCounter = 0; #global variable? Its outside the loop...

while (my $line = <>) {

	#NOTE: Deal with semicolons on a line by line basis

#print whitespace, if relevant
#	for ($x=0; $x<$whitespaceCounter; $x++) {
#		print ' ';
#	}

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
			&whitespacePrinter($whitespaceCounter);
			print "print $printInput\n";
		} else { #there is no variable (or many, which currently kill everything)
			&whitespacePrinter($whitespaceCounter);
			print "print \"$printInput\"\n";
		}

#print statment with no newline
	} elsif ($line =~ /^\s*print\s*"(.*)"[\s;]*$/) { 
		my $printInput = $1;
		if ($printInput =~ /^(.*)\s*\$(.*)*$/) { #there is ONE variable
			&whitespacePrinter($whitespaceCounter);			
			$printInput =~ s/\$//; #removes variable signal
			print "sys.stdout.write($printInput)\n";
		} else { #there is no variable (or many, which currently kill everything)
			&whitespacePrinter($whitespaceCounter);
			print "sys.stdout.write(\"$printInput\")\n";
		}

#break/continue	
	} elsif ($line =~ /^\s*last;$/) {
		&whitespacePrinter($whitespaceCounter);
		print "break\n";

	} elsif ($line =~ /^\s*next;$/) {
		&whitespacePrinter($whitespaceCounter);
		print "continue\n";

#arithmetic operations
	} elsif ($line =~ /^\s*[^\s]*\s*=(.*);$/) {
#		print $line;
		&whitespacePrinter($whitespaceCounter);
		&arithmeticLines($line);

# ++ and --
	} elsif ($line =~ /^\s*(.*)\s*\+\+(.*);$/) { 
		# change ++ and -- to python equivalents
		&whitespacePrinter($whitespaceCounter);
		my $plusPlus = $1;
		$plusPlus =~ s/\$//;
		print "$plusPlus +=1\n";
	} elsif ($line =~ /^\s*(.*)\s*\-\-(.*);$/) {
		&whitespacePrinter($whitespaceCounter);
		my $minusMinus = $1;
		$minusMinus =~ s/\$//;
		print "$minusMinus -= 1\n";

#for loops (If in C style then no direct comparison)?

#while loops
	} elsif ($line =~ /^\s*(.*)\s*while\s*\((.*)\)(.*)\s*$/) {
		my $whileCondition = $2;
		&whitespacePrinter($whitespaceCounter);		
		print "while ";
		&arithmeticLines($whileCondition);
		print ":\n";
		$whitespaceCounter ++;

# elsif 
	} elsif ($line =~ /^\s*(.*)\s*elsif\s*\((.*)\)(.*)\s*$/) {
		#remember to remove } if present
		#becomes elif
		my $elsifCondition = $2;
		&whitespacePrinter($whitespaceCounter-1);
		print "elif ";					#so, so frustratingly messy :/
		&arithmeticLines($elsifCondition);
		print ":\n";

#if statements
	} elsif ($line =~ /^\s*(.*)\s*if\s*\((.*)\)(.*)\s*$/) {
		my $ifCondition = $2;
		&whitespacePrinter($whitespaceCounter);
		print "if ";					#ugh this is messy :/
		&arithmeticLines($ifCondition);
		print ":\n";
		$whitespaceCounter ++;

#else
	} elsif ($line =~ /^\s*(.*)\s*else\s*(.*)\s*$/) {
		#remember to remove } if present
		&whitespacePrinter($whitespaceCounter-1);
		print "else:\n";;

#end curly brace needs removal
	} elsif ($line =~ /^\s*}\s*$/) {
		$line =~ s/\}/ /;
		$whitespaceCounter --;

#substitution using s/// (UNTESTED AS YET)
	} elsif ($line =~ /^\s*(.*)\s*s\/(.*)\/(.*)\/g(.*)\s*;$/) {
		my $replaced = $2;
		my $replaceWith = $3;
		print "re.compile('$replaced').sub('$replaceWith', s)"

#looping through STDIN
	} elsif ($line =~ /^\s*while\s*\(\<STDIN\>\)\s*(.*)\s*$/) {
		&whitespacePrinter($whitespaceCounter);
		print "import sys";
		&whitespacePrinter($whitespaceCounter);
		print "for line in sys.stdin:"; 

# Lines we can't translate are turned into comments
	} else { 
		print "#$line\n";
	}

}
sub arithmeticLines { 
#things for non interesting lines; to be called as a sub just before the untranslatables
	#removes $ before variables
	$_[0] =~ s/\$//g;

	#and/or/not
	$_[0] =~ s/\&\&/and /g;
	$_[0] =~ s/\|\|/or /g;
	$_[0] =~ s/!\s/not /g;

#comparison operators that dont exist in Python
	$_[0] =~ s/eq /\=\=/g;
	$_[0] =~ s/ne /!=/g;
	$_[0] =~ s/gt />/g;
	$_[0] =~ s/lt /</g;
	$_[0] =~ s/ge />=/g;
	$_[0] =~ s/le /<=/g;	

#division
	$_[0] =~ s/\//\/\//g;

#remove that semicolon
	$_[0] =~ s/\;//;
	print $_[0];
}

sub whitespacePrinter {
	my $whitespace = $_[0];
	for (my $x = 0; $x < $whitespace; $x ++) {
		print '   ';
	}
}

