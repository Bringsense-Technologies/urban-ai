#!/usr/bin/env bash
set -u -o pipefail

extensions=(
  "ms-azuretools.vscode-containers"
  "ms-vscode-remote.remote-containers"
  "ms-vscode.cmake-tools"
  "ms-vscode.cpptools"
  "ms-vscode.cpptools-extension-pack"
  "ms-vscode.cpptools-themes"
  "qbs-community.qbs-tools"
  "xaver.clang-format"
)

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is not available on this host; skipping VS Code extension setup."
  exit 0
fi

if ! command -v code >/dev/null 2>&1; then
  echo "VS Code CLI ('code') is not available; skipping extension setup."
  echo "Install VS Code and ensure 'code' is in PATH, then rerun this script if needed."
  exit 0
fi

echo "Installing VS Code extensions for container-based C++ development..."

failed=()
for extension_id in "${extensions[@]}"; do
  if code --list-extensions | grep -Fxq "${extension_id}"; then
    echo "[SKIP] ${extension_id} already installed"
    continue
  fi

  if code --install-extension "${extension_id}" --force >/dev/null 2>&1; then
    echo "[OK] Installed ${extension_id}"
  else
    echo "[WARN] Failed to install ${extension_id}"
    failed+=("${extension_id}")
  fi
done

if [[ ${#failed[@]} -gt 0 ]]; then
  echo
  echo "Some extensions could not be installed:"
  for extension_id in "${failed[@]}"; do
    echo "- ${extension_id}"
  done
  echo "You can retry with: code --install-extension <extension-id>"
else
  echo "VS Code extension setup complete."
fi
