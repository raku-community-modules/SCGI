#!/usr/bin/env perl6

BEGIN { @*INC.push: './lib'; }

use SCGI;

my $scgi = SCGI.new( :port(8118), :!strict, :PSGI, :debug );

my $handler = sub (%env) {
    my $name = %env<QUERY_STRING> || 'World';
    my $status = '200';
    my @headers = [ 'Content-Type' => 'text/plain' ];
    my @body = [ "Hello $name\n"; ];
    return [ $status, @headers, @body ];
}

$scgi.handle: $handler;

