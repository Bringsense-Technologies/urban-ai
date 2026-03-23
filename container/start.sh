#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: PROJECT_PREFIX=~/Development/MyProject $0 [number]"
  echo "Example: PROJECT_PREFIX=~/Development/MyProject $0 10"
  echo "Fallback: if PROJECT_PREFIX is not set, uses current folder name and optional trailing number"
}

if [[ $# -gt 1 ]]; then
  usage
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker CLI not found in PATH" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if ! docker info >/dev/null 2>&1; then
  echo "Error: cannot reach Docker daemon. Is Docker running and is your user in the docker group?" >&2
  exit 1
fi

if ! docker run --help 2>/dev/null | grep -q -- '--gpus'; then
  echo "Error: docker CLI does not support --gpus. Install/update NVIDIA Container Toolkit and Docker." >&2
  exit 1
fi

if ! docker image inspect ai-devbox:advanced >/dev/null 2>&1; then
  echo "Image 'ai-devbox:advanced' not found. Building it now..."

  if [[ ! -f "${REPO_ROOT}/docker-compose.yml" ]]; then
    echo "Error: cannot auto-build because docker-compose.yml was not found at '${REPO_ROOT}'." >&2
    echo "Build manually from your project root: docker compose build advanced" >&2
    exit 1
  fi

  if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
    echo "Error: Docker Compose plugin is not available." >&2
    echo "Install it, then build manually: docker compose build advanced" >&2
    exit 1
  fi

  docker compose -f "${REPO_ROOT}/docker-compose.yml" build advanced

  if ! docker image inspect ai-devbox:advanced >/dev/null 2>&1; then
    echo "Error: build finished but image 'ai-devbox:advanced' is still missing." >&2
    exit 1
  fi
fi

if [[ -n "${PROJECT_PREFIX:-}" ]]; then
  number="${1:-1}"
  if [[ ! "$number" =~ ^[0-9]+$ ]]; then
    echo "Error: [number] must be numeric (got: $number)" >&2
    exit 1
  fi

  prefix_expanded="${PROJECT_PREFIX/#\~/$HOME}"
  project_path="${prefix_expanded}${number}"
  project_name_base="$(basename "$prefix_expanded")"
  container_name="${project_name_base}${number}"
  echo "Mode: PROJECT_PREFIX"
  echo "PROJECT_PREFIX expanded: $prefix_expanded"
else
  if [[ $# -eq 1 && ! "$1" =~ ^[0-9]+$ ]]; then
    echo "Error: [number] must be numeric (got: $1)" >&2
    exit 1
  fi

  current_path="$PWD"
  current_name="$(basename "$current_path")"

  if [[ "$current_name" =~ ^(.*[^0-9])([0-9]+)$ ]]; then
    project_name_base="${BASH_REMATCH[1]}"
    detected_number="${BASH_REMATCH[2]}"
  else
    project_name_base="$current_name"
    detected_number="1"
  fi

  number="${1:-$detected_number}"
  project_path="$current_path"
  container_name="${project_name_base}${number}"

  echo "Mode: current-directory fallback"
  echo "PROJECT_PREFIX is not set; using current path: $project_path"
fi

echo "Resolved container name: $container_name"
echo "Resolved host project path: $project_path"

mkdir -p "$project_path"

if docker ps -a --format '{{.Names}}' | grep -Fxq "$container_name"; then
  echo "Error: container '$container_name' already exists" >&2
  echo "Remove it first (e.g. docker rm -f $container_name) or use another number." >&2
  exit 1
fi

docker run -d \
  --name "$container_name" \
  --restart unless-stopped \
  --gpus all \
  -e NVIDIA_VISIBLE_DEVICES=all \
  -v "$project_path:/root/project" \
  -v ai-devbox-ccache:/root/.ccache \
  ai-devbox:advanced

echo "Started container: $container_name"
echo "Host path mapped to /root/project: $project_path"