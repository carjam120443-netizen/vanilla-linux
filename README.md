# 🍦 Vanilla Linux

> **Debian, but vanilla — a Swiss Army knife for devs and normal users.** 🛠️🍦

Vanilla Linux is a lightweight, clean **Debian-based Linux distribution** built around the idea of keeping the base simple, familiar, and free from unnecessary layers — while somehow collecting a holy package list capable of doing a little bit of everything. 😂

The name is a little joke — because Linux Mint exists, so obviously we needed the **ice-cream-flavored Debian distro**. 🍦🐧

## ✨ What is Vanilla Linux?

Vanilla Linux aims to provide a straightforward Debian experience with:

- 🐧 **Debian Stable** as the base
- 📦 **APT + DPKG** for package management
- 🚫 **No Ubuntu repositories by default**
- 🧼 A clean, minimal starting point
- 🛠️ A growing toolbox for **developers and normal desktop users alike**
- 💿 A bootable live ISO
- 🛠️ Automated ISO builds through GitHub Actions
- 🐳 Reproducible builds using Docker
- 🔧 A project structure designed to be easy to modify

Basically: **a Swiss Army knife for devs, sysadmins, tinkerers, and regular users who just want their computer to do useful shit.** 😭🔧

## 💿 Building the ISO

The repository includes a Docker-based ISO builder. The GitHub Actions workflow automatically builds the live ISO when changes are pushed.

### Build locally

Requirements:

- Linux or a Linux-capable environment
- Docker
- Git

Then run:

```bash
git clone https://github.com/carjam120443-netizen/vanilla-linux.git
cd vanilla-linux
docker build -t vanilla-linux-builder .
mkdir -p output
docker run --privileged --rm \
  -v "$PWD/output:/build/output" \
  vanilla-linux-builder
```

The finished ISO will be placed at:

```text
output/vanilla-linux-live.iso
```

## 🤖 Automated Builds

Every push to the default branch can trigger the **Build Vanilla Linux ISO** GitHub Actions workflow.

The workflow:

1. Checks out the source
2. Builds the Docker image
3. Runs the ISO builder
4. Verifies that the ISO exists
5. Uploads the ISO as a GitHub Actions artifact

This means the distro can be rebuilt automatically without manually assembling an ISO every time. 🚀

## 🗂️ Project Structure

```text
vanilla-linux/
├── .github/
│   └── workflows/
│       └── build-iso.yml
├── scripts/
│   └── build-iso.sh
├── Dockerfile
├── .dockerignore
└── README.md
```

## 🧪 Current Status

**Early development / experimental** ⚠️

The goal right now is getting a reliable Debian-based live system and automated ISO pipeline working. Desktop environments, branding, installers, custom tooling, and additional polish can be added as the project develops.

Don't expect a perfectly polished daily-driver distro yet — this is where the fun begins. 😈

## 🎯 Roadmap

- [x] Debian-based root filesystem
- [x] Debian-only package sources
- [x] Live kernel and boot support
- [x] GRUB live boot menu
- [x] Docker ISO builder
- [x] GitHub Actions ISO builds
- [x] ISO artifact uploads
- [ ] Choose and integrate a desktop environment
- [ ] Add Vanilla Linux branding and artwork
- [ ] Add a graphical installer
- [ ] Improve hardware support
- [ ] Add first-boot configuration
- [ ] Produce release-ready ISO images

## 📜 Philosophy

Vanilla Linux is intentionally **boring in the best possible way**.

Use Debian as the foundation, keep the system understandable, avoid unnecessary distro-on-distro layers, and build useful features on top instead of replacing the foundation.

**No Ubuntu base. No mysterious magic. Just Linux — with a suspiciously large toolbox. 🍦🛠️**

## 📄 License

This project is currently experimental. Licensing information will be added as the project matures.
