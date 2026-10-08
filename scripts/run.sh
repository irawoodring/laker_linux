#!/usr/bin/env bash
#
# Boot the LakerLinux disk image in QEMU. Output goes to this terminal.
#
#   scripts/run.sh            # boot like real hardware: UEFI firmware -> disk
#   scripts/run.sh --direct   # QEMU loads out/bzImage itself (skips firmware;
#                             # fastest loop when you're hacking on the kernel)
#   scripts/run.sh --usb      # also plug in a virtual USB stick, out/usb.img
#                             # (blank, 4 GB, made if missing), to try
#                             # laker-install on
#   scripts/run.sh --boot-usb # boot from out/usb.img instead (after
#                             # laker-install has put LakerLinux on it)
#
# Exit QEMU with Ctrl-A then X (or run `poweroff` inside LakerLinux).

set -euo pipefail

LAKER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$LAKER_DIR/config/versions.sh"
OUT_DIR="${OUT_DIR:-$LAKER_DIR/out}"
DISK="$OUT_DIR/lakerlinux.img"
USB="$OUT_DIR/usb.img"

direct=0 usb=0 boot_usb=0
for arg in "$@"; do
    case "$arg" in
        --direct)   direct=1 ;;
        --usb)      usb=1 ;;
        --boot-usb) boot_usb=1 ;;
        *) echo "unknown option $arg (expected --direct, --usb or --boot-usb)" >&2; exit 1 ;;
    esac
done

args=(
    -m "${MEM:-1G}" -smp 2
    -netdev user,id=net0 -device virtio-net-pci,netdev=net0
    -nographic
)

if [ "$boot_usb" = 1 ]; then
    [ -f "$USB" ] || { echo "No $USB yet -- run ./laker run --usb and laker-install first." >&2; exit 1; }
else
    [ -f "$DISK" ] || { echo "No $DISK yet -- run ./laker build first." >&2; exit 1; }
    args+=(-drive "file=$DISK,format=raw,if=virtio")
fi

# The USB stick: a sparse file, so it takes no space until something's written.
if [ "$usb" = 1 ] || [ "$boot_usb" = 1 ]; then
    if [ ! -f "$USB" ]; then
        truncate -s 4G "$USB"
        # Made as root in Docker: hand it to you, like the build's other output.
        if [ -n "${HOST_UID:-}" ]; then chown "$HOST_UID:${HOST_GID:-$HOST_UID}" "$USB"; fi
        echo "Made a blank 4 GB USB stick, $USB. Inside LakerLinux: laker-install sda"
    fi
    args+=(-device qemu-xhci,id=xhci
           -drive "file=$USB,format=raw,if=none,id=usbstick"
           -device usb-storage,bus=xhci.0,drive=usbstick)
fi

# Hardware acceleration when available; plain emulation still works, just slower.
if [ -w /dev/kvm ]; then
    args+=(-enable-kvm -cpu host)
fi

if [ "$direct" = 1 ]; then
    args+=(-kernel "$OUT_DIR/bzImage"
           -append "$KERNEL_CMDLINE")
else
    firmware=""
    for f in /usr/share/ovmf/OVMF.fd /usr/share/OVMF/OVMF.fd /usr/share/qemu/OVMF.fd \
             /usr/share/edk2/x64/OVMF.fd /usr/share/edk2/ovmf/OVMF_CODE.fd \
             /opt/homebrew/share/qemu/edk2-x86_64-code.fd /usr/local/share/qemu/edk2-x86_64-code.fd; do
        [ -f "$f" ] && { firmware="$f"; break; }
    done
    [ -n "$firmware" ] || { echo "No UEFI firmware (OVMF) found; install 'ovmf' or use --direct." >&2; exit 1; }
    args+=(-bios "$firmware")
fi

exec qemu-system-x86_64 "${args[@]}"
