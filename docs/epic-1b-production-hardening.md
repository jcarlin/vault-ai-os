# Epic 1b: Production Hardening & Air-Gap Deployment

**Version:** 1.0
**Date:** 2025-10-29
**Status:** Planned
**Duration:** 3-5 weeks
**Effort:** 120-180 hours
**Depends On:** Epic 1a completion

---

## Executive Summary

Epic 1b transforms the functional demo box from Epic 1a into a **production-ready golden image** for customer deployment. This epic focuses on security hardening, air-gap deployment capability, enterprise monitoring, and rigorous validation.

**Key Deliverable:** Production-ready Vault Cube golden image that can be deployed offline in <30 minutes and passes enterprise compliance requirements.

---

## Goals

### Primary Goal
Transform demo box into production-ready golden image meeting enterprise security, compliance, and air-gap deployment requirements.

### Secondary Goals
1. Achieve CIS Level 1 Benchmark >90% compliance
2. Enable fully offline (air-gapped) installation and operation
3. Implement enterprise-grade monitoring and alerting
4. Validate production performance with MLPerf benchmarks
5. Create comprehensive production documentation
6. Prepare for SOC2/ISO27001/HIPAA compliance audits

---

## Scope

### In Scope
- **Security Hardening:**
  - Full CIS Level 1 compliance (200+ controls)
  - Full disk encryption (LUKS)
  - Secure boot configuration
  - SELinux/AppArmor mandatory access controls
  - Audit logging with tamper-evident storage
  - Secrets management

- **Air-Gap Deployment:**
  - Local APT package mirror (70-100GB)
  - Offline PyPI mirror with CUDA wheels
  - Local Docker registry with pre-cached images
  - NVIDIA driver package bundling
  - Offline installation testing
  - Update mechanism for air-gapped systems

- **Monitoring & Observability:**
  - Prometheus + Grafana stack
  - DCGM GPU metrics exporter
  - NVMe health monitoring (SMART)
  - Thermal and power alerting
  - System health dashboards
  - Air-gap compatible (no cloud dependencies)

- **Validation & Testing:**
  - MLPerf Training and Inference benchmarks
  - PCIe 5.0 bandwidth validation
  - 72-hour soak test under maximum load
  - Offline installation validation
  - Security compliance scanning

- **Documentation:**
  - Production deployment guide
  - Troubleshooting runbooks (10+ scenarios)
  - Compliance documentation (SOC2/ISO27001 readiness)
  - Administrator guide
  - Customer onboarding guide (<30 min setup)

### Out of Scope (Future Epics)
- Kubernetes/container orchestration (Epic 2+)
- CI/CD pipeline automation (Epic 2+)
- Multi-system fleet management (Epic 3+)
- Formal SOC2/ISO27001 audits (Epic 4+)
- Remote management/BMC configuration (Epic 3+)
- Disaster recovery procedures (Epic 3+)

---

## Timeline

### Phase 1: Security Hardening (Weeks 1-2)
**Duration:** 10-12 days
**Effort:** 48-64 hours
**Key Milestone:** System passes CIS Level 1 benchmark with >90% compliance

### Phase 2: Air-Gap Deployment (Weeks 2-3, Parallel with Phase 1)
**Duration:** 8-10 days
**Effort:** 31-44 hours
**Key Milestone:** System installs offline in <30 minutes

### Phase 3: Monitoring & Observability (Week 3-4)
**Duration:** 6-8 days
**Effort:** 19-28 hours
**Key Milestone:** Complete monitoring stack operational in air-gap mode

### Phase 4: Validation & Documentation (Weeks 4-5)
**Duration:** 8-12 days
**Effort:** 32-54 hours
**Key Milestone:** MLPerf benchmarks pass, 72-hour soak test completes, documentation finalized

**Total Duration:** 3-5 weeks (depends on parallelization)

---

## Detailed Task Breakdown

## Phase 1: Security Hardening

### Task 1b.1: CIS Level 1 Hardening (Full Implementation)
**Effort:** 10-15 hours
**MacBook:** ✅ Yes (can develop, validate on hardware)
**Dependencies:** Epic 1a complete

**Description:**
Implement full CIS Level 1 Benchmark for Ubuntu 24.04 LTS (200+ security controls).

**Actions:**
- Acquire CIS Benchmark for Ubuntu 24.04 LTS
- Create `ansible/roles/cis-hardening` role
- Implement all Level 1 controls:
  - **Section 1:** Initial Setup (filesystem, bootloader, process hardening)
  - **Section 2:** Services (disable unnecessary services)
  - **Section 3:** Network Configuration (firewall, packet filtering)
  - **Section 4:** Logging and Auditing (rsyslog, auditd)
  - **Section 5:** Access Control (PAM, SSH, sudo)
  - **Section 6:** System Maintenance (file permissions, user accounts)
- Create exceptions for NVIDIA kernel modules and GPU requirements
- Install OpenSCAP for automated compliance scanning
- Generate compliance report

**CIS Level 1 Sections:**
```yaml
cis_sections:
  1_initial_setup:
    - Filesystem configuration
    - Software updates
    - Filesystem integrity
    - Secure boot settings
    - Additional process hardening

  2_services:
    - Special purpose services (disable: NFS, FTP, HTTP, etc.)
    - Service clients

  3_network_configuration:
    - Network parameters (IP forwarding, packet redirect)
    - Firewall configuration (UFW/iptables)
    - Wireless interfaces

  4_logging_auditing:
    - Configure system accounting (auditd)
    - Configure logging (rsyslog)
    - Ensure log files permissions

  5_access_authentication:
    - Configure PAM
    - User accounts and environment
    - SSH server configuration

  6_system_maintenance:
    - System file permissions
    - User and group settings
```

**GPU-Specific Exceptions:**
```yaml
# Exceptions required for GPU workloads
cis_exceptions:
  - name: "Allow NVIDIA kernel modules"
    control: "1.5.4"
    reason: "NVIDIA drivers require dynamic kernel module loading"

  - name: "Allow GPU device permissions"
    control: "1.1.1.x"
    reason: "GPU containers need /dev/nvidia* device access"

  - name: "Docker service enabled"
    control: "2.1.x"
    reason: "Docker required for containerized workloads"
```

**Testing:**
```bash
# Run OpenSCAP compliance scan
oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_cis_level1_server \
  --results /tmp/cis-results.xml \
  --report /tmp/cis-report.html \
  /usr/share/xml/scap/ssg/content/ssg-ubuntu2404-ds.xml

# Check compliance percentage
grep -A 5 "score system" /tmp/cis-results.xml
```

**Acceptance Criteria:**
- [ ] All CIS Level 1 controls implemented (200+)
- [ ] OpenSCAP scan shows >90% compliance
- [ ] GPU exceptions documented and tested
- [ ] System boots and GPUs accessible after hardening
- [ ] Compliance report generated (HTML format)

---

### Task 1b.2: Full Disk Encryption (LUKS)
**Effort:** 6-8 hours
**MacBook:** ⚠️ VM testing recommended
**Dependencies:** Epic 1a complete

**Description:**
Implement LUKS full disk encryption for data-at-rest protection (HIPAA requirement).

**Actions:**
- Modify Packer template to create encrypted partitions
- Configure LUKS encryption with strong passphrase
- Set up key management for automated boot (TPM 2.0 or key file)
- Configure encrypted swap
- Test encrypted boot process
- Document key recovery procedures

**Partition Layout:**
```
/dev/sda1 - EFI System Partition (512MB, unencrypted)
/dev/sda2 - /boot (1GB, unencrypted for GRUB)
/dev/sda3 - LUKS encrypted volume
  └─ LVM physical volume
      ├─ root (50GB)
      ├─ home (50GB)
      ├─ var (100GB for Docker images)
      └─ swap (64GB)
```

**LUKS Configuration:**
```bash
# Create LUKS volume with strong encryption
cryptsetup luksFormat \
  --type luks2 \
  --cipher aes-xts-plain64 \
  --key-size 512 \
  --hash sha512 \
  --pbkdf argon2id \
  /dev/sda3

# Open encrypted volume
cryptsetup luksOpen /dev/sda3 vaultcube-encrypted

# Create LVM volumes
pvcreate /dev/mapper/vaultcube-encrypted
vgcreate vaultcube-vg /dev/mapper/vaultcube-encrypted
lvcreate -L 50G -n root vaultcube-vg
lvcreate -L 50G -n home vaultcube-vg
lvcreate -L 100G -n var vaultcube-vg
lvcreate -L 64G -n swap vaultcube-vg
```

**TPM 2.0 Integration (Automated Boot):**
```bash
# Enroll LUKS key in TPM 2.0 for automated unlock
systemd-cryptenroll --tpm2-device=auto /dev/sda3
```

**Acceptance Criteria:**
- [ ] Root filesystem encrypted with LUKS2
- [ ] System boots with encrypted disk
- [ ] TPM 2.0 automated unlock functional
- [ ] Manual unlock procedure documented
- [ ] Key recovery procedure tested
- [ ] Performance impact <10% vs unencrypted

---

### Task 1b.3: Secure Boot Configuration
**Effort:** 4-6 hours
**MacBook:** ❌ No (requires UEFI hardware)
**Dependencies:** Task 1b.2

**Description:**
Configure UEFI Secure Boot to prevent unauthorized bootloader modifications.

**Actions:**
- Enroll custom Secure Boot keys (Platform Key, Key Exchange Key, Database)
- Sign bootloader (GRUB) with custom key
- Sign Linux kernel with custom key
- Configure shim for Ubuntu
- Test Secure Boot with signed components
- Document key management procedures

**Secure Boot Keys:**
```bash
# Generate Secure Boot keys
openssl req -new -x509 -newkey rsa:2048 -keyout PK.key -out PK.crt -days 3650 -nodes -subj "/CN=Vault Cube Platform Key/"
openssl req -new -x509 -newkey rsa:2048 -keyout KEK.key -out KEK.crt -days 3650 -nodes -subj "/CN=Vault Cube Key Exchange Key/"
openssl req -new -x509 -newkey rsa:2048 -keyout DB.key -out DB.crt -days 3650 -nodes -subj "/CN=Vault Cube Database Key/"

# Sign GRUB bootloader
sbsign --key DB.key --cert DB.crt /boot/efi/EFI/ubuntu/grubx64.efi

# Sign kernel
sbsign --key DB.key --cert DB.crt /boot/vmlinuz-$(uname -r)
```

**UEFI Configuration:**
- Clear factory Secure Boot keys
- Enroll custom PK, KEK, DB keys
- Enable Secure Boot in UEFI settings
- Test boot with Secure Boot enabled

**Acceptance Criteria:**
- [ ] Custom Secure Boot keys enrolled
- [ ] Bootloader and kernel signed
- [ ] System boots with Secure Boot enabled
- [ ] `mokutil --sb-state` shows "SecureBoot enabled"
- [ ] Key management procedures documented

---

### Task 1b.4: SELinux/AppArmor Mandatory Access Control
**Effort:** 8-10 hours
**MacBook:** ✅ Yes (can develop, validate on hardware)
**Dependencies:** Task 1b.1

**Description:**
Implement SELinux or AppArmor for mandatory access control (process isolation).

**Decision:** Use AppArmor (default on Ubuntu, simpler than SELinux)

**Actions:**
- Enable AppArmor in enforcing mode
- Create custom AppArmor profiles for:
  - Docker daemon
  - NVIDIA driver processes
  - SSH daemon
  - GPU applications
- Test AppArmor profiles in complain mode
- Switch to enforcing mode
- Monitor AppArmor denials

**AppArmor Profile Example (Docker):**
```
# /etc/apparmor.d/docker-daemon
#include <tunables/global>

profile docker-daemon flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>

  capability sys_admin,
  capability sys_chroot,
  capability dac_override,
  capability setuid,
  capability setgid,
  capability net_admin,

  # Allow Docker to access /var/lib/docker
  /var/lib/docker/** rw,
  /var/run/docker.sock rw,

  # Allow GPU access
  /dev/nvidia* rw,
  /usr/lib/x86_64-linux-gnu/libnvidia*.so* mr,
}
```

**Testing:**
```bash
# Load profile in complain mode
apparmor_parser -r -C /etc/apparmor.d/docker-daemon

# Check AppArmor status
aa-status

# Monitor denials
journalctl -u apparmor -f | grep DENIED

# Switch to enforcing mode
aa-enforce docker-daemon
```

**Acceptance Criteria:**
- [ ] AppArmor enabled in enforcing mode
- [ ] Custom profiles for Docker, NVIDIA, SSH
- [ ] `aa-status` shows all profiles loaded
- [ ] Docker containers can access GPUs
- [ ] No AppArmor denials blocking normal operation

---

### Task 1b.5: Audit Logging (auditd) Configuration
**Effort:** 4-6 hours
**MacBook:** ✅ Yes
**Dependencies:** Task 1b.1

**Description:**
Configure comprehensive audit logging for compliance and forensics.

**Actions:**
- Install and configure auditd
- Configure audit rules for:
  - File access (/etc, /var/log, /home)
  - User authentication events
  - Privilege escalation (sudo)
  - Kernel module loading
  - Network connections
  - GPU access
- Configure log rotation and retention (90 days)
- Configure tamper-evident logging (write-once, remote syslog)
- Test audit log generation

**Audit Rules:**
```bash
# /etc/audit/rules.d/vault-cube.rules

# Monitor critical files
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k privilege-escalation
-w /var/log/ -p wa -k logs

# Monitor authentication
-w /var/log/auth.log -p wa -k auth
-w /var/log/faillog -p wa -k auth

# Monitor kernel modules (NVIDIA drivers)
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules

# Monitor GPU access
-w /dev/nvidia0 -p rwa -k gpu-access
-w /dev/nvidiactl -p rwa -k gpu-access

# Monitor Docker
-w /var/lib/docker/ -p wa -k docker
-w /var/run/docker.sock -p wa -k docker

# Monitor privilege escalation
-a always,exit -F arch=b64 -S setuid -S setgid -S setreuid -S setregid -k privilege-escalation
```

**Log Retention:**
```conf
# /etc/audit/auditd.conf
max_log_file = 100
num_logs = 90
max_log_file_action = ROTATE
space_left = 1024
space_left_action = email
admin_space_left = 512
admin_space_left_action = halt
```

**Acceptance Criteria:**
- [ ] auditd installed and running
- [ ] Audit rules configured (30+ rules)
- [ ] Log retention set to 90 days
- [ ] Audit logs rotated daily
- [ ] Test audit event generation (sudo, file access, GPU access)
- [ ] Audit logs immutable (`-w` flag)

---

### Task 1b.6: Secrets Management
**Effort:** 6-8 hours
**MacBook:** ✅ Yes
**Dependencies:** Task 1b.1

**Description:**
Implement secure secrets management (API keys, passwords, certificates).

**Decision:** Use encrypted files with restricted permissions (simple, air-gap compatible)
**Future:** Migrate to HashiCorp Vault in Epic 3 if needed

**Actions:**
- Create secrets directory: `/etc/vaultcube/secrets/`
- Encrypt secrets with GPG
- Configure file permissions (600, owner: root)
- Create secrets management script: `vaultcube-secrets`
- Document secrets rotation procedures
- Test secrets encryption/decryption

**Secrets Structure:**
```bash
/etc/vaultcube/
├── secrets/
│   ├── api-keys.gpg          # Encrypted API keys
│   ├── ssh-keys/             # SSH private keys
│   ├── ssl-certs/            # SSL certificates
│   └── passwords.gpg         # Encrypted passwords
└── secrets-metadata.json     # Non-sensitive metadata
```

**Secrets Management Script:**
```bash
#!/bin/bash
# /usr/local/bin/vaultcube-secrets

case "$1" in
  encrypt)
    gpg --symmetric --cipher-algo AES256 "$2" -o "$2.gpg"
    chmod 600 "$2.gpg"
    ;;
  decrypt)
    gpg --decrypt "$2" -o "${2%.gpg}"
    ;;
  rotate)
    # Rotate secrets (re-encrypt with new key)
    ;;
esac
```

**Acceptance Criteria:**
- [ ] Secrets directory created with proper permissions
- [ ] Test secrets encrypted with GPG
- [ ] Secrets management script functional
- [ ] No plaintext secrets in filesystem
- [ ] Secrets rotation procedure documented

---

## Phase 2: Air-Gap Deployment

### Task 1b.7: Local APT Package Mirror Setup
**Effort:** 8-12 hours
**MacBook:** ✅ Yes (requires 100GB+ disk space)
**Dependencies:** None (can start during Epic 1a)

**Description:**
Create local APT mirror for offline Ubuntu package installation.

**Strategy:** Selective mirror (not full Ubuntu archive)
- **Main:** Base packages (~20GB)
- **Universe:** Additional packages (~30GB)
- **Security:** Security updates (~10GB)
- **Total:** ~70GB (vs 450GB for full mirror)

**Actions:**
- Install apt-mirror
- Configure mirror sources (main, universe, security only)
- Run initial mirror sync (6-12 hours)
- Create APT repository metadata
- Configure Apache/Nginx to serve repository
- Test APT client against local mirror
- Create update procedure (monthly sync)

**apt-mirror Configuration:**
```bash
# /etc/apt/mirror.list
set base_path    /var/spool/apt-mirror
set nthreads     20
set _tilde       0

# Ubuntu 24.04 LTS (Noble)
deb http://archive.ubuntu.com/ubuntu noble main universe
deb http://archive.ubuntu.com/ubuntu noble-security main universe
deb http://archive.ubuntu.com/ubuntu noble-updates main universe

# Clean old packages
clean http://archive.ubuntu.com/ubuntu
```

**Apache Configuration:**
```apache
# /etc/apache2/sites-available/apt-mirror.conf
<VirtualHost *:80>
    ServerName apt.vaultcube.local
    DocumentRoot /var/spool/apt-mirror/mirror/archive.ubuntu.com/ubuntu

    <Directory /var/spool/apt-mirror/mirror/archive.ubuntu.com/ubuntu>
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
</VirtualHost>
```

**Client Configuration:**
```bash
# /etc/apt/sources.list (on golden image)
deb [trusted=yes] http://apt.vaultcube.local noble main universe
deb [trusted=yes] http://apt.vaultcube.local noble-security main universe
deb [trusted=yes] http://apt.vaultcube.local noble-updates main universe
```

**Acceptance Criteria:**
- [ ] APT mirror contains ~70GB packages
- [ ] All required packages available in mirror
- [ ] Golden image builds using only local mirror
- [ ] `apt-get update` works against local mirror
- [ ] Zero network calls during package installation

---

### Task 1b.8: Offline PyPI Mirror (Python Packages)
**Effort:** 6-10 hours
**MacBook:** ✅ Yes (requires 50GB+ disk space)
**Dependencies:** None (can start during Epic 1a)

**Description:**
Create offline PyPI mirror with CUDA-enabled ML library wheels.

**Actions:**
- Install bandersnatch or devpi for PyPI mirroring
- Configure selective mirroring (not all of PyPI):
  - torch, torchvision, torchaudio (CUDA 12.4 wheels)
  - tensorflow (CUDA 12.4 wheels)
  - vllm and dependencies
  - numpy, pandas, scikit-learn
  - All transitive dependencies
- Run initial mirror sync
- Create PyPI server (devpi or static files)
- Configure pip to use local mirror
- Test package installation from mirror

**Package List:**
```txt
# packages.txt - Packages to mirror
torch==2.2.0+cu124
torchvision==0.17.0+cu124
torchaudio==2.2.0+cu124
tensorflow==2.16.0
vllm==0.3.3
numpy==1.26.4
pandas==2.2.0
scikit-learn==1.4.0
transformers==4.38.0
accelerate==0.27.0
```

**devpi Setup:**
```bash
# Install devpi server
pip install devpi-server devpi-web

# Initialize devpi
devpi-init

# Start devpi server
devpi-server --start --host 0.0.0.0 --port 8080

# Create PyPI mirror
devpi use http://localhost:8080
devpi index -c pypi type=mirror mirror_url=https://pypi.org/simple/
```

**pip Configuration:**
```ini
# /etc/pip.conf
[global]
index-url = http://pypi.vaultcube.local:8080/root/pypi/+simple/
trusted-host = pypi.vaultcube.local
```

**Download CUDA Wheels:**
```bash
# Download PyTorch CUDA 12.4 wheels
pip download torch==2.2.0+cu124 torchvision==0.17.0+cu124 torchaudio==2.2.0+cu124 \
  --index-url https://download.pytorch.org/whl/cu124 \
  -d /var/spool/pypi-mirror/

# Download TensorFlow with CUDA
pip download tensorflow==2.16.0 \
  -d /var/spool/pypi-mirror/
```

**Acceptance Criteria:**
- [ ] PyPI mirror contains all required packages (~30GB)
- [ ] CUDA wheels for PyTorch and TensorFlow available
- [ ] pip installs packages from local mirror only
- [ ] Golden image builds with zero PyPI network calls
- [ ] All ML frameworks install successfully from mirror

---

### Task 1b.9: Local Docker Registry
**Effort:** 4-6 hours
**MacBook:** ✅ Yes
**Dependencies:** Epic 1a Task 1a.6

**Description:**
Set up local Docker registry for offline container image storage.

**Actions:**
- Install Docker Registry v2
- Configure persistent storage for images
- Pre-pull and cache essential images:
  - nvidia/cuda:12.4.0-base-ubuntu24.04
  - nvidia/cuda:12.4.0-devel-ubuntu24.04
  - nvidia/cuda:12.4.0-runtime-ubuntu24.04
  - pytorch/pytorch:2.2.0-cuda12.4-cudnn9-runtime
  - tensorflow/tensorflow:2.16.0-gpu
  - Prometheus, Grafana images
- Configure Docker daemon to use local registry
- Test image pull from local registry

**Registry Setup:**
```bash
# Start Docker registry
docker run -d -p 5000:5000 \
  -v /var/lib/docker-registry:/var/lib/registry \
  --restart always \
  --name registry \
  registry:2

# Pre-pull images and push to local registry
docker pull nvidia/cuda:12.4.0-base-ubuntu24.04
docker tag nvidia/cuda:12.4.0-base-ubuntu24.04 localhost:5000/nvidia/cuda:12.4.0-base
docker push localhost:5000/nvidia/cuda:12.4.0-base
```

**Docker Daemon Configuration:**
```json
{
  "insecure-registries": ["registry.vaultcube.local:5000"],
  "registry-mirrors": ["http://registry.vaultcube.local:5000"]
}
```

**Image Manifest:**
```yaml
# images.yml - Images to pre-cache
base_images:
  - nvidia/cuda:12.4.0-base-ubuntu24.04
  - nvidia/cuda:12.4.0-devel-ubuntu24.04
  - nvidia/cuda:12.4.0-runtime-ubuntu24.04

ml_frameworks:
  - pytorch/pytorch:2.2.0-cuda12.4-cudnn9-runtime
  - tensorflow/tensorflow:2.16.0-gpu

monitoring:
  - prom/prometheus:v2.50.0
  - grafana/grafana:10.3.0
  - nvidia/dcgm-exporter:3.3.0-ubuntu22.04

utilities:
  - alpine:latest
  - ubuntu:24.04
```

**Acceptance Criteria:**
- [ ] Docker registry running and persistent
- [ ] 10+ essential images pre-cached (~50GB)
- [ ] `docker pull localhost:5000/nvidia/cuda:12.4.0-base` works
- [ ] Zero DockerHub network calls during golden image build
- [ ] Registry accessible from golden image

---

### Task 1b.10: NVIDIA Driver Package Bundling
**Effort:** 3-4 hours
**MacBook:** ✅ Yes
**Dependencies:** Epic 1a Task 1a.8

**Description:**
Bundle NVIDIA driver packages for offline installation.

**Actions:**
- Download NVIDIA driver .deb packages (driver + CUDA + cuDNN)
- Download NVIDIA Container Toolkit .deb packages
- Create local Debian repository
- Sign repository with GPG key
- Configure APT to use local NVIDIA repository
- Test driver installation from local packages

**Driver Packages:**
```bash
# Download NVIDIA driver packages
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
dpkg -i cuda-keyring_1.1-1_all.deb

# Download driver packages (don't install yet)
apt-get download nvidia-driver-550
apt-get download cuda-toolkit-12-4
apt-get download libcudnn9

# Download Container Toolkit
apt-get download nvidia-container-toolkit
```

**Create Local Repository:**
```bash
# Create repository structure
mkdir -p /var/spool/nvidia-repo/pool/main

# Copy .deb files
cp *.deb /var/spool/nvidia-repo/pool/main/

# Generate repository metadata
cd /var/spool/nvidia-repo
dpkg-scanpackages pool/ /dev/null | gzip -9c > dists/stable/main/binary-amd64/Packages.gz

# Create Release file
apt-ftparchive release dists/stable/ > dists/stable/Release
```

**Client Configuration:**
```bash
# /etc/apt/sources.list.d/nvidia-local.list
deb [trusted=yes] file:///var/spool/nvidia-repo stable main
```

**Acceptance Criteria:**
- [ ] All NVIDIA packages downloaded (~5GB)
- [ ] Local NVIDIA repository created
- [ ] `apt-get install nvidia-driver-550` works offline
- [ ] CUDA toolkit installs from local repository
- [ ] Zero network calls during driver installation

---

### Task 1b.11: Offline Installation Testing
**Effort:** 6-8 hours
**MacBook:** ⚠️ Requires isolated test environment
**Dependencies:** Tasks 1b.7, 1b.8, 1b.9, 1b.10

**Description:**
Validate complete offline installation in air-gapped environment.

**Actions:**
- Create isolated test VM (no network access)
- Copy offline installation media:
  - Golden image ISO or disk image
  - APT mirror (70GB)
  - PyPI mirror (30GB)
  - Docker registry (50GB)
  - NVIDIA driver repository (5GB)
- Perform fresh installation
- Validate all components install without network
- Document offline installation procedure
- Measure installation time (target: <30 minutes)

**Test Procedure:**
```bash
# 1. Create air-gapped VM
# - No network adapter configured
# - Attach offline media (USB or secondary disk)

# 2. Boot golden image

# 3. Mount offline repositories
mount /dev/sdb1 /mnt/offline-repos
rsync -av /mnt/offline-repos/apt-mirror/ /var/spool/apt-mirror/
rsync -av /mnt/offline-repos/pypi-mirror/ /var/spool/pypi-mirror/
rsync -av /mnt/offline-repos/docker-registry/ /var/lib/docker-registry/

# 4. Start local services
systemctl start apt-mirror apache2
systemctl start devpi
systemctl start docker-registry

# 5. Run Ansible provisioning (should work offline)
ansible-playbook -i inventory/localhost ansible/playbooks/site.yml

# 6. Validate
./scripts/validate-offline-install.sh
```

**Validation Checklist:**
```bash
#!/bin/bash
# scripts/validate-offline-install.sh

echo "=== Offline Installation Validation ==="

# Check network isolation
if ping -c 1 8.8.8.8 &> /dev/null; then
    echo "ERROR: Network access detected!"
    exit 1
fi
echo "✓ Network isolated"

# Check APT repository
apt-get update &> /dev/null
if [ $? -eq 0 ]; then
    echo "✓ APT repository accessible"
else
    echo "ERROR: APT repository failed"
    exit 1
fi

# Check PyPI mirror
pip install --dry-run numpy &> /dev/null
if [ $? -eq 0 ]; then
    echo "✓ PyPI mirror accessible"
else
    echo "ERROR: PyPI mirror failed"
    exit 1
fi

# Check Docker registry
docker pull localhost:5000/nvidia/cuda:12.4.0-base &> /dev/null
if [ $? -eq 0 ]; then
    echo "✓ Docker registry accessible"
else
    echo "ERROR: Docker registry failed"
    exit 1
fi

# Check NVIDIA drivers
nvidia-smi &> /dev/null
if [ $? -eq 0 ]; then
    echo "✓ NVIDIA drivers installed"
else
    echo "ERROR: NVIDIA drivers failed"
    exit 1
fi

echo "=== Offline Installation PASSED ==="
```

**Acceptance Criteria:**
- [ ] Golden image installs without any network access
- [ ] All packages install from local repositories
- [ ] NVIDIA drivers install and GPUs detected
- [ ] ML frameworks (PyTorch, TensorFlow, vLLM) functional
- [ ] Installation completes in <30 minutes
- [ ] Offline installation guide documented

---

## Phase 3: Monitoring & Observability

### Task 1b.12: Prometheus + Grafana Installation
**Effort:** 8-12 hours
**MacBook:** ✅ Yes
**Dependencies:** Epic 1a complete

**Description:**
Install and configure Prometheus + Grafana for system and GPU monitoring (air-gap compatible).

**Actions:**
- Create `ansible/roles/prometheus` role
- Install Prometheus server
- Configure Prometheus to scrape:
  - Node Exporter (system metrics)
  - DCGM Exporter (GPU metrics)
  - NVMe exporter (storage metrics)
- Install Grafana
- Configure Grafana data sources (Prometheus)
- Import pre-built dashboards
- Configure alerting rules
- Secure Grafana with authentication
- Test monitoring stack

**Prometheus Configuration:**
```yaml
# /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'dcgm-exporter'
    static_configs:
      - targets: ['localhost:9400']

  - job_name: 'nvme-exporter'
    static_configs:
      - targets: ['localhost:9998']

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']

rule_files:
  - /etc/prometheus/rules/*.yml
```

**Grafana Dashboards:**
1. **System Overview:** CPU, RAM, disk, network
2. **GPU Metrics:** Utilization, temperature, VRAM, power
3. **Storage Health:** NVMe SMART, I/O throughput
4. **AI Workloads:** Inference throughput, batch latency

**Acceptance Criteria:**
- [ ] Prometheus installed and scraping metrics
- [ ] Grafana accessible at http://localhost:3000
- [ ] 4 pre-built dashboards imported
- [ ] Metrics visible for system, GPU, storage
- [ ] Alerting rules configured
- [ ] Works in air-gap mode (no cloud dependencies)

---

### Task 1b.13: DCGM Exporter (GPU Metrics)
**Effort:** 4-6 hours
**MacBook:** ❌ No (GPU hardware required)
**Dependencies:** Task 1b.12, Epic 1a Task 1a.8

**Description:**
Install NVIDIA DCGM Exporter for detailed GPU metrics in Prometheus.

**Actions:**
- Install NVIDIA Data Center GPU Manager (DCGM)
- Install DCGM Exporter
- Configure DCGM to monitor 4× RTX 5090 GPUs
- Configure Prometheus scrape for DCGM exporter
- Create Grafana dashboard for GPU metrics
- Test GPU metrics collection

**DCGM Metrics:**
```yaml
dcgm_metrics:
  - GPU utilization (%)
  - GPU memory utilization (%)
  - GPU memory used (MB)
  - GPU temperature (°C)
  - GPU power draw (W)
  - PCIe throughput (MB/s)
  - NVLink throughput (MB/s)
  - SM clock frequency (MHz)
  - Memory clock frequency (MHz)
  - Thermal throttling events
  - XID errors
```

**DCGM Exporter Configuration:**
```bash
# Start DCGM exporter
docker run -d --gpus all \
  --rm \
  -p 9400:9400 \
  localhost:5000/nvidia/dcgm-exporter:3.3.0-ubuntu22.04

# Or systemd service
systemctl enable dcgm-exporter
systemctl start dcgm-exporter
```

**Sample Grafana Dashboard Queries:**
```promql
# GPU Utilization
dcgm_gpu_utilization{gpu="0"}

# GPU Memory Used
dcgm_fb_used{gpu="0"} / dcgm_fb_total{gpu="0"} * 100

# GPU Temperature
dcgm_gpu_temp{gpu="0"}

# GPU Power Draw
dcgm_power_usage{gpu="0"}

# Thermal Throttling
rate(dcgm_thermal_violation[5m])
```

**Acceptance Criteria:**
- [ ] DCGM exporter running and accessible
- [ ] Prometheus scraping GPU metrics from all 4 GPUs
- [ ] Grafana dashboard shows per-GPU metrics
- [ ] Historical GPU metrics stored (30-day retention)
- [ ] GPU alerts fire correctly (temp >85°C, VRAM >90%)

---

### Task 1b.14: NVMe SMART Monitoring
**Effort:** 3-4 hours
**MacBook:** ⚠️ Limited (VM has emulated storage)
**Dependencies:** Task 1b.12

**Description:**
Monitor NVMe SSD health with SMART metrics.

**Actions:**
- Install smartmontools
- Configure SMART monitoring for 2× Samsung 990 Pro NVMe
- Create Prometheus exporter for SMART metrics
- Configure alerts for:
  - Drive temperature >70°C
  - Wear level >80%
  - Critical SMART attributes
  - Media errors
- Create Grafana dashboard for storage health

**SMART Metrics:**
```yaml
smart_metrics:
  - Temperature
  - Available spare (%)
  - Available spare threshold (%)
  - Percentage used (wear level)
  - Data units read
  - Data units written
  - Power cycles
  - Power on hours
  - Media errors
  - Critical warnings
```

**SMART Exporter:**
```bash
# Install smartctl_exporter
wget https://github.com/prometheus-community/smartctl_exporter/releases/download/v0.12.0/smartctl_exporter-0.12.0.linux-amd64.tar.gz
tar xvf smartctl_exporter-0.12.0.linux-amd64.tar.gz
cp smartctl_exporter /usr/local/bin/

# Create systemd service
cat > /etc/systemd/system/smartctl-exporter.service <<EOF
[Unit]
Description=Prometheus SMART Exporter
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/smartctl_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl enable smartctl-exporter
systemctl start smartctl-exporter
```

**Prometheus Configuration:**
```yaml
# Add to prometheus.yml
scrape_configs:
  - job_name: 'smartctl'
    static_configs:
      - targets: ['localhost:9633']
```

**Acceptance Criteria:**
- [ ] smartmontools installed
- [ ] SMART exporter running on port 9633
- [ ] Prometheus scraping NVMe SMART metrics
- [ ] Grafana dashboard shows drive health
- [ ] Alerts configured for critical SMART attributes

---

### Task 1b.15: Alerting Rules Configuration
**Effort:** 4-6 hours
**MacBook:** ✅ Yes
**Dependencies:** Task 1b.12, 1b.13, 1b.14

**Description:**
Configure Prometheus alerting rules for system and GPU anomalies.

**Actions:**
- Create Prometheus alert rules file
- Configure Alertmanager
- Create alert templates (email, webhook)
- Test alert firing and resolution
- Document alert runbooks

**Alert Rules:**
```yaml
# /etc/prometheus/rules/vault-cube-alerts.yml
groups:
  - name: gpu_alerts
    interval: 30s
    rules:
      - alert: GPUTemperatureHigh
        expr: dcgm_gpu_temp > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "GPU {{ $labels.gpu }} temperature high"
          description: "GPU {{ $labels.gpu }} temperature is {{ $value }}°C (threshold: 85°C)"

      - alert: GPUTemperatureCritical
        expr: dcgm_gpu_temp > 90
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "GPU {{ $labels.gpu }} temperature critical"
          description: "GPU {{ $labels.gpu }} temperature is {{ $value }}°C - immediate action required"

      - alert: GPUMemoryHigh
        expr: (dcgm_fb_used / dcgm_fb_total) * 100 > 90
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "GPU {{ $labels.gpu }} memory usage high"
          description: "GPU {{ $labels.gpu }} memory usage is {{ $value }}%"

      - alert: GPUThermalThrottling
        expr: rate(dcgm_thermal_violation[5m]) > 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "GPU {{ $labels.gpu }} thermal throttling detected"
          description: "GPU {{ $labels.gpu }} is throttling due to thermal constraints"

      - alert: GPUPowerDrawHigh
        expr: dcgm_power_usage > 580
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "GPU {{ $labels.gpu }} power draw high"
          description: "GPU {{ $labels.gpu }} power draw is {{ $value }}W (max: 600W)"

  - name: system_alerts
    interval: 60s
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 90
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is {{ $value }}%"

      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage"
          description: "Memory usage is {{ $value }}%"

      - alert: DiskSpaceLow
        expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 10
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Disk space low on /"
          description: "Only {{ $value }}% disk space remaining"

  - name: storage_alerts
    interval: 300s
    rules:
      - alert: NVMeTemperatureHigh
        expr: smartctl_device_temperature > 70
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "NVMe drive {{ $labels.device }} temperature high"
          description: "NVMe temperature is {{ $value }}°C"

      - alert: NVMeWearLevelHigh
        expr: smartctl_device_percentage_used > 80
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "NVMe drive {{ $labels.device }} wear level high"
          description: "NVMe wear level is {{ $value }}%"

      - alert: NVMeMediaErrors
        expr: smartctl_device_media_errors > 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "NVMe drive {{ $labels.device }} has media errors"
          description: "{{ $value }} media errors detected"
```

**Alertmanager Configuration:**
```yaml
# /etc/alertmanager/alertmanager.yml
global:
  resolve_timeout: 5m

route:
  receiver: 'email-alerts'
  group_by: ['alertname', 'cluster']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  routes:
    - match:
        severity: critical
      receiver: 'email-critical'

receivers:
  - name: 'email-alerts'
    email_configs:
      - to: 'admin@vaultcube.local'
        from: 'prometheus@vaultcube.local'
        smarthost: 'localhost:25'

  - name: 'email-critical'
    email_configs:
      - to: 'oncall@vaultcube.local'
        from: 'prometheus@vaultcube.local'
        smarthost: 'localhost:25'
```

**Acceptance Criteria:**
- [ ] 12+ alert rules configured
- [ ] Alertmanager running and configured
- [ ] Test alert fires correctly (GPU temp >85°C)
- [ ] Alert notifications delivered
- [ ] Runbooks documented for each alert

---

## Phase 4: Validation & Documentation

### Task 1b.16: MLPerf Benchmarks
**Effort:** 6-10 hours
**MacBook:** ❌ No (GPU hardware required)
**Dependencies:** Epic 1a complete, all security hardening complete

**Description:**
Run MLPerf Training and Inference benchmarks to validate production performance.

**Actions:**
- Install MLPerf Training suite
- Install MLPerf Inference suite
- Run ResNet-50 training benchmark (4-GPU)
- Run BERT-Large inference benchmark
- Run Llama-2-70B inference benchmark (if possible with 128GB VRAM)
- Compare results to reference hardware
- Document performance metrics
- Identify bottlenecks

**MLPerf Training Benchmarks:**
```bash
# Clone MLPerf Training repository
git clone https://github.com/mlcommons/training.git
cd training/image_classification

# Run ResNet-50 training (4-GPU DDP)
python train.py \
  --model resnet50 \
  --batch-size 256 \
  --epochs 90 \
  --distributed \
  --world-size 4

# Measure throughput (images/sec)
# Target: >5000 images/sec (4× RTX 5090)
```

**MLPerf Inference Benchmarks:**
```bash
# Clone MLPerf Inference repository
git clone https://github.com/mlcommons/inference.git
cd inference/vision/classification_and_detection

# Run ResNet-50 inference (offline scenario)
python python/main.py \
  --backend pytorch \
  --model resnet50 \
  --scenario Offline

# Run BERT-Large inference
python python/main.py \
  --backend pytorch \
  --model bert \
  --scenario Offline

# Measure throughput (queries/sec) and latency (ms)
```

**Performance Targets:**
| Benchmark | Metric | Target | Notes |
|-----------|--------|--------|-------|
| ResNet-50 Training | Images/sec | >5000 | 4-GPU DDP |
| ResNet-50 Inference | Queries/sec | >10000 | Offline scenario |
| BERT-Large Inference | Queries/sec | >500 | Offline scenario |
| Llama-2-70B Inference | Tokens/sec | >20 | Single GPU (INT8) |

**Acceptance Criteria:**
- [ ] MLPerf Training benchmark completes
- [ ] MLPerf Inference benchmark completes
- [ ] Performance within 5% of reference hardware
- [ ] No thermal throttling during benchmarks
- [ ] Performance metrics documented

---

### Task 1b.17: PCIe 5.0 Bandwidth Validation
**Effort:** 3-4 hours
**MacBook:** ❌ No (requires PCIe 5.0 hardware)
**Dependencies:** Epic 1a Task 1a.8

**Description:**
Validate PCIe 5.0 bandwidth between GPUs and system.

**Actions:**
- Install NVIDIA CUDA samples (bandwidthTest)
- Run PCIe bandwidth tests
- Measure GPU-to-GPU bandwidth (via PCIe switch)
- Compare to theoretical PCIe 5.0 x16 bandwidth (128 GB/s)
- Validate PCIe link speed in nvidia-smi
- Document actual bandwidth achieved

**Bandwidth Tests:**
```bash
# Compile CUDA bandwidth test
cd /usr/local/cuda/samples/1_Utilities/bandwidthTest
make

# Test host-to-device bandwidth
./bandwidthTest --htod

# Test device-to-host bandwidth
./bandwidthTest --dtoh

# Test device-to-device bandwidth (GPU-to-GPU via PCIe)
./bandwidthTest --dtod

# Expected results (PCIe 5.0 x16):
# - Host-to-Device: ~25 GB/s (theoretical: 32 GB/s)
# - Device-to-Host: ~25 GB/s
# - Device-to-Device: ~20 GB/s (via PCIe switch)
```

**PCIe Topology Check:**
```bash
# Check PCIe link speed
nvidia-smi topo -m

# Should show:
# GPU0 - GPU1: PCIe Gen5 x16 (via PCIe switch)
# GPU0 - CPU: PCIe Gen5 x16
```

**Acceptance Criteria:**
- [ ] PCIe 5.0 x16 link confirmed in nvidia-smi
- [ ] Host-to-Device bandwidth >20 GB/s
- [ ] Device-to-Device bandwidth >15 GB/s
- [ ] PCIe topology documented
- [ ] No PCIe errors in dmesg

---

### Task 1b.18: 72-Hour Soak Test
**Effort:** 8-12 hours (mostly unattended)
**MacBook:** ❌ No (GPU hardware required)
**Dependencies:** All previous tasks

**Description:**
Run 72-hour continuous load test to validate stability under sustained load.

**Actions:**
- Create soak test script (GPU + CPU + disk stress)
- Run 72-hour continuous test
- Monitor GPU temperatures, power, throttling
- Monitor system logs for errors
- Measure average GPU utilization
- Document any failures or anomalies
- Validate system recovers cleanly

**Soak Test Script:**
```bash
#!/bin/bash
# scripts/soak-test.sh - 72-hour load test

DURATION=$((72 * 3600))  # 72 hours in seconds
START_TIME=$(date +%s)

echo "=== Starting 72-Hour Soak Test ==="
echo "Start: $(date)"

# Background GPU stress (all 4 GPUs)
for gpu in 0 1 2 3; do
    CUDA_VISIBLE_DEVICES=$gpu python3 << EOF &
import torch
import time

start = time.time()
while time.time() - start < $DURATION:
    # Matrix multiplication stress
    x = torch.randn(10000, 10000).cuda()
    y = torch.randn(10000, 10000).cuda()
    z = torch.matmul(x, y)
    torch.cuda.synchronize()

    # Every 5 minutes, print status
    if int(time.time() - start) % 300 == 0:
        temp = torch.cuda.get_device_properties(0).temperature
        print(f"GPU $gpu: {temp}°C")
EOF
done

# Background CPU stress
stress-ng --cpu 32 --timeout ${DURATION}s &

# Background disk I/O stress
fio --name=soak-test --ioengine=libaio --rw=randrw --bs=4k \
    --size=10G --numjobs=4 --runtime=${DURATION}s --time_based &

# Monitor loop (every 5 minutes)
while true; do
    ELAPSED=$(($(date +%s) - START_TIME))
    if [ $ELAPSED -ge $DURATION ]; then
        break
    fi

    echo "=== Soak Test Status ($(($ELAPSED / 3600))h $(($ELAPSED % 3600 / 60))m) ==="
    nvidia-smi --query-gpu=index,temperature.gpu,utilization.gpu,power.draw --format=csv,noheader
    uptime
    free -h | grep Mem

    # Check for errors
    dmesg | tail -10 | grep -i "error\|warning" || echo "No recent errors"

    sleep 300  # 5 minutes
done

echo "=== Soak Test Complete ==="
echo "End: $(date)"

# Kill background processes
pkill -f "soak-test"
pkill -f "stress-ng"

# Final report
echo "=== Final Status ==="
nvidia-smi
uptime
```

**Monitoring During Soak Test:**
```bash
# Monitor GPU metrics
watch -n 5 'nvidia-smi --query-gpu=index,temperature.gpu,utilization.gpu,power.draw,clocks.current.sm --format=csv,noheader'

# Monitor throttling
watch -n 60 'nvidia-smi --query-gpu=index,clocks_throttle_reasons.active --format=csv,noheader'

# Monitor system logs
journalctl -f | grep -i "error\|warning"
```

**Success Metrics:**
- **Target GPU Utilization:** >90% average
- **Max GPU Temperature:** <90°C
- **Thermal Throttling:** 0 events
- **System Errors:** 0 critical errors
- **Uptime:** 72 hours continuous

**Acceptance Criteria:**
- [ ] System runs 72 hours without crash
- [ ] GPU utilization >90% average
- [ ] No thermal throttling events
- [ ] Max GPU temperature <90°C
- [ ] No critical errors in logs
- [ ] System responsive after soak test

---

### Task 1b.19: Security Compliance Scanning
**Effort:** 4-6 hours
**MacBook:** ⚠️ VM testing recommended
**Dependencies:** All security hardening tasks complete

**Description:**
Run comprehensive security compliance scans and generate compliance report.

**Actions:**
- Run OpenSCAP CIS Level 1 scan
- Run Lynis security audit
- Run vulnerability scanner (OpenVAS or Nessus)
- Review scan results
- Fix critical and high findings
- Generate compliance report
- Document exceptions and remediation

**OpenSCAP CIS Scan:**
```bash
# Run CIS Level 1 scan
oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_cis_level1_server \
  --results /tmp/cis-results.xml \
  --report /tmp/cis-report.html \
  /usr/share/xml/scap/ssg/content/ssg-ubuntu2404-ds.xml

# Generate compliance score
oscap xccdf generate report /tmp/cis-results.xml > /tmp/cis-compliance-report.html

# Extract pass/fail counts
grep -A 10 "Rule Results" /tmp/cis-report.html
```

**Lynis Security Audit:**
```bash
# Run Lynis audit
lynis audit system --quick --log-file /tmp/lynis-report.log

# Check hardening index (target: >85)
grep "Hardening index" /tmp/lynis-report.log
```

**Vulnerability Scan:**
```bash
# Install and run vulnerability scanner
apt-get install -y openvas
openvas-setup
openvas-start

# Run scan (via web UI or CLI)
# Target: 0 critical, <5 high vulnerabilities
```

**Compliance Report Structure:**
```markdown
# Vault Cube Security Compliance Report

## Executive Summary
- CIS Level 1 Compliance: XX%
- Lynis Hardening Index: XX
- Critical Vulnerabilities: XX
- High Vulnerabilities: XX

## Scan Results
### OpenSCAP CIS Level 1
- Total Controls: 200+
- Pass: XX
- Fail: XX
- Not Applicable: XX

### Lynis Audit
- Tests Performed: XX
- Hardening Index: XX/100
- Warnings: XX
- Suggestions: XX

### Vulnerability Scan
- Total Hosts: 1
- Critical: XX
- High: XX
- Medium: XX
- Low: XX

## Remediation Plan
[List of findings requiring remediation]

## Exceptions
[List of CIS controls with documented exceptions]
```

**Acceptance Criteria:**
- [ ] CIS Level 1 compliance >90%
- [ ] Lynis hardening index >85
- [ ] 0 critical vulnerabilities
- [ ] <5 high vulnerabilities
- [ ] Compliance report generated
- [ ] Exceptions documented with justification

---

### Task 1b.20: Production Deployment Guide
**Effort:** 6-10 hours
**MacBook:** ✅ Yes
**Dependencies:** All previous tasks

**Description:**
Create comprehensive production deployment guide for customer use.

**Document Outline:**
```markdown
# Vault Cube Production Deployment Guide

## Table of Contents
1. Introduction
2. Prerequisites
3. Hardware Requirements
4. Pre-Installation Checklist
5. Installation Procedure
6. Post-Installation Validation
7. Configuration
8. Air-Gap Deployment
9. Security Hardening Verification
10. Monitoring Setup
11. Troubleshooting
12. Appendix

## 1. Introduction
[Overview of Vault Cube, target audience, support contacts]

## 2. Prerequisites
### Required Skills
- Linux system administration
- Network configuration
- GPU management (NVIDIA)

### Required Access
- Physical access to Vault Cube
- Network access (if not air-gapped)
- USB drive (128GB+) for air-gap deployment

## 3. Hardware Requirements
### Minimum Specifications
- CPU: AMD Threadripper PRO 7975WX
- RAM: 256GB DDR5 ECC
- GPU: 4× NVIDIA RTX 5090
- Storage: 2× Samsung 990 Pro 4TB NVMe
- PSU: 3000W 80+ Platinum
- Cooling: 12× Noctua fans minimum

### BIOS Configuration
- Enable: UEFI mode
- Enable: Secure Boot
- Enable: TPM 2.0
- Enable: Virtualization (VT-d/AMD-V)
- Set: PCIe to Gen5 (not Auto)
- Set: Boot order (NVMe first)

## 4. Pre-Installation Checklist
- [ ] Hardware assembled and tested
- [ ] BIOS configured per requirements
- [ ] Golden image downloaded and verified (SHA256 checksum)
- [ ] USB drive prepared (for air-gap)
- [ ] Offline repositories available (if air-gap)
- [ ] Network configuration documented
- [ ] Backup plan in place

## 5. Installation Procedure
### Online Installation
[Step-by-step instructions for internet-connected deployment]

### Offline (Air-Gap) Installation
[Step-by-step instructions for air-gapped deployment]

## 6. Post-Installation Validation
### GPU Validation
```bash
nvidia-smi
# Expected: 4× NVIDIA GeForce RTX 5090 visible
```

### ML Framework Validation
```bash
python3 << EOF
import torch
print(f"PyTorch: {torch.__version__}")
print(f"CUDA: {torch.cuda.is_available()}")
print(f"GPUs: {torch.cuda.device_count()}")
EOF
```

### Security Validation
```bash
# Check firewall
ufw status

# Check SSH hardening
grep "PasswordAuthentication" /etc/ssh/sshd_config
# Expected: PasswordAuthentication no
```

## 7. Configuration
### Network Configuration
### User Account Setup
### GPU Performance Tuning
### Storage Configuration

## 8. Air-Gap Deployment
[Detailed air-gap installation procedure]

## 9. Security Hardening Verification
[How to verify CIS compliance, encryption, etc.]

## 10. Monitoring Setup
[How to access Grafana, configure alerts]

## 11. Troubleshooting
### GPU Not Detected
### Driver Installation Fails
### Thermal Throttling
### Network Issues
### Boot Failures

## 12. Appendix
### A. BIOS Screenshots
### B. Network Diagrams
### C. Default Passwords (if any)
### D. Support Contacts
```

**Acceptance Criteria:**
- [ ] Deployment guide >5000 words
- [ ] Online installation procedure documented
- [ ] Offline installation procedure documented
- [ ] Validation steps included
- [ ] Troubleshooting section with 10+ scenarios
- [ ] Guide tested by non-author
- [ ] Customer can deploy in <30 minutes using guide

---

### Task 1b.21: Troubleshooting Runbooks
**Effort:** 6-10 hours
**MacBook:** ✅ Yes
**Dependencies:** Epic 1a + Epic 1b experience

**Description:**
Create detailed troubleshooting runbooks for common operational issues.

**Runbook Template:**
```markdown
# Runbook: [Issue Title]

## Symptom
[What the user observes]

## Impact
[Severity and affected functionality]

## Probable Causes
1. [Most likely cause]
2. [Second most likely]
3. [Other possibilities]

## Diagnostic Steps
1. [How to verify the issue]
2. [How to identify root cause]

## Resolution
### Quick Fix (Temporary)
[Immediate workaround]

### Permanent Fix
[Long-term solution]

## Prevention
[How to avoid this issue in future]

## Related Issues
[Links to related runbooks]
```

**Required Runbooks:**
1. **GPU Not Detected After Boot**
2. **NVIDIA Driver Installation Fails**
3. **Thermal Throttling Detected**
4. **Out of Memory (OOM) Errors**
5. **Docker Cannot Access GPUs**
6. **PyTorch NCCL Timeout**
7. **vLLM Inference Slow**
8. **Disk Space Full**
9. **SSH Connection Refused**
10. **Grafana Dashboard Not Loading**
11. **Air-Gap Installation Fails**
12. **CIS Compliance Scan Failures**

**Acceptance Criteria:**
- [ ] 12+ runbooks created
- [ ] Each runbook follows template
- [ ] Diagnostic commands included
- [ ] Resolution steps tested
- [ ] Runbooks reviewed by operations team

---

### Task 1b.22: Compliance Documentation
**Effort:** 4-6 hours
**MacBook:** ✅ Yes
**Dependencies:** Task 1b.19

**Description:**
Create compliance documentation for SOC2, ISO 27001, and HIPAA readiness.

**Documents to Create:**
1. **Security Controls Matrix**
   - Map CIS controls to SOC2/ISO27001/HIPAA requirements
   - Document control implementation status
   - Identify gaps for future remediation

2. **Data Protection Policy**
   - Encryption at rest (LUKS)
   - Encryption in transit (TLS)
   - Access controls (SSH keys, sudo)
   - Audit logging

3. **Incident Response Plan**
   - Security incident classification
   - Response procedures
   - Escalation paths
   - Forensics procedures

4. **Change Management Policy**
   - Golden image versioning
   - Update procedures
   - Rollback procedures
   - Testing requirements

**Compliance Readiness Checklist:**
```markdown
# SOC2 Readiness Checklist

## CC6.1 - Logical and Physical Access Controls
- [x] SSH key-based authentication only
- [x] Multi-factor authentication (future)
- [x] Firewall enabled (UFW)
- [x] Physical access controls (customer responsibility)

## CC6.6 - Logical Access - Existing Users
- [x] User account review process
- [x] Sudo access logging (auditd)
- [x] Failed login monitoring (fail2ban)

## CC6.7 - Logical Access - Restrictions
- [x] Least privilege principle
- [x] Role-based access control (future)

## CC7.2 - Detection of Security Events
- [x] Audit logging (auditd)
- [x] GPU monitoring (DCGM)
- [x] System monitoring (Prometheus)
- [x] Alerting configured

## CC7.4 - Response to Security Incidents
- [x] Incident response plan documented
- [x] Escalation procedures defined
- [ ] Tabletop exercises (future)
```

**Acceptance Criteria:**
- [ ] Security controls matrix complete
- [ ] Data protection policy documented
- [ ] Incident response plan created
- [ ] Change management policy created
- [ ] Compliance gap analysis complete
- [ ] Documents reviewed by compliance team

---

## Success Criteria

### Security & Compliance
- [ ] CIS Level 1 Benchmark >90% compliance
- [ ] Full disk encryption (LUKS) configured and tested
- [ ] Secure boot enabled and validated
- [ ] SELinux/AppArmor enforcing mode enabled
- [ ] Audit logging configured with 90-day retention
- [ ] Security scan passes (0 critical, <5 high vulnerabilities)
- [ ] Secrets management implemented (no plaintext credentials)

### Air-Gap Requirements
- [ ] System installs offline in <30 minutes (no internet)
- [ ] Local APT mirror contains all required packages (~70GB)
- [ ] Offline PyPI mirror contains all ML libraries (~30GB)
- [ ] Local Docker registry contains all required images (~50GB)
- [ ] NVIDIA drivers install without internet access
- [ ] Update mechanism works in air-gapped environment

### Monitoring & Observability
- [ ] Prometheus + Grafana accessible locally
- [ ] GPU metrics dashboard operational (4× RTX 5090)
- [ ] NVMe health monitoring active
- [ ] Thermal alerting configured (>80°C threshold)
- [ ] Power monitoring active (>2500W threshold)
- [ ] All dashboards work in air-gapped mode

### Validation & Testing
- [ ] MLPerf Training benchmark within 5% of reference
- [ ] MLPerf Inference benchmark within 5% of reference
- [ ] PCIe 5.0 bandwidth test achieves >20GB/s
- [ ] 72-hour soak test completes without errors
- [ ] Offline installation test passes (simulated air-gap)
- [ ] Security compliance scan passes

### Documentation
- [ ] Production deployment guide complete (>5000 words)
- [ ] Troubleshooting runbooks complete (12+ scenarios)
- [ ] Compliance documentation complete (SOC2/ISO27001 readiness)
- [ ] Administrator guide complete
- [ ] Customer onboarding guide achieves <30 min setup time

---

## Deliverables

### Code Deliverables
1. **Ansible Security Roles** - CIS hardening, LUKS encryption, AppArmor, auditd
2. **Air-Gap Setup Scripts** - APT mirror, PyPI mirror, Docker registry automation
3. **Monitoring Stack** - Prometheus, Grafana, DCGM exporter, NVMe exporter
4. **Validation Scripts** - MLPerf runners, PCIe bandwidth test, soak test

### Image Deliverable
5. **Production Golden Image** - `vault-cube-production-v1.0.img`
   - Format: Encrypted disk image
   - Size: ~50GB (compressed)
   - Checksum: SHA256 provided

### Air-Gap Deployment Package
6. **Offline Installer** - `vault-cube-offline-installer-v1.0.iso`
   - APT mirror (70GB)
   - PyPI mirror (30GB)
   - Docker registry (50GB)
   - NVIDIA drivers (5GB)
   - Installation scripts
   - Total: ~155GB

### Documentation Deliverables
7. **Production Deployment Guide** - `docs/production-deployment-guide.md`
8. **Troubleshooting Runbooks** - `docs/runbooks/`
9. **Compliance Documentation** - `docs/compliance/`
10. **Administrator Guide** - `docs/admin-guide.md`
11. **Compliance Report** - `docs/compliance-report.html` (OpenSCAP output)

---

## Risk Management

### Critical Risks

#### Risk 1: Air-Gap Infrastructure Complexity
**Probability:** HIGH (70%)
**Impact:** HIGH (blocks customer deployments)
**Mitigation:**
- Start air-gap setup during Epic 1a (parallel work)
- Test offline installation weekly
- Allocate dedicated storage server (100GB+)
- Have network-connected fallback if air-gap fails initially

#### Risk 2: CIS Compliance Breaks GPU Functionality
**Probability:** MEDIUM (50%)
**Impact:** HIGH (system non-functional)
**Mitigation:**
- Test CIS hardening incrementally (not all at once)
- Validate `nvidia-smi` after each CIS section
- Document all GPU-related exceptions
- Have rollback procedure ready

#### Risk 3: 72-Hour Soak Test Failure
**Probability:** MEDIUM (40%)
**Impact:** MEDIUM (delays production readiness)
**Mitigation:**
- Run progressive stress tests (24hr, 48hr, 72hr)
- Monitor thermal performance closely
- Have thermal mitigation plan (fan curve, undervolting)
- Document thermal limits for customer environments

---

## Communication Plan

### Weekly Status Updates
- Monday: Week planning, dependency checks
- Wednesday: Mid-week progress, blocker resolution
- Friday: Week completion, next week preview

### Milestone Demos
- **End of Week 2:** Security hardening complete, CIS compliance >90%
- **End of Week 3:** Air-gap deployment functional, offline install <30 min
- **End of Week 4:** Monitoring stack operational, MLPerf benchmarks complete
- **End of Week 5:** 72-hour soak test passed, all documentation complete

---

## Next Steps After Epic 1b

### Epic 2: AI/ML Runtime Environment (Recommended Next)
- Multi-model serving (vLLM, TensorRT)
- Model repository and caching
- Fine-tuning workflows (LoRA, PEFT)
- Distributed training (Ray, DeepSpeed)

### Epic 3: Operations & Management
- Fleet management (>10 systems)
- Remote monitoring and management
- Automated update mechanism
- Backup and disaster recovery

### Epic 4: Compliance & Certification
- Formal SOC2 audit
- ISO 27001 certification
- HIPAA BAA preparation
- FedRAMP preparation (if government customers)

---

**Document Version:** 1.0
**Last Updated:** 2025-10-29
**Next Review:** End of Week 2 (adjust based on Epic 1a learnings)
