#!/bin/bash
# Build Vault Cube bare metal image via VirtualBox
# Builds OVA, extracts VMDK, converts to raw disk image
#
# Usage:
#   ./scripts/build-via-virtualbox.sh              # Full build
#   ./scripts/build-via-virtualbox.sh --skip-build # Skip Packer, just convert existing OVA
#   ./scripts/build-via-virtualbox.sh --test       # Build + test in QEMU

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PACKER_DIR="$PROJECT_ROOT/packer/ubuntu-24.04"
OUTPUT_DIR="$PACKER_DIR/output-vault-cube-demo-box-2404"
BAREMETAL_DIR="$PACKER_DIR/output-baremetal"

VM_NAME="vault-cube-demo-box-2404"
OVA_FILE="$OUTPUT_DIR/${VM_NAME}.ova"
RAW_OUTPUT="$BAREMETAL_DIR/vault-cube-baremetal.raw"

# Parse arguments
SKIP_BUILD=false
RUN_TEST=false
FORCE_BUILD=true  # Default to force rebuild

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --test)
            RUN_TEST=true
            shift
            ;;
        --no-force)
            FORCE_BUILD=false
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-build    Skip Packer build, convert existing OVA"
            echo "  --test          Run QEMU test after build"
            echo "  --no-force      Don't force rebuild if output exists"
            echo "  -h, --help      Show this help"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}=============================================="
echo "Vault Cube Image Builder (VirtualBox)"
echo "=============================================="
echo ""
echo "Build Configuration:"
echo "  Packer Dir:  $PACKER_DIR"
echo "  Output OVA:  $OVA_FILE"
echo "  Raw Output:  $RAW_OUTPUT"
echo "  Skip Build:  $SKIP_BUILD"
echo "  Force Build: $FORCE_BUILD"
echo "  Run Test:    $RUN_TEST"
echo -e "===============================================${NC}"
echo ""

# Check dependencies
check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}ERROR: $1 not found${NC}"
        echo "Install with: $2"
        exit 1
    fi
}

echo -e "${YELLOW}Checking dependencies...${NC}"
check_dependency "packer" "brew install packer"
check_dependency "qemu-img" "brew install qemu"

if $RUN_TEST; then
    check_dependency "qemu-system-x86_64" "brew install qemu"
fi

echo -e "${GREEN}All dependencies found${NC}"
echo ""

# =============================================================================
# Phase 1: Packer Build
# =============================================================================

if ! $SKIP_BUILD; then
    echo -e "${BLUE}=============================================="
    echo "Phase 1: VirtualBox Packer Build"
    echo -e "===============================================${NC}"

    cd "$PACKER_DIR"

    # Check if OVA already exists
    if [ -f "$OVA_FILE" ] && ! $FORCE_BUILD; then
        echo -e "${YELLOW}OVA already exists. Use --no-force to skip or default behavior rebuilds.${NC}"
    fi

    # Initialize Packer plugins
    echo -e "${YELLOW}Initializing Packer plugins...${NC}"
    packer init local-dev-only.pkr.hcl

    # Validate template
    echo -e "${YELLOW}Validating Packer template...${NC}"
    packer validate local-dev-only.pkr.hcl

    # Build
    echo ""
    echo -e "${GREEN}Starting Packer build...${NC}"
    echo "This will take 30-45 minutes. VirtualBox GUI will appear."
    echo ""

    BUILD_ARGS="-only=virtualbox-iso.ubuntu-2404"
    if $FORCE_BUILD; then
        BUILD_ARGS="-force $BUILD_ARGS"
    fi

    # Run build (target specific file to avoid conflicts with other templates)
    packer build $BUILD_ARGS local-dev-only.pkr.hcl

    echo ""
    echo -e "${GREEN}Packer build complete!${NC}"

    cd "$PROJECT_ROOT"

    # Pause after Phase 1
    echo ""
    echo -e "${BLUE}=============================================="
    echo "Phase 1 Complete"
    echo -e "===============================================${NC}"
    echo ""
    echo "OVA created at: $OVA_FILE"
    echo ""
    echo "Next: Extract VMDK and convert to raw disk image"
    echo ""
    read -p "Press Enter to continue to Phase 2 (or Ctrl+C to stop here)..."
else
    echo -e "${YELLOW}Skipping Packer build (--skip-build specified)${NC}"

    if [ ! -f "$OVA_FILE" ]; then
        echo -e "${RED}ERROR: OVA file not found: $OVA_FILE${NC}"
        echo "Run without --skip-build to create it first."
        exit 1
    fi
fi

# =============================================================================
# Phase 2: Extract VMDK from OVA
# =============================================================================

echo ""
echo -e "${BLUE}=============================================="
echo "Phase 2: Extract VMDK from OVA"
echo -e "===============================================${NC}"

cd "$OUTPUT_DIR"

# Check OVA exists
if [ ! -f "${VM_NAME}.ova" ]; then
    echo -e "${RED}ERROR: OVA not found: ${VM_NAME}.ova${NC}"
    exit 1
fi

# Extract OVA (which is just a tar archive)
echo -e "${YELLOW}Extracting OVA...${NC}"
tar -xvf "${VM_NAME}.ova" 2>/dev/null || true

# Find the VMDK file
VMDK_FILE=$(ls -1 *.vmdk 2>/dev/null | head -1)

if [ -z "$VMDK_FILE" ]; then
    echo -e "${RED}ERROR: No VMDK file found in OVA${NC}"
    echo "Contents of $OUTPUT_DIR:"
    ls -la
    exit 1
fi

echo -e "${GREEN}Found VMDK: $VMDK_FILE${NC}"

# =============================================================================
# Phase 3: Convert VMDK to Raw
# =============================================================================

echo ""
echo -e "${BLUE}=============================================="
echo "Phase 3: Convert VMDK to Raw Disk Image"
echo -e "===============================================${NC}"

# Create output directory
mkdir -p "$BAREMETAL_DIR"

# Convert
echo -e "${YELLOW}Converting VMDK to raw (this may take a few minutes)...${NC}"
qemu-img convert -f vmdk -O raw "$VMDK_FILE" "$RAW_OUTPUT"

# Get image info
echo ""
echo -e "${GREEN}Conversion complete!${NC}"
echo ""
echo "Image details:"
qemu-img info "$RAW_OUTPUT"

# Get size
RAW_SIZE=$(ls -lh "$RAW_OUTPUT" | awk '{print $5}')
echo ""
echo -e "${GREEN}Raw image size: $RAW_SIZE${NC}"

cd "$PROJECT_ROOT"

# =============================================================================
# Phase 4: Verify Image (Optional)
# =============================================================================

echo ""
echo -e "${BLUE}=============================================="
echo "Build Complete!"
echo -e "===============================================${NC}"
echo ""
echo "Output files:"
echo "  OVA:  $OVA_FILE"
echo "  Raw:  $RAW_OUTPUT"
echo ""
echo "Next steps:"
echo ""
echo "1. Test the image in QEMU:"
echo "   ./scripts/test-baremetal-image.sh packer/ubuntu-24.04/output-baremetal/vault-cube-baremetal raw"
echo ""
echo "2. Deploy to appliance (choose one):"
echo ""
echo "   Option A - Direct NVMe write:"
echo "   Connect NVMe to Mac via USB adapter, then:"
echo "   sudo dd if=$RAW_OUTPUT of=/dev/diskN bs=4m status=progress"
echo ""
echo "   Option B - PXE network boot:"
echo "   ./scripts/setup-pxe-server.sh $RAW_OUTPUT"
echo ""
echo "   Option C - USB boot:"
echo "   sudo dd if=$RAW_OUTPUT of=/dev/rdiskN bs=4m status=progress"
echo ""

# Run test if requested
if $RUN_TEST; then
    echo ""
    echo -e "${BLUE}=============================================="
    echo "Phase 4: QEMU Test"
    echo -e "===============================================${NC}"
    echo ""

    "$SCRIPT_DIR/test-baremetal-image.sh" "$BAREMETAL_DIR/vault-cube-baremetal" raw
fi

echo -e "${GREEN}Done!${NC}"
