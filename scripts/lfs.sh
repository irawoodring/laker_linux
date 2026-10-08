#!/usr/bin/env bash
#
# Build LakerLinux's userland by following Linux From Scratch 12.4, one book
# section at a time. Each section is a script in lfs/, in chapter order:
#
#   lfs/4-prepare/          chapter 4: the new system's top-level layout
#   lfs/5-cross-toolchain/  chapter 5: a cross-compiler for the new system
#   lfs/6-temporary-tools/  chapter 6: basic tools, cross-compiled
#   lfs/7-chroot/           chapter 7: enter the new system, more tools
#   lfs/8-system/           chapter 8: the final system, package by package
#   lfs/9-config/           chapters 9-11: boot scripts, network, fstab, ...
#
#   scripts/lfs.sh                  # run every step that hasn't succeeded yet
#   scripts/lfs.sh download         # just download and check the sources
#   scripts/lfs.sh status           # list the steps, and which are done
#   scripts/lfs.sh redo 8-system/35-bash.sh   # run one step again
#
# Chapters 4-6 run here in the build container; 7-9 run inside the new system
# with chroot, which needs a privileged container (./laker passes --privileged).
# A step that succeeds is recorded in $BUILD_DIR/lfs-done/, so after a failure,
# running this again carries on where it stopped.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

LFS="$BUILD_DIR/lfs"                 # the new system's root directory
LFS_TGT=x86_64-lfs-linux-gnu         # the cross-compiler's target (chapter 4.4)
SOURCES="$BUILD_DIR/lfs-sources"     # tarballs and patches (chapter 3)
DONE_DIR="$BUILD_DIR/lfs-done"
STEPS_DIR="$LAKER_DIR/lfs"
LFS_PATCHES="$LAKER_DIR/patches/lfs"
LOG_DIR="$BUILD_DIR/lfs-logs"

# --- Chapter 3: packages and patches -------------------------------------

download_sources() {
    mkdir -p "$SOURCES"
    local url file n=0
    while read -r url; do
        [ -n "$url" ] || continue
        file="${url##*/}"
        [ -f "$SOURCES/$file" ] && continue
        # Everything comes from the LFS project's mirror of this release,
        # except LFS's own bootscripts, which the mirror doesn't carry.
        case "$file" in
            lfs-bootscripts-*) ;;
            *) url="$LFS_MIRROR/$file" ;;
        esac
        log "Downloading $file"
        curl -fL --retry 3 -o "$SOURCES/$file.part" "$url"
        mv "$SOURCES/$file.part" "$SOURCES/$file"
        n=$((n + 1))
    done < "$STEPS_DIR/book/wget-list-sysv"
    if [ "$n" -gt 0 ] || [ ! -f "$SOURCES/.verified" ]; then
        log "Checking the packages against the book's md5sums"
        (cd "$SOURCES" && md5sum --quiet -c "$STEPS_DIR/book/md5sums") ||
            die "some downloads don't match lfs/book/md5sums; delete them from $SOURCES and retry"
        touch "$SOURCES/.verified"
    fi
}

# --- Running steps -------------------------------------------------------

steps() { (cd "$STEPS_DIR" && ls -1 [4-9]-*/*.sh); }
stamp() { echo "$DONE_DIR/${1//\//_}"; }

# Chapters 4-6: in the build container, with the environment chapter 4.4
# sets up for the lfs user (we're root in a throwaway container instead).
run_on_host() {
    env -i HOME=/root TERM="${TERM:-xterm}" LC_ALL=POSIX \
        LFS="$LFS" LFS_TGT="$LFS_TGT" \
        PATH="$LFS/tools/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
        CONFIG_SITE="$LFS/usr/share/config.site" \
        MAKEFLAGS="-j$JOBS" FORCE_UNSAFE_CONFIGURE=1 \
        /bin/bash --norc "$LAKER_DIR/scripts/lfs-step.sh" "$SOURCES" "$LFS_PATCHES" "$STEPS_DIR/$1"
}

# Chapters 7-9: inside the new system (chapter 7.4). The repository is
# mounted at /lakerlinux and the sources at /sources while this runs.
run_in_chroot() {
    chroot "$LFS" /usr/bin/env -i HOME=/root TERM="${TERM:-xterm}" \
        PATH=/usr/bin:/usr/sbin MAKEFLAGS="-j$JOBS" FORCE_UNSAFE_CONFIGURE=1 \
        ROOT_PARTUUID="$ROOT_PARTUUID" \
        /bin/bash --norc /lakerlinux/scripts/lfs-step.sh /sources /lakerlinux/patches/lfs "/lakerlinux/lfs/$1"
}

# Chapter 7.3: the virtual kernel file systems, plus the sources and this
# repository. Undone by unmount_chroot (also on exit, even after a failure).
mount_chroot() {
    mountpoint -q "$LFS/proc" && return 0
    log "Mounting /dev, /proc, /sys and /run in the new system (chapter 7.3)"
    mkdir -p "$LFS"/{dev,proc,sys,run,sources,lakerlinux}
    mount --bind /dev "$LFS/dev"
    mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
    mount -t proc proc "$LFS/proc"
    mount -t sysfs sysfs "$LFS/sys"
    mount -t tmpfs tmpfs "$LFS/run"
    if [ -h "$LFS/dev/shm" ]; then
        install -d -m 1777 "$LFS$(realpath /dev/shm)"
    else
        mount -t tmpfs -o nosuid,nodev tmpfs "$LFS/dev/shm"
    fi
    mount --bind "$SOURCES" "$LFS/sources"
    mount --bind "$LAKER_DIR" "$LFS/lakerlinux"
    trap unmount_chroot EXIT
}

unmount_chroot() {
    local m
    for m in lakerlinux sources dev/shm dev/pts dev run sys proc; do
        mountpoint -q "$LFS/$m" && umount -l "$LFS/$m"
    done
    rmdir "$LFS/sources" "$LFS/lakerlinux" 2>/dev/null || true
}

run_step() {
    local step="$1" log="$LOG_DIR/${1//\//_}.log"
    if grep -q '^# Skip:' "$STEPS_DIR/$step"; then
        echo "    skipping $step ($(sed -n 's/^# Skip: //p' "$STEPS_DIR/$step"))"
        touch "$(stamp "$step")"
        return 0
    fi
    log "$step: $(sed -n '1s/^# LFS 12.4, //p' "$STEPS_DIR/$step")"
    local start=$SECONDS
    case "$step" in
        [4-6]-*) run_on_host "$step" ;;
        *)       mount_chroot; run_in_chroot "$step" ;;
    esac > "$log" 2>&1 || {
        tail -30 "$log"
        die "$step failed; the full log is $log. Fix the problem, then run ./laker build lfs again."
    }
    echo "    done in $(( (SECONDS - start) / 60 ))m$(( (SECONDS - start) % 60 ))s"
    touch "$(stamp "$step")"
}

cmd_build() {
    mkdir -p "$LFS" "$DONE_DIR" "$LOG_DIR"
    download_sources
    local step
    for step in $(steps); do
        [ -f "$(stamp "$step")" ] || run_step "$step"
    done
    log "Linux From Scratch is complete in $LFS"
}

cmd_status() {
    local step
    for step in $(steps); do
        if [ -f "$(stamp "$step")" ]; then echo "  done  $step"; else echo "        $step"; fi
    done
}

case "${1:-build}" in
    build)  cmd_build ;;
    download) download_sources ;;
    status) cmd_status ;;
    redo)   [ $# -eq 2 ] || die "usage: scripts/lfs.sh redo <chapter>/<step>.sh"
            mkdir -p "$DONE_DIR" "$LOG_DIR"; rm -f "$(stamp "$2")"; run_step "$2" ;;
    *)      die "usage: scripts/lfs.sh [build|download|status|redo <step>]" ;;
esac
