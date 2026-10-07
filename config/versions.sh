# Pinned upstream versions. Bump these to upgrade; the build re-downloads
# anything it doesn't already have.
KERNEL_VERSION="${KERNEL_VERSION:-6.18.44}"
KERNEL_URL="${KERNEL_URL:-https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_VERSION%%.*}.x/linux-${KERNEL_VERSION}.tar.xz}"

# Everything else comes from Linux From Scratch 12.4: the package versions
# are the book's (lfs/book/wget-list-sysv), downloaded from the LFS project's
# mirror of that release.
LFS_VERSION=12.4
LFS_MIRROR="${LFS_MIRROR:-https://ftp.osuosl.org/pub/lfs/lfs-packages/$LFS_VERSION}"

# Disk layout. The partition UUID is fixed so the kernel's built-in command
# line can always find the root filesystem (root=PARTUUID=...).
# 8 GB leaves room to build more software (Beyond LFS) inside LakerLinux. The
# image file is sparse, so its empty space doesn't use disk on your computer.
IMAGE_SIZE_MB="${IMAGE_SIZE_MB:-8192}"
ESP_SIZE_MB=64
DISK_GUID="4c414b45-5200-4c49-4e55-580000000000"
ROOT_PARTUUID="4c414b45-5200-4c49-4e55-580000000002"
ROOT_FS_UUID="4c414b45-5200-4c49-4e55-580000000003"

# The kernel's built-in command line (see "How it boots" in README.md).
# net.ifnames=0 keeps the network card's traditional name, eth0, which
# lfs/9-config/02-network.sh configures.
KERNEL_CMDLINE="root=PARTUUID=$ROOT_PARTUUID rootwait net.ifnames=0 console=tty0 console=ttyS0,115200"
