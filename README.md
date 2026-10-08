# LakerLinux

<p align="center">
  <img src="./resources/tux_gv.png" width="300">
</p>

A version of Linux for students to use and learn with.

It's a tiny distribution you build from source, for learning how an
operating system goes together: the kernel, the boot process, init, the
shell, and the build tools that tie it all together.

It starts out deliberately small: a Linux kernel, the
[GNU C library](https://www.gnu.org/software/libc/) (glibc),
[BusyBox](https://busybox.net) (one program that provides `sh`, `ls`, `mount`,
`vi`, `ip`, and ~300 other commands), a C compiler and GNU make, packed into a
disk image that boots in QEMU or on a real PC. You can write and compile
programs inside LakerLinux itself. The compiler is your choice: GCC, the
standard GNU compiler, or TCC, a tiny one you can read in an afternoon.
Everything else is up to you.

Or build the full version: a complete, conventional GNU/Linux system built by
following [Linux From Scratch](https://www.linuxfromscratch.org/lfs/view/12.4/)
12.4, one book section at a time. See
[Two ways to build](#two-ways-to-build-busybox-or-linux-from-scratch).

- [Quick start](#quick-start)
- [Two ways to build: BusyBox or Linux From Scratch](#two-ways-to-build-busybox-or-linux-from-scratch)
- [What's in this repository](#whats-in-this-repository)
- [Where everything comes from](#where-everything-comes-from)
- [How the build works](#how-the-build-works)
- [The C library: glibc](#the-c-library-glibc)
- [Choosing a compiler](#choosing-a-compiler)
- [The toolchain: GCC, binutils and make](#the-toolchain-gcc-binutils-and-make)
- [The Tiny C Compiler](#the-tiny-c-compiler)
- [The full system: Linux From Scratch](#the-full-system-linux-from-scratch)
- [Changing the kernel or BusyBox source](#changing-the-kernel-or-busybox-source)
- [The root filesystem and `rootfs-overlay/`](#the-root-filesystem-and-rootfs-overlay)
- [How it boots](#how-it-boots)
- [The initramfs](#the-initramfs)
- [Running LakerLinux](#running-lakerlinux)
- [Installing to a USB stick or another disk](#installing-to-a-usb-stick-or-another-disk)
- [Everyday workflow](#everyday-workflow)
- [Where to take it next](#where-to-take-it-next)
- [Troubleshooting](#troubleshooting)

## Quick start

You need **Docker** and about **25 GB of disk** (more for the Linux From
Scratch system). Nothing else. Then pick one of these:

| What you get | Build it | First build (4 cores) |
|---|---|---|
| BusyBox system with GCC (the default) | `./laker build` | About an hour, mostly GCC |
| BusyBox system with TCC, the Tiny C Compiler | `COMPILER=tcc ./laker build` | About 20 minutes, mostly the kernel and glibc |
| BusyBox system with both compilers | `COMPILER=both ./laker build` | About an hour |
| Full Linux From Scratch system | `SYSTEM=lfs ./laker build` | Several hours |

and boot it:

```sh
./laker run       # boots the system you built last, in this terminal
```

See [Two ways to build](#two-ways-to-build-busybox-or-linux-from-scratch) and
[Choosing a compiler](#choosing-a-compiler) for what the options mean. To make
one the default, set `SYSTEM` or `COMPILER` in `config/versions.sh` instead.

At the `lakerlinux login:` prompt, type **`root`**. There's no password.
Inside LakerLinux, run `poweroff` when you're done. If it gets stuck, press
**Ctrl-A** then **X** to kill QEMU.

Rebuilding after a change only redoes what changed, so later builds take seconds
to minutes.

### Without Docker (Linux only)

For the BusyBox system on an x86_64 Debian/Ubuntu machine, install the
toolchain once and set `LAKER_NATIVE=1`:

```sh
sudo apt install build-essential bc bison flex libelf-dev libssl-dev cpio \
    curl xz-utils bzip2 python3 perl e2fsprogs dosfstools mtools fdisk fakeroot \
    qemu-system-x86 ovmf rsync gawk m4 texinfo
LAKER_NATIVE=1 ./laker build
LAKER_NATIVE=1 ./laker run
```

The LFS system needs root (it builds chapters 7 to 9 in a chroot), so build it
in Docker.

## Two ways to build: BusyBox or Linux From Scratch

`SYSTEM` in `config/versions.sh` chooses what LakerLinux is built from. Set it
there, or for one build on the command line:

```sh
./laker build                    # SYSTEM=busybox, the default
SYSTEM=lfs ./laker build
SYSTEM=lfs ./laker run
```

| | `busybox` (default) | `lfs` |
|---|---|---|
| Userland | [BusyBox](https://busybox.net): one program providing ~300 commands | The real GNU tools: coreutils, bash, util-linux, grep, sed, ... about 80 packages |
| C library | glibc 2.42 | glibc 2.42 (built by the book) |
| Compiler | GCC or TCC, your choice (`COMPILER`) | GCC 15.2.0 (built by the book) |
| Also includes | | Perl, Python, vim, man pages, SysVinit and the LFS boot scripts |
| First build | 20 minutes (TCC) to an hour (GCC) | Several hours |
| Disk image | 2 GB | 8 GB |
| Build container | Native to your computer | Always x86_64 (emulated on Apple Silicon), `--privileged` |
| How it's built | This README, from here to [The Tiny C Compiler](#the-tiny-c-compiler) | [The full system: Linux From Scratch](#the-full-system-linux-from-scratch) |

The BusyBox system is quick to build and small enough to understand in one
sitting: a good start. The LFS system is what a "real" distribution looks
like, and every package in it is a short script you can read alongside the
book.

The two systems keep separate Docker volumes (`lakerlinux-build` and
`lakerlinux-lfs-build`), so building one never disturbs the other. Both
write `out/lakerlinux.img`, though: `./laker run` boots whichever you built
last. Everything else in this README (the kernel, the boot process, running it)
applies to both, except where it says otherwise.

## What's in this repository

```
laker                 the front door: build / run / shell / diff / reset / clean
Dockerfile            the build environment (compilers, QEMU, disk tools)
config/
  versions.sh         package versions, download URLs, disk layout
  kernel.fragment     kernel options, applied on top of the x86_64 defaults
initramfs/            the initramfs built into the kernel
  init.c              its one program: finds and mounts the root file system
  files.list          what goes in it
patches/              changes to the source of each component
  kernel/             *.patch files applied to the kernel, in name order
  glibc/, busybox/    ...to glibc and BusyBox
  binutils/, gcc/, make/
                      ...to the toolchain (gcc/ has two, from the LFS book)
  util-linux/, e2fsprogs/
                      ...to the disk tools
lfs/                  SYSTEM=lfs: Linux From Scratch, one script per book section
  book/               the book's package list (wget-list-sysv) and checksums (md5sums)
  4-prepare/ ... 9-config/
                      chapters 4 to 11, in order
  rootfs-overlay/     LakerLinux's own files, copied on top of the LFS system
rootfs-overlay/       files copied onto the BusyBox root filesystem as-is
  etc/inittab         what init (PID 1) starts
  etc/init.d/rcS      the boot script
  etc/init.d/rcK      the shutdown script
  etc/passwd, ...     users, hostname, shell profile, login banner
  usr/share/udhcpc/   the script that applies DHCP settings
  usr/sbin/laker-install
                      copies LakerLinux to another disk (both systems)
scripts/
  build.sh            the whole build, in eight readable stages
  lfs.sh              SYSTEM=lfs: runs the lfs/ scripts in order
  lfs-step.sh         SYSTEM=lfs: runs one lfs/ script (unpack, patch, build, clean up)
  run.sh              boots the image in QEMU
  source.sh           ./laker diff and ./laker reset
  common.sh           settings shared by the scripts, and the patch handling
build/                (generated, native builds only) sources and intermediate files
tools/
  extract-book.py     generates lfs/ scripts from the LFS book (for upgrading)
out/                  (generated) lakerlinux.img and bzImage
```

The repository holds only *our* files: configuration, scripts, patches, and the
overlay. The sources of the kernel, glibc, BusyBox and the toolchain are
downloaded during the build and never committed. Changes to them are kept in `patches/`.

## Where everything comes from

| Piece | Where it comes from | Set in |
|---|---|---|
| Linux kernel source | The official release tarball from [kernel.org](https://www.kernel.org): `cdn.kernel.org/pub/linux/kernel/v6.x/linux-<version>.tar.xz` | `config/versions.sh` (`KERNEL_VERSION`, `KERNEL_URL`) |
| glibc source | The official release tarball from the [GNU project](https://ftp.gnu.org/gnu/glibc/): `glibc-<version>.tar.xz` | `config/versions.sh` (`GLIBC_VERSION`, `GLIBC_URL`) |
| binutils, GCC, GMP, MPFR, MPC and make source | Official release tarballs from the [GNU project](https://ftp.gnu.org/gnu/) | `config/versions.sh` (`BINUTILS_VERSION`, `GCC_VERSION`, ..., and `GNU_MIRROR`) |
| TCC source | A pinned commit of TCC's development branch ("mob"), as a tarball from [its GitHub mirror](https://github.com/TinyCC/tinycc) | `config/versions.sh` (`TCC_COMMIT`, `TCC_URL`) |
| util-linux and e2fsprogs source (for `sfdisk` and `mke2fs`) | Official release tarballs from [kernel.org](https://www.kernel.org/pub/linux/utils/util-linux/) | `config/versions.sh` (`UTIL_LINUX_VERSION`, `E2FSPROGS_VERSION`) |
| Everything in `SYSTEM=lfs` but the kernel (95 packages and patches) | The versions in LFS 12.4, from the [LFS project's mirror](https://ftp.osuosl.org/pub/lfs/lfs-packages/12.4/), checked against the book's MD5 checksums | `lfs/book/wget-list-sysv`, `config/versions.sh` (`LFS_MIRROR`) |
| BusyBox source | The official release tarball from [busybox.net](https://busybox.net/downloads/): `busybox-<version>.tar.bz2` | `config/versions.sh` (`BUSYBOX_VERSION`, `BUSYBOX_URL`) |
| Compilers, `make`, disk tools, QEMU, UEFI firmware | Ubuntu 24.04 packages, installed into the Docker image by `Dockerfile` (or by you, for a native build) | `Dockerfile` |
| Changes to any of that source | This repository: `patches/<component>/` | |
| DHCP client script | BusyBox's own example, `examples/udhcp/simple.script`, copied into the overlay | `rootfs-overlay/usr/share/udhcpc/default.script` |
| Everything else in the image | This repository: `rootfs-overlay/`, plus a few files the build writes (see below) | |

The versions are pinned: currently **Linux 6.18.44** (a long-term-support
series), **glibc 2.42**, **BusyBox 1.36.1**, and the toolchain from
[Linux From Scratch 12.4](https://www.linuxfromscratch.org/lfs/view/12.4/):
**GCC 15.2.0**, **binutils 2.45**, **GMP 6.3.0**, **MPFR 4.2.2**,
**MPC 1.3.1** and **make 4.4.1**, and its **util-linux 2.41.1** and
**e2fsprogs 1.47.3**, plus TCC commit `43c7708` (October 2026).
TCC's last formal release, 0.9.27, is from 2017 and can't handle today's
glibc headers; development carries on in the "mob" branch. To upgrade, change the version in
`config/versions.sh` and run `./laker build`. The build downloads anything it
doesn't already have.

To download from a mirror instead, override the URL for one build:

```sh
KERNEL_URL=https://mirrors.edge.kernel.org/pub/linux/kernel/v6.x/linux-6.18.44.tar.xz ./laker build
```

Note that the build doesn't verify checksums or signatures on what it
downloads yet. kernel.org and the GNU project publish both if you want to add
that.

Downloaded tarballs are cached in `downloads/` inside the build directory (see
below), so they're fetched once. `./laker clean` keeps them.

## How the build works

This section describes the BusyBox system. With `SYSTEM=lfs`, there are five
stages instead: **fetch** (the kernel and the LFS sources), **kernel**, **lfs**
(the whole book: see
[The full system](#the-full-system-linux-from-scratch)), **rootfs** (copy
`lfs/rootfs-overlay/` on top) and **image**.

`./laker build` runs `scripts/build.sh`. Under Docker, it runs inside a
container built from `Dockerfile`, which `./laker` builds the first time you use
it. The script runs eight stages in order. You can also run any subset, e.g.
`./laker build rootfs image`.

1. **fetch**: download and unpack all the sources, if they aren't already there, and apply `patches/` (see
   [Changing the kernel or BusyBox source](#changing-the-kernel-or-busybox-source)).
2. **kernel**: configure and compile Linux.
   - Bring the source up to date with `patches/kernel/`.
   - Compile `initramfs/init.c`, the program that goes in the kernel's
     built-in initramfs (see [The initramfs](#the-initramfs)).
   - `make x86_64_defconfig` starts from the kernel's standard x86_64 defaults.
   - `scripts/kconfig/merge_config.sh` layers `config/kernel.fragment` on top.
   - The build also adds `CONFIG_CMDLINE`, the built-in kernel command line (see
     [How it boots](#how-it-boots)), and `CONFIG_INITRAMFS_SOURCE`, the list
     of files in the initramfs.
   - `make olddefconfig` fills in anything that depends on those choices.
   - `make bzImage` builds the compressed kernel, which is copied to `out/bzImage`.
3. **glibc**: build the C library into the *sysroot* (see
   [The C library: glibc](#the-c-library-glibc)).
   - Bring the source up to date with `patches/glibc/`.
   - `make headers_install` copies the kernel's headers into the sysroot.
   - `configure` sets up a build folder outside the source tree (glibc
     requires that). This only happens the first time.
   - `make`, then `make install DESTDIR=<sysroot>`.
4. **cross**: build the cross-compiler, a GCC and binutils that run in the
   build container and produce programs for LakerLinux (see
   [The toolchain](#the-toolchain-gcc-binutils-and-make)). Only when
   `COMPILER` includes GCC.
5. **devtools**: build the compiler(s) `COMPILER` asks for, make, and two
   disk tools, `sfdisk` and `mke2fs` (from util-linux and e2fsprogs, for
   [laker-install](#installing-to-a-usb-stick-or-another-disk)), to run
   *inside* LakerLinux.
6. **busybox**: bring the source up to date with `patches/busybox/`, then
   configure and compile BusyBox. It starts from BusyBox's `defconfig`
   (nearly every command enabled), then:
   - points it at the sysroot (`CONFIG_SYSROOT`), so it links against our glibc
     instead of the build container's C library;
   - turns off `tc`, which doesn't compile against current kernel headers.
7. **rootfs**: assemble the root filesystem as a plain directory (see
   [The root filesystem](#the-root-filesystem-and-rootfs-overlay)).
8. **image**: pack the kernel and that directory into `out/lakerlinux.img`.
   - Format a FAT filesystem image and copy the kernel into it as
     `EFI/BOOT/BOOTX64.EFI` (`mkfs.vfat`, `mmd`, `mcopy`).
   - Format an ext4 image straight from the rootfs directory (`mke2fs -d`).
   - Write a GPT partition table into an empty 2 GB file (`sfdisk`), then copy
     each filesystem image into its partition (`dd`).

   None of this needs root or loop devices, because it only ever works on
   ordinary files.

> **Configure through the files, not `menuconfig`.** The kernel and busybox
> stages regenerate `.config` from scratch on every build. If you change options
> with `make menuconfig` inside `./laker shell`, the next build throws those
> changes away. Use `menuconfig` to *explore*, then put the options you want in
> `config/kernel.fragment` (or, for BusyBox, add a `sed` line to the busybox
> stage in `scripts/build.sh`).

The kernel is built with everything LakerLinux needs compiled in (`=y`), not as
loadable modules. A dozen defconfig options remain modules (`=m`), mostly
firewall logging plus `efivarfs`. The build doesn't compile or install modules,
so those features aren't available. There's no `/lib/modules`.

### Where the build files go

| | Native build (`LAKER_NATIVE=1`) | Docker build |
|---|---|---|
| Build directory | `build/` in this repository | `/build` inside the container: a Docker volume named `lakerlinux-build` |
| Outputs | `out/` | `out/` (shared with your machine) |

Inside the build directory:

```
downloads/              cached source tarballs
src/linux-6.18.44/      the kernel source tree (with its .config, and a .git that tracks your edits)
src/glibc-2.42/         the glibc source tree (likewise)
src/busybox-1.36.1/     the BusyBox source tree (likewise)
src/binutils-2.45/, src/gcc-15.2.0/, src/make-4.4.1/
                        the toolchain source trees (likewise)
src/util-linux-2.41.1/, src/e2fsprogs-1.47.3/
                        the disk tools' source trees (likewise)
src/gmp-6.3.0/, ...     GMP, MPFR and MPC, linked into the GCC tree, which builds them
cross/                  the cross-compiler (x86_64-laker-linux-gnu-gcc and friends)
cross-*/, devtools-*/   where GCC and binutils are compiled
tcc-build/, make-build-*/
                        where TCC and make are compiled
util-linux-build-*/, e2fsprogs-build-*/
                        where the disk tools are compiled
devtools/gcc/, devtools/tcc/, devtools/make/, devtools/disk/
                        each tool, installed, before it goes into the image
initramfs/              the compiled /init, and the list of files in the initramfs
glibc-build-2.42/       where glibc is compiled (glibc doesn't build inside its source tree)
kernel-headers/         the kernel's headers, staged before they're copied into the sysroot
sysroot/                glibc and the kernel headers, for compiling programs for LakerLinux
kernel.fragment         the fragment as actually applied, with CONFIG_CMDLINE and
                        CONFIG_INITRAMFS_SOURCE added
rootfs/                 the root filesystem, as a directory
esp.img, root.img       the two filesystem images, before they go into the disk image
```

To look around in the Docker volume, run `./laker shell` and `cd /build`. The
kernel tree lives in a volume rather than in this repository because it's large,
and because macOS's case-insensitive filesystem can't hold it.

## The C library: glibc

Almost every program on Linux is written against the C library. It provides
`printf`, `malloc`, `open`, and the rest of the C standard library, plus thin
wrappers around the kernel's system calls. LakerLinux uses
[glibc](https://www.gnu.org/software/libc/), the C library on most Linux
distributions.

Programs use it as **shared libraries**: one copy in `/usr/lib`, loaded into
each program when it starts. The kernel can't do that loading itself. Instead,
each program names a **dynamic loader**, `/lib64/ld-linux-x86-64.so.2` on x86_64,
and the kernel runs that first. The loader finds the libraries the program needs,
maps them into memory, and then jumps to the program.

### The sysroot

The build container has its own C library, but that's Ubuntu's, not ours.
To compile programs for LakerLinux, the build keeps a separate **sysroot** at
`sysroot/` in the build directory (`/build/sysroot` in Docker). It's a miniature
`/usr` holding everything a compiler needs to target LakerLinux:

| In the sysroot | What it is |
|---|---|
| `usr/include/linux`, `usr/include/asm`, ... | The kernel's headers, from `make headers_install`. glibc is compiled against them |
| `usr/include/stdio.h`, ... | glibc's headers |
| `usr/lib/libc.so.6`, `libm.so.6`, ... | The shared libraries |
| `usr/lib/libc.a`, `crt1.o`, ... | Static libraries and start-up code, used only when linking |

The compiler's `--sysroot` option makes it use these instead of the
container's own. BusyBox is built this way.

### What goes into the image

The rootfs stage copies the whole sysroot into the image: the shared libraries
that programs need to run, and the headers, start-up files and link libraries
that GCC needs to compile programs inside LakerLinux. Debug information is
stripped. It also adds one symlink:

```
/lib64/ld-linux-x86-64.so.2 -> ../usr/lib/ld-linux-x86-64.so.2
```

Every x86_64 Linux program has the `/lib64` path built in, so the link has to be
there, even though LakerLinux keeps its libraries in `/usr/lib`.

BusyBox is now one of those programs. Because it's also `init`, the system
can't start without glibc: if the loader or `libc.so.6` were missing, the
initramfs would stop with `laker-init: can't run /sbin/init`.

### Running the loader yourself

Inside LakerLinux:

```sh
/lib64/ld-linux-x86-64.so.2 --list /bin/busybox   # which libraries it loads, from where
/usr/lib/libc.so.6                                # glibc prints its own version
```

There's no `ldd` command: glibc's `ldd` is a bash script, and LakerLinux has no
bash. Running the loader with `--list` does the same job.

## Choosing a compiler

`COMPILER` in `config/versions.sh` decides which C compiler LakerLinux ships.
Set it there, or for one build on the command line:

```sh
./laker build                    # COMPILER=gcc, the default
COMPILER=tcc ./laker build
COMPILER=both ./laker build
```

| | `gcc` | `tcc` |
|---|---|---|
| Compiler | [GCC](https://gcc.gnu.org/) 15.2.0, with binutils 2.45 | [TCC](https://bellard.org/tcc/), the Tiny C Compiler |
| Languages | C and C++ | C |
| Generated code | Optimized | Simple, slower to run |
| Compiling inside LakerLinux | Slow under emulation (a small C++ program: about 10 seconds) | Instant |
| Adds to the first build | About 35 minutes (on 4 cores) | About a minute |
| Root file system | About 270 MB | About 45 MB |
| Its source in the image | No | Yes, in `/usr/src/tinycc`: TCC can rebuild itself |

Both come with GNU make 4.4.1, and with glibc's headers and libraries.
`COMPILER=both` installs both. Then `cc` (what `make` uses by default) runs
`gcc`; run `tcc` by name.

Switching is cheap once each has been built: the build keeps both in the
build directory and copies only the chosen one(s) into the image. After
changing `COMPILER`, run `./laker build devtools rootfs image` (plus `cross`
the first time you choose GCC).

## The toolchain: GCC, binutils and make

This section is about `COMPILER=gcc` (the default) and `both`.

LakerLinux ships a real compiler toolchain:

| Package | Gives you |
|---|---|
| [GCC](https://gcc.gnu.org/) | `gcc` and `cc` (C), `g++` (C++), and C++'s standard library, `libstdc++` |
| [binutils](https://www.gnu.org/software/binutils/) | the assembler (`as`), the linker (`ld`), and tools like `ar`, `nm`, `objdump`, `readelf` and `strip` |
| [GMP, MPFR, MPC](https://gcc.gnu.org/install/prerequisites.html) | math libraries GCC itself uses; they're built into GCC |
| [GNU make](https://www.gnu.org/software/make/) | `make` |

### Compiling inside LakerLinux

```sh
cat > hello.c <<'END'
#include <stdio.h>
int main(void) { printf("Hello from LakerLinux!\n"); return 0; }
END
gcc -O2 -o hello hello.c && ./hello
```

C++ works too (`g++ -o prog prog.cpp`), and so does `make` with a Makefile.
Without KVM (on a Mac, for example) QEMU emulates the CPU, so compiling is
slow: a small C++ program takes about 10 seconds.

### How it's built: a cross-compiler first

There's a chicken-and-egg problem here. A GCC that runs *on* LakerLinux has to be
compiled by something, and LakerLinux has no compiler yet. The build container's
GCC can't do it directly, because it produces programs for Ubuntu, linked
against Ubuntu's C library. So the build goes in two steps, the same way
[Linux From Scratch](https://www.linuxfromscratch.org/lfs/view/12.4/) does:

1. **cross** (LFS chapter 5): build a **cross-compiler**, a GCC and binutils
   that *run* in the build container but *produce* programs for LakerLinux.
   They're configured with `--with-sysroot`, so they compile against the glibc
   in the sysroot, and they're installed in `cross/` in the build directory.
2. **devtools** (LFS chapter 6): use the cross-compiler to build GCC, binutils
   and make *for* LakerLinux, and install them into `devtools/`. The rootfs
   stage copies them into the image.

The cross tools are named after their target: `x86_64-laker-linux-gnu-gcc`,
`x86_64-laker-linux-gnu-ld`, and so on. That name has three parts: CPU, vendor
and operating system. The vendor part, `laker`, is what makes this work. The
build container calls itself `x86_64-pc-linux-gnu`, and configure scripts only
cross-compile when the machine they build *on* and the machine they build *for*
have different names. Inside LakerLinux, `gcc -dumpmachine` prints
`x86_64-laker-linux-gnu`.

So GCC is built twice, which is most of the first build's time: about
15 minutes for the cross stage and 18 for the devtools stage, on 4 CPU cores. The second GCC's own libraries (`libgcc`, `libstdc++`) have to be
compiled by a GCC of the same version, so the build container's older GCC can't
be used for them.

LFS builds its cross GCC in two passes, before and after glibc. LakerLinux builds
glibc first, with the build container's compiler, so one pass is enough.

GCC needs two changes to its source, both straight from the LFS book. They're
in `patches/gcc/`, with an explanation at the top of each:

- `0001-use-lib-not-lib64.patch`: install libraries in `/usr/lib`, like the
  rest of LakerLinux, instead of `/usr/lib64`.
- `0002-posix-threads-when-cross-compiling.patch`: build `libstdc++` with
  thread support when GCC is cross-compiled, so `std::thread` works.

### Compiling from the build container

You can also compile programs for LakerLinux without booting it, using the
cross-compiler in `./laker shell`. No `--sysroot` option is needed, since it
already knows where LakerLinux's glibc is:

```sh
./laker shell
mkdir -p /lakerlinux/rootfs-overlay/usr/local/bin
x86_64-laker-linux-gnu-gcc -O2 -o /lakerlinux/rootfs-overlay/usr/local/bin/hello hello.c
exit
./laker build rootfs image && ./laker run
```

The repository is mounted at `/lakerlinux` in the container, so the program
lands in `rootfs-overlay/` and goes into the image.

## The Tiny C Compiler

With `COMPILER=tcc` (or `both`), LakerLinux ships the
[Tiny C Compiler](https://bellard.org/tcc/) (TCC), written by Fabrice Bellard
(also the author of QEMU and FFmpeg). It's a complete C compiler, assembler and
linker in one small program: around 30,000 lines of C, small enough to read.
It compiles very quickly, at the cost of producing slower code than GCC.

| Command | What it is |
|---|---|
| `tcc` | The compiler. With `COMPILER=tcc`, `cc` is a link to it, so Makefiles that use the default `$(CC)` work |
| `tcc -run file.c` | Compiles a C file in memory and runs it straight away, like a script |
| `/usr/src/tinycc` | TCC's own source code |

TCC handles C (C99 and most of C11), not C++.

```sh
tcc -o hello hello.c && ./hello
tcc -run hello.c               # compile and run in one step
```

A C file can even start with `#!/usr/bin/tcc -run` and be made executable, so
you can use C like a scripting language.

### TCC compiles itself

TCC's source is in `/usr/src/tinycc`, so you can build a new TCC with the one
you have, the classic test of a compiler:

```sh
cd /usr/src/tinycc
./configure --cc=tcc --prefix=/usr --crtprefix=/usr/lib \
    --libpaths='{B}:/usr/lib' --sysincludepaths='{B}/include:/usr/include'
make
./tcc -v
```

That compiles the whole compiler in about 6 seconds, even when QEMU is
emulating the CPU. Change something, rebuild it, and use your own compiler.
(`./tcc -B. -run hello.c` tries the new one without installing it.)

### How TCC is built

TCC needs no cross-compiler of its own. The build container's x86_64 compiler,
`x86_64-linux-gnu-gcc`, builds it, pointed at the sysroot (`--sysroot`) so it
links against LakerLinux's glibc:

- `--cross-prefix=x86_64-linux-gnu-` chooses that compiler, and
  `--crtprefix`, `--libpaths`, `--sysincludepaths` and `--elfinterp` tell the
  new TCC where to find headers, libraries and the dynamic loader inside
  LakerLinux. `{B}` stands for TCC's own directory, `/usr/lib/tcc`.
- TCC has a small runtime library, `libtcc1.a`, that it normally compiles with
  the `tcc` it just built. That `tcc` runs on LakerLinux, not in the container,
  so the build uses `x86_64-libtcc1-usegcc=yes` to compile it with the
  container's compiler too.
- It's built in a copy of its source tree, because the Makefile for
  `libtcc1.a` only works in-tree.
- While building, TCC compiles and runs a small helper, `c2str.exe`, that turns
  its `include/tccdefs.h` into C source (`tccdefs_.h`). The build compiles that
  helper first with the container's own `gcc`, so it runs on the build machine
  whatever its CPU (Apple Silicon included), rather than being an x86_64
  LakerLinux program.

GNU make is built the same way, whichever compiler you choose.

## The full system: Linux From Scratch

With `SYSTEM=lfs`, LakerLinux is built entirely from source by following
[Linux From Scratch](https://www.linuxfromscratch.org/lfs/view/12.4/) (LFS)
12.4, the classic step-by-step guide to building a GNU/Linux system yourself.
Every section of the book is a short script in `lfs/`, and the build runs them
all, in Docker.

What you get is a complete, conventional Linux system: the GNU toolchain (GCC,
binutils, make), bash, coreutils, util-linux, Perl, Python, vim, man pages,
SysVinit with the LFS boot scripts, and about 75 other packages.

```sh
SYSTEM=lfs ./laker build        # several hours; resumes where it left off if stopped
SYSTEM=lfs ./laker run          # log in as root, no password
./laker lfs status              # in another terminal: which steps are done
```

The build records each step as it finishes. If it stops (an error, a closed
laptop, Ctrl-C), run it again and it carries on from that step. On a Mac,
`caffeinate -i SYSTEM=lfs ./laker build` keeps the Mac awake meanwhile.

### Linux From Scratch, automated

The [LFS book](https://www.linuxfromscratch.org/lfs/view/12.4/) is the best
documentation for this build: read it alongside the scripts. Every script in
`lfs/` starts with the section it comes from and a link to that page:

```sh
# LFS 12.4, 8.35. Grep-3.12
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/grep.html
# Package: grep-3.12.tar.xz
# (1 test-suite command block(s) from the book left out.)

./configure --prefix=/usr

make

make install
```

The rest of the script is the book's commands for that section, exactly as
printed. `tools/extract-book.py` generated these scripts from the book itself.
Wherever LakerLinux had to differ, there's a comment starting with
`LakerLinux:` explaining why.

#### What happens in each step

`scripts/lfs-step.sh` does what the book's "General Compilation Instructions"
ask of you before and after each section:

1. go to the sources directory and unpack the package named on the `# Package:`
   line;
2. `cd` into it, and apply any patches in `patches/lfs/<package>/`;
3. run the section's commands;
4. go back and delete the unpacked source.

`scripts/lfs.sh` runs the steps in order and records each one that succeeds. A
step's output goes to `lfs-logs/` in the build directory; if a step fails, you
see the end of its log.

#### Where each chapter runs

| Chapters | Where | Environment |
|---|---|---|
| 4 to 6 | In the build container | The variables the book sets up in section 4.4: `LFS`, `LFS_TGT`, a `PATH` starting with the new cross-compiler, `LC_ALL=POSIX`, `CONFIG_SITE` |
| 7 to 11 | Inside the new system, with `chroot` (section 7.4) | `/dev`, `/proc`, `/sys` and `/run` mounted as in section 7.3, and a clean environment |

This is why the build container runs with `--privileged`: mounting those file
systems needs it.

#### Commands

| Command | What it does |
|---|---|
| `./laker lfs status` | Lists every step, marking the finished ones |
| `./laker lfs redo 8-system/35-bash.sh` | Runs one step again |
| `./laker lfs download` | Downloads and checks the sources only |
| `SYSTEM=lfs ./laker build lfs` | Runs every unfinished step (part of `./laker build`) |

#### Where LakerLinux differs from the book

- **You're root, in a container.** The book has you create an `lfs` user for
  chapters 5 and 6, so a mistake can't damage the computer you're building on.
  Here the Docker container plays that role. `FORCE_UNSAFE_CONFIGURE=1` lets a
  few packages' configure scripts run as root.
- **Test suites are skipped.** The book marks them optional, and running them
  takes hours. Each script notes how many test blocks it left out. Try one: run
  the package's `make check` by hand.
- **No GRUB.** LakerLinux boots the kernel directly from UEFI firmware (see
  [How it boots](#how-it-boots)), so `8-system/63-grub.sh` has a `# Skip:` line.
  Delete that line to build GRUB anyway.
- **The kernel** is built by the `kernel` stage, not by chapter 10's
  instructions, and it has no loadable modules.
- **Choices the book leaves to you**, all marked in the scripts: time zone
  `America/Detroit`, US English UTF-8 locale, letter paper, no root password,
  the host name `lakerlinux`, and a network set up for QEMU (below). Only the
  book's list of individual locales is installed, not all of them.
- **A login prompt on the serial console**, added to `/etc/inittab`, because
  that's the terminal `./laker run` shows you.
- **Nothing that needs a person at the keyboard**: `exec bash --login`,
  `tzselect`, `passwd` and the chapter 7 backup are replaced, with comments.

### Changing an LFS package's build

Edit its script in `lfs/`, then run it again:

```sh
vim lfs/8-system/72-vim.sh
./laker lfs redo 8-system/72-vim.sh
SYSTEM=lfs ./laker build rootfs image
```

Later packages that depend on it aren't rebuilt automatically. Redo those too,
or delete `lfs-done/` in the build directory to rebuild everything.

### Changing an LFS package's source

Make a patch and put it in `patches/lfs/<package>/`, where `<package>` is the
tarball's name without `.tar.*`, e.g. `patches/lfs/grep-3.12/`. The step applies
it after unpacking, before the book's commands. To make one, in `./laker shell`:

```sh
cd /tmp && tar -xf /build/lfs-sources/grep-3.12.tar.xz
cp -a grep-3.12 grep-3.12.orig
vim grep-3.12/src/grep.c                    # make your change
diff -Naur grep-3.12.orig grep-3.12 > /lakerlinux/patches/lfs/grep-3.12/0001-my-change.patch
```

(Create the directory first.) Then `./laker lfs redo 8-system/34-grep.sh`.

### How the LFS system boots

The kernel and the disk image are the same as the BusyBox system's (see
[How it boots](#how-it-boots)); what runs after the kernel differs:

```
UEFI firmware           finds the FAT "EFI System Partition" and runs
                        \EFI\BOOT\BOOTX64.EFI
  -> Linux kernel       that file *is* the kernel (built with EFI_STUB), so
                        there's no bootloader
    -> /init            the initramfs finds the partition named "lakerroot"
                        and mounts it as /
      -> /sbin/init     SysVinit (LFS 8.82) reads /etc/inittab
        -> rc S, rc 3   the LFS boot scripts (LFS 9.2): mount file systems,
                        start udev, check and remount /, set the clock and
                        host name, bring up eth0, start syslog
        -> agetty -> login -> bash
```

The network is set up statically for QEMU (`10.0.2.15`, gateway `10.0.2.2`,
DNS `10.0.2.3`) by `lfs/9-config/02-network.sh`, rather than with DHCP. To
boot a real machine, change `/etc/sysconfig/ifconfig.eth0` to suit your
network, or build a DHCP client such as `dhcpcd` from
[Beyond LFS](https://www.linuxfromscratch.org/blfs/).

## Changing the kernel or BusyBox source

You can change any file in the kernel or BusyBox source. The build compiles
whatever is in the source tree, and never overwrites your edits.

### The workflow

```sh
./laker shell                                 # a shell in the build container
cd /build/src/linux-6.18.44
vim init/main.c                               # or nano; make your change
exit

./laker build kernel image                    # recompiles only what you changed
./laker run                                   # try it

./laker diff kernel                           # review your edits
./laker diff kernel hello-message             # save them as a patch
git add patches && git commit -m "Say hello at boot"
```

For a first experiment, in `init/main.c` find this line:

```c
	pr_notice("%s", linux_banner);
```

Add this line right after it:

```c
	pr_notice("Hello from the LakerLinux kernel!\n");
```

Rebuild and boot. Your message appears in the boot output and in `dmesg`.

BusyBox works the same way. Its source is in `/build/src/busybox-1.36.1`, and you
use `./laker build busybox rootfs image` and `./laker diff busybox <name>`.

So does glibc: its source is in `/build/src/glibc-2.42`. After changing it, run
`./laker build glibc busybox rootfs image` (BusyBox is relinked against the new
library), and save your changes with `./laker diff glibc <name>`.

The toolchain works the same way too: `./laker diff gcc`, `./laker diff binutils`,
`./laker diff tcc` and `./laker diff make`. After changing GCC, run
`./laker build cross devtools rootfs image`; after changing TCC or make,
`./laker build devtools rootfs image`.

### Why save edits as patches?

Until you save them, your edits exist only in the build directory (for Docker,
that's the `lakerlinux-build` volume). They're lost if you run `./laker clean` or
change `KERNEL_VERSION`, and nobody else can see them.

`./laker diff kernel <name>` saves your edits as a numbered patch file, such as
`patches/kernel/0001-hello-message.patch`. Commit it to git, and:

- every build, on any machine, applies it automatically after unpacking the source;
- it shows up in pull requests, so others can review the change;
- it survives `./laker clean` and kernel upgrades (if it still applies).

This is how distributions maintain their changes to upstream software.

Each `./laker diff kernel <name>` saves only the changes made since the last
saved patch, so you build up a series: `0001-...`, `0002-...`, and so on. The
text at the top of a patch file, above the first `diff --git` line, is a
description for people to read. Edit it to explain the change.

### Commands

| Command | What it does |
|---|---|
| `./laker diff` | Lists the files you've changed (and not saved) in each source tree |
| `./laker diff kernel` | Shows those changes in full (any component works: `glibc`, `busybox`, `gcc`, ...) |
| `./laker diff kernel <name>` | Saves them as the next numbered patch in `patches/kernel/` |
| `./laker reset kernel` | Throws away unsaved changes, back to upstream plus your patches |

### How it works

When the build unpacks a release tarball, it turns the source tree into a
small git repository. It commits the pristine source and tags it `upstream`.
That takes a minute or two the first time for the kernel, and about 600 MB of
disk. Each patch in `patches/kernel/` is then applied on top as its own commit.

On every build, each stage compares `patches/` with the patches
already applied to the source. If they differ (you pulled a new patch, deleted
one, or edited one), the build resets the source to `upstream` and applies all of
`patches/` again, in name order.

The build won't do that over unsaved edits. Instead it stops and asks you to save
them (`./laker diff`) or throw them away (`./laker reset`). The trees' own
`.gitignore` files keep compiled files out of all of this, so `./laker diff`
shows only real source changes.

## The root filesystem and `rootfs-overlay/`

The rootfs stage builds the root filesystem (everything you see under `/` when
LakerLinux is running) in five layers:

1. **Empty directories**: `/dev`, `/proc`, `/sys`, `/run`, `/tmp`, `/root`,
   `/home`, `/mnt`, `/var/log`, `/etc`.
2. **BusyBox**: `make install` puts the one real program at `/bin/busybox` and
   creates a symlink for each command it provides: `/bin/ls`, `/bin/sh`,
   `/sbin/init`, `/usr/bin/vi`, and so on. When you run `ls`, BusyBox looks at the
   name it was called by and acts like `ls`.
3. **glibc**: the libraries and headers in `/usr/lib` and `/usr/include`, and
   the dynamic loader's `/lib64` link (see
   [The C library: glibc](#the-c-library-glibc)).
4. **The toolchain and disk tools**: make, the compiler(s) `COMPILER`
   chose, and `sfdisk`, `mke2fs` and `e2fsck`, from `devtools/` (see
   [Choosing a compiler](#choosing-a-compiler)). Where they have a command
   with the same name as one of BusyBox's (`ar`, `strings`, `fdisk`, ...),
   the real one replaces BusyBox's (or comes first in `PATH`). With TCC, its source goes in
   `/usr/src/tinycc`.
5. **The overlay**: everything in `rootfs-overlay/` is copied on top, keeping
   the same paths. `rootfs-overlay/etc/inittab` becomes `/etc/inittab`, and a file
   you add at `rootfs-overlay/usr/local/bin/hello` shows up as
   `/usr/local/bin/hello`.

"Overlay" here just means "copied on top". It isn't Linux's `overlayfs`. If a
file in the overlay has the same path as one BusyBox installed, the overlay's
version wins.

Last, the build writes `/etc/os-release` with the build date, and makes the
scripts in `/etc/init.d/` and the DHCP script executable.

What the overlay contains:

| File | Purpose |
|---|---|
| `etc/inittab` | Tells BusyBox `init` what to run at boot, on each terminal, and at shutdown |
| `etc/init.d/rcS` | The boot script: mounts filesystems, sets the hostname, starts networking, then runs any `/etc/init.d/S*` scripts |
| `etc/init.d/rcK` | The shutdown script: stops the `S*` scripts in reverse order and unmounts everything |
| `etc/fstab` | Filesystems for `mount -a`: `/proc`, `/sys`, and RAM-backed `tmpfs` at `/run` and `/tmp` |
| `etc/passwd`, `etc/group` | The user database. Just `root`, with an empty password field (see below) |
| `etc/hostname`, `etc/hosts` | The machine's name (`lakerlinux`) and local name lookups |
| `etc/profile` | Shell setup at login: `PATH`, the prompt, `umask` |
| `etc/issue`, `etc/motd` | Text shown before and after login |
| `usr/share/udhcpc/default.script` | Called by the DHCP client to set the IP address, route, and `/etc/resolv.conf` |
| `usr/sbin/laker-install` | Copies LakerLinux to another disk (see [Installing to a USB stick](#installing-to-a-usb-stick-or-another-disk)). The LFS system gets it too |

Finally, debug information is stripped from every program and library, which
saves well over a gigabyte with GCC. The result is about 270 MB with GCC, or
45 MB with TCC, nearly all of it the toolchain and glibc's headers and
libraries.

**File ownership.** Every file in the image is owned by root (uid 0). Docker
builds run as root. Native builds wrap `mke2fs` in `fakeroot`, which makes your
own files look root-owned while the image is written. Nothing is setuid.

**Logging in.** `/etc/passwd` contains one line:

```
root::0:0:root:/root:/bin/sh
```

The second field, normally the password hash, is empty, so `login` doesn't ask
for a password. You can run `passwd` inside LakerLinux, but the next build
rebuilds the image from the overlay, which undoes it. To set a password for every
build, put a hash (from `openssl passwd -6`) in that field of
`rootfs-overlay/etc/passwd`.

Changes you make *inside* a running LakerLinux are saved on the disk image, but
only until the next `./laker build ... image`. Anything you want to keep belongs
in `rootfs-overlay/`.

## How it boots

```
UEFI firmware                 reads the GPT partition table, finds the FAT
                              "EFI System Partition", and runs
                              \EFI\BOOT\BOOTX64.EFI
  -> Linux kernel             that file *is* the kernel (built with EFI_STUB),
                              so we don't need GRUB
    -> /init                  a tiny program built into the kernel (the
                              initramfs): finds the partition named
                              "lakerroot" and mounts it as /
      -> /sbin/init           BusyBox init reads /etc/inittab
        -> /etc/init.d/rcS    mounts /proc, /sys, ...; sets the hostname; gets
                              an IP address over DHCP
        -> getty -> login -> sh
```

The disk image (`out/lakerlinux.img`, 2 GB) has two partitions:

| # | Name (in the partition table) | Type | Size  | Contents |
|---|------|------|-------|----------|
| 1 | `LAKERBOOT` | FAT  | 64 MB | `EFI/BOOT/BOOTX64.EFI` (the kernel) |
| 2 | `lakerroot` | ext4 | rest  | the root filesystem |

Step by step:

1. **Firmware.** UEFI firmware (OVMF in QEMU) looks for a FAT partition marked
   as the "EFI System Partition". On removable media, it runs
   `\EFI\BOOT\BOOTX64.EFI` from it.
2. **Kernel.** A kernel built with `CONFIG_EFI_STUB` is also a valid UEFI
   program, so the firmware runs the kernel directly. Normally a bootloader
   tells the kernel its options. Here they're compiled in through `CONFIG_CMDLINE`:

   | Option | Meaning |
   |---|---|
   | `net.ifnames=0` | Keep the network card's traditional name, `eth0`, which both systems' network setup uses |
   | `console=tty0 console=ttyS0,115200` | Send kernel messages to the screen and to the serial port. The last one listed (serial, which `./laker run` shows you) becomes `/dev/console` |

   The kernel starts its drivers (they're built in) and finds the disks.
3. **The initramfs.** The kernel unpacks the small file system built into it
   and runs its `/init` (see [The initramfs](#the-initramfs)). That waits for
   the partition named `lakerroot` to appear, mounts it read-only on
   `/newroot`, moves `/dev` (a `devtmpfs`, where device files like `/dev/vda`
   appear by themselves) across, and makes `/newroot` the root directory.
4. **init.** `/init` runs the root filesystem's `/sbin/init`, BusyBox's `init`,
   which takes over as process 1. It reads `/etc/inittab`, which tells it to:
   - run `/etc/init.d/rcS` once;
   - keep a login prompt (`getty`) running on the serial port and on the
     first virtual terminal, restarting it after each logout;
   - run `/etc/init.d/rcK` at shutdown.
5. **rcS.** The boot script:
   - mounts everything in `/etc/fstab`, plus `/dev/pts` for terminals;
   - remounts `/` read-write (the kernel mounts it read-only so it can be
     checked first; we skip the check);
   - sets the hostname;
   - brings up the network and asks for an address over DHCP;
   - runs every executable `/etc/init.d/S*` script with `start`, in name order.
6. **Login.** `getty` prints `/etc/issue` and asks for a user name. `login`
   checks `/etc/passwd`, prints `/etc/motd`, and starts `/bin/sh`, which reads
   `/etc/profile`.

`./laker run --direct` skips step 1: QEMU loads `out/bzImage` itself and passes
the command line with `-append`.

## The initramfs

When Linux starts, it doesn't mount your root filesystem straight away. It
first unpacks an **initramfs**: a small archive of files (in `cpio` format) that
it keeps in memory. It runs that archive's `/init` program, which finds and
prepares the real root filesystem and then switches to it. Most distributions
need this step because their kernels are generic: before they can reach the
root filesystem, userspace has to load drivers, unlock an encrypted disk,
assemble RAID or LVM, or find the disk on the network.

LakerLinux's drivers are all built into the kernel, so the kernel *could* mount
the root filesystem by itself, given its ID on the command line
(`root=PARTUUID=...`). But that ID is compiled into the kernel, and a USB stick
made with [laker-install](#installing-to-a-usb-stick-or-another-disk) needs
its own. So LakerLinux's initramfs finds the root filesystem by its
partition's **name** instead, `lakerroot`, which every LakerLinux disk has.

The initramfs holds just one program, `/init`, built from
[`initramfs/init.c`](initramfs/init.c): under 400 lines of C, written to be
read. It:

1. mounts `/dev`, `/proc` and `/sys`, to see the disks the kernel has found;
2. looks in `/sys/class/block/*/uevent` for a partition whose `PARTNAME` is
   `lakerroot`, checking again every tenth of a second until one appears (USB
   disks take a few seconds);
3. if it finds more than one (say, two LakerLinux USB sticks are plugged in),
   lists them on every console and asks which to start, picking the first
   after 10 seconds;
4. mounts it read-only on `/newroot`, moves `/dev` over, and makes `/newroot`
   the root directory (what the `switch_root` command does);
5. runs `/sbin/init` from it, which takes over as process 1.

If something goes wrong it says so, and waits (Ctrl-Alt-Del restarts).

It's a static program (it carries its own copy of the C library), compiled
with the build container's compiler, so it doesn't need LakerLinux's glibc,
which isn't built yet when the kernel is. It's 800 KB. The kernel stage
compiles it and builds it into the kernel, using `CONFIG_INITRAMFS_SOURCE`.
That names [`initramfs/files.list`](initramfs/files.list), the list of
what goes in the archive: `/init`, a few empty directories, and
`/dev/console`.

**Options.** `/init` reads the kernel command line (`/proc/cmdline`). You can
add these to `KERNEL_CMDLINE` in `config/versions.sh`, or type them in when
booting through a bootloader:

| Option | Meaning |
|---|---|
| `root=/dev/sdb2` | Use this partition, instead of looking for `lakerroot` |
| `root=PARTLABEL=name` | Look for a partition with this name instead |
| `rootfstype=ext4` | The filesystem type (by default it tries every type the kernel knows) |
| `rw` | Mount the root filesystem read-write (it's read-only by default, so it can be checked; both systems' boot scripts remount it read-write) |
| `init=/bin/sh` | Run this instead of `/sbin/init`: a quick way into a broken system |

**Changing it.** Edit `initramfs/init.c` (or add files to
`initramfs/files.list`), then `./laker build kernel image`. Ideas:

- Add a rescue shell: put a static BusyBox in the initramfs, and have `/init`
  start it when something goes wrong.
- A "live" USB stick that never changes: pack the root filesystem into one
  read-only, compressed SquashFS file, and have `/init` mount it with a RAM
  disk on top (`overlayfs`), so changes vanish at reboot.
- Check the root filesystem with `e2fsck` before mounting it.

## Running LakerLinux

`./laker run` starts QEMU with:

- 1 GB of RAM (set `MEM=2G` to change it) and 2 CPUs;
- the disk image attached as a virtio disk, `/dev/vda` inside LakerLinux;
- a virtio network card, `eth0`;
- no graphical window: the serial console is your terminal.

On a Linux host where `/dev/kvm` is available, QEMU uses hardware
virtualization and boots in a few seconds. Elsewhere (including macOS) it
emulates the CPU, which is slower but works.

**Networking.** QEMU's built-in "user mode" network gives LakerLinux a private
network:

| Address | What it is |
|---|---|
| `10.0.2.15` | LakerLinux |
| `10.0.2.2` | The gateway: your computer, as seen from LakerLinux |
| `10.0.2.3` | The DNS server (QEMU forwards lookups to your computer's resolver) |

LakerLinux can reach the internet through it: try `nslookup gvsu.edu` or
`wget -O - http://example.com`. Nothing outside can connect *in* to LakerLinux
unless you add a port forward to `scripts/run.sh` (QEMU's `hostfwd` option). `ping`
to outside hosts may not work, depending on your computer's settings, even when
everything else does.

**Booting a real machine.** Write `out/lakerlinux.img` to a USB stick (see
below), turn off Secure Boot, and boot from USB in UEFI mode. The kernel
includes drivers for USB disks and keyboards, common SATA and NVMe disks, Intel
network cards, and a basic framebuffer console. Your machine's hardware may need
more (add its drivers to `config/kernel.fragment`).

## Installing to a USB stick or another disk

There are two ways to get LakerLinux onto a USB stick.

**From your computer:** write the disk image to it. On macOS:

```sh
diskutil list                          # find the stick, e.g. /dev/disk4
diskutil unmountDisk /dev/disk4
sudo dd if=out/lakerlinux.img of=/dev/rdisk4 bs=4m
```

On Linux, `lsblk` lists the disks, then
`sudo dd if=out/lakerlinux.img of=/dev/sdX bs=4M conv=fsync status=progress`.
Either way, check the name carefully: this erases the whole disk. Tools like
balenaEtcher do the same thing. The stick ends up with a 2 GB system (8 GB for
LFS), however big it is.

**From LakerLinux itself:** `laker-install` copies the running system onto
another disk, so a LakerLinux USB stick can make more of them:

```sh
laker-install          # lists the disks you could install to
laker-install sdb      # installs to /dev/sdb (asks first: it erases it)
```

It makes the same two partitions as the disk image, but with the root
partition filling the whole disk:

1. **Partitions.** `sfdisk` writes a new GPT partition table: `LAKERBOOT`, the
   same size as the running system's, then `lakerroot` with the rest.
2. **Boot partition.** `dd` copies the running system's, byte for byte. It only
   holds the kernel, `\EFI\BOOT\BOOTX64.EFI`.
3. **Root filesystem.** `mke2fs` formats `lakerroot` as ext4, and every file
   on the running system's root filesystem is copied across (`cp -ax` on the
   LFS system; `find` and `cpio` on BusyBox, whose `cp` can't stay on one
   filesystem). `/proc`, `/sys`, `/dev`, `/run` and `/tmp` are copied empty,
   since what's in them is made at boot.

Because the copy's root partition is also named `lakerroot`, the same kernel
finds it when it boots (see [The initramfs](#the-initramfs)). Each copy gets a
new partition ID, though, and on the LFS system, `laker-install` updates the
copy's `/etc/fstab` to match.

The script is [`rootfs-overlay/usr/sbin/laker-install`](rootfs-overlay/usr/sbin/laker-install),
plain `sh` that runs on both systems. BusyBox's own `fdisk` can't write GPT
partition tables and its `mke2fs` only makes ext2, so the BusyBox system gets
the real `sfdisk` (from util-linux) and `mke2fs` (from e2fsprogs); the LFS
system has them already.

**Trying it in QEMU.** `./laker run --usb` plugs in a virtual 4 GB USB stick,
`out/usb.img` (made the first time, blank). Inside LakerLinux, it's `/dev/sda`:

```sh
./laker run --usb
# log in, then:
laker-install sda
poweroff

./laker run --boot-usb     # boots from the USB stick alone
./laker run --usb          # both disks: /init asks which to start
```

To start again with a blank stick, delete `out/usb.img`.

## Everyday workflow

| You changed...                 | Run                                   |
|--------------------------------|---------------------------------------|
| something in `rootfs-overlay/` | `./laker build rootfs image`          |
| `config/kernel.fragment`       | `./laker build kernel image`          |
| `initramfs/`                   | `./laker build kernel image`          |
| kernel source code             | `./laker build kernel image`, then `./laker diff kernel <name>` to keep it |
| BusyBox config or source       | `./laker build busybox rootfs image`  |
| glibc source                   | `./laker build glibc busybox rootfs image` |
| GCC or binutils source         | `./laker build cross devtools rootfs image` |
| TCC or make source             | `./laker build devtools rootfs image` |
| util-linux or e2fsprogs source | `./laker build devtools rootfs image` |
| `COMPILER`                     | `./laker build cross devtools rootfs image` |
| a program in `rootfs-overlay/` | `./laker build rootfs image`          |
| a file in `patches/`           | `./laker build` (the stages re-apply all patches) |
| a version in `config/versions.sh` | `./laker build`                    |
| anything, and want to be sure  | `./laker build`                       |

`./laker run --direct` has QEMU load the kernel itself instead of going through
UEFI firmware. It's faster, and handy when you're iterating on the kernel.

`./laker shell` opens a shell inside the build container. The sources live in
`/build/src` there. The container has `vim`, `nano`, `git` and `less` for
editing and exploring the source, and `make menuconfig` for browsing kernel
options.

## Where to take it next

Ideas for student projects, roughly in order of difficulty:

- **Make it yours.** Change the login banner, prompt, and hostname. Add a
  non-root user, set passwords, and figure out why `login` and `su` need
  the setuid bit.
- **Boot scripts.** Add `/etc/init.d/S50hello`, then a service that starts at
  boot and stops cleanly at shutdown.
- **Hack the compiler.** With TCC, add a warning, a new keyword or a builtin
  in `/usr/src/tinycc`, rebuild it with itself, and try it out.
- **Your first package.** Start with the hello program in
  [Compiling inside LakerLinux](#compiling-inside-lakerlinux), then download
  the source of a real tool like `lua` and build it with `make`, inside
  LakerLinux. Then try `nano`, which needs a library (ncurses) built first.
- **A package format.** Design a tarball plus manifest format and write a
  `laker-pkg install` command to unpack it into the image.
- **Verify the downloads.** Have the fetch stage check kernel.org's published
  checksums (or PGP signatures) before unpacking anything.
- **Kernel hacking.** Start with the hello message in
  [Changing the kernel or BusyBox source](#changing-the-kernel-or-busybox-source).
  Write a "hello world" kernel module. Teach the build to
  compile and install modules into `/lib/modules`. Add a `/proc` file. Add a
  system call and a userspace program that calls it.
- **The initramfs.** Add a rescue shell, or make a "live" USB stick. See
  [The initramfs](#the-initramfs).
- **Replace BusyBox pieces.** Write your own `init`, your own shell, or your
  own `ls`, and swap it in for BusyBox's.
- **Replace BusyBox with the real tools.** Build GNU coreutils, bash, grep,
  sed and friends inside LakerLinux, one at a time, and install them over
  BusyBox's versions. This is the rest of the Linux From Scratch path.

## Troubleshooting

- **The kernel build fails with a weird error on a Mac.** Build in Docker (the
  default). The kernel tree has files whose names differ only in case, which
  macOS's filesystem can't store. `./laker` keeps the source in a Docker volume
  for this reason.
- **On Apple Silicon.** Both systems build and run on Apple Silicon Macs.
  The BusyBox system's build container runs natively (ARM) and cross-compiles
  for x86_64; the LFS system's container is x86_64, emulated (see below). Either
  way QEMU emulates the CPU, so `./laker run` is slower than on an Intel/AMD
  machine.
- **The TCC build fails with "rosetta error: failed to open elf at
  /lib64/ld-linux-x86-64.so.2" (Apple Silicon).** An older version of the build
  tried to run an x86_64 helper program (`c2str.exe`) in the ARM container.
  Pull the latest version of this repository and build again.
- **Compiling inside LakerLinux is slow.** Without KVM (on a Mac, or a Linux
  machine without virtualization), QEMU emulates the CPU in software. Compile
  with `./laker shell` and the cross-compiler instead (see
  [Compiling from the build container](#compiling-from-the-build-container)),
  or give QEMU more memory with `MEM=2G ./laker run`.
- **"No UEFI firmware (OVMF) found".** Install your distro's `ovmf` package, or
  use `./laker run --direct`.
- **My `menuconfig` changes disappeared.** The build regenerates `.config` every
  time. Put kernel options in `config/kernel.fragment` instead.
- **My changes inside LakerLinux disappeared.** The image is rebuilt from
  `rootfs-overlay/` each time. Put files there instead.
- **"patches/kernel/ changed, but the kernel source has unsaved edits".** A
  patch was added, removed or changed (often by a `git pull`) while you had
  edits in progress. Save your edits with `./laker diff kernel <name>`, or
  throw them away with `./laker reset kernel`, then build again.
- **"patches/kernel/NNNN-name.patch doesn't apply".** The patch was made
  for different source: another kernel version, or before an earlier patch
  changed the same lines. Fix the patch, or remove it to build without it.
- **"laker-init: waiting for a partition named "lakerroot" to appear".** The
  initramfs can't find the root filesystem. On a real machine, the kernel may
  lack the driver for that disk's controller: add it to
  `config/kernel.fragment`. A disk image made before the partitions were
  named needs `./laker build image` again.
- **"laker-init: can't run /sbin/init".** The root filesystem's `/sbin/init`
  couldn't run, usually because glibc's loader or a library is missing from
  the image. Check that `./laker build` ran the glibc and rootfs stages
  without errors.
- **laker-install says "... is mounted".** Unmount it first, e.g.
  `umount /dev/sdb1`. It won't install to a disk in use, or to the one it's
  running from.
- **glibc fails with "'-fcf-protection=full' is not supported for this target"
  (Apple Silicon).** The build container is missing the x86_64 C++
  cross-compiler, so it's using one for the wrong CPU. Pull the latest version
  of this repository; its `Dockerfile` installs `g++-x86-64-linux-gnu`. Then delete
  the glibc build folder (`rm -rf /build/glibc-build-*` in `./laker shell`) so
  `configure` runs again.
- **An LFS step failed.** The error shows the end of the step's log; the full
  log is in `/build/lfs-logs/` (`SYSTEM=lfs ./laker shell`). Fix the cause, then
  run `SYSTEM=lfs ./laker build` again: it starts from the failed step.
- **"some downloads don't match lfs/book/md5sums".** A download was cut off or
  the mirror changed a file. Delete it from `/build/lfs-sources/` and build
  again. To use a different mirror, set `LFS_MIRROR`.
- **"... still has file systems mounted from the lfs stage".** An LFS build was
  killed in chapter 7 or later. Run `SYSTEM=lfs ./laker build lfs` (it unmounts
  when it finishes), or restart Docker.
- **The LFS build is very slow on a Mac.** Its container runs as x86_64,
  emulated on Apple Silicon. Turn on Rosetta in Docker Desktop's settings, and
  give Docker as many CPUs and as much memory as you can.
- **Start over.** `./laker clean` deletes everything except downloaded tarballs
  (with `SYSTEM=lfs`, the LFS build's).
  Saved patches are safe: they're in `patches/`.
