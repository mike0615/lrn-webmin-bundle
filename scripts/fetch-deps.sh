#!/usr/bin/env bash
# fetch-deps.sh — Download all RPMs needed for the air-gapped bundle.
# Run this on an internet-connected machine BEFORE running `make rpm`.
# Output: SOURCES/repo/ populated with all required RPMs.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)/SOURCES/repo"
EL_VER="${EL_VER:-9}"
ARCH="${ARCH:-x86_64}"

# Webmin / Virtualmin repo URLs
WEBMIN_REPO="https://download.webmin.com/download/newkey/yum/noarch"
VMIN_REPO="https://software.virtualmin.com/vm/7/rpm/el${EL_VER}/${ARCH}"
VMIN_NOARCH="https://software.virtualmin.com/vm/7/rpm/el${EL_VER}/noarch"

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

# ── Webmin ─────────────────────────────────────────────────────────────────────
log "=== Webmin ==="
WEBMIN_RPM_URL="https://www.webmin.com/download/rpm/webmin-current.rpm"
download_rpm "$WEBMIN_RPM_URL"

# ── Virtualmin GPL packages ────────────────────────────────────────────────────
log "=== Virtualmin GPL ==="
VMIN_PKGS=(
    "wbm-virtual-server"
    "wbm-virtualmin-htpasswd"
    "wbm-virtualmin-awstats"
    "wbm-virtualmin-dav"
    "wbm-virtualmin-spamassassin"
    "virtualmin-config"
    "virtualmin-lamp-stack"
    "wbm-jailkit"
    "wbm-phpini"
)

# Add Virtualmin repo temporarily
VMIN_REPO_FILE="/etc/yum.repos.d/virtualmin-fetch-tmp.repo"
cat > "$VMIN_REPO_FILE" <<EOF
[virtualmin-fetch]
name=Virtualmin EL${EL_VER}
baseurl=${VMIN_REPO}
enabled=1
gpgcheck=0

[virtualmin-fetch-noarch]
name=Virtualmin EL${EL_VER} noarch
baseurl=${VMIN_NOARCH}
enabled=1
gpgcheck=0
EOF

for pkg in "${VMIN_PKGS[@]}"; do
    dnf_download "$pkg"
done

rm -f "$VMIN_REPO_FILE"

# ── System packages (from Rocky Linux repos) ──────────────────────────────────
log "=== System Packages ==="
SYS_PKGS=(
    bind
    bind-utils
    dhcp-server
    mysql-server
    postgresql-server
    libvirt
    libvirt-daemon-kvm
    qemu-kvm
    virt-install
    perl-LWP-UserAgent
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
