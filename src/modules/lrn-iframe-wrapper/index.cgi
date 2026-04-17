#!/usr/bin/perl
# LRN Service Panels - main index page

require './lrn-iframe-wrapper-lib.pl';

&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);

my @services = &list_services();
my %by_cat;
foreach my $svc (@services) {
    my $cat = $svc->{category} || 'other';
    push @{$by_cat{$cat}}, $svc;
}

if (!@services) {
    print &ui_alert_box($text{'index_noservices'}, 'info');
}

# Render service tiles grouped by category
my @cat_order = qw(identity automation messaging virtualization monitoring other);
my %seen_cat;
my @cats = grep { !$seen_cat{$_}++ } (@cat_order, keys %by_cat);

foreach my $cat (@cats) {
    next unless $by_cat{$cat};
    print "<h3 style='margin-top:20px; border-bottom:1px solid #ccc; padding-bottom:4px'>"
        . &html_escape(&category_label($cat)) . "</h3>\n";
    print "<div style='display:flex; flex-wrap:wrap; gap:16px; margin-bottom:24px'>\n";

    foreach my $svc (@{$by_cat{$cat}}) {
        my $enc_name = &urlize($svc->{name});
        my $icon     = $svc->{icon} || 'default.png';

        print "<div style='border:1px solid #ddd; border-radius:6px; padding:16px; "
            . "width:200px; text-align:center; background:#fafafa'>\n";
        print "<img src='images/$icon' width='48' height='48' "
            . "onerror=\"this.src='images/default.png'\" style='margin-bottom:8px'><br>\n";
        print "<strong>" . &html_escape($svc->{name}) . "</strong><br>\n";
        print "<small style='color:#666'>" . &html_escape($svc->{desc}) . "</small><br>\n";
        print "<div style='margin-top:10px'>\n";
        print "<a href='view_service.cgi?name=$enc_name' "
            . "class='btn btn-success btn-xs'>Open</a> &nbsp;\n";
        print "<a href='edit_service.cgi?name=$enc_name' "
            . "class='btn btn-default btn-xs'>Edit</a> &nbsp;\n";
        print "<a href='delete_service.cgi?name=$enc_name' "
            . "onClick='return confirm(\"Delete ${\&html_escape($svc->{name})}?\")' "
            . "class='btn btn-danger btn-xs'>Del</a>\n";
        print "</div>\n";
        print "</div>\n";
    }
    print "</div>\n";
}

print &ui_hr();
print "<a href='edit_service.cgi' class='btn btn-primary'>"
    . "<i class='fa fa-plus'></i> " . $text{'index_add'} . "</a>\n";

&ui_print_footer("", $text{'index_return'});
