#!/usr/bin/perl -w

$a = 12;
$b = 2;

$c = $a + $b / $b;

if ($c != 0 && $a < 0) {
	print "Not right. No value for you.\n";
} else {
	print "$c"
}
