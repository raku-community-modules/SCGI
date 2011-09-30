class SCGI { ... }
class SCGI::Request {

    has $.strict = True;
    has $.connection;
    has %.env is rw;
    has $.body is rw;
    has $.request is rw;
    has $!closed is rw = 0;
    has $.debug = False; 
    has $.errors = $*ERR;

    method err (
        $message, 
        $status = "Status: 500 SCGI Protocol Error";
    ) {
        my $crlf = "\x0D\x0A" x 2;
        $.errors.say: "[{time}] $message";
        $.connection.send("$status$crlf");
        self.close;
        return 0;
    }

    method shutdown (:$message="Server Shutdown (by request)", :$status) {
        self.err($message, $status);
        exit;
    }

    method parse {
        $.request = $.connection.recv();
        my $rlen = $.request.chars;
        if $.debug { $.errors.say: "Receieved request: $.request"; }
        if $.request ~~ / ^ (\d+) \: / {
            if $.debug {
              $.errors.say: "A proper request was received, parsing into an ENV";
            }
            my $length = +$0;
            my $offset = $0.Str.chars + 1;
            if ($rlen < $length + $offset) {
              return self.err("malformed netstring, length is incorrect.");
            }
            my $env_string = $.request.substr($offset, $length);
            my $comma = $.request.substr($offset+$length, 1);
            if $comma ne ',' {
                return self.err("malformed netstring, expecting terminating comma, found \"$comma\"");
            }
            $.body = $.request.substr($offset+$length+1);
            my @env = $env_string.split("\0");
            @env.pop;
            %.env = @env;
            if $.strict {
                unless defined %.env<CONTENT_LENGTH> && %.env<CONTENT_LENGTH> ~~ / ^ \d+ $ / {
                    return self.err("malformed or missing CONTENT_LENGTH header");
                }
                unless %.env<SCGI> && %.env<SCGI> eq '1' {
                    return self.err: "missing SCGI header";
                }
            }
            return 1;
        }
        elsif $.request ~~ /:s ^ QUIT $ / {
            self.shutdown(:status<Server Shutdown>);
        }
        else {
            return self.err(
                "invalid request, expected a netstring, got: $.request"
            );
        }
    }

    method close () {
        $.connection.close if $.connection;
        $!closed = 1;
    }

    submethod DESTROY {
        self.close unless $.closed;
    }

}

class SCGI {

    use HTTP::Status;

    has Int $.port = 8080;
    has Str $.addr = 'localhost';
    has $.socket = IO::Socket::INET.new(:localhost($.addr), :localport($.port), :listen(1));

    ## Don't override these unless you really know what you are doing.
    ## All of my libraries expect the defaults to have been used.
    has $.bodykey    = 'SCGI.Body';    ## The body of the request.
    has $.requestkey = 'SCGI.Request'; ## The Request Object itself.
    has $.scgikey    = 'SCGI.Object';  ## The SCGI Object itself.
    has $.errkey     = 'SCGI.Errors';  ## The Error Stream.

    has $.errors = $*ERR; ## Default error stream.

    has $.PSGI = False;   ## Set to true to use PSGI mode.
    has $.NPH  = False;   ## Set to true to use NPH mode.

    has $.debug  = False; ## Set to true to debug stuff.
    has $.strict = True;  ## If set to false, don't ensure proper SCGI.

    constant $CRLF = "\x0D\x0A";
    
    method accept () {
        if ($.debug) {
          $.errors.say: "Waiting for connection.";
        }
        my $connection = self.socket.accept() or return;
        if ($.debug) {
          $.errors.say: "connection family is "~$connection.family;
          $.errors.say: "connection proto is "~$connection.proto;
          $.errors.say: "connection type is "~$connection.type;
        }
        SCGI::Request.new( 
          :connection($connection), :$.strict, :$.debug, :$.errors 
        );
    }

    method handle (&closure) {
        if ($.debug) {
          $.errors.say: "socket family is "~$.socket.family;
          $.errors.say: "socket proto is "~$.socket.proto;
          $.errors.say: "socket type is "~$.socket.type;
        }
        $.errors.say: "[{time}] SCGI is ready and waiting.";
        while (my $request = self.accept) {
            if ($.debug) { $.errors.say: "Doing the loop"; }
            if $request.parse {
                my %env = $request.env;
                %env{$.requestkey} = $request;
                %env{$.scgikey} = self;
                %env{$.bodykey} = $request.body;
                %env{$.errkey}  = $.errors;
                if ($.PSGI)
                {
                  %env<psgi.version>      = [1,0];
                  %env<psgi.url_scheme>   = 'http';  ## FIXME: detect this.
                  %env<psgi.multithread>  = False;
                  %env<psgi.multiprocess> = False;
                  %env<psgi.input>        = $request.body; ## Is this valid?
                  %env<psgi.errors>       = $.errors;
                  %env<psgi.run_once>     = False;
                  %env<psgi.nonblocking>  = False;   ## Allow when NBIO.
                  %env<psgi.streaming>    = False;   ## Eventually?
                }
                my $return = closure(%env);
                my $output;
                if ($.PSGI)
                { 
                  my $headers;
                  my $code = $return[0];
                  my $message = get_http_status_msg($code);
                  if ($.NPH) {
                    $headers = "HTTP/1.1 $code $message"~$CRLF;
                  }
                  else {
                    $headers = "Status: $code $message"~$CRLF;
                  }
                  for @($return[1]) -> $header {
                    $headers ~= $header.key ~ ": " ~ $header.value ~ $CRLF;
                  }
                  my $body = $return[2].join($CRLF);
                  $output = $headers~$CRLF~$body;
                }
                else {
                  if ($.NPH && $return !~~ /^HTTP/) {
                    $return ~~ s:g/^ Status: \s* (\d+) \s* (\w)* $//;
                    my $code = +$0;
                    my $message;
                    if ($1) {
                      $message = ~$1;
                    }
                    else {
                      $message = get_http_status_msg($code);
                    }
                    $output = "HTTP/1.1 $code $message"~$CRLF~$return;
                  }
                  else {
                    $output = $return; 
                  }
                }
                $request.connection.send($output);
                $request.close;
            }
        }
    }

    method shutdown {
        ## Not as graceful as using the request shutdown.
        $*ERR.say: "[{time}] Server Shutdown (direct)";
        exit;
    }

}

