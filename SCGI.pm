class SCGI::Request {

    has $!strict = True;
    has $.connection;
    has %.env is rw;
    has $.body is rw;
    has $.request is rw;
    has $!closed is rw = 0;

    method err ($message) {
        my $crlf = "\x0D\x0A" x 2;
        $*ERR.say: "[{time}] $message";
        $.connection.send("Status: 500 SCGI Protocol Error$crlf");
        self.close;
        return 0;
    }

    method parse {
        $.request = $.connection.recv();
        if $.request ~~ / ^ (\d+) \: / {
            my $length = +$0;
            my $offset = ~$0.chars + 1;
            my $env_string = $.request.substr($offset, $length);
            my $comma = $.request.substr($offset+$length, 1);
            return self.err("malformed netstring, expecting terminating comma, found \"$comma\"") if $comma ne ',';
            $.body = $.request.substr($offset+$length+1);
            my @env = $env_string.split("\0");
            @env.pop;
            %.env = @env;
            if $!strict {
                return self.err("malformed or missing CONTENT_LENGTH header")\
                unless defined %.env<CONTENT_LENGTH> \
                && %.env<CONTENT_LENGTH> ~~ / ^ \d+ $ /;
                return self.err("missing SCGI header")\
                unless %.env<SCGI> && %.env<SCGI> eq '1';
            }
            return 1;
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

    has Int $!port = 8080;
    has Str $!addr = 'localhost';
    has IO::Socket $.socket = IO::Socket::INET.socket(2, 1, 6)\
                                              .bind($!addr, $!port)\
                                              .listen();
    has $!bodykey    = 'Request.Body';
    has $!requestkey = 'Request.Object';
    has $!scgikey    = 'Request.SCGI';

    has $!strict = True;
    
    method accept () {
        my $connection = self.socket.accept() or return;
        SCGI::Request.new( :connection($connection), :strict($!strict) );
    }

    method handle (&closure) {
        while (my $request = self.accept) {
            if $request.parse {
                my %env = $request.env;
                %env{$!requestkey} = $request;
                %env{$!scgikey} = self;
                %env{$!bodykey} = $request.body; 
                $request.connection.send(closure(%env));
                $request.close;
            }
        }
    }

}

