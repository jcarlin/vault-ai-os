# Packer template for Ubuntu 24.04 LTS - Local VirtualBox Development Only
# Vault AI Systems - Cube Golden Image
# NO GPU components - Base system validation only

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
  default = "/Users/julian/Downloads/ubuntu-24.04.3-live-server-amd64.iso"
}

variable "iso_checksum" {
  type = string
  # SHA256 checksum for ubuntu-24.04.3-live-server-amd64.iso
  default = "sha256:c3514bf0056180d09376462a7a1b4f213c1d6e8ea67fae5c25099c6fd3d8274b"
}

variable "vm_name" {
  type    = string
  default = "vault-cube-demo-box-2404"
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
  type      = string
  default   = "vaultadmin"
  sensitive = true
}

# VirtualBox ISO builder
source "virtualbox-iso" "ubuntu-2404" {
  # VM configuration
  vm_name              = var.vm_name
  guest_os_type        = "Ubuntu_64"
  cpus                 = var.cpus
  memory               = var.memory
  disk_size            = var.disk_size
  hard_drive_interface = "sata"

  # VISIBILITY: Show VirtualBox GUI
  headless = false

  # ISO configuration
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  # Network configuration
  guest_additions_mode = "disable"

  # HTTP server for serving cloud-init files
  http_directory = "../http"

  # Boot configuration for Ubuntu 24.04
  # Adjusted timing for 24.04's different GRUB sequence
  boot_wait = "10s"
  boot_command = [
    # Wait for GRUB menu to fully render
    "<wait5>",
    # Press 'e' to edit boot entry
    "e",
    "<wait3>",
    # Navigate to linux line - Ubuntu 24.04 may need different navigation
    "<down><down><down><end>",
    "<wait>",
    # Add autoinstall parameters
    " autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/",
    "<wait>",
    # Boot with F10
    "<f10>"
  ]

  # SSH configuration
  ssh_username           = var.ssh_username
  ssh_password           = var.ssh_password
  ssh_timeout            = "60m"
  ssh_handshake_attempts = 420
  ssh_pty                = true
  ssh_wait_timeout       = "60m"

  # Shutdown configuration
  shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"

  # Output configuration
  output_directory = "output-${var.vm_name}"
  format           = "ova"

  # VirtualBox specific settings
  vboxmanage = [
    ["modifyvm", "{{.Name}}", "--nic1", "nat"],
    ["modifyvm", "{{.Name}}", "--nat-localhostreachable1", "on"],
    ["modifyvm", "{{.Name}}", "--audio", "none"],
    ["modifyvm", "{{.Name}}", "--usb", "on"],
    # Serial console logging for debugging installation
    ["modifyvm", "{{.Name}}", "--uart1", "0x3F8", "4"],
    ["modifyvm", "{{.Name}}", "--uartmode1", "file", "vault-cube-2404-console.log"]
  ]

  # Add permanent SSH port forwarding (saved in OVA)
  vboxmanage_post = [
    ["modifyvm", "{{.Name}}", "--natpf1", "ssh,tcp,,2222,,22"]
  ]
}

# Build configuration
build {
  sources = ["source.virtualbox-iso.ubuntu-2404"]

  # Verify SSH connection
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
      "echo 'OS Version:'",
      "cat /etc/os-release | grep PRETTY_NAME",
      "echo 'Kernel Version:'",
      "uname -r",
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

  # Wait for cloud-init to complete
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

  # Install Ansible
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

  # Ansible provisioning - Base system configuration (NO GPU)
  provisioner "ansible-local" {
    playbook_file = "../../ansible/playbooks/site.yml"
    role_paths = [
      "../../ansible/roles/common",
      "../../ansible/roles/users",
      "../../ansible/roles/packages",
      "../../ansible/roles/networking",
      "../../ansible/roles/docker",
      "../../ansible/roles/python"
    ]
    staging_directory = "/tmp/ansible"
    extra_arguments = [
      "--extra-vars={\"ansible_python_interpreter\":\"/usr/bin/python3\",\"packer_build\":true,\"ubuntu_version\":\"24.04\"}",
      "--skip-tags=security,hardening,ai-runtime"
    ]
  }

  # Verify kernel version
  provisioner "shell" {
    inline = [
      "echo '=============================================='",
      "echo '=== Kernel Version Check ==='",
      "KERNEL_VERSION=$(uname -r)",
      "echo \"Kernel: $KERNEL_VERSION\"",
      "if [[ \"$KERNEL_VERSION\" == 6.13.* ]] || [[ \"$KERNEL_VERSION\" > \"6.13\" ]]; then",
      "  echo '✓ Kernel 6.13+ confirmed (RTX 5090 ready)'",
      "elif [[ \"$KERNEL_VERSION\" == 6.8.* ]]; then",
      "  echo '⚠ Kernel 6.8 detected (default Ubuntu 24.04)'",
      "  echo '  NOTE: Kernel 6.13+ would be installed by nvidia role for RTX 5090'",
      "else",
      "  echo \"Kernel: $KERNEL_VERSION\"",
      "fi",
      "echo '=============================================='",
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
    output     = "packer-manifest-local-2404.json"
    strip_path = true
  }
}
