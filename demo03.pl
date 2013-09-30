#!/usr/bin/perl -w

$a = 12;
$b = 2;

$c = $a + $b / $b;

if ($c != 0 && $a < 0) {
	print "Where is your logic?\n";
} else {
	print "the value of c is $c.\n"
}
