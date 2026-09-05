#!/bin/bash
set -euo pipefail

BUILD_DIR="/build/work"
ROOTFS="$BUILD_DIR/rootfs"
OUT_DIR="/build/output"
SUITE="stable"

rm -rf "$BUILD_DIR" "$OUT_DIR"
mkdir -p "$ROOTFS" "$OUT_DIR"

echo "==> Bootstrapping Debian $SUITE"
debootstrap --variant=minbase "$SUITE" "$ROOTFS" http://deb.debian.org/debian

cat > "$ROOTFS/etc/apt/sources.list" <<EOF
# Vanilla Linux uses Debian repositories only.
deb http://deb.debian.org/debian $SUITE main contrib non-free-firmware
deb http://deb.debian.org/debian ${SUITE}-updates main contrib non-free-firmware
deb http://security.debian.org/debian-security ${SUITE}-security main contrib non-free-firmware
EOF

cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf"

mount --bind /dev "$ROOTFS/dev"
mount -t proc /proc "$ROOTFS/proc"
mount -t sysfs /sys "$ROOTFS/sys"
trap 'umount -lf "$ROOTFS/dev" "$ROOTFS/proc" "$ROOTFS/sys" 2>/dev/null || true' EXIT

chroot "$ROOTFS" /bin/bash <<'CHROOT'
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
    linux-image-amd64 \
    systemd-sysv \
    systemd-resolved \
    sudo \
    network-manager \
    ca-certificates \
    curl \
    wget \
    git \
    nano \
    less \
    bash-completion

printf 'Vanilla Linux\n' > /etc/hostname

apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/*
CHROOT

echo "==> Creating compressed root filesystem"
mksquashfs "$ROOTFS" "$OUT_DIR/filesystem.squashfs" -comp zstd -noappend

echo "==> Base root filesystem created"
echo "Output: $OUT_DIR/filesystem.squashfs"
