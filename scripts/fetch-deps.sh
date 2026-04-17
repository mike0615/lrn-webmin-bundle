#!/usr/bin/env bash
# fetch-deps.sh — Download all RPMs needed for the air-gapped bundle.
# Run this on an internet-connected machine BEFORE running `make rpm`.
# Output: SOURCES/repo-el<EL_VER>/ populated with all required RPMs.
#
# Usage:
#   ./scripts/fetch-deps.sh              # EL9 (default)
#   EL_VER=10 ./scripts/fetch-deps.sh   # EL10
set -euo pipefail

EL_VER="${EL_VER:-9}"
ARCH="${ARCH:-x86_64}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Allow REPO_DIR override from environment (used when running inside a container)
REPO_DIR="${REPO_DIR:-${ROOT}/SOURCES/repo-el${EL_VER}}"

# Virtualmin GPL repo (noarch — same packages for all EL versions)
VMIN_GPL_NOARCH="https://software.virtualmin.com/vm/7/gpl/rpm/noarch"

# Rocky Linux mirror base
ROCKY_MIRROR="https://dl.rockylinux.org/pub/rocky/${EL_VER}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
die()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

command -v curl &>/dev/null || die "curl is required"

# ── Cross-version: run inside a Rocky Linux container if EL_VER != host ───────
HOST_EL_VER="$(rpm -E '%{rhel}' 2>/dev/null || echo '9')"

if [[ "$EL_VER" != "$HOST_EL_VER" ]]; then
    if command -v podman &>/dev/null || command -v docker &>/dev/null; then
        RUNTIME=$(command -v podman || command -v docker)
        log "Cross-version build: re-running inside Rocky Linux ${EL_VER} container via $(basename "$RUNTIME")"
        mkdir -p "$REPO_DIR"
        # Mount the repo dir and run this same script inside the container
        mkdir -p "$REPO_DIR"
        "$RUNTIME" run --rm \
            -v "$REPO_DIR:/repo-out:z" \
            -v "$ROOT/scripts:/scripts:z,ro" \
            -e EL_VER="$EL_VER" \
            -e ARCH="$ARCH" \
            -e REPO_DIR=/repo-out \
            "rockylinux:${EL_VER}" \
            bash -c "
                dnf install -y curl createrepo_c 2>&1 | tail -5
                bash /scripts/fetch-deps.sh
            "
        log "Container run complete — packages in $REPO_DIR"
        exit 0
    else
        warn "No podman/docker found; attempting native cross-version download (may have dep conflicts)"
    fi
fi

command -v dnf          &>/dev/null || die "dnf is required"
command -v createrepo_c &>/dev/null || warn "createrepo_c not found — install: dnf install -y createrepo_c"

mkdir -p "$REPO_DIR"
log "Downloading to: $REPO_DIR"
log "Target:         EL${EL_VER} / ${ARCH}"

# ── Helpers ────────────────────────────────────────────────────────────────────
download_rpm() {
    local url="$1"
    local dest="$REPO_DIR/$(basename "$url")"
    if [[ -f "$dest" ]]; then
        log "  Already downloaded: $(basename "$url")"
        return
    fi
    echo -n "  Fetching $(basename "$url") ... "
    if curl -sfL -o "$dest" "$url"; then
        echo "OK"
    else
        warn "FAILED (skipping): $url"
        rm -f "$dest"
    fi
}

dnf_download() {
    local pkg="$1"
    log "Downloading: $pkg"
    # DNF 4 (EL9): dnf download --resolve
    # DNF 5 (EL10): dnf install --downloadonly --destdir
    if dnf download --help &>/dev/null 2>&1; then
        dnf download --resolve --destdir="$REPO_DIR" "$pkg" 2>&1 \
            | grep -vE "^(Last metadata|$)" \
            || warn "dnf download failed for: $pkg (skipping)"
    else
        dnf install --downloadonly --destdir="$REPO_DIR" -y "$pkg" 2>&1 \
            | grep -vE "^(Last metadata|Nothing to do|Complete|Downloading|Total|Running|$)" \
            || warn "dnf install --downloadonly failed for: $pkg (skipping)"
    fi
}

cleanup() { :; }
trap cleanup EXIT

# ── Webmin + Virtualmin GPL (direct URL — noarch, same for all EL) ─────────────
log "=== Webmin + Virtualmin GPL ==="

VMIN_GPL_PKGS=(
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

for url in "${VMIN_GPL_PKGS[@]}"; do
    download_rpm "$url"
done

# ── System packages ────────────────────────────────────────────────────────────
log "=== System Packages ==="

# EL10 replaced ISC dhcp-server with ISC Kea
if [[ "$EL_VER" -ge 10 ]]; then
    DHCP_PKG="kea"
    log "EL${EL_VER}: using kea (replaces dhcp-server)"
else
    DHCP_PKG="dhcp-server"
fi

SYS_PKGS=(
    bind
    bind-utils
    "$DHCP_PKG"
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
    warn "createrepo_c not found — run it manually: createrepo_c $REPO_DIR"
fi

RPM_COUNT=$(find "$REPO_DIR" -maxdepth 1 -name '*.rpm' | wc -l)
log "=== Done: ${RPM_COUNT} RPMs in $REPO_DIR ==="
log "Next step:  make rpm EL_VER=${EL_VER}"
