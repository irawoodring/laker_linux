# Which system to build (see "Two ways to build" in README.md):
#   busybox  a small system: BusyBox, glibc, and a compiler (COMPILER below);
#            about 20 minutes to an hour
#   lfs      a complete GNU/Linux system built by following Linux From
#            Scratch 12.4, about 80 packages; several hours
# Override it for one build with e.g. SYSTEM=lfs ./laker build
SYSTEM="${SYSTEM:-busybox}"

# Which C compiler the busybox system ships (see "Choosing a compiler" in
# README.md). The lfs system always has GCC, built by the book.
#   gcc   GCC 15 and binutils: C and C++, optimizing; about an hour to build
#   tcc   the Tiny C Compiler: C only, tiny and fast; builds in a minute
#   both  both of them (cc runs gcc)
# Override it for one build with e.g. COMPILER=tcc ./laker build
COMPILER="${COMPILER:-gcc}"

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
# Disk tools for laker-install (sfdisk and mke2fs), also as in LFS 12.4.
UTIL_LINUX_VERSION="${UTIL_LINUX_VERSION:-2.41.1}"
E2FSPROGS_VERSION="${E2FSPROGS_VERSION:-1.47.3}"
# TCC's last release (0.9.27) is from 2017 and predates today's glibc, so this
# pins a commit from its active development branch, "mob".
TCC_COMMIT="${TCC_COMMIT:-43c7708b85681a2fd4451c8a541af4494a8919b2}"

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
TCC_URL="${TCC_URL:-https://github.com/TinyCC/tinycc/archive/${TCC_COMMIT}.tar.gz}"
UTIL_LINUX_URL="https://cdn.kernel.org/pub/linux/utils/util-linux/v${UTIL_LINUX_VERSION%.*}/util-linux-${UTIL_LINUX_VERSION}.tar.xz"
E2FSPROGS_URL="https://cdn.kernel.org/pub/linux/kernel/people/tytso/e2fsprogs/v${E2FSPROGS_VERSION}/e2fsprogs-${E2FSPROGS_VERSION}.tar.xz"

# SYSTEM=lfs: everything but the kernel comes from Linux From Scratch 12.4.
# The package versions are the book's (lfs/book/wget-list-sysv), downloaded
# from the LFS project's mirror of that release.
LFS_VERSION=12.4
LFS_MIRROR="${LFS_MIRROR:-https://ftp.osuosl.org/pub/lfs/lfs-packages/$LFS_VERSION}"

# Disk layout. The initramfs finds the root file system by its partition's
# name, "lakerroot" (see "The initramfs" in README.md); the IDs below are
# fixed only so that every build of the image is the same.
# The image is a sparse file, so its empty space doesn't use disk on your
# computer. The defaults leave room for building software inside LakerLinux.
if [ "$SYSTEM" = lfs ]; then
    IMAGE_SIZE_MB="${IMAGE_SIZE_MB:-8192}"
else
    IMAGE_SIZE_MB="${IMAGE_SIZE_MB:-2048}"
fi
ESP_SIZE_MB=64
DISK_GUID="4c414b45-5200-4c49-4e55-580000000000"
ROOT_PARTUUID="4c414b45-5200-4c49-4e55-580000000002"
ROOT_FS_UUID="4c414b45-5200-4c49-4e55-580000000003"

# Add git
ZLIB_VERSION="${ZLIB_VERSION:-1.3.1}"         # zlib and OpenSSL: LFS 12.4's versions
OPENSSL_VERSION="${OPENSSL_VERSION:-3.5.2}"
CURL_VERSION="${CURL_VERSION:-8.15.0}"
GIT_VERSION="${GIT_VERSION:-2.51.0}"
ZLIB_URL="https://zlib.net/fossils/zlib-${ZLIB_VERSION}.tar.gz"
OPENSSL_URL="https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz"
CURL_URL="https://curl.se/download/curl-${CURL_VERSION}.tar.xz"
GIT_URL="https://cdn.kernel.org/pub/software/scm/git/git-${GIT_VERSION}.tar.xz"

# The kernel's built-in command line (see "How it boots" in README.md).
# No root=: the initramfs finds the root file system itself. net.ifnames=0
# keeps the network card's traditional name, eth0, which both systems'
# network setup uses.
KERNEL_CMDLINE="net.ifnames=0 console=tty0 console=ttyS0,115200"
