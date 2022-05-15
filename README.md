[![Actions Status](https://github.com/raku-community-modules/SCGI/actions/workflows/test.yml/badge.svg)](https://github.com/raku-community-modules/SCGI/actions)

NAME
====

SCGI - A SCGI library for Raku

DESCRIPTION
===========

This is a simple SCGI library for Raku.

It's main influences are the Perl SCGI library, and the Raku HTTP::Daemon library.

It offers a bit of candy coating compared to the Perl version.

By default is uses a PSGI-compliant interface, but can also handle raw HTTP responses.

You don't need to create your own `IO::Socket::INET` object. Just pass an 'addr' and 'port' attribute to the new() declaration and it'll create the object for you.

USAGE
=====

The simplest (and recommended) form of usage is to use the handle() method with PSGI-compliant output. Here's an example:

```raku
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
```

There are other ways of using SCGI, such as writing your own run loop, or using a raw HTTP output instead of PSGI. Here's an example doing both:

```raku
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
```

Test script representing both examples can be found in the 'examples' folder.

If you are serious about using SCGI for web application development, see the [Web](https://github.com/raku-community-modules/Web/) library set, or one of the full blown frameworks built using it.

CONFIGURATION
=============

nginx
-----

Make sure you compiled nginx with the SCGI plugin (it is included by default.) Then, in one of your server blocks, add a location mount:

```nginx
location /scgi/ {
    scgi_pass 127.0.0.1:8118;
    include scgi_params;
    # Optionally rewrite document URI path
    rewrite ^/scgi/(.*) /$1 break;
    # Some applications may need rewritten URI in PATH_INFO
    scgi_param PATH_INFO $uri;
}
```

lighttpd
--------

First, make sure the SCGI library is being loaded.

```lighttpd
server.modules += ( "mod_scgi" )
```

Next, set up an SCGI handler:

```lighttpd
scgi.server = (
    "/scgi" =>
    ((
      "host" => "127.0.0.1",
      "port" => 8118,
      "check-local" => "disable"
    ))
)
```

Apache 2 with mod_scgi:
-----------------------

Add the following line to your site config, changing the details to match your SCGI script configuration:

```apache
SCGIMount /scgi/ 127.0.0.1:8118
```

Apache 2 with mod_proxy_scgi:
-----------------------------

Add the following line to your site config, changes the details to match your SCGI script configuration:

```apache
<Proxy *>
    Order deny,allow
    Allow from all
</Proxy>
ProxyPass /scgi/ scgi://localhost:8118/
```

AUTHOR
======

Timothy Totten

COPYRIGHT AND LICENSE
=====================

Copyright 2013 - 2017 Timothy Totten

Copyright 2018 - 2022 Raku Community

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

