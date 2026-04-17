#!/usr/bin/perl
# LRN Service Panels - save service

require './lrn-iframe-wrapper-lib.pl';

&error_setup($text{'save_err'});

# Input validation
my $name = $in{'name'};
$name =~ s/^\s+|\s+$//g;
$name =~ s/[^a-zA-Z0-9 _\-]//g;
&error($text{'save_noname'}) unless length($name) > 0;

my $url = $in{'url'};
$url =~ s/^\s+|\s+$//g;
&error($text{'save_nourl'})    unless length($url) > 0;
&error($text{'save_badurl'})   unless &validate_url($url);

my $desc     = $in{'desc'};
$desc        =~ s/[<>]//g;
my $category = $in{'category'} || 'other';
my $icon     = $in{'icon'} || 'default.png';
$icon        =~ s|[/\\]||g;
my $proxy    = $in{'proxy'} ? 1 : 0;
my $orig     = $in{'orig_name'} || '';
$orig        =~ s/[^a-zA-Z0-9 _\-]//g;

# If renaming, remove old entry first
if ($orig && $orig ne $name) {
    &delete_service($orig);
}

my $svc = {
    name     => $name,
    url      => $url,
    desc     => $desc,
    category => $category,
    icon     => $icon,
    proxy    => $proxy,
};

&add_or_update_service($svc);

&redirect("index.cgi");
