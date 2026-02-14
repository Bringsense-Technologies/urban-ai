#!/usr/bin/env bash
set -euo pipefail

is_in_container() {
  [[ -f /.dockerenv ]] && return 0
  grep -qaE 'docker|containerd|kubepods|podman' /proc/1/cgroup 2>/dev/null && return 0
  return 1
}

if ! is_in_container; then
  echo "Not running inside a container."
  exit 0
fi

container_name="${CONTAINER_NAME:-}"
if [[ -z "${container_name}" ]]; then
  container_name="$(cat /etc/hostname 2>/dev/null || true)"
fi

image_name="${CONTAINER_IMAGE_NAME:-${IMAGE_NAME:-unknown}}"
image_sha="${CONTAINER_IMAGE_SHA:-${IMAGE_SHA:-unknown}}"

echo "Inside container: yes"
echo "Container name: ${container_name:-unknown}"
echo "Image name: ${image_name}"
echo "Image SHA:  ${image_sha}"
