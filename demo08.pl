#!/usr/bin/perl -w

#tests split and join and concatenation

$info = "Caine:Michael:Actor:14, Leafy Drive";

@personal = split(/:/, $info);

print "@personal\n"
