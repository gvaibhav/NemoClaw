# NemoClaw Customization Guide

This guide explains how to customize NemoClaw for different environments, particularly for local development with Docker Desktop or slow network environments.

## Quick Start

1. **Copy the template configuration:**
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` to customize settings:**
   ```bash
   nano .env  # or use your preferred editor
   ```

3. **Run installation with your custom settings:**
   ```bash
   ./install.sh
   # or
   curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash
   ```

## Configuration Locations

NemoClaw supports two configuration file locations:

1. **Project-specific**: `<repo>/.env` — applies only when installing from this repository
2. **Global**: `~/.nemoclaw/.env` — applies to all NemoClaw installations

Project-specific settings override global settings.

## Common Customization Scenarios

### Installing from a Forked Repository

If you have a forked version of NemoClaw:

```bash
# In .env
NEMOCLAW_REPO_URL=https://github.com/YOUR_USERNAME/NemoClaw.git
NEMOCLAW_INSTALL_TAG=your-branch-name
```

### Using a Custom Container Registry

**Important:** NemoClaw uses THREE types of images:
1. **Sandbox Image** — The OpenClaw agent container
2. **Cluster Image** — The k3s cluster container (gateway)
3. **Gateway Image** — Same as cluster (runs inside cluster container)

For corporate environments with an internal artifactory or private registry:

```bash
# Sandbox image (OpenClaw agent)
NEMOCLAW_SANDBOX_IMAGE_REGISTRY=your-artifactory.company.com/nvidia/sandboxes
# or full reference:
NEMOCLAW_SANDBOX_IMAGE=your-registry.company.com/openclaw:v1.2.3

# Cluster image (k3s gateway)
NEMOCLAW_CLUSTER_IMAGE_REGISTRY=your-artifactory.company.com/nvidia/openshell
# or full reference (must include version tag):
NEMOCLAW_CLUSTER_IMAGE=your-registry.company.com/cluster:0.0.36
```

**Note:** The cluster image version is usually auto-detected from your installed OpenShell version. Only override with full image reference if you need a specific version.

### Docker Desktop / Slow Environment Configuration

Docker Desktop on macOS/Windows can be slower than native Docker. Increase timeouts and polling intervals:

```bash
# Gateway startup (default: 600 seconds / 10 minutes)
# Increase if k3s network takes time to initialize
NEMOCLAW_GATEWAY_START_TIMEOUT=1200

# Health check interval (default: 5 seconds on x86, 10 on ARM)
# Poll less frequently to avoid overwhelming slow systems
NEMOCLAW_HEALTH_POLL_INTERVAL=15

# Health check count (default: 12 on x86, 30 on ARM)
# Increase to wait longer (count × interval = total wait time)
NEMOCLAW_HEALTH_POLL_COUNT=80

# Gateway startup polling (defaults to health check values)
NEMOCLAW_GATEWAY_START_POLL_INTERVAL=20
NEMOCLAW_GATEWAY_START_POLL_COUNT=60

# Image pull timeout (default: 10 minutes)
# Increase for slow networks
NEMOCLAW_PULL_TIMEOUT_MS=1800000  # 30 minutes

# Image build timeout (default: 5 minutes)
NEMOCLAW_BUILD_TIMEOUT_MS=900000  # 15 minutes
```

**Calculation:** Total wait time = `POLL_COUNT × POLL_INTERVAL`

Example: 60 count × 20 seconds = 1200 seconds (20 minutes)

### ARM64 / Jetson Configuration

ARM64 systems are slower by default. You may want to further increase timeouts:

```bash
NEMOCLAW_GATEWAY_START_TIMEOUT=900
NEMOCLAW_HEALTH_POLL_INTERVAL=15
NEMOCLAW_HEALTH_POLL_COUNT=40
```

### Slow Network Configuration

If you're on a slow internet connection:

```bash
# Increase timeouts for pulling large container images
NEMOCLAW_PULL_TIMEOUT_MS=2400000  # 40 minutes
NEMOCLAW_BUILD_TIMEOUT_MS=1200000  # 20 minutes
```

### Local Inference with Ollama/vLLM/NIM

If using local inference providers that take time to warm up:

```bash
# Local inference timeout (default: 180 seconds)
NEMOCLAW_LOCAL_INFERENCE_TIMEOUT=600

# Agent timeout for long-running operations
NEMOCLAW_AGENT_TIMEOUT=900
```

### Non-Interactive Installation

For CI/CD pipelines or automated deployments:

```bash
NEMOCLAW_NON_INTERACTIVE=1
NEMOCLAW_ACCEPT_THIRD_PARTY_SOFTWARE=1
NEMOCLAW_SANDBOX_NAME=ci-sandbox
NEMOCLAW_PROVIDER=build
NEMOCLAW_POLICY_MODE=suggested
NVIDIA_API_KEY=your-api-key-here
```

## Installation Reuse Behavior

**Question:** If I install Rust, Node.js, or Python using custom scripts, will NemoClaw try to reinstall them?

**Answer:** No. NemoClaw intelligently reuses existing installations. It only installs or upgrades when necessary.

### Dependency Reuse Table

| Tool | Managed by Installer? | Reuse Behavior | Minimum Version |
|------|----------------------|----------------|-----------------|
| **Node.js** | ✅ Yes (via nvm) | Reuses if version ≥ 22.16.0 | 22.16.0 |
| **npm** | ✅ Yes (with Node.js) | Reuses if version ≥ 10 | 10.x |
| **Ollama** | ✅ Yes (if GPU detected) | Reuses if version ≥ 0.18.0 | 0.18.0 |
| **Python** | ❌ Not managed | Uses system Python (must be available) | 3.8+ |
| **Rust** | ❌ Not managed | Uses system Rust (must be available) | Any recent version |
| **Docker** | ❌ Not managed | Must be pre-installed | 20.10+ |
| **uv** | ⚠️ Blueprint dependency | Installed by blueprint if needed | Latest |
| **git** | ❌ Not managed | Must be pre-installed | 2.x |

### Installation Logic

**Node.js:**
```bash
# Checks existing Node.js
if command -v node; then
  version=$(node --version)
  if version >= 22.16.0; then
    echo "Using existing Node.js"
    SKIP_INSTALL
  else
    echo "Upgrading Node.js via nvm"
    INSTALL_VIA_NVM
  fi
else
  echo "Installing Node.js via nvm"
  INSTALL_VIA_NVM
fi
```

**Ollama:**
```bash
# Only installs if GPU detected
if nvidia-smi; then
  if command -v ollama; then
    version=$(ollama --version)
    if version >= 0.18.0; then
      echo "Using existing Ollama"
      SKIP_INSTALL
    else
      echo "Upgrading Ollama"
      UPGRADE
    fi
  else
    echo "Installing Ollama"
    INSTALL
  fi
else
  echo "No GPU detected, skipping Ollama"
  SKIP
fi
```

**Python/Rust/Docker:**
```bash
# Not managed - uses whatever is on PATH
# Blueprint and build scripts expect these to be available
command -v python3 || ERROR
command -v docker || ERROR
# Rust is optional (only needed for some agent extensions)
```

### Custom Installation Support

You can install dependencies however you prefer:

**Via Package Managers:**
```bash
# Install Node.js via package manager instead of nvm
sudo apt install nodejs npm  # Ubuntu/Debian
brew install node            # macOS

# Then run NemoClaw installer
./install.sh
# ✅ Will detect and use your Node.js installation
```

**Via Version Managers:**
```bash
# Install Node.js via fnm instead of nvm
fnm install 22
fnm use 22

# Install Python via pyenv
pyenv install 3.12.0
pyenv global 3.12.0

# Install Rust via rustup
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Then run NemoClaw installer
./install.sh
# ✅ Will detect and use your installations
```

**Pre-installed in Docker:**
```dockerfile
FROM ubuntu:24.04

# Install all dependencies first
RUN apt-get update && apt-get install -y \
    nodejs npm python3 docker.io git

# Then run NemoClaw installer
RUN curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash
# ✅ Will detect and use pre-installed tools
```

### What Gets Installed

**Always installed by NemoClaw:**
- Node.js (if missing or too old) via nvm
- npm (bundled with Node.js)

**Conditionally installed:**
- Ollama (only if GPU detected and version < 0.18.0)
- OpenShell CLI (always, via separate script)

**Never installed (must be pre-installed):**
- Docker or Podman
- git
- Python (used by blueprint, must be on PATH)
- Rust (optional, for some extensions)

**Installed by blueprint (during sandbox creation):**
- uv (Python package manager)
- Agent-specific dependencies

### Verification

Check what will be reused:

```bash
# Check Node.js
node --version  # Should be >= 22.16.0
npm --version   # Should be >= 10

# Check Ollama (if using local inference)
ollama --version  # Should be >= 0.18.0

# Check other tools
python3 --version
docker --version
git --version
```

If versions are sufficient, the installer will reuse them.

## Configuration Reference

### Repository Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `NEMOCLAW_REPO_URL` | `https://github.com/NVIDIA/NemoClaw.git` | Git repository URL |
| `NEMOCLAW_INSTALL_TAG` | `latest` | Git branch/tag to install |

### Image Registry Settings

**Important:** See [ARCHITECTURE.md](../ARCHITECTURE.md) for detailed explanation of the three image types.

| Variable | Default | Description |
|----------|---------|-------------|
| `NEMOCLAW_SANDBOX_IMAGE_REGISTRY` | `ghcr.io/nvidia/openshell-community/sandboxes` | Sandbox image registry |
| `NEMOCLAW_SANDBOX_IMAGE` | (derived from blueprint) | Full sandbox image reference (overrides registry) |
| `NEMOCLAW_CLUSTER_IMAGE_REGISTRY` | `ghcr.io/nvidia/openshell` | Cluster image registry (version auto-appended) |
| `NEMOCLAW_CLUSTER_IMAGE` | (derived from OpenShell version) | Full cluster image reference (overrides registry) |
| `NEMOCLAW_IMAGE_REGISTRY` | (deprecated) | Legacy setting, use specific registries instead |

### Timeout Settings (seconds)

| Variable | Default | Description |
|----------|---------|-------------|
| `NEMOCLAW_GATEWAY_START_TIMEOUT` | `600` | Maximum time to wait for gateway startup |
| `NEMOCLAW_LOCAL_INFERENCE_TIMEOUT` | `180` | Timeout for local inference providers |
| `NEMOCLAW_AGENT_TIMEOUT` | (blueprint) | Agent execution timeout |

### Polling Settings

| Variable | Default (x86 / ARM64) | Description |
|----------|----------------------|-------------|
| `NEMOCLAW_HEALTH_POLL_INTERVAL` | `5` / `10` | Seconds between health checks |
| `NEMOCLAW_HEALTH_POLL_COUNT` | `12` / `30` | Number of health check attempts |
| `NEMOCLAW_GATEWAY_START_POLL_INTERVAL` | (same as health) | Seconds between gateway startup checks |
| `NEMOCLAW_GATEWAY_START_POLL_COUNT` | (same as health) | Number of gateway startup check attempts |

### Docker Operation Timeouts (milliseconds)

| Variable | Default | Description |
|----------|---------|-------------|
| `NEMOCLAW_PULL_TIMEOUT_MS` | `600000` (10 min) | Docker image pull timeout |
| `NEMOCLAW_BUILD_TIMEOUT_MS` | `300000` (5 min) | Docker image build timeout |
| `NEMOCLAW_INSPECT_TIMEOUT_MS` | `30000` (30 sec) | Docker inspect timeout |

### Installation Behavior

| Variable | Default | Description |
|----------|---------|-------------|
| `NEMOCLAW_NON_INTERACTIVE` | (unset) | Skip prompts, use env vars/defaults |
| `NEMOCLAW_FRESH` | (unset) | Discard existing onboarding session |
| `NEMOCLAW_RECREATE_SANDBOX` | (unset) | Recreate existing sandbox |
| `NEMOCLAW_SINGLE_SESSION` | (unset) | Abort if active sessions exist |

### Inference Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `NEMOCLAW_PROVIDER` | (prompted) | Inference provider (`build`, `openai`, `anthropic`, etc.) |
| `NEMOCLAW_MODEL` | (provider default) | Inference model name |
| `NEMOCLAW_POLICY_MODE` | (prompted) | Network policy mode (`suggested`, `custom`, `skip`) |
| `NEMOCLAW_POLICY_PRESETS` | (empty) | Comma-separated policy presets |

## Applying Image Registry Overrides

Image registry overrides are applied automatically during installation. To manually apply them:

```bash
./scripts/apply-image-overrides.sh
```

This script:
1. Loads configuration from `.env`
2. Updates `nemoclaw-blueprint/blueprint.yaml`
3. Creates a backup at `nemoclaw-blueprint/blueprint.yaml.backup`

To restore the original:

```bash
cp nemoclaw-blueprint/blueprint.yaml.backup nemoclaw-blueprint/blueprint.yaml
```

## Verifying Configuration

Check which settings are active:

```bash
# Show loaded environment variables
env | grep NEMOCLAW

# Verify blueprint image reference
grep 'image:' nemoclaw-blueprint/blueprint.yaml
```

## Troubleshooting

### Gateway Startup Timeout

**Symptom:** `nemoclaw onboard` fails with "Gateway startup timeout"

**Solutions:**
1. Increase `NEMOCLAW_GATEWAY_START_TIMEOUT`
2. Increase `NEMOCLAW_GATEWAY_START_POLL_COUNT`
3. Increase `NEMOCLAW_GATEWAY_START_POLL_INTERVAL`

```bash
# Example for Docker Desktop
NEMOCLAW_GATEWAY_START_TIMEOUT=1200
NEMOCLAW_GATEWAY_START_POLL_INTERVAL=15
NEMOCLAW_GATEWAY_START_POLL_COUNT=80
```

### Image Pull Timeout

**Symptom:** Installation fails with "Image pull timeout" or "transfer timeout"

**Solution:** Increase `NEMOCLAW_PULL_TIMEOUT_MS`

```bash
# 30 minutes for slow connections
NEMOCLAW_PULL_TIMEOUT_MS=1800000
```

### k3s Network Not Ready

**Symptom:** Gateway fails to start, logs show k3s networking issues

**Solution:** Increase both poll count and interval

```bash
NEMOCLAW_HEALTH_POLL_INTERVAL=20
NEMOCLAW_HEALTH_POLL_COUNT=60
# Total wait: 20s × 60 = 1200s (20 minutes)
```

### Image Registry Connection Failed

**Symptom:** Cannot pull images from custom registry

**Solutions:**
1. Verify `NEMOCLAW_IMAGE_REGISTRY` or `NEMOCLAW_SANDBOX_IMAGE` is correct
2. Ensure Docker is authenticated to your registry:
   ```bash
   docker login your-registry.company.com
   ```
3. Check network connectivity to the registry

## Best Practices

1. **Start Conservative:** Use higher timeouts initially, then reduce if stable
2. **Document Custom Settings:** Add comments to your `.env` explaining why values were changed
3. **Version Control:** Add `.env.example` to git, but **never commit `.env`** with secrets
4. **Test Incrementally:** Change one setting at a time to identify what works
5. **Monitor Resources:** Use `docker stats` to see if you're resource-constrained

## Example Configurations

### Docker Desktop (macOS/Windows)

```bash
# .env for Docker Desktop
NEMOCLAW_GATEWAY_START_TIMEOUT=1200
NEMOCLAW_HEALTH_POLL_INTERVAL=15
NEMOCLAW_HEALTH_POLL_COUNT=60
NEMOCLAW_PULL_TIMEOUT_MS=1800000
```

### Corporate Environment

```bash
# .env for corporate network with artifactory
NEMOCLAW_IMAGE_REGISTRY=artifactory.company.com/nvidia
NEMOCLAW_PULL_TIMEOUT_MS=1200000
NEMOCLAW_GATEWAY_START_TIMEOUT=900
```

### Jetson Developer Kit

```bash
# .env for NVIDIA Jetson
NEMOCLAW_GATEWAY_START_TIMEOUT=1200
NEMOCLAW_HEALTH_POLL_INTERVAL=20
NEMOCLAW_HEALTH_POLL_COUNT=40
NEMOCLAW_LOCAL_INFERENCE_TIMEOUT=600
```

### Development Fork

```bash
# .env for development fork
NEMOCLAW_REPO_URL=https://github.com/mycompany/NemoClaw.git
NEMOCLAW_INSTALL_TAG=feature/custom-integration
NEMOCLAW_SANDBOX_IMAGE=localhost:5000/openclaw:dev
```

## Getting Help

If you continue to experience issues after tuning timeouts:

1. Check the logs: `nemoclaw <sandbox-name> logs`
2. Inspect Docker containers: `docker ps -a`
3. Review k3s status: `nemoclaw <sandbox-name> connect`, then `kubectl get pods --all-namespaces`
4. Open an issue: https://github.com/NVIDIA/NemoClaw/issues

Include your `.env` file (with secrets redacted) when reporting issues.
