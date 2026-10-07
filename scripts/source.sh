#!/usr/bin/env bash
#
# Work with your changes to the kernel source.
#
#   scripts/source.sh diff                    # which files you've changed, in each
#   scripts/source.sh diff kernel             # show your unsaved kernel edits
#   scripts/source.sh diff kernel hello-msg   # save them as patches/kernel/NNNN-hello-msg.patch
#   scripts/source.sh reset kernel            # throw away unsaved kernel edits
#
# "Unsaved" means not yet in a patches/ file. See common.sh for how the
# source trees track this with git.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# The source tree for a component, which must already be unpacked.
existing_src() {
    local src
    src="$(src_dir "$1")"
    [ -d "$src/.git" ] || die "no $1 source yet; run ./laker build $1 first"
    echo "$src"
}

# Stage everything (new files included) so `git diff --cached` sees it all.
stage_all() { src_git "$1" add -A; }

summary() {
    local comp src
    for comp in $COMPONENTS; do
        src="$(src_dir "$comp")"
        if [ ! -d "$src/.git" ]; then
            echo "== $comp: no source yet (./laker build $comp unpacks it)"
            continue
        fi
        stage_all "$src"
        echo "== $comp ($(basename "$src"))"
        if src_git "$src" diff --cached --quiet HEAD; then
            echo "   no unsaved changes"
        else
            src_git "$src" diff --cached --stat HEAD
        fi
    done
}

show() {
    local src
    src="$(existing_src "$1")"
    stage_all "$src"
    if src_git "$src" diff --cached --quiet HEAD; then
        echo "No unsaved changes in the $1 source."
    else
        src_git "$src" diff --cached HEAD
    fi
}

save() {
    local comp="$1" name src
    src="$(existing_src "$comp")"
    # Patch names: lowercase letters, digits and dashes.
    name="$(printf '%s' "$2" | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//')"
    [ -n "$name" ] || die "give the patch a name, e.g. ./laker diff $comp hello-message"

    stage_all "$src"
    if src_git "$src" diff --cached --quiet HEAD; then
        echo "No unsaved changes in the $comp source; nothing to save."
        return 0
    fi

    # Number patches so they apply in the order they were written.
    mkdir -p "$PATCH_DIR/$comp"
    local last=0 f n
    for f in "$PATCH_DIR/$comp"/[0-9][0-9][0-9][0-9]-*.patch; do
        [ -f "$f" ] || continue
        n="$(basename "$f" | cut -c1-4)"
        [ $((10#$n)) -gt "$last" ] && last=$((10#$n))
    done
    local file
    file="$(printf '%s/%s/%04d-%s.patch' "$PATCH_DIR" "$comp" $((last + 1)) "$name")"

    {
        echo "$name"
        echo
        echo "Describe this change here. Everything above the first \"diff --git\""
        echo "line is a comment: the build ignores it."
        echo
        src_git "$src" diff --cached --binary HEAD
    } > "$file"

    # Mark it applied, so the next build doesn't try to apply it again.
    record_patch "$src" "$(basename "$file")" "$(sha256sum < "$file" | cut -d' ' -f1)"
    if [ -n "${HOST_UID:-}" ]; then
        chown -R "$HOST_UID:${HOST_GID:-$HOST_UID}" "$PATCH_DIR"
    fi

    echo "Saved patches/$comp/$(basename "$file"):"
    src_git "$src" show --stat --format= HEAD
    echo "Commit it to git to keep it. Every build applies it from now on."
}

reset_src() {
    local comp="$1" src
    src="$(existing_src "$comp")"
    if [ -z "$(unsaved_changes "$src")" ]; then
        echo "No unsaved changes in the $comp source."
        return 0
    fi
    echo "These unsaved changes to the $comp source will be thrown away:"
    unsaved_changes "$src"
    if [ -t 0 ]; then
        local answer
        read -r -p "Continue? [y/N] " answer
        case "$answer" in y|Y|yes) ;; *) echo "Nothing changed."; return 0 ;; esac
    fi
    src_git "$src" reset -q --hard HEAD
    src_git "$src" clean -q -fd
    echo "Done: the $comp source matches upstream plus patches/$comp/ again."
}

case "${1:-}" in
    diff)
        if [ $# -eq 1 ]; then summary
        elif [ $# -eq 2 ]; then show "$2"
        else save "$2" "${*:3}"
        fi ;;
    reset)
        [ $# -eq 2 ] || die "usage: ./laker reset kernel"
        reset_src "$2" ;;
    *) sed -n '3,11p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
