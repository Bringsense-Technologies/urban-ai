#!/usr/bin/env bash
set -euo pipefail

disable_invalid_docker_repo() {
  local docker_list="/etc/apt/sources.list.d/docker.list"

  if [[ ! -f "${docker_list}" ]]; then
    return
  fi

  if grep -Eq '^deb .*download\.docker\.com/linux/ubuntu ' "${docker_list}" \
    && ! grep -Eq '^deb .*download\.docker\.com/linux/ubuntu (noble|jammy|focal|bionic) ' "${docker_list}"; then
    local backup="${docker_list}.disabled.$(date +%Y%m%d%H%M%S)"
    echo "Disabling invalid Docker apt source in ${docker_list} (backup: ${backup})"
    sudo mv "${docker_list}" "${backup}"
  fi
}

disable_invalid_docker_repo

curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# Configure Docker to use NVIDIA runtime
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

docker run --rm --gpus all ubuntu:22.04 nvidia-smi

