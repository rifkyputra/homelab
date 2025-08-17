#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib/common.sh"; need_root

msg "Install KVM/QEMU/Libvirt stack"
aptq install qemu-kvm libvirt-daemon-system libvirt-clients virt-manager bridge-utils ovmf spice-webdavd
systemctl enable --now libvirtd
usermod -aG kvm "${TARGET_USER}"
usermod -aG libvirt "${TARGET_USER}"
