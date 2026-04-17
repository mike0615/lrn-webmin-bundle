#!/usr/bin/perl
# LRN Service Panels - add/edit service form

require './lrn-iframe-wrapper-lib.pl';

my $name = $in{'name'} || '';
$name =~ s/[^a-zA-Z0-9 _\-]//g;
my $edit = $name ? 1 : 0;

my $svc = $edit ? (&get_service($name) || {}) : {};

my $title = $edit ? "$text{'edit_title'}: " . &html_escape($name)
                  : $text{'add_title'};

&ui_print_header(undef, $title, "", undef, 0, 1);

print &ui_form_start("save_service.cgi", "post");
print &ui_hidden("orig_name", $svc->{name} || '') if $edit;

my @rows = (
    [ $text{'edit_name'},
      &ui_textbox("name", $svc->{name} || '', 40) . " *" ],

    [ $text{'edit_url'},
      &ui_textbox("url", $svc->{url} || 'http://', 60) . " *<br>"
      . "<small>e.g. https://ipa.local, http://localhost:3000</small>" ],

    [ $text{'edit_desc'},
      &ui_textbox("desc", $svc->{desc} || '', 60) ],

    [ $text{'edit_category'},
      &ui_select("category", $svc->{category} || 'other', [
          [ 'identity',       'Identity & Auth'   ],
          [ 'automation',     'Automation'        ],
          [ 'messaging',      'Messaging'         ],
          [ 'virtualization', 'Virtualization'    ],
          [ 'monitoring',     'Monitoring'        ],
          [ 'other',          'Other'             ],
      ]) ],

    [ $text{'edit_icon'},
      &ui_textbox("icon", $svc->{icon} || 'default.png', 30) . "<br>"
      . "<small>Filename in module images/ directory</small>" ],

    [ $text{'edit_proxy'},
      &ui_checkbox("proxy", 1, $text{'edit_proxy_label'},
          $svc->{proxy} ? 1 : 0) . "<br>"
      . "<small>Route requests through Webmin to bypass X-Frame-Options. "
      . "Requires enable_proxy=1 in module config.</small>" ],
);

print &ui_table_start($title, "width=100%", 2);
foreach my $row (@rows) {
    print &ui_table_row($row->[0], $row->[1]);
}
print &ui_table_end();

print &ui_form_end([
    [ "save", $edit ? $text{'edit_save'} : $text{'add_save'} ],
]);

&ui_print_footer("index.cgi", $text{'index_return'});
