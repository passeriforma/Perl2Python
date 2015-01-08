#!/usr/bin/perl -w

#taken from the 2041 website
#tests foreach loops and printing ARGV

foreach $i (0..$#ARGV) {
    print "$ARGV[$i]\n";
}
