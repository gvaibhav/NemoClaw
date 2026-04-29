#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Apply image registry overrides to blueprint.yaml based on environment variables.
# This script is automatically called during onboarding if image overrides are configured.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BLUEPRINT_FILE="${REPO_ROOT}/nemoclaw-blueprint/blueprint.yaml"

# Load environment variables
if [[ -f "${SCRIPT_DIR}/load-env.sh" ]]; then
  # shellcheck source=scripts/load-env.sh
  . "${SCRIPT_DIR}/load-env.sh"
fi

# Check if any image overrides are configured
if [[ -z "${NEMOCLAW_SANDBOX_IMAGE:-}" && -z "${NEMOCLAW_SANDBOX_IMAGE_REGISTRY:-}" && -z "${NEMOCLAW_IMAGE_REGISTRY:-}" ]]; then
  # No overrides configured, exit silently
  exit 0
fi

# Note: Cluster image registry (NEMOCLAW_CLUSTER_IMAGE_REGISTRY) is handled
# directly in src/lib/onboard.ts and doesn't require blueprint modification

if [[ ! -f "$BLUEPRINT_FILE" ]]; then
  echo "[ERROR] Blueprint file not found: $BLUEPRINT_FILE" >&2
  exit 1
fi

# Backup original blueprint
cp "$BLUEPRINT_FILE" "${BLUEPRINT_FILE}.backup"

# Apply sandbox image override
if [[ -n "${NEMOCLAW_SANDBOX_IMAGE:-}" ]]; then
  # Full image reference provided
  echo "[INFO] Applying custom sandbox image: $NEMOCLAW_SANDBOX_IMAGE"

  # Use sed to replace the image line
  if [[ "$(uname -s)" == "Darwin" ]]; then
    # macOS sed
    sed -i '' "s|image: \"ghcr.io/nvidia/openshell-community/sandboxes/openclaw@.*\"|image: \"$NEMOCLAW_SANDBOX_IMAGE\"|" "$BLUEPRINT_FILE"
  else
    # GNU sed
    sed -i "s|image: \"ghcr.io/nvidia/openshell-community/sandboxes/openclaw@.*\"|image: \"$NEMOCLAW_SANDBOX_IMAGE\"|" "$BLUEPRINT_FILE"
  fi

elif [[ -n "${NEMOCLAW_SANDBOX_IMAGE_REGISTRY:-}" ]]; then
  # Sandbox registry override provided - replace just the registry part
  echo "[INFO] Applying custom sandbox image registry: $NEMOCLAW_SANDBOX_IMAGE_REGISTRY"

  # Extract the image name and tag/digest from the original
  ORIGINAL_IMAGE=$(grep -E '^\s+image:' "$BLUEPRINT_FILE" | sed -E 's/.*"([^"]+)".*/\1/')
  IMAGE_SUFFIX=$(echo "$ORIGINAL_IMAGE" | sed -E 's|^[^/]+/[^/]+/[^/]+/(.*)|\1|')

  NEW_IMAGE="${NEMOCLAW_SANDBOX_IMAGE_REGISTRY}/${IMAGE_SUFFIX}"

  if [[ "$(uname -s)" == "Darwin" ]]; then
    sed -i '' "s|image: \"${ORIGINAL_IMAGE}\"|image: \"${NEW_IMAGE}\"|" "$BLUEPRINT_FILE"
  else
    sed -i "s|image: \"${ORIGINAL_IMAGE}\"|image: \"${NEW_IMAGE}\"|" "$BLUEPRINT_FILE"
  fi

elif [[ -n "${NEMOCLAW_IMAGE_REGISTRY:-}" ]]; then
  # Legacy: NEMOCLAW_IMAGE_REGISTRY for backward compatibility
  echo "[INFO] Applying custom image registry (legacy): $NEMOCLAW_IMAGE_REGISTRY"
  echo "[WARN] NEMOCLAW_IMAGE_REGISTRY is deprecated, use NEMOCLAW_SANDBOX_IMAGE_REGISTRY instead"

  ORIGINAL_IMAGE=$(grep -E '^\s+image:' "$BLUEPRINT_FILE" | sed -E 's/.*"([^"]+)".*/\1/')
  IMAGE_SUFFIX=$(echo "$ORIGINAL_IMAGE" | sed -E 's|^[^/]+/[^/]+/(.*)|\1|')

  NEW_IMAGE="${NEMOCLAW_IMAGE_REGISTRY}/${IMAGE_SUFFIX}"

  if [[ "$(uname -s)" == "Darwin" ]]; then
    sed -i '' "s|image: \"${ORIGINAL_IMAGE}\"|image: \"${NEW_IMAGE}\"|" "$BLUEPRINT_FILE"
  else
    sed -i "s|image: \"${ORIGINAL_IMAGE}\"|image: \"${NEW_IMAGE}\"|" "$BLUEPRINT_FILE"
  fi
fi

# Display cluster image registry info if configured
if [[ -n "${NEMOCLAW_CLUSTER_IMAGE_REGISTRY:-}" ]]; then
  echo "[INFO] Cluster image registry will be: ${NEMOCLAW_CLUSTER_IMAGE_REGISTRY}/cluster:<version>"
  echo "[INFO] (Cluster registry is applied dynamically during onboarding)"
fi

echo "[INFO] Blueprint updated successfully"
echo "[INFO] Backup saved to: ${BLUEPRINT_FILE}.backup"
