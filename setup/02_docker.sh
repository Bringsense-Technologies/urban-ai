#!/usr/bin/env bash
set -euo pipefail

source /etc/os-release

resolve_docker_codename() {
  local codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"

  if [[ -z "${codename}" ]]; then
    case "${VERSION_ID:-}" in
      24|24.*) codename="noble" ;;
      22|22.*) codename="jammy" ;;
      *) codename="" ;;
    esac
  fi

  if [[ -z "${codename}" ]]; then
    echo "Could not determine Ubuntu codename. Set UBUNTU_CODENAME or VERSION_CODENAME in /etc/os-release." >&2
    exit 1
  fi

  if ! curl -fsSL "https://download.docker.com/linux/ubuntu/dists/${codename}/Release" >/dev/null; then
    case "${VERSION_ID:-}" in
      24|24.*) codename="noble" ;;
      22|22.*) codename="jammy" ;;
      *)
        echo "Docker apt repository does not support codename '${codename}'." >&2
        exit 1
        ;;
    esac
  fi

  echo "${codename}"
}

# Refresh only Ubuntu default sources first (ignores broken third-party lists).
sudo apt-get update \
  -o Dir::Etc::sourcelist="sources.list" \
  -o Dir::Etc::sourceparts="-" \
  -o APT::Get::List-Cleanup="0"

# Add Docker's official GPG key:
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
DOCKER_CODENAME="$(resolve_docker_codename)"
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  ${DOCKER_CODENAME} stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add your user to the docker group (so you don't need 'sudo docker')
target_user="${SUDO_USER:-${USER}}"
sudo usermod -aG docker "${target_user}"
echo "Docker group updated for user '${target_user}'."
echo "Log out and back in (or reboot) before running docker without sudo."
