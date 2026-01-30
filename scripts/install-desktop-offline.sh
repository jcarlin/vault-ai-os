#!/bin/bash
# install-desktop-offline.sh
# Install Ubuntu Desktop (GNOME) packages from offline USB/ISO
#
# ============================================================================
# OVERVIEW
# ============================================================================
# This script is used AFTER the base server OS is installed. It installs
# the Ubuntu Desktop environment (GNOME) from pre-downloaded packages,
# allowing GUI installation on air-gapped systems without network access.
#
# ============================================================================
# PREREQUISITES
# ============================================================================
# - Ubuntu 24.04 Server installed and running (from the autoinstall ISO)
# - USB drive or ISO file containing the desktop packages
# - Root/sudo access
#
# ============================================================================
# WORKFLOW (for end user)
# ============================================================================
# Step 1: Boot into the installed Ubuntu Server system
#
# Step 2: Insert USB drive containing desktop packages
#         (or copy the ISO file to the system)
#
# Step 3: Mount the USB drive or ISO:
#         USB:  sudo mount /dev/sdb1 /mnt
#         ISO:  sudo mount -o loop vault-cube-desktop-packages.iso /mnt
#
# Step 4: Copy this script and run it:
#         sudo cp /mnt/install-desktop-offline.sh /tmp/
#         sudo bash /tmp/install-desktop-offline.sh /mnt
#
# Step 5: Reboot when prompted
#         sudo reboot
#
# Step 6: Login at the graphical GNOME login screen
#
# ============================================================================
# USAGE
# ============================================================================
#   sudo ./install-desktop-offline.sh /path/to/mounted/usb-or-iso
#
# Examples:
#   sudo ./install-desktop-offline.sh /mnt
#   sudo ./install-desktop-offline.sh /media/usb
#   sudo ./install-desktop-offline.sh /mnt/iso

set -e

SCRIPT_NAME=$(basename "$0")
PACKAGES_DIR="${1:-/mnt/usb}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

# Check if packages directory exists
if [[ ! -d "$PACKAGES_DIR" ]]; then
    log_error "Packages directory not found: $PACKAGES_DIR"
    echo "Usage: sudo $SCRIPT_NAME /path/to/packages"
    echo ""
    echo "Mount your USB or ISO first:"
    echo "  USB: sudo mount /dev/sdX1 /mnt/usb"
    echo "  ISO: sudo mount -o loop vault-cube-desktop-packages.iso /mnt/iso"
    exit 1
fi

# Count .deb files
DEB_COUNT=$(find "$PACKAGES_DIR" -maxdepth 1 -name "*.deb" 2>/dev/null | wc -l)

if [[ $DEB_COUNT -eq 0 ]]; then
    log_error "No .deb files found in $PACKAGES_DIR"
    log_info "Looking for packages in subdirectories..."

    # Try to find packages in subdirectories
    if [[ -d "$PACKAGES_DIR/desktop-packages" ]]; then
        PACKAGES_DIR="$PACKAGES_DIR/desktop-packages"
        DEB_COUNT=$(find "$PACKAGES_DIR" -maxdepth 1 -name "*.deb" 2>/dev/null | wc -l)
    fi

    if [[ $DEB_COUNT -eq 0 ]]; then
        log_error "No .deb files found. Ensure the ISO/USB contains the desktop packages."
        exit 1
    fi
fi

log_info "Found $DEB_COUNT .deb packages in $PACKAGES_DIR"

# Confirm installation
echo ""
echo "This will install Ubuntu Desktop packages from: $PACKAGES_DIR"
echo "This includes GNOME desktop environment and related applications."
echo ""
read -p "Continue with installation? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Installation cancelled."
    exit 0
fi

# Create temporary directory for dpkg
log_info "Preparing installation..."
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Install packages using dpkg
log_info "Installing packages (this may take several minutes)..."
echo ""

# Use dpkg to install all packages at once
# The --force-depends handles dependency ordering issues during batch install
# We'll run it twice to resolve circular dependencies
cd "$PACKAGES_DIR"

log_info "First pass: Installing packages..."
dpkg -i --force-depends *.deb 2>&1 | tee "$TEMP_DIR/dpkg-pass1.log" || true

log_info "Second pass: Fixing any broken dependencies..."
dpkg --configure -a 2>&1 | tee "$TEMP_DIR/dpkg-pass2.log" || true

# Fix any remaining broken dependencies
log_info "Running apt-get fix for any remaining issues..."
apt-get -f install -y 2>&1 | tee "$TEMP_DIR/apt-fix.log" || true

# Verify ubuntu-desktop is installed
if dpkg -l ubuntu-desktop 2>/dev/null | grep -q "^ii"; then
    log_info "ubuntu-desktop package verified as installed"
else
    log_warn "ubuntu-desktop package may not be fully installed"
    log_info "You may need to run: sudo apt-get -f install"
fi

# Configure display manager
log_info "Configuring GDM display manager..."
if dpkg -l gdm3 2>/dev/null | grep -q "^ii"; then
    systemctl set-default graphical.target
    systemctl enable gdm3 2>/dev/null || true
    log_info "GDM enabled and set as default"
else
    log_warn "GDM not found, trying alternative display managers..."
    for dm in lightdm sddm; do
        if dpkg -l $dm 2>/dev/null | grep -q "^ii"; then
            systemctl set-default graphical.target
            systemctl enable $dm 2>/dev/null || true
            log_info "$dm enabled and set as default"
            break
        fi
    done
fi

# Summary
echo ""
echo "=========================================="
log_info "Installation complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Reboot the system: sudo reboot"
echo "  2. At the login screen, select your user"
echo "  3. Before entering password, click the gear icon"
echo "     to select 'Ubuntu' or 'GNOME' session"
echo ""
echo "If you encounter issues:"
echo "  - Run: sudo dpkg --configure -a"
echo "  - Run: sudo apt-get -f install"
echo "  - Check logs in: $TEMP_DIR"
echo ""
log_info "Reboot when ready: sudo reboot"
