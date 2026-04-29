# NemoClaw Customization Quick Start

This guide helps you quickly customize NemoClaw for local Docker Desktop or custom environments.

## TL;DR - Docker Desktop Setup

```bash
# 1. Copy the template
cp .env.example .env

# 2. Edit .env and add these lines:
cat >> .env << 'EOF'
# Docker Desktop optimized settings
NEMOCLAW_GATEWAY_START_TIMEOUT=1200
NEMOCLAW_HEALTH_POLL_INTERVAL=15
NEMOCLAW_HEALTH_POLL_COUNT=60
NEMOCLAW_PULL_TIMEOUT_MS=1800000
EOF

# 3. Run installation
./install.sh
# or
curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash
```

## Common Scenarios

### 1. Forked Repository

```bash
# In .env
NEMOCLAW_REPO_URL=https://github.com/YOUR_USERNAME/NemoClaw.git
NEMOCLAW_INSTALL_TAG=your-branch
```

### 2. Custom Image Registry

```bash
# In .env
NEMOCLAW_SANDBOX_IMAGE_REGISTRY=your-artifactory.company.com/nvidia/sandboxes
# or for full image override:
NEMOCLAW_SANDBOX_IMAGE=your-registry.company.com/openclaw:latest
```

### 3. Slow Environment (Docker Desktop / ARM64)

```bash
# In .env
NEMOCLAW_GATEWAY_START_TIMEOUT=1200
NEMOCLAW_HEALTH_POLL_INTERVAL=15
NEMOCLAW_HEALTH_POLL_COUNT=80
NEMOCLAW_PULL_TIMEOUT_MS=1800000
```

### 4. Very Slow Network

```bash
# In .env
NEMOCLAW_PULL_TIMEOUT_MS=2400000  # 40 minutes
NEMOCLAW_BUILD_TIMEOUT_MS=1200000  # 20 minutes
```

## How It Works

1. **Configuration Files:**
   - `.env` — Project-specific settings (create from `.env.example`)
   - `~/.nemoclaw/.env` — Global settings (optional)

2. **Auto-Loading:**
   - Installation scripts automatically load `.env` if present
   - No code changes needed — just set environment variables

3. **Override Priority:**
   - Command-line environment variables (highest)
   - Project `.env` file
   - Global `~/.nemoclaw/.env`
   - Built-in defaults (lowest)

## Key Settings for Docker Desktop

| Setting | Recommended | Why |
|---------|-------------|-----|
| `NEMOCLAW_GATEWAY_START_TIMEOUT` | `1200` | k3s network needs extra time |
| `NEMOCLAW_HEALTH_POLL_INTERVAL` | `15` | Poll less frequently |
| `NEMOCLAW_HEALTH_POLL_COUNT` | `60-80` | More attempts before timeout |
| `NEMOCLAW_PULL_TIMEOUT_MS` | `1800000` | Slower image pulls |

**Total wait calculation:** `POLL_COUNT × POLL_INTERVAL`  
Example: 60 × 15s = 900s (15 minutes)

## Verification

```bash
# Check loaded settings
env | grep NEMOCLAW

# Verify image configuration
grep 'image:' nemoclaw-blueprint/blueprint.yaml
```

## Next Steps

See [docs/customization-guide.md](docs/customization-guide.md) for:
- Complete configuration reference
- Troubleshooting guide
- Advanced scenarios
- Best practices

## Quick Troubleshooting

**Gateway timeout?**
→ Increase `NEMOCLAW_GATEWAY_START_TIMEOUT` and poll count/interval

**Image pull timeout?**
→ Increase `NEMOCLAW_PULL_TIMEOUT_MS`

**k3s network not ready?**
→ Increase both `NEMOCLAW_HEALTH_POLL_INTERVAL` and `NEMOCLAW_HEALTH_POLL_COUNT`

## Getting Help

- Full guide: [docs/customization-guide.md](docs/customization-guide.md)
- Issues: https://github.com/NVIDIA/NemoClaw/issues
- Template: [.env.example](.env.example)
