# Backwards Compatibility Guarantee

**TL;DR:** If you don't configure `.env`, NemoClaw works exactly as it did before. All customizations are optional.

## The Guarantee

| Scenario | Behavior |
|----------|----------|
| **Empty `.env` file** | ✅ All defaults used, installs normally |
| **No `.env` file** | ✅ All defaults used, installs normally |
| **Commented-out settings** | ✅ Settings ignored, defaults used |
| **Only some settings configured** | ✅ Configured values used, rest defaults |
| **All settings configured** | ✅ Custom values used throughout |

**Result in all cases:** Installation and onboarding complete successfully.

---

## How Fallbacks Work

### 1. Image Registries (Sandbox & Cluster)

**Sandbox Image:**
```
Priority:
1. NEMOCLAW_SANDBOX_IMAGE (full reference) — if set
2. NEMOCLAW_SANDBOX_IMAGE_REGISTRY (registry only) — if set
3. NEMOCLAW_IMAGE_REGISTRY (legacy, deprecated) — if set
4. ✅ DEFAULT: ghcr.io/nvidia/openshell-community/sandboxes/openclaw@sha256:...
```

**Cluster Image:**
```
Priority:
1. NEMOCLAW_CLUSTER_IMAGE (full reference) — if set
2. NEMOCLAW_CLUSTER_IMAGE_REGISTRY (registry only) — if set
3. ✅ DEFAULT: ghcr.io/nvidia/openshell/cluster:<version>
   (version auto-detected from installed OpenShell)
```

**Script Behavior:**
```bash
# If no custom registries are set...
if [[ -z "${NEMOCLAW_SANDBOX_IMAGE:-}" && \
      -z "${NEMOCLAW_SANDBOX_IMAGE_REGISTRY:-}" && \
      -z "${NEMOCLAW_IMAGE_REGISTRY:-}" ]]; then
  # Exit silently - don't modify blueprint.yaml
  exit 0
fi
```

### 2. Timeouts & Performance

**Docker Operations:**
```bash
# If environment variables are not set, use defaults:
DEFAULT_PULL_TIMEOUT_MS = envInt("NEMOCLAW_PULL_TIMEOUT_MS", 10 * 60 * 1000)
# Result: 10 minutes (original default)

DEFAULT_BUILD_TIMEOUT_MS = envInt("NEMOCLAW_BUILD_TIMEOUT_MS", 5 * 60 * 1000)  
# Result: 5 minutes (original default)

DEFAULT_INSPECT_TIMEOUT_MS = envInt("NEMOCLAW_INSPECT_TIMEOUT_MS", 30 * 1000)
# Result: 30 seconds (original default)
```

**Gateway & Health Checks:**
```
If NEMOCLAW_GATEWAY_START_TIMEOUT not set:
  → Use original default (600 seconds = 10 minutes)

If NEMOCLAW_HEALTH_POLL_INTERVAL not set:
  → Use original default (5 seconds on x86, 10 on ARM)

If NEMOCLAW_HEALTH_POLL_COUNT not set:
  → Use original default (12 on x86, 30 on ARM)
```

### 3. Repository URL

**Default:**
```bash
# If NEMOCLAW_REPO_URL not set:
git clone --depth 1 https://github.com/NVIDIA/NemoClaw.git
# (Original behavior preserved)
```

---

## What Happens If You Leave `.env` Blank?

### Scenario: Empty `.env` file (or no `.env` file)

```bash
# .env is empty (or missing entirely)

# 1. load-env.sh runs but finds nothing to load
#    → All NEMOCLAW_* variables remain unset

# 2. apply-image-overrides.sh checks for custom settings
#    → Finds none, exits silently
#    → blueprint.yaml is NOT modified
#    → Uses original default image

# 3. onboard.ts constructs cluster image
#    const registry = process.env.NEMOCLAW_CLUSTER_IMAGE_REGISTRY 
#                     || "ghcr.io/nvidia/openshell"
#    → Falls back to default registry

# 4. cluster-image-patch.ts uses timeout defaults
#    const pullTimeout = envInt(..., 10 * 60 * 1000)
#    → Falls back to 10 minutes

# 5. Installation proceeds with ALL original defaults
#    → Installs from github.com/NVIDIA/NemoClaw.git
#    → Pulls from ghcr.io/nvidia/...
#    → Uses original timeout values
#    → Onboarding completes successfully
```

**Result:** Everything works exactly as before customization was added.

---

## Installation Flow (With & Without `.env`)

### Without `.env` (Original Behavior)

```
$ ./install.sh

[1/3] Node.js
  ✓ Node.js found: v22.16.0
  
[2/3] NemoClaw CLI
  ✓ Cloning from: https://github.com/NVIDIA/NemoClaw.git
  ✓ Installing dependencies...
  
[3/3] Onboarding
  → Using defaults:
    - Sandbox: ghcr.io/nvidia/openshell-community/sandboxes/openclaw@sha256:...
    - Cluster: ghcr.io/nvidia/openshell/cluster:0.0.36
    - Gateway timeout: 600 seconds
    - Pull timeout: 10 minutes

✅ Installation complete
```

### With Empty `.env`

```
$ ./install.sh

[1/3] Node.js
  ✓ Node.js found: v22.16.0
  [load-env.sh sourced - no custom settings found]
  
[2/3] NemoClaw CLI
  ✓ Cloning from: https://github.com/NVIDIA/NemoClaw.git
  ✓ Installing dependencies...
  
[3/3] Onboarding
  [apply-image-overrides.sh: no overrides configured, exiting silently]
  → Using defaults:
    - Sandbox: ghcr.io/nvidia/openshell-community/sandboxes/openclaw@sha256:...
    - Cluster: ghcr.io/nvidia/openshell/cluster:0.0.36
    - Gateway timeout: 600 seconds
    - Pull timeout: 10 minutes

✅ Installation complete
```

### With Custom `.env`

```
$ ./install.sh

[1/3] Node.js
  ✓ Node.js found: v22.16.0
  [load-env.sh sourced - custom settings loaded]
  
[2/3] NemoClaw CLI
  ✓ Cloning from: https://github.com/yourorg/NemoClaw.git
  ✓ Installing dependencies...
  
[3/3] Onboarding
  [apply-image-overrides.sh: applying custom sandbox image registry]
  → Using custom settings:
    - Sandbox: artifactory.company.com/nvidia/sandboxes/openclaw@sha256:...
    - Cluster: artifactory.company.com/nvidia/openshell/cluster:0.0.36
    - Gateway timeout: 1200 seconds (custom)
    - Pull timeout: 30 minutes (custom)

✅ Installation complete
```

**Same installation, different configuration — backwards compatible!**

---

## Test Results

Run the backwards compatibility test yourself:

```bash
# 1. Create empty .env
touch .env

# 2. Load and verify no overrides are set
source scripts/load-env.sh
env | grep NEMOCLAW
# (Should output nothing or existing values only)

# 3. Try installing
./install.sh
# (Should work with defaults)
```

---

## Verification Checklist

✅ **If you don't set any `.env` variables:**
- [ ] Sandbox image uses `ghcr.io/nvidia/openshell-community/sandboxes/openclaw@sha256:...`
- [ ] Cluster image uses `ghcr.io/nvidia/openshell/cluster:<version>`
- [ ] Pull timeout is 10 minutes (original)
- [ ] Build timeout is 5 minutes (original)
- [ ] Gateway startup timeout is 10 minutes (original)
- [ ] Installation clones from `github.com/NVIDIA/NemoClaw.git` (original)
- [ ] Onboarding completes successfully

✅ **If you set some `.env` variables:**
- [ ] Customized settings are used
- [ ] Other settings fall back to defaults
- [ ] Everything still works

---

## FAQ: Will This Break If...

### Q: I leave `.env` empty?
**A:** No. Empty `.env` is treated the same as no `.env` file. All defaults used.

### Q: I don't create `.env` at all?
**A:** No problem. Scripts check `if [[ -f "$ENV_FILE" ]]` before loading. Works fine without it.

### Q: I update NemoClaw but keep my `.env`?
**A:** Your settings continue to work. New defaults are only used for variables you didn't customize.

### Q: My `.env` has typos?
**A:** Those variables are ignored, other settings work. Only valid `KEY=VALUE` pairs are loaded.

### Q: I git-commit my `.env` file by mistake?
**A:** It's already in `.gitignore`, so won't be tracked. But never commit `.env` with secrets!

### Q: The installation says "using defaults" — is that bad?
**A:** No! Using defaults means no customization was found, everything works normally.

---

## How to Verify Backwards Compatibility

**Check current configuration:**
```bash
source scripts/load-env.sh
env | grep NEMOCLAW

# If output is empty, using all defaults ✓
# If output shows your custom values, using customization ✓
```

**Check which images will be used:**
```bash
# Sandbox image (from blueprint)
grep 'image:' nemoclaw-blueprint/blueprint.yaml

# Expected default:
# image: "ghcr.io/nvidia/openshell-community/sandboxes/openclaw@sha256:..."
```

**Check timeout values:**
```bash
# Fallback timeout defaults
grep "envInt.*NEMOCLAW_.*_TIMEOUT" src/lib/*.ts

# Expected fallbacks:
# DEFAULT_PULL_TIMEOUT_MS = envInt(..., 10 * 60 * 1000)
# DEFAULT_BUILD_TIMEOUT_MS = envInt(..., 5 * 60 * 1000)
```

---

## Summary

| Aspect | Without .env | With Empty .env | With Custom .env |
|--------|-------------|-----------------|------------------|
| **Cloning** | `github.com/NVIDIA` | `github.com/NVIDIA` | Your fork URL |
| **Sandbox Image** | Default registry | Default registry | Custom registry |
| **Cluster Image** | Default registry | Default registry | Custom registry |
| **Timeouts** | Original defaults | Original defaults | Your values |
| **Installation** | ✅ Works | ✅ Works | ✅ Works |
| **Onboarding** | ✅ Completes | ✅ Completes | ✅ Completes |

**Bottom line:** Customization is completely optional. Don't set `.env`, everything works. Set `.env`, customize to your environment. Either way, full backwards compatibility.
