# lrn-webmin-bundle

An air-gapped, self-contained RPM bundle that installs Webmin and Virtualmin on
Rocky Linux 10.x hypervisors with full support for enterprise infrastructure
management — including a custom iframe panel module for services without native
Webmin plugins.

## Managed Services

| Service | Method |
|---|---|
| BIND 9 DNS | Native Webmin module |
| DHCP Server | Native Webmin module |
| SSL/TLS Certificates | Native Webmin module |
| MySQL | Native Webmin module |
| PostgreSQL | Native Webmin module |
| KVM Virtual Machines | Native Webmin module |
| FreeIPA | LRN Service Panels (iframe) |
| Ansible (Semaphore/AWX) | LRN Service Panels (iframe) |
| XMPP Chat Server | LRN Service Panels (iframe) |

## Build Requirements

Build must be performed on an **internet-connected** machine before transfer to
the air-gapped target.

Dependencies: `rpm-build`, `git`, `curl`, `createrepo_c`

```bash
dnf install -y rpm-build git curl createrepo_c
```

## Build Steps

```bash
# 1. Clone the repo
git clone git@github.com:mike0615/lrn-webmin-bundle.git
cd lrn-webmin-bundle

# 2. Fetch all RPM dependencies (requires internet)
./scripts/fetch-deps.sh

# 3. Build the self-contained RPM bundle
make rpm

# 4. Transfer to air-gapped target
scp RPMS/x86_64/lrn-webmin-bundle-*.rpm root@target:/tmp/
```

## Air-Gapped Installation

```bash
# On the target Rocky Linux 10.x machine (as root)
rpm -ivh /tmp/lrn-webmin-bundle-1.0-1.el10.x86_64.rpm
/opt/lrn-webmin-bundle/scripts/install.sh
```

Webmin will be accessible at: `https://<host>:10000`

## LRN Service Panels Module

The `lrn-iframe-wrapper` Webmin module provides configurable iframe panels for
any web-based service. After installation, navigate to:

**Webmin → Others → LRN Service Panels**

Pre-configured panels are included for FreeIPA, Ansible Semaphore, ejabberd
XMPP admin, and Cockpit. Each panel URL is editable post-install.

### X-Frame-Options Note

Many services block iframe embedding by default. To enable framing, either:
- Configure the service to allow embedding from localhost/127.0.0.1
- Use the built-in proxy mode (`Settings → Enable Proxy Mode`)

For FreeIPA: `ipa-server-install --no-ntp` and configure `httpd` to omit
`X-Frame-Options` for the management interface.

## Author

LRN-MAN — Planet Maytag  
License: GPLv3
