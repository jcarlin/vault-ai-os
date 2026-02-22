# GCP App Deployment Validation Report

**Date:** 2026-02-22
**Instance:** gpu-test-01 (g2-standard-8, NVIDIA L4, us-central1-a)
**Playbook:** `app.yml` (vault-backend, vault-frontend, caddy roles)
**Tester:** Julian + Claude Code

---

## Summary

First-ever run of `app.yml` on real hardware (GCP). Found and fixed **7 bugs** across 5 commits. All 3 services deploy successfully, all validation endpoints pass, and the playbook is idempotent (4 cosmetic changes on re-run).

---

## Test Results

### app.yml Final Run

```
PLAY RECAP *********************************************************************
localhost : ok=53  changed=4  unreachable=0  failed=0  skipped=3  rescued=0  ignored=0
```

### Service Status

| Service | Status | Port | Notes |
|---------|--------|------|-------|
| vault-backend | active | 8000 | FastAPI, degraded (no vLLM — expected) |
| vault-frontend | active | 3001 | Next.js 16.1.6, redirects to /auth |
| caddy | active | 443/80 | TLSv1.3, self-signed internal CA |

### Endpoint Validation

| Endpoint | Method | Expected | Actual | Status |
|----------|--------|----------|--------|--------|
| `http://localhost:8000/vault/health` | GET | 200 | 200 (degraded) | PASS |
| `http://localhost:8000/vault/setup/status` | GET | 200 | 200 (pending) | PASS |
| `http://localhost:8000/metrics` | GET | 200 | 200 (Prometheus text) | PASS |
| `http://localhost:8000/v1/models` | GET+Auth | 200 | 200 (model list) | PASS |
| `http://localhost:8000/v1/models` | GET (no auth) | 401 | 401 | PASS |
| `http://localhost:3001` | GET | 200/307 | 307 (→ /auth) | PASS |
| `https://localhost/vault/health` | GET | 200 | 200 (via Caddy) | PASS |
| `https://localhost/` | GET | 200/307 | 307 (via Caddy) | PASS |
| `https://localhost/v1/models` | GET+Auth | 200 | 200 (via Caddy) | PASS |
| `http://localhost/` | GET | 301/308 | 308 (→ HTTPS) | PASS |

### API Key Creation

```bash
sudo -u vaultadmin bash -c 'export VAULT_DB_URL="sqlite+aiosqlite:////opt/vault/data/vault.db" && \
  /opt/vault/backend-venv/bin/python -m app.cli create-key --label test --scope admin'
# Returns: vault_sk_fb7... (working key, verified with auth endpoints)
```

### Idempotency

Steady-state re-run: `ok=53, changed=4, failed=0`. The 4 changed tasks are cosmetic rsync permission diffs on root directories (`.d...p..... ./`) — source dir permissions differ from dest. No actual file content changes.

---

## Bugs Found and Fixed

### Bug #1: uv installer uses wrong env var for install path
**File:** `ansible/roles/uv/tasks/main.yml`
**Symptom:** `uv` installed to `/root/.local/bin/` instead of `/usr/local/bin/`
**Root cause:** `CARGO_HOME=/usr/local` does not control the uv installer path
**Fix:** Use `UV_UNMANAGED_INSTALL=/usr/local/bin` instead
**Commit:** `8bf033a`

### Bug #2: uv sync fails — no lockfile and VIRTUAL_ENV ignored
**File:** `ansible/roles/vault-backend/tasks/deploy_app.yml`
**Symptom:** `uv sync --frozen` fails: no `uv.lock`, and `VIRTUAL_ENV` warning about `.venv` mismatch
**Root cause:** Backend repo has no `uv.lock`; uv ignores `VIRTUAL_ENV` when it doesn't match project default
**Fix:** Add `uv lock` step (with `creates:` guard) before sync; add `--active` flag to `uv sync`
**Commit:** `716cb5e`

### Bug #3: rsync deletes generated uv.lock on every run
**File:** `ansible/roles/vault-backend/tasks/deploy_app.yml`
**Symptom:** `rsync --delete` removes `uv.lock` (not in source), triggering re-lock + re-install
**Fix:** Add `--exclude=uv.lock` to rsync opts
**Commit:** `06d16a5`

### Bug #4: Secret key regenerated on every run
**File:** `ansible/roles/vault-backend/tasks/configure.yml`
**Symptom:** `openssl rand -hex 32` generates a new key each run, causing env file change + service restart
**Fix:** Read existing key from env file on subsequent runs; only generate on first deploy
**Commit:** `06d16a5`

### Bug #5: rsync runs as root, changing file ownership
**Files:** `ansible/roles/vault-backend/tasks/deploy_app.yml`, `ansible/roles/vault-frontend/tasks/main.yml`
**Symptom:** Files synced as root, then chown loop reports changes
**Fix:** Add `--chown=vaultadmin:vaultadmin` to rsync opts
**Commit:** `06d16a5`

### Bug #6: SQLite DB URL uses relative path (3 slashes)
**File:** `ansible/roles/vault-backend/defaults/main.yml`
**Symptom:** Backend crash-loops with `sqlite3.OperationalError: unable to open database file`
**Root cause:** `sqlite+aiosqlite:///opt/vault/data/vault.db` = relative path; needs 4 slashes for absolute
**Fix:** Change to `sqlite+aiosqlite:////opt/vault/data/vault.db`
**Commit:** `cecd109`

### Bug #7: Caddy TLS fails with port-only config
**File:** `ansible/roles/caddy/templates/Caddyfile.j2`
**Symptom:** TLS handshake fails — `tlsv1 alert internal error`
**Root cause:** `:443` (port-only) gives Caddy no hostname to generate a leaf certificate for
**Fix:** Use `vault-cube.local, localhost` as the site address instead of `:443`
**Commit:** `7c9e30b`

### Additional improvements (non-bugs)
- Frontend: exclude `next-env.d.ts` from rsync (build-generated)
- Frontend: skip `npm ci` when `node_modules` already exists
- Frontend: skip `npm run build` when `.next/BUILD_ID` already exists
- **Commit:** `2b1b619`

---

## Known Issues (Not Bugs)

1. **GPU driver DKMS fails on GCP kernel 6.17** — nvidia-dkms-550 can't build against kernel 6.17.0-1008-gcp. Not an app.yml issue; doesn't affect the Cube (which runs kernel 6.8). Workaround: remove broken nvidia packages.

2. **4 cosmetic rsync "changed" on idempotent re-run** — rsync reports permission diff (`.d...p.....`) on source root directories because git clone uses different permissions than `/opt/vault/`. No actual file changes occur.

3. **Frontend returns 307 instead of 200** — Next.js auth middleware redirects unauthenticated requests to `/auth`. Expected behavior for a production deployment.

---

## Deployment Artifacts

| Path | Description |
|------|-------------|
| `/opt/vault/backend/` | FastAPI application code |
| `/opt/vault/backend-venv/` | Python 3.12 venv (separate from PyTorch) |
| `/opt/vault/frontend/` | Next.js production build |
| `/opt/vault/data/vault.db` | SQLite database |
| `/opt/vault/config/vault-backend.env` | Backend environment (secret key, DB URL, etc.) |
| `/opt/vault/config/vault-frontend.env` | Frontend environment |
| `/etc/systemd/system/vault-backend.service` | Backend systemd unit |
| `/etc/systemd/system/vault-frontend.service` | Frontend systemd unit |
| `/etc/caddy/Caddyfile` | Caddy reverse proxy config |

---

## Pre-flight Versions

| Component | Version |
|-----------|---------|
| Python | 3.12.3 |
| Node.js | v20.20.0 |
| uv | 0.10.4 |
| Caddy | v2.11.1 |
| Next.js | 16.1.6 |
| FastAPI | 0.115.x |
| Ubuntu | 24.04.4 LTS |
| Kernel | 6.17.0-1008-gcp |

---

## GCP Instance

- **Created:** 2026-02-22 07:43 UTC
- **Deleted:** 2026-02-22 ~08:30 UTC
- **Runtime:** ~47 minutes
- **Estimated cost:** ~$0.60 (g2-standard-8 @ $0.77/hr)
