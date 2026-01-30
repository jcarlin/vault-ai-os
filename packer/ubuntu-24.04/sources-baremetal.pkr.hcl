# QEMU builder for Bare Metal deployment
# Creates bootable disk images for physical Vault Cube hardware
# Optimized for 4x RTX 5090, 256GB RAM, 2TB NVMe SSD

source "qemu" "ubuntu-2404-baremetal" {
  # ============================================================================
  # Source ISO Configuration
  # ============================================================================
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  # ============================================================================
  # Output Configuration
  # ============================================================================
  output_directory = var.baremetal_output_dir
  vm_name          = var.baremetal_vm_name

  # Output format: raw for dd, qcow2 for compressed images
  format = var.baremetal_output_format

  # Disk image will be named: vault-cube-baremetal.raw (or .qcow2)
  # This can be written to USB/SSD with: dd if=vault-cube-baremetal.raw of=/dev/sdX bs=4M status=progress

  # ============================================================================
  # Hardware Configuration (Matching Vault Cube Specs)
  # ============================================================================
  cpus   = var.baremetal_cpus     # 32 CPU cores
  memory = var.baremetal_memory   # 256GB RAM

  # Disk configuration
  disk_size      = var.baremetal_disk_size      # 2TB (2000G)
  disk_interface = var.baremetal_disk_interface # virtio-scsi for performance

  # Use backing file for incremental builds (optional)
  use_backing_file = var.baremetal_use_backing_file

  # ============================================================================
  # Acceleration
  # ============================================================================
  # KVM on Linux (fastest), HVF on macOS, TCG as fallback
  accelerator = var.baremetal_accelerator

  # QEMU binary path (auto-detect or specify)
  qemu_binary = var.baremetal_qemu_binary != "" ? var.baremetal_qemu_binary : "qemu-system-x86_64"

  # ============================================================================
  # Network Configuration
  # ============================================================================
  net_device = var.baremetal_net_device  # virtio-net for performance

  # User-mode networking (no root required)
  net_bridge = ""

  # Port forwarding for SSH (QEMU forwards guest:22 to host:random)
  # Packer handles this automatically

  # ============================================================================
  # Display Configuration
  # ============================================================================
  headless = var.baremetal_headless

  # Force cocoa display for macOS (GTK doesn't work on macOS)
  display = "cocoa"

  # VNC display (for debugging if headless=false)
  vnc_bind_address = "127.0.0.1"
  vnc_port_min     = 5900
  vnc_port_max     = 5900

  # ============================================================================
  # HTTP Server for Cloud-Init
  # ============================================================================
  http_directory = "../http"
  http_port_min  = 8000
  http_port_max  = 8099

  # ============================================================================
  # Boot Configuration
  # ============================================================================
  boot_wait = var.baremetal_boot_wait

  boot_command = [
    # Wait for GRUB menu
    "<wait>",
    # Edit boot entry
    "e<wait>",
    # Navigate to linux line
    "<down><down><down>",
    # Go to end of line
    "<end>",
    # Add autoinstall with cloud-init data source
    " autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/",
    # Boot with modified parameters
    "<f10>"
  ]

  # ============================================================================
  # SSH Configuration
  # ============================================================================
  ssh_username           = var.ssh_username
  ssh_password           = var.ssh_password
  ssh_timeout            = var.baremetal_ssh_timeout
  ssh_handshake_attempts = 100
  ssh_pty                = true

  # ============================================================================
  # Shutdown Configuration
  # ============================================================================
  shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"
  shutdown_timeout = var.baremetal_shutdown_timeout

  # ============================================================================
  # QEMU Arguments (Advanced Hardware Emulation)
  # ============================================================================
  # DISABLED FOR MACOS COMPATIBILITY - Let Packer use defaults
  # qemuargs = [
  #   ["-cpu", "host"],
  #   ["-serial", "file:baremetal-console.log"],
  #   ["-vga", "std"],
  #   ["-usb"],
  #   ["-device", "usb-tablet"]
  # ]
}
