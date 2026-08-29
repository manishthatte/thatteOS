#!/usr/bin/env bash
# studioMani/tools/build_usb.sh — bootable studioMani kiosk USB image builder
#
# Creates a GPT disk image with EFI GRUB + minimal Debian Trixie rootfs.
# The system boots directly into studioMani using SDL2 kmsdrm (no X server).
#
# Usage:
#   sudo bash studioMani/tools/build_usb.sh            # build image only
#   sudo bash studioMani/tools/build_usb.sh /dev/sdX   # build + write to USB
#
# Prerequisites (all available on Debian Trixie):
#   parted losetup mkfs.vfat mkfs.ext4 debootstrap grub-efi-amd64
#
# Time estimate: ~10-15 min (debootstrap network download dominates).
#
# Author: Manish Jagdish Thatte

set -euo pipefail

# ── Paths ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STUDIO_BIN="$SCRIPT_DIR/../output/studioMani"
OUTPUT_IMG="$SCRIPT_DIR/../output/studioMani_usb.img"
IMG_SIZE_MB=4096        # 4 GB — plenty for Debian minbase + kernel + SDL2

TARGET_DEV="${1:-}"     # optional USB device (e.g. /dev/sdb)

LOOP=""
ROOTFS=""

# ── Colors ────────────────────────────────────────────────────────────────────
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'; N='\033[0m'
log()  { echo -e "${G}[USB]${N} $*"; }
step() { echo -e "${B}[USB] ══ $* ══${N}"; }
warn() { echo -e "${Y}[USB] WARN:${N} $*"; }
die()  { echo -e "${R}[USB] ERROR:${N} $*" >&2; cleanup; exit 1; }

# ── Cleanup on exit ───────────────────────────────────────────────────────────
cleanup() {
    set +e
    if [ -n "$ROOTFS" ] && mountpoint -q "$ROOTFS" 2>/dev/null; then
        for d in dev/pts dev proc sys run; do
            umount -lf "$ROOTFS/$d" 2>/dev/null || true
        done
        umount -lf "$ROOTFS/boot/efi" 2>/dev/null || true
        umount -lf "$ROOTFS"          2>/dev/null || true
        rm -rf "$ROOTFS"
    fi
    if [ -n "$LOOP" ]; then
        losetup -d "$LOOP" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# ── Pre-flight ────────────────────────────────────────────────────────────────
step "Pre-flight checks"
[ "$(id -u)" -eq 0 ] || die "Must run as root:  sudo bash $0 [/dev/sdX]"
[ -f "$STUDIO_BIN" ] || die "Binary not found: $STUDIO_BIN\n  Build first:  bash studioMani/build.sh"

for cmd in parted losetup mkfs.vfat mkfs.ext4 debootstrap grub-install; do
    command -v "$cmd" &>/dev/null || die "Required tool not found: $cmd\n  Install: sudo apt install $(echo $cmd | sed 's/grub-install/grub-efi-amd64/')"
done

if [ -n "$TARGET_DEV" ]; then
    [ -b "$TARGET_DEV" ] || die "Not a block device: $TARGET_DEV"
    DEVNAME=$(basename "$TARGET_DEV")
    # Safety: don't write to an internal disk (sda usually = OS disk)
    if [ "$DEVNAME" = "sda" ]; then
        warn "Target is $TARGET_DEV — this is usually the primary OS disk!"
        read -r -p "Are you sure? Type YES to continue: " CONFIRM
        [ "$CONFIRM" = "YES" ] || die "Aborted."
    fi
fi

# ── Create or verify the disk image ──────────────────────────────────────────
step "Creating ${IMG_SIZE_MB}MB disk image"
mkdir -p "$(dirname "$OUTPUT_IMG")"
dd if=/dev/zero of="$OUTPUT_IMG" bs=1M count="$IMG_SIZE_MB" status=progress
log "Image created: $OUTPUT_IMG"

# ── Partition: GPT with EFI (100 MiB) + rootfs (rest) ────────────────────────
step "Partitioning"
parted -s "$OUTPUT_IMG" mktable gpt
parted -s "$OUTPUT_IMG" mkpart ESP  fat32 1MiB   101MiB
parted -s "$OUTPUT_IMG" set 1 esp on
parted -s "$OUTPUT_IMG" mkpart ROOT ext4  101MiB 100%
log "GPT: EFI (100MiB) + ROOT (rest)"

# ── Loop device ───────────────────────────────────────────────────────────────
step "Setting up loop device"
LOOP=$(losetup --find --partscan --show "$OUTPUT_IMG")
log "Loop device: $LOOP"
EFI_PART="${LOOP}p1"
ROOT_PART="${LOOP}p2"
sleep 1   # udev scan

mkfs.vfat -F32 -n EFI      "$EFI_PART"
mkfs.ext4 -L studioMani -F "$ROOT_PART"
log "Formatted EFI (FAT32) + ROOT (ext4)"

# ── Mount ─────────────────────────────────────────────────────────────────────
step "Mounting"
ROOTFS=$(mktemp -d /tmp/sm_usb.XXXXXX)
mount "$ROOT_PART" "$ROOTFS"
mkdir -p "$ROOTFS/boot/efi"
mount "$EFI_PART" "$ROOTFS/boot/efi"

# ── Debootstrap ───────────────────────────────────────────────────────────────
step "Running debootstrap (Debian Trixie minbase) — grab a coffee ☕"
debootstrap \
    --variant=minbase \
    --include=systemd,systemd-sysv,dbus,udev,kmod,procps,less,nano \
    trixie "$ROOTFS" https://deb.debian.org/debian

# ── Bind mounts for chroot ────────────────────────────────────────────────────
step "Preparing chroot"
mount --bind /dev     "$ROOTFS/dev"
mount --bind /dev/pts "$ROOTFS/dev/pts"
mount -t proc  proc  "$ROOTFS/proc"
mount -t sysfs sysfs "$ROOTFS/sys"
mount -t tmpfs tmpfs "$ROOTFS/run"
mkdir -p "$ROOTFS/run/lock"

# Prevent services from starting in chroot (Debian policy-rc.d trick)
echo '#!/bin/sh' > "$ROOTFS/usr/sbin/policy-rc.d"
echo 'exit 101'  >> "$ROOTFS/usr/sbin/policy-rc.d"
chmod +x "$ROOTFS/usr/sbin/policy-rc.d"

# ── Install kernel + SDL2 + GRUB in chroot ────────────────────────────────────
step "Installing kernel, SDL2, GRUB (chroot apt)"
chroot "$ROOTFS" /bin/bash -c "
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y --no-install-recommends \
        linux-image-amd64 \
        grub-efi-amd64 \
        libsdl2-2.0-0 \
        libsdl2-ttf-2.0-0 \
        libcurl4t64 \
        libdrm2 \
        libgbm1 \
        libegl1 \
        libgl1 \
        fonts-dejavu-core \
        iproute2 \
        iw \
        wpasupplicant \
        curl \
        bash-completion
    apt-get clean
"

# ── Install studioMani binary ─────────────────────────────────────────────────
step "Installing studioMani binary"
install -Dm755 "$STUDIO_BIN" "$ROOTFS/usr/local/bin/studioMani"
log "Binary installed to /usr/local/bin/studioMani"

# ── Hostname and hosts ────────────────────────────────────────────────────────
echo "studioMani" > "$ROOTFS/etc/hostname"
cat > "$ROOTFS/etc/hosts" <<'EOF'
127.0.0.1   localhost studioMani
::1         localhost ip6-localhost ip6-loopback
EOF

# ── Root password (empty = no password, just Enter) ───────────────────────────
chroot "$ROOTFS" /bin/bash -c "passwd -d root"

# ── Auto-login on tty1 ────────────────────────────────────────────────────────
step "Configuring auto-login on tty1"
mkdir -p "$ROOTFS/etc/systemd/system/getty@tty1.service.d"
cat > "$ROOTFS/etc/systemd/system/getty@tty1.service.d/autologin.conf" <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
Type=idle
EOF

# ── Root .profile: launch studioMani on tty1 via kmsdrm ──────────────────────
cat > "$ROOTFS/root/.profile" <<'PROFILE'
# studioMani kiosk launcher (tty1 only)
if [ "$(tty)" = "/dev/tty1" ]; then
    # Direct KMS rendering — no X server, no Wayland compositor needed
    export SDL_VIDEODRIVER=kmsdrm
    export HOME=/root
    export XDG_RUNTIME_DIR=/tmp/sm_runtime
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 0700 "$XDG_RUNTIME_DIR"

    clear
    echo "═══════════════════════════════════════"
    echo "  studioMani — thatteOS Native IDE"
    echo "  Manish Jagdish Thatte  ·  thatteOS"
    echo "═══════════════════════════════════════"
    echo ""
    echo "Starting studioMani..."
    sleep 1

    # Restart loop: press Ctrl+C twice to drop to shell
    while true; do
        /usr/local/bin/studioMani || true
        echo ""
        echo "studioMani exited. Press Ctrl-C within 3s to drop to shell..."
        sleep 3 && continue || break
    done

    echo ""
    echo "Dropped to shell. Type 'studioMani' to restart."
fi
PROFILE

# ── /etc/fstab ────────────────────────────────────────────────────────────────
ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")
EFI_UUID=$(blkid  -s UUID -o value "$EFI_PART")
cat > "$ROOTFS/etc/fstab" <<EOF
# <fs>                                  <mp>       <type>  <opts>            <dump> <pass>
UUID=$ROOT_UUID  /          ext4    defaults,noatime  0      1
UUID=$EFI_UUID   /boot/efi  vfat    umask=0077        0      2
tmpfs            /tmp       tmpfs   defaults,nosuid   0      0
EOF

# ── GRUB EFI ──────────────────────────────────────────────────────────────────
step "Installing GRUB EFI"
chroot "$ROOTFS" grub-install \
    --target=x86_64-efi \
    --efi-directory=/boot/efi \
    --bootloader-id=studioMani \
    --removable \
    --no-nvram \
    --recheck

# Build GRUB config manually (simpler than running update-grub in chroot)
VMLINUZ=$(ls "$ROOTFS/boot/vmlinuz-"* | sort -V | tail -1 | sed "s|$ROOTFS||")
INITRD=$(ls  "$ROOTFS/boot/initrd.img-"* | sort -V | tail -1 | sed "s|$ROOTFS||")
log "Kernel:  $VMLINUZ"
log "Initrd:  $INITRD"

cat > "$ROOTFS/boot/grub/grub.cfg" <<EOF
# studioMani GRUB config — auto-generated
set timeout=3
set default=0

menuentry "studioMani OS" --class thatteOS {
    linux  $VMLINUZ root=UUID=$ROOT_UUID rw quiet loglevel=3 systemd.show_status=auto
    initrd $INITRD
}

menuentry "studioMani OS (verbose)" {
    linux  $VMLINUZ root=UUID=$ROOT_UUID rw systemd.show_status=true
    initrd $INITRD
}
EOF

# ── Remove policy-rc.d ────────────────────────────────────────────────────────
rm -f "$ROOTFS/usr/sbin/policy-rc.d"

# ── Sync and unmount ──────────────────────────────────────────────────────────
step "Syncing and unmounting"
sync

for d in dev/pts dev proc sys run; do
    umount -lf "$ROOTFS/$d" 2>/dev/null || true
done
umount "$ROOTFS/boot/efi"
umount "$ROOTFS"
rm -rf "$ROOTFS"
ROOTFS=""

losetup -d "$LOOP"
LOOP=""

# ── Write to USB if requested ─────────────────────────────────────────────────
if [ -n "$TARGET_DEV" ]; then
    step "Writing image to $TARGET_DEV"
    warn "ALL DATA ON $TARGET_DEV WILL BE ERASED"
    dd if="$OUTPUT_IMG" of="$TARGET_DEV" bs=4M status=progress oflag=sync
    sync
    log "Written to $TARGET_DEV"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
step "Complete!"
echo ""
log "Image:   $OUTPUT_IMG"
log "Size:    $(du -sh "$OUTPUT_IMG" | cut -f1)"
echo ""
echo -e "${G}To write to USB:${N}"
echo "  sudo dd if=$OUTPUT_IMG of=/dev/sdX bs=4M status=progress"
echo ""
echo -e "${G}To test in QEMU (needs OVMF):${N}"
echo "  sudo apt install ovmf qemu-system-x86"
echo "  qemu-system-x86_64 -m 2G -cpu host -enable-kvm \\"
echo "    -bios /usr/share/OVMF/OVMF_CODE.fd \\"
echo "    -drive file=$OUTPUT_IMG,format=raw,if=virtio \\"
echo "    -vga virtio -display sdl"
echo ""
echo -e "${G}Boot flow:${N}  GRUB → Debian Trixie → systemd → auto-login root → studioMani (kmsdrm)"
