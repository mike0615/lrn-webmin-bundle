#!/usr/bin/env bash
# fetch-deps.sh — Download all RPMs needed for the air-gapped bundle.
# Run this on an internet-connected machine BEFORE running `make rpm`.
# Output: SOURCES/repo/ populated with all required RPMs.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)/SOURCES/repo"
EL_VER="${EL_VER:-9}"
ARCH="${ARCH:-x86_64}"

# Virtualmin GPL repo base URLs (confirmed working)
VMIN_GPL_NOARCH="https://software.virtualmin.com/vm/7/gpl/rpm/noarch"
VMIN_X86_64="https://software.virtualmin.com/vm/7/rpm/x86_64"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
die()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

command -v curl     &>/dev/null || die "curl is required"
command -v dnf      &>/dev/null || die "dnf is required"
command -v createrepo_c &>/dev/null || { warn "createrepo_c not found — install it: dnf install -y createrepo_c"; }

mkdir -p "$REPO_DIR"
log "Downloading to: $REPO_DIR"
log "Target: EL${EL_VER} / ${ARCH}"

# ── Helper ─────────────────────────────────────────────────────────────────────
download_rpm() {
    local url="$1"
    local dest="$REPO_DIR/$(basename "$url")"
    if [[ -f "$dest" ]]; then
        log "  Already downloaded: $(basename "$url")"
        return
    fi
    echo -n "  Fetching: $(basename "$url") ... "
    if curl -sfL -o "$dest" "$url"; then
        echo "OK"
    else
        warn "FAILED (skipping): $url"
        rm -f "$dest"
    fi
}

dnf_download() {
    local pkg="$1"
    log "Downloading package + deps: $pkg"
    dnf download --resolve --destdir="$REPO_DIR" "$pkg" 2>&1 \
        | grep -v "^Last metadata" \
        | grep -v "^$" \
        || warn "dnf download failed for: $pkg"
}

# ── Webmin + Virtualmin GPL (direct URL downloads — no repo needed) ───────────
log "=== Webmin + Virtualmin GPL ==="

# Latest versions as of April 2026 — bump these when upstream releases updates
VMIN_GPL_DIRECT=(
    "${VMIN_GPL_NOARCH}/webmin-2.630-1.noarch.rpm"
    "${VMIN_GPL_NOARCH}/usermin-2.530-1.noarch.rpm"
    "${VMIN_GPL_NOARCH}/wbm-virtual-server-8.1.0.gpl-1.noarch.rpm"
    "${VMIN_GPL_NOARCH}/wbt-virtual-server-theme-9.4-1.noarch.rpm"
    "${VMIN_GPL_NOARCH}/virtualmin-config-7.0.24-1.noarch.rpm"
    "${VMIN_GPL_NOARCH}/wbm-virtualmin-htpasswd-3.7-1.noarch.rpm"
    "${VMIN_GPL_NOARCH}/wbm-virtualmin-awstats-7.0.0-1.noarch.rpm"
    "${VMIN_GPL_NOARCH}/wbm-virtualmin-dav-3.13-1.noarch.rpm"
    "${VMIN_GPL_NOARCH}/wbm-virtualmin-git-1.15-1.noarch.rpm"
    "${VMIN_GPL_NOARCH}/wbm-virtualmin-nginx-2.40-1.noarch.rpm"
    "${VMIN_GPL_NOARCH}/wbm-virtualmin-nginx-ssl-1.31-1.noarch.rpm"
    "${VMIN_GPL_NOARCH}/wbm-jailkit-1.1-1.noarch.rpm"
    "${VMIN_GPL_NOARCH}/wbm-virtualmin-init-2.10-1.noarch.rpm"
    "${VMIN_GPL_NOARCH}/wbm-virtualmin-svn-5.1-1.noarch.rpm"
    "${VMIN_GPL_NOARCH}/wbm-virtualmin-vsftpd-1.11-1.noarch.rpm"
    "${VMIN_GPL_NOARCH}/wbm-ruby-gems-1.9-1.noarch.rpm"
    "${VMIN_GPL_NOARCH}/wbm-virtualmin-sqlite-1.8-1.noarch.rpm"
    "${VMIN_GPL_NOARCH}/perl-Authen-OATH-2.0.1-16.el8.vm.noarch.rpm"
    "${VMIN_GPL_NOARCH}/perl-Term-Spinner-Color-0.05-1.noarch.rpm"
)

for url in "${VMIN_GPL_DIRECT[@]}"; do
    download_rpm "$url"
done

# ── System packages (from Rocky Linux repos) ──────────────────────────────────
log "=== System Packages ==="
SYS_PKGS=(
    bind
    bind-utils
    dhcp-server
    mariadb-server
    postgresql-server
    libvirt
    libvirt-daemon-kvm
    qemu-kvm
    virt-install
    perl-libwww-perl
    perl-LWP-Protocol-https
    perl-JSON
    perl-URI
    perl-HTTP-Message
    perl-Net-SSLeay
    perl-IO-Socket-SSL
    createrepo_c
    firewalld
)

for pkg in "${SYS_PKGS[@]}"; do
    dnf_download "$pkg"
done

# ── Build local repo index ─────────────────────────────────────────────────────
if command -v createrepo_c &>/dev/null; then
    log "=== Building repo index ==="
    createrepo_c "$REPO_DIR"
    log "Repo index created"
else
    warn "createrepo_c not found — run it manually on $REPO_DIR before building the RPM"
fi

RPM_COUNT=$(ls "$REPO_DIR"/*.rpm 2>/dev/null | wc -l)
log "=== Done: ${RPM_COUNT} RPMs in $REPO_DIR ==="
log "Next step: make rpm"
