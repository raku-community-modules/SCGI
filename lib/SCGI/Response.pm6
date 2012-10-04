class SCGI::Response;

use HTTP::Status;
use SCGI::Constants;

has $.connection;

method send ($response-data)
{
  my $http_message;
  if $.connection.parent.PSGI
  {
    my $headers;
    my $code = $response-data[0];
    my $message = get_http_status_msg($code);
    if $.connection.parent.NPH 
    {
      $headers = "HTTP/1.1 $code $message"~CRLF;
    }
    else 
    {
      $headers = "Status: $code $message"~CRLF;
    }
    for @($response-data[1]) -> $header 
    {
      $headers ~= $header.key ~ ": " ~ $header.value ~ CRLF;
    }
    my $body = $response-data[2].join;
    $http_message = $headers~CRLF~$body;
  }
  else 
  {
    if $.connection.parent.NPH && $response-data !~~ /^HTTP/ 
    {
      $response-data ~~ s:g/^ Status: \s* (\d+) \s* (\w)* $//;
      my $code = +$0;
      my $message;
      if ($1) 
      {
        $message = ~$1;
      }
      else 
      {
        $message = get_http_status_msg($code);
      }
      $http_message = "HTTP/1.1 $code $message"~CRLF~$response-data;
    }
    else 
    {
      $http_message = $response-data; 
    }
  }
  $.connection.socket.send($http_message);
}

