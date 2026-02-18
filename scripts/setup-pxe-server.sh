#!/bin/bash
# PXE server setup for Vault Cube image deployment (Legacy BIOS)
# Sets up TFTP and HTTP servers for network-based image deployment
#
# Usage:
#   ./scripts/setup-pxe-server.sh [IMAGE_PATH] [SERVER_IP]
#
# Example:
#   ./scripts/setup-pxe-server.sh packer/ubuntu-24.04/output-baremetal/vault-cube-baremetal.raw

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=============================================="
echo "Vault Cube PXE Server Setup"
echo "(Legacy BIOS Network Boot)"
echo -e "===============================================${NC}"
echo ""

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PXE_ROOT="/tmp/pxe-boot"
IMAGE_PATH="${1:-$PROJECT_ROOT/packer/ubuntu-24.04/output-baremetal/vault-cube-baremetal.raw}"

# Auto-detect server IP (prefer en0 for macOS, fall back to other interfaces)
detect_ip() {
    # Try en0 first (common macOS ethernet/wifi)
    local ip=$(ipconfig getifaddr en0 2>/dev/null || true)
    if [ -n "$ip" ]; then
        echo "$ip"
        return
    fi

    # Try en1
    ip=$(ipconfig getifaddr en1 2>/dev/null || true)
    if [ -n "$ip" ]; then
        echo "$ip"
        return
    fi

    # Linux fallback
    ip=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
    if [ -n "$ip" ]; then
        echo "$ip"
        return
    fi

    echo "192.168.1.100"  # Fallback default
}

SERVER_IP="${2:-$(detect_ip)}"

echo "Configuration:"
echo "  Image:     $IMAGE_PATH"
echo "  Server IP: $SERVER_IP"
echo "  PXE Root:  $PXE_ROOT"
echo ""

# Validate image exists
if [ ! -f "$IMAGE_PATH" ]; then
    echo -e "${RED}ERROR: Image not found: $IMAGE_PATH${NC}"
    echo ""
    echo "Build the image first:"
    echo "  ./scripts/build-via-virtualbox.sh"
    exit 1
fi

IMAGE_SIZE=$(ls -lh "$IMAGE_PATH" | awk '{print $5}')
echo -e "${GREEN}Image found: $IMAGE_PATH ($IMAGE_SIZE)${NC}"
echo ""

# =============================================================================
# Create Directory Structure
# =============================================================================

echo -e "${YELLOW}Creating PXE directory structure...${NC}"

mkdir -p "$PXE_ROOT"/{tftpboot/pxelinux.cfg,images}

# =============================================================================
# Download PXELINUX Bootloader (Legacy BIOS)
# =============================================================================

echo ""
echo -e "${YELLOW}Setting up PXELINUX bootloader...${NC}"

cd "$PXE_ROOT/tftpboot"

if [ ! -f pxelinux.0 ]; then
    echo "Downloading syslinux..."

    # Download syslinux for pxelinux.0
    curl -sL https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.gz -o syslinux.tar.gz
    tar -xzf syslinux.tar.gz

    # Copy required BIOS boot files
    cp syslinux-6.03/bios/core/pxelinux.0 .
    cp syslinux-6.03/bios/com32/elflink/ldlinux/ldlinux.c32 .
    cp syslinux-6.03/bios/com32/lib/libcom32.c32 .
    cp syslinux-6.03/bios/com32/libutil/libutil.c32 .
    cp syslinux-6.03/bios/com32/menu/menu.c32 .

    # Cleanup
    rm -rf syslinux-6.03 syslinux.tar.gz

    echo -e "${GREEN}PXELINUX bootloader installed${NC}"
else
    echo -e "${GREEN}PXELINUX bootloader already exists${NC}"
fi

# =============================================================================
# Download Ubuntu Live Boot Files
# =============================================================================

echo ""
echo -e "${YELLOW}Setting up Ubuntu live boot environment...${NC}"

if [ ! -f vmlinuz ] || [ ! -f initrd ]; then
    echo "Downloading Ubuntu 24.04 live boot files..."

    # Use Ubuntu 24.04 casper (live) kernel and initrd
    # These are from the live server ISO, which provides a minimal rescue environment
    UBUNTU_MIRROR="http://archive.ubuntu.com/ubuntu/dists/noble/main/installer-amd64/current/legacy-images/netboot/ubuntu-installer/amd64"

    # Download kernel
    echo "  Downloading kernel (vmlinuz)..."
    curl -sL "$UBUNTU_MIRROR/linux" -o vmlinuz

    # Download initrd
    echo "  Downloading initrd..."
    curl -sL "$UBUNTU_MIRROR/initrd.gz" -o initrd

    echo -e "${GREEN}Boot files downloaded${NC}"
else
    echo -e "${GREEN}Boot files already exist${NC}"
fi

# =============================================================================
# Create Deployment Script (embedded in initrd would be complex, so we'll
# provide instructions for manual deployment after PXE boot)
# =============================================================================

echo ""
echo -e "${YELLOW}Creating deployment helper script...${NC}"

cat > "$PXE_ROOT/images/deploy.sh" << 'DEPLOY_SCRIPT'
#!/bin/bash
# Vault Cube Image Deployment Script
# Run this after PXE booting into rescue environment

set -e

SERVER_IP="${1:-REPLACE_SERVER_IP}"
TARGET_DISK="${2:-/dev/nvme0n1}"
IMAGE_URL="http://${SERVER_IP}:8080/vault-cube-baremetal.raw"

echo "=============================================="
echo "Vault Cube Image Deployment"
echo "=============================================="
echo ""
echo "Server:      $SERVER_IP"
echo "Image URL:   $IMAGE_URL"
echo "Target Disk: $TARGET_DISK"
echo ""

# Check target disk exists
if [ ! -b "$TARGET_DISK" ]; then
    echo "ERROR: Target disk not found: $TARGET_DISK"
    echo ""
    echo "Available disks:"
    lsblk
    exit 1
fi

# Confirm
read -p "WARNING: This will ERASE $TARGET_DISK. Continue? (yes/no) " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "Downloading and writing image..."
echo "This will take several minutes depending on network speed."
echo ""

# Download and write image
wget -O - "$IMAGE_URL" | dd of="$TARGET_DISK" bs=4M status=progress

# Sync
echo ""
echo "Syncing..."
sync

echo ""
echo "=============================================="
echo "Deployment complete!"
echo "=============================================="
echo ""
echo "Remove network boot and reboot into installed system:"
echo "  reboot"
DEPLOY_SCRIPT

# Replace placeholder with actual server IP
sed -i '' "s/REPLACE_SERVER_IP/$SERVER_IP/g" "$PXE_ROOT/images/deploy.sh" 2>/dev/null || \
sed -i "s/REPLACE_SERVER_IP/$SERVER_IP/g" "$PXE_ROOT/images/deploy.sh"

chmod +x "$PXE_ROOT/images/deploy.sh"

# =============================================================================
# Copy Image to HTTP Directory
# =============================================================================

echo ""
echo -e "${YELLOW}Setting up image for HTTP serving...${NC}"

# Instead of copying (which uses disk space), create a symlink
cd "$PXE_ROOT/images"
ln -sf "$IMAGE_PATH" vault-cube-baremetal.raw 2>/dev/null || cp "$IMAGE_PATH" vault-cube-baremetal.raw

echo -e "${GREEN}Image ready for HTTP serving${NC}"

# =============================================================================
# Create PXE Boot Menu
# =============================================================================

echo ""
echo -e "${YELLOW}Creating PXE boot menu...${NC}"

cat > "$PXE_ROOT/tftpboot/pxelinux.cfg/default" << EOF
# Vault Cube PXE Boot Menu (Legacy BIOS)

UI menu.c32
PROMPT 0
TIMEOUT 100
MENU TITLE Vault Cube Deployment

LABEL deploy
  MENU LABEL ^1. Install Vault Cube (Network Deploy)
  KERNEL vmlinuz
  APPEND initrd=initrd auto=true priority=critical --- quiet

LABEL rescue
  MENU LABEL ^2. Rescue Mode (Manual Deployment)
  KERNEL vmlinuz
  APPEND initrd=initrd rescue/enable=true --- quiet

LABEL local
  MENU LABEL ^3. Boot from Local Disk
  LOCALBOOT 0
EOF

echo -e "${GREEN}PXE menu created${NC}"

# =============================================================================
# Create dnsmasq Config
# =============================================================================

echo ""
echo -e "${YELLOW}Creating dnsmasq configuration...${NC}"

CONFIG_DIR="$PROJECT_ROOT/config"
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_DIR/dnsmasq-pxe.conf" << EOF
# PXE Boot Configuration for Vault Cube Deployment (Legacy BIOS)
# Run with: sudo dnsmasq -d -C config/dnsmasq-pxe.conf
#
# NOTE: Only use this if you don't have an existing DHCP server on the network.
# If you have a router providing DHCP, use proxy mode instead (see below).

# Network interface (change to match your setup)
# macOS: typically en0 (ethernet) or en1 (wifi)
# Linux: typically eth0, enp0s3, etc.
interface=en0

# DHCP range - adjust to your network
# Format: start-ip,end-ip,lease-time
dhcp-range=192.168.1.200,192.168.1.250,12h

# Legacy BIOS PXE boot
dhcp-boot=pxelinux.0

# TFTP server settings
enable-tftp
tftp-root=$PXE_ROOT/tftpboot

# Logging (helpful for debugging)
log-dhcp
log-queries

# ============================================================================
# ALTERNATIVE: Proxy DHCP Mode
# ============================================================================
# Use this configuration if you already have a DHCP server (router, etc.)
# Comment out the dhcp-range line above and uncomment these:
#
# dhcp-range=192.168.1.0,proxy
# pxe-service=x86PC,"Install Vault Cube",pxelinux
# ============================================================================
EOF

echo -e "${GREEN}dnsmasq configuration created at: $CONFIG_DIR/dnsmasq-pxe.conf${NC}"

# =============================================================================
# Summary and Instructions
# =============================================================================

cd "$PROJECT_ROOT"

echo ""
echo -e "${BLUE}=============================================="
echo "PXE Server Setup Complete!"
echo -e "===============================================${NC}"
echo ""
echo "Directory structure created:"
echo "  $PXE_ROOT/"
echo "  ├── tftpboot/"
echo "  │   ├── pxelinux.0      (bootloader)"
echo "  │   ├── ldlinux.c32     (required module)"
echo "  │   ├── menu.c32        (menu system)"
echo "  │   ├── vmlinuz         (kernel)"
echo "  │   ├── initrd          (initial ramdisk)"
echo "  │   └── pxelinux.cfg/"
echo "  │       └── default     (boot menu)"
echo "  └── images/"
echo "      ├── vault-cube-baremetal.raw  (disk image)"
echo "      └── deploy.sh       (deployment script)"
echo ""
echo -e "${GREEN}=== Starting the PXE Server ===${NC}"
echo ""
echo "Open 3 terminal windows and run:"
echo ""
echo -e "${YELLOW}Terminal 1 - TFTP Server (port 69):${NC}"
echo "  sudo python3 -m py3tftp --host 0.0.0.0 -p 69 -r $PXE_ROOT/tftpboot"
echo ""
echo "  If py3tftp not installed: pip3 install py3tftp"
echo "  Alternative: brew install tftp-hpa && sudo in.tftpd -L -s $PXE_ROOT/tftpboot"
echo ""
echo -e "${YELLOW}Terminal 2 - HTTP Server (port 8080):${NC}"
echo "  cd $PXE_ROOT/images && python3 -m http.server 8080"
echo ""
echo -e "${YELLOW}Terminal 3 - DHCP/PXE (if no existing DHCP):${NC}"
echo "  sudo dnsmasq -d -C $CONFIG_DIR/dnsmasq-pxe.conf"
echo ""
echo "  If using existing DHCP server, configure it to point to:"
echo "    next-server: $SERVER_IP"
echo "    filename: pxelinux.0"
echo ""
echo -e "${GREEN}=== Deploying to Appliance ===${NC}"
echo ""
echo "1. Configure appliance BIOS for network boot (PXE)"
echo "2. Start all 3 servers above"
echo "3. Boot the appliance - it should:"
echo "   a. Get IP via DHCP"
echo "   b. Download pxelinux.0 via TFTP"
echo "   c. Show boot menu"
echo ""
echo "4. Select 'Rescue Mode' and wait for shell prompt"
echo ""
echo "5. In rescue shell, configure networking (if not automatic):"
echo "   ip addr  # check if IP assigned"
echo "   dhclient eth0  # if needed"
echo ""
echo "6. Download and run deployment script:"
echo "   wget http://$SERVER_IP:8080/deploy.sh"
echo "   chmod +x deploy.sh"
echo "   ./deploy.sh $SERVER_IP /dev/nvme0n1"
echo ""
echo "7. Or deploy manually:"
echo "   wget http://$SERVER_IP:8080/vault-cube-baremetal.raw -O - | dd of=/dev/nvme0n1 bs=4M status=progress"
echo "   sync && reboot"
echo ""
echo -e "${GREEN}Done!${NC}"
