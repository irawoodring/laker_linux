# LakerLinux

A version of Linux for Grand Valley students to use and learn with.

LakerLinux is built entirely from source by following
[Linux From Scratch](https://www.linuxfromscratch.org/lfs/view/12.4/) (LFS)
12.4, the classic step-by-step guide to building a GNU/Linux system yourself.
Every section of the book is a short script in this repository, and one command
runs them all, in Docker, then packs the result into a disk image that boots in
QEMU or on a real PC.

What you get is a complete, conventional Linux system: the GNU toolchain (GCC,
binutils, make), bash, coreutils, util-linux, Perl, Python, vim, man pages,
SysVinit with the LFS boot scripts, and about 75 other packages. It's small
enough to understand, and it's all yours to change.

- [Quick start](#quick-start)
- [What's in this repository](#whats-in-this-repository)
- [Where everything comes from](#where-everything-comes-from)
- [How the build works](#how-the-build-works)
- [Linux From Scratch, automated](#linux-from-scratch-automated)
- [Changing things](#changing-things)
- [How it boots](#how-it-boots)
- [Why there's no initramfs](#why-theres-no-initramfs)
- [Running LakerLinux](#running-lakerlinux)
- [Where to take it next](#where-to-take-it-next)
- [Troubleshooting](#troubleshooting)

## Quick start

You need **Docker** and about **30 GB of free disk**. Nothing else.

```sh
./laker build     # first build: several hours (it compiles ~80 packages)
./laker run       # boots in this terminal
```

At the `lakerlinux login:` prompt, type **`root`**. There's no password; set one
with `passwd`. Run `poweroff` when you're done. If QEMU gets stuck, press
**Ctrl-A** then **X** to kill it.

The build records each step as it finishes. If it stops (an error, a closed
laptop, Ctrl-C), run `./laker build` again and it carries on from that step.

## What's in this repository

```
laker                 the front door: build / run / lfs / shell / diff / reset / clean
Dockerfile            the build environment (compilers, QEMU, disk tools)
config/
  versions.sh         kernel version, LFS release and mirror, disk layout, kernel command line
  kernel.fragment     kernel options, applied on top of the x86_64 defaults
lfs/                  Linux From Scratch, one script per book section
  book/               the book's package list (wget-list-sysv) and checksums (md5sums)
  4-prepare/          chapter 4: the new system's top-level directories
  5-cross-toolchain/  chapter 5: a cross-compiler
  6-temporary-tools/  chapter 6: basic tools, cross-compiled
  7-chroot/           chapter 7: entering the new system; a few more tools
  8-system/           chapter 8: the final system, package by package
  9-config/           chapters 9-11: boot scripts, network, locale, fstab
patches/              changes to upstream source
  kernel/             *.patch files applied to the kernel, in name order
  lfs/                *.patch files applied to LFS packages
rootfs-overlay/       LakerLinux's own files, copied on top of the LFS system
scripts/
  build.sh            the build's stages: fetch, kernel, lfs, rootfs, image
  lfs.sh              runs the lfs/ scripts in order, inside a chroot from chapter 7
  lfs-step.sh         runs one lfs/ script: unpack, patch, build, clean up
  run.sh              boots the image in QEMU
  source.sh           ./laker diff and ./laker reset
  common.sh           settings shared by the scripts
tools/
  extract-book.py     generates lfs/ scripts from the LFS book (for upgrading)
out/                  (generated) lakerlinux.img and bzImage
```

## Where everything comes from

| Piece | Where it comes from | Set in |
|---|---|---|
| Linux kernel | The release tarball from [kernel.org](https://www.kernel.org) | `config/versions.sh` (`KERNEL_VERSION`, `KERNEL_URL`) |
| Everything else (95 packages and patches) | The versions in LFS 12.4, from the [LFS project's mirror](https://ftp.osuosl.org/pub/lfs/lfs-packages/12.4/); LFS's own boot scripts from [linuxfromscratch.org](https://www.linuxfromscratch.org/lfs/downloads/12.4/) | `lfs/book/wget-list-sysv`, `config/versions.sh` (`LFS_MIRROR`) |
| How to build each package | The [LFS 12.4 book](https://www.linuxfromscratch.org/lfs/view/12.4/), section by section | `lfs/` |
| Compilers and tools to build with | Ubuntu 24.04 packages, in the Docker image | `Dockerfile` |

Every download is checked against the book's MD5 checksums (`lfs/book/md5sums`)
before anything is built. `./laker lfs download` fetches and checks everything
without building, if you want to download ahead of time.

The kernel is Linux 6.18.44, a newer long-term-support release than the book's
6.16.1. The book's 6.16.1 is still downloaded, because chapter 5 uses its headers.

## How the build works

`./laker build` runs `scripts/build.sh` inside a Docker container built from
`Dockerfile`. It runs five stages, or any of them on its own
(`./laker build image`):

1. **fetch**: download and unpack the kernel source.
2. **kernel**: configure and build the kernel (see
   [How it boots](#how-it-boots)).
   - `make x86_64_defconfig` starts from the kernel's standard x86_64 defaults.
   - `config/kernel.fragment` adds LakerLinux's options, including everything
     LFS section 10.3 asks for.
   - The kernel command line, `KERNEL_CMDLINE` in `config/versions.sh`, is
     built in.
3. **lfs**: build the whole Linux From Scratch system (next section). This is
   most of the time.
4. **rootfs**: copy `rootfs-overlay/` (LakerLinux's login banner and welcome
   message) on top of it.
5. **image**: pack the kernel and the new system into `out/lakerlinux.img`, an 8
   GB disk image (a sparse file: unused space takes no room on your disk).

The build directory lives in a Docker volume, `lakerlinux-lfs-build` (`/build`
in the container):

```
downloads/       the kernel tarball
src/linux-*/     the kernel source tree (with a .git that tracks your edits)
lfs-sources/     the LFS packages and patches (the book's $LFS/sources)
lfs/             the new system: the book's $LFS
lfs-done/        one file per finished LFS step
lfs-logs/        each LFS step's output
```

`./laker shell` opens a shell in the container if you want to look around.

## Linux From Scratch, automated

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

### What happens in each step

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

### Where each chapter runs

| Chapters | Where | Environment |
|---|---|---|
| 4 to 6 | In the build container | The variables the book sets up in section 4.4: `LFS`, `LFS_TGT`, a `PATH` starting with the new cross-compiler, `LC_ALL=POSIX`, `CONFIG_SITE` |
| 7 to 11 | Inside the new system, with `chroot` (section 7.4) | `/dev`, `/proc`, `/sys` and `/run` mounted as in section 7.3, and a clean environment |

This is why the build container runs with `--privileged`: mounting those file
systems needs it.

### Commands

| Command | What it does |
|---|---|
| `./laker lfs status` | Lists every step, marking the finished ones |
| `./laker lfs redo 8-system/35-bash.sh` | Runs one step again |
| `./laker lfs download` | Downloads and checks the sources only |
| `./laker build lfs` | Runs every unfinished step (part of `./laker build`) |

### Where LakerLinux differs from the book

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

## Changing things

### An LFS package's build

Edit its script in `lfs/`, then run it again:

```sh
vim lfs/8-system/72-vim.sh
./laker lfs redo 8-system/72-vim.sh
./laker build rootfs image
```

Later packages that depend on it aren't rebuilt automatically. Redo those too,
or delete `lfs-done/` in the build directory to rebuild everything.

### An LFS package's source

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

### The kernel

The kernel source is kept, tracked with git, so you can edit it directly and
save your changes as patches:

```sh
./laker shell
cd /build/src/linux-6.18.44
vim init/main.c                               # make your change
exit

./laker build kernel image                    # recompiles only what you changed
./laker run

./laker diff kernel                           # review your edits
./laker diff kernel hello-message             # save them as patches/kernel/0001-hello-message.patch
git add patches && git commit -m "Say hello at boot"
```

For a first experiment, in `init/main.c` find `pr_notice("%s", linux_banner);`
and add `pr_notice("Hello from the LakerLinux kernel!\n");` after it. Your message
appears in the boot output and in `dmesg`.

`./laker reset kernel` throws away edits you haven't saved. Saved patches apply
automatically on every build, on every machine, and survive `./laker clean`.
When `patches/kernel/` changes (after a `git pull`, say), the build resets the
kernel source and applies them all again, but it stops first if you have unsaved
edits.

Kernel options go in `config/kernel.fragment`. The kernel stage regenerates
`.config` every build, so changes made with `make menuconfig` don't last; use it
to explore, then copy the options you want into the fragment.

### LakerLinux's own files

Anything in `rootfs-overlay/` is copied into the system by the rootfs stage, at
the same path, over whatever LFS installed. Then run
`./laker build rootfs image`.

## How it boots

```
UEFI firmware           finds the FAT "EFI System Partition" and runs
                        \EFI\BOOT\BOOTX64.EFI
  -> Linux kernel       that file *is* the kernel (built with EFI_STUB), so
                        there's no bootloader. Its built-in command line says
                        which partition is the root file system.
    -> /sbin/init       SysVinit (LFS 8.82) reads /etc/inittab
      -> rc S, rc 3     the LFS boot scripts (LFS 9.2): mount file systems,
                        start udev, check and remount /, set the clock and
                        host name, bring up eth0, start syslog
      -> agetty -> login -> bash
```

The disk image (`out/lakerlinux.img`) has two partitions:

| # | Type | Size | Contents |
|---|------|------|----------|
| 1 | FAT  | 64 MB | `EFI/BOOT/BOOTX64.EFI` (the kernel) |
| 2 | ext4 | the rest | the LFS system, partition UUID `4c414b45-5200-4c49-4e55-580000000002` |

The kernel command line (`KERNEL_CMDLINE` in `config/versions.sh`):

| Option | Meaning |
|---|---|
| `root=PARTUUID=4c414b45-...-02` | Mount this partition as `/`. The ID is fixed, so it's the same in every build; `/etc/fstab` uses it too |
| `rootwait` | Wait for that disk to appear instead of giving up |
| `net.ifnames=0` | Call the network card `eth0`, the name LFS's network configuration uses |
| `console=tty0 console=ttyS0,115200` | Kernel messages on the screen and the serial port; the serial port, the one `./laker run` shows you, is `/dev/console` |

`./laker run --direct` skips the firmware: QEMU loads `out/bzImage` itself.

## Why there's no initramfs

Most distributions boot through an **initramfs**: a small archive of files the
kernel unpacks into memory and runs first. Its job is to get the real root file
system ready, by loading disk and file system drivers, unlocking encryption or
assembling RAID, before switching to it. Generic distribution kernels need that
because their drivers are modules on the disk they're trying to reach.

LakerLinux doesn't. Its disk drivers and ext4 are built into the kernel, and the
kernel can find a partition by its PARTUUID by itself. So it mounts the root
file system directly and starts `/sbin/init`. The boot message
`check access for rdinit=/init failed: -2, ignoring` is the kernel looking for
an initramfs and not finding one; that's expected.

Adding one makes a good project: build a directory with a statically linked
shell and an `/init` script that mounts the real root and runs `switch_root`,
then point `CONFIG_INITRAMFS_SOURCE` at it in `config/kernel.fragment`.

## Running LakerLinux

`./laker run` starts QEMU with 1 GB of RAM (set `MEM=2G` to change it), 2 CPUs,
the disk image as a virtio disk (`/dev/vda`), and a virtio network card
(`eth0`). There's no window: the serial console is your terminal.

On a Linux computer with `/dev/kvm`, QEMU uses hardware virtualization and
LakerLinux boots in seconds. Elsewhere, including on a Mac, QEMU emulates the
CPU in software: it works, but slowly.

**Networking.** QEMU's "user mode" network has fixed addresses, which
`lfs/9-config/02-network.sh` sets up statically:

| Address | What it is |
|---|---|
| `10.0.2.15` | LakerLinux (`eth0`) |
| `10.0.2.2` | The gateway: your computer, as seen from LakerLinux |
| `10.0.2.3` | The DNS server (QEMU forwards to your computer's) |

To boot a real machine, write `out/lakerlinux.img` to a USB stick, turn off
Secure Boot, and boot from USB in UEFI mode. Change `/etc/sysconfig/ifconfig.eth0`
to suit your network first, or build a DHCP client (see below).

## Where to take it next

- **Make it yours.** Add a user with `useradd`, set passwords, change the
  boot banner, write a boot script in `/etc/rc.d/init.d/`.
- **Read along.** Pick a package, read its page in the book and its script, and
  explain every command. Run its test suite.
- **Beyond Linux From Scratch.** [BLFS](https://www.linuxfromscratch.org/blfs/)
  is the next book: DHCP (`dhcpcd`), SSH, `wget`, `git`, a web server, X. Build
  them inside LakerLinux, then add them to the build as new scripts in `lfs/`.
- **A package manager.** LFS section 8.2 discusses the options. Install each
  package into its own `DESTDIR` and track what it installed.
- **Kernel hacking.** Start with the hello message in [The kernel](#the-kernel).
  Write a kernel module, add a `/proc` file, add a system call.
- **An initramfs.** See [Why there's no initramfs](#why-theres-no-initramfs).
- **Upgrade to the next LFS release.** Run `tools/extract-book.py` on the new
  book, compare with `lfs/`, and carry over the `LakerLinux:` changes.

## Troubleshooting

- **A step failed.** The error shows the end of the step's log; the full log is
  in `/build/lfs-logs/` (`./laker shell`). Fix the cause, then run
  `./laker build` again: it starts from the failed step.
- **"some downloads don't match lfs/book/md5sums".** A download was cut off or
  the mirror changed a file. Delete that file from `/build/lfs-sources/` and run
  the build again. To use a different mirror, set `LFS_MIRROR`.
- **"... still has file systems mounted from the lfs stage".** A build was
  killed in chapter 7 or later. Run `./laker build lfs` (it unmounts when it
  finishes), or restart Docker.
- **It's very slow on a Mac.** The build container runs as x86_64, emulated on
  Apple Silicon (enable Rosetta in Docker Desktop's settings for the best
  speed). Expect the first build to take several times longer than on an
  Intel/AMD computer, and give Docker as many CPUs and as much memory as you can.
- **Docker refuses `--privileged`.** Docker Desktop allows it by default. Some
  managed setups (e.g. rootless Docker) don't, and the LFS build can't run there.
- **"No UEFI firmware (OVMF) found".** Use `./laker run --direct`.
- **Start over.** `./laker clean` deletes everything except downloaded sources.
  Saved patches are safe: they're in `patches/`.
