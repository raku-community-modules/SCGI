class SCGI::Request {

    has $.connection;
    has $!env_read is rw;
    has $!env_buffer is rw = '';
    has $!env_length_buffer is rw = '';
    has $!env_length_read is rw;
    has %.env is rw;
    has $!closed is rw = 0;
    #has Bool $.blocking is rw = False;

    method read_env {
        unless $!env_length_read {
            say "read_env entered";
            my $buffer = $.connection.recv(14);
            say "initial receiving done";
            my $bytes_read = ~$buffer.chars;
            die "read error $!" unless defined $bytes_read;
            return unless $bytes_read;
            if $buffer ~~ / ^ (\d+) \: (.*) $ / {
                $!env_length_buffer ~= +$0;
                $!env_buffer ~= ~$1;
                $!env_length_read = 1;
            }
            elsif $!env_length_buffer ne '' && $buffer ~~ / ^ \: (.*) $ / {
                $!env_buffer ~= ~$0;
                $!env_length_read = 1;
            }
            elsif $buffer ~~ / ^ \d+ $ / {
                $!env_length_buffer = +$buffer;
                return;
            }
            else {
                die "malformed env length";
            }
        }
        my $left_to_read = $!env_length_buffer - $!env_buffer.chars;
        my $buffer = $.connection.recv($left_to_read + 1);
        my $read = ~$buffer.chars;
        die "read error: $!" unless defined $read;
        return unless $read;
        if $read == $left_to_read + 1 {
            if (my $comma = $buffer.substr($left_to_read) ne ',') {
                die "malformed netstring, expecting terminating comma, found \"$comma\"";
            }
            self!decode_env($!env_buffer ~ $buffer.substr(0, $left_to_read));
            return 1;
        }
        else {
            $!env_buffer ~= $buffer;
            return;
        }
    }

    method close () {
        $.connection.close if $.connection;
        $!closed = 1;
    }

    method !decode_env ($env_string) {
        my %env = $env_string.split("\0");
        die "malformed or missing CONTENT_LENGTH header" unless %env<CONTENT_LENGTH> && %env<CONTENT_LENGTH> ~~ / ^ \d+ $ /;
        die "missing SCGI header" unless %env<SCGI> && %env<SCGI> eq '1';
        my $body = $.connection.recv(%env<CONTENT_LENGTH>);
        %env<Request.Body> = $body;
        %.env = %env;
    }

    submethod DESTROY {
        self.close unless $.closed;
    }

}

class SCGI {

    #has Bool $.blocking = False;
    has Int $!port = 8080;
    has Str $!addr = 'localhost';
    has IO::Socket $.socket = IO::Socket::INET.socket(2, 1, 6)\
                                              .bind($!addr, $!port)\
                                              .listen();
    
    method accept () {
        my $connection = self.socket.accept() or return;
        #$connecton.blocking(0) unless $.blocking;
        SCGI::Request.new( :connection($connection) );
    }

    method handle (&closure) {
        while (my $request = self.accept) {
            $request.read_env;
            my %env = $request.env;
            %env<Request.Object> = $request;
            %env<Request.SCGI> = self;
            closure(%env);
        }
    }

}

