# Pinned upstream versions. Bump these to upgrade; the build re-downloads
# anything it doesn't already have.
KERNEL_VERSION="${KERNEL_VERSION:-6.18.44}"
BUSYBOX_VERSION="${BUSYBOX_VERSION:-1.36.1}"

KERNEL_URL="${KERNEL_URL:-https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_VERSION%%.*}.x/linux-${KERNEL_VERSION}.tar.xz}"
BUSYBOX_URL="${BUSYBOX_URL:-https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2}"

# Disk layout. The partition UUID is fixed so the kernel's built-in command
# line can always find the root filesystem (root=PARTUUID=...).
IMAGE_SIZE_MB="${IMAGE_SIZE_MB:-512}"
ESP_SIZE_MB=64
DISK_GUID="4c414b45-5200-4c49-4e55-580000000000"
ROOT_PARTUUID="4c414b45-5200-4c49-4e55-580000000002"
ROOT_FS_UUID="4c414b45-5200-4c49-4e55-580000000003"
