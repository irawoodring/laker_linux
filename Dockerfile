# Everything needed to build and boot LakerLinux, so students only need Docker.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential bc bison flex libelf-dev libssl-dev cpio kmod \
        curl ca-certificates xz-utils bzip2 python3 \
        e2fsprogs dosfstools mtools fdisk fakeroot \
        qemu-system-x86 ovmf \
        git patch vim nano less \
        rsync gawk \
    && if [ "$(dpkg --print-architecture)" != amd64 ]; then \
        apt-get install -y --no-install-recommends \
            gcc-x86-64-linux-gnu g++-x86-64-linux-gnu libc6-dev-amd64-cross; \
    fi \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /lakerlinux
