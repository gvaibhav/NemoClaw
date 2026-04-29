#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Load environment variables from .env file if it exists.
# This script is sourced by install.sh and other scripts to support
# user customizations via .env configuration.

# Determine the repository root
if [[ -n "${NEMOCLAW_REPO_ROOT:-}" ]]; then
  REPO_ROOT="$NEMOCLAW_REPO_ROOT"
elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
  REPO_ROOT="$(pwd)"
fi

# Look for .env in repository root
ENV_FILE="${REPO_ROOT}/.env"

# Also check user's home directory for global config
GLOBAL_ENV_FILE="${HOME}/.nemoclaw/.env"

# Function to safely load environment file
load_env_file() {
  local env_file="$1"
  local label="${2:-environment file}"

  if [[ ! -f "$env_file" ]]; then
    return 0
  fi

  # Validate that file doesn't contain suspicious patterns
  if grep -qE '`|\$\(|;[[:space:]]*rm|;[[:space:]]*sudo' "$env_file" 2>/dev/null; then
    printf "[WARN] %s contains suspicious patterns - skipping for security\n" "$label" >&2
    return 1
  fi

  # Load variables from .env file (only KEY=VALUE lines, ignore comments and blanks)
  # Export variables that aren't already set in the environment
  while IFS='=' read -r key value; do
    # Skip comments and empty lines
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue

    # Remove leading/trailing whitespace
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    # Skip if key is invalid
    [[ ! "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]] && continue

    # Remove quotes from value if present
    if [[ "$value" =~ ^\".*\"$ ]] || [[ "$value" =~ ^\'.*\'$ ]]; then
      value="${value:1:-1}"
    fi

    # Only set if not already defined in environment
    if [[ -z "${!key:-}" ]]; then
      export "${key}=${value}"
    fi
  done < <(grep -E '^[A-Z_][A-Z0-9_]*=' "$env_file" 2>/dev/null || true)
}

# Load global config first (lower priority)
if [[ -f "$GLOBAL_ENV_FILE" ]]; then
  load_env_file "$GLOBAL_ENV_FILE" "global config (~/.nemoclaw/.env)"
fi

# Load project-specific config (higher priority)
if [[ -f "$ENV_FILE" ]]; then
  load_env_file "$ENV_FILE" "project config (.env)"
fi
