%global debug_package %{nil}

Name:           lrn-webmin-bundle
Version:        %{_version}
Release:        %{_release}%{?dist}
Summary:        Air-gapped Webmin/Virtualmin bundle for Rocky Linux 9 hypervisors
License:        GPLv3
URL:            https://github.com/mike0615/lrn-webmin-bundle
Source0:        %{name}-%{version}.tar.gz
BuildArch:      x86_64

Requires:       perl
Requires:       curl
Requires:       firewalld

%description
Self-contained air-gapped installation bundle for Webmin and Virtualmin on
Rocky Linux 9.x hypervisors. Includes a bundled local DNF repository of all
required packages and the LRN Service Panels custom Webmin module for managing
FreeIPA, Ansible, XMPP, and other services via integrated iframe panels.

Managed services include: BIND 9 DNS, DHCP, SSL/TLS Certificates, MySQL,
PostgreSQL, KVM virtual machines, FreeIPA (iframe), Ansible Semaphore (iframe),
and XMPP chat servers (iframe).

%prep
%setup -q

%build
# Nothing to compile

%install
install -d %{buildroot}/opt/%{name}
install -d %{buildroot}/opt/%{name}/scripts
install -d %{buildroot}/opt/%{name}/modules
install -d %{buildroot}/opt/%{name}/repo

cp -r scripts/*          %{buildroot}/opt/%{name}/scripts/
cp -r modules/*          %{buildroot}/opt/%{name}/modules/
chmod 755                %{buildroot}/opt/%{name}/scripts/*.sh

# Bundle the offline repo if it was fetched
if [ -d %{_sourcedir}/repo ] && [ "$(ls -A %{_sourcedir}/repo)" ]; then
    cp -r %{_sourcedir}/repo/* %{buildroot}/opt/%{name}/repo/
fi

# Generate file list dynamically to cover all bundled RPMs and repodata
find %{buildroot}/opt/%{name} -not -type d \
    | sed "s|^%{buildroot}||" \
    > %{_builddir}/%{name}-%{version}/filelist
find %{buildroot}/opt/%{name} -mindepth 1 -type d \
    | sed "s|^%{buildroot}|%%dir |" \
    >> %{_builddir}/%{name}-%{version}/filelist

%files -f filelist
%defattr(-,root,root,-)

%post
echo ""
echo "============================================================"
echo "  lrn-webmin-bundle installed to /opt/lrn-webmin-bundle"
echo "============================================================"
echo ""
echo "  To complete installation, run as root:"
echo "    /opt/lrn-webmin-bundle/scripts/install.sh"
echo ""
echo "  Webmin will be available at: https://$(hostname -f):10000"
echo ""

%preun
# Stop webmin before removal if it's running
if systemctl is-active --quiet webmin 2>/dev/null; then
    systemctl stop webmin
fi

%changelog
* Fri Apr 17 2026 LRN-MAN <lrn-man@planet-maytag.local> - 1.0-1
- Initial release: air-gapped Webmin/Virtualmin bundle for EL9 with LRN Service Panels
