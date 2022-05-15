use SCGI::Connection;

unit class SCGI:auth<zef:raku-community-modules>:ver<2.5>;

has Int $.port = 8118;
has Str $.addr = 'localhost';
has     $.socket;

has $.NPH  = False;   ## Set to true to use NPH mode (not recommended.)

has $.PSGI  = False;  ## Include PSGI Classic Headers.
has $.P6SGI = True;   ## Include default P6SGI Headers.
                      ## If neither of those is used, assume raw HTTP headers.

has $.debug  = False; ## Set to true to debug stuff.
has $.strict = True;  ## If set to false, don't ensure proper SCGI.

has $.multithread = False; ## Set to true for asynchronous concurrent requests.

method version() { self.^ver }

method connect(:$port = $.port, :$addr = $.addr) {
    $!socket := IO::Socket::INET.new(
        :localhost($addr), 
        :localport($port), 
        :listen
    )
}

method accept() {
    self.connect without $.socket;
    $*ERR.say: "Waiting for connection." if $.debug;

    my $connection := $.socket.accept() or return;
    if $.debug {
        $*ERR.say: "connection family is $connection.family()";
        $*ERR.say: "connection proto is $connection.proto()";
        $*ERR.say: "connection type is $connection.type()";
    }
    SCGI::Connection.new(:socket($connection), :parent(self))
}

method handle(&closure) {
    if $.debug {
        if $!socket {
            $*ERR.say: "socket family is $.socket.family()";
            $*ERR.say: "socket proto is $.socket.proto()";
            $*ERR.say: "socket type is $.socket.type()";
        }
        else {
            $*ERR.say: "No socket yet";
        }
    }
    $*ERR.say: "[{time}] SCGI is ready and waiting ($!addr:$!port)";

    loop {
        my $connection := self.accept or last;
        if $.debug {
            $*ERR.say: "Doing the loop";
        }

        my $request = $connection.request;
        if $request.success {
            my %env = $request.env;
            if $!multithread {
                my $s = Supplier.new;

                start {
                    $s.emit: closure(%env);
                    $s.done;
                }

                $s.Supply.tap: -> $return {
                    $connection.send: $return;
                    $connection.close;
                }

            }
            else {
                my $return = closure(%env);
                $connection.send: $return;
                $connection.close;
            }
        }
        else {
          $connection.close;
        }
    }
}

method shutdown() {
    exit;
}

=begin pod

=head1 NAME

SCGI - A SCGI library for Raku

=head1 DESCRIPTION

This is a simple SCGI library for Raku.

It's main influences are the Perl SCGI library, and the
Raku HTTP::Daemon library.

It offers a bit of candy coating compared to the Perl version.

By default is uses a PSGI-compliant interface, but can also handle
raw HTTP responses.

You don't need to create your own C<IO::Socket::INET> object.
Just pass an 'addr' and 'port' attribute to the new() declaration and it'll
create the object for you.

=head1 USAGE

The simplest (and recommended) form of usage is to use the handle() method
with PSGI-compliant output. Here's an example:

=begin code :lang<raku>

use SCGI;

my $scgi = SCGI.new( :port(8118) );

sub handler(%env) {
    my $name    = %env<QUERY_STRING> || 'world';
    my $status  = '200';
    my @headers = 'Content-Type' => 'text/plain';
    my @body    = "Hello $name\n";
    @headers.push: 'Content-Length' => @body.join.encode.bytes;
    [ $status, @headers, @body ]
}

$scgi.handle: &handler;

=end code

There are other ways of using SCGI, such as writing your own run loop,
or using a raw HTTP output instead of PSGI. Here's an example doing both:

=begin code :lang<raku>

use SCGI;

my $scgi = SCGI.new( :port(8118), :!PSGI, :!P6SGI );
while my $connection = $scgi.accept() {
    my $request = $connection.request;
    if $request.success {
        my $name    = $request.env<QUERY_STRING> || 'world';
        my $return  = "Hello $name\n";
        my $len     = $return.encode.bytes;
        my $headers = "Content-Type: text/plain\nContent-Length: $len\n";
        $connection.send("$headers\n$return");
    }
    $connection.close;
}

=end code

Test script representing both examples can be found in the 'examples' folder.

If you are serious about using SCGI for web application development, see
the L<Web|https://github.com/raku-community-modules/Web/> library set,
or one of the full blown frameworks built using it.

=head1 CONFIGURATION

=head2 nginx

Make sure you compiled nginx with the SCGI plugin (it is included by default.)
Then, in one of your server blocks, add a location mount:

=begin code :lang<nginx>

location /scgi/ {
    scgi_pass 127.0.0.1:8118;
    include scgi_params;
    # Optionally rewrite document URI path
    rewrite ^/scgi/(.*) /$1 break;
    # Some applications may need rewritten URI in PATH_INFO
    scgi_param PATH_INFO $uri;
}

=end code

=head2 lighttpd

First, make sure the SCGI library is being loaded.

=begin code :lang<lighttpd>

server.modules += ( "mod_scgi" )

=end code

Next, set up an SCGI handler:

=begin code :lang<lighttpd>

scgi.server = (
    "/scgi" =>
    ((
      "host" => "127.0.0.1",
      "port" => 8118,
      "check-local" => "disable"
    ))
)

=end code

=head2 Apache 2 with mod_scgi:

Add the following line to your site config, changing the details to match your
SCGI script configuration:

=begin code :lang<apache>

SCGIMount /scgi/ 127.0.0.1:8118

=end code

=head2 Apache 2 with mod_proxy_scgi:

Add the following line to your site config, changes the details to match your
SCGI script configuration:

=begin code :lang<apache>

<Proxy *>
    Order deny,allow
    Allow from all
</Proxy>
ProxyPass /scgi/ scgi://localhost:8118/

=end code

=head1 AUTHOR

Timothy Totten

=head1 COPYRIGHT AND LICENSE

Copyright 2013 - 2017 Timothy Totten

Copyright 2018 - 2022 Raku Community

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod

# vim: expandtab shiftwidth=4
