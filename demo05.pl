#!/usr/bin/perl -w

#tests array initialisation, push, pop, shift and unshift

@a = (6, 7, 8, 9);

push @a, 9;
pop @a;
unshift @a, 5;
shift @a;

split(/\s+/, "do re mi fa");

#should probably rejig this in a bit to make it more 'relevant'
