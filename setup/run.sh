#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_DIR="${ROOT_DIR}"

if [[ ! -d "${SETUP_DIR}" ]]; then
  echo "Setup directory not found: ${SETUP_DIR}" >&2
  exit 1
fi

mapfile -t discovered_steps < <(find "${SETUP_DIR}" -maxdepth 1 -type f -name '[0-9][0-9]_*.sh' | sort)

if [[ ${#discovered_steps[@]} -eq 0 ]]; then
  echo "No numbered setup scripts found in ${SETUP_DIR}" >&2
  exit 1
fi

steps=()
declare -A seen=()

add_step_if_exists() {
  local basename="$1"
  local path="${SETUP_DIR}/${basename}"
  if [[ -f "${path}" && -z "${seen["${path}"]+x}" ]]; then
    steps+=("${path}")
    seen["${path}"]=1
  fi
}

# Dependency-aware default order:
# - drivers first
# - Docker engine before NVIDIA toolkit runtime configuration
# - editor extensions last
add_step_if_exists "01_nvidia_drivers.sh"
add_step_if_exists "02_nvidia_container_toolkit.sh"
add_step_if_exists "03_docker.sh"
add_step_if_exists "04_vscode_extensions.sh"

# Include any additional numbered scripts not covered above in lexical order.
for step in "${discovered_steps[@]}"; do
  if [[ -z "${seen["${step}"]+x}" ]]; then
    steps+=("${step}")
    seen["${step}"]=1
  fi
done

echo "Running AI DevBox setup steps:"
for step in "${steps[@]}"; do
  echo "- $(basename "${step}")"
done

echo
for step in "${steps[@]}"; do
  echo "========================================"
  echo "[SETUP] Running $(basename "${step}")"
  echo "========================================"
  bash "${step}"
  echo

done

echo "All setup steps completed."
echo "If NVIDIA drivers were installed/updated, reboot before launching containers."
