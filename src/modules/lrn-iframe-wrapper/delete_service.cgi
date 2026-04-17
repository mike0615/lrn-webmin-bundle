#!/usr/bin/perl
# LRN Service Panels - delete service

require './lrn-iframe-wrapper-lib.pl';

my $name = $in{'name'} || '';
$name =~ s/[^a-zA-Z0-9 _\-]//g;
&error($text{'delete_noname'}) unless $name;

&delete_service($name);
&redirect("index.cgi");
