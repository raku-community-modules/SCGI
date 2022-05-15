use SCGI::Constants;

unit class SCGI::Errors;

has $.connection;

method print($message) {
    my $crlf := CRLF x 2;
    $*ERR.print: "[{time}] $message";
    $.connection.socket.print(SCGI_ERROR_CODE ~ $crlf);
    $.connection.close;
}

method say($message) {
    self.print($message~"\n");
}

method printf($message, *@params) {
    self.print(sprintf($message, |@params));
}

method sayf($message, *@params) {
    self.printf($message~"\n", |@params);
}

# vim: expandtab shiftwidth=4
