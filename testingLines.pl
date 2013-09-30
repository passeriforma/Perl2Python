#!/usr/bin/perl -w

use strict;

while (my $line = <>) {

	#NOTE: Deal with semicolons on a line by line basis

#	&whitespaceStack(&stateStack); #I think that this works?

	if ($line =~ /^#!/ && $. == 1) { # translate #! line 
		print "#!/usr/bin/python2.7 -u\n";

	} elsif ($line =~ /^\s*#/ || $line =~ /^\s*$/) { # Blank & comment lines (unchanged)
		print $line;

	} elsif ($line =~ /^\s*print\s*"(.*)"[\s;]*$/) { #print statment with no newline
			print "sys.stdout.write(\"$1\")"; #THIS IS NOT WORKING??? WHY U NO MATCH?

	} else { # Lines we can't translate are turned into comments
		print "#$line\n";
	}
}
