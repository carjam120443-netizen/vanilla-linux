FROM debian:stable-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    debootstrap \
    live-build \
    xorriso \
    squashfs-tools \
    grub-pc-bin \
    grub-efi-amd64-bin \
    grub2-common \
    mtools \
    dosfstools \
    ca-certificates \
    git \
    rsync \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

COPY scripts/ /build/scripts/
RUN chmod +x /build/scripts/*.sh

ENTRYPOINT ["/build/scripts/build-iso.sh"]
