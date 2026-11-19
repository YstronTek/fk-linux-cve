#!/usr/bin/env bash
# Install kernel build + packaging dependencies on Debian (run as root).
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update --error-on=any
apt-get install -y --no-install-recommends \
  bc bison build-essential ca-certificates cpio curl debhelper dpkg-dev \
  fakeroot flex gh jq kmod libdw-dev libelf-dev libssl-dev openssl python3 rpm \
  rsync xz-utils zstd
