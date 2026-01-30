#!/bin/bash
# Create bootable Ubuntu 24.04 autoinstall ISO for Vault Cube
# Embeds autoinstall configuration for unattended installation

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
SOURCE_ISO="${1:-}"
OUTPUT_DIR="$PROJECT_ROOT/output"
OUTPUT_ISO="$OUTPUT_DIR/vault-cube-24.04-autoinstall.iso"
WORK_DIR=""

# Autoinstall config sources
USER_DATA="$PROJECT_ROOT/packer/http/user-data"
META_DATA="$PROJECT_ROOT/packer/http/meta-data"

echo -e "${BLUE}=============================================="
echo "Vault Cube Autoinstall ISO Builder"
echo "Ubuntu 24.04 + Embedded Autoinstall"
echo -e "===============================================${NC}"
echo ""

# Print usage
usage() {
    echo "Usage: $0 <path-to-ubuntu-24.04-iso>"
    echo ""
    echo "Arguments:"
    echo "  <path-to-ubuntu-24.04-iso>  Path to Ubuntu 24.04 Live Server ISO"
    echo ""
    echo "Examples:"
    echo "  $0 ~/Downloads/ubuntu-24.04.3-live-server-amd64.iso"
    echo "  $0 /path/to/ubuntu-24.04-live-server-amd64.iso"
    echo ""
    echo "Download Ubuntu 24.04 from: https://releases.ubuntu.com/24.04/"
    exit 1
}

# Cleanup function
cleanup() {
    if [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ]; then
        echo -e "${YELLOW}Cleaning up temporary files...${NC}"
        rm -rf "$WORK_DIR"
    fi
}

# Set trap for cleanup on exit
trap cleanup EXIT

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    local missing=0

    # Check for xorriso
    if ! command -v xorriso &> /dev/null; then
        echo -e "${RED}ERROR: xorriso not found${NC}"
        echo "Install xorriso:"
        echo "  macOS:  brew install xorriso"
        echo "  Ubuntu: sudo apt-get install xorriso"
        echo "  Fedora: sudo dnf install xorriso"
        missing=1
    else
        echo -e "${GREEN}  xorriso: found${NC}"
    fi

    # Check for 7z (p7zip)
    if ! command -v 7z &> /dev/null; then
        echo -e "${RED}ERROR: 7z not found${NC}"
        echo "Install p7zip:"
        echo "  macOS:  brew install p7zip"
        echo "  Ubuntu: sudo apt-get install p7zip-full"
        echo "  Fedora: sudo dnf install p7zip p7zip-plugins"
        missing=1
    else
        echo -e "${GREEN}  7z: found${NC}"
    fi

    if [ $missing -eq 1 ]; then
        echo ""
        echo -e "${RED}Please install missing prerequisites and try again.${NC}"
        exit 1
    fi

    echo ""
}

# Validate source ISO
validate_source_iso() {
    if [ -z "$SOURCE_ISO" ]; then
        echo -e "${RED}ERROR: No source ISO specified${NC}"
        echo ""
        usage
    fi

    if [ ! -f "$SOURCE_ISO" ]; then
        echo -e "${RED}ERROR: Source ISO not found: $SOURCE_ISO${NC}"
        echo ""
        usage
    fi

    # Check if it's an Ubuntu ISO
    if ! echo "$SOURCE_ISO" | grep -qi "ubuntu.*24.04"; then
        echo -e "${YELLOW}WARNING: ISO filename doesn't match Ubuntu 24.04 pattern${NC}"
        echo "Expected pattern: ubuntu-24.04*-live-server-amd64.iso"
        echo ""
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    echo -e "${GREEN}Source ISO: $SOURCE_ISO${NC}"
}

# Validate autoinstall config files
validate_config_files() {
    echo -e "${YELLOW}Validating autoinstall configuration files...${NC}"

    if [ ! -f "$USER_DATA" ]; then
        echo -e "${RED}ERROR: user-data not found: $USER_DATA${NC}"
        exit 1
    fi
    echo -e "${GREEN}  user-data: found${NC}"

    if [ ! -f "$META_DATA" ]; then
        echo -e "${RED}ERROR: meta-data not found: $META_DATA${NC}"
        exit 1
    fi
    echo -e "${GREEN}  meta-data: found${NC}"

    echo ""
}

# Extract ISO
extract_iso() {
    echo -e "${YELLOW}Extracting Ubuntu ISO...${NC}"
    echo "  This may take a few minutes..."

    WORK_DIR=$(mktemp -d)
    local iso_extract="$WORK_DIR/iso-extract"

    mkdir -p "$iso_extract"

    # Extract ISO contents using 7z
    7z x -o"$iso_extract" "$SOURCE_ISO" > /dev/null

    # Remove the [BOOT] catalog directory that 7z creates
    rm -rf "$iso_extract/[BOOT]"

    echo -e "${GREEN}  ISO extracted to: $iso_extract${NC}"
}

# Extract MBR for hybrid boot
extract_mbr() {
    echo -e "${YELLOW}Extracting MBR boot sector...${NC}"

    # Extract the first 432 bytes (MBR boot code)
    dd if="$SOURCE_ISO" bs=1 count=432 of="$WORK_DIR/isohdpfx.bin" 2>/dev/null

    echo -e "${GREEN}  MBR extracted${NC}"
}

# Find and extract EFI partition image
extract_efi() {
    echo -e "${YELLOW}Locating EFI boot image...${NC}"

    local iso_extract="$WORK_DIR/iso-extract"
    local efi_img=""

    # Check common EFI image locations
    if [ -f "$iso_extract/boot/grub/efi.img" ]; then
        efi_img="$iso_extract/boot/grub/efi.img"
    elif [ -f "$iso_extract/EFI/boot/efi.img" ]; then
        efi_img="$iso_extract/EFI/boot/efi.img"
    else
        # Try to find it
        efi_img=$(find "$iso_extract" -name "efi.img" -type f 2>/dev/null | head -1)
    fi

    if [ -n "$efi_img" ] && [ -f "$efi_img" ]; then
        cp "$efi_img" "$WORK_DIR/efi.img"
        echo -e "${GREEN}  EFI image found: $efi_img${NC}"
    else
        echo -e "${YELLOW}  EFI image not found in standard location, will extract from ISO${NC}"
        # Extract EFI partition from ISO using xorriso
        xorriso -indev "$SOURCE_ISO" -report_el_torito as_mkisofs 2>/dev/null | \
            grep -E "^-append_partition" | head -1 > "$WORK_DIR/efi_info.txt" || true

        # Fallback: extract from boot/grub directory structure
        if [ -d "$iso_extract/boot/grub" ]; then
            echo -e "${GREEN}  GRUB boot structure found, will use it for EFI boot${NC}"
        fi
    fi
}

# Embed autoinstall configuration
embed_autoinstall() {
    echo -e "${YELLOW}Embedding autoinstall configuration...${NC}"

    local iso_extract="$WORK_DIR/iso-extract"
    local nocloud_dir="$iso_extract/nocloud"

    # Create nocloud directory
    mkdir -p "$nocloud_dir"

    # Copy autoinstall config files
    cp "$USER_DATA" "$nocloud_dir/user-data"
    cp "$META_DATA" "$nocloud_dir/meta-data"

    echo -e "${GREEN}  Copied user-data and meta-data to /nocloud/${NC}"
}

# Modify GRUB configuration
modify_grub() {
    echo -e "${YELLOW}Modifying GRUB configuration for autoinstall...${NC}"

    local iso_extract="$WORK_DIR/iso-extract"
    local grub_cfg="$iso_extract/boot/grub/grub.cfg"

    if [ ! -f "$grub_cfg" ]; then
        echo -e "${RED}ERROR: grub.cfg not found at: $grub_cfg${NC}"
        exit 1
    fi

    # Backup original
    cp "$grub_cfg" "$WORK_DIR/grub.cfg.orig"

    # Make grub.cfg writable (7z extracts read-only)
    chmod u+w "$grub_cfg"

    # Set timeout to 3 seconds (was -1 for manual selection)
    sed -i.bak 's/set timeout=-1/set timeout=3/' "$grub_cfg"
    sed -i.bak 's/set timeout=30/set timeout=3/' "$grub_cfg"

    # Add autoinstall parameter to the first (default) menuentry kernel line
    # This matches the kernel line and appends autoinstall parameter before the ---
    # Pattern: linux ... --- becomes linux ... autoinstall ds=nocloud\;s=/cdrom/nocloud/ ---
    # Note: semicolon must be escaped with backslash for GRUB to pass it to kernel
    sed -i.bak 's|\(linux.*vmlinuz.*\)---|\1autoinstall ds=nocloud\\;s=/cdrom/nocloud/ ---|' "$grub_cfg"

    # Also modify loopback.cfg if it exists
    local loopback_cfg="$iso_extract/boot/grub/loopback.cfg"
    if [ -f "$loopback_cfg" ]; then
        chmod u+w "$loopback_cfg"
        sed -i.bak 's/set timeout=-1/set timeout=3/' "$loopback_cfg"
        sed -i.bak 's/set timeout=30/set timeout=3/' "$loopback_cfg"
        sed -i.bak 's|\(linux.*vmlinuz.*\)---|\1autoinstall ds=nocloud\\;s=/cdrom/nocloud/ ---|' "$loopback_cfg"
        rm -f "$loopback_cfg.bak"
    fi

    # Clean up backup files
    rm -f "$grub_cfg.bak"

    echo -e "${GREEN}  GRUB timeout set to 3 seconds${NC}"
    echo -e "${GREEN}  Autoinstall kernel parameter added${NC}"
}

# Rebuild ISO with xorriso
rebuild_iso() {
    echo -e "${YELLOW}Rebuilding ISO with autoinstall configuration...${NC}"
    echo "  This may take a few minutes..."

    local iso_extract="$WORK_DIR/iso-extract"

    # Ensure output directory exists
    mkdir -p "$OUTPUT_DIR"

    # Remove old output if exists
    rm -f "$OUTPUT_ISO"

    # Check if EFI image exists
    local efi_args=""
    if [ -f "$WORK_DIR/efi.img" ]; then
        efi_args="-append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b $WORK_DIR/efi.img -appended_part_as_gpt"
    elif [ -f "$iso_extract/boot/grub/efi.img" ]; then
        efi_args="-append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b $iso_extract/boot/grub/efi.img -appended_part_as_gpt"
    fi

    # Build the ISO with hybrid BIOS+UEFI boot support
    xorriso -as mkisofs \
        -r \
        -V "Vault-Cube-2404" \
        -o "$OUTPUT_ISO" \
        --grub2-mbr "$WORK_DIR/isohdpfx.bin" \
        -partition_offset 16 \
        --mbr-force-bootable \
        $efi_args \
        -c '/boot.catalog' \
        -b '/boot/grub/i386-pc/eltorito.img' \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        --grub2-boot-info \
        -eltorito-alt-boot \
        -e '/boot/grub/efi.img' \
        -no-emul-boot \
        -isohybrid-gpt-basdat \
        "$iso_extract" 2>/dev/null || {
            # Fallback: simpler xorriso command if the full one fails
            echo -e "${YELLOW}  Trying simplified ISO build...${NC}"
            xorriso -as mkisofs \
                -r \
                -V "Vault-Cube-2404" \
                -o "$OUTPUT_ISO" \
                --grub2-mbr "$WORK_DIR/isohdpfx.bin" \
                -partition_offset 16 \
                --mbr-force-bootable \
                -c '/boot.catalog' \
                -b '/boot/grub/i386-pc/eltorito.img' \
                -no-emul-boot \
                -boot-load-size 4 \
                -boot-info-table \
                --grub2-boot-info \
                "$iso_extract"
        }

    # Get ISO size
    local iso_size=$(ls -lh "$OUTPUT_ISO" | awk '{print $5}')

    echo -e "${GREEN}  ISO created: $OUTPUT_ISO ($iso_size)${NC}"
}

# Print completion message
print_completion() {
    echo ""
    echo -e "${GREEN}=============================================="
    echo "Autoinstall ISO Created Successfully!"
    echo -e "===============================================${NC}"
    echo ""
    echo -e "${BLUE}Output:${NC} $OUTPUT_ISO"
    echo ""
    echo -e "${BLUE}What's embedded:${NC}"
    echo "  - Ubuntu 24.04 Live Server"
    echo "  - Autoinstall configuration (unattended)"
    echo "  - 3-second boot timeout"
    echo "  - User: vaultadmin / Password: vaultadmin"
    echo ""
    echo -e "${BLUE}Quick Test (QEMU):${NC}"
    echo "  # Create test disk"
    echo "  qemu-img create -f qcow2 /tmp/test-disk.qcow2 50G"
    echo ""
    echo "  # Boot ISO (macOS)"
    echo "  qemu-system-x86_64 -m 4G -accel hvf \\"
    echo "      -cdrom $OUTPUT_ISO \\"
    echo "      -hda /tmp/test-disk.qcow2 \\"
    echo "      -boot d"
    echo ""
    echo "  # Boot ISO (Linux with KVM)"
    echo "  qemu-system-x86_64 -m 4G -accel kvm \\"
    echo "      -cdrom $OUTPUT_ISO \\"
    echo "      -hda /tmp/test-disk.qcow2 \\"
    echo "      -boot d"
    echo ""
    echo -e "${BLUE}Write to USB for Production:${NC}"
    echo "  # Find your USB device (be careful!)"
    echo "  diskutil list  # macOS"
    echo "  lsblk          # Linux"
    echo ""
    echo "  # Write ISO to USB"
    echo "  sudo dd if=$OUTPUT_ISO of=/dev/diskX bs=4M status=progress"
    echo ""
    echo -e "${YELLOW}IMPORTANT: The ISO will auto-install after 3 seconds!${NC}"
    echo -e "${YELLOW}Make sure you're booting on the intended hardware.${NC}"
    echo ""
    echo -e "${BLUE}Post-Install (after reboot):${NC}"
    echo "  1. SSH as vaultadmin: ssh vaultadmin@<ip-address>"
    echo "  2. Run Ansible roles manually:"
    echo "     cd /path/to/ansible"
    echo "     ansible-playbook -i localhost, -c local playbooks/site.yml"
    echo ""
}

# Main execution
main() {
    check_prerequisites
    validate_source_iso
    validate_config_files

    extract_iso
    extract_mbr
    extract_efi
    embed_autoinstall
    modify_grub
    rebuild_iso

    print_completion
}

# Run main
main
