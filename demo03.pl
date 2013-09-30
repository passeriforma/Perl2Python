#!/usr/bin/perl -w

#tests a couple of things; prints with/without newlines and with only a variable
#also if/elsif/else statements

$a = 12;
$b = 2;

$c = $a + $b / $b;

if ($c != 0 && $a < 0) {
	print "Not right. No value for you.\n";
} elsif ($a > 20) {
print "This program should correct my incorrect syntax here.";
} else {
	print "$c"
}
