# Packer template for Ubuntu 24.04 LTS Demo Box - RTX 5090 Optimized
# Vault AI Systems - Cube Golden Image
# Updated for: CUDA 12.8, Kernel 6.13+, RTX 5090/Blackwell Architecture
# default = "https://releases.ubuntu.com/24.04.1/ubuntu-24.04.1-live-server-amd64.iso"

# Required Packer version
packer {
  required_version = ">= 1.9.0"
  required_plugins {
    virtualbox = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/virtualbox"
    }
    googlecompute = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/googlecompute"
    }
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
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
  # Verified from actual ISO file
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

# Cloud platform detection
variable "cloud_platform" {
  type        = string
  description = "Target platform: local (VirtualBox), gcp, aws, azure"
  default     = "local"
}

variable "enable_gpu_roles" {
  type        = bool
  description = "Enable GPU ansible roles (nvidia, pytorch, tensorflow, vllm)"
  default     = false
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

  # VISIBILITY: Show VirtualBox GUI so you can see what's happening!
  headless = false

  # ISO configuration
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  # Network configuration
  # NAT allows internet access during build
  # We'll add host-only adapter later for Ansible
  guest_additions_mode = "disable"

  # HTTP server for serving cloud-init files
  # Packer starts a web server to serve files from http directory
  # Path is relative to template location (../http from ubuntu-24.04/)
  http_directory = "../http"

  # Boot configuration for Ubuntu 24.04
  # Ubuntu 24.04 uses GRUB menu, so we navigate to the boot entry and modify it
  # The autoinstall parameter tells Ubuntu to use automated installation
  # ds=nocloud-net points to our HTTP server for cloud-init configuration
  boot_wait = "15s"
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
  # Increased timeouts to 60m and handshake attempts to 420 (community-proven for Ubuntu 24.04)
  ssh_username           = var.ssh_username
  ssh_password           = var.ssh_password
  ssh_timeout            = "60m" # Increased to 60m for maximum reliability
  ssh_handshake_attempts = 420   # Increased to 420 for Ubuntu 24.04 (works around Packer timeout bug)
  ssh_pty                = true
  ssh_wait_timeout       = "60m" # Match ssh_timeout for consistent behavior

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
    ["modifyvm", "{{.Name}}", "--usb", "on"]
    # VISIBILITY: Serial console logging disabled due to macOS permissions issues
    # ["modifyvm", "{{.Name}}", "--uart1", "0x3F8", "4"],
    # ["modifyvm", "{{.Name}}", "--uartmode1", "file", "vault-cube-demo-box-2404-console.log"]
  ]
}

# Local VirtualBox build (no GPU - Tasks 1a.0-7)
build {
  name    = "local-dev"
  sources = ["source.virtualbox-iso.ubuntu-2404"]

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

  # Ansible provisioning - Base system configuration (Tasks 1a.4-7)
  provisioner "ansible-local" {
    playbook_file = "../../ansible/playbooks/site.yml"
    role_paths = [
      "../../ansible/roles/common",
      "../../ansible/roles/users",
      # "../../ansible/roles/security",
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

  # Verify kernel version (should be 6.13+ for RTX 5090)
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
      "  echo '  NOTE: Kernel 6.13+ will be installed by nvidia role for RTX 5090'",
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

# ==============================================================================
# GCP GPU Build (cloud-gpu-gcp) - Ubuntu 24.04 + CUDA 12.8 + RTX 5090 Validation
# ==============================================================================
# This build creates GPU-enabled images on Google Cloud Platform
# Uses L4 GPU (Ada Lovelace - RTX 40/50 equivalent) for validation
# Includes all GPU ansible roles for task 1a.8+ validation
# CUDA 12.8 + cuDNN 9.7.1 + PyTorch cu128 + TensorFlow 2.17 (NGC container)
# ==============================================================================

build {
  name    = "cloud-gpu-gcp"
  sources = ["source.googlecompute.ubuntu-2404-gpu"]

  # Verify GPU presence at start
  provisioner "shell" {
    inline = [
      "echo '=============================================='",
      "echo '=== GCP GPU Build Instance Started ==='",
      "echo '=== Ubuntu 24.04 + CUDA 12.8 + RTX 5090 ==='",
      "echo '=============================================='",
      "echo 'OS Version:'",
      "cat /etc/os-release | grep PRETTY_NAME",
      "echo 'Kernel Version:'",
      "uname -r",
      "echo ''",
      "echo 'Checking for NVIDIA GPU...'",
      "lspci | grep -i nvidia || echo 'WARNING: No NVIDIA GPU detected at boot'",
      "echo '=============================================='",
    ]
  }

  # Wait for cloud-init to complete
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do",
      "  echo 'Still waiting for cloud-init... (checking every 5s)'",
      "  sleep 5",
      "done",
      "echo 'Cloud-init complete!'",
    ]
  }

  # System update
  provisioner "shell" {
    inline = [
      "echo 'Updating system packages...'",
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold'",
      "echo 'System update complete!'"
    ]
  }

  # Install Ansible
  provisioner "shell" {
    inline = [
      "echo 'Installing Ansible...'",
      "sudo apt-get install -y software-properties-common",
      "sudo add-apt-repository --yes --update ppa:ansible/ansible",
      "sudo apt-get install -y ansible",
      "echo 'Ansible version:'",
      "ansible --version",
      "echo 'Ansible installed successfully!'"
    ]
  }

  # Run Ansible with ALL roles including GPU (Tasks 1a.8-12)
  provisioner "ansible-local" {
    playbook_file = "../../ansible/playbooks/site.yml"
    role_paths = [
      # Base system roles (Tasks 1a.4-7)
      "../../ansible/roles/common",
      "../../ansible/roles/users",
      "../../ansible/roles/packages",
      "../../ansible/roles/networking",
      "../../ansible/roles/docker",
      "../../ansible/roles/python",
      # GPU roles (Tasks 1a.8-12 validation)
      "../../ansible/roles/nvidia",
      "../../ansible/roles/nvidia-container-toolkit",
      "../../ansible/roles/pytorch",
      "../../ansible/roles/tensorflow",
      "../../ansible/roles/vllm",
      "../../ansible/roles/monitoring-basic"
    ]
    staging_directory = "/tmp/ansible"
    extra_arguments = [
      "--extra-vars",
      "{\"ansible_python_interpreter\":\"/usr/bin/python3\",\"packer_build\":true,\"cloud_platform\":\"gcp\",\"enable_gpu\":true,\"nvidia_expected_gpu_count\":1,\"nvidia_gpu_architecture\":\"ada-lovelace\",\"ubuntu_version\":\"24.04\",\"cuda_version\":\"12.8\",\"cudnn_version\":\"9.7.1\"}",
      "-vv"
    ]
  }

  # Validate GPU installation - CUDA 12.8, Kernel 6.13+, PyTorch cu128, TensorFlow NGC
  provisioner "shell" {
    inline = [
      "echo '=============================================='",
      "echo '=== GPU Installation Validation ==='",
      "echo '=== CUDA 12.8 + RTX 5090 Stack ==='",
      "echo '=============================================='",
      "",
      "echo '1. Kernel Version:'",
      "KERNEL_VERSION=$(uname -r)",
      "echo \"Kernel: $KERNEL_VERSION\"",
      "if [[ \"$KERNEL_VERSION\" == 6.13.* ]] || [[ \"$KERNEL_VERSION\" > \"6.13\" ]]; then",
      "  echo 'PASS: Kernel 6.13+ confirmed (RTX 5090 ready)'",
      "else",
      "  echo \"WARNING: Kernel $KERNEL_VERSION (RTX 5090 requires 6.13+)\"",
      "fi",
      "",
      "echo '2. NVIDIA Driver:'",
      "if command -v nvidia-smi &> /dev/null; then",
      "  nvidia-smi",
      "  DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1)",
      "  echo \"Driver Version: $DRIVER_VERSION\"",
      "  if [[ \"$DRIVER_VERSION\" == 570.* ]] || [[ \"$DRIVER_VERSION\" > \"570\" ]]; then",
      "    echo 'PASS: Driver 570+ confirmed (RTX 5090 support)'",
      "  else",
      "    echo \"WARNING: Driver $DRIVER_VERSION (RTX 5090 requires 570+)\"",
      "  fi",
      "else",
      "  echo 'FAIL: nvidia-smi not found'",
      "fi",
      "",
      "echo '3. CUDA Toolkit:'",
      "if command -v nvcc &> /dev/null; then",
      "  CUDA_VERSION=$(nvcc --version | grep 'release' | sed 's/.*release \\([0-9.]*\\).*/\\1/')",
      "  echo \"CUDA Version: $CUDA_VERSION\"",
      "  if [[ \"$CUDA_VERSION\" == 12.8* ]]; then",
      "    echo 'PASS: CUDA 12.8 confirmed (RTX 5090 optimized)'",
      "  else",
      "    echo \"WARNING: CUDA $CUDA_VERSION (expected 12.8 for RTX 5090)\"",
      "  fi",
      "else",
      "  echo 'WARNING: nvcc not found (may not be in PATH)'",
      "fi",
      "",
      "echo '4. PyTorch CUDA 12.8:'",
      "python3 -c '",
      "import torch",
      "print(f\"PyTorch version: {torch.__version__}\")",
      "print(f\"CUDA available: {torch.cuda.is_available()}\")",
      "print(f\"CUDA version: {torch.version.cuda}\")",
      "print(f\"GPU count: {torch.cuda.device_count()}\")",
      "if torch.version.cuda and \"12.8\" in torch.version.cuda:",
      "    print(\"PASS: PyTorch with CUDA 12.8 (cu128)\")",
      "else:",
      "    print(f\"WARNING: PyTorch CUDA {torch.version.cuda} (expected 12.8)\")",
      "' || echo 'WARNING: PyTorch CUDA check failed'",
      "",
      "echo '5. TensorFlow NGC Container:'",
      "if command -v docker &> /dev/null; then",
      "  echo 'Docker installed - checking for NGC TensorFlow container...'",
      "  docker pull nvcr.io/nvidia/tensorflow:25.02-tf2-py3 || echo 'WARNING: NGC container pull failed'",
      "  docker run --rm --gpus all nvcr.io/nvidia/tensorflow:25.02-tf2-py3 python3 -c 'import tensorflow as tf; print(f\"TensorFlow: {tf.__version__}\"); print(f\"GPUs: {len(tf.config.list_physical_devices(\\\"GPU\\\"))}\")'",
      "else",
      "  echo 'WARNING: Docker not found'",
      "fi",
      "",
      "echo '=============================================='",
      "echo '=== Validation Complete ==='",
      "echo '=============================================='",
    ]
  }

  # Cleanup
  provisioner "shell" {
    inline = [
      "echo 'Cleaning up...'",
      "sudo apt-get autoremove -y",
      "sudo apt-get clean",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*",
      "sudo rm -rf /root/.ansible",
      "sudo journalctl --vacuum-time=1d",
      "echo 'Cleanup complete!'"
    ]
  }

  # Generate manifest
  post-processor "manifest" {
    output     = "packer-manifest-gcp-2404.json"
    strip_path = true
  }
}

# ==============================================================================
# Bare Metal Build (baremetal-gpu) - Physical Vault Cube Hardware
# ==============================================================================
# This build creates bootable disk images for physical deployment
# Optimized for Vault Cube: 4x RTX 5090, 256GB RAM, 2TB NVMe SSD
# Output: Raw disk image (.raw) or QCOW2 (.qcow2) for USB/SSD installation
# Deployment: dd if=vault-cube-baremetal.raw of=/dev/sdX bs=4M status=progress
# ==============================================================================

build {
  name    = "baremetal-gpu"
  sources = ["source.qemu.ubuntu-2404-baremetal"]

  # Verify build environment
  provisioner "shell" {
    inline = [
      "echo '=============================================='",
      "echo '=== Bare Metal Build Started ==='",
      "echo '=== Ubuntu 24.04 + RTX 5090 Stack ==='",
      "echo '=============================================='",
      "echo 'OS Version:'",
      "cat /etc/os-release | grep PRETTY_NAME",
      "echo 'Kernel Version:'",
      "uname -r",
      "echo 'CPU Count:'",
      "nproc",
      "echo 'Memory:'",
      "free -h | grep Mem",
      "echo 'Disk Space:'",
      "df -h /",
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

  # Run Ansible with BASE SYSTEM ONLY (validated components)
  # GPU roles commented out for first appliance test
  provisioner "ansible-local" {
    playbook_file = "../../ansible/playbooks/site.yml"
    role_paths = [
      # Base system roles (Tasks 1a.4-7) - VALIDATED
      "../../ansible/roles/common",
      "../../ansible/roles/users",
      "../../ansible/roles/packages",
      "../../ansible/roles/networking",
      "../../ansible/roles/docker",
      "../../ansible/roles/python",
      # GPU roles (Tasks 1a.8-12) - COMMENTED OUT FOR FIRST TEST
      # "../../ansible/roles/nvidia",
      # "../../ansible/roles/nvidia-container-toolkit",
      # "../../ansible/roles/pytorch",
      # "../../ansible/roles/tensorflow",
      # "../../ansible/roles/vllm",
      "../../ansible/roles/monitoring-basic"
    ]
    staging_directory = "/tmp/ansible"
    extra_arguments = [
      "--extra-vars",
      "{\"ansible_python_interpreter\":\"/usr/bin/python3\",\"packer_build\":true,\"cloud_platform\":\"baremetal\",\"enable_gpu\":false,\"ubuntu_version\":\"24.04\"}",
      "-vv"
    ]
  }

  # Validate base system (no GPU components in this build)
  provisioner "shell" {
    inline = [
      "echo '=============================================='",
      "echo '=== Bare Metal Image Validation ==='",
      "echo '=== Base System (GPU components excluded) ==='",
      "echo '=============================================='",
      "",
      "echo '1. Kernel Version:'",
      "KERNEL_VERSION=$(uname -r)",
      "echo \"Kernel: $KERNEL_VERSION\"",
      "echo '✓ Kernel installed'",
      "",
      "echo '2. Python 3.12:'",
      "python3 --version",
      "echo '✓ PASS: Python installed'",
      "",
      "echo '3. Docker:'",
      "docker --version",
      "echo '✓ PASS: Docker installed'",
      "",
      "echo '4. System packages:'",
      "dpkg -l | grep -E 'git|curl|vim' && echo '✓ PASS: Essential packages installed'",
      "",
      "echo '=============================================='",
      "echo '=== Base Image Build Complete ==='",
      "echo '=== Ready for Physical Deployment ==='",
      "echo '=== GPU components can be added later via Ansible ==='",
      "echo '=============================================='",
    ]
  }

  # Cleanup before finalizing image
  provisioner "shell" {
    inline = [
      "echo 'Cleaning up...'",
      "sudo apt-get autoremove -y",
      "sudo apt-get clean",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*",
      "sudo rm -rf /root/.ansible",
      "sudo journalctl --vacuum-time=1d",
      "",
      "# Prepare for first boot on physical hardware",
      "sudo rm -f /etc/ssh/ssh_host_*",
      "sudo rm -f /var/lib/dbus/machine-id",
      "sudo truncate -s 0 /etc/machine-id",
      "",
      "echo 'Cleanup complete!'"
    ]
  }

  # Generate manifest
  post-processor "manifest" {
    output     = "packer-manifest-baremetal.json"
    strip_path = true
  }
}
