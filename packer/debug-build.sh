#!/bin/bash
# Packer Debug Build Script
# Follows HashiCorp official debugging practices:
# https://developer.hashicorp.com/packer/docs/debugging

set -e

echo "================================"
echo "Packer Debug Build"
echo "================================"
echo ""
echo "Official Packer debugging enabled:"
echo "  ✓ PACKER_LOG=1            (verbose logging)"
echo "  ✓ PACKER_LOG_PATH         (logs to file)"
echo "  ✓ VirtualBox GUI visible  (headless=false)"
echo "  ✓ Serial console logging  (console.log)"
echo ""
echo "Logs will be saved to:"
echo "  - packer-debug.log                 (PACKER_LOG_PATH)"
echo "  - packer-output.log                (build output)"
echo "  - vault-cube-demo-box-console.log  (serial console)"
echo ""
echo "For interactive debugging, use:"
echo "  packer build -debug ubuntu-24.04-demo-box.pkr.hcl"
echo ""
echo "For pause-on-error, use:"
echo "  packer build -on-error=ask ubuntu-24.04-demo-box.pkr.hcl"
echo ""

# Official Packer debugging environment variables
export PACKER_LOG=1
export PACKER_LOG_PATH="packer-debug.log"

# Run Packer build with tee for terminal output
packer build ubuntu-24.04-demo-box.pkr.hcl 2>&1 | tee packer-output.log

echo ""
echo "================================"
echo "Build Complete!"
echo "================================"
echo ""
echo "Review logs:"
echo "  - packer-debug.log                 (Packer internals)"
echo "  - packer-output.log                (Build terminal output)"
echo "  - vault-cube-demo-box-console.log  (VM serial console)"
