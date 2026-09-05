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

rm -f "$ROOTFS/etc/resolv.conf"
cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf"

mkdir -p "$ROOTFS/build/scripts" "$ROOTFS/build/assets"
cp /build/scripts/vanillafetch "$ROOTFS/build/scripts/vanillafetch"
cp /build/assets/vanilla-linux.txt "$ROOTFS/build/assets/vanilla-linux.txt"
cp /build/assets/vanilla-linux-wallpaper.svg "$ROOTFS/build/assets/vanilla-linux-wallpaper.svg"
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
    xserver-xorg xserver-xorg-video-all xinit \
    xfce4 lightdm lightdm-gtk-greeter dbus-x11 polkitd pkexec accountsservice \
    udisks2 parted dosfstools e2fsprogs ntfs-3g \
    calamares calamares-settings-debian adduser apt-offline aptitude backup-manager adb fastboot dnf subuser \
    ino-headers cjs 9menu abbtr acl 7zip 2ping shelltestrunner supercat window-size \
    dvi2ps-fontdata-a2n dvi2ps-fontdata-ja dvi2ps-fontdata-n2a \
    dvi2ps-fontdata-ptexfake dvi2ps-fontdata-rsp \
    dvi2ps-fontdata-tbank dvi2ps-fontdata-three

if ! id -u vanilla >/dev/null 2>&1; then
    adduser --disabled-password --gecos "Vanilla Linux Live User" vanilla
fi
usermod -aG sudo,video,audio,netdev,plugdev vanilla

mkdir -p /home/vanilla/.config
chown -R vanilla:vanilla /home/vanilla
printf 'startxfce4\n' > /home/vanilla/.xinitrc
chown vanilla:vanilla /home/vanilla/.xinitrc
chmod 644 /home/vanilla/.xinitrc

mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/50-vanilla-autologin.conf <<'LIGHTDM'
[Seat:*]
autologin-user=vanilla
autologin-user-timeout=0
autologin-session=xfce
user-session=xfce
greeter-session=lightdm-gtk-greeter
LIGHTDM

ln -sf /lib/systemd/system/lightdm.service /etc/systemd/system/display-manager.service
systemctl enable lightdm || true
systemctl set-default graphical.target || true

printf 'Vanilla Linux\n' > /etc/hostname
printf 'Vanilla Linux\n' > /etc/issue

# Brand Calamares as Vanilla Linux instead of the Debian installer.
if [[ -f /etc/calamares/settings.conf ]]; then
    sed -i 's/^branding: debian$/branding: vanilla/' /etc/calamares/settings.conf
fi
mkdir -p /etc/calamares/branding/vanilla
if [[ -d /etc/calamares/branding/debian ]]; then
    cp -a /etc/calamares/branding/debian/. /etc/calamares/branding/vanilla/
fi
cat > /etc/calamares/branding/vanilla/branding.desc <<'BRANDING'
---
componentName: vanilla
welcomeStyleCalamares: false
welcomeExpandingLogo: true
windowExpanding: normal
windowSize: 800px,580px
windowPlacement: center

strings:
 productName: Vanilla Linux
 shortProductName: Vanilla
 version: 1.0
 shortVersion: 1.0
 versionedName: Vanilla Linux 1.0
 shortVersionedName: Vanilla Linux 1.0
 bootloaderEntryName: Vanilla Linux
 productUrl: https://github.com/carjam120443-netizen/vanilla-linux
 supportUrl: https://github.com/carjam120443-netizen/vanilla-linux/issues
 knownIssuesUrl: https://github.com/carjam120443-netizen/vanilla-linux/issues
 releaseNotesUrl: https://github.com/carjam120443-netizen/vanilla-linux
 donateUrl:

sidebar: widget
navigation: widget

images:
 productLogo: "debian-logo.png"
 productIcon: "debian-logo.png"
 productWelcome: "welcome.png"
BRANDING

install -Dm755 /build/scripts/vanillafetch /usr/bin/vanillafetch
install -Dm644 /build/assets/vanilla-linux.txt /usr/share/vanillafetch/vanilla-linux.txt

# Install the generated Vanilla Linux wallpaper.
install -Dm644 /build/assets/vanilla-linux-wallpaper.svg /usr/share/backgrounds/vanilla-linux/vanilla-linux-wallpaper.svg

# Make sure the installer has access to disks through udisks2.
systemctl enable udisks2.service || true

# Launch Calamares through PolicyKit so the graphical installer can obtain root privileges.
mkdir -p /usr/share/polkit-1/actions
cat > /usr/share/polkit-1/actions/org.vanillalinux.calamares.policy <<'POLKIT'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN" "http://www.freedesktop.org/standards/PolicyKit/1.0/policyconfig.dtd">
<policyconfig>
  <action id="org.vanillalinux.calamares">
    <description>Install Vanilla Linux</description>
    <message>Authentication is required to install Vanilla Linux.</message>
    <defaults>
      <allow_any>auth_admin_keep</allow_any>
      <allow_inactive>auth_admin_keep</allow_inactive>
      <allow_active>auth_admin_keep</allow_active>
    </defaults>
  </action>
</policyconfig>
POLKIT

# Desktop shortcut explicitly starts Calamares with root privileges.
mkdir -p /etc/skel/Desktop
cat > /etc/skel/Desktop/install-vanilla-linux.desktop <<'DESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=Install Vanilla Linux
Comment=Install Vanilla Linux to your computer
Exec=pkexec calamares
Icon=calamares
Terminal=false
Categories=System;Settings;
StartupNotify=true
DESKTOP
chmod 644 /etc/skel/Desktop/install-vanilla-linux.desktop

mkdir -p /home/vanilla/Desktop
cp /etc/skel/Desktop/install-vanilla-linux.desktop /home/vanilla/Desktop/install-vanilla-linux.desktop
chmod 644 /home/vanilla/Desktop/install-vanilla-linux.desktop

# Configure the live user's XFCE wallpaper.
mkdir -p /home/vanilla/.config/xfce4/xfconf/xfce-perchannel-xml
cat > /home/vanilla/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml <<'XFCE'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="last-image" type="string" value="/usr/share/backgrounds/vanilla-linux/vanilla-linux-wallpaper.svg"/>
          <property name="image-style" type="int" value="5"/>
        </property>
      </property>
    </property>
  </property>
</channel>
XFCE
chown -R vanilla:vanilla /home/vanilla/.config
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
