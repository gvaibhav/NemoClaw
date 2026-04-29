# NemoClaw Customization System

NemoClaw now supports comprehensive customization through environment variables and configuration files. This allows you to install from forked repositories, use custom image registries, and tune timeouts for your environment.

## What's New

This customization system adds:

1. **`.env` Configuration File** — Override any setting without modifying code
2. **Repository Customization** — Install from your own fork
3. **Image Registry Override** — Use corporate artifactory or private registries
4. **Timeout Tuning** — Adjust for Docker Desktop, slow networks, or ARM64
5. **Auto-Loading** — Configuration automatically loaded by installation scripts

## Quick Start

### 1. Create Configuration

```bash
# Copy the template
cp .env.example .env

# Edit with your settings
nano .env
```

### 2. Common Use Cases

**Docker Desktop (Mac/Windows):**
```bash
NEMOCLAW_GATEWAY_START_TIMEOUT=1200
NEMOCLAW_HEALTH_POLL_INTERVAL=15
NEMOCLAW_HEALTH_POLL_COUNT=60
NEMOCLAW_PULL_TIMEOUT_MS=1800000
```

**Forked Repository:**
```bash
NEMOCLAW_REPO_URL=https://github.com/YOUR_USERNAME/NemoClaw.git
NEMOCLAW_INSTALL_TAG=your-branch-name
```

**Custom Image Registry:**
```bash
NEMOCLAW_SANDBOX_IMAGE_REGISTRY=artifactory.company.com/nvidia/sandboxes
# or for full image override:
NEMOCLAW_SANDBOX_IMAGE=your-registry.com/openclaw:tag
```

### 3. Install

```bash
./install.sh
# or
curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash
```

Settings are automatically loaded from `.env` if present.

## Files Created

| File | Purpose |
|------|---------|
| `.env.example` | Template with all available settings and documentation |
| `.env` | Your customized settings (create from template, never commit) |
| `scripts/load-env.sh` | Auto-loads `.env` configuration |
| `scripts/apply-image-overrides.sh` | Applies image registry changes to blueprint |
| `scripts/pre-onboard-hook.sh` | Pre-onboarding hook that applies overrides |
| `docs/customization-guide.md` | Complete customization reference |
| `CUSTOMIZATION_QUICKSTART.md` | Quick reference guide |

## Configuration Locations

1. **Project `.env`** — `<repo>/.env` (highest priority)
2. **Global `.env`** — `~/.nemoclaw/.env` (optional, lower priority)
3. **Environment variables** — Direct export (overrides files)
4. **Built-in defaults** — Fallback when nothing set

## Key Settings

### Timeouts (seconds)

```bash
NEMOCLAW_GATEWAY_START_TIMEOUT=600        # Gateway startup wait
NEMOCLAW_LOCAL_INFERENCE_TIMEOUT=180      # Local inference timeout
NEMOCLAW_HEALTH_POLL_INTERVAL=5           # Health check interval
NEMOCLAW_HEALTH_POLL_COUNT=12             # Health check attempts
```

### Docker Operations (milliseconds)

```bash
NEMOCLAW_PULL_TIMEOUT_MS=600000           # Image pull (10 min)
NEMOCLAW_BUILD_TIMEOUT_MS=300000          # Image build (5 min)
NEMOCLAW_INSPECT_TIMEOUT_MS=30000         # Image inspect (30 sec)
```

### Repository & Images

```bash
NEMOCLAW_REPO_URL=https://github.com/NVIDIA/NemoClaw.git
NEMOCLAW_INSTALL_TAG=latest
NEMOCLAW_SANDBOX_IMAGE_REGISTRY=ghcr.io/nvidia/openshell-community/sandboxes
NEMOCLAW_CLUSTER_IMAGE_REGISTRY=ghcr.io/nvidia/openshell
NEMOCLAW_SANDBOX_IMAGE=  # Full sandbox image override
```

## How It Works

### Installation Flow

1. **Load Configuration:**
   - `install.sh` sources `scripts/load-env.sh`
   - Loads `~/.nemoclaw/.env` (if exists)
   - Loads project `.env` (if exists)

2. **Apply Image Overrides:**
   - `pre-onboard-hook.sh` calls `apply-image-overrides.sh`
   - Updates `nemoclaw-blueprint/blueprint.yaml`
   - Creates backup at `.yaml.backup`

3. **Clone Repository:**
   - Uses `NEMOCLAW_REPO_URL` if set
   - Defaults to official NVIDIA repo

4. **Onboard with Timeouts:**
   - TypeScript code reads `NEMOCLAW_*` env vars
   - Uses configured timeouts and poll intervals

### Code Changes

**Modified Files:**
- `scripts/install.sh` — Sources load-env.sh, uses NEMOCLAW_REPO_URL
- `src/lib/cluster-image-patch.ts` — Respects timeout env vars
- `src/lib/onboard.ts` — Already reads env vars (no changes needed)

**New Scripts:**
- `scripts/load-env.sh` — Safely loads .env files
- `scripts/apply-image-overrides.sh` — Updates blueprint.yaml
- `scripts/pre-onboard-hook.sh` — Onboarding pre-hook

## Examples

### Docker Desktop on macOS

```bash
# .env
NEMOCLAW_GATEWAY_START_TIMEOUT=1200
NEMOCLAW_HEALTH_POLL_INTERVAL=15
NEMOCLAW_HEALTH_POLL_COUNT=80
NEMOCLAW_PULL_TIMEOUT_MS=1800000
```

**Rationale:** Docker Desktop's virtualization layer adds overhead. k3s networking takes longer to initialize.

**Total wait:** 80 × 15s = 1200s (20 minutes)

### Corporate Environment

```bash
# .env
NEMOCLAW_SANDBOX_IMAGE_REGISTRY=artifactory.company.com/nvidia-images
NEMOCLAW_CLUSTER_IMAGE_REGISTRY=artifactory.company.com/nvidia/openshell
NEMOCLAW_PULL_TIMEOUT_MS=1200000
NEMOCLAW_GATEWAY_START_TIMEOUT=900
```

**Rationale:** Corporate networks may have slower registry access and additional security scanning.

### Jetson AGX Orin

```bash
# .env
NEMOCLAW_GATEWAY_START_TIMEOUT=1500
NEMOCLAW_HEALTH_POLL_INTERVAL=20
NEMOCLAW_HEALTH_POLL_COUNT=60
NEMOCLAW_LOCAL_INFERENCE_TIMEOUT=600
```

**Rationale:** ARM64 systems are slower. Local inference on Jetson needs more time to load models.

### Development Fork

```bash
# .env
NEMOCLAW_REPO_URL=https://github.com/mycompany/NemoClaw.git
NEMOCLAW_INSTALL_TAG=feature/custom-integration
NEMOCLAW_SANDBOX_IMAGE=localhost:5000/openclaw:dev
NEMOCLAW_FRESH=1
```

**Rationale:** Testing custom features with locally-built images.

## Verification

### Check Configuration

```bash
# View loaded settings
env | grep NEMOCLAW

# Show current blueprint image
grep 'image:' nemoclaw-blueprint/blueprint.yaml

# Verify repo will be used
echo $NEMOCLAW_REPO_URL
```

### Test Installation

```bash
# Dry-run: load env and show what would be used
source scripts/load-env.sh
env | grep NEMOCLAW
```

## Troubleshooting

### Gateway Startup Timeout

**Error:** "Gateway startup timeout" during `nemoclaw onboard`

**Fix:**
```bash
# In .env
NEMOCLAW_GATEWAY_START_TIMEOUT=1500
NEMOCLAW_GATEWAY_START_POLL_INTERVAL=20
NEMOCLAW_GATEWAY_START_POLL_COUNT=75
```

### Image Pull Timeout

**Error:** "Image pull timeout" or "transfer timeout"

**Fix:**
```bash
# In .env
NEMOCLAW_PULL_TIMEOUT_MS=2400000  # 40 minutes
```

### Wrong Repository Cloned

**Issue:** Installation cloned official repo instead of fork

**Fix:**
```bash
# Verify .env exists and has correct setting
cat .env | grep REPO_URL

# Ensure load-env.sh is being sourced
ls -l scripts/load-env.sh
```

### Blueprint Not Updated

**Issue:** Custom image registry not applied

**Fix:**
```bash
# Manually apply overrides
./scripts/apply-image-overrides.sh

# Check result
grep 'image:' nemoclaw-blueprint/blueprint.yaml
```

## Best Practices

1. **Start with `.env.example`**
   ```bash
   cp .env.example .env
   ```

2. **Document Your Changes**
   ```bash
   # In .env
   # Increased for Docker Desktop on M1 Mac
   NEMOCLAW_GATEWAY_START_TIMEOUT=1200
   ```

3. **Never Commit `.env`**
   - Already in `.gitignore`
   - Contains secrets (API keys)

4. **Test Incrementally**
   - Change one setting at a time
   - Verify with `env | grep NEMOCLAW`

5. **Keep Backups**
   - Scripts auto-create `.backup` files
   - Manual backup: `cp .env .env.backup`

## Migration from Hardcoded Values

If you previously modified source files directly:

1. **Identify Your Changes**
   ```bash
   git diff src/lib/onboard.ts
   git diff nemoclaw-blueprint/blueprint.yaml
   ```

2. **Convert to `.env`**
   - Move hardcoded values to `.env`
   - Revert source file changes

3. **Verify**
   ```bash
   env | grep NEMOCLAW
   ./install.sh --help  # Should load .env
   ```

## Documentation

- **Quick Reference:** [CUSTOMIZATION_QUICKSTART.md](CUSTOMIZATION_QUICKSTART.md)
- **Complete Guide:** [docs/customization-guide.md](docs/customization-guide.md)
- **Template:** [.env.example](.env.example)

## Getting Help

1. **Check the guides:**
   - Quick start: `CUSTOMIZATION_QUICKSTART.md`
   - Full guide: `docs/customization-guide.md`

2. **Verify configuration:**
   ```bash
   env | grep NEMOCLAW
   cat .env
   ```

3. **Report issues:**
   - GitHub: https://github.com/NVIDIA/NemoClaw/issues
   - Include `.env` (with secrets redacted)

## What's Configurable

**Everything.** All timeouts, URLs, images, credentials, and behaviors are now configurable through environment variables. See `.env.example` for the complete list.

Common categories:
- Repository & installation
- Container images & registries  
- Timeouts & polling
- Docker operations
- Inference configuration
- API keys & credentials

## Summary

This customization system makes NemoClaw flexible for:
- ✅ Local Docker Desktop development
- ✅ Corporate environments with artifactory
- ✅ Forked repositories
- ✅ Slow networks
- ✅ ARM64 systems (Jetson, Mac M1/M2/M3)
- ✅ Custom container registries
- ✅ Non-interactive CI/CD pipelines

All without modifying source code.
