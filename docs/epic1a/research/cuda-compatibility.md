# CUDA Toolkit Compatibility Research
**Epic 1A Technical Research**
**Date:** 2025-10-29
**Status:** ⚠️ CUDA 12.8 REQUIRED - CUDA 12.4 INCOMPATIBLE

## Executive Summary

The RTX 5090 (Blackwell architecture with SM 12.0 compute capability) **requires CUDA 12.8**. CUDA 12.4 will **NOT work** due to lack of sm_120 architecture support.

### 🚨 Critical Compatibility Requirements

- **CUDA Version:** 12.8 ONLY (12.4 is insufficient)
- **Compute Capability:** SM 12.0 (Blackwell architecture)
- **PyTorch:** 2.7.0+ (with CUDA 12.8 support as of April 2025)
- **TensorFlow:** ⚠️ Limited support - CUDA 12.3 is official recommendation (NOT 12.4 or 12.8)
- **cuDNN:** 9.1.0+ (for PyTorch), 8.9.7+ (for TensorFlow)

---

## CUDA 12.8 vs 12.4 Comparison

### Why CUDA 12.4 Fails with RTX 5090

| Aspect | CUDA 12.4 | CUDA 12.8 |
|--------|-----------|-----------|
| **SM 12.0 Support** | ❌ NO | ✅ YES |
| **RTX 5090 Support** | ❌ Errors on sm_120 | ✅ Full support |
| **PyTorch 2.7+** | ⚠️ Compatibility issues | ✅ Native support |
| **Blackwell Optimization** | ❌ Not optimized | ✅ Fully optimized |
| **Release Status** | Stable (Jan 2024) | Latest (supports RTX 50 series) |

### Error Example with CUDA 12.4
```
RuntimeError: CUDA error: no kernel image is available for execution on the device
Error: sm_120 is not supported
```

**Resolution:** Upgrade to CUDA 12.8

---

## Framework Compatibility Matrix

### PyTorch Compatibility

#### PyTorch 2.4
- **CUDA 12.4:** ✅ Supported
- **cuDNN:** 8.9.7.29
- **RTX 5090:** ❌ NOT supported (requires CUDA 12.8)

#### PyTorch 2.5
- **CUDA 12.4:** ✅ Supported
- **cuDNN:** 9.1.0.70
- **RTX 5090:** ⚠️ Limited support (nightly builds only)

#### PyTorch 2.6
- **CUDA 12.4:** ✅ Maintained as stable
- **CUDA 12.6:** 🔄 Migration planned
- **RTX 5090:** ⚠️ Partial support

#### PyTorch 2.7+ (REQUIRED for RTX 5090)
- **CUDA 12.8:** ✅ Full support (as of April 24, 2025)
- **cuDNN:** 9.1.0+
- **RTX 5090:** ✅ Native support
- **Compute Capability:** SM 12.0 fully supported

**Installation:**
```bash
# PyTorch 2.7+ with CUDA 12.8
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128

# Verify
python3 -c "import torch; print(torch.cuda.is_available()); print(torch.version.cuda)"
```

**Important:** PyTorch ships with bundled CUDA runtime. You don't need to install CUDA Toolkit separately for PyTorch.

---

### TensorFlow Compatibility

#### TensorFlow 2.x Status (⚠️ PROBLEMATIC)

| TensorFlow Version | CUDA Support | RTX 5090 Support | Status |
|-------------------|--------------|------------------|--------|
| 2.12.0 | 11.8, 12.0 | ❌ NO | Does not detect GPU with CUDA 12.4/12.8 |
| 2.16.1 | 12.3 | ⚠️ Workaround possible | Unofficial, requires manual config |
| Latest (2025) | **12.3 recommended** | ⚠️ Limited | Not officially supported |

**Official TensorFlow Recommendation:** CUDA 12.3 (NOT 12.4 or 12.8)

**Issue:** TensorFlow does NOT officially support CUDA 12.4 or 12.8 with cuDNN 9.0+

**Workarounds:**
1. Use TensorFlow 2.16.1 with CUDA 12.3 (closest supported version)
2. Build TensorFlow from source with CUDA 12.8 support
3. Use containerized TensorFlow NGC images from NVIDIA

**Community Report (June 2024):**
> "TensorFlow v2.12.0 unable to detect GPU with CUDA Toolkit 12.4 and cuDNN 9.0.0"

---

### cuDNN Compatibility

#### cuDNN 9.x
- **PyTorch 2.5:** cuDNN 9.1.0.70 ✅
- **PyTorch 2.7:** cuDNN 9.1.0+ ✅
- **TensorFlow 2.x:** ⚠️ cuDNN 9.0+ NOT officially supported

#### cuDNN 8.x
- **PyTorch 2.4:** cuDNN 8.9.7.29 ✅
- **TensorFlow 2.12:** cuDNN 8.x preferred ✅

**Recommendation for RTX 5090:**
- **PyTorch:** Use cuDNN 9.1.0+ (bundled with PyTorch 2.7+)
- **TensorFlow:** Use cuDNN 8.x with CUDA 12.3 until official support arrives

---

## Installation Recommendations

### Option 1: PyTorch-Only Environment (RECOMMENDED)
```bash
# CUDA 12.8 + PyTorch 2.7+
# PyTorch bundles CUDA runtime - no separate CUDA installation needed

pip3 install torch==2.7.0 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
```

**Advantages:**
- ✅ Full RTX 5090 support
- ✅ CUDA bundled (no manual CUDA installation)
- ✅ cuDNN bundled
- ✅ Latest optimizations

**Disadvantages:**
- ⚠️ Cannot use with RTX 40/30 series in same environment (separate Docker images required)

---

### Option 2: TensorFlow-Only Environment
```bash
# CUDA 12.3 + TensorFlow 2.16.1
# Requires manual CUDA 12.3 installation

sudo apt install cuda-toolkit-12-3
pip3 install tensorflow==2.16.1
```

**Advantages:**
- ✅ Stable TensorFlow installation
- ✅ Documented compatibility

**Disadvantages:**
- ❌ Limited RTX 5090 optimization
- ⚠️ May require building from source for full support
- ⚠️ CUDA 12.3 lacks latest Blackwell optimizations

---

### Option 3: Mixed Environment (NOT RECOMMENDED)
**Challenge:** PyTorch wants CUDA 12.8, TensorFlow wants CUDA 12.3

**Solutions:**
1. **Separate Docker containers** (RECOMMENDED)
   - PyTorch container: CUDA 12.8
   - TensorFlow container: CUDA 12.3

2. **Conda environments** (LIMITED)
   - Conda can isolate CUDA versions
   - Complex to configure

3. **Build TensorFlow from source with CUDA 12.8** (ADVANCED)
   - Time-consuming
   - Requires expertise
   - Not officially supported

---

## Docker Container Recommendations

### PyTorch + RTX 5090
```dockerfile
# Use NVIDIA PyTorch NGC container with CUDA 12.8
FROM nvcr.io/nvidia/pytorch:25.02-py3

# PyTorch 2.7+ with CUDA 12.8 support included
# Supports Blackwell architecture (SM 12.0)
```

**Command:**
```bash
docker run --gpus all --ipc=host --ulimit memlock=-1 --ulimit stack=67108864 \
  -it nvcr.io/nvidia/pytorch:25.02-py3
```

**Environment Variables:**
```bash
# If Flash Attention 3 issues occur with Blackwell
export VLLM_FLASH_ATTN_VERSION=2
```

---

### TensorFlow + RTX 5090
```dockerfile
# Use NVIDIA TensorFlow NGC container
FROM nvcr.io/nvidia/tensorflow:22.06-tf2-py3

# TensorFlow with CUDA 12.3 support
# Note: May require custom build for RTX 5090 optimization
```

---

## Known Bugs and Issues

### Issue 1: PyTorch sm_120 Not Compiled
**Symptom:**
```
RuntimeError: RTX 5090 with CUDA capability sm_120 is not compatible with current PyTorch installation
```

**Cause:** PyTorch version < 2.7 with CUDA < 12.8
**Solution:** Upgrade to PyTorch 2.7+ with CUDA 12.8

---

### Issue 2: TensorFlow GPU Not Detected
**Symptom:**
```
Could not load dynamic library 'libcudnn.so.9'
No GPU devices available
```

**Cause:** TensorFlow 2.x does not support cuDNN 9.0+ with CUDA 12.4/12.8
**Solution:**
- Use CUDA 12.3 + cuDNN 8.x + TensorFlow 2.16.1
- OR build TensorFlow from source
- OR use NVIDIA NGC TensorFlow container

---

### Issue 3: Mixed GPU Architecture Support
**Symptom:** Need to support both RTX 5090 (SM 12.0) and RTX 4090 (SM 8.9) in same environment

**Cause:** CUDA 12.8 required for RTX 5090, but RTX 40/30 series don't support CUDA 12.8

**Solution:** Maintain separate Docker images:
```bash
# RTX 5090 image
FROM nvcr.io/nvidia/pytorch:25.02-py3  # CUDA 12.8

# RTX 4090 image
FROM nvcr.io/nvidia/pytorch:24.05-py3  # CUDA 12.4
```

---

## Compatibility Testing Checklist

### Pre-Deployment Validation
```bash
# 1. Verify CUDA version
nvcc --version  # Should show 12.8

# 2. Verify driver supports CUDA 12.8
nvidia-smi  # Check CUDA Version in output

# 3. Test PyTorch
python3 -c "import torch; print(torch.cuda.is_available()); print(torch.cuda.get_device_name(0))"

# 4. Test compute capability detection
python3 -c "import torch; print(torch.cuda.get_device_capability(0))"
# Should return (12, 0) for RTX 5090

# 5. Verify cuDNN
python3 -c "import torch; print(torch.backends.cudnn.version())"
# Should return 9010x+ for cuDNN 9.1
```

---

## Performance Optimization Notes

### CUDA 12.8 Optimizations for Blackwell
- **Tensor Cores:** Enhanced FP8/FP16 support
- **Memory Bandwidth:** Optimized for GDDR7
- **NVLink:** NVSwitch support for multi-GPU
- **Kernel Launches:** Reduced latency for small kernels

### Mixed Precision Training
```python
# PyTorch AMP with RTX 5090
import torch
from torch.cuda.amp import autocast, GradScaler

scaler = GradScaler()

with autocast():
    output = model(input)
    loss = criterion(output, target)

scaler.scale(loss).backward()
scaler.step(optimizer)
scaler.update()
```

---

## Risk Assessment

### 🔴 HIGH RISK
- **TensorFlow compatibility** - No official CUDA 12.8 support
- **Mixed architecture support** - Requires separate environments

### 🟡 MEDIUM RISK
- **CUDA 12.8 maturity** - Relatively new (released for RTX 50 series)
- **Framework update frequency** - Rapid changes in PyTorch 2.7+

### 🟢 LOW RISK
- **PyTorch compatibility** - Well-supported with CUDA 12.8
- **cuDNN 9.1** - Stable with PyTorch 2.7+

---

## Recommendations for Epic 1A

### Primary Development Environment
**Framework:** PyTorch 2.7+
**CUDA:** 12.8
**cuDNN:** 9.1.0+ (bundled)
**Container:** `nvcr.io/nvidia/pytorch:25.02-py3`

**Rationale:**
- Full RTX 5090 support
- No manual CUDA installation required
- Latest optimizations for Blackwell architecture

---

### Secondary Environment (If TensorFlow Required)
**Framework:** TensorFlow 2.16.1
**CUDA:** 12.3
**cuDNN:** 8.x
**Container:** Custom build or NGC container

**Rationale:**
- Closest stable TensorFlow configuration
- May require source build for optimal RTX 5090 support

---

## Automation Implications (Packer/Ansible)

### Docker-Based Approach (RECOMMENDED)
```yaml
# Ansible playbook
- name: Pull PyTorch NGC container
  docker_image:
    name: nvcr.io/nvidia/pytorch:25.02-py3
    source: pull

# No CUDA installation required - bundled in container
```

**Advantages:**
- ✅ No manual CUDA installation
- ✅ Version consistency
- ✅ Easy rollback
- ✅ Multi-environment support

---

### Manual Installation Approach (NOT RECOMMENDED)
```yaml
# Would require:
- CUDA 12.8 installation from NVIDIA runfile
- cuDNN 9.1 installation
- PyTorch pip installation with CUDA 12.8
- Complex dependency management
```

**Disadvantages:**
- ❌ Complex dependency chain
- ❌ Version conflicts
- ❌ Difficult to maintain

---

## References

- PyTorch GitHub: CUDA support matrix issues #134015, #138609
- TensorFlow GitHub: GPU support issue #70444
- NVIDIA PyTorch NGC Containers: Release notes
- NVIDIA CUDA Toolkit: 12.8 release notes
- Community compatibility matrices: eminsafa/pytorch-cuda-compatibility

---

## Next Steps for Epic 1A

1. ✅ Standardize on PyTorch 2.7+ with CUDA 12.8
2. ✅ Use NGC containers for deployment (avoid manual CUDA installation)
3. ⚠️ Create separate environment for TensorFlow if required
4. ✅ Document Flash Attention 2 fallback (Flash Attention 3 not yet compatible)
5. ✅ Test compute capability detection in validation scripts
