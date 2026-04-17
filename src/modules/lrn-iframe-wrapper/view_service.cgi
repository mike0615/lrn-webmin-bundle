#!/usr/bin/perl
# LRN Service Panels - display service in iframe

require './lrn-iframe-wrapper-lib.pl';

my $name = $in{'name'} || '';
$name =~ s/[^a-zA-Z0-9 _\-]//g;

my $svc = &get_service($name);
&error($text{'view_notfound'}) unless $svc;

my $use_proxy = $svc->{proxy} && $config{enable_proxy};
my $frame_url = $use_proxy
    ? "proxy.cgi?name=" . &urlize($name)
    : $svc->{url};

&ui_print_header(undef, $svc->{name} . " &mdash; " . $text{'index_title'}, "", undef, 0, 1);

# Toolbar
print "<div style='margin-bottom:8px; display:flex; align-items:center; gap:10px'>\n";
print "<strong>" . &html_escape($svc->{name}) . "</strong>\n";
print "<span style='color:#888; font-size:0.9em'>"
    . &html_escape($svc->{url}) . "</span>\n";
print "<a href='" . &html_escape($svc->{url}) . "' target='_blank' "
    . "class='btn btn-xs btn-default'>Open in new tab</a>\n";
print "<a href='index.cgi' class='btn btn-xs btn-default'>Back</a>\n";
print "</div>\n";

# Iframe
print "<div style='border:1px solid #ccc; border-radius:4px; overflow:hidden'>\n";
print "<iframe src='" . &html_escape($frame_url) . "' "
    . "width='100%' height='800' frameborder='0' "
    . "style='display:block' "
    . "sandbox='allow-same-origin allow-scripts allow-forms allow-popups allow-modals'>"
    . "</iframe>\n";
print "</div>\n";

print "<p style='margin-top:8px; font-size:0.85em; color:#888'>"
    . "If the panel is blank, the service may be blocking iframe embedding. "
    . "See <a href='edit_service.cgi?name=" . &urlize($name) . "'>settings</a> "
    . "to enable proxy mode, or configure the service to allow framing.</p>\n";

&ui_print_footer("index.cgi", $text{'index_return'});
