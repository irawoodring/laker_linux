#!/usr/bin/env bash
#
# Build LakerLinux: a Linux kernel, the GNU C library and a BusyBox userland,
# packed into a bootable UEFI disk image.
#
#   scripts/build.sh            # build everything
#   scripts/build.sh kernel     # just one stage: fetch|kernel|glibc|busybox|rootfs|image
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
    fetch_one "$GLIBC_URL" "$GLIBC_SRC"
    fetch_one "$BUSYBOX_URL" "$BUSYBOX_SRC"
    sync_patches kernel
    sync_patches glibc
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

stage_glibc() {
    fetch_one "$KERNEL_URL" "$KERNEL_SRC"
    fetch_one "$GLIBC_URL" "$GLIBC_SRC"
    sync_patches glibc

    # glibc talks to the kernel through system calls, so it's compiled against
    # our kernel's headers: system call numbers, structures, constants.
    # They're staged first, then only headers whose contents changed are copied
    # in, so unchanged ones keep their timestamps and don't trigger a rebuild.
    log "Installing Linux $KERNEL_VERSION headers into the sysroot"
    "${KMAKE[@]}" headers_install INSTALL_HDR_PATH="$BUILD_DIR/kernel-headers" >/dev/null
    mkdir -p "$SYSROOT/usr/include"
    rsync -r --checksum "$BUILD_DIR/kernel-headers/include/" "$SYSROOT/usr/include/"

    # glibc must be built outside its source tree.
    local build="$BUILD_DIR/glibc-build-$GLIBC_VERSION"
    if [ ! -f "$build/config.make" ]; then
        log "Configuring glibc $GLIBC_VERSION"
        mkdir -p "$build"
        # Everything goes in /usr/lib (glibc's default splits /lib64 and
        # /usr/lib64). --enable-kernel is the oldest kernel to support.
        (cd "$build" && "$GLIBC_SRC/configure" \
            --prefix=/usr --libdir=/usr/lib libc_cv_slibdir=/usr/lib \
            --host="$TARGET" \
            --with-headers="$SYSROOT/usr/include" \
            --enable-kernel=5.4 \
            --disable-werror) > "$build/configure.log" 2>&1 ||
            { tail -20 "$build/configure.log"; die "glibc configure failed; see $build/configure.log"; }
    fi

    log "Building glibc $GLIBC_VERSION"
    make -C "$build" -j"$JOBS"
    # Install into the sysroot, not /: DESTDIR keeps it away from the build
    # machine's own C library. Skipped when nothing was rebuilt.
    local stamp="$build/.installed"
    if [ ! -f "$stamp" ] || [ -n "$(find "$build" -newer "$stamp" -name '*.so*' -print -quit)" ]; then
        log "Installing glibc into the sysroot"
        make -C "$build" install DESTDIR="$SYSROOT" > "$build/install.log" 2>&1 ||
            { tail -20 "$build/install.log"; die "glibc install failed; see $build/install.log"; }
        touch "$stamp"
    fi
}

stage_busybox() {
    fetch_one "$BUSYBOX_URL" "$BUSYBOX_SRC"
    sync_patches busybox
    [ -f "$SYSROOT/usr/lib/libc.so.6" ] || die "glibc isn't built yet; run ./laker build glibc first"
    log "Configuring BusyBox $BUSYBOX_VERSION"
    "${BBMAKE[@]}" defconfig
    # Link against our glibc in the sysroot, not the build machine's C library.
    sed -i -e "s|^CONFIG_SYSROOT=.*|CONFIG_SYSROOT=\"$SYSROOT\"|" \
           -e "s|^CONFIG_CROSS_COMPILER_PREFIX=.*|CONFIG_CROSS_COMPILER_PREFIX=\"$TARGET-\"|" \
           "$BUSYBOX_SRC/.config"
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

    # glibc's run-time pieces: the dynamic loader and the shared libraries.
    # Headers, static libraries and crt*.o files stay in the sysroot, since
    # they're only needed for compiling. Stripping debug info takes this from
    # about 75 MB to 5 MB.
    mkdir -p "$ROOTFS/usr/lib" "$ROOTFS/lib64"
    local lib
    for lib in "$SYSROOT"/usr/lib/*.so.*; do
        "$TARGET-strip" --strip-debug -o "$ROOTFS/usr/lib/$(basename "$lib")" "$lib"
    done
    # Every x86_64 Linux program has this loader path built in.
    ln -s ../usr/lib/ld-linux-x86-64.so.2 "$ROOTFS/lib64/ld-linux-x86-64.so.2"

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
[ ${#stages[@]} -eq 0 ] && stages=(fetch kernel glibc busybox rootfs image)
for s in "${stages[@]}"; do
    case "$s" in
        fetch|kernel|glibc|busybox|rootfs|image) mkdir -p "$BUILD_DIR"; "stage_$s" ;;
        *) die "unknown stage '$s' (expected fetch, kernel, glibc, busybox, rootfs, image)" ;;
    esac
done

# When built in Docker as root, hand the outputs back to the host user.
if [ -n "${HOST_UID:-}" ] && [ -d "$OUT_DIR" ]; then
    chown -R "$HOST_UID:${HOST_GID:-$HOST_UID}" "$OUT_DIR"
fi
