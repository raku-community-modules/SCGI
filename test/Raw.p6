#!/usr/bin/env perl6

use SCGI;

my $scgi = SCGI.new( :port(8118), :!PSGI );

my $handler = sub (%env) {
    my $name = %env<QUERY_STRING> || 'World';
    return "Content-type: text/plain\n\nHello $name\n";
}

$scgi.handle: $handler;

