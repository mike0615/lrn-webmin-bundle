#!/usr/bin/env bash
# LRN Webmin Bundle Uninstaller
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Must be run as root"; exit 1; }

read -rp "Remove Webmin, Virtualmin, and LRN modules? [y/N] " confirm
[[ "${confirm,,}" == "y" ]] || { echo "Aborted."; exit 0; }

systemctl stop webmin 2>/dev/null || true
systemctl disable webmin 2>/dev/null || true

dnf remove -y webmin wbm-virtual-server virtualmin-config 2>/dev/null || true

rm -rf /usr/share/webmin/lrn-iframe-wrapper
rm -rf /etc/webmin/lrn-iframe-wrapper
rm -f  /etc/yum.repos.d/lrn-webmin-local.repo

firewall-cmd --permanent --remove-port=10000/tcp 2>/dev/null || true
firewall-cmd --reload 2>/dev/null || true

echo "Uninstall complete. Bundle files remain at /opt/lrn-webmin-bundle/"
echo "Remove them with: rpm -e lrn-webmin-bundle"
