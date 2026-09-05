#!/bin/bash
set -euo pipefail

BUILD_DIR="/build/work"
ROOTFS="$BUILD_DIR/rootfs"
ISO_DIR="$BUILD_DIR/iso"
OUT_DIR="/build/output"
SUITE="stable"

rm -rf "$BUILD_DIR" "$OUT_DIR"
mkdir -p "$ROOTFS" "$ISO_DIR/live" "$ISO_DIR/boot/grub" "$OUT_DIR"

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
    linux-image-amd64 systemd-sysv systemd-resolved live-boot \
    sudo network-manager ca-certificates curl wget git nano less bash-completion

printf 'Vanilla Linux\n' > /etc/hostname
printf 'Vanilla Linux\n' > /etc/issue
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/*
CHROOT

KERNEL=$(find "$ROOTFS/boot" -maxdepth 1 -type f -name 'vmlinuz-*' | sort | tail -n1)
INITRD=$(find "$ROOTFS/boot" -maxdepth 1 -type f -name 'initrd.img-*' | sort | tail -n1)

if [[ -z "$KERNEL" || -z "$INITRD" ]]; then
    echo "ERROR: Kernel or initramfs was not generated."
    exit 1
fi

cp "$KERNEL" "$ISO_DIR/live/vmlinuz"
cp "$INITRD" "$ISO_DIR/live/initrd.img"
mksquashfs "$ROOTFS" "$ISO_DIR/live/filesystem.squashfs" -comp zstd -noappend

cat > "$ISO_DIR/boot/grub/grub.cfg" <<'GRUB'
set timeout=5
set default=0
insmod all_video
insmod gfxterm
insmod png

menuentry "Vanilla Linux (Live)" {
    linux /live/vmlinuz boot=live quiet splash
    initrd /live/initrd.img
}

menuentry "Vanilla Linux (Live, safe graphics)" {
    linux /live/vmlinuz boot=live nomodeset
    initrd /live/initrd.img
}

menuentry "Reboot" { reboot }
menuentry "Power Off" { halt }
GRUB

echo "==> Building hybrid BIOS/UEFI ISO"
grub-mkrescue -o "$OUT_DIR/vanilla-linux-live.iso" "$ISO_DIR"
ls -lh "$OUT_DIR/vanilla-linux-live.iso"
