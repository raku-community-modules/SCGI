#!/usr/bin/env perl6

BEGIN { @*INC.push: './lib'; }

use SCGI;

my $scgi = SCGI.new( :port(8118), :strict );

my $handler = sub (%env) {
    my $name = %env<QUERY_STRING> || 'World';
    return "Content-type: text/plain\n\nHello $name\n";
}

$scgi.handle: $handler;

