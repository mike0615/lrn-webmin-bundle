# Air-Gapped Installation Guide

## Overview

The `lrn-webmin-bundle` RPM is a self-contained installation package for
Webmin, Virtualmin GPL, and the LRN Service Panels module on Rocky Linux 10.x
hypervisors. It ships with a bundled local DNF repository so no internet access
is required on the target machine.

## Required: Build on an Internet-Connected Machine

The bundle RPM must be **assembled on an internet-connected machine** before
being transferred to the air-gapped target. This is a one-time build step.

### Build Machine Requirements

- Rocky Linux 9 or 10 (x86_64)
- Root or sudo access
- Internet access
- ~2 GB free disk space

```bash
dnf install -y rpm-build git curl createrepo_c
```

### Build Steps

```bash
git clone git@github.com:mike0615/lrn-webmin-bundle.git
cd lrn-webmin-bundle

# Download all upstream RPMs and their dependencies
./scripts/fetch-deps.sh

# Build the self-contained bundle RPM
make rpm

# Output will be in:
ls RPMS/x86_64/lrn-webmin-bundle-*.rpm
```

The resulting RPM will be large (~200–800 MB depending on package versions).

## Transfer to Air-Gapped Machine

```bash
# Via USB drive, PXE, or whatever transfer mechanism is available
scp RPMS/x86_64/lrn-webmin-bundle-1.0-1.el10.x86_64.rpm root@target:/tmp/
```

## Installation on Air-Gapped Rocky Linux 10.x

```bash
# As root on the target hypervisor

# Step 1: Install the bundle RPM
rpm -ivh /tmp/lrn-webmin-bundle-1.0-1.el10.x86_64.rpm

# Step 2: Run the installer
/opt/lrn-webmin-bundle/scripts/install.sh

# Webmin will start automatically on port 10000
```

## Post-Installation

Access Webmin at: `https://<hostname>:10000`

Log in with root credentials.

### Native Webmin/Virtualmin Modules Available

| Module | Path in Webmin |
|---|---|
| BIND 9 DNS | Servers → BIND DNS Server |
| DHCP Server | Servers → DHCP Server |
| SSL Certificates | Webmin → Webmin Configuration → SSL Encryption |
| Let's Encrypt | Webmin → Webmin Configuration → Let's Encrypt |
| MySQL | Servers → MySQL Database Server |
| PostgreSQL | Servers → PostgreSQL Database Server |
| KVM/Libvirt | Servers → KVM Virtual Machines |
| Virtualmin | Side navigation → Virtualmin |

### LRN Service Panels (FreeIPA, Ansible, XMPP)

Navigate to: **Webmin → Others → LRN Service Panels**

Pre-configured panels are included for:
- **FreeIPA** — `https://localhost` (adjust to your IPA host)
- **Ansible Semaphore** — `http://localhost:3000`
- **XMPP Admin (ejabberd)** — `http://localhost:5280/admin`
- **Cockpit (KVM)** — `https://localhost:9090`

Edit panel URLs from the **LRN Service Panels** index page.

## X-Frame-Options Troubleshooting

If a service panel appears blank, the upstream service is blocking iframe
embedding. Solutions:

### Option A — Enable Proxy Mode in the module
1. Go to **Webmin → Others → LRN Service Panels → Module Config**
2. Set **Enable reverse proxy mode** to Yes
3. Edit the service and check **Proxy Mode**

### Option B — Disable X-Frame-Options on the upstream service

**FreeIPA (Apache httpd):**
```bash
# Add to /etc/httpd/conf.d/ipa.conf inside the VirtualHost block:
Header unset X-Frame-Options
Header always set X-Frame-Options "SAMEORIGIN"
# Or to allow all:
Header always unset X-Frame-Options
```
Then: `systemctl reload httpd`

**ejabberd:**
Edit `/etc/ejabberd/ejabberd.yml`, add under the `listen` section:
```yaml
request_handlers:
  /admin: ejabberd_web_admin
# Set custom headers (ejabberd 23+):
custom_headers:
  "X-Frame-Options": "SAMEORIGIN"
```

**Cockpit:**
```bash
# /etc/cockpit/cockpit.conf
[WebService]
Origins = https://your-webmin-host:10000
```

## Firewall Ports

The installer opens TCP 10000 (Webmin) automatically. You may need to
open additional ports for services:

```bash
firewall-cmd --permanent --add-port=10000/tcp   # Webmin
firewall-cmd --permanent --add-port=9090/tcp    # Cockpit
firewall-cmd --permanent --add-port=5280/tcp    # ejabberd HTTP
firewall-cmd --permanent --add-port=5222/tcp    # XMPP client
firewall-cmd --permanent --add-port=3000/tcp    # Ansible Semaphore
firewall-cmd --reload
```

## Uninstalling

```bash
/opt/lrn-webmin-bundle/scripts/uninstall.sh
rpm -e lrn-webmin-bundle
```
