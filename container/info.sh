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

build_info_file="/etc/ai-devbox-release"
container_name="${CONTAINER_NAME:-}"
if [[ -z "${container_name}" ]]; then
  container_name="$(cat /etc/hostname 2>/dev/null || true)"
fi

image_name="${CONTAINER_IMAGE_NAME:-${IMAGE_NAME:-unknown}}"
base_image="unknown"
gcc_version="unknown"
cmake_version="unknown"
torch_url="unknown"
torch_version="unknown"
opencv_version="unknown"
eigen_version="unknown"
ccache_maxsize="${CCACHE_MAXSIZE:-unknown}"
zed_version="unknown"
zed_gl="unknown"

if [[ -f "${build_info_file}" ]]; then
  while IFS='=' read -r key value; do
    case "${key}" in
      AI_DEVBOX_BASE_IMAGE) base_image="${value}" ;;
      AI_DEVBOX_GCC_VERSION) gcc_version="${value}" ;;
      AI_DEVBOX_CMAKE_VERSION) cmake_version="${value}" ;;
      AI_DEVBOX_TORCH_URL) torch_url="${value}" ;;
      AI_DEVBOX_TORCH_VERSION) torch_version="${value}" ;;
      AI_DEVBOX_OPENCV_VERSION) opencv_version="${value}" ;;
      AI_DEVBOX_EIGEN_VERSION) eigen_version="${value}" ;;
      AI_DEVBOX_ZED_VERSION) zed_version="${value}" ;;
      AI_DEVBOX_ZED_GL) zed_gl="${value}" ;;
      AI_DEVBOX_CCACHE_MAXSIZE)
        if [[ -z "${CCACHE_MAXSIZE:-}" ]]; then
          ccache_maxsize="${value}"
        fi
        ;;
    esac
  done < "${build_info_file}"
fi

echo "Inside container: yes"
echo "Container name: ${container_name:-unknown}"
echo "Image name: ${image_name}"
echo "Base image: ${base_image}"
echo "GCC version: ${gcc_version}"
echo "CMake version: ${cmake_version}"
echo "LibTorch version: ${torch_version}"
echo "LibTorch URL: ${torch_url}"
echo "OpenCV version: ${opencv_version}"
echo "Eigen version: ${eigen_version}"
echo "ZED SDK version: ${zed_version}"
echo "ZED GL: ${zed_gl}"
echo "ccache max size: ${ccache_maxsize}"
