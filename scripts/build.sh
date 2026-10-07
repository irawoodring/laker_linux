#!/usr/bin/env bash
#
# Build LakerLinux: a Linux kernel and a complete GNU/Linux system built by
# following Linux From Scratch, packed into a bootable UEFI disk image.
#
#   scripts/build.sh            # build everything
#   scripts/build.sh kernel     # just one stage: fetch|kernel|lfs|rootfs|image
#
# Every stage is a plain shell function below -- read them, they're short.
# The lfs stage is scripts/lfs.sh, which runs the scripts in lfs/.
# Shared settings, and the code that applies patches/, are in common.sh.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# LOCALVERSION= (set, but empty) stops the kernel adding a "+" to its version
# because the source tree has commits since the release.
KMAKE=(make -C "$KERNEL_SRC" ARCH=x86_64 LOCALVERSION= -j"$JOBS")

# The new system's root directory: the lfs stage builds into it, and the
# image stage packs it into the disk image.
ROOTFS="$BUILD_DIR/lfs"

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
    # --no-same-owner: as root (in Docker), tar would otherwise keep the file
    # owners recorded in the tarball.
    tar -xf "$tarball" -C "$SRC_DIR" --no-same-owner
    [ -d "$dest" ] || die "expected $dest after extracting $tarball"
    init_source_git "$dest"
}

stage_fetch() {
    fetch_one "$KERNEL_URL" "$KERNEL_SRC"
    sync_patches kernel
}

stage_kernel() {
    fetch_one "$KERNEL_URL" "$KERNEL_SRC"
    sync_patches kernel
    log "Configuring Linux $KERNEL_VERSION"
    "${KMAKE[@]}" x86_64_defconfig
    # Layer our options on top of the defaults.
    local frag="$BUILD_DIR/kernel.fragment"
    cp "$LAKER_DIR/config/kernel.fragment" "$frag"
    echo "CONFIG_CMDLINE=\"$KERNEL_CMDLINE\"" >> "$frag"
    (cd "$KERNEL_SRC" && ARCH=x86_64 scripts/kconfig/merge_config.sh -m .config "$frag")
    "${KMAKE[@]}" olddefconfig

    log "Building kernel (this is the slow part -- go get coffee)"
    "${KMAKE[@]}" bzImage
    mkdir -p "$OUT_DIR"
    cp "$KERNEL_SRC/arch/x86/boot/bzImage" "$OUT_DIR/bzImage"
}

# Linux From Scratch, chapters 4 to 11 (all but the kernel, which the kernel
# stage builds, and GRUB, which LakerLinux doesn't need).
stage_lfs() {
    "$LAKER_DIR/scripts/lfs.sh" build
}

# LakerLinux's own touches on top of LFS: everything in rootfs-overlay/.
stage_rootfs() {
    [ -x "$ROOTFS/usr/bin/bash" ] || die "no LFS system yet; run ./laker build lfs first"
    log "Copying rootfs-overlay/ into the new system"
    cp -a "$LAKER_DIR/rootfs-overlay/." "$ROOTFS/"
}

stage_image() {
    [ -f "$OUT_DIR/bzImage" ] || die "no kernel yet; run the kernel stage first"
    [ -x "$ROOTFS/usr/bin/bash" ] || die "no LFS system yet; run ./laker build lfs first"
    mountpoint -q "$ROOTFS/proc" && die "$ROOTFS still has file systems mounted from the lfs stage"
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

    # 2. Root partition (ext4), populated straight from the LFS directory.
    rm -f "$root"
    as_root mke2fs -q -t ext4 -L lakerroot -U "$ROOT_FS_UUID" \
        -d "$ROOTFS" "$root" "${root_mb}M"

    # 3. Partition table, then copy each filesystem into its slot.
    #    conv=sparse skips all-zero blocks, so the image's empty space takes no disk.
    rm -f "$disk"
    truncate -s "${IMAGE_SIZE_MB}M" "$disk"
    sfdisk --quiet "$disk" <<EOF
label: gpt
label-id: $DISK_GUID
start=1MiB, size=${ESP_SIZE_MB}MiB, type=uefi, name="LAKERBOOT"
start=$((ESP_SIZE_MB + 1))MiB, size=${root_mb}MiB, type=linux, uuid=$ROOT_PARTUUID, name="lakerroot"
EOF
    dd if="$esp" of="$disk" bs=1M seek=1 conv=notrunc,sparse status=none
    dd if="$root" of="$disk" bs=1M seek=$((ESP_SIZE_MB + 1)) conv=notrunc,sparse status=none
    rm -f "$root" "$esp"

    log "Done: $disk"
    echo "Boot it with: ./laker run"
}

stages=("$@")
[ ${#stages[@]} -eq 0 ] && stages=(fetch kernel lfs rootfs image)
for s in "${stages[@]}"; do
    case "$s" in
        fetch|kernel|lfs|rootfs|image) mkdir -p "$BUILD_DIR"; "stage_$s" ;;
        *) die "unknown stage '$s' (expected fetch, kernel, lfs, rootfs, image)" ;;
    esac
done

# When built in Docker as root, hand the outputs back to the host user.
if [ -n "${HOST_UID:-}" ] && [ -d "$OUT_DIR" ]; then
    chown -R "$HOST_UID:${HOST_GID:-$HOST_UID}" "$OUT_DIR"
fi
