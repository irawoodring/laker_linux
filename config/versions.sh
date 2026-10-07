# Pinned upstream versions. Bump these to upgrade; the build re-downloads
# anything it doesn't already have.
KERNEL_VERSION="${KERNEL_VERSION:-6.18.44}"
BUSYBOX_VERSION="${BUSYBOX_VERSION:-1.36.1}"
GLIBC_VERSION="${GLIBC_VERSION:-2.42}"
# The toolchain, matching Linux From Scratch 12.4.
BINUTILS_VERSION="${BINUTILS_VERSION:-2.45}"
GCC_VERSION="${GCC_VERSION:-15.2.0}"
GMP_VERSION="${GMP_VERSION:-6.3.0}"
MPFR_VERSION="${MPFR_VERSION:-4.2.2}"
MPC_VERSION="${MPC_VERSION:-1.3.1}"
MAKE_VERSION="${MAKE_VERSION:-4.4.1}"

KERNEL_URL="${KERNEL_URL:-https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_VERSION%%.*}.x/linux-${KERNEL_VERSION}.tar.xz}"
BUSYBOX_URL="${BUSYBOX_URL:-https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2}"
GLIBC_URL="${GLIBC_URL:-https://ftp.gnu.org/gnu/glibc/glibc-${GLIBC_VERSION}.tar.xz}"
GNU_MIRROR="${GNU_MIRROR:-https://ftp.gnu.org/gnu}"
BINUTILS_URL="$GNU_MIRROR/binutils/binutils-${BINUTILS_VERSION}.tar.xz"
GCC_URL="$GNU_MIRROR/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz"
GMP_URL="$GNU_MIRROR/gmp/gmp-${GMP_VERSION}.tar.xz"
MPFR_URL="$GNU_MIRROR/mpfr/mpfr-${MPFR_VERSION}.tar.xz"
MPC_URL="$GNU_MIRROR/mpc/mpc-${MPC_VERSION}.tar.gz"
MAKE_URL="$GNU_MIRROR/make/make-${MAKE_VERSION}.tar.gz"

# Disk layout. The partition UUID is fixed so the kernel's built-in command
# line can always find the root filesystem (root=PARTUUID=...).
# 2 GB leaves room for the compiler and for building software inside LakerLinux.
IMAGE_SIZE_MB="${IMAGE_SIZE_MB:-2048}"
ESP_SIZE_MB=64
DISK_GUID="4c414b45-5200-4c49-4e55-580000000000"
ROOT_PARTUUID="4c414b45-5200-4c49-4e55-580000000002"
ROOT_FS_UUID="4c414b45-5200-4c49-4e55-580000000003"
