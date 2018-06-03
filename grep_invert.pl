#!/bin/perl -n
# circumvent docker bug "unknown shorthand flag 'v'" when piping into grep -ev

print unless /(Preparing|Waiting)/