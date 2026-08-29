#!/usr/bin/env bash
# thatteos/tools/test_qemu.sh — Test THATTEOS USB image in QEMU
#
# Uses QEMU direct kernel loading (no GRUB, no sudo needed).
# build_usb.sh saves thatteos_vmlinuz + thatteos_initramfs alongside the image.
#
# Requirements:
#   sudo apt install -y qemu-system-x86
#
# Usage:
#   bash thatteos/tools/test_qemu.sh [image]
#
# Controls: Ctrl+A X = quit,  Ctrl+A C = QEMU monitor
# All boot output (GRUB, kernel, init, THATTEOS) appears in this terminal.
#
# Author: Manish Jagdish Thatte

set -euo pipefail
cd /home/manish/THATTE

IMG="${1:-thatteOS/baremetal/thatteos_usb.img}"
KERNEL="thatteOS/baremetal/thatteos_vmlinuz"
INITRD="thatteOS/baremetal/thatteos_initramfs"
RAM_MB=2048

# ── pre-flight ────────────────────────────────────────────────────────────────

if ! command -v qemu-system-x86_64 &>/dev/null; then
    echo "MISSING: qemu-system-x86_64"
    echo "  sudo apt install -y qemu-system-x86"
    exit 1
fi

for f in "$IMG" "$KERNEL" "$INITRD"; do
    if [ ! -f "$f" ]; then
        echo "MISSING: $f"
        echo "  run: sudo bash thatteOS/tools/build_usb.sh"
        exit 1
    fi
done

echo "=== THATTEOS QEMU boot test ==="
echo "    image:  $IMG  ($(du -sh $IMG | cut -f1))"
echo "    kernel: $KERNEL  ($(du -sh $KERNEL | cut -f1))"
echo "    RAM:    ${RAM_MB} MB"
echo ""
GUI_MODE="${THATTEOS_QEMU_GUI:-}"

if [ -z "$GUI_MODE" ]; then
    echo "  Mode: serial/terminal — Ctrl+A X = quit,  Ctrl+A C = monitor"
    echo "  For SDL2 GUI apps:  THATTEOS_QEMU_GUI=1 bash $0"
else
    echo "  Mode: graphical window (SDL2 apps work)"
    echo "  Ctrl+Alt+G = release mouse,  close window to quit"
fi
echo ""

# ── KVM check ─────────────────────────────────────────────────────────────────

ACCEL=kvm
if ! [ -w /dev/kvm ]; then
    echo "  NOTE: /dev/kvm not writable — using tcg (slower)"
    ACCEL=tcg
fi

# ── boot ──────────────────────────────────────────────────────────────────────

KAPPEND="root=/dev/vda2 rootfstype=ext4"
KAPPEND+=" modules=sd-mod,usb-storage,ext4,virtio,virtio_pci,virtio_blk"

if [ -z "$GUI_MODE" ]; then
    KAPPEND+=" console=ttyS0,115200"
    DISPLAY_ARGS=(-nographic -serial mon:stdio)
else
    # Serial still captures kernel boot; VGA window for SDL2
    KAPPEND+=" console=tty1 console=ttyS0,115200"
    DISPLAY_ARGS=(
        -device virtio-vga
        -display gtk,zoom-to-fit=on
        -serial stdio
    )
fi

qemu-system-x86_64 \
    -name "THATTEOS" \
    -machine "type=q35,accel=${ACCEL}" \
    -cpu host \
    -smp 4 \
    -m "${RAM_MB}M" \
    -drive "file=${IMG},format=raw,if=virtio,snapshot=on" \
    -kernel "$KERNEL" \
    -initrd "$INITRD" \
    -append "$KAPPEND" \
    -netdev user,id=net0 \
    -device virtio-net-pci,netdev=net0 \
    "${DISPLAY_ARGS[@]}" \
    -no-reboot
