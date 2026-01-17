use Netstring:ver<0.0.4+>:auth<zef:raku-community-modules>;
use SCGI::Constants;
use PSGI:ver<1.2.2+>:auth<zef:raku-community-modules>;

unit class SCGI::Request;

has $.connection;
has $.success = False;
has %.env;
has $.input;
has $.request;

method parse() {
    my $debug := $.connection.parent.debug;

    my $netstring := read-netstring($.connection.socket);
    $!request := $netstring.decode;

    my $rlen := $.request.chars;
    my $err  := $.connection.err;
    $*ERR.say: "Received request: $.request" if $debug;

    my @env = $.request.split(SEP);
    @env.pop;
    %!env = @env;

    if $.connection.parent.strict {
        unless defined %.env<CONTENT_LENGTH> 
          && %.env<CONTENT_LENGTH> ~~ / ^ \d+ $ / {
            $err.say(SCGI_E_CONTENT);
            return self;
        }
        unless %.env<SCGI> && %.env<SCGI> eq '1' {
            $err.say(SCGI_E_SCGI);
            return self;
        }
    }

    my $clen = +%.env<CONTENT_LENGTH>;
    if $clen > 0 {
        $!input = $.connection.socket.read($clen);
    }

    %.env<scgi.request> = self;
    my $scheme = %.env<HTTPS> ?? 'https' !! 'http';
    if $.connection.parent.PSGI || $.connection.parent.P6SGI {
        populate-psgi-env(%.env, :input($.input), :errors($.connection.err), 
          :psgi-classic($.connection.parent.PSGI), 
          :p6sgi($.connection.parent.P6SGI),
          :url-scheme($scheme),
          :multithread($.connection.parent.multithread)
      );
  }

  $!success = True;
  self
}

# vim: expandtab shiftwidth=4
