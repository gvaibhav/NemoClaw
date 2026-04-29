# NemoClaw Container Image Architecture

Understanding the three types of container images used by NemoClaw.

## Overview

NemoClaw uses a multi-container architecture with three distinct image types:

```
┌─────────────────────────────────────────────┐
│         Your Local Machine                  │
│                                             │
│  ┌────────────────────────────────────┐    │
│  │    Docker / Podman Engine          │    │
│  │                                    │    │
│  │  ┌──────────────────────────────┐ │    │
│  │  │  Cluster Container (k3s)     │ │    │
│  │  │  Image: openshell/cluster    │ │    │
│  │  │  ┌────────────────────────┐  │ │    │
│  │  │  │  Gateway Service       │  │ │    │
│  │  │  │  (OpenShell)           │  │ │    │
│  │  │  └────────────────────────┘  │ │    │
│  │  │  ┌────────────────────────┐  │ │    │
│  │  │  │  Sandbox Pod           │  │ │    │
│  │  │  │  Image: openclaw       │  │ │    │
│  │  │  │  (Your AI Assistant)   │  │ │    │
│  │  │  └────────────────────────┘  │ │    │
│  │  └──────────────────────────────┘ │    │
│  └────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

## The Three Image Types

### 1. Sandbox Image (OpenClaw Agent)

**Purpose:** Runs your AI assistant (OpenClaw)

**Default Registry:** `ghcr.io/nvidia/openshell-community/sandboxes/openclaw`

**Configured in:** `nemoclaw-blueprint/blueprint.yaml`

**Environment Variables:**
```bash
# Override just the registry
NEMOCLAW_SANDBOX_IMAGE_REGISTRY=your-registry.com/path

# Override the complete image reference
NEMOCLAW_SANDBOX_IMAGE=your-registry.com/openclaw:custom-tag
```

**What runs in this container:**
- OpenClaw agent
- Python runtime
- User workspace files
- Agent tools and extensions

### 2. Cluster Image (k3s Gateway)

**Purpose:** Provides the k3s cluster that hosts the OpenShell gateway and sandbox pods

**Default Registry:** `ghcr.io/nvidia/openshell/cluster:${VERSION}`

**Configured in:** `src/lib/onboard.ts` (dynamically constructed)

**Environment Variables:**
```bash
# Override the registry (version auto-appended)
NEMOCLAW_CLUSTER_IMAGE_REGISTRY=your-registry.com/path

# Override the complete image reference
NEMOCLAW_CLUSTER_IMAGE=your-registry.com/cluster:0.0.36
```

**What runs in this container:**
- k3s (lightweight Kubernetes)
- OpenShell gateway service
- Network policies
- Container orchestration

**Note:** The version tag is automatically determined by your installed OpenShell version.

### 3. Gateway Image

**Purpose:** Same as cluster image (they are the same container)

The "gateway" is a service running inside the cluster container, not a separate image.

## Configuration Priority

### For Sandbox Image

1. `NEMOCLAW_SANDBOX_IMAGE` (full reference) — highest priority
2. `NEMOCLAW_SANDBOX_IMAGE_REGISTRY` (registry only)
3. `NEMOCLAW_IMAGE_REGISTRY` (legacy, deprecated)
4. Default: `ghcr.io/nvidia/openshell-community/sandboxes/openclaw@sha256:...`

### For Cluster Image

1. `NEMOCLAW_CLUSTER_IMAGE` (full reference) — highest priority
2. `NEMOCLAW_CLUSTER_IMAGE_REGISTRY` (registry only, version auto-appended)
3. Default: `ghcr.io/nvidia/openshell/cluster:${openshell_version}`

## When to Override Each Image

### Sandbox Image

Override when:
- ✅ Using a custom OpenClaw build
- ✅ Corporate artifactory requires pulling from internal registry
- ✅ Testing custom agent features
- ✅ Using a specific pinned version

### Cluster Image

Override when:
- ✅ Corporate firewall blocks GitHub Container Registry
- ✅ Using a patched OpenShell version
- ✅ Testing OpenShell features
- ✅ Airgapped environment with pre-pulled images

## Examples

### Corporate Artifactory Setup

```bash
# .env
# Both images from the same artifactory
NEMOCLAW_SANDBOX_IMAGE_REGISTRY=artifactory.company.com/nvidia/sandboxes
NEMOCLAW_CLUSTER_IMAGE_REGISTRY=artifactory.company.com/nvidia/openshell
```

### Different Registries

```bash
# .env
# Sandbox from GitHub, cluster from local registry
NEMOCLAW_SANDBOX_IMAGE=ghcr.io/nvidia/openshell-community/sandboxes/openclaw:latest
NEMOCLAW_CLUSTER_IMAGE_REGISTRY=localhost:5000/openshell
```

### Development Setup

```bash
# .env
# Local builds for both
NEMOCLAW_SANDBOX_IMAGE=localhost:5000/openclaw:dev
NEMOCLAW_CLUSTER_IMAGE=localhost:5000/openshell-cluster:dev
```

### Mixed Environment

```bash
# .env
# Production sandbox, custom cluster
NEMOCLAW_SANDBOX_IMAGE=ghcr.io/nvidia/openshell-community/sandboxes/openclaw@sha256:abc123
NEMOCLAW_CLUSTER_IMAGE=company-registry.com/openshell-cluster:patched-v0.0.36
```

## Image Pull Flow

1. **Installation Phase:**
   - No images pulled yet
   - Configuration loaded from `.env`

2. **Onboarding Phase:**
   - `apply-image-overrides.sh` updates `blueprint.yaml` with sandbox image
   - `onboard.ts` constructs cluster image URL using env var

3. **Gateway Startup:**
   - Docker/Podman pulls cluster image
   - k3s starts inside cluster container
   - Gateway service initializes

4. **Sandbox Creation:**
   - Gateway reads sandbox image from blueprint
   - k3s pulls sandbox image into the cluster
   - Sandbox pod starts with OpenClaw

## Verification

### Check Configured Images

```bash
# Sandbox image (in blueprint)
grep 'image:' nemoclaw-blueprint/blueprint.yaml

# Cluster image (will be constructed at runtime)
env | grep NEMOCLAW_CLUSTER

# Show what will be used
source scripts/load-env.sh
echo "Sandbox: ${NEMOCLAW_SANDBOX_IMAGE:-default}"
echo "Cluster registry: ${NEMOCLAW_CLUSTER_IMAGE_REGISTRY:-ghcr.io/nvidia/openshell}"
```

### Check Running Containers

```bash
# See the cluster container
docker ps | grep openshell

# See images pulled
docker images | grep -E 'openshell|openclaw'

# Inside cluster, see sandbox pod
nemoclaw <sandbox-name> connect
kubectl get pods -A
kubectl describe pod <openclaw-pod-name> -n openclaw
```

## Troubleshooting

### Sandbox Image Not Found

```
Error: Failed to pull image "ghcr.io/nvidia/openshell-community/sandboxes/openclaw@sha256:..."
```

**Solutions:**
1. Check `NEMOCLAW_SANDBOX_IMAGE_REGISTRY` is correct
2. Verify Docker/Podman can reach the registry: `docker pull <image>`
3. Authenticate if required: `docker login <registry>`
4. Check blueprint was updated: `grep image nemoclaw-blueprint/blueprint.yaml`

### Cluster Image Not Found

```
Error: Failed to pull image "ghcr.io/nvidia/openshell/cluster:0.0.36"
```

**Solutions:**
1. Check `NEMOCLAW_CLUSTER_IMAGE_REGISTRY` is correct
2. Verify version exists in registry: `docker manifest inspect <image>`
3. Use full image override: `NEMOCLAW_CLUSTER_IMAGE=your-registry.com/cluster:0.0.36`

### Images Pulled from Wrong Registry

**Issue:** Images still pulling from default registry despite config

**Solutions:**
1. Verify `.env` is being loaded: `env | grep NEMOCLAW`
2. Check `load-env.sh` was sourced by installer
3. Manually apply overrides: `./scripts/apply-image-overrides.sh`
4. Verify no typos in env var names

## Best Practices

1. **Pin Versions:** Use digest-pinned images for production
   ```bash
   NEMOCLAW_SANDBOX_IMAGE=registry.com/openclaw@sha256:abc123def...
   ```

2. **Test Registry Access First:**
   ```bash
   docker pull your-registry.com/openclaw:latest
   docker pull your-registry.com/openshell/cluster:0.0.36
   ```

3. **Use Same Registry for Both:** Simplifies firewall rules and credentials
   ```bash
   NEMOCLAW_SANDBOX_IMAGE_REGISTRY=artifactory.company.com/nvidia/sandboxes
   NEMOCLAW_CLUSTER_IMAGE_REGISTRY=artifactory.company.com/nvidia/openshell
   ```

4. **Document Custom Images:** Add comments to your `.env`
   ```bash
   # Custom OpenClaw build with company-specific tools
   NEMOCLAW_SANDBOX_IMAGE=company.com/openclaw:v1.2.3-custom
   ```

## Summary

- **Sandbox Image** = Your AI assistant container (OpenClaw)
- **Cluster Image** = k3s + gateway container (OpenShell)
- **Gateway** = Service inside the cluster container, not a separate image

Configure them independently based on your environment needs.
