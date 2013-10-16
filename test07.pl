#!/usr/bin/perl -w

#tests implementation of foreach with commandline arguments

foreach $i (0..$#ARGV) {
   print "This input is called $ARGV[$i]\n";
}
