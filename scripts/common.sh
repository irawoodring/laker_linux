# Settings and helpers shared by build.sh and source.sh. Not run directly.

LAKER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$LAKER_DIR/config/versions.sh"

BUILD_DIR="${BUILD_DIR:-$LAKER_DIR/build}"
OUT_DIR="${OUT_DIR:-$LAKER_DIR/out}"
# Make them absolute: some build steps run from inside the source trees.
case "$BUILD_DIR" in /*) ;; *) BUILD_DIR="$PWD/$BUILD_DIR" ;; esac
case "$OUT_DIR" in /*) ;; *) OUT_DIR="$PWD/$OUT_DIR" ;; esac
DL_DIR="$BUILD_DIR/downloads"
SRC_DIR="$BUILD_DIR/src"
PATCH_DIR="$LAKER_DIR/patches"
JOBS="${JOBS:-$(nproc)}"

KERNEL_SRC="$SRC_DIR/linux-$KERNEL_VERSION"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

# Source trees tracked with git (see below). The LFS packages aren't: each is
# unpacked fresh, built and deleted, as the book does. Changes to them go in
# patches/lfs/<package>/ (see patches/README.md).
COMPONENTS="kernel"

# component -> its source directory
src_dir() {
    case "$1" in
        kernel)  echo "$KERNEL_SRC" ;;
        *) die "unknown component '$1' (expected: $COMPONENTS)" ;;
    esac
}

# --- Tracking source changes with git ---------------------------------------
#
# Each unpacked source tree is also a small git repository:
#
#   upstream            the release tarball exactly as downloaded (tagged)
#   + one commit per    patches/<component>/*.patch, in name order
#   + your edits        not committed: `./laker diff` shows or saves them
#
# The trees' own .gitignore files keep compiled output out of all of this.

# safe.directory: git refuses to work in a repository owned by another user,
# which these trees can be (e.g. unpacked as root in Docker).
src_git() {
    git -C "$1" -c safe.directory='*' -c user.name=LakerLinux -c user.email=laker@localhost "${@:2}"
}

# Make a freshly unpacked tree a git repo, with its contents tagged `upstream`.
init_source_git() {
    local src="$1"
    [ -d "$src/.git" ] && return 0
    log "Recording pristine $(basename "$src") source (one-time, takes a minute)"
    src_git "$src" init -q
    src_git "$src" add -A
    src_git "$src" commit -q -m "upstream $(basename "$src")"
    src_git "$src" tag upstream
}

# "NAME SHA256" for each patch the repo says to apply, in order.
wanted_patches() {
    local f
    for f in "$PATCH_DIR/$1"/*.patch; do
        [ -f "$f" ] && echo "$(basename "$f") $(sha256sum < "$f" | cut -d' ' -f1)"
    done
    return 0
}

# "NAME SHA256" for each patch already applied to the tree, in order.
applied_patches() {
    src_git "$1" log --reverse --format=%s upstream..HEAD
}

# Lists files you've changed (or added) that aren't saved as a patch yet.
unsaved_changes() {
    src_git "$1" status --porcelain
}

# Commit whatever is staged, recording it as patch NAME with checksum SHA.
record_patch() {
    src_git "$1" commit -q --allow-empty -m "$2 $3"
}

# Bring the tree to: upstream + every patch in patches/<component>/.
sync_patches() {
    local comp="$1" src
    src="$(src_dir "$comp")"
    init_source_git "$src"
    src_git "$src" rev-parse -q --verify upstream >/dev/null ||
        die "$src has no 'upstream' tag; run ./laker clean and build again"

    local wanted applied
    wanted="$(wanted_patches "$comp")"
    applied="$(applied_patches "$src")"
    [ "$wanted" = "$applied" ] && return 0

    if [ -n "$(unsaved_changes "$src")" ]; then
        die "patches/$comp/ changed, but the $comp source has unsaved edits.
Save them first with:   ./laker diff $comp <name>
or throw them away:     ./laker reset $comp"
    fi

    log "Applying patches/$comp/ to the $comp source"
    src_git "$src" reset -q --hard upstream
    src_git "$src" clean -q -fd
    local name sha
    while read -r name sha; do
        [ -n "$name" ] || continue
        echo "  $name"
        src_git "$src" apply --index "$PATCH_DIR/$comp/$name" ||
            die "patches/$comp/$name doesn't apply to $(basename "$src")"
        record_patch "$src" "$name" "$sha"
    done <<< "$wanted"
}
