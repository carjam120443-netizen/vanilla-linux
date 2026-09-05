# Vanilla Linux live image

This directory contains the boot-time layout used by the Vanilla Linux ISO.

Expected generated ISO layout:

```text
/boot/grub/grub.cfg
/live/vmlinuz
/live/initrd.img
/live/filesystem.squashfs
```

The ISO boots the Debian-based live filesystem with the Linux kernel and initramfs stored under `/live`.
