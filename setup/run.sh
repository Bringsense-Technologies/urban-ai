#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_DIR="${ROOT_DIR}"

if [[ ! -d "${SETUP_DIR}" ]]; then
  echo "Setup directory not found: ${SETUP_DIR}" >&2
  exit 1
fi

mapfile -t steps < <(find "${SETUP_DIR}" -maxdepth 1 -type f -name '[0-9][0-9]_*.sh' | sort)

if [[ ${#steps[@]} -eq 0 ]]; then
  echo "No numbered setup scripts found in ${SETUP_DIR}" >&2
  exit 1
fi

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
