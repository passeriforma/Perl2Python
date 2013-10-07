#!/usr/bin/perl -w

#adapted from cookie, on the 2041 website

while (1) {
    print "Give me cookie\n";
    $line = <STDIN>;
    chomp $line;
    if ($line eq "cookie") {
        last;
    }
}
print "Thank you\n";
