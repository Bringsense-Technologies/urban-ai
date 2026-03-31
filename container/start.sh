#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

usage() {
  echo "Usage: [PROJECT_PREFIX=~/Development/MyProject] $0 [number]"
  echo "Example: PROJECT_PREFIX=~/Development/MyProject $0 10"
  echo "Fallback: if PROJECT_PREFIX is not set, uses current folder name and optional trailing number"
}

if [[ $# -gt 1 ]]; then
  usage
  exit 1
fi

require_docker

if ! docker image inspect "ai-devbox:advanced" >/dev/null 2>&1; then
  echo "Image 'ai-devbox:advanced' not found. Building it now..."

  if [[ ! -f "${REPO_ROOT}/docker-compose.yml" ]]; then
    echo "Error: cannot auto-build because docker-compose.yml was not found at '${REPO_ROOT}'." >&2
    echo "Build manually from your project root: docker compose build advanced" >&2
    exit 1
  fi

  require_docker_compose

  docker compose -f "${REPO_ROOT}/docker-compose.yml" build advanced

  if ! docker image inspect "ai-devbox:advanced" >/dev/null 2>&1; then
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

default_build_jobs="$(resolve_default_build_jobs)"

# Allow overrides while defaulting to one less than total host cores for desktop responsiveness.
cmake_parallel_level="${CMAKE_BUILD_PARALLEL_LEVEL:-${default_build_jobs}}"
ai_devbox_build_jobs="${AI_DEVBOX_BUILD_JOBS:-${default_build_jobs}}"
ccache_maxsize="${CCACHE_MAXSIZE:-20G}"

# Flags applied to all containers: privileged for USB camera passthrough,
# full driver capabilities, ZED model volume, and X11 forwarding (harmless if not used).
extra_flags=()
extra_flags+=(--privileged)
extra_flags+=(-e "NVIDIA_DRIVER_CAPABILITIES=compute,video,utility,graphics")
extra_flags+=(-v "${COMPOSE_PROJECT_NAME:-ai-devbox}-zed-resources:/usr/local/zed/resources")
extra_flags+=(-e "DISPLAY=${DISPLAY:-:0}")
extra_flags+=(-v "/tmp/.X11-unix:/tmp/.X11-unix")

docker run -d \
  --name "$container_name" \
  --restart unless-stopped \
  --gpus all \
  --cap-add SYS_PTRACE \
  --security-opt seccomp:unconfined \
  "${extra_flags[@]+"${extra_flags[@]}"}"\
  -e CMAKE_BUILD_PARALLEL_LEVEL="$cmake_parallel_level" \
  -e AI_DEVBOX_BUILD_JOBS="$ai_devbox_build_jobs" \
  -e CCACHE_MAXSIZE="$ccache_maxsize" \
  -e NVIDIA_VISIBLE_DEVICES=all \
  -e CONTAINER_NAME="$container_name" \
  -v "$project_path:/root/project" \
  -v "${COMPOSE_PROJECT_NAME:-ai-devbox}-ccache:/root/.ccache" \
  "ai-devbox:advanced"

echo "Started container: $container_name (image: ai-devbox:advanced)"
echo "Host path mapped to /root/project: $project_path"
echo "Default build jobs in container: CMAKE_BUILD_PARALLEL_LEVEL=${cmake_parallel_level}, AI_DEVBOX_BUILD_JOBS=${ai_devbox_build_jobs}"
echo "ccache max size in container: CCACHE_MAXSIZE=${ccache_maxsize}"