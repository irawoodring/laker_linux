# Pinned upstream versions. Bump these to upgrade; the build re-downloads
# anything it doesn't already have.
KERNEL_VERSION="${KERNEL_VERSION:-6.18.44}"
BUSYBOX_VERSION="${BUSYBOX_VERSION:-1.36.1}"
GLIBC_VERSION="${GLIBC_VERSION:-2.42}"
# TCC's last release (0.9.27) is from 2017 and predates today's glibc, so this
# pins a commit from its active development branch, "mob".
TCC_COMMIT="${TCC_COMMIT:-43c7708b85681a2fd4451c8a541af4494a8919b2}"
MAKE_VERSION="${MAKE_VERSION:-4.4.1}"

KERNEL_URL="${KERNEL_URL:-https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_VERSION%%.*}.x/linux-${KERNEL_VERSION}.tar.xz}"
BUSYBOX_URL="${BUSYBOX_URL:-https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2}"
GLIBC_URL="${GLIBC_URL:-https://ftp.gnu.org/gnu/glibc/glibc-${GLIBC_VERSION}.tar.xz}"
TCC_URL="${TCC_URL:-https://github.com/TinyCC/tinycc/archive/${TCC_COMMIT}.tar.gz}"
MAKE_URL="${MAKE_URL:-https://ftp.gnu.org/gnu/make/make-${MAKE_VERSION}.tar.gz}"

# Disk layout. The partition UUID is fixed so the kernel's built-in command
# line can always find the root filesystem (root=PARTUUID=...).
# 1 GB leaves room for building software inside LakerLinux. The image file is
# sparse, so its empty space doesn't use disk on your computer.
IMAGE_SIZE_MB="${IMAGE_SIZE_MB:-1024}"
ESP_SIZE_MB=64
DISK_GUID="4c414b45-5200-4c49-4e55-580000000000"
ROOT_PARTUUID="4c414b45-5200-4c49-4e55-580000000002"
ROOT_FS_UUID="4c414b45-5200-4c49-4e55-580000000003"
