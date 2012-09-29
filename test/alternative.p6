#!/usr/bin/env perl6
###############################################################################
#
# Test script using raw HTTP responses, and its own request loop.
#
###############################################################################
use SCGI;

my $scgi = SCGI.new( :port(8118), :!PSGI );

say "Starting raw SCGI server.";

while (my $connection = $scgi.accept())
{
  my $request = $connection.request;
  if $request.success
  {
    my $name = $request.env<QUERY_STRING> || 'World';
    $connection.send("Content-type: text/plain\n\nHello $name\n");
  }
  $connection.close;
}

