%global debug_package %{nil}
%global el_ver %{?_el_ver}%{!?_el_ver:9}

Name:           lrn-webmin-bundle
Version:        %{_version}
Release:        %{_release}%{?dist}
Summary:        Air-gapped Webmin/Virtualmin bundle for Rocky Linux %{el_ver} hypervisors
License:        GPLv3
URL:            https://github.com/mike0615/lrn-webmin-bundle
Source0:        %{name}-%{version}.tar.gz
BuildArch:      x86_64

# No RPM-level Requires — all dependencies are bundled inside the repo/
# directory and installed by install.sh from the local offline repo.

%description
Self-contained air-gapped installation bundle for Webmin and Virtualmin on
Rocky Linux %{el_ver}.x hypervisors. Includes a bundled local DNF repository of
all required packages and the LRN Service Panels custom Webmin module for
managing FreeIPA, Ansible, XMPP, and other services via integrated iframe panels.

Managed services include: BIND 9 DNS, DHCP/Kea, SSL/TLS Certificates, MariaDB,
PostgreSQL, KVM virtual machines, FreeIPA (iframe), Ansible Semaphore (iframe),
and XMPP chat servers (iframe).

Target OS: Rocky Linux %{el_ver}.x (EL%{el_ver})

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

# Bundle the offline repo — path passed in via --define from Makefile
%{?_repo_dir:%global _effective_repo_dir %{_repo_dir}}
%{!?_repo_dir:%global _effective_repo_dir %{_sourcedir}/repo-el%{el_ver}}

if [ -d "%{_effective_repo_dir}" ] && [ "$(ls -A '%{_effective_repo_dir}')" ]; then
    cp -r %{_effective_repo_dir}/* %{buildroot}/opt/%{name}/repo/
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
echo "  lrn-webmin-bundle (EL%{el_ver}) installed"
echo "  Path: /opt/lrn-webmin-bundle"
echo "============================================================"
echo ""
echo "  To complete installation, run as root:"
echo "    /opt/lrn-webmin-bundle/scripts/install.sh"
echo ""
echo "  Webmin will be available at: https://$(hostname -f):10000"
echo ""

%preun
if systemctl is-active --quiet webmin 2>/dev/null; then
    systemctl stop webmin
fi

%changelog
* Fri Apr 17 2026 LRN-MAN <lrn-man@planet-maytag.local> - 1.0-1
- Initial release: air-gapped Webmin/Virtualmin bundle for EL9 with LRN Service Panels
- EL10 variant adds Kea DHCP support (replaces ISC dhcp-server removed in RHEL 10)
