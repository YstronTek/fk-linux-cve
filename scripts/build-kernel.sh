#!/usr/bin/env bash
# Build .deb and .rpm binary packages for one kernel.org release.
#
# Usage: build-kernel.sh <version> <source-url> <out-dir>
#
# Config: Fedora rawhide's x86_64 kernel config ($BASE_CONFIG_URL) +
# configs/fragment.config; symbols missing from the base get defaults.
# Writes *.deb, *.rpm, config-<kernelrelease> and SHA256SUMS to <out-dir>.
# Scratch tree: $WORK_DIR (default $RUNNER_TEMP/kernel-build or /tmp/...).
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 <version> <source-url> <out-dir>" >&2
  exit 2
fi
version=$1
source_url=$2
out_dir=$(realpath -m "$3")
repo_dir=$(realpath "$(dirname "$0")/..")
work_dir=${WORK_DIR:-${RUNNER_TEMP:-/tmp}/kernel-build}
src_dir=$work_dir/linux
base_config_url=${BASE_CONFIG_URL:-https://src.fedoraproject.org/rpms/kernel/raw/rawhide/f/kernel-x86_64-fedora.config}

rm -rf "$work_dir" "$HOME/rpmbuild"
mkdir -p "$src_dir" "$out_dir"

echo "Downloading linux $version from $source_url"
tarball=$work_dir/${source_url##*/}
curl -fL --retry 3 -o "$tarball" "$source_url"
tar -xf "$tarball" -C "$src_dir" --strip-components=1
rm -f "$tarball"
cd "$src_dir"

echo "Configuring from $base_config_url"
curl -fsSL --retry 3 -o .config "$base_config_url"
scripts/kconfig/merge_config.sh -m .config "$repo_dir/configs/fragment.config"
make olddefconfig
krelease=$(make -s kernelrelease)

jobs=$(nproc)
# Debian packages land in the parent directory ($work_dir).
make -j"$jobs" bindeb-pkg
# --nodeps: the RPM database on Debian is empty, so BuildRequires never match.
# --build-in-place --buildroot: rpm >= 4.20 runs %install in a per-package
# subdirectory; older kernel specs (e.g. 5.10) use paths relative to srctree.
make -j"$jobs" binrpm-pkg \
  RPMOPTS="--nodeps --build-in-place --buildroot=$work_dir/rpmroot"

cp "$work_dir"/*.deb "$out_dir"/
# RPM output dir: <srctree>/rpmbuild since 6.x, ~/rpmbuild on older trees.
for rpm_dir in "$src_dir/rpmbuild/RPMS" "$HOME/rpmbuild/RPMS"; do
  if [[ -d $rpm_dir ]]; then
    find "$rpm_dir" -name '*.rpm' -exec cp -t "$out_dir" {} +
  fi
done
cp .config "$out_dir/config-$krelease"

cd "$out_dir"
compgen -G '*.deb' >/dev/null || { echo "no .deb produced" >&2; exit 1; }
compgen -G '*.rpm' >/dev/null || { echo "no .rpm produced" >&2; exit 1; }
sha256sum -- *.deb *.rpm "config-$krelease" >SHA256SUMS
cat SHA256SUMS
