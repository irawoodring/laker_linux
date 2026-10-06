# LakerLinux

A version of Linux for Grand Valley students to use and learn with.

It's a tiny distribution you build from source, for learning how an
operating system goes together: the kernel, the boot process, init, the
shell, and the build tools that tie it all together.

It starts out deliberately small: a Linux kernel plus [BusyBox](https://busybox.net)
(one static binary that provides `sh`, `ls`, `mount`, `vi`, `ip`, and ~300 other
commands), packed into a disk image that boots in QEMU or on a real PC.
Everything else is up to you.

## Quick start

You need **Docker** and about **10 GB of disk**. Nothing else.

```sh
./laker build     # first build: ~10-30 min, mostly the kernel
./laker run       # boots in this terminal; log in as root (no password)
```

Inside LakerLinux, run `poweroff` when you're done. If it gets stuck, press **Ctrl-A**
then **X** to kill QEMU.

Rebuilding after a change only redoes what changed, so later builds take seconds
to minutes.

### Without Docker (Linux only)

On Debian/Ubuntu, install the toolchain once and set `LAKER_NATIVE=1`:

```sh
sudo apt install build-essential bc bison flex libelf-dev libssl-dev cpio \
    curl xz-utils bzip2 python3 e2fsprogs dosfstools mtools fdisk fakeroot \
    qemu-system-x86 ovmf
LAKER_NATIVE=1 ./laker build
LAKER_NATIVE=1 ./laker run
```

## What's in here

```
laker                 the front door: build / run / shell / clean
Dockerfile            the build environment (compilers, QEMU, disk tools)
config/
  versions.sh         kernel and BusyBox versions, disk size
  kernel.fragment     kernel options, applied on top of the x86_64 defaults
rootfs-overlay/       files copied onto the root filesystem as-is
  etc/inittab         what init (PID 1) starts
  etc/init.d/rcS      the boot script
  etc/passwd, ...     users, hostname, shell profile, login banner
scripts/
  build.sh            the whole build, in five readable stages
  run.sh              boots the image in QEMU
out/                  (generated) lakerlinux.img and bzImage
```

## How it boots

```
UEFI firmware                 reads the GPT partition table, finds the FAT
                              "EFI System Partition", and runs
                              \EFI\BOOT\BOOTX64.EFI
  -> Linux kernel             that file *is* the kernel (built with EFI_STUB),
                              so we don't need GRUB. Its built-in command line
                              says the root filesystem is the partition with
                              PARTUUID 4c414b45-...-02.
    -> /sbin/init             BusyBox init reads /etc/inittab
      -> /etc/init.d/rcS      mounts /proc, /sys, ...; sets the hostname; gets
                              an IP address over DHCP
      -> getty -> login -> sh
```

The disk image (`out/lakerlinux.img`, 512 MB) has two partitions:

| # | Type | Size  | Contents                          |
|---|------|-------|-----------------------------------|
| 1 | FAT  | 64 MB | `EFI/BOOT/BOOTX64.EFI` (the kernel) |
| 2 | ext4 | rest  | the root filesystem               |

`scripts/build.sh` creates it without root access or loop devices: it formats
each filesystem as an ordinary file, writes a partition table with `sfdisk`, and
`dd`s each filesystem into place.

## Everyday workflow

| You changed...                 | Run                                   |
|--------------------------------|---------------------------------------|
| something in `rootfs-overlay/` | `./laker build rootfs image`          |
| `config/kernel.fragment`       | `./laker build kernel image`          |
| kernel source code             | `./laker build kernel image`          |
| BusyBox config/source          | `./laker build busybox rootfs image`  |
| anything, and want to be sure  | `./laker build`                       |

`./laker run --direct` has QEMU load the kernel itself instead of going through
UEFI firmware. It's faster, and handy when you're iterating on the kernel.

`./laker shell` opens a shell inside the build container. The sources live in
`/build/src` there, for running `make menuconfig` and other tools by hand.

Booting a real machine: write `out/lakerlinux.img` to a USB stick (with `dd`, or
a tool like balenaEtcher), turn off Secure Boot, and boot from USB in UEFI mode.

## Where to take it next

Ideas for student projects, roughly in order of difficulty:

- **Make it yours.** Change the login banner, prompt, and hostname. Add a
  non-root user, set passwords, and figure out why `login` and `su` need
  the setuid bit.
- **Boot scripts.** Add `/etc/init.d/S50hello`, then a service that starts at
  boot and stops cleanly at shutdown.
- **Your first package.** Cross-compile a C program (or a tool like `htop`,
  `nano`, or `lua`) and install it into the image. Static linking is easy.
  Dynamic linking means shipping a C library: that's a good lesson in itself.
- **A package format.** Design a tarball plus manifest format and write a
  `laker-pkg install` command to unpack it into the image.
- **Kernel hacking.** Write a "hello world" kernel module. Add a `/proc` file.
  Add a system call and a userspace program that calls it.
- **Replace BusyBox pieces.** Write your own `init`, your own shell, or your
  own `ls`, and swap it in for BusyBox's.
- **A real toolchain.** Build GCC and musl (or glibc) *for* LakerLinux, so you
  can compile software inside it. This is the Linux From Scratch path.

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
- **Start over.** `./laker clean` deletes everything except downloaded tarballs.
