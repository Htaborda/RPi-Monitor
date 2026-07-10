#!/bin/bash
# RPi-Monitor installer for Raspberry Pi OS (Bookworm and later)
#
# This script installs RPi-Monitor from source and configures it for
# modern Raspberry Pi OS. It replaces the old apt-key-based approach
# that no longer works on Debian 12 (Bookworm) and later.
#
# Usage:
#   sudo bash install.sh
#
# Requirements:
#   - Raspberry Pi running Raspberry Pi OS (Bookworm or later recommended)
#   - Internet access (for installing Perl dependencies via apt)
#   - Run as root (sudo)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -----------------------------------------------------------------------
# Colour helpers
# -----------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# -----------------------------------------------------------------------
# Root check
# -----------------------------------------------------------------------
[ "$(id -u)" -eq 0 ] || error "This script must be run as root. Use: sudo bash install.sh"

# -----------------------------------------------------------------------
# Detect OS
# -----------------------------------------------------------------------
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="${ID}"
    OS_VERSION="${VERSION_CODENAME:-unknown}"
else
    OS_ID="unknown"
    OS_VERSION="unknown"
fi
info "Detected OS: ${OS_ID} ${OS_VERSION}"

# -----------------------------------------------------------------------
# Install Perl dependencies
# -----------------------------------------------------------------------
info "Updating apt package lists..."
apt-get update -qq

info "Installing Perl dependencies..."
apt-get install -y \
    librrds-perl \
    libhttp-daemon-perl \
    libjson-perl \
    libipc-sharelite-perl \
    libfile-which-perl \
    rrdtool \
    perl

# -----------------------------------------------------------------------
# Create dedicated system user/group for rpimonitor
# (Raspberry Pi OS Bookworm+ no longer creates a default 'pi' user)
# -----------------------------------------------------------------------
if ! id -u rpimonitor &>/dev/null; then
    info "Creating system user 'rpimonitor'..."
    adduser --system --group --no-create-home --shell /bin/false rpimonitor
else
    info "User 'rpimonitor' already exists, skipping."
fi

# Add rpimonitor to the 'video' group so vcgencmd works without root
if getent group video &>/dev/null; then
    usermod -aG video rpimonitor
    info "Added 'rpimonitor' user to 'video' group (required for vcgencmd)."
fi

# Add rpimonitor to the 'gpio' group for GPIO access if present
if getent group gpio &>/dev/null; then
    usermod -aG gpio rpimonitor
fi

# -----------------------------------------------------------------------
# Create required directories
# -----------------------------------------------------------------------
info "Creating directories..."
mkdir -p /var/lib/rpimonitor/stat
mkdir -p /var/log
mkdir -p /etc/rpimonitor/template
mkdir -p /usr/share/rpimonitor/{web,scripts}
mkdir -p /usr/bin
mkdir -p /etc/cron.d
mkdir -p /usr/lib/systemd/system

# -----------------------------------------------------------------------
# Install files from source tree
# -----------------------------------------------------------------------
info "Installing RPi-Monitor files..."

# Data directory
cp -r "${SCRIPT_DIR}/src/var/lib/rpimonitor/"* /var/lib/rpimonitor/

# Configuration
cp -r "${SCRIPT_DIR}/src/etc/rpimonitor/"* /etc/rpimonitor/

# Cron job
cp "${SCRIPT_DIR}/src/etc/cron.d/rpimonitor" /etc/cron.d/rpimonitor
chmod 644 /etc/cron.d/rpimonitor

# Main daemon binary
cp "${SCRIPT_DIR}/src/usr/bin/rpimonitord" /usr/bin/rpimonitord
chmod 755 /usr/bin/rpimonitord

# Web assets and helper scripts
cp -r "${SCRIPT_DIR}/src/usr/share/rpimonitor/"* /usr/share/rpimonitor/
chmod 755 /usr/share/rpimonitor/scripts/*.pl 2>/dev/null || true
chmod 755 /usr/share/rpimonitor/scripts/*.sh 2>/dev/null || true

# Systemd service (preferred on all modern Raspberry Pi OS)
cp "${SCRIPT_DIR}/src/usr/lib/systemd/system/rpimonitord.service" \
   /usr/lib/systemd/system/rpimonitord.service
cp "${SCRIPT_DIR}/src/usr/lib/systemd/system/rpimonitord-upgradable.service" \
   /usr/lib/systemd/system/rpimonitord-upgradable.service 2>/dev/null || true
cp "${SCRIPT_DIR}/src/usr/lib/systemd/system/rpimonitord-upgradable.timer" \
   /usr/lib/systemd/system/rpimonitord-upgradable.timer 2>/dev/null || true

# -----------------------------------------------------------------------
# Set ownership
# -----------------------------------------------------------------------
info "Setting file ownership..."
chown -R rpimonitor:rpimonitor /var/lib/rpimonitor
chown rpimonitor:rpimonitor /usr/share/rpimonitor/scripts/*.pl 2>/dev/null || true

# -----------------------------------------------------------------------
# Update the default data.conf to point to the Raspberry Pi template
# (the file ships with just the filename; ensure it's absolute)
# -----------------------------------------------------------------------
if [ -f /etc/rpimonitor/data.conf ] && \
   grep -q '^template/' /etc/rpimonitor/data.conf; then
    sed -i 's|^template/|/etc/rpimonitor/template/|' /etc/rpimonitor/data.conf
    info "Updated data.conf to use absolute path for template."
fi

# -----------------------------------------------------------------------
# Write initial empty updatestatus.txt if missing
# -----------------------------------------------------------------------
if [ ! -f /var/lib/rpimonitor/updatestatus.txt ]; then
    echo "   0 upgradable(s)" > /var/lib/rpimonitor/updatestatus.txt
    chown rpimonitor:rpimonitor /var/lib/rpimonitor/updatestatus.txt
fi

# -----------------------------------------------------------------------
# Enable and start rpimonitord via systemd
# -----------------------------------------------------------------------
if command -v systemctl &>/dev/null; then
    info "Reloading systemd and enabling rpimonitord..."
    systemctl daemon-reload
    systemctl enable rpimonitord
    systemctl restart rpimonitord && \
        info "rpimonitord started successfully." || \
        warn "rpimonitord failed to start. Check: journalctl -u rpimonitord"
else
    warn "systemd not found. Start rpimonitord manually: /usr/bin/rpimonitord"
fi

# -----------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------
info "-------------------------------------------------------"
info "RPi-Monitor installation complete!"
info "Access the web interface at: http://$(hostname -I | awk '{print $1}'):8888"
info ""
info "To check status:   systemctl status rpimonitord"
info "To view logs:      journalctl -u rpimonitord -f"
info "To stop:           systemctl stop rpimonitord"
info "-------------------------------------------------------"
