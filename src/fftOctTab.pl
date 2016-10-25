#! /usr/bin/perl

$e = 1.3915;

$sum = 0;
$count = 0;

for ($i=0; $i < 16; $i++) {
        printf "%2d  ", $i;
        $n = $e ** $i;
        printf "%6.2f  ", $n;

        $d = int($n + 0.5);
        printf "%3d  ", $d;

        $sum += $n;
        printf "%6.2f  ", $sum;

        printf "%3d ", $count;
        $count += $d - 1;
        printf "%3d ", $count;
        $count++;

        print "\n";
}
