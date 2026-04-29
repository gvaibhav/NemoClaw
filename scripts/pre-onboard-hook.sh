#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Pre-onboard hook: Apply image registry overrides before onboarding starts.
# This ensures custom image configurations are in place before NemoClaw
# attempts to create the sandbox.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Apply image overrides if configured
if [[ -f "${SCRIPT_DIR}/apply-image-overrides.sh" ]]; then
  "${SCRIPT_DIR}/apply-image-overrides.sh"
fi
