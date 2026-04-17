#!/usr/bin/env bash
# LRN Webmin Bundle Installer
# Author: LRN-MAN, Planet Maytag
set -euo pipefail

BUNDLE_DIR="/opt/lrn-webmin-bundle"
REPO_DIR="${BUNDLE_DIR}/repo"
MODULE_DIR="${BUNDLE_DIR}/modules"
WEBMIN_MODULE_DIR="/usr/share/webmin"
WEBMIN_ETC="/etc/webmin"
REPO_FILE="/etc/yum.repos.d/lrn-webmin-local.repo"
LOG="/var/log/lrn-webmin-bundle-install.log"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*" | tee -a "$LOG"; }
warn() { echo -e "${YELLOW}[!]${NC} $*" | tee -a "$LOG"; }
die()  { echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG"; exit 1; }
section() { echo -e "\n${YELLOW}=== $* ===${NC}\n" | tee -a "$LOG"; }

# ── Preflight ──────────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "Must be run as root"
mkdir -p "$(dirname "$LOG")"
date >> "$LOG"

section "Preflight Checks"
log "Host: $(hostname -f)"
OS_RELEASE=$(cat /etc/rocky-release 2>/dev/null || grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
log "OS:   $OS_RELEASE"
log "Arch: $(uname -m)"

# Detect EL version
EL_VER=$(rpm -E '%{rhel}' 2>/dev/null || echo "9")
log "EL:   ${EL_VER}"

if [[ ! -d "$REPO_DIR" ]] || [[ -z "$(ls -A "$REPO_DIR" 2>/dev/null)" ]]; then
    warn "Offline repo not found at $REPO_DIR"
    warn "Package installation will require network access or manually populated repo."
    OFFLINE=false
else
    log "Offline repo found: $(ls "$REPO_DIR"/*.rpm 2>/dev/null | wc -l) RPMs available"
    OFFLINE=true
fi

# ── Local repo setup ───────────────────────────────────────────────────────────
if [[ "$OFFLINE" == "true" ]]; then
    section "Configuring Local DNF Repository"

    if ! command -v createrepo_c &>/dev/null; then
        # Bootstrap createrepo_c from the bundle itself
        rpm -ivh "${REPO_DIR}"/createrepo_c-*.rpm 2>/dev/null \
            || die "createrepo_c not found and could not be installed from bundle"
    fi

    createrepo_c --quiet "$REPO_DIR" 2>&1 | tee -a "$LOG" || true

    cat > "$REPO_FILE" <<EOF
[lrn-webmin-local]
name=LRN Webmin Bundle Local Repository
baseurl=file://${REPO_DIR}
enabled=1
gpgcheck=0
priority=1
EOF
    log "Local repo configured: $REPO_FILE"
    DNF_OPTS="--disablerepo='*' --enablerepo='lrn-webmin-local'"
else
    warn "Using system DNF repos (network required)"
    DNF_OPTS=""
fi

# ── Install Webmin ─────────────────────────────────────────────────────────────
section "Installing Webmin"

if rpm -q webmin &>/dev/null; then
    log "Webmin already installed: $(rpm -q webmin)"
else
    # shellcheck disable=SC2086
    dnf install -y $DNF_OPTS webmin 2>&1 | tee -a "$LOG" || die "Failed to install webmin"
    log "Webmin installed"
fi

# ── Install Virtualmin GPL ─────────────────────────────────────────────────────
section "Installing Virtualmin GPL"

VIRT_PKGS=(
    wbm-virtual-server
    wbt-virtual-server-theme
    wbm-virtualmin-htpasswd
    wbm-virtualmin-awstats
    wbm-virtualmin-dav
    wbm-virtualmin-git
    wbm-virtualmin-init
    wbm-virtualmin-sqlite
    wbm-jailkit
    virtualmin-config
    usermin
)

for pkg in "${VIRT_PKGS[@]}"; do
    if rpm -q "$pkg" &>/dev/null; then
        log "Already installed: $pkg"
    else
        # shellcheck disable=SC2086
        dnf install -y $DNF_OPTS "$pkg" 2>&1 | tee -a "$LOG" \
            && log "Installed: $pkg" \
            || warn "Package not available (skipping): $pkg"
    fi
done

# ── Install supporting packages ────────────────────────────────────────────────
section "Installing Supporting Packages"

# EL10 replaced ISC dhcp-server with ISC Kea
if [[ "$EL_VER" -ge 10 ]]; then
    DHCP_PKG="kea"
    log "EL${EL_VER}: using Kea DHCP server (replaces dhcp-server)"
else
    DHCP_PKG="dhcp-server"
fi

SUPPORT_PKGS=(
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
    firewalld
)

for pkg in "${SUPPORT_PKGS[@]}"; do
    # shellcheck disable=SC2086
    dnf install -y $DNF_OPTS "$pkg" 2>&1 | tee -a "$LOG" \
        && log "Installed: $pkg" \
        || warn "Package not available (skipping): $pkg"
done

# EL10 Kea: enable dhcp4 service instead of dhcpd
if [[ "$EL_VER" -ge 10 ]]; then
    log "Note: DHCP managed by Kea — use 'kea-dhcp4' service and /etc/kea/kea-dhcp4.conf"
    log "      Webmin DHCP module (wbm-dhcpd) targets ISC dhcpd; manage Kea via LRN Service Panels"
fi

# ── Install LRN custom Webmin modules ─────────────────────────────────────────
section "Installing LRN Service Panels Module"

if [[ ! -d "$WEBMIN_MODULE_DIR" ]]; then
    die "Webmin module directory not found: $WEBMIN_MODULE_DIR"
fi

for mod_path in "$MODULE_DIR"/*/; do
    mod_name=$(basename "$mod_path")
    dest="$WEBMIN_MODULE_DIR/$mod_name"
    if [[ -d "$dest" ]]; then
        log "Updating module: $mod_name"
        rm -rf "$dest"
    else
        log "Installing module: $mod_name"
    fi
    cp -r "$mod_path" "$dest"
    find "$dest" -name '*.cgi' -exec chmod 755 {} \;
    find "$dest" -name '*.pl'  -exec chmod 644 {} \;
done

# Create module config directory
IFRAME_CONF="$WEBMIN_ETC/lrn-iframe-wrapper"
if [[ ! -d "$IFRAME_CONF" ]]; then
    mkdir -p "$IFRAME_CONF"
    if [[ -f "$WEBMIN_MODULE_DIR/lrn-iframe-wrapper/config" ]]; then
        cp "$WEBMIN_MODULE_DIR/lrn-iframe-wrapper/config" "$IFRAME_CONF/config"
    fi
fi

# Register modules with Webmin
if command -v /usr/share/webmin/acl/save_user_module.pl &>/dev/null; then
    perl /usr/share/webmin/acl/save_user_module.pl root lrn-iframe-wrapper 2>/dev/null || true
fi

# ── Enable & start Webmin ──────────────────────────────────────────────────────
section "Enabling Webmin Service"

systemctl enable webmin 2>&1 | tee -a "$LOG"
systemctl restart webmin 2>&1 | tee -a "$LOG"
log "Webmin service: $(systemctl is-active webmin)"

# ── Firewall ───────────────────────────────────────────────────────────────────
section "Configuring Firewall"

if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-port=10000/tcp 2>&1 | tee -a "$LOG"
    firewall-cmd --reload 2>&1 | tee -a "$LOG"
    log "Firewall: port 10000/tcp opened"
else
    warn "firewalld not running — ensure port 10000/tcp is accessible"
fi

# ── Cleanup ────────────────────────────────────────────────────────────────────
if [[ -f "$REPO_FILE" ]]; then
    log "Local DNF repo file left in place: $REPO_FILE"
    log "Remove it with: rm $REPO_FILE  (if no longer needed)"
fi

section "Installation Complete"
cat <<EOF
  Webmin:     https://$(hostname -f):10000
  Virtualmin: https://$(hostname -f):10000/virtual-server/
  Log:        $LOG

  LRN Service Panels (FreeIPA, Ansible, XMPP, Cockpit):
    Webmin → Others → LRN Service Panels
EOF
