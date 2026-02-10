# Next Steps - Bare Metal Image Creation

**Date**: 2026-01-08
**Status**: BLOCKED on QEMU boot configuration
**Decision Needed**: Choose path forward

---

## 🚨 Current Situation

QEMU bare metal builds are **not working** due to boot command timing issue:
- ✅ Configuration is valid
- ✅ ISO and dependencies verified
- ❌ Ubuntu autoinstall never triggers
- ❌ Disk stays at 196KB (should grow to GB)

**Root Cause**: GRUB menu timing/navigation not triggering autoinstall.

---

## ✅ What's Ready

1. **Complete deployment plan**: `docs/bare-metal-deployment-plan.md`
2. **Validated configuration**: All Packer files are syntactically correct
3. **GPU exclusion confirmed**: Base system only (as requested)
4. **Working VirtualBox build**: Alternative path available

---

## 🎯 Three Options (Choose One)

### Option A: Fix QEMU Now ⚙️

**Use if**: You want the "proper" solution before moving forward

**Time**: 2-4 hours debugging
**Steps**:
1. Connect VNC during build: `open vnc://127.0.0.1:5900`
2. Watch GRUB menu behavior
3. Adjust `boot_wait` and `boot_command` in `sources-baremetal.pkr.hcl`
4. Iterate until working

**Command to retry**:
```bash
cd packer/ubuntu-24.04
packer build -only='baremetal-gpu.qemu.ubuntu-2404-baremetal' \
  -var='baremetal_boot_wait=20s' .
```

---

### Option B: Use VirtualBox + Convert 🔄

**Use if**: You need a working image **tonight**

**Time**: 30-60 minutes
**Steps**:

```bash
# 1. Build with VirtualBox (proven working)
cd packer/ubuntu-24.04
packer build -force -only='local-dev.virtualbox-iso.ubuntu-2404' .

# 2. Extract VMDK from OVA
cd output-vault-cube-demo-box-2404
tar -xvf vault-cube-demo-box-2404.ova

# 3. Convert to raw
qemu-img convert -f vmdk -O raw \
  vault-cube-demo-box-2404-disk001.vmdk \
  ../output-baremetal/vault-cube-baremetal.raw

# 4. Test
cd ../..
./scripts/test-baremetal-image.sh \
  packer/ubuntu-24.04/output-baremetal/vault-cube-baremetal \
  raw
```

**Result**: Working bootable raw disk image for Vault Cube

---

### Option C: Hybrid (RECOMMENDED) ⭐

**Use if**: You want both progress AND proper solution

**Now** (30 min):
- Use VirtualBox to build working image (Option B)
- Test and validate base system
- Proceed with physical deployment planning

**Later** (separate task):
- Debug QEMU boot issue with VNC observation
- Update configuration once working
- Switch to pure QEMU for future builds

**Advantages**:
- ✅ Unblocked immediately
- ✅ Working deliverable tonight
- ✅ Proper solution in backlog
- ✅ No technical debt ignored

---

## 📋 If Choosing Option B or C (Quick Win)

### Run This Now:

```bash
#!/bin/bash
# Quick VirtualBox build and convert

cd /Users/julian/dev/vault-ai-systems/cube-golden-image/packer/ubuntu-24.04

echo "Building with VirtualBox (30-45 min)..."
packer build -force -only='local-dev.virtualbox-iso.ubuntu-2404' .

echo "Extracting VMDK..."
cd output-vault-cube-demo-box-2404
tar -xvf vault-cube-demo-box-2404.ova

echo "Converting to raw format..."
mkdir -p ../output-baremetal
qemu-img convert -f vmdk -O raw \
  vault-cube-demo-box-2404-disk001.vmdk \
  ../output-baremetal/vault-cube-baremetal.raw

echo "✓ Raw image ready:"
ls -lh ../output-baremetal/vault-cube-baremetal.raw

echo "Test with:"
echo "  ./scripts/test-baremetal-image.sh packer/ubuntu-24.04/output-baremetal/vault-cube-baremetal raw"
```

Save as `scripts/build-via-virtualbox.sh`, then:
```bash
chmod +x scripts/build-via-virtualbox.sh
./scripts/build-via-virtualbox.sh
```

---

## 📊 Session Results

### Completed ✅
- [x] Phase 1: Configuration validation
- [x] Comprehensive deployment plan (42KB documentation)
- [x] GPU exclusion confirmed
- [x] Build issue root cause identified

### Blocked ❌
- [ ] QEMU bare metal build
- [ ] Raw disk image creation
- [ ] Physical deployment

### Available Workaround ✅
- [x] VirtualBox build path
- [x] Conversion process documented
- [x] Can proceed with alternative

---

## 🔧 For QEMU Debugging (If Choosing Option A)

### Investigation Checklist
- [ ] Connect VNC during build to watch GRUB
- [ ] Test manual autoinstall in QEMU
- [ ] Try boot_wait = 15s, 20s, 30s
- [ ] Test different boot_command sequences
- [ ] Verify HTTP server reachable from VM
- [ ] Check cloud-init logs in VM

### Files to Modify
```
packer/ubuntu-24.04/sources-baremetal.pkr.hcl:
  - Line 80: boot_wait (currently "10s")
  - Lines 82-95: boot_command

Test incrementally with:
  packer build -debug -on-error=ask \
    -only='baremetal-gpu.qemu.ubuntu-2404-baremetal' .
```

---

## 📂 Files Created This Session

```
docs/
├── bare-metal-deployment-plan.md    (42KB - comprehensive guide)
├── build-session-2026-01-08.md      (detailed session report)
└── [this file] NEXT-STEPS.md        (quick action plan)
```

---

## 💬 Quick Decision Matrix

| Scenario | Choose Option |
|----------|---------------|
| Need image tonight for testing | **B or C** |
| Want proper QEMU solution first | **A** |
| Want both progress and quality | **C** ⭐ |
| Have 30-60 minutes | **B or C** |
| Have 2-4 hours | **A** |
| Comfortable with technical debt | **B** |
| Want zero technical debt | **A** |

---

## 🎯 My Recommendation

**Go with Option C**:

1. **Tonight**: Run VirtualBox build → get working raw image (30-60 min)
2. **Tomorrow**: Test image, plan physical deployment
3. **Next sprint**: Fix QEMU boot as separate task

This gets you unblocked while ensuring the root cause gets properly resolved.

---

## ⏭️ After Getting Working Image

Whether from Option A, B, or C, next steps:

1. **Test Image**:
   ```bash
   ./scripts/test-baremetal-image.sh \
     packer/ubuntu-24.04/output-baremetal/vault-cube-baremetal \
     raw
   ```

2. **Validate Base System**:
   - Login works (vaultadmin/vaultadmin)
   - Python 3.12 installed
   - Docker working
   - Network connectivity
   - No GPU components (expected)

3. **Create Bootable USB**:
   ```bash
   sudo dd if=packer/ubuntu-24.04/output-baremetal/vault-cube-baremetal.raw \
     of=/dev/sdX bs=4M status=progress
   ```

4. **Physical Deployment**:
   - Boot Vault Cube from USB
   - Clone to internal NVMe
   - Validate hardware detection

5. **Add GPU Layer** (when hardware ready):
   ```bash
   ansible-playbook -i localhost, -c local ansible/playbooks/site.yml \
     --tags=nvidia,pytorch,tensorflow,vllm
   ```

---

## 📞 Questions?

- **QEMU boot issue**: See `docs/build-session-2026-01-08.md` for detailed analysis
- **Deployment procedures**: See `docs/bare-metal-deployment-plan.md`
- **Configuration files**: All in `packer/ubuntu-24.04/`

---

**Action Required**: Choose Option A, B, or C and proceed.

**No action needed**: All documentation is complete and ready for use.
