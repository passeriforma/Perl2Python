#!/usr/bin/perl -w
# written by andrewt@cse.unsw.edu.au as a COMP2041 lecture example

#tests simple STDIN use

$number = 0;
while ($number >= 0) {
   print "Enter number:\n";
   $number = <STDIN>;
   if ($number >= 0) {
       if ($number % 2 == 0) {
           print "Even\n";
       } else {
           print "Odd\n";
       }
   }
}
