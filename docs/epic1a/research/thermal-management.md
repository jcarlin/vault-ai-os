# Thermal Management Research: 4× RTX 5090 Configuration
**Epic 1A Technical Research**
**Date:** 2025-10-29
**Status:** ⚠️ EXTREME THERMAL REQUIREMENTS - CUSTOM COOLING MANDATORY

## Executive Summary

A 4× RTX 5090 configuration with Threadripper PRO generates **~2.5-3.2kW of heat** requiring enterprise-grade cooling solutions. Standard PC cooling is **INSUFFICIENT**.

### 🚨 Critical Thermal Findings

1. **Total Heat Output:** 2.5-3.2kW (GPUs alone, excluding CPU/system)
2. **Per-GPU TDP:** 575W rated, **~800W peak** reported in engineering samples
3. **Cooling Solution:** **Custom liquid cooling REQUIRED** (air cooling insufficient)
4. **Chassis Requirement:** Corsair Obsidian 1000D or equivalent full-tower
5. **Alternative:** 5U rackmount with 2800W PSU (200-240V required)

---

## RTX 5090 Thermal Specifications

### Power Specifications
| Metric | Rated | Peak (Engineering) | Notes |
|--------|-------|-------------------|-------|
| **TDP (Single GPU)** | 575W | ~800W | Peak during workloads |
| **4× GPUs Total** | 2,300W | 3,200W | Excludes CPU/system |
| **Idle Power** | ~50W/GPU | 200W total | Minimal savings at idle |

### Temperature Specifications
| Component | Normal | Warning | Critical | Throttle Point |
|-----------|--------|---------|----------|----------------|
| **GPU Core** | 65-71°C | 75-80°C | 85°C+ | 90°C |
| **Memory Junction (GDDR7)** | 70-84°C | 90-100°C | 105°C | 110°C |
| **Hotspot** | 80-90°C | 95-100°C | 105°C+ | 110°C |
| **VRM** | 70-85°C | 90-100°C | 105°C+ | 110°C |

**During extended stress testing:**
- GPU Core: **71°C peak** (575W load)
- Memory Junction: **84°C peak** (well below 110°C throttle)

---

## Threadripper PRO 9995WX Thermal Requirements

### CPU Power Specifications
| Metric | Value | Notes |
|--------|-------|-------|
| **TDP** | 350W | Base specification |
| **PPT (Package Power Tracking)** | ~400W | Peak sustained |
| **cTDP Range** | 280-400W | Configurable |

### Combined System Heat Output
```
4× RTX 5090:     2,300W (rated) to 3,200W (peak)
1× Threadripper:   350W (rated) to 400W (peak)
Motherboard:       100W
RAM (256GB):       80W
Storage/Fans:      70W
------------------------
TOTAL:          2,900W (rated) to 3,850W (peak)
```

**Thermal Output:** ~2.9-3.8kW = **9,900-13,000 BTU/hr**

---

## Cooling Solutions Analysis

### Option 1: Custom Liquid Cooling (RECOMMENDED)

#### Dual-Loop Configuration
**Loop 1: CPU (Threadripper PRO)**
- **Radiator:** 360mm × 60mm (triple 120mm fans)
- **Flow Rate:** 1.0 GPM
- **Cooling Capacity:** 400W+
- **Pump:** D5 or DDC high-performance

**Loop 2: GPUs (4× RTX 5090)**
- **Radiator:** 2× 480mm × 60mm (quad 120mm fans each) OR 1× 560mm × 80mm
- **Flow Rate:** 1.5-2.0 GPM (high-flow)
- **Cooling Capacity:** 2,500W+
- **Pump:** Dual D5 pumps in series (for high flow rate)
- **Water Blocks:** 4× full-coverage GPU blocks

**Total Radiator Area:** 360mm + 960mm = **1,320mm** (11× 120mm fans minimum)

---

#### Component List (Dual-Loop Build)
```yaml
# CPU Loop
- CPU Block: EK Quantum Velocity² (Threadripper)
- Radiator: 1× 360mm × 60mm
- Fans: 3× Noctua NF-A12x25 (120mm, high static pressure)
- Pump: EK-D5 PWM
- Reservoir: 250-300ml

# GPU Loop
- GPU Blocks: 4× EK Quantum Vector² RTX 5090 (when available)
- Radiators: 2× 480mm × 60mm OR 1× 560mm × 80mm
- Fans: 8-10× Noctua NF-A12x25
- Pumps: 2× EK-D5 PWM (series configuration)
- Reservoir: 500ml+

# Shared
- Coolant: EK-CryoFuel (clear or solid, 5L+)
- Tubing: 16mm OD soft tubing or PETG hard tubing
- Fittings: 30-40× compression fittings
- Radiator Mounts: Custom or case-specific

# Estimated Cost: $3,000-4,500
```

---

#### Chassis Requirement
**Corsair Obsidian 1000D** (or equivalent)
- **Radiator Support:**
  - Top: 3× 360mm or 2× 480mm
  - Front: 1× 480mm
  - Side: 1× 360mm
- **Dimensions:** 693mm × 307mm × 697mm (H×W×D)
- **Weight:** 30kg+ (with water cooling)

**Alternative:** Thermaltake Core W200 (full open-air design)

---

### Option 2: Hybrid Liquid + High-Airflow

#### Configuration
- **GPUs:** AIO liquid-cooled RTX 5090 models (ASUS ROG or MSI)
  - 4× pre-installed AIOs (360mm radiators each)
  - Requires 4× 360mm radiator mounting locations
- **CPU:** Custom loop or AIO (360mm-420mm)

**Challenges:**
- Very few chassis support 5× 360mm radiators
- Complex cable management
- Difficult maintenance

**Verdict:** ⚠️ Not recommended for 4-GPU config (works better with 2 GPUs)

---

### Option 3: Air Cooling (❌ NOT RECOMMENDED)

#### Why Air Cooling Fails
**Single RTX 5090 (Air):**
- **Cooler Design:** Triple-fan, 4-slot width
- **Thermal Performance:** 71°C at 575W (adequate for single card)

**4× RTX 5090 (Air):**
- **Spacing:** 4-slot cards leave minimal gap between GPUs
- **Airflow:** Bottom 2 GPUs starve for air (intake blocked)
- **Exhaust:** Hot air from GPU 1-2 feeds into GPU 3-4 intakes
- **Result:** Thermal throttling on bottom GPUs, 85-95°C temps

**Verdict:** ❌ **DO NOT use air cooling for 4× RTX 5090**

---

### Option 4: 5U Rackmount (ENTERPRISE SOLUTION)

#### Puget Systems Approach
- **Form Factor:** 5U rackmount chassis
- **GPUs:** 2× RTX 5090 (dual config tested)
- **Power:** 2800W PSU (200-240V required)
- **Cooling:** Rackmount-grade fans (high CFM, high noise)
- **Expandability:** Can support 4× GPUs with proper airflow

**Advantages:**
- ✅ Enterprise-grade reliability
- ✅ Hot-swap PSUs
- ✅ Datacenter-compatible
- ✅ Supports remote management (IPMI)

**Disadvantages:**
- ⚠️ Extremely loud (60-80 dB)
- ⚠️ Requires 240V power circuit
- ⚠️ Expensive ($1,500+ for chassis alone)
- ⚠️ Not office/lab-friendly (noise)

**Recommended Use Case:** Datacenter or dedicated server room

---

## Motherboard Thermal Considerations

### ASUS Pro WS WRX90E-SAGE SE
**PCIe Slot Spacing:** 7× PCIe 5.0 x16 slots
- **Advantage:** Full x16 spacing between GPUs (better airflow)
- **RTX 5090 4-slot cards:** Can fit 4× GPUs with 1-2 slot gaps

**VRM Cooling:**
- **VRM TDP:** 350W+ support for Threadripper PRO
- **Heatsinks:** Passive heatsinks (consider adding active cooling)
- **Recommendation:** Direct case fan airflow over VRM area

---

## Cooling Configuration Recommendations

### Recommended: Dual-Loop Liquid Cooling in Corsair 1000D

#### Fan Configuration (11-13 fans total)
```yaml
# Intake (positive pressure)
- Front: 3× 120mm (480mm rad for GPU loop) - 1500 RPM
- Bottom: 3× 120mm (direct GPU intake) - 1200 RPM

# Exhaust
- Top: 3× 120mm (360mm rad for CPU loop) - 1500 RPM
- Rear: 2× 120mm (480mm rad for GPU loop, 2nd rad) - 1500 RPM
- Side: 1-2× 120mm (case exhaust) - 1000 RPM

# Total CFM: ~250-350 CFM (positive pressure)
```

#### Coolant Temperature Targets
```yaml
CPU Loop:
  Idle: 25-30°C
  Load: 35-45°C

GPU Loop:
  Idle: 30-35°C
  Load: 40-50°C

Acceptable delta T (coolant to ambient): 10-20°C
```

---

### Fan Curve Recommendations

#### GPU Radiator Fans (Critical)
```python
# Temperature-based curve (coolant temp sensor)
{
  "30°C": "40%",   # 500 RPM - Idle
  "35°C": "50%",   # 650 RPM
  "40°C": "65%",   # 850 RPM
  "45°C": "80%",   # 1050 RPM - Training workload
  "50°C": "100%"   # 1300 RPM - Maximum
}
```

#### CPU Radiator Fans
```python
{
  "25°C": "35%",   # 450 RPM - Idle
  "30°C": "45%",   # 600 RPM
  "35°C": "60%",   # 780 RPM
  "40°C": "80%",   # 1050 RPM - Heavy compilation
  "45°C": "100%"   # 1300 RPM - Maximum
}
```

---

## Stress Testing and Monitoring

### Thermal Stress Test Protocol

#### Phase 1: Single GPU Validation (30 minutes)
```bash
# Install CUDA samples
cuda-install-samples-12.8.sh ~

# Compile and run stress test
cd ~/NVIDIA_CUDA-12.8_Samples/0_Introduction/matrixMul
make
./matrixMul -wA=10240 -wB=10240 -hA=10240 -hB=10240

# Monitor temperatures
watch -n 1 nvidia-smi --query-gpu=temperature.gpu,temperature.memory,power.draw --format=csv
```

**Expected Results:**
- GPU Temp: 65-71°C
- Memory Temp: 70-84°C
- Power Draw: 550-575W

---

#### Phase 2: Multi-GPU Stress Test (1-2 hours)
```bash
# Use PyTorch distributed training stress test
python3 - <<EOF
import torch
import torch.nn as nn
import torch.distributed as dist
from torch.nn.parallel import DistributedDataParallel as DDP

# Initialize 4-GPU training
dist.init_process_group(backend='nccl', world_size=4)

# Large model to stress GPUs
model = nn.Sequential(
    nn.Linear(10000, 20000),
    nn.ReLU(),
    nn.Linear(20000, 20000),
    nn.ReLU(),
    nn.Linear(20000, 10000)
).cuda()

model = DDP(model)

# Stress test loop (runs indefinitely)
while True:
    x = torch.randn(1024, 10000).cuda()
    y = model(x)
    loss = y.sum()
    loss.backward()
EOF

# In separate terminal, monitor all GPUs
watch -n 1 'nvidia-smi --query-gpu=index,temperature.gpu,temperature.memory,power.draw,clocks.gr --format=csv'
```

**Acceptable Limits:**
- GPU Temp: <80°C sustained
- Memory Temp: <95°C sustained
- Power Draw: 550-600W per GPU
- No thermal throttling

---

#### Phase 3: Thermal Soak Test (8-24 hours)
```bash
# Run overnight training job
nohup python long_training_job.py &

# Log GPU stats every 60 seconds
while true; do
  nvidia-smi --query-gpu=timestamp,temperature.gpu,temperature.memory,power.draw,fan.speed \
    --format=csv >> gpu_thermal_log.csv
  sleep 60
done
```

**Analysis:**
```python
import pandas as pd
df = pd.read_csv('gpu_thermal_log.csv')
print(f"Max GPU Temp: {df['temperature.gpu [C]'].max()}")
print(f"Avg GPU Temp: {df['temperature.gpu [C]'].mean()}")
print(f"Max Memory Temp: {df['temperature.memory [C]'].max()}")
```

**Acceptable:** All temps <85°C for 24-hour soak

---

### Monitoring Tools

#### Real-Time Monitoring
```bash
# Option 1: nvtop (interactive)
sudo apt install nvtop
nvtop

# Option 2: nvidia-smi dmon (continuous)
nvidia-smi dmon -s pucvmet -d 5

# Option 3: Prometheus + Grafana
# Export metrics via nvidia_gpu_exporter
docker run -d --gpus all \
  -p 9835:9835 \
  mindprince/nvidia_gpu_prometheus_exporter:latest
```

#### Temperature Logging
```bash
# Log to file with timestamps
while true; do
  echo "$(date +%Y-%m-%d\ %H:%M:%S),$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader | tr '\n' ',')" \
    >> temps.log
  sleep 10
done
```

---

## Thermal Emergency Procedures

### Over-Temperature Shutdown
```bash
#!/bin/bash
# /usr/local/bin/thermal-monitor.sh

TEMP_THRESHOLD=85  # °C

while true; do
  MAX_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader | sort -nr | head -1)

  if [ "$MAX_TEMP" -gt "$TEMP_THRESHOLD" ]; then
    echo "CRITICAL: GPU temperature $MAX_TEMP°C exceeds threshold!"
    # Kill training jobs
    pkill -f python
    pkill -f pytorch

    # Notify
    wall "GPU OVERHEAT: $MAX_TEMP°C - Training stopped!"

    # Wait for cooldown
    sleep 60
  fi

  sleep 10
done
```

**Install as systemd service:**
```ini
# /etc/systemd/system/thermal-monitor.service
[Unit]
Description=GPU Thermal Monitor
After=nvidia-persistenced.service

[Service]
ExecStart=/usr/local/bin/thermal-monitor.sh
Restart=always

[Install]
WantedBy=multi-user.target
```

---

## Room Cooling Considerations

### HVAC Requirements

**Heat Dissipation:** 2.9-3.8kW = **9,900-13,000 BTU/hr**

**Recommended Room Cooling:**
- **Minimum:** 12,000 BTU/hr (1-ton) dedicated AC unit
- **Recommended:** 15,000 BTU/hr (1.25-ton) with overhead
- **Ideal:** 18,000 BTU/hr (1.5-ton) for comfortable ambient temp

**Room Size Calculations:**
```
Heat Density: 3,000W / 20m² = 150W/m²
Recommended: <100W/m² for comfortable environment
Minimum Room Size: 30m² (320 sq ft) with dedicated cooling
```

---

### Ambient Temperature Impact
| Ambient Temp | GPU Load Temp | Coolant Temp | Performance |
|--------------|---------------|--------------|-------------|
| 18°C (64°F)  | 60-65°C       | 30-35°C      | ✅ Optimal |
| 22°C (72°F)  | 65-70°C       | 35-40°C      | ✅ Good |
| 25°C (77°F)  | 70-75°C       | 40-45°C      | ⚠️ Acceptable |
| 28°C (82°F)  | 75-80°C       | 45-50°C      | ⚠️ Marginal |
| 30°C+ (86°F+)| 80-85°C+      | 50°C+        | ❌ Throttling risk |

**Recommendation:** Maintain room temperature at **22°C (72°F) or below**

---

## Cost Analysis

### Custom Liquid Cooling Build
```yaml
Water Cooling Components: $3,000-4,500
  - CPU Loop: $600-800
  - GPU Loop: $2,000-3,200
  - Fittings/Tubing: $400-500

Chassis: $500-700
  - Corsair Obsidian 1000D: $600

Case Fans (additional): $300-500
  - 8-10× Noctua NF-A12x25: $30 each

Labor (DIY or professional): $0-1,500
  - Professional loop installation: $1,000-1,500

Room Cooling (dedicated AC): $800-2,000
  - 15,000 BTU portable AC: $800-1,200
  - Mini-split system: $1,500-2,000

Total: $4,600-9,200
```

---

### Rackmount Solution
```yaml
5U Chassis: $1,500-2,500
Rackmount-grade PSU (2800W): $800-1,200
Rack (42U): $500-1,000 (if not already available)
Installation: $500-1,000
Total: $3,300-5,700
```

**Plus:** Datacenter space rental or dedicated server room (~$500-2,000/month)

---

## Risk Assessment

### 🔴 CRITICAL RISKS
- **Thermal runaway** - Insufficient cooling causes throttling and damage
- **Coolant leak** - Liquid cooling failure destroys $20k+ in hardware
- **Room temperature** - Inadequate HVAC leads to system-wide overheating

### 🟡 MEDIUM RISKS
- **Pump failure** - Single point of failure in custom loops (use redundancy)
- **Fan failure** - Gradual temperature increase (monitor RPMs)
- **Dust accumulation** - Reduced cooling efficiency over time

### 🟢 MANAGEABLE RISKS
- **Maintenance** - Coolant replacement every 12-24 months
- **Noise** - High-performance fans can be loud (40-60 dB)

---

## Recommendations for Epic 1A

### Primary Configuration (Desktop/Lab)
- **Cooling:** Dual-loop custom liquid cooling
- **Chassis:** Corsair Obsidian 1000D
- **Radiators:** 360mm (CPU) + 2× 480mm (GPUs)
- **Fans:** 11× Noctua NF-A12x25 PWM
- **Room Cooling:** 15,000 BTU dedicated AC unit
- **Cost:** ~$5,000-7,000 (cooling only)

---

### Alternative Configuration (Datacenter)
- **Cooling:** 5U rackmount with high-CFM fans
- **Chassis:** Custom 5U (e.g., Puget Systems)
- **Power:** 2800W redundant PSU (240V)
- **Environment:** Dedicated server room with HVAC
- **Cost:** ~$4,000-6,000 (chassis + cooling)

---

## Next Steps for Epic 1A

1. ✅ Budget $5,000-7,000 for custom liquid cooling
2. ✅ Procure Corsair Obsidian 1000D chassis
3. ✅ Source water cooling components (EK, Aquacomputer)
4. ⚠️ Plan room HVAC upgrade (15,000 BTU minimum)
5. ✅ Develop thermal monitoring scripts
6. ✅ Create thermal emergency shutdown procedures
7. ⚠️ Schedule professional loop installation (if not DIY)
8. ✅ Conduct 24-hour thermal soak test post-deployment

---

## References

- RTX 5090 Founders Edition review (GamersNexus)
- Dual RTX 5090 Threadripper build guides (Micro Center, FaceOfIT)
- Puget Systems: Dual RTX 5090 rackmount workstation
- Custom water cooling guides (EK, JayzTwoCents)
- NVIDIA thermal specifications (TechPowerUp)
