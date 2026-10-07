#!/usr/bin/env bash
#
# Build LakerLinux: a Linux kernel + a BusyBox userland, packed into a
# bootable UEFI disk image.
#
#   scripts/build.sh            # build everything
#   scripts/build.sh kernel     # just one stage: fetch|kernel|busybox|rootfs|image
#
# Every stage is a plain shell function below -- read them, they're short.
# Shared settings, and the code that applies patches/, are in common.sh.
# Nothing here needs root: the disk image is assembled from ordinary files.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# LakerLinux targets x86_64. On other hosts (e.g. Apple Silicon) cross-compile.
if [ "$(uname -m)" != x86_64 ]; then
    export CROSS_COMPILE="${CROSS_COMPILE:-x86_64-linux-gnu-}"
fi
# LOCALVERSION= (set, but empty) stops the kernel adding a "+" to its version
# because the source tree has commits since the release.
KMAKE=(make -C "$KERNEL_SRC" ARCH=x86_64 LOCALVERSION= -j"$JOBS")
BBMAKE=(make -C "$BUSYBOX_SRC" -j"$JOBS")

# Run a command as "root" without being root, so files land in the image
# owned by uid 0. Inside Docker we usually are root already.
as_root() {
    if [ "$(id -u)" -eq 0 ]; then "$@"; else fakeroot -- "$@"; fi
}

# download URL -> extracts into $SRC_DIR (skipped if already present)
fetch_one() {
    local url="$1" dest="$2" tarball="$DL_DIR/$(basename "$1")"
    [ -d "$dest" ] && return 0
    mkdir -p "$DL_DIR" "$SRC_DIR"
    if [ ! -f "$tarball" ]; then
        log "Downloading $url"
        curl -fL --retry 3 -o "$tarball.part" "$url"
        mv "$tarball.part" "$tarball"
    fi
    log "Extracting $(basename "$tarball")"
    tar -xf "$tarball" -C "$SRC_DIR"
    [ -d "$dest" ] || die "expected $dest after extracting $tarball"
    init_source_git "$dest"
}

stage_fetch() {
    fetch_one "$KERNEL_URL" "$KERNEL_SRC"
    fetch_one "$BUSYBOX_URL" "$BUSYBOX_SRC"
    sync_patches kernel
    sync_patches busybox
}

stage_kernel() {
    fetch_one "$KERNEL_URL" "$KERNEL_SRC"
    sync_patches kernel
    log "Configuring Linux $KERNEL_VERSION"
    "${KMAKE[@]}" x86_64_defconfig
    # Layer our options on top of the defaults.
    local frag="$BUILD_DIR/kernel.fragment"
    cp "$LAKER_DIR/config/kernel.fragment" "$frag"
    echo "CONFIG_CMDLINE=\"root=PARTUUID=$ROOT_PARTUUID rootwait console=tty0 console=ttyS0,115200\"" >> "$frag"
    (cd "$KERNEL_SRC" && ARCH=x86_64 scripts/kconfig/merge_config.sh -m .config "$frag")
    "${KMAKE[@]}" olddefconfig

    log "Building kernel (this is the slow part -- go get coffee)"
    "${KMAKE[@]}" bzImage
    mkdir -p "$OUT_DIR"
    cp "$KERNEL_SRC/arch/x86/boot/bzImage" "$OUT_DIR/bzImage"
}

stage_busybox() {
    fetch_one "$BUSYBOX_URL" "$BUSYBOX_SRC"
    sync_patches busybox
    log "Configuring BusyBox $BUSYBOX_VERSION"
    "${BBMAKE[@]}" defconfig
    # Static binary: no shared libraries needed in the image.
    sed -i 's/^# CONFIG_STATIC is not set/CONFIG_STATIC=y/' "$BUSYBOX_SRC/.config"
    # `tc` doesn't build against modern kernel headers; we don't need it.
    sed -i 's/^CONFIG_TC=y/# CONFIG_TC is not set/' "$BUSYBOX_SRC/.config"
    "${BBMAKE[@]}" oldconfig </dev/null >/dev/null

    log "Building BusyBox"
    "${BBMAKE[@]}"
}

stage_rootfs() {
    log "Assembling root filesystem in $ROOTFS"
    rm -rf "$ROOTFS"
    mkdir -p "$ROOTFS"/{dev,proc,sys,run,tmp,root,home,mnt,var/log,etc}
    chmod 1777 "$ROOTFS/tmp"
    chmod 700 "$ROOTFS/root"

    # BusyBox installs itself as /bin/busybox plus a symlink per applet.
    "${BBMAKE[@]}" CONFIG_PREFIX="$ROOTFS" install >/dev/null

    # Everything students customize lives in rootfs-overlay/.
    cp -a "$LAKER_DIR/rootfs-overlay/." "$ROOTFS/"
    chmod +x "$ROOTFS"/etc/init.d/* "$ROOTFS"/usr/share/udhcpc/default.script

    cat > "$ROOTFS/etc/os-release" <<EOF
NAME="LakerLinux"
ID=lakerlinux
PRETTY_NAME="LakerLinux ($(date +%Y.%m.%d))"
BUILD_ID=$(date +%Y%m%d%H%M)
EOF
}

stage_image() {
    [ -f "$OUT_DIR/bzImage" ] || die "no kernel yet; run the kernel stage first"
    [ -d "$ROOTFS" ] || die "no rootfs yet; run the rootfs stage first"
    log "Creating disk image"

    local esp="$BUILD_DIR/esp.img" root="$BUILD_DIR/root.img" disk="$OUT_DIR/lakerlinux.img"
    local root_mb=$((IMAGE_SIZE_MB - ESP_SIZE_MB - 2)) # 1 MiB lead-in + 1 MiB for backup GPT

    # 1. EFI System Partition (FAT). UEFI firmware boots \EFI\BOOT\BOOTX64.EFI
    #    from removable media, and a kernel built with EFI_STUB is a valid EFI
    #    program -- so no GRUB needed.
    rm -f "$esp"
    mkfs.vfat -n LAKERBOOT -C "$esp" $((ESP_SIZE_MB * 1024)) >/dev/null
    mmd -i "$esp" ::/EFI ::/EFI/BOOT
    mcopy -i "$esp" "$OUT_DIR/bzImage" ::/EFI/BOOT/BOOTX64.EFI

    # 2. Root partition (ext4), populated straight from the rootfs directory.
    rm -f "$root"
    as_root mke2fs -q -t ext4 -L lakerroot -U "$ROOT_FS_UUID" \
        -d "$ROOTFS" "$root" "${root_mb}M"

    # 3. Partition table, then copy each filesystem into its slot.
    rm -f "$disk"
    truncate -s "${IMAGE_SIZE_MB}M" "$disk"
    sfdisk --quiet "$disk" <<EOF
label: gpt
label-id: $DISK_GUID
start=1MiB, size=${ESP_SIZE_MB}MiB, type=uefi, name="LAKERBOOT"
start=$((ESP_SIZE_MB + 1))MiB, size=${root_mb}MiB, type=linux, uuid=$ROOT_PARTUUID, name="lakerroot"
EOF
    dd if="$esp" of="$disk" bs=1M seek=1 conv=notrunc status=none
    dd if="$root" of="$disk" bs=1M seek=$((ESP_SIZE_MB + 1)) conv=notrunc status=none

    log "Done: $disk"
    echo "Boot it with: ./laker run"
}

stages=("$@")
[ ${#stages[@]} -eq 0 ] && stages=(fetch kernel busybox rootfs image)
for s in "${stages[@]}"; do
    case "$s" in
        fetch|kernel|busybox|rootfs|image) mkdir -p "$BUILD_DIR"; "stage_$s" ;;
        *) die "unknown stage '$s' (expected fetch, kernel, busybox, rootfs, image)" ;;
    esac
done

# When built in Docker as root, hand the outputs back to the host user.
if [ -n "${HOST_UID:-}" ] && [ -d "$OUT_DIR" ]; then
    chown -R "$HOST_UID:${HOST_GID:-$HOST_UID}" "$OUT_DIR"
fi
