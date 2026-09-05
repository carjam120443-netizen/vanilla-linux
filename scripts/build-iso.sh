#!/bin/bash
set -euo pipefail

BUILD_DIR="/build/work"
ROOTFS="$BUILD_DIR/rootfs"
ISO_DIR="$BUILD_DIR/iso"
OUT_DIR="/build/output"
SUITE="stable"

# /build/output is a host-mounted Docker volume in CI, so never rm -rf it.
rm -rf "$BUILD_DIR"
mkdir -p "$ROOTFS" "$ISO_DIR/live" "$ISO_DIR/boot/grub" "$OUT_DIR"

echo "==> Bootstrapping Debian $SUITE"
debootstrap --variant=minbase "$SUITE" "$ROOTFS" http://deb.debian.org/debian

cat > "$ROOTFS/etc/apt/sources.list" <<EOF
# Vanilla Linux uses Debian repositories only.
deb http://deb.debian.org/debian $SUITE main contrib non-free-firmware
deb http://deb.debian.org/debian ${SUITE}-updates main contrib non-free-firmware
deb http://security.debian.org/debian-security ${SUITE}-security main contrib non-free-firmware
EOF

# debootstrap/systemd may leave resolv.conf as a symlink; replace it with a usable copy.
rm -f "$ROOTFS/etc/resolv.conf"
cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf"

# Files copied into the Docker builder are outside the chroot. Copy the fetch
# utility and its logo into the rootfs so the chroot can install them.
mkdir -p "$ROOTFS/build/scripts" "$ROOTFS/build/assets"
cp /build/scripts/vanillafetch "$ROOTFS/build/scripts/vanillafetch"
cp /build/assets/vanilla-linux.txt "$ROOTFS/build/assets/vanilla-linux.txt"
chmod 755 "$ROOTFS/build/scripts/vanillafetch"

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
    sudo network-manager ca-certificates curl wget git nano less bash-completion \
    xfce4 lightdm calamares calamares-settings-debian adduser apt-offline aptitude backup-manager adb fastboot dnf subuser \
    ino-headers cjs 9menu abbtr acl 7zip 2ping shelltestrunner supercat window-size \
    dvi2ps-fontdata-a2n dvi2ps-fontdata-ja dvi2ps-fontdata-n2a \
    dvi2ps-fontdata-ptexfake dvi2ps-fontdata-rsp \
    dvi2ps-fontdata-tbank dvi2ps-fontdata-three

# Boot directly into a graphical XFCE session on installed/live boots.
systemctl enable lightdm || true
systemctl set-default graphical.target || true

printf 'Vanilla Linux\n' > /etc/hostname
printf 'Vanilla Linux\n' > /etc/issue

# Install Vanilla Linux fetch utility and its logo.
install -Dm755 /build/scripts/vanillafetch /usr/bin/vanillafetch
install -Dm644 /build/assets/vanilla-linux.txt /usr/share/vanillafetch/vanilla-linux.txt

# Add a clear XFCE desktop shortcut for the graphical installer.
mkdir -p /etc/skel/Desktop
cat > /etc/skel/Desktop/install-vanilla-linux.desktop <<'DESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=Install Vanilla Linux
Comment=Install Vanilla Linux to your computer
Exec=calamares
Icon=calamares
Terminal=false
Categories=System;Settings;
StartupNotify=true
DESKTOP
chmod 644 /etc/skel/Desktop/install-vanilla-linux.desktop

# Make the shortcut available to the live desktop immediately.
mkdir -p /home/vanilla/Desktop
cp /etc/skel/Desktop/install-vanilla-linux.desktop /home/vanilla/Desktop/install-vanilla-linux.desktop
chmod 644 /home/vanilla/Desktop/install-vanilla-linux.desktop
chown -R 1000:1000 /home/vanilla 2>/dev/null || true

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

# Do not include live virtual filesystems (/proc, /sys, /dev) in SquashFS.
echo "==> Unmounting virtual filesystems before SquashFS"
umount -lf "$ROOTFS/dev" 2>/dev/null || true
umount -lf "$ROOTFS/proc" 2>/dev/null || true
umount -lf "$ROOTFS/sys" 2>/dev/null || true

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
