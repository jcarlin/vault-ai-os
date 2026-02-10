# Airgap Architecture & Strategy — Vault AI Systems

## Context

Vault AI ships as a pre-loaded appliance to enterprises who need private LLM inference/fine-tuning. The core value prop is "no data leaves the building." But the current infrastructure has significant airgap gaps: packages install from the internet, Docker pulls from Docker Hub, DNS/NTP point to public servers, the security role isn't wired into the production playbook, and there's no update delivery mechanism. This plan defines the architecture, prioritized implementation, and cost-benefit for a configurable airgap posture — from "LAN-only, no internet" to "full SCIF-grade isolation."

---

## Current State Assessment

### What exists (working)
- Packer golden image builder (VirtualBox .ova working)
- Ansible roles: common, users, packages, networking, docker, python
- Security role (SSH hardening, UFW, fail2ban, sysctl) — **exists but NOT enabled** in `site.yml`
- Offline desktop installer script (`scripts/install-desktop-offline.sh`)
- PXE boot config for deployment
- Backend PRD with basic airgap section (pip wheels + tarball)

### Critical gaps for airgap
| Gap | Severity | Current behavior |
|-----|----------|-----------------|
| No offline apt repo | **Critical** | All packages fetched from internet during build |
| No offline Docker registry | **Critical** | Docker images pulled from Docker Hub at runtime |
| No offline pip/wheel cache | **High** | Python packages need internet |
| Public DNS defaults (8.8.8.8) | **High** | Fails silently in airgap |
| Public NTP pools | **Medium** | Clock drift without internet NTP |
| Security role not enabled | **High** | Firewall/hardening not applied in prod builds |
| No update delivery mechanism | **Critical** | Customers stranded after deployment |
| No model distribution pipeline | **Critical** | 10-140GB model files need offline delivery |
| No internal TLS/cert management | **High** | Caddy auto-TLS depends on Let's Encrypt (internet) |
| No integrity verification | **Medium** | No checksums/signatures on update bundles |
| No USB device policy | **Medium** | No peripheral control for SCIF deployments |
| No audit logging | **Medium** | No centralized log for compliance |

---

## Airgap Isolation Levels (Configurable)

The system should support three deployment modes, selected at image flash time via an Ansible variable (`vault_airgap_level`):

### Level 1: LAN-Connected (Default)
- Server on customer LAN, users access via browser
- No internet gateway — no outbound traffic
- Local DNS for hostname resolution on LAN
- Local NTP from customer's time server or GPS clock
- **Who**: Most enterprise customers

### Level 2: Standalone (No LAN)
- Direct-connect only (single admin workstation via Ethernet)
- No DHCP — static IPs
- mDNS/Avahi for zero-conf discovery
- Free-running clock with battery-backed RTC
- **Who**: Field deployments, sensitive facilities

### Level 3: SCIF-Grade (Full Isolation)
- All Level 2 restrictions plus:
- USB ports disabled except during authorized update windows
- WiFi/Bluetooth physically disabled (kernel module blacklist)
- No wireless network interfaces loaded
- Tamper-evident boot with measured boot chain
- **Who**: Government/defense, ITAR-regulated

---

## Architecture: Six Pillars

### Pillar 1: Offline Package Management

**Problem**: Every apt, pip, and Docker pull fails in an airgap.

**Solution**: Bake everything into the golden image at build time.

| Component | Strategy | Build-time cost | Runtime cost |
|-----------|----------|----------------|-------------|
| **APT packages** | Pre-download all .debs during Packer build; bundle into image. Disable apt repos on target. | +5-10 min build, +2-4GB image | Zero (no apt calls needed) |
| **Python wheels** | `pip download` all requirements into `/opt/vault/wheels/`; install from local during setup | +2-3 min build, +1-2GB image | Zero |
| **Docker images** | `docker save` all required images into tarball; `docker load` on target | +5-10 min build, +5-15GB image | Zero |
| **NVIDIA/CUDA** | Pre-download .run installers and .deb packages; bundle into image | +3-5 min build, +3-5GB image | Zero |

**Implementation**:
- New Ansible role: `offline-packages` — runs during Packer build to download and cache everything
- Modify `packages`, `docker`, `python` roles to check for local cache before reaching out
- Ansible variable: `vault_offline_mode: true` to switch all roles to local-only
- Estimated total golden image size: **30-50GB** (base OS + all packages + Docker images, excluding models)

**Cost-benefit**:
- **Cost**: ~2-3 days dev. Larger image size (50GB vs 8GB). Slower builds.
- **Benefit**: True zero-internet deployment. Single artifact to ship. Eliminates "missing dep" class of field failures entirely.

---

### Pillar 2: Model Distribution Pipeline

**Problem**: LLM weights are 5-140GB per model. Can't bake all of them into the golden image.

**Solution**: Tiered model delivery.

| Tier | Models | Delivery | Size |
|------|--------|----------|------|
| **Pre-loaded** | 1-2 flagship models (e.g., Llama 3.1 8B-Instruct, Mistral 7B) | Baked into golden image | 10-20GB |
| **Catalog** | Customer-selected models at purchase | Shipped on NVMe drive alongside server | Up to 500GB |
| **Updates** | New models, LoRA adapters from fine-tuning | USB update bundles (see Pillar 4) | Varies |

**Implementation**:
- Model storage: `/data/models/` on dedicated NVMe partition
- Model manifest: JSON file listing available models, checksums, sizes
- Import tool: `vault-model-import` CLI that validates checksums and registers models in the DB
- Pre-load script in Packer build downloads selected models during image creation

**Cost-benefit**:
- **Cost**: ~2 days dev (import tool + manifest format). NVMe storage cost ($200-400 for 2-4TB drives shipped with unit).
- **Benefit**: Customers get models day-1 without internet. Integrity-verified import prevents corrupted weights.

---

### Pillar 3: Network & Service Isolation

**Problem**: Current defaults assume internet (DNS 8.8.8.8, NTP pool.ntp.org, Docker Hub).

**Solution**: Airgap-aware networking defaults based on `vault_airgap_level`.

| Service | Level 1 (LAN) | Level 2 (Standalone) | Level 3 (SCIF) |
|---------|---------------|---------------------|----------------|
| **DNS** | Customer's LAN DNS | Local `/etc/hosts` only | `/etc/hosts` only, systemd-resolved disabled |
| **NTP** | Customer's NTP server | Free-running RTC | Free-running RTC, chrony disabled |
| **DHCP** | Customer's DHCP | Static IP (192.168.1.100/24) | Static IP, single-host subnet |
| **Firewall (UFW)** | Allow 22, 80, 443 from LAN | Allow 22, 443 from single IP | Allow 443 from single IP only |
| **Outbound** | Block all outbound | Block all | Block all, DROP policy |
| **IPv6** | Disabled | Disabled | Disabled |
| **mDNS/Avahi** | Enabled (LAN discovery) | Optional | Disabled |
| **Bluetooth** | Disabled | Disabled | Kernel module blacklisted |
| **WiFi** | Disabled | Disabled | Kernel module blacklisted + rfkill |

**Implementation**:
- Modify `networking/defaults/main.yml`: Replace public DNS/NTP with conditional defaults
- Modify `security/defaults/main.yml`: Tighten UFW rules based on level
- New template: `etc/hosts.j2` with static entries for vault services
- New Ansible tasks in security role: wireless/bluetooth disable based on level
- Enable security role in `site.yml` (currently commented out)

**Cost-benefit**:
- **Cost**: ~1-2 days dev. Ansible variable refactoring.
- **Benefit**: Eliminates network-dependent failures on boot. Defense-in-depth even if customer LAN is compromised.

---

### Pillar 4: Update Delivery System

**Problem**: No mechanism for customers to receive OS patches, app updates, or new models after deployment.

**Recommended approach**: **Signed Update Bundles via USB**

#### Update Bundle Format
```
vault-update-2026-02-v1.2.3.vub    (Vault Update Bundle)
├── manifest.json                    # Version, checksums, dependencies
├── signature.sig                    # Ed25519 signature (your signing key)
├── os-patches/                      # .deb security patches
│   └── *.deb
├── app/                             # Backend/frontend updates
│   ├── wheels/                      # Python wheel updates
│   ├── docker-images/               # Saved Docker images
│   └── migrations/                  # DB migration scripts
├── models/ (optional)               # New/updated model weights
│   └── *.safetensors
└── scripts/
    ├── pre-update.sh                # Pre-flight checks
    ├── apply-update.sh              # Main update logic
    └── rollback.sh                  # Rollback on failure
```

#### Update Workflow
1. **You** (build machine with internet): Run `vault-update-builder` script that pulls latest security patches, builds new app version, signs the bundle
2. **Ship**: USB drive or secure file transfer to customer's air-transfer workstation
3. **Customer**: Inserts USB into Vault server, runs `vault-update apply /mnt/usb/vault-update-*.vub`
4. **System**: Verifies Ed25519 signature, checks version compatibility, applies updates atomically, rolls back on failure

#### Update Cadence
| Update type | Frequency | Typical size | Urgency |
|-------------|-----------|-------------|---------|
| Security patches (OS) | Monthly | 50-200MB | High |
| App updates | Quarterly | 100-500MB | Medium |
| Model updates | As-needed | 5-140GB | Low |
| Emergency patches | As-needed | 10-50MB | Critical |

**Cost-benefit**:
- **Cost**: ~5-7 days dev (bundle builder, signature verification, apply/rollback logic, CLI tool). $5-15 per USB drive per customer per update cycle.
- **Benefit**: Customers stay patched without internet. Signature verification prevents tampered updates. Atomic apply + rollback prevents bricked servers. This is the #1 feature that makes airgap viable long-term.

**Alternative considered**: Secure update portal (customer downloads on internet-connected machine, transfers via approved media). This adds complexity and another machine to the customer's process — better as a Phase 2 option on top of USB delivery.

---

### Pillar 5: TLS & Identity Without Internet

**Problem**: Caddy's auto-TLS uses Let's Encrypt (requires internet). JWT auth needs a trusted certificate chain.

**Solution**: Self-signed CA baked into the golden image.

| Component | Approach |
|-----------|----------|
| **Root CA** | Generated at image build time. Unique per customer (keyed to serial number). |
| **Server cert** | Signed by root CA. CN = `vault.local` + customer hostname. |
| **Caddy config** | Point to local certs instead of ACME. |
| **Browser trust** | First-login wizard prompts user to download and install root CA cert. |
| **JWT signing** | Use separate key pair, generated on first boot. Stored in `/etc/vault/keys/`. |
| **Cert rotation** | Update bundles can include renewed certs (5-year validity). |

**Cost-benefit**:
- **Cost**: ~2 days dev. Slight UX friction (browser trust warning until CA installed).
- **Benefit**: Full TLS encryption on LAN without internet dependency. Per-customer CA means one compromised server doesn't affect others.

---

### Pillar 6: Boot Integrity & Hardware Security

**Problem**: Physical access to the server = potential tamper vector.

**Solution**: Layered based on airgap level.

| Control | Level 1 | Level 2 | Level 3 | Cost |
|---------|---------|---------|---------|------|
| UEFI Secure Boot | Enabled | Enabled | Enabled | Free (firmware) |
| BIOS password | Set | Set | Set | Free |
| Disk encryption (LUKS) | Optional | Recommended | Required | Free (CPU overhead ~2-5%) |
| TPM-backed key storage | Optional | Optional | Required | $0 (TPM on Threadripper PRO) |
| USB port disable | No | Boot-only | Always (except update window) | Free (usbguard) |
| Chassis intrusion detection | No | No | Yes | ~$50 (sensor + alerting) |
| Measured boot (IMA/EVM) | No | No | Recommended | Free (kernel config) |

**Cost-benefit**:
- **Cost**: ~3-4 days dev for LUKS + usbguard + Secure Boot Ansible roles. Zero hardware cost (TPM built into Threadripper PRO board).
- **Benefit**: Protects against physical tamper, evil-maid attacks, and unauthorized USB devices. Required for government/defense sales.

---

## Priority Matrix & Roadmap

### Phase 1: Ship-Ready Airgap (Weeks 1-3) — **Do First**
| Item | Pillar | Effort | Impact |
|------|--------|--------|--------|
| Enable security role in site.yml | 3 | 0.5 day | High — firewall/SSH actually applied |
| Offline apt package caching | 1 | 2 days | Critical — server boots without internet |
| Offline Docker image bundling | 1 | 1 day | Critical — services start without Docker Hub |
| Offline pip wheel cache | 1 | 1 day | Critical — backend installs without PyPI |
| Network defaults for airgap levels | 3 | 1.5 days | High — no phone-home on boot |
| Pre-loaded model bundling | 2 | 1.5 days | High — inference works day-1 |
| Self-signed CA + local TLS | 5 | 2 days | High — HTTPS works without internet |

**Total: ~10 days. After this, the server boots and works fully offline.**

### Phase 2: Update & Lifecycle (Weeks 4-6) — **Do Second**
| Item | Pillar | Effort | Impact |
|------|--------|--------|--------|
| Update bundle format + builder | 4 | 3 days | Critical — customers can receive patches |
| Signature verification (Ed25519) | 4 | 1.5 days | High — tamper-proof updates |
| Apply + rollback CLI tool | 4 | 2.5 days | High — safe update application |
| Model import tool with checksums | 2 | 1.5 days | Medium — validated model delivery |

**Total: ~9 days. After this, customers can receive and apply updates safely.**

### Phase 3: Hardened Posture (Weeks 7-9) — **Do for Government/Defense Customers**
| Item | Pillar | Effort | Impact |
|------|--------|--------|--------|
| LUKS full-disk encryption | 6 | 2 days | High for SCIF |
| USBGuard policy | 6 | 1.5 days | High for SCIF |
| Wireless/BT kernel blacklist | 3 | 0.5 day | Medium |
| UEFI Secure Boot config | 6 | 1.5 days | Medium |
| Audit logging (auditd rules) | 3 | 1.5 days | Medium |
| IMA/EVM measured boot | 6 | 2 days | Low (nice-to-have for compliance) |

**Total: ~9 days. After this, the server meets SCIF/STIG-adjacent requirements.**

---

## Cost Summary

### Development cost
| Phase | Effort | When |
|-------|--------|------|
| Phase 1 (Ship-Ready) | ~10 days | Before first customer ship |
| Phase 2 (Updates) | ~9 days | Before second update cycle |
| Phase 3 (Hardened) | ~9 days | Before government/defense sales |
| **Total** | **~28 days** | Spread across 2-3 months |

### Per-unit cost impact
| Item | Cost per unit | Notes |
|------|--------------|-------|
| Larger NVMe for image + models | +$0 (8TB already spec'd) | Current spec handles it |
| USB drives for updates | $5-15/update cycle | Bulk USB 3.0 drives |
| TPM (for SCIF) | $0 | Built into Threadripper PRO motherboard |
| LUKS performance overhead | ~2-5% CPU | Negligible with AES-NI |

### Revenue impact
| Customer segment | Airgap level needed | Price sensitivity | Market size |
|-----------------|--------------------|--------------------|-------------|
| Enterprise (finance, legal) | Level 1-2 | Medium | Large |
| Government/defense | Level 2-3 | Low (compliance-driven) | Medium, high-margin |
| Healthcare (HIPAA) | Level 1-2 | Medium | Large |
| Critical infrastructure | Level 2-3 | Low | Small, high-margin |

---

## Key Files to Modify (When Implementing)

| File | Change |
|------|--------|
| `ansible/playbooks/site.yml` | Enable security role, add offline-packages role |
| `ansible/group_vars/all.yml` | Add `vault_airgap_level`, `vault_offline_mode` vars |
| `ansible/roles/security/defaults/main.yml` | Add level-conditional firewall rules |
| `ansible/roles/networking/defaults/main.yml` | Replace public DNS/NTP with local defaults |
| `ansible/roles/docker/defaults/main.yml` | Add offline registry config |
| `ansible/roles/docker/tasks/main.yml` | Add `docker load` from local cache path |
| New: `ansible/roles/offline-packages/` | Entire new role for package caching |
| New: `scripts/vault-update-builder.sh` | Build signed update bundles |
| New: `scripts/vault-update-apply.sh` | Apply update bundles on target |
| New: `scripts/vault-model-import.sh` | Import and verify model weights |

---

## Open Questions

These don't block the strategy doc but will need answers before implementation:

1. **Customer support model**: Will you provide remote support (VPN tunnel during maintenance windows), or is all support via documentation + phone?
2. **Compliance targets**: Any specific frameworks needed? (NIST 800-171, FedRAMP, STIG, HIPAA?) This affects Phase 3 scope.
3. **Multi-unit fleet management**: If a customer buys 3+ servers, do they need centralized management across units?
4. **Licensing/activation**: Any need for license key verification that works offline?

---

## Verification (When Implementing)

For each phase, validate with:

### Phase 1
- Build golden image with `vault_offline_mode: true`
- Boot in VirtualBox with **no NAT/bridged network adapter** (host-only)
- Verify: all services start, Docker containers load, model inference works
- Verify: UFW rules applied (`sudo ufw status verbose`)
- Verify: no DNS/NTP failures in `journalctl`

### Phase 2
- Build update bundle on internet-connected machine
- Transfer to airgapped VM via shared folder (simulating USB)
- Run `vault-update apply` — verify signature check, apply, and service restart
- Test rollback by intentionally corrupting an update

### Phase 3
- Boot with LUKS — verify unlock prompt or TPM auto-unlock
- Insert unauthorized USB — verify USBGuard blocks it
- Check `auditd` logs for security events
- Verify Secure Boot chain with `mokutil --sb-state`
