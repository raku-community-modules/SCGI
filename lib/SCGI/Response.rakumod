use HTTP::Status;
use SCGI::Constants;
use PSGI;

unit class SCGI::Response;

has $.connection;

method send($response-data) {
    my $http_message;
    if $.connection.parent.PSGI || $.connection.parent.P6SGI {
        my $nph = $.connection.parent.NPH;
        $http_message = encode-psgi-response($response-data, :$nph);
    }
    else {
        if $.connection.parent.NPH && $response-data !~~ /^HTTP/ {
            $response-data ~~ s:g/^ Status: \s* (\d+) \s* (\w)* $//;
            my $code    := $0.Int;
            my $message := $1 ?? $1.Str !! get_http_status_msg($code);
            $http_message = "HTTP/1.1 $code $message" ~ CRLF ~ $response-data;
        }
        else {
            $http_message = $response-data; 
        }
    }
    $.connection.socket.print($http_message);
}

# vim: expandtab shiftwidth=4
