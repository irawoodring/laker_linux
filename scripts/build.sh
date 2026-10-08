#!/usr/bin/env bash
#
# Build LakerLinux: a Linux kernel and a userland, packed into a bootable UEFI
# disk image. SYSTEM (config/versions.sh) chooses the userland:
#
#   SYSTEM=busybox (default)   the GNU C library, BusyBox, a C compiler
#                              (GCC or TCC: see COMPILER) and disk tools
#     stages: fetch kernel glibc cross devtools busybox rootfs image
#   SYSTEM=lfs                 Linux From Scratch 12.4 (scripts/lfs.sh)
#     stages: fetch kernel lfs rootfs image
#
#   scripts/build.sh            # build everything
#   scripts/build.sh kernel     # just one stage
#
# Every stage is a plain shell function below -- read them, they're short.
# Shared settings, and the code that applies patches/, are in common.sh.
# Only the lfs stage needs root (for its chroot): the disk image is
# assembled from ordinary files.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# LakerLinux targets x86_64. On other hosts (e.g. Apple Silicon) cross-compile.
if [ "$(uname -m)" != x86_64 ]; then
    export CROSS_COMPILE="${CROSS_COMPILE:-x86_64-linux-gnu-}"
fi
# LOCALVERSION= (set, but empty) stops the kernel adding a "+" to its version
# because the source tree has commits since the release.
KMAKE=(make -C "$KERNEL_SRC" ARCH=x86_64 LOCALVERSION= -j"$JOBS")
# The cross-compiler (stage `cross`) installs here.
export PATH="$CROSS_DIR/bin:$PATH"
BBMAKE=(make -C "$BUSYBOX_SRC" -j"$JOBS")

# Run a command as "root" without being root, so files land in the image
# owned by uid 0. Inside Docker we usually are root already.
as_root() {
    if [ "$(id -u)" -eq 0 ]; then "$@"; else fakeroot -- "$@"; fi
}

# download URL -> extracts into $SRC_DIR (skipped if already present).
# Pass "nogit" as a third argument for sources we don't track changes to.
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
    # owners recorded in the tarball, i.e. its maintainers' user IDs.
    tar -xf "$tarball" -C "$SRC_DIR" --no-same-owner
    [ -d "$dest" ] || die "expected $dest after extracting $tarball"
    [ "${3:-}" = nogit ] || init_source_git "$dest"
}

# GCC and its three math libraries. GCC builds GMP, MPFR and MPC itself if
# their sources sit inside its tree as gmp/, mpfr/ and mpc/ (here, symlinks).
fetch_gcc() {
    fetch_one "$GCC_URL" "$GCC_SRC"
    local lib ver url
    for lib in gmp mpfr mpc; do
        case $lib in
            gmp)  ver=$GMP_VERSION;  url=$GMP_URL ;;
            mpfr) ver=$MPFR_VERSION; url=$MPFR_URL ;;
            mpc)  ver=$MPC_VERSION;  url=$MPC_URL ;;
        esac
        fetch_one "$url" "$SRC_DIR/$lib-$ver" nogit
        ln -sfn "../$lib-$ver" "$GCC_SRC/$lib"
        # Keep the links out of ./laker diff gcc.
        grep -qx "/$lib" "$GCC_SRC/.git/info/exclude" || echo "/$lib" >> "$GCC_SRC/.git/info/exclude"
    done
}

# The build machine's own name, for --build. Anything that isn't
# $CROSS_TARGET makes configure scripts cross-compile.
build_triplet() { "$MAKE_SRC/build-aux/config.guess"; }

# autobuild NAME SRC BUILD_DIR INSTALL_ARGS -- CONFIGURE_ARGS...
#   Configure (once) in BUILD_DIR, run make, then `make INSTALL_ARGS install`
#   unless nothing was rebuilt since the last install. Logs go in BUILD_DIR.
autobuild() {
    local name="$1" src="$2" build="$3" install_args="$4"
    shift 4; [ "$1" = -- ] && shift
    if [ ! -f "$build/Makefile" ]; then
        log "Configuring $name"
        mkdir -p "$build"
        (cd "$build" && "$src/configure" "$@") > "$build/configure.log" 2>&1 ||
            { tail -20 "$build/configure.log"; die "$name: configure failed; see $build/configure.log"; }
    fi
    log "Building $name"
    make -C "$build" -j"$JOBS" > "$build/make.log" 2>&1 ||
        { tail -30 "$build/make.log"; die "$name: build failed; see $build/make.log"; }
    # The stamp's name depends on where it installs, so a new destination
    # gets a fresh install.
    local stamp="$build/.installed-$(echo "$install_args" | md5sum | cut -c1-8)"
    if [ ! -f "$stamp" ] || [ -n "$(find "$build" -newer "$stamp" -type f ! -name '*.log' -print -quit)" ]; then
        log "Installing $name"
        # shellcheck disable=SC2086
        make -C "$build" $install_args install > "$build/install.log" 2>&1 ||
            { tail -20 "$build/install.log"; die "$name: install failed; see $build/install.log"; }
        touch "$stamp"
    fi
}

stage_fetch() {
    fetch_one "$KERNEL_URL" "$KERNEL_SRC"
    if [ "$SYSTEM" = lfs ]; then
        sync_patches kernel
        "$LAKER_DIR/scripts/lfs.sh" download
        return 0
    fi
    fetch_one "$GLIBC_URL" "$GLIBC_SRC"
    fetch_one "$BUSYBOX_URL" "$BUSYBOX_SRC"
    fetch_one "$MAKE_URL" "$MAKE_SRC"
    if wants gcc; then
        fetch_one "$BINUTILS_URL" "$BINUTILS_SRC"
        fetch_gcc
    fi
    if wants tcc; then fetch_one "$TCC_URL" "$TCC_SRC"; fi
    fetch_one "$UTIL_LINUX_URL" "$UTIL_LINUX_SRC"
    fetch_one "$E2FSPROGS_URL" "$E2FSPROGS_SRC"
    local comp
    for comp in $COMPONENTS; do
        [ -d "$(src_dir "$comp")" ] && sync_patches "$comp"
    done
    return 0
}

# The initramfs: a tiny file system built into the kernel, holding one
# program, /init (initramfs/init.c), that finds and mounts the real root file
# system. It's compiled with the build container's own C library, statically,
# so it needs nothing else -- not even LakerLinux's glibc, which isn't built
# yet. initramfs/files.list says what goes in it.
build_initramfs() {
    local dir="$BUILD_DIR/initramfs"
    mkdir -p "$dir"
    if [ ! -f "$dir/init" ] || [ "$LAKER_DIR/initramfs/init.c" -nt "$dir/init" ]; then
        log "Compiling the initramfs's /init"
        "$TARGET-gcc" -static -Os -Wall -o "$dir/init" "$LAKER_DIR/initramfs/init.c"
        "$TARGET-strip" "$dir/init"
    fi
    # The list names files by their paths here; only replace it when it
    # changes, so the kernel isn't relinked for nothing.
    sed "s|@INIT@|$dir/init|" "$LAKER_DIR/initramfs/files.list" > "$dir/files.list.new"
    if cmp -s "$dir/files.list.new" "$dir/files.list"; then
        rm "$dir/files.list.new"
    else
        mv "$dir/files.list.new" "$dir/files.list"
    fi
}

stage_kernel() {
    fetch_one "$KERNEL_URL" "$KERNEL_SRC"
    sync_patches kernel
    build_initramfs
    log "Configuring Linux $KERNEL_VERSION"
    "${KMAKE[@]}" x86_64_defconfig
    # Layer our options on top of the defaults.
    local frag="$BUILD_DIR/kernel.fragment"
    cp "$LAKER_DIR/config/kernel.fragment" "$frag"
    echo "CONFIG_CMDLINE=\"$KERNEL_CMDLINE\"" >> "$frag"
    echo "CONFIG_INITRAMFS_SOURCE=\"$BUILD_DIR/initramfs/files.list\"" >> "$frag"
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

# The cross-compiler: binutils and GCC that run in the build container and
# produce programs for LakerLinux, using the glibc in the sysroot. Like
# chapter 5 of Linux From Scratch, except that glibc already exists, so GCC
# is built completely in one go instead of in two passes.
stage_cross() {
    if ! wants gcc; then
        log "Skipping the cross-compiler: only needed for GCC (COMPILER=$COMPILER)"
        return 0
    fi
    [ -f "$SYSROOT/usr/lib/libc.so.6" ] || die "glibc isn't built yet; run ./laker build glibc first"
    fetch_one "$BINUTILS_URL" "$BINUTILS_SRC"
    fetch_gcc
    sync_patches binutils
    sync_patches gcc

    autobuild "cross binutils $BINUTILS_VERSION" "$BINUTILS_SRC" \
        "$BUILD_DIR/cross-binutils-$BINUTILS_VERSION" "" -- \
        --prefix="$CROSS_DIR" --target="$CROSS_TARGET" --with-sysroot="$SYSROOT" \
        --disable-nls --enable-gprofng=no --disable-werror \
        --enable-new-dtags --enable-default-hash-style=gnu

    autobuild "cross GCC $GCC_VERSION" "$GCC_SRC" \
        "$BUILD_DIR/cross-gcc-$GCC_VERSION" "" -- \
        --prefix="$CROSS_DIR" --target="$CROSS_TARGET" --with-sysroot="$SYSROOT" \
        --enable-default-pie --enable-default-ssp \
        --disable-nls --disable-multilib --disable-libsanitizer \
        --enable-languages=c,c++
}

# The compiler(s) chosen by COMPILER, make, and the disk tools laker-install
# uses, all built to run *inside* LakerLinux and installed under
# $DEVTOOLS_ROOT (the rootfs stage copies them into the image).
stage_devtools() {
    [ -f "$SYSROOT/usr/lib/libc.so.6" ] || die "glibc isn't built yet; run ./laker build glibc first"
    fetch_one "$MAKE_URL" "$MAKE_SRC"
    sync_patches make
    if wants gcc; then devtools_gcc; fi
    if wants tcc; then devtools_tcc; fi
    devtools_make
    devtools_disk
    devtools_git
}

# GCC and binutils, cross-compiled with the cross-compiler. Like chapter 6
# of Linux From Scratch.
devtools_gcc() {
    command -v "$CROSS_TARGET-gcc" >/dev/null || die "no cross-compiler yet; run ./laker build cross first"
    fetch_one "$BINUTILS_URL" "$BINUTILS_SRC"
    fetch_gcc
    sync_patches binutils
    sync_patches gcc
    local build root="$DEVTOOLS_ROOT/gcc"
    build="$(build_triplet)"

    autobuild "binutils $BINUTILS_VERSION" "$BINUTILS_SRC" \
        "$BUILD_DIR/devtools-binutils-$BINUTILS_VERSION" "DESTDIR=$root" -- \
        --prefix=/usr --build="$build" --host="$CROSS_TARGET" \
        --disable-nls --enable-shared --enable-gprofng=no --disable-werror \
        --enable-64-bit-bfd --enable-new-dtags --enable-default-hash-style=gnu
    # libtool archives only get in the way of linking; LFS removes them too.
    rm -f "$root"/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}

    # GCC's own target libraries (libgcc, libstdc++) are compiled by the cross
    # GCC above, which is the same version -- they must match.
    local gccbuild="$BUILD_DIR/devtools-gcc-$GCC_VERSION"
    autobuild "GCC $GCC_VERSION" "$GCC_SRC" "$gccbuild" "DESTDIR=$root" -- \
        --build="$build" --host="$CROSS_TARGET" --target="$CROSS_TARGET" \
        LDFLAGS_FOR_TARGET="-L$gccbuild/$CROSS_TARGET/libgcc" \
        --prefix=/usr --with-build-sysroot="$SYSROOT" \
        --enable-default-pie --enable-default-ssp \
        --disable-nls --disable-multilib --disable-libatomic --disable-libgomp \
        --disable-libquadmath --disable-libsanitizer --disable-libssp --disable-libvtv \
        --enable-languages=c,c++
    ln -sfn gcc "$root/usr/bin/cc"
}

# TCC, the Tiny C Compiler: compiler, assembler and linker in one program.
# It needs no cross-compiler of its own: the build container's x86_64
# compiler builds it, against the glibc in the sysroot.
devtools_tcc() {
    fetch_one "$TCC_URL" "$TCC_SRC"
    sync_patches tcc
    # --cross-prefix chooses that compiler; the paths are where the new tcc
    # will find headers and libraries inside LakerLinux. {B} is TCC's own
    # directory (/usr/lib/tcc), where it keeps libtcc1.a and its headers.
    # x86_64-libtcc1-usegcc=yes: compile TCC's runtime library, libtcc1.a,
    # with that compiler too (normally TCC compiles it with the tcc it just
    # built, but that tcc runs on LakerLinux, not here).
    local build="$BUILD_DIR/tcc-build" root="$DEVTOOLS_ROOT/tcc"
    local args=(--prefix=/usr --cpu=x86_64 --cross-prefix="$TARGET-"
                --extra-cflags="-O2 --sysroot=$SYSROOT" --extra-ldflags="--sysroot=$SYSROOT"
                --crtprefix=/usr/lib --libpaths='{B}:/usr/lib'
                --sysincludepaths='{B}/include:/usr/include'
                --elfinterp=/lib64/ld-linux-x86-64.so.2)
    # Built in a copy of its source tree (rsync refreshes it with any edits):
    # TCC's runtime library Makefile only works when building in-tree.
    mkdir -p "$build"
    rsync -a --exclude=.git "$TCC_SRC/" "$build/"
    # Configure again whenever the options above change.
    if [ ! -f "$build/config.mak" ] || [ "${args[*]}" != "$(cat "$build/.configure-args" 2>/dev/null)" ]; then
        log "Configuring TCC"
        (cd "$build" && ./configure "${args[@]}") > "$build/configure.log" 2>&1 ||
            { tail -20 "$build/configure.log"; die "TCC configure failed; see $build/configure.log"; }
        echo "${args[*]}" > "$build/.configure-args"
    fi
    # c2str.exe is a helper TCC's build compiles and then runs, to turn a
    # header into C source. Build it for *this* machine (with the native gcc),
    # or it would be an x86_64 LakerLinux program that can't run here (e.g.
    # on Apple Silicon). make then sees it's up to date and leaves it alone.
    gcc -DC2STR "$build/conftest.c" -o "$build/c2str.exe"
    log "Building TCC"
    make -C "$build" -j"$JOBS" x86_64-libtcc1-usegcc=yes > "$build/make.log" 2>&1 ||
        { tail -30 "$build/make.log"; die "TCC build failed; see $build/make.log"; }
    make -C "$build" x86_64-libtcc1-usegcc=yes DESTDIR="$root" install > "$build/install.log" 2>&1 ||
        { tail -20 "$build/install.log"; die "TCC install failed; see $build/install.log"; }
    ln -sfn tcc "$root/usr/bin/cc"
}

# GNU make, built with the build container's x86_64 compiler, so it doesn't
# need GCC's cross-compiler and works with either COMPILER.
devtools_make() {
    autobuild "make $MAKE_VERSION" "$MAKE_SRC" \
        "$BUILD_DIR/make-build-$MAKE_VERSION" "DESTDIR=$DEVTOOLS_ROOT/make" -- \
        --prefix=/usr --build="$(build_triplet)" --host="$CROSS_TARGET" \
        --without-guile --disable-nls \
        CC="$TARGET-gcc --sysroot=$SYSROOT" AR="$TARGET-ar" RANLIB="$TARGET-ranlib"
}

# sfdisk (from util-linux) and mke2fs (from e2fsprogs), which laker-install
# needs: BusyBox's fdisk can't write GPT partition tables, and its mke2fs only
# makes ext2. Built like make, with the build container's compiler. Their own
# libraries (libfdisk, libext2fs, ...) are linked in statically, so nothing
# but the programs goes into the image.
devtools_disk() {
    fetch_one "$UTIL_LINUX_URL" "$UTIL_LINUX_SRC"
    fetch_one "$E2FSPROGS_URL" "$E2FSPROGS_SRC"
    sync_patches util-linux
    sync_patches e2fsprogs
    local root="$DEVTOOLS_ROOT/disk" build
    build="$(build_triplet)"
    local cc=(CC="$TARGET-gcc --sysroot=$SYSROOT" AR="$TARGET-ar" RANLIB="$TARGET-ranlib")

    # Just sfdisk and fdisk, and the libraries they need. (fdisks=check:
    # also cfdisk, but only if ncurses is there, which it isn't.)
    autobuild "util-linux $UTIL_LINUX_VERSION (sfdisk, fdisk)" "$UTIL_LINUX_SRC" \
        "$BUILD_DIR/util-linux-build-$UTIL_LINUX_VERSION" "DESTDIR=$root" -- \
        --prefix=/usr --bindir=/usr/bin --sbindir=/usr/sbin \
        --build="$build" --host="$CROSS_TARGET" \
        --disable-all-programs --enable-fdisks=check \
        --enable-libfdisk --enable-libuuid --enable-libblkid --enable-libsmartcols \
        --disable-shared --disable-nls --disable-asciidoc --disable-poman \
        --disable-bash-completion --disable-liblastlog2 \
        --without-python --without-systemd --without-udev --without-ncursesw \
        --without-ncurses --without-tinfo --without-readline --without-cap-ng \
        --without-libz --without-btrfs --without-econf --without-libmagic \
        "${cc[@]}"

    # mke2fs, e2fsck and friends. Their own copies of libuuid and libblkid.
    autobuild "e2fsprogs $E2FSPROGS_VERSION (mke2fs, e2fsck)" "$E2FSPROGS_SRC" \
        "$BUILD_DIR/e2fsprogs-build-$E2FSPROGS_VERSION" "DESTDIR=$root" -- \
        --prefix=/usr --sysconfdir=/etc --build="$build" --host="$CROSS_TARGET" \
        --disable-nls --disable-fsck --disable-uuidd --disable-fuse2fs \
        --disable-e2scrub --without-libarchive \
        --with-crond-dir=no --with-systemd-unit-dir=no --with-udev-rules-dir=no \
        "${cc[@]}"

    # Only the programs: not the libraries' headers and .a files, which are
    # only needed to build these.
    rm -rf "$root/usr/include" "$root/usr/lib" "$root/usr/share/bash-completion" \
           "$root/usr/sbin/e2scrub" "$root/usr/sbin/e2scrub_all"
}

devtools_git() {
    fetch_one "$ZLIB_URL" "$ZLIB_SRC";       sync_patches zlib
    fetch_one "$OPENSSL_URL" "$OPENSSL_SRC"; sync_patches openssl
    fetch_one "$CURL_URL" "$CURL_SRC";       sync_patches curl
    fetch_one "$GIT_URL" "$GIT_SRC";         sync_patches git
    local root="$DEVTOOLS_ROOT/git"
    # The build container's compiler, aimed at LakerLinux's glibc (the sysroot).
    local cc=(CC="$TARGET-gcc --sysroot=$SYSROOT" AR="$TARGET-ar" RANLIB="$TARGET-ranlib")

    # Each library is installed twice:
    #   into the sysroot, so the next package can link against it;
    #   into devtools/git, so it ends up in the image.

    # 1. zlib. Its configure isn't autoconf: it takes CC from the environment.
    local zb="$BUILD_DIR/zlib-build"
    mkdir -p "$zb"
    [ -f "$zb/Makefile" ] || (cd "$zb" && env "${cc[@]}" "$ZLIB_SRC/configure" --prefix=/usr)
    make -C "$zb" -j"$JOBS"
    make -C "$zb" install DESTDIR="$SYSROOT"
    make -C "$zb" install DESTDIR="$root"

    # 2. OpenSSL. Its own Perl Configure script, told the target outright.
    local ob="$BUILD_DIR/openssl-build"
    mkdir -p "$ob"
    [ -f "$ob/Makefile" ] || (cd "$ob" && env -u CROSS_COMPILE "${cc[@]}" "$OPENSSL_SRC/Configure" linux-x86_64 \
        --prefix=/usr --openssldir=/etc/ssl --libdir=lib shared no-tests no-docs)
    make -C "$ob" -j"$JOBS"                      # the slow one: a few minutes
    make -C "$ob" install_sw DESTDIR="$SYSROOT"  # install_sw: skip the man pages
    make -C "$ob" install_sw install_ssldirs DESTDIR="$root"

    # 3. curl: normal autoconf, so autobuild does configure/make/install.
    #    --without-*: optional libraries we don't have.
    local cb="$BUILD_DIR/curl-build"
    autobuild "curl $CURL_VERSION" "$CURL_SRC" "$cb" "DESTDIR=$SYSROOT" -- \
        --prefix=/usr --build="$(build_triplet)" --host="$CROSS_TARGET" \
        --with-openssl --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt \
        --disable-static --disable-ldap --disable-manual --disable-docs \
        --without-libpsl --without-brotli --without-zstd --without-nghttp2 \
        --without-libidn2 --without-libssh2 "${cc[@]}"
    make -C "$cb" install DESTDIR="$root"

    # 4. git. No configure step: its Makefile takes settings as variables.
    #    NO_*: leave out the parts needing Perl, Python, Tcl/Tk, gettext,
    #    expat, which LakerLinux doesn't have. git builds in-tree, so copy it.
    local gb="$BUILD_DIR/git-build"
    mkdir -p "$gb"
    rsync -a --exclude=.git "$GIT_SRC/" "$gb/"
    local gitmake=(make -C "$gb" prefix=/usr
        CC="$TARGET-gcc --sysroot=$SYSROOT" AR="$TARGET-ar" uname_S=Linux uname_M=x86_64
        NO_PERL=1 NO_PYTHON=1 NO_TCLTK=1 NO_GETTEXT=1 NO_EXPAT=1 NO_OPENSSL=1
        CURL_LDFLAGS=-lcurl INSTALL_SYMLINKS=1)
    "${gitmake[@]}" -j"$JOBS" all
    "${gitmake[@]}" install DESTDIR="$root"
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

# Remove debug info from every ELF file under a directory. Executables and
# shared libraries lose their symbol tables too; object files and static
# libraries keep theirs, because the linker needs them.
strip_tree() {
    local f
    find "$1" -type f \( -perm -u+x -o -name '*.so*' -o -name '*.a' -o -name '*.o' \) -print0 |
    while IFS= read -r -d '' f; do
        [ "$(head -c4 "$f" 2>/dev/null | od -An -c | tr -d ' ')" = '177ELF' ] || [[ $f == *.a ]] || continue
        case "$f" in
            *.a|*.o) "$TARGET-strip" --strip-debug "$f" 2>/dev/null || true ;;
            *)       "$TARGET-strip" --strip-unneeded "$f" 2>/dev/null || true ;;
        esac
    done
}

# SYSTEM=lfs: Linux From Scratch, chapters 4 to 11 (all but the kernel, which
# the kernel stage builds, and GRUB, which LakerLinux doesn't need).
stage_lfs() {
    "$LAKER_DIR/scripts/lfs.sh" build
}

stage_rootfs() {
    if [ "$SYSTEM" = lfs ]; then
        # LFS builds the system in place; just add LakerLinux's own files.
        [ -x "$ROOTFS/usr/bin/bash" ] || die "no LFS system yet; run ./laker build lfs first"
        log "Copying lfs/rootfs-overlay/ into the LFS system"
        cp -a "$LAKER_DIR/lfs/rootfs-overlay/." "$ROOTFS/"
        # The installer is the same for both systems.
        install -m 755 "$LAKER_DIR/rootfs-overlay/usr/sbin/laker-install" "$ROOTFS/usr/sbin/"
        return 0
    fi
    log "Assembling root filesystem in $ROOTFS"
    rm -rf "$ROOTFS"
    mkdir -p "$ROOTFS"/{dev,proc,sys,run,tmp,root,home,mnt,var/log,etc}
    chmod 1777 "$ROOTFS/tmp"
    chmod 700 "$ROOTFS/root"

    # BusyBox installs itself as /bin/busybox plus a symlink per applet.
    "${BBMAKE[@]}" CONFIG_PREFIX="$ROOTFS" install >/dev/null

    # The sysroot: glibc (the dynamic loader and shared libraries programs
    # need to run, plus the headers, crt*.o start-up files and link libraries
    # that compiling needs) and the kernel's headers.
    mkdir -p "$ROOTFS/usr" "$ROOTFS/lib64"
    cp -a "$SYSROOT/usr/include" "$SYSROOT/usr/lib" "$ROOTFS/usr/"
    # Every x86_64 Linux program has this loader path built in.
    ln -s ../usr/lib/ld-linux-x86-64.so.2 "$ROOTFS/lib64/ld-linux-x86-64.so.2"

    # make, then the chosen compiler(s): TCC before GCC, so with both, cc
    # runs gcc. --remove-destination replaces BusyBox's symlinks for the same
    # names (ar, strings, ...) instead of writing through them into
    # /bin/busybox.
    local tools=(make disk git) t
    if wants tcc; then tools+=(tcc); fi
    if wants gcc; then tools+=(gcc); fi
    for t in "${tools[@]}"; do
        [ -d "$DEVTOOLS_ROOT/$t/usr" ] || die "$t isn't built yet; run ./laker build devtools first"
        cp -a --remove-destination "$DEVTOOLS_ROOT/$t/usr/." "$ROOTFS/usr/"
    done
    install -D -m 644 /etc/ssl/certs/ca-certificates.crt "$ROOTFS/etc/ssl/certs/ca-certificates.crt"
    ln -sfn certs/ca-certificates.crt "$ROOTFS/etc/ssl/cert.pem"   # OpenSSL's default location
    rm -rf "$ROOTFS"/usr/share/{info,man,doc}   # no man or info reader here

    # TCC's own source, so you can rebuild TCC with TCC inside LakerLinux.
    if wants tcc; then
        mkdir -p "$ROOTFS/usr/src"
        rsync -a --exclude=.git "$TCC_SRC/" "$ROOTFS/usr/src/tinycc/"
    fi

    # Strip debugging information: about 1 GB of it, mostly in GCC.
    strip_tree "$ROOTFS"

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
    if mountpoint -q "$ROOTFS/proc"; then
        die "$ROOTFS still has file systems mounted from the lfs stage"
    fi
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
    # conv=sparse skips all-zero blocks, so the image's empty space takes no disk.
    dd if="$esp" of="$disk" bs=1M seek=1 conv=notrunc,sparse status=none
    dd if="$root" of="$disk" bs=1M seek=$((ESP_SIZE_MB + 1)) conv=notrunc,sparse status=none

    log "Done: $disk"
    echo "Boot it with: ./laker run"
}

if [ "$SYSTEM" = lfs ]; then
    all_stages=(fetch kernel lfs rootfs image)
else
    all_stages=(fetch kernel glibc cross devtools busybox rootfs image)
fi
stages=("$@")
[ ${#stages[@]} -eq 0 ] && stages=("${all_stages[@]}")
for s in "${stages[@]}"; do
    case " ${all_stages[*]} " in
        *" $s "*) mkdir -p "$BUILD_DIR"; "stage_$s" ;;
        *) die "unknown stage '$s' for SYSTEM=$SYSTEM (expected: ${all_stages[*]})" ;;
    esac
done

# When built in Docker as root, hand the outputs back to the host user.
if [ -n "${HOST_UID:-}" ] && [ -d "$OUT_DIR" ]; then
    chown -R "$HOST_UID:${HOST_GID:-$HOST_UID}" "$OUT_DIR"
fi
