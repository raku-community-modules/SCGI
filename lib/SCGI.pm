class SCGI { ... }
class SCGI::Request {

    has $.strict = True;
    has $.connection;
    has %.env is rw;
    has $.body is rw;
    has $.request is rw;
    has $!closed is rw = 0;

    method err (
        $message, 
        $status = "Status: 500 SCGI Protocol Error";
    ) {
        my $crlf = "\x0D\x0A" x 2;
        $*ERR.say: "[{time}] $message";
        $.connection.send("$status$crlf");
        self.close;
        return 0;
    }

    method shutdown (:$message="Server Shutdown (by request)", :$status) {
        self.err($message, $status);
        exit;
    }

    method parse {
        $.request = $.connection.get();#recv();
        $*ERR.say: "Receieved request: $.request";
        if $.request ~~ / ^ (\d+) \: / {
            $*ERR.say: "A proper request was received, parsing into an ENV";
            my $length = +$0;
            my $offset = $0.Str.chars + 1;
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

    has Int $.port = 8080;
    has Str $.addr = 'localhost';
    has $.socket = IO::Socket::INET.new(:localhost($.addr), :localport($.port), :listen(1));

    has $.bodykey    = 'SCGI.Body';
    has $.requestkey = 'SCGI.Request';
    has $.scgikey    = 'SCGI.Object';

    has $.strict = True;
    
    method accept () {
        $*ERR.say: "Waiting for connection.";
        my $connection = self.socket.accept() or return;
        $*ERR.say: "connection family is "~$connection.family;
        $*ERR.say: "connection proto is "~$connection.proto;
        $*ERR.say: "connection type is "~$connection.type;
        SCGI::Request.new( :connection($connection), :strict($.strict) );
    }

    method handle (&closure) {
        $*ERR.say: "socket family is "~$.socket.family;
        $*ERR.say: "socket proto is "~$.socket.proto;
        $*ERR.say: "socket type is "~$.socket.type;
        while (my $request = self.accept) {
            $*ERR.say: "Doing the loop";
            if $request.parse {
                my %env = $request.env;
                %env{$.requestkey} = $request;
                %env{$.scgikey} = self;
                %env{$.bodykey} = $request.body; 
                $request.connection.send(closure(%env));
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

