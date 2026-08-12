#!/usr/bin/env bash
# Populate the platform npm packages from pryx release tarballs.
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <release-assets-directory>" >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
assets="$(cd "$1" && pwd)"

prepare() {
  local package="$1" archive="$2" archived_binary="$3" installed_binary="$4"
  local package_dir="$repo_root/sdk/npm/$package"
  rm -rf "$package_dir/bin"
  mkdir -p "$package_dir/bin"
  tar -xzf "$assets/$archive" -C "$package_dir/bin"
  mv "$package_dir/bin/$archived_binary" "$package_dir/bin/$installed_binary"
  chmod +x "$package_dir/bin/$installed_binary"
}

prepare linux-x64 pryx-linux-x86_64.tar.gz pryx-linux-x86_64 pryx
prepare linux-arm64 pryx-linux-aarch64.tar.gz pryx-linux-aarch64 pryx
prepare darwin-x64 pryx-macos-x86_64.tar.gz pryx-macos-x86_64 pryx
prepare darwin-arm64 pryx-macos-aarch64.tar.gz pryx-macos-aarch64 pryx
prepare win32-x64 pryx-windows-x86_64.tar.gz pryx-windows-x86_64.exe pryx.exe
prepare win32-arm64 pryx-windows-aarch64.tar.gz pryx-windows-aarch64.exe pryx.exe
