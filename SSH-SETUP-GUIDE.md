# SSH Setup Guide for the Cube

This guide walks a non-technical person through setting up SSH on the cube
and verifying it works — first from the home LAN, then from the internet.

---

## Overview / Game Plan

```
Step 1: Run the setup script ON the cube           (installs & configures SSH)
Step 2: Test SSH from ANOTHER device on the LAN     (phone/laptop on same wifi)
Step 3: Set up remote access from the internet       (Tailscale — easiest option)
Step 4: Test SSH from Costa Rica                     (the real test)
```

---

## STEP 0 — Prerequisites

You need:
- Physical access to the cube (monitor + keyboard, or existing terminal)
- The cube's local IP address (you said it's static — write it down, e.g. `192.168.1.50`)
- Another device on the same home network (laptop, phone, etc.) for testing

### Confirm the cube's IP address

On the cube, run:

```bash
ip addr show | grep "inet " | grep -v 127.0.0.1
```

You should see something like `inet 192.168.1.50/24`. The part before the `/` is
the IP address. Write it down — you'll need it throughout this guide.

---

## STEP 1 — Install & Configure SSH on the Cube

### Option A: Run the script (preferred)

If you can get the script onto the cube (USB drive, git clone, or just paste it):

```bash
# If you have git on the cube:
git clone https://github.com/jcarlin/vault-ai-os.git
cd vault-ai-os/scripts
chmod +x setup-ssh.sh
sudo ./setup-ssh.sh
```

### Option B: Copy-paste commands manually

If you can't get the script onto the cube, run these commands one at a time.
Copy each line, paste it, press Enter, wait for it to finish, then do the next one.

**For Ubuntu / Debian / Raspberry Pi OS:**

```bash
# 1. Update package list
sudo apt-get update

# 2. Install SSH server
sudo apt-get install -y openssh-server

# 3. Enable SSH to start on boot
sudo systemctl enable ssh

# 4. Start SSH now
sudo systemctl start ssh

# 5. Check it's running (look for "active (running)")
sudo systemctl status ssh

# 6. Open firewall if ufw is active
sudo ufw allow 22/tcp

# 7. Show your IP address
echo "Your IP address is:"
hostname -I
```

**For CentOS / RHEL / Fedora:**

```bash
# 1. Install SSH server
sudo dnf install -y openssh-server

# 2. Enable SSH to start on boot
sudo systemctl enable sshd

# 3. Start SSH now
sudo systemctl start sshd

# 4. Check it's running (look for "active (running)")
sudo systemctl status sshd

# 5. Open firewall
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload

# 6. Show your IP address
echo "Your IP address is:"
hostname -I
```

### Verify SSH is running

After either option, run this on the cube:

```bash
sudo systemctl status ssh 2>/dev/null || sudo systemctl status sshd
```

You should see **"active (running)"** in green. If you see "failed" or "inactive",
something went wrong — send me the full output.

---

## STEP 2 — Test from the Home LAN (BEFORE trying from Costa Rica)

This is the critical step. Use **another device on the same home wifi/network**
(a laptop, another computer, even a phone with a terminal app like Termux).

### Test 2a: Ping the cube

From the other device, run:

```bash
ping 192.168.1.50
```

(Replace `192.168.1.50` with the cube's actual IP.)

**Expected:** You see replies like `64 bytes from 192.168.1.50: time=1.2ms`

**If ping fails:**
- Are both devices on the same wifi / network?
- Is the IP correct? Double-check with `ip addr show` on the cube
- Some devices block ping — proceed to the next test anyway

### Test 2b: Check if port 22 is open

```bash
# Using nc (netcat) — most Linux/Mac systems have this
nc -zv 192.168.1.50 22

# OR using telnet
telnet 192.168.1.50 22

# OR on Mac/Linux with bash built-in
echo > /dev/tcp/192.168.1.50/22 && echo "Port 22 is open" || echo "Port 22 is closed"
```

**Expected for nc:** `Connection to 192.168.1.50 22 port [tcp/ssh] succeeded!`
**Expected for telnet:** You'll see something like `SSH-2.0-OpenSSH_8.9`. Type `quit` to exit.

**If port 22 is closed:**
- SSH server may not be running: go back to Step 1
- Firewall may be blocking it: run `sudo ufw status` on the cube (or `sudo firewall-cmd --list-all`)

### Test 2c: Actually SSH in

From the other device on the LAN:

```bash
ssh <username>@192.168.1.50
```

Replace `<username>` with the user account on the cube. If you don't know it,
run `whoami` on the cube to see the current username.

It will ask:
1. "Are you sure you want to continue connecting?" → Type `yes`
2. Password → Type the cube user's password

**If you get a command prompt on the cube — SSH is working on the LAN!**

### Test 2d: From a phone (if no second computer available)

Install **Termux** (Android) or **iSH** (iOS), then run the same ping/ssh commands.
Or use the **JuiceSSH** app (Android) which has a nice GUI.

---

## STEP 3 — Set Up Remote Access from the Internet

Since you're in Costa Rica and the cube is on a home network, you need a way
to punch through the home router's NAT. Two options:

### Option A: Tailscale (STRONGLY RECOMMENDED — easiest by far)

Tailscale creates a secure peer-to-peer VPN. No port forwarding needed.
No router configuration needed. Works even if the ISP uses CGNAT.

**On the cube:**

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Start and authenticate
sudo tailscale up
```

This will print a URL. Open that URL in a browser, log in (create a free account
if needed), and authorize the device.

**On YOUR machine in Costa Rica:**

Install Tailscale the same way (or download from https://tailscale.com/download),
log into the **same Tailscale account**.

Then:

```bash
# Find the cube's Tailscale IP
tailscale status

# SSH to the cube using its Tailscale IP (usually 100.x.x.x)
ssh <username>@100.x.x.x
```

That's it. Tailscale handles everything — encryption, NAT traversal, DNS.

### Option B: Router Port Forwarding (more complex, requires router access)

If Tailscale isn't an option:

1. Log into the home router (usually `192.168.1.1` in a browser)
2. Find "Port Forwarding" or "Virtual Server" settings
3. Create a rule:
   - External port: `22` (or a custom port like `2222` for security)
   - Internal IP: the cube's static IP (e.g., `192.168.1.50`)
   - Internal port: `22`
   - Protocol: TCP
4. Find the home's public IP: go to https://whatismyip.com on any device on the home network
5. From Costa Rica: `ssh <username>@<public-ip> -p 22`

**Downsides of port forwarding:**
- Need router admin access
- Public IP may change (unless you set up dynamic DNS)
- Exposes port 22 to the internet (use key-based auth and fail2ban)
- Won't work if the ISP uses CGNAT (carrier-grade NAT)

---

## STEP 4 — Test from Costa Rica

### Using the diagnostic script

```bash
# If you cloned this repo:
chmod +x scripts/test-ssh-connectivity.sh

# Test with Tailscale IP:
./scripts/test-ssh-connectivity.sh 100.x.x.x

# Or with public IP + port forwarding:
./scripts/test-ssh-connectivity.sh <public-ip> 22
```

### Manual test

```bash
# 1. Ping (may not work through Tailscale, that's OK)
ping 100.x.x.x

# 2. Test port
nc -zv 100.x.x.x 22

# 3. SSH in
ssh <username>@100.x.x.x
```

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `Connection refused` | SSH not running | Run `sudo systemctl start ssh` on cube |
| `Connection timed out` | Firewall or routing issue | Check `ufw status`, check port forwarding |
| `No route to host` | Wrong IP or network down | Verify IP with `ip addr show` on cube |
| `Permission denied` | Wrong username or password | Check with `whoami` on cube, reset password with `sudo passwd <user>` |
| `Host key verification failed` | SSH key changed | Run `ssh-keygen -R <ip>` on your machine |
| Tailscale shows "offline" | Tailscale service stopped | Run `sudo tailscale up` on cube |

### Useful debug commands (run on the cube)

```bash
# Is SSH running?
sudo systemctl status ssh 2>/dev/null || sudo systemctl status sshd

# What's listening on port 22?
sudo ss -tlnp | grep :22

# Firewall rules?
sudo ufw status verbose 2>/dev/null || sudo firewall-cmd --list-all 2>/dev/null || sudo iptables -L -n

# Watch SSH login attempts live (useful while testing)
sudo journalctl -fu ssh 2>/dev/null || sudo journalctl -fu sshd

# What's the cube's IP?
ip addr show | grep "inet " | grep -v 127.0.0.1

# What's the Tailscale IP?
tailscale ip -4
```

---

## Quick Reference Card (Print this for your colleague)

```
╔══════════════════════════════════════════════════════════════╗
║                    SSH QUICK REFERENCE                       ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  1. INSTALL SSH:                                             ║
║     sudo apt-get update && sudo apt-get install -y openssh-server ║
║     sudo systemctl enable ssh && sudo systemctl start ssh    ║
║                                                              ║
║  2. CHECK IT'S RUNNING:                                      ║
║     sudo systemctl status ssh                                ║
║                                                              ║
║  3. FIND YOUR IP:                                            ║
║     hostname -I                                              ║
║                                                              ║
║  4. TEST FROM ANOTHER LAN DEVICE:                            ║
║     ping <CUBE-IP>                                           ║
║     ssh <username>@<CUBE-IP>                                 ║
║                                                              ║
║  5. INSTALL TAILSCALE:                                       ║
║     curl -fsSL https://tailscale.com/install.sh | sh         ║
║     sudo tailscale up                                        ║
║                                                              ║
║  6. FIND TAILSCALE IP:                                       ║
║     tailscale ip -4                                          ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```
