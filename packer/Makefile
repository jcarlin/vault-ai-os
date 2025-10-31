# Packer Build Troubleshooting Makefile
# Quick commands for iterating on the Vault Cube golden image

.PHONY: help clean clean-vms clean-all build debug-build force-build list-vms logs

# Default target - show help
help:
	@echo "Packer Build Commands:"
	@echo "  make clean         - Remove output directory and logs"
	@echo "  make clean-vms     - Remove VirtualBox VMs"
	@echo "  make clean-all     - Clean everything (files + VMs)"
	@echo "  make build         - Run packer build"
	@echo "  make debug-build   - Run with debug logging (recommended)"
	@echo "  make force-build   - Build with -force flag"
	@echo "  make list-vms      - Show all VirtualBox VMs"
	@echo "  make logs          - View packer output log"

# Clean output directory and log files
clean:
	@echo "Cleaning output directory and logs..."
	rm -rf output-vault-cube-demo-box/
	@-chmod +w vault-cube-demo-box-console.log 2>/dev/null || true
	rm -f packer-output.log packer-debug.log vault-cube-demo-box-console.log manifest.json
	rm -f *.log
	@echo "Clean complete!"

# Remove VirtualBox VMs matching our build
clean-vms:
	@echo "Removing VirtualBox VMs..."
	@-VBoxManage list vms | grep "vault-cube" | awk '{print $$2}' | tr -d '{}' | xargs -I {} VBoxManage unregistervm {} --delete 2>/dev/null || true
	@-rm -rf ~/VirtualBox\ VMs/vault-cube-demo-box/ 2>/dev/null || true
	@echo "VMs removed!"

# Clean everything
clean-all: clean clean-vms

# Standard build
build:
	packer build ubuntu-24.04-demo-box.pkr.hcl

# Debug build with logging (recommended for troubleshooting)
debug-build:
	./debug-build.sh

# Force build (auto-cleanup)
force-build:
	packer build -force ubuntu-24.04-demo-box.pkr.hcl

# List all VirtualBox VMs
list-vms:
	@echo "VirtualBox VMs:"
	@VBoxManage list vms

# View packer output log (if it exists)
logs:
	@if [ -f packer-output.log ]; then \
		tail -f packer-output.log; \
	else \
		echo "No packer-output.log found. Run 'make debug-build' first."; \
	fi
