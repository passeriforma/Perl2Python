#!/usr/bin/perl -w

#taken from the 2041 site

$n = 1;
while ($n <= 10) {
    $total = 0;
    $j = 1;
    while ($j <= $n) {
        $i = 1;
        while ($i <= $j) {
            $total = $total + $i;
            $i = $i + 1;
        }
        $j = $j + 1;
    }
    print "$total\n";
    $n = $n + 1;
}
