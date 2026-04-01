#!/usr/bin/env bash
# Shared helpers for AI DevBox container scripts.
# Source this file; do not execute it directly.
#
# After sourcing, the following are available:
#   CONTAINER_DIR         – absolute path to the container/ directory
#   REPO_ROOT             – absolute path to the repository root
#   require_docker        – validates docker CLI, compose plugin, and daemon
#   require_docker_compose – validates docker CLI, compose plugin, and daemon
#   require_gpu_support   – validates docker CLI supports GPU flags
#   resolve_host_cores    – prints detected host CPU core count
#   resolve_default_build_jobs – prints max(cores - 1, 1)
#   compose_service_usage – prints standard service-selection usage

CONTAINER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${CONTAINER_DIR}/.." && pwd)"
export REPO_ROOT

require_docker_cli() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "Error: docker CLI not found in PATH" >&2
    exit 1
  fi
}

require_docker_daemon() {
  if ! docker info >/dev/null 2>&1; then
    echo "Error: cannot reach Docker daemon. Is Docker running and is your user in the docker group?" >&2
    exit 1
  fi
}

require_docker_compose() {
  require_docker_cli
  if ! docker compose version >/dev/null 2>&1; then
    echo "Error: Docker Compose plugin is not available." >&2
    exit 1
  fi
  require_docker_daemon
}

require_gpu_support() {
  require_docker_cli
  if ! docker run --help 2>/dev/null | grep -q -- '--gpus'; then
    echo "Error: docker CLI does not support --gpus. Install/update NVIDIA Container Toolkit and Docker." >&2
    exit 1
  fi
}

require_docker() {
  require_docker_compose
  require_gpu_support
}

resolve_host_cores() {
  local cores

  cores="$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || echo 1)"
  if [[ ! "${cores}" =~ ^[0-9]+$ || "${cores}" -lt 1 ]]; then
    cores=1
  fi

  printf '%s\n' "${cores}"
}

resolve_default_build_jobs() {
  local cores jobs

  cores="$(resolve_host_cores)"
  jobs=$((cores - 1))
  if [[ "${jobs}" -lt 1 ]]; then
    jobs=1
  fi

  printf '%s\n' "${jobs}"
}

compose_service_usage() {
  local script="${1:-$0}"
  echo "Usage: ${script} [compose-service]"
  echo "Example: ${script} advanced"
  echo "If no service is provided, 'advanced' is going to be used."
}
