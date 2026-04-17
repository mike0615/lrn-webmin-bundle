#!/usr/bin/perl
# LRN Service Panels - HTTP reverse proxy for iframe embedding
# Strips X-Frame-Options and Content-Security-Policy frame directives
# so services that block iframing can still be embedded in Webmin.

require './lrn-iframe-wrapper-lib.pl';

# Proxy mode must be explicitly enabled in module config
unless ($config{enable_proxy}) {
    print "Content-type: text/plain\n\n";
    print "Proxy mode is disabled. Set enable_proxy=1 in module config.\n";
    exit 0;
}

my $name = $in{'name'} || '';
$name =~ s/[^a-zA-Z0-9 _\-]//g;
my $svc = &get_service($name);
unless ($svc) {
    print "Content-type: text/plain\n\n";
    print "Service not found.\n";
    exit 0;
}

eval { require LWP::UserAgent; };
if ($@) {
    print "Content-type: text/plain\n\n";
    print "LWP::UserAgent not available. Install perl-LWP-UserAgent.\n";
    exit 0;
}

my $base_url = $svc->{url};
$base_url =~ s|/+$||;

# Reconstruct downstream path from PATH_INFO or query string
my $path      = $ENV{PATH_INFO}  || '/';
my $query_str = $ENV{QUERY_STRING} || '';
$query_str =~ s/(?:^|&)name=[^&]*//g;
$query_str =~ s/^&//;

my $target = $base_url . $path;
$target .= "?$query_str" if $query_str;

my $ua = LWP::UserAgent->new(
    ssl_opts         => { verify_hostname => 0, SSL_verify_mode => 0 },
    timeout          => 30,
    requests_redirectable => [qw(GET HEAD POST)],
);

# Forward incoming cookies and auth headers
my %req_headers;
$req_headers{'Cookie'}        = $ENV{HTTP_COOKIE}        if $ENV{HTTP_COOKIE};
$req_headers{'Authorization'} = $ENV{HTTP_AUTHORIZATION} if $ENV{HTTP_AUTHORIZATION};

my $method   = $ENV{REQUEST_METHOD} || 'GET';
my $response;

if ($method eq 'POST') {
    my $body = '';
    read(STDIN, $body, $ENV{CONTENT_LENGTH} || 0);
    $response = $ua->post($target, %req_headers,
        'Content-Type'   => $ENV{CONTENT_TYPE} || 'application/x-www-form-urlencoded',
        Content          => $body,
    );
} else {
    my $req = HTTP::Request->new('GET', $target, [%req_headers]);
    $response = $ua->request($req);
}

# Strip framing-prevention headers, pass everything else through
my $content_type = $response->header('Content-Type') || 'text/html';

print "Content-type: $content_type\n";
foreach my $h ($response->header_field_names()) {
    next if $h =~ /^(X-Frame-Options|Content-Security-Policy|Transfer-Encoding|Content-Length)$/i;
    print "$h: " . $response->header($h) . "\n";
}
print "\n";

my $body = $response->content;

# Rewrite absolute URLs in HTML responses to route through the proxy
if ($content_type =~ m|text/html|i) {
    my $script = $ENV{SCRIPT_NAME} || '/cgi-bin/webmin/lrn-iframe-wrapper/proxy.cgi';
    $body =~ s|(href|src|action)="(${\quotemeta($base_url)})|$1="$script?name=${\&urlize($name)}&_url=$2|gi;
}

print $body;
