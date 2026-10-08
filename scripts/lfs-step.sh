#!/bin/bash
#
# Run one LFS step script, the way the book's "General Compilation
# Instructions" describe (chapter 5 introduction):
#
#   1. go to the sources directory,
#   2. unpack the step's package (its "# Package:" line) and cd into it,
#   3. apply any patches from patches/lfs/<package>/,
#   4. run the book's commands,
#   5. go back and delete the unpacked source.
#
# Called by scripts/lfs.sh, either in the build container (chapters 4-6) or
# inside the chroot (chapters 7-9):
#
#   lfs-step.sh SOURCES_DIR PATCHES_DIR STEP_SCRIPT

set -e
set +h          # don't remember where commands are; new tools appear as we go
umask 022

LAKER_SOURCES="$1" LAKER_PATCHES="$2" LAKER_STEP="$3"

LAKER_PKG="$(sed -n 's/^# Package: //p' "$LAKER_STEP")"
cd "$LAKER_SOURCES"

if [ -n "$LAKER_PKG" ] && [ "$LAKER_PKG" != "(none)" ]; then
    [ -f "$LAKER_PKG" ] || { echo "lfs-step: $LAKER_SOURCES/$LAKER_PKG is missing" >&2; exit 1; }
    LAKER_DIR="$(tar -tf "$LAKER_PKG" | head -1 | cut -d/ -f1)"
    rm -rf "$LAKER_DIR"
    tar -xf "$LAKER_PKG" --no-same-owner
    cd "$LAKER_DIR"
    for p in "$LAKER_PATCHES/${LAKER_PKG%.tar*}"/*.patch "$LAKER_PATCHES/${LAKER_PKG%.tgz}"/*.patch; do
        [ -f "$p" ] || continue
        echo "lfs-step: applying $(basename "$p")"
        patch -Np1 -i "$p"
    done
fi

# The book's commands. Sourced (not run) so they see the variables above, and
# so `cd` in one command carries over to the next, as when typing them.
# shellcheck disable=SC1090
source "$LAKER_STEP"

cd "$LAKER_SOURCES"
[ -n "${LAKER_DIR:-}" ] && rm -rf "$LAKER_DIR"
exit 0
