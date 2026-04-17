#!/usr/bin/perl
# LRN Service Panels - shared library

do 'web-lib.pl';
&init_config();

our %text;
our %config;
our $module_config_file = "$module_config_directory/config";
our $services_config    = "$module_config_directory/services.conf";

# Default service definitions shipped with the module
our @DEFAULT_SERVICES = (
    {
        name     => 'FreeIPA',
        url      => 'https://localhost',
        desc     => 'Identity and Access Management',
        category => 'identity',
        icon     => 'freeipa.png',
        proxy    => 1,
    },
    {
        name     => 'Ansible Semaphore',
        url      => 'http://localhost:3000',
        desc     => 'Ansible automation and playbook runner',
        category => 'automation',
        icon     => 'ansible.png',
        proxy    => 0,
    },
    {
        name     => 'XMPP Admin (ejabberd)',
        url      => 'http://localhost:5280/admin',
        desc     => 'ejabberd XMPP server administration',
        category => 'messaging',
        icon     => 'xmpp.png',
        proxy    => 0,
    },
    {
        name     => 'Cockpit (KVM)',
        url      => 'https://localhost:9090',
        desc     => 'KVM virtual machine management via Cockpit',
        category => 'virtualization',
        icon     => 'cockpit.png',
        proxy    => 1,
    },
);

sub list_services {
    my @services;
    if (-e $services_config) {
        open(my $fh, '<', $services_config) or return @DEFAULT_SERVICES;
        my %cur;
        while (<$fh>) {
            chomp;
            next if /^\s*#/ || /^\s*$/;
            if (/^---$/) {
                push @services, {%cur} if %cur;
                %cur = ();
            } elsif (/^(\w+)=(.*)$/) {
                $cur{$1} = $2;
            }
        }
        push @services, {%cur} if %cur;
        close $fh;
    }
    return @services ? @services : @DEFAULT_SERVICES;
}

sub get_service {
    my ($name) = @_;
    foreach my $svc (list_services()) {
        return $svc if $svc->{name} eq $name;
    }
    return undef;
}

sub save_services {
    my (@services) = @_;
    open(my $fh, '>', $services_config) or &error("Cannot write $services_config: $!");
    foreach my $svc (@services) {
        foreach my $key (sort keys %$svc) {
            print $fh "$key=$svc->{$key}\n";
        }
        print $fh "---\n";
    }
    close $fh;
}

sub delete_service {
    my ($name) = @_;
    my @services = grep { $_->{name} ne $name } list_services();
    save_services(@services);
}

sub add_or_update_service {
    my ($svc) = @_;
    my @services = list_services();
    my $found = 0;
    foreach my $s (@services) {
        if ($s->{name} eq $svc->{name}) {
            %$s = %$svc;
            $found = 1;
            last;
        }
    }
    push @services, $svc unless $found;
    save_services(@services);
}

sub category_label {
    my ($cat) = @_;
    my %labels = (
        identity      => 'Identity & Auth',
        automation    => 'Automation',
        messaging     => 'Messaging',
        virtualization => 'Virtualization',
        monitoring    => 'Monitoring',
        other         => 'Other',
    );
    return $labels{$cat} || ucfirst($cat);
}

sub validate_url {
    my ($url) = @_;
    return 0 unless $url =~ m|^https?://[^\s/$.?#].[^\s]*$|i;
    return 1;
}

1;
