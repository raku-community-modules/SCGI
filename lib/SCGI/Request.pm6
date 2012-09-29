class SCGI::Request;

use SCGI::Constants;

has $.connection;
has $.success = False;
has %.env;
has $.input;
has $.request;

method parse ()
{
  $!request = $.connection.socket.recv();
  my $rlen = $.request.chars;
  my $debug = $.connection.parent.debug;
  my $err = $.connection.err;
  if $debug { $*ERR.say: "Receieved request: $.request"; }
  if $.request ~~ / ^ (\d+) \: / 
  {
    if $debug 
    {
      $*ERR.say: "A proper request was received, parsing into an ENV";
    }
    my $length = +$0;
    my $offset = $0.Str.chars + 1;
    if ($rlen < $length + $offset) 
    {
      $err.say(SCGI_E_LENGTH);
      return self;
    }
    my $env_string = $.request.substr($offset, $length);
    my $comma = $.request.substr($offset+$length, 1);
    if $comma ne ',' 
    {
      $err.sayf(SCGI_E_COMMA, $comma);
      return self;
    }
    $!input = $.request.substr($offset+$length+1);
    my @env = $env_string.split(SEP);
    @env.pop;
    %!env = @env;
    if $.connection.parent.strict 
    {
      unless defined %.env<CONTENT_LENGTH> 
      && %.env<CONTENT_LENGTH> ~~ / ^ \d+ $ / 
      {
        $err.say(SCGI_E_CONTENT);
        return self;
      }
      unless %.env<SCGI> && %.env<SCGI> eq '1' 
      {
        $err.say(SCGI_E_SCGI);
        return self;
      }
    }

    %.env<scgi.request> = self;
    if $.connection.parent.PSGI
    {
      %.env<psgi.version>      = [1,0];
      %.env<psgi.url_scheme>   = 'http';  ## FIXME: detect this.
      %.env<psgi.multithread>  = False;
      %.env<psgi.multiprocess> = False;
      %.env<psgi.input>        = $.input;
      %.env<psgi.errors>       = $.connection.err;
      %.env<psgi.run_once>     = False;
      %.env<psgi.nonblocking>  = False;   ## Allow when NBIO.
      %.env<psgi.streaming>    = False;   ## Eventually?
    }

    $!success = True;
    return self;
  }
  elsif $.request ~~ /:s ^ QUIT $ / 
  {
    $.connection.shutdown(SCGI_M_QUIT);
  }
  else 
  {
    $err.sayf(SCGI_E_INVALID, $.request);
    return self;
  }
}

