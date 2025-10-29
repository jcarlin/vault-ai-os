# RTX 5090 Driver Availability Research for Ubuntu 24.04 LTS
**Research Date:** October 29, 2025
**Target Platform:** Ubuntu 24.04 LTS (Noble Numbat)
**GPU:** NVIDIA GeForce RTX 5090 (Blackwell Architecture)
**Status:** CRITICAL PATH RESEARCH

---

## Executive Summary

**GO/NO-GO RECOMMENDATION: CONDITIONAL GO** ✅ (with mitigation strategies)

The RTX 5090 is **technically supported** on Ubuntu 24.04 LTS as of October 2025, but requires careful manual installation and specific driver/kernel configurations. Production deployment is viable but requires:
- Manual driver installation (not out-of-box support)
- Kernel upgrade to 6.11+ recommended (Ubuntu 24.04 ships with 6.8)
- Open kernel modules (proprietary drivers will NOT work)
- Driver version 570.172.08+ or preferably 575+ for stability

---

## 1. NVIDIA Driver 570-Open Availability

### 1.1 Package Repository Status

**NVIDIA CUDA Repository (developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/):**

✅ **CONFIRMED AVAILABLE** - Multiple driver versions found:

| Package Type | Latest Version | Date | Status |
|--------------|----------------|------|--------|
| cuda-drivers-570 | 570.195.03-0ubuntu1 | Latest | Production |
| cuda-drivers-570 | 570.172.08-0ubuntu1 | Stable | Production |
| cuda-drivers-570 | 570.158.01-0ubuntu1 | Older | Deprecated |
| cuda-drivers-570 | 570.133.20-0ubuntu1 | Older | Deprecated |
| cuda-drivers-570 | 570.86.15-0ubuntu1 | Initial RTX 5090 Support | Deprecated |

**Note:** Repository contains standard driver packages, not separate `-open` or `-server` variants at this location.

### 1.2 Ubuntu Launchpad Packages

✅ **CONFIRMED AVAILABLE** - nvidia-driver-570-open in Ubuntu repositories:

| Package | Version | Upload Date | Repository |
|---------|---------|-------------|------------|
| nvidia-driver-570-open | 570.158.01-0ubuntu0.24.04.1 | June 18, 2025 | noble/restricted |
| nvidia-driver-570-server-open | 570.158.01-0ubuntu0.24.04.1 | June 18, 2025 | noble/restricted |

**Status Timeline:**
- March 2025: NVIDIA 570 first made available via Graphics Drivers PPA
- May 2025: Ubuntu officially backported to 24.04/22.04 desktop (after 1 month testing in proposed)
- June 2025: Stable release in main repositories

### 1.3 Installation Methods

**Option A: Ubuntu Repository (Recommended for Desktop)**
```bash
sudo apt update
sudo apt install nvidia-driver-570-open
```

**Option B: Server Variant**
```bash
sudo apt install nvidia-driver-570-server-open
```

**Option C: DKMS Version (for custom kernels)**
```bash
sudo apt install nvidia-dkms-570
```

**Option D: Graphics Drivers PPA (Latest versions)**
```bash
sudo add-apt-repository ppa:graphics-drivers/ppa
sudo apt update
sudo apt install nvidia-driver-570-open
```

---

## 2. RTX 5090 Requirements Analysis

### 2.1 Hardware & Architecture

**GPU Specifications:**
- Architecture: NVIDIA Blackwell (New in 2025)
- CUDA Compute Capability: 12.0
- Memory: 32GB GDDR7
- Release Date: January 30, 2025
- Transistors: 92 billion
- AI Performance: 3,352 TOPS

### 2.2 Kernel Requirements

**Ubuntu 24.04 Default Kernel:** 6.8.0 LTS

**RTX 5090 Kernel Compatibility Matrix:**

| Kernel Version | Status | RTX 5090 Support | Notes |
|----------------|--------|------------------|-------|
| 6.8.0 (Default) | ⚠️ Limited | Partial | Default Ubuntu 24.04 kernel, some detection issues reported |
| 6.11.x | ✅ Good | Full | Confirmed working by community |
| 6.12.x | ✅ Good | Full | Better Blackwell support (originally mentioned requirement) |
| 6.13.x | ✅ Excellent | Full | Recommended by several installation guides |
| 6.14.x | ✅ Excellent | Full | Latest tested, best performance |

**Recommendation:** Upgrade to kernel 6.11+ for optimal support
- Kernel 6.8 may work but has detection issues
- Kernel 6.11+ provides significantly better Blackwell architecture support
- No hard requirement for 6.12+, but newer is better

**Kernel Upgrade Command:**
```bash
# Install mainline kernel (6.11 or newer)
# Method 1: Ubuntu Mainline Kernel PPA
sudo add-apt-repository ppa:cappelikan/ppa
sudo apt update
sudo apt install mainline
# Then use mainline GUI to install kernel 6.11+

# Method 2: Manual installation
wget https://kernel.ubuntu.com/mainline/v6.13/amd64/linux-*.deb
sudo dpkg -i linux-*.deb
```

### 2.3 Driver Version Requirements

**Minimum Requirements:**
- **Absolute Minimum:** Driver 570.86.16+ (Initial RTX 5090 support)
- **Recommended Minimum:** Driver 570.172.08+ (Stable support)
- **Production Recommended:** Driver 575+ (Best stability and performance)

**Critical Requirement:**
- ⚠️ **MUST use NVIDIA Open Kernel Modules**
- ❌ **Proprietary/closed driver WILL NOT WORK with RTX 5090**

### 2.4 Known Compatibility Issues

**Driver 570 Issues:**
1. **Performance Problems:**
   - With CUDA 12.8+ and PyTorch 2.7.1+: Up to 5x slower than RTX 4090
   - ComfyUI nodes performance degradation reported
   - Requires driver 572+ for proper CUDA/PyTorch utilization

2. **Detection Issues:**
   - GPU not detected by `nvidia-smi` on some configurations
   - Black screen after GRUB bootloader
   - Display output problems (only one DisplayPort working)

3. **System Stability:**
   - Server variant uses more power and fans run constantly
   - GNOME crashes due to forced Xorg configuration

**Driver 575 Improvements:**
- ✅ Significantly better stability for RTX 5090
- ✅ NVIDIA Smooth Motion support (RTX 50 series exclusive)
- ✅ Proper CUDA 12.8 and PyTorch 2.7.1+ support
- ✅ Better Blackwell architecture optimization

### 2.5 System Prerequisites

**BIOS/UEFI:**
- ⚠️ **Secure Boot MUST be DISABLED** (Critical requirement)

**Display Configuration:**
- Nouveau driver must be blacklisted
- Wayland may have issues; X11 recommended initially

**Ubuntu 24.04 Status:**
- ❌ **Does NOT ship with RTX 5090 support out-of-box** (as of Oct 2025)
- ✅ Manual installation required but well-documented
- ⚠️ Most tools/libraries still catching up with Blackwell architecture

---

## 3. Alternative Driver Options

### 3.1 nvidia-driver-570-server

**Package:** `nvidia-driver-570-server-open`
**Version:** 570.158.01-0ubuntu0.24.04.1

**Pros:**
- ✅ Available in official Ubuntu repositories
- ✅ Works "right out of the box" on Ubuntu 24.04.2 LTS
- ✅ Designed for server/compute workloads
- ✅ More stable for headless configurations

**Cons:**
- ⚠️ Higher power consumption reported
- ⚠️ Fans run constantly
- ⚠️ Missing i386 libraries (incompatible with Steam, some games)
- ⚠️ Not optimized for desktop/gaming use

**Use Case:** Data centers, compute workloads, headless servers

### 3.2 nvidia-driver-575 (Beta/Proposed)

**Package:** `nvidia-driver-575-server`
**Status:** Available in Ubuntu proposed repository

**Pros:**
- ✅ **Best stability for RTX 5090** (community consensus)
- ✅ NVIDIA Smooth Motion support
- ✅ Optimal CUDA 12.8+ performance
- ✅ Better Blackwell architecture support

**Cons:**
- ⚠️ May be in proposed/testing repository
- ⚠️ Less mature than 570 series
- ⚠️ Requires enabling proposed repository

**Installation:**
```bash
# Enable proposed repository
sudo add-apt-repository "deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc)-proposed restricted"

# Install with preferences
sudo apt update
sudo apt install nvidia-driver-575-server
```

**Recommendation:** ✅ **Preferred option for production RTX 5090 deployments**

### 3.3 nvidia-driver-580 (Latest Available)

**Packages Available:**
- cuda-drivers-580_580.95.05-0ubuntu1
- cuda-drivers-580_580.82.07-0ubuntu1
- cuda-drivers-580_580.65.06-0ubuntu1

**Status:** Available in NVIDIA CUDA repository

**Pros:**
- ✅ Latest driver series
- ✅ Newest features and optimizations
- ✅ Best Blackwell support theoretically

**Cons:**
- ⚠️ Very new, less field testing
- ⚠️ May have undiscovered bugs
- ⚠️ Limited community feedback

**Use Case:** Bleeding-edge testing, latest features required

### 3.4 Fallback to RTX 4090 Compatibility

**Research Finding:** ❌ **NO FALLBACK MODE EXISTS**

- RTX 5090 uses new Blackwell architecture (CUDA compute 12.0)
- RTX 4090 uses Ada Lovelace architecture (CUDA compute 8.9)
- No backward compatibility mode or emulation available
- Cannot use RTX 4090 drivers with RTX 5090
- No "compatibility mode" in NVIDIA drivers for architecture fallback

**Implication:** RTX 5090 requires proper Blackwell-compatible drivers; cannot degrade gracefully to older driver support.

---

## 4. Compatibility Matrix

### 4.1 Driver × Kernel Compatibility

| Driver Version | Kernel 6.8 | Kernel 6.11 | Kernel 6.12 | Kernel 6.13+ | Status |
|----------------|------------|-------------|-------------|--------------|--------|
| 570.86.x (Initial) | ⚠️ Limited | ✅ Works | ✅ Works | ✅ Works | Deprecated |
| 570.158.x | ⚠️ Limited | ✅ Good | ✅ Good | ✅ Good | Current Stable |
| 570.172.x | ⚠️ Limited | ✅ Good | ✅ Good | ✅ Good | Current Stable |
| 575.x | ⚠️ Limited | ✅ Excellent | ✅ Excellent | ✅ Excellent | **Recommended** |
| 580.x | ⚠️ Limited | ✅ Good | ✅ Excellent | ✅ Excellent | Bleeding Edge |

### 4.2 Use Case Recommendations

| Use Case | Recommended Driver | Kernel | Notes |
|----------|-------------------|--------|-------|
| Production ML/AI | nvidia-driver-575-server | 6.11+ | Best CUDA/PyTorch performance |
| Desktop/Gaming | nvidia-driver-575-open | 6.11+ | Smooth Motion support |
| Development/Testing | nvidia-driver-570-open | 6.8+ | Most stable, widely tested |
| Headless Server | nvidia-driver-575-server | 6.11+ | Power efficiency improved |
| Bleeding Edge | nvidia-driver-580 | 6.13+ | Latest features, less tested |

### 4.3 CUDA Compatibility

| CUDA Version | Min Driver | RTX 5090 Support | PyTorch Compatibility |
|--------------|-----------|------------------|----------------------|
| CUDA 12.6 | 570.86+ | ⚠️ Limited | Issues with PyTorch 2.7.1+ |
| CUDA 12.7 | 570.86+ | ⚠️ Limited | Issues with PyTorch 2.7.1+ |
| CUDA 12.8 | 572+ | ✅ Full | Requires driver 572+ |
| CUDA 12.9 | 575+ | ✅ Optimal | Best performance |

---

## 5. Installation Recommendations

### 5.1 Recommended Installation Path (Production)

**Configuration:** Ubuntu 24.04 LTS + RTX 5090 + Production Workloads

**Step-by-Step:**

```bash
# 1. Disable Secure Boot in BIOS/UEFI (REQUIRED)

# 2. Update system
sudo apt update && sudo apt upgrade -y

# 3. Upgrade kernel to 6.11+ (RECOMMENDED)
sudo add-apt-repository ppa:cappelikan/ppa -y
sudo apt update
sudo apt install mainline
# Use mainline GUI to install kernel 6.11 or newer

# 4. Reboot to new kernel
sudo reboot

# 5. Blacklist nouveau
sudo bash -c "echo blacklist nouveau > /etc/modprobe.d/blacklist-nvidia-nouveau.conf"
sudo bash -c "echo options nouveau modeset=0 >> /etc/modprobe.d/blacklist-nvidia-nouveau.conf"
sudo update-initramfs -u

# 6. Install nvidia-driver-575 (RECOMMENDED)
# Enable proposed repository if needed
sudo add-apt-repository "deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc)-proposed restricted"

# Install driver
sudo apt update
sudo apt install nvidia-driver-575-server-open

# OR if 575 not available, use 570:
# sudo apt install nvidia-driver-570-open

# 7. Reboot
sudo reboot

# 8. Verify installation
nvidia-smi
# Should show RTX 5090 with driver version 575.x or 570.x
```

### 5.2 Alternative: Manual Driver Installation

**Use Case:** When repository packages don't work or latest version needed

```bash
# 1. Download latest driver from NVIDIA
# Visit: https://www.nvidia.com/Download/index.aspx
# Select: RTX 5090, Linux 64-bit, Production Branch

# 2. Install build dependencies
sudo apt install build-essential gcc-12 make dkms

# 3. Stop display manager
sudo systemctl isolate multi-user.target

# 4. Run installer (example for 575.x)
sudo bash NVIDIA-Linux-x86_64-575.xx.xx.run --dkms

# 5. Reboot
sudo reboot
```

### 5.3 Minimal Configuration (Development/Testing)

**Use Case:** Quick setup for testing, development

```bash
# Simplest working configuration
sudo apt update
sudo apt install nvidia-driver-570-open
sudo reboot
nvidia-smi
```

**Caveats:**
- May have performance issues with ML workloads
- Kernel 6.8 may have detection problems
- Not recommended for production

---

## 6. Risk Assessment

### 6.1 Technical Risks

| Risk Category | Severity | Probability | Mitigation |
|--------------|----------|-------------|------------|
| **Driver Installation Failure** | High | Medium | Use manual installation method, disable Secure Boot |
| **GPU Not Detected** | High | Medium | Upgrade kernel to 6.11+, use open kernel modules |
| **Performance Degradation** | Medium | Medium | Use driver 575+, upgrade CUDA to 12.8+ |
| **Black Screen Issues** | High | Low | Boot to console, reconfigure X11 |
| **Power/Thermal Issues** | Low | Low | Use server driver variant, monitor temps |
| **CUDA Compatibility** | Medium | Medium | Match driver version with CUDA requirements |

### 6.2 Timeline Risks

**Consideration:** RTX 5090 launched January 30, 2025 (9 months ago as of Oct 2025)

**Maturity Assessment:**
- ✅ Hardware: Mature (9 months in market)
- ✅ Linux Drivers: Stable (570.x series production-ready since March 2025)
- ✅ CUDA Support: Mature (12.8+ fully supports Blackwell)
- ⚠️ Ecosystem Tools: Catching up (some applications still optimizing)

**Production Readiness:** ✅ **READY** (as of October 2025)

### 6.3 Support & Documentation

| Support Channel | Quality | Availability | Notes |
|----------------|---------|--------------|-------|
| NVIDIA Official Docs | Good | High | Comprehensive but generic |
| Ubuntu Launchpad | Good | High | Package-specific documentation |
| Community Forums | Excellent | Very High | Multiple detailed guides available |
| GitHub Guides | Excellent | High | Step-by-step installation scripts |
| Stack Overflow | Good | Medium | Growing knowledge base |

**Notable Resources:**
- [NVIDIA RTX 5090 Ubuntu 24.04 Driver Installation Guide](https://www.kamenski.me/articles/nvidia-rtx5090-ubuntu)
- [GitHub: installing-rtx-5090-on-ubuntu-24.04.2-LTS](https://github.com/bluntstone/installing-rtx-5090-on-ubuntu-24.04.2-LTS)
- [NVIDIA GeForce RTX 5090 Driver Guide](https://github.com/aticzz/NVIDIA-GeForce-RTX-5090-Driver-Guide)

### 6.4 Operational Risks

**Post-Installation:**
- System updates may break driver (DKMS mitigates this)
- Kernel updates require driver rebuild (use DKMS version)
- Ubuntu LTS point releases may have compatibility issues

**Mitigation Strategies:**
1. Use DKMS driver variant for automatic rebuilds
2. Test kernel updates in non-production environment first
3. Keep fallback kernel in GRUB menu
4. Document working configuration

---

## 7. GO/NO-GO Decision Framework

### 7.1 GO Criteria ✅

**Proceed with RTX 5090 deployment if:**
- [ ] Team can perform manual driver installation
- [ ] Secure Boot can be disabled
- [ ] Kernel upgrade to 6.11+ is acceptable
- [ ] Open kernel module requirement is acceptable
- [ ] Time for troubleshooting is available (2-4 hours initial setup)
- [ ] Production deployment can wait for stable configuration
- [ ] ML/AI workload requires RTX 5090 performance

**Risk Tolerance:** Medium to High
**Technical Expertise Required:** Intermediate to Advanced

### 7.2 NO-GO Criteria ❌

**Avoid RTX 5090 deployment if:**
- [ ] Out-of-box installation required (not possible)
- [ ] Secure Boot cannot be disabled
- [ ] Kernel 6.8 LTS must be used (compatibility issues)
- [ ] No time for manual configuration
- [ ] Production stability is critical (consider RTX 4090)
- [ ] No Linux driver experience on team

**Alternative:** RTX 4090 has mature, stable Ubuntu 24.04 support with out-of-box drivers.

### 7.3 Final Recommendation

**CONDITIONAL GO** ✅ with the following implementation plan:

**Phase 1: Preparation (Week 0)**
- [ ] Validate BIOS can disable Secure Boot
- [ ] Download driver packages and test kernel
- [ ] Create backup and recovery plan
- [ ] Document baseline system configuration

**Phase 2: Installation (Week 1)**
- [ ] Install Ubuntu 24.04 LTS
- [ ] Upgrade kernel to 6.11+
- [ ] Install nvidia-driver-575-server-open (or 570 if 575 unavailable)
- [ ] Validate GPU detection and basic functionality

**Phase 3: Validation (Week 1-2)**
- [ ] CUDA toolkit installation and testing
- [ ] PyTorch/TensorFlow compatibility verification
- [ ] Performance benchmarking
- [ ] Stability testing (48+ hours)

**Phase 4: Production (Week 2+)**
- [ ] Deploy workloads gradually
- [ ] Monitor for issues
- [ ] Document any workarounds
- [ ] Create runbook for future installations

---

## 8. Current Driver Availability Summary

### 8.1 Package Availability Status (as of Oct 29, 2025)

| Repository | Package | Version | Status |
|-----------|---------|---------|--------|
| Ubuntu Noble (24.04) | nvidia-driver-570-open | 570.158.01-0ubuntu0.24.04.1 | ✅ Available |
| Ubuntu Noble (24.04) | nvidia-driver-570-server-open | 570.158.01-0ubuntu0.24.04.1 | ✅ Available |
| Ubuntu Proposed | nvidia-driver-575-server | Latest | ✅ Available |
| NVIDIA CUDA Repo | cuda-drivers-570 | 570.195.03-0ubuntu1 | ✅ Available |
| NVIDIA CUDA Repo | cuda-drivers-575 | 575.57.08-0ubuntu1 | ✅ Available |
| NVIDIA CUDA Repo | cuda-drivers-580 | 580.95.05-0ubuntu1 | ✅ Available |
| Graphics Drivers PPA | nvidia-driver-570 | Latest | ✅ Available |

### 8.2 Exact Package Names for Installation

**For Desktop/Gaming:**
```bash
nvidia-driver-570-open          # Stable, tested
nvidia-driver-575-open          # Recommended, better performance
```

**For Server/Compute:**
```bash
nvidia-driver-570-server-open   # Stable, available now
nvidia-driver-575-server        # Recommended, proposed repo
nvidia-driver-575-server-open   # Best option if available
```

**DKMS Variants:**
```bash
nvidia-dkms-570                 # Auto-rebuilds on kernel updates
nvidia-dkms-575                 # Recommended with DKMS
```

---

## 9. Conclusion

The RTX 5090 is **fully supported** on Ubuntu 24.04 LTS as of October 2025, with multiple driver options available through official Ubuntu repositories and NVIDIA CUDA repositories. While manual installation is required (no out-of-box support), the process is well-documented and the driver ecosystem is mature after 9 months of availability.

**Key Takeaways:**
1. ✅ Driver 570.158.01+ available in Ubuntu repos (stable)
2. ✅ Driver 575+ available in proposed/CUDA repos (recommended)
3. ✅ Kernel 6.11+ recommended but not strictly required
4. ⚠️ Open kernel modules mandatory (proprietary won't work)
5. ⚠️ Manual installation required, no auto-detection
6. ⚠️ Secure Boot must be disabled
7. ✅ Production-ready as of October 2025
8. ✅ Well-documented with community support

**Final Verdict:** **PROCEED** with RTX 5090 deployment on Ubuntu 24.04 LTS using driver 575-server-open and kernel 6.11+ for optimal results.

---

## Appendix A: Quick Reference Commands

```bash
# Check current kernel version
uname -r

# Check current driver version
nvidia-smi --query-gpu=driver_version --format=csv,noheader

# List available NVIDIA drivers
ubuntu-drivers devices

# Check if GPU is detected
lspci | grep -i nvidia

# Monitor GPU in real-time
watch -n 1 nvidia-smi

# Check CUDA version
nvcc --version

# Reinstall driver if needed
sudo apt purge nvidia-* -y
sudo apt autoremove -y
sudo apt install nvidia-driver-575-server-open

# Check for errors
sudo dmesg | grep -i nvidia
journalctl -b | grep -i nvidia
```

## Appendix B: Troubleshooting Guide

**Problem:** GPU not detected by nvidia-smi
```bash
# Solution 1: Check if driver loaded
lsmod | grep nvidia

# Solution 2: Rebuild DKMS modules
sudo dkms autoinstall
sudo update-initramfs -u
sudo reboot

# Solution 3: Check kernel version
uname -r  # Should be 6.11 or higher
```

**Problem:** Black screen after driver installation
```bash
# Solution: Boot to console (Ctrl+Alt+F3)
sudo systemctl isolate multi-user.target
sudo apt purge nvidia-* -y
sudo reboot
# Then try server driver variant
```

**Problem:** Performance issues with ML workloads
```bash
# Solution: Upgrade to driver 575+ and CUDA 12.8+
sudo apt install nvidia-driver-575-server-open
# Reinstall PyTorch with CUDA 12.8 support
```

---

**Document Version:** 1.0
**Research Conducted:** October 29, 2025
**Next Review Date:** November 29, 2025 (or when driver 580 reaches production status)
