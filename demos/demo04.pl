#!/usr/bin/perl -w

#modified from answer6 taken from the 2041 site
#tests while loops, break and continue, as well as ++

$answer = 0;
while ($answer < 36) {
    $answer = $answer + 7;
	if ($answer == 9) {
		$answer ++;
		last;
	} else {
		next;
	}
}
print "$answer\n";
