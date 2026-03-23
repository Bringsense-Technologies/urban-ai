#!/usr/bin/env bash
set -euo pipefail

# Refresh only Ubuntu default sources first (ignores broken third-party lists)
sudo apt-get update \
	-o Dir::Etc::sourcelist="sources.list" \
	-o Dir::Etc::sourceparts="-" \
	-o APT::Get::List-Cleanup="0"
sudo apt install -y nvidia-driver-590-open nvidia-utils-590
# REBOOT NOW
# sudo reboot

