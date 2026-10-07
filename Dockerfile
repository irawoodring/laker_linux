# Everything needed to build and boot LakerLinux, so students only need Docker.
# ./laker always runs this as an x86_64 (linux/amd64) container, because the
# LFS build runs the new system's own programs inside a chroot. On Apple
# Silicon, Docker Desktop emulates x86_64 for it.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# The Linux From Scratch "host system requirements" (book section 2.2), plus
# the kernel build, disk image and QEMU tools LakerLinux itself uses.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential bison gawk m4 texinfo python3 perl patch xz-utils \
        bc flex libelf-dev libssl-dev cpio kmod rsync \
        curl ca-certificates bzip2 \
        e2fsprogs dosfstools mtools fdisk fakeroot \
        qemu-system-x86 ovmf \
        git vim nano less \
    && rm -rf /var/lib/apt/lists/* \
    # LFS expects /bin/sh to be bash.
    && ln -sf bash /bin/sh

WORKDIR /lakerlinux
