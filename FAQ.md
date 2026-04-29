# NemoClaw Customization FAQ

Quick answers to common customization questions.

## Images & Registries

### Q1: Do I need to configure NEMOCLAW_SANDBOX_IMAGE and NEMOCLAW_CLUSTER_IMAGE separately?

**A:** Yes, if you're using a custom registry.

- **NEMOCLAW_SANDBOX_IMAGE** (or `_REGISTRY`) — OpenClaw agent container
- **NEMOCLAW_CLUSTER_IMAGE** (or `_REGISTRY`) — k3s cluster container (gateway)

They are two different images pulled from potentially different registries.

**Example:**
```bash
# Both from same corporate artifactory
NEMOCLAW_SANDBOX_IMAGE_REGISTRY=artifactory.company.com/nvidia/sandboxes
NEMOCLAW_CLUSTER_IMAGE_REGISTRY=artifactory.company.com/nvidia/openshell
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for details.

### Q2: What's the difference between sandbox, cluster, and gateway images?

**A:**

| Term | What It Is | Image |
|------|------------|-------|
| **Sandbox** | Your OpenClaw AI assistant | Separate image |
| **Cluster** | k3s container running gateway | Separate image |
| **Gateway** | OpenShell service inside cluster | Same as cluster (not a separate image) |

Only TWO images to configure: sandbox + cluster.

### Q3: When should I override the registry vs the full image?

**A:**

**Use `_REGISTRY` when:**
- ✅ You want to pull from a different registry but keep the same image names
- ✅ Corporate artifactory mirrors official images
- ✅ You want version auto-detection to still work (cluster image)

**Use full `_IMAGE` when:**
- ✅ You have custom image names
- ✅ You need a specific pinned version
- ✅ You built custom images locally

**Examples:**
```bash
# Registry override (recommended for corporate environments)
NEMOCLAW_SANDBOX_IMAGE_REGISTRY=artifactory.company.com/nvidia/sandboxes
# Results in: artifactory.company.com/nvidia/sandboxes/openclaw@sha256:...

# Full image override (for custom builds)
NEMOCLAW_SANDBOX_IMAGE=localhost:5000/my-custom-openclaw:dev
# Results in: localhost:5000/my-custom-openclaw:dev (exactly as specified)
```

## Installation & Dependencies

### Q4: Will NemoClaw reinstall Node.js if I already have it?

**A:** No. NemoClaw checks the existing version and only installs/upgrades if:
- Node.js is missing, OR
- Version is < 22.16.0, OR
- npm version is < 10

If your Node.js meets requirements, it's reused.

**Tested with:**
- ✅ System package manager (apt, brew, etc.)
- ✅ nvm
- ✅ fnm
- ✅ asdf
- ✅ Docker pre-installed base image

### Q5: What if I installed Python/Rust using custom scripts?

**A:** Perfect! NemoClaw doesn't manage Python or Rust installation.

- **Python:** Must be on PATH as `python3`. Any version 3.8+ works.
- **Rust:** Optional, only needed for some agent extensions. Any recent version works.

Install them however you prefer (package manager, pyenv, rustup, etc.) — NemoClaw will use what's on PATH.

### Q6: Can I use Podman instead of Docker?

**A:** Yes. NemoClaw works with both Docker and Podman.

The installer doesn't install or configure either — it expects them to be pre-installed and working.

## Timeouts & Performance

### Q7: How do I calculate total wait time for timeout settings?

**A:** `Total Wait = POLL_COUNT × POLL_INTERVAL`

**Example:**
```bash
NEMOCLAW_HEALTH_POLL_COUNT=60
NEMOCLAW_HEALTH_POLL_INTERVAL=15
# Total: 60 × 15 = 900 seconds (15 minutes)
```

**When to increase:**
- Docker Desktop: 15-20 minute total wait
- Slow network: 20-30 minute total wait
- ARM64 systems: 15-20 minute total wait

### Q8: What timeouts should I increase for Docker Desktop?

**A:** Start with these Docker Desktop optimized settings:

```bash
# Docker Desktop (Mac/Windows)
NEMOCLAW_GATEWAY_START_TIMEOUT=1200      # 20 minutes
NEMOCLAW_HEALTH_POLL_INTERVAL=15         # Check every 15s
NEMOCLAW_HEALTH_POLL_COUNT=60            # 60 attempts
NEMOCLAW_PULL_TIMEOUT_MS=1800000         # 30 min image pulls
```

**Why:** Docker Desktop uses virtualization which adds overhead. k3s networking takes longer to initialize.

### Q9: Why did onboarding timeout even with increased settings?

**Checklist:**
1. ✅ `.env` file exists and contains settings
2. ✅ Settings are not commented out (no `#` prefix)
3. ✅ `load-env.sh` is being sourced (check install.sh)
4. ✅ Variable names are spelled correctly
5. ✅ Values are numeric (no quotes for numbers)

**Verify:**
```bash
# Check what's loaded
env | grep NEMOCLAW

# Should show:
# NEMOCLAW_GATEWAY_START_TIMEOUT=1200
# NEMOCLAW_HEALTH_POLL_INTERVAL=15
# etc.
```

If not showing, `.env` wasn't loaded. Check file location and syntax.

## Configuration

### Q10: Where should I put the .env file?

**A:** Two options:

1. **Project-specific:** `<repo>/.env` (applies when installing from this repo)
2. **Global:** `~/.nemoclaw/.env` (applies to all NemoClaw installations)

Project `.env` overrides global `.env`.

### Q11: Can I use environment variables instead of .env?

**A:** Yes! Priority is:

1. **Environment variables** (highest) — `export NEMOCLAW_GATEWAY_START_TIMEOUT=1200`
2. **Project .env** — `<repo>/.env`
3. **Global .env** — `~/.nemoclaw/.env`
4. **Built-in defaults** (lowest)

**Example:**
```bash
# Override just one setting via environment
export NEMOCLAW_GATEWAY_START_TIMEOUT=1800
./install.sh
# All other settings from .env, this one from environment
```

### Q12: How do I verify my configuration before installing?

**A:**

```bash
# Load .env and check
source scripts/load-env.sh
env | grep NEMOCLAW

# Check what blueprint will use
grep 'image:' nemoclaw-blueprint/blueprint.yaml

# Dry-run image overrides
./scripts/apply-image-overrides.sh
cat nemoclaw-blueprint/blueprint.yaml
```

## Forked Repositories

### Q13: How do I install from my forked repository?

**A:**

```bash
# In .env
NEMOCLAW_REPO_URL=https://github.com/YOUR_USERNAME/NemoClaw.git
NEMOCLAW_INSTALL_TAG=your-branch-or-tag

# Then install
curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash
```

The installer will clone from your fork instead of the official repo.

### Q14: Can I use a private repository?

**A:** Yes, but you must authenticate git first:

```bash
# SSH authentication
git config --global url."git@github.com:".insteadOf "https://github.com/"

# Or use GitHub token
git config --global url."https://YOUR_TOKEN@github.com/".insteadOf "https://github.com/"

# Then install
NEMOCLAW_REPO_URL=https://github.com/yourorg/NemoClaw.git ./install.sh
```

## Troubleshooting

### Q15: I set NEMOCLAW_SANDBOX_IMAGE but it still pulls from ghcr.io. Why?

**Check:**

1. ✅ `.env` file exists: `ls -la .env`
2. ✅ Setting is not commented out: `grep NEMOCLAW_SANDBOX_IMAGE .env`
3. ✅ Installer sources `load-env.sh`: `grep load-env scripts/install.sh`
4. ✅ Blueprint was updated: `grep image nemoclaw-blueprint/blueprint.yaml`

**Manual fix:**
```bash
# Manually apply overrides
./scripts/apply-image-overrides.sh

# Verify
grep 'image:' nemoclaw-blueprint/blueprint.yaml
```

### Q16: How do I reset to defaults?

**A:**

```bash
# Remove your customizations
rm .env

# Restore original blueprint (if you have a backup)
cp nemoclaw-blueprint/blueprint.yaml.backup nemoclaw-blueprint/blueprint.yaml

# Or reinstall
rm -rf ~/.nemoclaw
./install.sh
```

### Q17: Where can I find more help?

**Resources:**

- **Quick Start:** [CUSTOMIZATION_QUICKSTART.md](CUSTOMIZATION_QUICKSTART.md)
- **Full Guide:** [docs/customization-guide.md](docs/customization-guide.md)
- **Architecture:** [ARCHITECTURE.md](ARCHITECTURE.md)
- **Template:** [.env.example](.env.example)
- **Issues:** https://github.com/NVIDIA/NemoClaw/issues

**Getting Help:**

Include in your issue:
- Your `.env` file (with secrets redacted)
- Output of `env | grep NEMOCLAW`
- Output of `docker images | grep -E 'openshell|openclaw'`
- Installation logs

## Best Practices

### Q18: Should I commit .env to git?

**A:** NO. Never commit `.env` — it may contain secrets.

✅ **Do commit:** `.env.example` (template)  
❌ **Never commit:** `.env` (your config)

`.env` is already in `.gitignore`.

### Q19: How do I share configuration with my team?

**A:** Use `.env.example`:

```bash
# Update the example with your team's recommended settings
cp .env .env.example
# Remove any secrets
nano .env.example
# Commit to git
git add .env.example
git commit -m "docs: update .env.example for Docker Desktop"
git push
```

Team members can then:
```bash
cp .env.example .env
# Customize as needed
nano .env
```

### Q20: What settings should I always customize for production?

**A:**

```bash
# Use specific version tags, not :latest
NEMOCLAW_SANDBOX_IMAGE=registry.com/openclaw@sha256:abc123...
NEMOCLAW_CLUSTER_IMAGE=registry.com/cluster:0.0.36

# Increase timeouts for stability
NEMOCLAW_GATEWAY_START_TIMEOUT=1500
NEMOCLAW_PULL_TIMEOUT_MS=2400000

# Use your private registry
NEMOCLAW_SANDBOX_IMAGE_REGISTRY=registry.company.com/nvidia/sandboxes
NEMOCLAW_CLUSTER_IMAGE_REGISTRY=registry.company.com/nvidia/openshell
```

Pin versions to prevent unexpected changes from `:latest` tags.
