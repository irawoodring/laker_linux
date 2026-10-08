# LakerLinux

A version of Linux for students to use and learn with.

It's a tiny distribution you build from source, for learning how an
operating system goes together: the kernel, the boot process, init, the
shell, and the build tools that tie it all together.

It starts out deliberately small: a Linux kernel, the
[GNU C library](https://www.gnu.org/software/libc/) (glibc), and
[BusyBox](https://busybox.net) (one program that provides `sh`, `ls`, `mount`,
`vi`, `ip`, and ~300 other commands), packed into a disk image that boots in QEMU
or on a real PC. Everything else is up to you.

- [Quick start](#quick-start)
- [What's in this repository](#whats-in-this-repository)
- [Where everything comes from](#where-everything-comes-from)
- [How the build works](#how-the-build-works)
- [The C library: glibc](#the-c-library-glibc)
- [Changing the kernel or BusyBox source](#changing-the-kernel-or-busybox-source)
- [The root filesystem and `rootfs-overlay/`](#the-root-filesystem-and-rootfs-overlay)
- [How it boots](#how-it-boots)
- [Why there's no initramfs](#why-theres-no-initramfs)
- [Running LakerLinux](#running-lakerlinux)
- [Everyday workflow](#everyday-workflow)
- [Where to take it next](#where-to-take-it-next)
- [Troubleshooting](#troubleshooting)

## Quick start

You need **Docker** and about **12 GB of disk**. Nothing else.

```sh
./laker build     # first build: ~15-45 min, mostly the kernel and glibc
./laker run       # boots in this terminal
```

At the `lakerlinux login:` prompt, type **`root`**. There's no password.
Inside LakerLinux, run `poweroff` when you're done. If it gets stuck, press
**Ctrl-A** then **X** to kill QEMU.

Rebuilding after a change only redoes what changed, so later builds take seconds
to minutes.

### Without Docker (Linux only)

On Debian/Ubuntu, install the toolchain once and set `LAKER_NATIVE=1`:

```sh
sudo apt install build-essential bc bison flex libelf-dev libssl-dev cpio \
    curl xz-utils bzip2 python3 e2fsprogs dosfstools mtools fdisk fakeroot \
    qemu-system-x86 ovmf rsync gawk
LAKER_NATIVE=1 ./laker build
LAKER_NATIVE=1 ./laker run
```

## What's in this repository

```
laker                 the front door: build / run / shell / diff / reset / clean
Dockerfile            the build environment (compilers, QEMU, disk tools)
config/
  versions.sh         kernel, glibc and BusyBox versions, download URLs, disk layout
  kernel.fragment     kernel options, applied on top of the x86_64 defaults
patches/              your changes to the kernel, glibc and BusyBox source
  kernel/             *.patch files applied to the kernel, in name order
  glibc/              *.patch files applied to glibc
  busybox/            *.patch files applied to BusyBox
rootfs-overlay/       files copied onto the root filesystem as-is
  etc/inittab         what init (PID 1) starts
  etc/init.d/rcS      the boot script
  etc/init.d/rcK      the shutdown script
  etc/passwd, ...     users, hostname, shell profile, login banner
  usr/share/udhcpc/   the script that applies DHCP settings
scripts/
  build.sh            the whole build, in six readable stages
  run.sh              boots the image in QEMU
  source.sh           ./laker diff and ./laker reset
  common.sh           settings shared by the scripts, and the patch handling
build/                (generated, native builds only) sources and intermediate files
out/                  (generated) lakerlinux.img and bzImage
```

The repository holds only *our* files: configuration, scripts, patches, and the
overlay. The kernel, glibc and BusyBox sources are downloaded during the build
and never committed. Changes to them are kept in `patches/`.

## Where everything comes from

| Piece | Where it comes from | Set in |
|---|---|---|
| Linux kernel source | The official release tarball from [kernel.org](https://www.kernel.org): `cdn.kernel.org/pub/linux/kernel/v6.x/linux-<version>.tar.xz` | `config/versions.sh` (`KERNEL_VERSION`, `KERNEL_URL`) |
| glibc source | The official release tarball from the [GNU project](https://ftp.gnu.org/gnu/glibc/): `glibc-<version>.tar.xz` | `config/versions.sh` (`GLIBC_VERSION`, `GLIBC_URL`) |
| BusyBox source | The official release tarball from [busybox.net](https://busybox.net/downloads/): `busybox-<version>.tar.bz2` | `config/versions.sh` (`BUSYBOX_VERSION`, `BUSYBOX_URL`) |
| Compilers, `make`, disk tools, QEMU, UEFI firmware | Ubuntu 24.04 packages, installed into the Docker image by `Dockerfile` (or by you, for a native build) | `Dockerfile` |
| Changes to the kernel, glibc and BusyBox source | This repository: `patches/kernel/`, `patches/glibc/` and `patches/busybox/` | |
| DHCP client script | BusyBox's own example, `examples/udhcp/simple.script`, copied into the overlay | `rootfs-overlay/usr/share/udhcpc/default.script` |
| Everything else in the image | This repository: `rootfs-overlay/`, plus a few files the build writes (see below) | |

The versions are pinned: currently **Linux 6.18.44** (a long-term-support
series), **glibc 2.42** and **BusyBox 1.36.1**. To upgrade, change the version in
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

`./laker build` runs `scripts/build.sh`. Under Docker, it runs inside a
container built from `Dockerfile`, which `./laker` builds the first time you use
it. The script runs six stages in order. You can also run any subset, e.g.
`./laker build rootfs image`.

1. **fetch**: download and unpack the kernel, glibc and BusyBox sources, if
   they aren't already there, and apply `patches/` (see
   [Changing the kernel or BusyBox source](#changing-the-kernel-or-busybox-source)).
2. **kernel**: configure and compile Linux.
   - Bring the source up to date with `patches/kernel/`.
   - `make x86_64_defconfig` starts from the kernel's standard x86_64 defaults.
   - `scripts/kconfig/merge_config.sh` layers `config/kernel.fragment` on top.
   - The build also adds `CONFIG_CMDLINE`, the built-in kernel command line (see
     [How it boots](#how-it-boots)).
   - `make olddefconfig` fills in anything that depends on those choices.
   - `make bzImage` builds the compressed kernel, which is copied to `out/bzImage`.
3. **glibc**: build the C library into the *sysroot* (see
   [The C library: glibc](#the-c-library-glibc)).
   - Bring the source up to date with `patches/glibc/`.
   - `make headers_install` copies the kernel's headers into the sysroot.
   - `configure` sets up a build folder outside the source tree (glibc
     requires that). This only happens the first time.
   - `make`, then `make install DESTDIR=<sysroot>`.
4. **busybox**: bring the source up to date with `patches/busybox/`, then
   configure and compile BusyBox. It starts from BusyBox's `defconfig`
   (nearly every command enabled), then:
   - points it at the sysroot (`CONFIG_SYSROOT`), so it links against our glibc
     instead of the build container's C library;
   - turns off `tc`, which doesn't compile against current kernel headers.
5. **rootfs**: assemble the root filesystem as a plain directory (see
   [The root filesystem](#the-root-filesystem-and-rootfs-overlay)).
6. **image**: pack the kernel and that directory into `out/lakerlinux.img`.
   - Format a FAT filesystem image and copy the kernel into it as
     `EFI/BOOT/BOOTX64.EFI` (`mkfs.vfat`, `mmd`, `mcopy`).
   - Format an ext4 image straight from the rootfs directory (`mke2fs -d`).
   - Write a GPT partition table into an empty 512 MB file (`sfdisk`), then copy
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
glibc-build-2.42/       where glibc is compiled (glibc doesn't build inside its source tree)
kernel-headers/         the kernel's headers, staged before they're copied into the sysroot
sysroot/                glibc and the kernel headers, for compiling programs for LakerLinux
kernel.fragment         the fragment as actually applied, with CONFIG_CMDLINE added
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

The rootfs stage copies only what programs need at run time: the files in
`sysroot/usr/lib` named `*.so.*`, with debug information stripped (about 75 MB
down to 5 MB). It also adds one symlink:

```
/lib64/ld-linux-x86-64.so.2 -> ../usr/lib/ld-linux-x86-64.so.2
```

Every x86_64 Linux program has the `/lib64` path built in, so the link has to be
there, even though LakerLinux keeps its libraries in `/usr/lib`.

BusyBox is now one of those programs. Because it's also `init`, the system
can't start without glibc: if the loader or `libc.so.6` were missing, the kernel
would stop with `Kernel panic - not syncing: No working init found`.

### Compiling your own programs

In `./laker shell`, compile with the cross-compiler and the sysroot, then put the
program in `rootfs-overlay/`. The repository is mounted at `/lakerlinux` in the
container.

```c
// hello.c
#include <stdio.h>
#include <gnu/libc-version.h>

int main(void)
{
    printf("Hello from glibc %s!\n", gnu_get_libc_version());
    return 0;
}
```

```sh
./laker shell
mkdir -p /lakerlinux/rootfs-overlay/usr/local/bin
x86_64-linux-gnu-gcc --sysroot=/build/sysroot -O2 \
    -o /lakerlinux/rootfs-overlay/usr/local/bin/hello hello.c
exit
./laker build rootfs image && ./laker run
```

Then, inside LakerLinux:

```sh
hello                                                    # Hello from glibc 2.42!
/lib64/ld-linux-x86-64.so.2 --list /usr/local/bin/hello  # which libraries it loads
/usr/lib/libc.so.6                                       # glibc prints its own version
```

There's no `ldd` command: glibc's `ldd` is a bash script, and LakerLinux has no
bash. Running the loader with `--list` does the same job.

Use `x86_64-linux-gnu-gcc`, not plain `gcc`. On an Intel/AMD machine they're the
same compiler, but on Apple Silicon only `x86_64-linux-gnu-gcc` builds x86_64 code.

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
| `./laker diff kernel` | Shows those changes in full (`glibc` and `busybox` work too) |
| `./laker diff kernel <name>` | Saves them as the next numbered patch in `patches/kernel/` |
| `./laker reset kernel` | Throws away unsaved changes, back to upstream plus your patches |

### How it works

When the build unpacks a release tarball, it turns the source tree into a
small git repository. It commits the pristine source and tags it `upstream`.
That takes a minute or two the first time for the kernel, and about 600 MB of
disk. Each patch in `patches/kernel/` is then applied on top as its own commit.

On every build, the kernel, glibc and busybox stages compare `patches/` with the patches
already applied to the source. If they differ (you pulled a new patch, deleted
one, or edited one), the build resets the source to `upstream` and applies all of
`patches/` again, in name order.

The build won't do that over unsaved edits. Instead it stops and asks you to save
them (`./laker diff`) or throw them away (`./laker reset`). The trees' own
`.gitignore` files keep compiled files out of all of this, so `./laker diff`
shows only real source changes.

## The root filesystem and `rootfs-overlay/`

The rootfs stage builds the root filesystem (everything you see under `/` when
LakerLinux is running) in four layers:

1. **Empty directories**: `/dev`, `/proc`, `/sys`, `/run`, `/tmp`, `/root`,
   `/home`, `/mnt`, `/var/log`, `/etc`.
2. **BusyBox**: `make install` puts the one real program at `/bin/busybox` and
   creates a symlink for each command it provides: `/bin/ls`, `/bin/sh`,
   `/sbin/init`, `/usr/bin/vi`, and so on. When you run `ls`, BusyBox looks at the
   name it was called by and acts like `ls`.
3. **glibc**: the shared libraries in `/usr/lib`, and the dynamic loader's
   `/lib64` link (see [The C library: glibc](#the-c-library-glibc)).
4. **The overlay**: everything in `rootfs-overlay/` is copied on top, keeping
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

The result is about 6 MB: 5 MB of glibc libraries, plus BusyBox and the
overlay.

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
                              so we don't need GRUB. It mounts the root
                              filesystem named in its built-in command line.
    -> /sbin/init             BusyBox init reads /etc/inittab
      -> /etc/init.d/rcS      mounts /proc, /sys, ...; sets the hostname; gets
                              an IP address over DHCP
      -> getty -> login -> sh
```

The disk image (`out/lakerlinux.img`, 512 MB) has two partitions:

| # | Type | Size  | Contents |
|---|------|-------|----------|
| 1 | FAT  | 64 MB | `EFI/BOOT/BOOTX64.EFI` (the kernel) |
| 2 | ext4 | rest  | the root filesystem, with partition UUID `4c414b45-5200-4c49-4e55-580000000002` |

Step by step:

1. **Firmware.** UEFI firmware (OVMF in QEMU) looks for a FAT partition marked
   as the "EFI System Partition". On removable media, it runs
   `\EFI\BOOT\BOOTX64.EFI` from it.
2. **Kernel.** A kernel built with `CONFIG_EFI_STUB` is also a valid UEFI
   program, so the firmware runs the kernel directly. Normally a bootloader
   tells the kernel its options. Here they're compiled in through `CONFIG_CMDLINE`:

   | Option | Meaning |
   |---|---|
   | `root=PARTUUID=4c414b45-...-02` | Mount the partition with this GPT ID as `/`. The ID is fixed in `config/versions.sh`, so it's the same in every build |
   | `rootwait` | Wait for that disk to appear instead of giving up: USB and NVMe disks show up a moment after boot starts |
   | `console=tty0 console=ttyS0,115200` | Send kernel messages to the screen and to the serial port. The last one listed (serial, which `./laker run` shows you) becomes `/dev/console` |

   The kernel finds its drivers (they're built in), mounts the ext4 partition
   read-only, and mounts `devtmpfs` on `/dev`, so device files like `/dev/vda`
   appear without any help from userspace.
3. **init.** The kernel runs `/sbin/init`, BusyBox's `init`, as process 1. It
   reads `/etc/inittab`, which tells it to:
   - run `/etc/init.d/rcS` once;
   - keep a login prompt (`getty`) running on the serial port and on the
     first virtual terminal, restarting it after each logout;
   - run `/etc/init.d/rcK` at shutdown.
4. **rcS.** The boot script:
   - mounts everything in `/etc/fstab`, plus `/dev/pts` for terminals;
   - remounts `/` read-write (the kernel mounts it read-only so it can be
     checked first; we skip the check);
   - sets the hostname;
   - brings up the network and asks for an address over DHCP;
   - runs every executable `/etc/init.d/S*` script with `start`, in name order.
5. **Login.** `getty` prints `/etc/issue` and asks for a user name. `login`
   checks `/etc/passwd`, prints `/etc/motd`, and starts `/bin/sh`, which reads
   `/etc/profile`.

`./laker run --direct` skips step 1: QEMU loads `out/bzImage` itself and passes
the command line with `-append`.

## Why there's no initramfs

On most distributions, the kernel doesn't mount your real root filesystem
first. Instead it unpacks an **initramfs**: a small archive (in `cpio` format) of
files that's loaded into memory along with the kernel. The kernel runs that
archive's `/init` program, which prepares the real root filesystem and then
switches to it. Distributions need this step because their kernels are generic:
they can only reach the root filesystem after userspace has done some setup, such
as:

- loading the kernel modules for the disk controller and filesystem;
- unlocking an encrypted disk, or assembling RAID or LVM volumes;
- finding the root filesystem by label or UUID, or over the network.

LakerLinux needs none of that. The storage drivers and ext4 are compiled into
the kernel, and the kernel can find a partition by its PARTUUID by itself. So it
mounts the root filesystem directly and runs `/sbin/init` from it.

You may notice this line in the boot messages:

```
check access for rdinit=/init failed: -2, ignoring
```

The kernel always checks for an initramfs `/init` first (its built-in initramfs
is empty, since `CONFIG_INITRAMFS_SOURCE` is unset). Error -2 means "no such
file", so it moves on to the `root=` partition. That's expected.

Adding an initramfs makes a good project. Build a directory with BusyBox (and
the glibc files it needs, or a separate static BusyBox) and an `/init` script that mounts the real root and runs `switch_root`, then
either:

- point `CONFIG_INITRAMFS_SOURCE` at it in `config/kernel.fragment` to build it into the kernel; or
- pack it with `cpio` and load it separately (`-initrd` in QEMU, or `initrd=` on
  the EFI stub's command line).

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

**Booting a real machine.** Write `out/lakerlinux.img` to a USB stick (with
`dd`, or a tool like balenaEtcher), turn off Secure Boot, and boot from USB in
UEFI mode. The kernel includes drivers for common SATA and NVMe disks, Intel
network cards, and a basic framebuffer console. Your machine's hardware may need
more.

## Everyday workflow

| You changed...                 | Run                                   |
|--------------------------------|---------------------------------------|
| something in `rootfs-overlay/` | `./laker build rootfs image`          |
| `config/kernel.fragment`       | `./laker build kernel image`          |
| kernel source code             | `./laker build kernel image`, then `./laker diff kernel <name>` to keep it |
| BusyBox config or source       | `./laker build busybox rootfs image`  |
| glibc source                   | `./laker build glibc busybox rootfs image` |
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
- **Your first package.** Start with the hello program in
  [Compiling your own programs](#compiling-your-own-programs), then build a
  real tool like `lua`, `nano` (which needs ncurses: a second library to build
  into the sysroot) or `htop`, and install it into the image.
- **A package format.** Design a tarball plus manifest format and write a
  `laker-pkg install` command to unpack it into the image.
- **Verify the downloads.** Have the fetch stage check kernel.org's published
  checksums (or PGP signatures) before unpacking anything.
- **Kernel hacking.** Start with the hello message in
  [Changing the kernel or BusyBox source](#changing-the-kernel-or-busybox-source).
  Write a "hello world" kernel module. Teach the build to
  compile and install modules into `/lib/modules`. Add a `/proc` file. Add a
  system call and a userspace program that calls it.
- **An initramfs.** See [Why there's no initramfs](#why-theres-no-initramfs).
- **Replace BusyBox pieces.** Write your own `init`, your own shell, or your
  own `ls`, and swap it in for BusyBox's.
- **A real toolchain.** Build binutils and GCC that run *on* LakerLinux, against
  its glibc, so you can compile software inside it. This is the Linux From
  Scratch path.

## Troubleshooting

- **The kernel build fails with a weird error on a Mac.** Build in Docker (the
  default). The kernel tree has files whose names differ only in case, which
  macOS's filesystem can't store. `./laker` keeps the source in a Docker volume
  for this reason.
- **On Apple Silicon.** The container cross-compiles for x86_64 and QEMU
  emulates the CPU, so `./laker run` is slower than on an Intel/AMD machine.
  (This path hasn't been tested as much as x86_64 Linux hosts yet.)
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
- **"Kernel panic - not syncing: No working init found".** The kernel couldn't
  run BusyBox as `init`, usually because glibc's loader or a library is missing
  from the image. Check that `./laker build` ran the glibc and rootfs stages
  without errors.
- **glibc fails with "'-fcf-protection=full' is not supported for this target"
  (Apple Silicon).** The build container is missing the x86_64 C++
  cross-compiler, so it's using one for the wrong CPU. Pull the latest version
  of this repository; its `Dockerfile` installs `g++-x86-64-linux-gnu`. Then delete
  the glibc build folder (`rm -rf /build/glibc-build-*` in `./laker shell`) so
  `configure` runs again.
- **Start over.** `./laker clean` deletes everything except downloaded tarballs.
  Saved patches are safe: they're in `patches/`.
