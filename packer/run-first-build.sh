#!/bin/bash
# First Packer Build - Quick Win Script
# Vault AI Systems - Cube Golden Image

set -e

echo "=================================="
echo "Packer First Build - Quick Win"
echo "=================================="
echo ""

# Change to packer directory
cd "$(dirname "$0")"

# Clean previous failed builds
echo "🧹 Cleaning previous build artifacts..."
rm -rf output-vault-cube-demo-box/
rm -f vault-cube-demo-box-console.log
rm -f packer-build.log
rm -f manifest.json
echo "✅ Cleanup complete"
echo ""

# Validate configuration
echo "🔍 Validating Packer configuration..."
packer validate ubuntu-24.04-demo-box.pkr.hcl
echo "✅ Configuration valid"
echo ""

# Show what will be built
echo "📋 Build Configuration:"
packer inspect ubuntu-24.04-demo-box.pkr.hcl | grep -A 20 "builds:"
echo ""

# Confirm before starting
echo "⏱️  Expected build time: 30-35 minutes"
echo ""
echo "🎯 What this build will do:"
echo "  1. Create Ubuntu 24.04 LTS VM"
echo "  2. Configure vaultadmin user with SSH access"
echo "  3. Update system packages"
echo "  4. Install Python3 prerequisites"
echo "  5. Export as OVA image"
echo ""
echo "📝 Note: Ansible provisioning is disabled for this first build"
echo "   We'll enable it after confirming SSH connectivity works"
echo ""

read -p "Ready to start build? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Build cancelled"
    exit 1
fi

echo ""
echo "🚀 Starting Packer build with logging..."
echo "   Log file: ./packer-build.log"
echo "   Console log: ./vault-cube-demo-box-console.log"
echo ""
echo "💡 Tip: In another terminal, run:"
echo "   tail -f packer-build.log"
echo ""

# Run build with logging
PACKER_LOG=1 PACKER_LOG_PATH=./packer-build.log \
  packer build ubuntu-24.04-demo-box.pkr.hcl

# Check if build succeeded
if [ $? -eq 0 ]; then
    echo ""
    echo "=================================="
    echo "🎉 BUILD SUCCESSFUL!"
    echo "=================================="
    echo ""
    echo "📦 Output files:"
    ls -lh output-vault-cube-demo-box/
    echo ""
    echo "✅ Next steps:"
    echo "  1. Test the image:"
    echo "     vboxmanage import output-vault-cube-demo-box/vault-cube-demo-box.ova"
    echo ""
    echo "  2. Review the Quick Start Guide:"
    echo "     cat ../docs/packer/QUICK-START-GUIDE.md"
    echo ""
    echo "  3. Enable Ansible and run second build"
    echo ""
else
    echo ""
    echo "=================================="
    echo "❌ BUILD FAILED"
    echo "=================================="
    echo ""
    echo "🔍 Troubleshooting:"
    echo "  1. Check the build log:"
    echo "     tail -100 packer-build.log"
    echo ""
    echo "  2. Check the console log:"
    echo "     tail -100 vault-cube-demo-box-console.log"
    echo ""
    echo "  3. Review troubleshooting guide:"
    echo "     cat TROUBLESHOOTING.md"
    echo ""
    exit 1
fi
