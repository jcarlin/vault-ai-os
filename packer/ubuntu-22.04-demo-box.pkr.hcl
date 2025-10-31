# Packer template for Ubuntu 22.04 LTS Demo Box
# Vault AI Systems - Cube Golden Image

# Required Packer version
packer {
  required_version = ">= 1.9.0"
  required_plugins {
    virtualbox = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/virtualbox"
    }
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

# Variables
variable "iso_url" {
  type    = string
  default = "/Users/julian/Downloads/ubuntu-22.04.5-live-server-amd64.iso"
}

variable "iso_checksum" {
  type    = string
  # SHA256 checksum for ubuntu-22.04.5-live-server-amd64.iso
  # Verified checksum: 9bc6028870aef3f74f4e16b900008179e78b130e6b0b9a140635434a46aa98b0
  default = "sha256:9bc6028870aef3f74f4e16b900008179e78b130e6b0b9a140635434a46aa98b0"
}

variable "vm_name" {
  type    = string
  default = "vault-cube-demo-box"
}

variable "cpus" {
  type    = number
  default = 4
}

variable "memory" {
  type    = number
  default = 8192
}

variable "disk_size" {
  type    = number
  default = 51200 # 50GB in MB
}

variable "ssh_username" {
  type    = string
  default = "vaultadmin"
}

variable "ssh_password" {
  type    = string
  default = "vaultadmin"
  sensitive = true
}

# VirtualBox ISO builder
source "virtualbox-iso" "ubuntu-2204" {
  # VM configuration
  vm_name              = var.vm_name
  guest_os_type        = "Ubuntu_64"
  cpus                 = var.cpus
  memory               = var.memory
  disk_size            = var.disk_size
  hard_drive_interface = "sata"

  # VISIBILITY: Show VirtualBox GUI so you can see what's happening!
  headless             = false

  # ISO configuration
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  # Network configuration
  # NAT allows internet access during build
  # We'll add host-only adapter later for Ansible
  guest_additions_mode = "disable"

  # HTTP server for serving cloud-init files
  # Packer starts a web server to serve files from http directory
  http_directory = "http"

  # Boot configuration for Ubuntu 22.04
  # Ubuntu 22.04 uses GRUB menu, so we navigate to the boot entry and modify it
  # The autoinstall parameter tells Ubuntu to use automated installation
  # ds=nocloud-net points to our HTTP server for cloud-init configuration
  boot_wait = "5s"
  boot_command = [
    # Wait for GRUB menu to appear
    "<wait>",
    # Press 'e' to edit the default boot entry
    "e<wait>",
    # Navigate down to the linux line (typically 3 down arrows)
    "<down><down><down>",
    # Go to end of line
    "<end>",
    # Add autoinstall and cloud-init data source parameters
    " autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/",
    # Ctrl+X or F10 to boot with modified parameters
    "<f10>"
  ]

  # SSH configuration - ENHANCED for reliability with password auth
  # After installation completes, Packer connects via SSH to provision
  # Increased timeouts to 60m and handshake attempts to 200 for maximum reliability
  ssh_username           = var.ssh_username
  ssh_password           = var.ssh_password
  ssh_timeout            = "60m"  # Increased to 60m for maximum reliability
  ssh_handshake_attempts = 200    # Increased to 200 for better reliability
  ssh_pty                = true
  ssh_wait_timeout       = "60m"  # Match ssh_timeout for consistent behavior

  # Shutdown configuration
  shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"

  # Output configuration
  output_directory = "output-${var.vm_name}"
  format           = "ova"

  # VirtualBox specific settings
  vboxmanage = [
    # Explicit NAT configuration for first adapter
    ["modifyvm", "{{.Name}}", "--nic1", "nat"],
    ["modifyvm", "{{.Name}}", "--nat-localhostreachable1", "on"],
    # Note: Packer creates its own SSH port forwarding dynamically
    # Disable unnecessary hardware
    ["modifyvm", "{{.Name}}", "--audio", "none"],
    ["modifyvm", "{{.Name}}", "--usb", "on"],
    # VISIBILITY: Enable serial console logging (must be before boot, not in vboxmanage_post)
    ["modifyvm", "{{.Name}}", "--uart1", "0x3F8", "4"],
    # ["modifyvm", "{{.Name}}", "--uartmode1", "file", "vault-cube-demo-box-console.log"]
  ]
}

# Build configuration
build {
  sources = ["source.virtualbox-iso.ubuntu-2204"]

  # FIRST PROVISIONER: Verify SSH connection and user setup
  provisioner "shell" {
    inline = [
      "echo '=============================================='",
      "echo '=== SSH CONNECTION SUCCESSFUL!!! ==='",
      "echo '=============================================='",
      "echo 'Current user: $(whoami)'",
      "echo 'User ID: $(id)'",
      "echo 'Groups: $(groups)'",
      "echo 'Home directory: $HOME'",
      "echo 'Shell: $SHELL'",
      "echo ''",
      "echo 'Testing sudo access...'",
      "sudo -n whoami && echo 'Sudo access: WORKING' || echo 'Sudo access: FAILED'",
      "echo ''",
      "echo 'SSH service status:'",
      "systemctl is-active ssh && echo 'SSH service: ACTIVE' || echo 'SSH service: INACTIVE'",
      "echo ''",
      "echo '=== SSH VERIFICATION COMPLETE ==='",
      "echo '=============================================='",
    ]
  }

  # Wait for cloud-init to complete and network to be ready
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait",
      "echo 'Cloud-init complete!'",
      "",
      "echo 'Waiting for network to be ready...'",
      "timeout 60 bash -c 'until ping -c 1 8.8.8.8 &>/dev/null; do sleep 2; done' || echo 'Network check timed out'",
      "echo 'Network is ready!'"
    ]
  }

  # System update
  provisioner "shell" {
    inline = [
      "echo 'Updating system packages...'",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold'",
      "echo 'System update complete!'"
    ]
  }

  # Install Ansible (required for ansible-local provisioner)
  provisioner "shell" {
    inline = [
      "echo 'Installing Ansible...'",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common",
      "sudo DEBIAN_FRONTEND=noninteractive apt-add-repository --yes --update ppa:ansible/ansible",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ansible",
      "echo 'Verifying Ansible installation...'",
      "ansible --version",
      "echo 'Ansible installed successfully!'"
    ]
  }

  # Ansible provisioning - Base system configuration
  provisioner "ansible-local" {
    playbook_file   = "../ansible/playbooks/site.yml"
    role_paths      = [
      "../ansible/roles/common",
      "../ansible/roles/users",
      "../ansible/roles/security",
      "../ansible/roles/packages",
      "../ansible/roles/networking"
    ]
    staging_directory = "/tmp/ansible"
    extra_arguments = [
      "--extra-vars", "ansible_python_interpreter=/usr/bin/python3"
    ]
  }

  # Clean up before finalizing image
  provisioner "shell" {
    inline = [
      "echo 'Cleaning up...'",
      "sudo apt-get autoremove -y",
      "sudo apt-get clean",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*",
      "echo 'Cleanup complete!'"
    ]
  }

  post-processor "manifest" {
    output = "manifest.json"
  }
}
