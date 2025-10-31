#!/bin/bash
# Packer Build Script - Ubuntu 22.04 Golden Image
# Vault AI Systems - Cube Demo Box
# Run with fixes for autoinstall (password hash + boot command)

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Vault AI Systems - Cube Golden Image Builder               ║${NC}"
echo -e "${BLUE}║  Ubuntu 22.04 LTS - Autoinstall Configuration (FIXED)       ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Change to packer directory
cd "$(dirname "$0")"
SCRIPT_DIR="$(pwd)"

echo -e "${YELLOW}[1/6] Pre-Flight Validation${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check Packer is installed
if ! command -v packer &> /dev/null; then
    echo -e "${RED}✗ ERROR: Packer not found${NC}"
    echo "Install with: brew install packer"
    exit 1
fi
echo -e "${GREEN}✓ Packer installed:${NC} $(packer version)"

# Check VirtualBox is installed
if ! command -v VBoxManage &> /dev/null; then
    echo -e "${RED}✗ ERROR: VirtualBox not found${NC}"
    echo "Install with: brew install --cask virtualbox"
    exit 1
fi
echo -e "${GREEN}✓ VirtualBox installed:${NC} $(VBoxManage --version)"

# Check ISO file exists
ISO_PATH="/Users/julian/Downloads/ubuntu-22.04.5-live-server-amd64.iso"
if [ ! -f "$ISO_PATH" ]; then
    echo -e "${RED}✗ ERROR: ISO file not found at $ISO_PATH${NC}"
    exit 1
fi
echo -e "${GREEN}✓ ISO file found:${NC} $(du -h "$ISO_PATH" | cut -f1)"

# Validate Packer template
echo ""
echo -e "${YELLOW}[2/6] Validating Packer Template${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if packer validate ubuntu-22.04-demo-box.pkr.hcl; then
    echo -e "${GREEN}✓ Packer template is valid${NC}"
else
    echo -e "${RED}✗ ERROR: Packer template validation failed${NC}"
    exit 1
fi

# Validate cloud-init files
echo ""
echo -e "${YELLOW}[3/6] Validating Cloud-Init Configuration${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ! -f "http/user-data" ]; then
    echo -e "${RED}✗ ERROR: http/user-data not found${NC}"
    exit 1
fi

if [ ! -f "http/meta-data" ]; then
    echo -e "${RED}✗ ERROR: http/meta-data not found${NC}"
    exit 1
fi

# Check password hash is complete (should be 100+ characters)
PASSWORD_HASH=$(grep -A 1 "password:" http/user-data | grep -oP '\$6\$[^\s]+' || echo "")
HASH_LENGTH=${#PASSWORD_HASH}

if [ "$HASH_LENGTH" -lt 50 ]; then
    echo -e "${RED}✗ ERROR: Password hash is incomplete (${HASH_LENGTH} chars, expected 100+)${NC}"
    echo "Current hash: $PASSWORD_HASH"
    echo "Run this to generate: python3 -c \"import crypt; print(crypt.crypt('vaultadmin', '\\\$6\\\$rounds=656000\\\$'))\""
    exit 1
fi
echo -e "${GREEN}✓ Password hash is complete:${NC} ${HASH_LENGTH} characters"

# Check YAML syntax (if Python is available)
if command -v python3 &> /dev/null; then
    if python3 -c "import yaml; yaml.safe_load(open('http/user-data'))" 2>/dev/null; then
        echo -e "${GREEN}✓ user-data has valid YAML syntax${NC}"
    else
        echo -e "${RED}✗ ERROR: user-data has invalid YAML syntax${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ meta-data exists${NC}"

# Clean previous builds
echo ""
echo -e "${YELLOW}[4/6] Cleaning Previous Build Artifacts${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -d "output-vault-cube-demo-box" ]; then
    echo "Removing old output directory..."
    rm -rf output-vault-cube-demo-box
    echo -e "${GREEN}✓ Cleaned output directory${NC}"
fi

if [ -f "manifest.json" ]; then
    echo "Removing old manifest..."
    rm -f manifest.json
    echo -e "${GREEN}✓ Cleaned manifest${NC}"
fi

# Archive old logs
if ls packer-build-*.log 1> /dev/null 2>&1; then
    ARCHIVE_DIR="logs-archive-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$ARCHIVE_DIR"
    mv packer-build-*.log "$ARCHIVE_DIR/" 2>/dev/null || true
    echo -e "${GREEN}✓ Archived old logs to $ARCHIVE_DIR${NC}"
fi

# Setup logging
LOG_FILE="packer-build-$(date +%Y%m%d-%H%M%S).log"
export PACKER_LOG=1
export PACKER_LOG_PATH="./$LOG_FILE"

echo ""
echo -e "${YELLOW}[5/6] Starting Packer Build${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}Log file:${NC} $LOG_FILE"
echo -e "${BLUE}VirtualBox:${NC} headless=false (GUI visible for monitoring)"
echo -e "${BLUE}Expected duration:${NC} 20-30 minutes"
echo ""
echo -e "${GREEN}What to watch for:${NC}"
echo "  ✓ VirtualBox console should show NO interactive prompts"
echo "  ✓ Text should scroll continuously (installation progress)"
echo "  ✓ System should reboot automatically after ~10 minutes"
echo "  ✓ Packer should connect via SSH after reboot"
echo ""
echo -e "${YELLOW}Build starting in 5 seconds...${NC}"
sleep 5

# Record start time
START_TIME=$(date +%s)

# Run Packer build
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
if packer build ubuntu-22.04-demo-box.pkr.hcl; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    DURATION_MIN=$((DURATION / 60))
    DURATION_SEC=$((DURATION % 60))

    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ BUILD SUCCESSFUL!${NC}"
    echo -e "${GREEN}Duration: ${DURATION_MIN}m ${DURATION_SEC}s${NC}"

    echo ""
    echo -e "${YELLOW}[6/6] Build Artifacts${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ -d "output-vault-cube-demo-box" ]; then
        echo -e "${GREEN}✓ Output directory:${NC} output-vault-cube-demo-box/"
        ls -lh output-vault-cube-demo-box/
    fi

    if [ -f "manifest.json" ]; then
        echo -e "${GREEN}✓ Manifest:${NC} manifest.json"
    fi

    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                       NEXT STEPS                             ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "1. Import OVA into VirtualBox:"
    echo "   ${BLUE}VBoxManage import output-vault-cube-demo-box/vault-cube-demo-box.ova --vsys 0 --vmname \"test-cube\"${NC}"
    echo ""
    echo "2. Start VM:"
    echo "   ${BLUE}VBoxManage startvm \"test-cube\"${NC}"
    echo ""
    echo "3. Login credentials:"
    echo "   ${BLUE}Username: vaultadmin${NC}"
    echo "   ${BLUE}Password: vaultadmin${NC}"
    echo ""
    echo "4. Test sudo access:"
    echo "   ${BLUE}sudo whoami${NC} (should show 'root' without password prompt)"
    echo ""

    exit 0
else
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    DURATION_MIN=$((DURATION / 60))
    DURATION_SEC=$((DURATION % 60))

    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}✗ BUILD FAILED${NC}"
    echo -e "${RED}Duration before failure: ${DURATION_MIN}m ${DURATION_SEC}s${NC}"
    echo ""
    echo -e "${YELLOW}Troubleshooting Steps:${NC}"
    echo ""
    echo "1. Check Packer logs:"
    echo "   ${BLUE}tail -n 100 $LOG_FILE${NC}"
    echo "   ${BLUE}grep -i error $LOG_FILE${NC}"
    echo ""
    echo "2. Check VirtualBox console:"
    echo "   - Did GRUB menu appear?"
    echo "   - Did you see interactive installer prompts? (language, keyboard)"
    echo "   - Is the VM stuck at a prompt waiting for input?"
    echo ""
    echo "3. Review troubleshooting guide:"
    echo "   ${BLUE}cat TROUBLESHOOTING.md${NC}"
    echo "   ${BLUE}cat AUTOINSTALL-VALIDATION.md${NC}"
    echo ""
    echo "4. Common issues:"
    echo "   - ${YELLOW}Manual prompts appear:${NC} Boot command failed to inject autoinstall parameter"
    echo "   - ${YELLOW}SSH timeout:${NC} User creation or SSH service failed"
    echo "   - ${YELLOW}Black screen:${NC} VirtualBox CPU/RAM insufficient or ISO corruption"
    echo ""

    exit 1
fi
