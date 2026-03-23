#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./setup/run.sh [--dry-run]

Options:
  --dry-run   Print the ordered setup plan without executing scripts.
EOF
}

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
  shift
fi

if [[ $# -gt 0 ]]; then
  usage >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_DIR="${ROOT_DIR}"

if [[ ! -d "${SETUP_DIR}" ]]; then
  echo "Setup directory not found: ${SETUP_DIR}" >&2
  exit 1
fi

mapfile -t discovered_steps < <(find "${SETUP_DIR}" -maxdepth 1 -type f -name '[0-9][0-9]_*.sh' | LC_ALL=C sort)

if [[ ${#discovered_steps[@]} -eq 0 ]]; then
  echo "No numbered setup scripts found in ${SETUP_DIR}" >&2
  exit 1
fi

# Numeric prefixes define execution sequence.
steps=("${discovered_steps[@]}")

echo "Running AI DevBox setup steps:"
for step in "${steps[@]}"; do
  echo "- $(basename "${step}")"
done

if [[ ${DRY_RUN} -eq 1 ]]; then
  echo
  echo "Dry run mode enabled; no setup scripts were executed."
  exit 0
fi

echo
current_step=""
trap 'exit_code=$?; if [[ ${exit_code} -ne 0 && -n "${current_step}" ]]; then echo "[SETUP] Failed while running $(basename "${current_step}") (exit code ${exit_code})" >&2; fi' EXIT
for step in "${steps[@]}"; do
  current_step="${step}"
  echo "========================================"
  echo "[SETUP] Running $(basename "${step}")"
  echo "========================================"
  bash "${step}"
  echo

done

trap - EXIT

echo "All setup steps completed."
echo "If NVIDIA drivers were installed/updated, reboot before launching containers."
