#!/usr/bin/env bash
#
# Boot the LakerLinux disk image in QEMU. Output goes to this terminal.
#
#   scripts/run.sh            # boot like real hardware: UEFI firmware -> disk
#   scripts/run.sh --direct   # QEMU loads out/bzImage itself (skips firmware;
#                             # fastest loop when you're hacking on the kernel)
#
# Exit QEMU with Ctrl-A then X (or run `poweroff` inside LakerLinux).

set -euo pipefail

LAKER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$LAKER_DIR/config/versions.sh"
OUT_DIR="${OUT_DIR:-$LAKER_DIR/out}"
DISK="$OUT_DIR/lakerlinux.img"

[ -f "$DISK" ] || { echo "No $DISK yet -- run ./laker build first." >&2; exit 1; }

args=(
    -m "${MEM:-1G}" -smp 2
    -drive "file=$DISK,format=raw,if=virtio"
    -netdev user,id=net0 -device virtio-net-pci,netdev=net0
    -nographic
)

# Hardware acceleration when available; plain emulation still works, just slower.
if [ -w /dev/kvm ]; then
    args+=(-enable-kvm -cpu host)
fi

if [ "${1:-}" = "--direct" ]; then
    args+=(-kernel "$OUT_DIR/bzImage"
           -append "root=PARTUUID=$ROOT_PARTUUID rootwait console=ttyS0,115200")
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
