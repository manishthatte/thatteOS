#!/usr/bin/env bash
# thatteos/tools/build_usb.sh — Build a bootable THATTEOS USB image
#
# Base: Alpine Linux (fast, lightweight, proven to boot)
# ABI:  THATTEOS binaries are glibc — bundle the exact host libraries
#       alongside the binaries so they run natively without recompilation.
#
# Author: Manish Jagdish Thatte

set -euo pipefail
cd /home/manish/THATTE

IMG=thatteOS/baremetal/thatteos_usb.img
IMG_SIZE_MB=1024
ALPINE_VERSION=3.21.3
ALPINE_ARCH=x86_64
ALPINE_MIRROR="https://dl-cdn.alpinelinux.org/alpine"
ALPINE_MINI="alpine-minirootfs-${ALPINE_VERSION}-${ALPINE_ARCH}.tar.gz"
ALPINE_URL="${ALPINE_MIRROR}/v3.21/releases/${ALPINE_ARCH}/${ALPINE_MINI}"
VIRT_ISO="alpine-virt-${ALPINE_VERSION}-${ALPINE_ARCH}.iso"
VIRT_URL="${ALPINE_MIRROR}/v3.21/releases/${ALPINE_ARCH}/${VIRT_ISO}"

THATTEOS_BIN=./thatteOS/thatteos
USERSPACE_BIN=./thatteOS/userspace/bin
STUDIOMANI_BIN=./thatteOS/studioMani/output
LAUNCH_GUI_SH=./thatteOS/tools/launch_gui.sh

# ── cleanup trap ──────────────────────────────────────────────────────────────

MNT=""
LOOP=""
cleanup() {
    set +e
    if [ -n "$MNT" ]; then
        for special in dev/pts dev/shm dev proc sys; do
            mountpoint -q "$MNT/$special" 2>/dev/null && sudo umount -lf "$MNT/$special" || true
        done
        mountpoint -q "$MNT/boot/efi" 2>/dev/null && sudo umount -lf "$MNT/boot/efi" || true
        mountpoint -q "$MNT"          2>/dev/null && sudo umount -lf "$MNT" || true
        [ -d "$MNT" ] && rmdir "$MNT" 2>/dev/null || true
    fi
    [ -n "$LOOP" ] && sudo losetup -d "$LOOP" 2>/dev/null || true
    echo "[cleanup] done"
}
trap cleanup EXIT

# ── pre-flight ────────────────────────────────────────────────────────────────

echo "=== THATTEOS USB image builder ==="
echo "    image:  $IMG  (${IMG_SIZE_MB} MB)"
echo "    base:   Alpine ${ALPINE_VERSION} + bundled host glibc libs"
echo ""

check_tool() { command -v "$1" &>/dev/null || { echo "MISSING: $1 (apt install $2)"; exit 1; }; }
check_tool parted      parted
check_tool mkfs.fat    dosfstools
check_tool mkfs.ext4   e2fsprogs
check_tool grub-install grub-efi-amd64-bin
check_tool wget        wget
check_tool ldd         libc-bin
check_tool readelf     binutils

for f in "$THATTEOS_BIN" "$LAUNCH_GUI_SH"; do
    [ -f "$f" ] || { echo "MISSING: $f"; exit 1; }
done
[ -d "$USERSPACE_BIN" ]  || { echo "MISSING: $USERSPACE_BIN"; exit 1; }
[ -d "$STUDIOMANI_BIN" ] || { echo "MISSING: $STUDIOMANI_BIN"; exit 1; }

# ── create image ──────────────────────────────────────────────────────────────

echo "[1/8] creating blank image (${IMG_SIZE_MB} MB)"
dd if=/dev/zero of="$IMG" bs=1M count="$IMG_SIZE_MB" status=progress

echo "[2/8] partitioning"
parted -s "$IMG" \
    mklabel gpt \
    mkpart ESP  fat32   2MiB  102MiB \
    mkpart ROOT ext4  102MiB  100%   \
    set 1 esp on

echo "[3/8] setting up loop device"
LOOP=$(sudo losetup --find --show --partscan "$IMG")
echo "    $LOOP"
sleep 1

sudo mkfs.fat  -F32 -n TEOS_EFI  "${LOOP}p1"
sudo mkfs.ext4 -F   -L TEOS_ROOT "${LOOP}p2"

MNT=$(mktemp -d)
sudo mount "${LOOP}p2" "$MNT"
sudo mkdir -p "$MNT/boot/efi"
sudo mount "${LOOP}p1" "$MNT/boot/efi"

# ── Alpine minirootfs ─────────────────────────────────────────────────────────

echo "[4/8] Alpine minirootfs"
[ -f "/tmp/$ALPINE_MINI" ] || wget -q --show-progress -O "/tmp/$ALPINE_MINI" "$ALPINE_URL"
sudo tar -xzf "/tmp/$ALPINE_MINI" -C "$MNT"

# apk repositories
sudo mkdir -p "$MNT/etc/apk"
printf "https://dl-cdn.alpinelinux.org/alpine/v3.21/main\nhttps://dl-cdn.alpinelinux.org/alpine/v3.21/community\n" \
    | sudo tee "$MNT/etc/apk/repositories" >/dev/null

# Bind mounts for apk (no daemon hooks — keep them minimal)
sudo mount --bind /proc    "$MNT/proc"
sudo mount --bind /sys     "$MNT/sys"
sudo mount --bind /dev     "$MNT/dev"
sudo cp /etc/resolv.conf "$MNT/etc/resolv.conf"

echo "[5/8] apk: kernel + init only (no SDL2/curl — bundling host libs instead)"
sudo chroot "$MNT" /bin/sh -c "
    set -e
    apk update -q
    apk add --no-cache \
        linux-lts \
        linux-firmware-none \
        openrc \
        busybox-openrc \
        eudev \
        kmod \
        bash \
        dhcpcd
    rc-update add devfs   sysinit 2>/dev/null || true
    rc-update add dmesg   sysinit 2>/dev/null || true
    rc-update add udev    sysinit 2>/dev/null || true
    rc-update add modules boot    2>/dev/null || true
    rc-update add hostname boot   2>/dev/null || true
    rc-update add bootmisc boot   2>/dev/null || true
    rc-update add dhcpcd  default 2>/dev/null || true
    echo 'apk done'
"

# Unmount bind mounts (done with apk)
sudo umount "$MNT/dev"
sudo umount "$MNT/sys"
sudo umount "$MNT/proc"

# ── system config ─────────────────────────────────────────────────────────────

sudo tee "$MNT/etc/hostname"  <<'EOF' >/dev/null
thatteos
EOF
sudo tee "$MNT/etc/hosts" <<'EOF' >/dev/null
127.0.0.1 localhost thatteos
::1       localhost thatteos
EOF
sudo tee "$MNT/etc/fstab" <<'EOF' >/dev/null
LABEL=TEOS_ROOT  /          ext4  defaults    0 1
LABEL=TEOS_EFI   /boot/efi  vfat  umask=0077  0 2
proc  /proc proc defaults 0 0
sysfs /sys  sysfs defaults 0 0
EOF
sudo tee "$MNT/etc/inittab" <<'EOF' >/dev/null
::sysinit:/sbin/openrc sysinit
::sysinit:/sbin/openrc boot
::wait:/sbin/openrc default
tty1::respawn:/bin/thatteos
ttyS0::respawn:/bin/thatteos
tty2::respawn:/bin/sh
::ctrlaltdel:/sbin/reboot
::shutdown:/sbin/openrc shutdown
EOF
sudo mkdir -p "$MNT/root"
sudo tee "$MNT/root/.profile" <<'EOF' >/dev/null
export PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin
export HOME=/root
export TERM=linux
export SDL_VIDEODRIVER=kmsdrm
export SDL_AUDIODRIVER=dummy
EOF

# ── bundle host glibc libraries ───────────────────────────────────────────────
# Strategy: put ELF loader + all libs in a single flat dir /opt/thatteos/lib/
# Run every binary via:  /opt/thatteos/lib/ld-linux.so --library-path ... /opt/thatteos/bin/X
# This avoids all symlink-loop issues in Alpine's /lib directory tree.

echo "[6/8] bundling host libraries + THATTEOS binaries"

TLIB="$MNT/opt/thatteos/lib"
TBIN="$MNT/opt/thatteos/bin"
sudo mkdir -p "$TLIB" "$TBIN"

# Find ELF interpreter
INTERP=$(readelf -l "$THATTEOS_BIN" 2>/dev/null \
    | grep "interpreter" | sed 's/.*interpreter: //;s/\].*//' | tr -d '[:space:]' || true)
INTERP_REAL=$(readlink -f "$INTERP" 2>/dev/null || echo "$INTERP")
echo "    interpreter: $INTERP_REAL"

# Copy interpreter into /opt/thatteos/lib/
LOADER_NAME=$(basename "$INTERP_REAL")
sudo cp -f "$INTERP_REAL" "$TLIB/$LOADER_NAME"
sudo chmod 755 "$TLIB/$LOADER_NAME"

# Collect all required shared libraries.
# For each dep: record "SONAME REALPATH" so we can copy the real file
# AND create a symlink from the SONAME name the binary actually requests.
ALL_LIB_PAIRS=$(
    for bin in "$THATTEOS_BIN" "$USERSPACE_BIN"/* "$STUDIOMANI_BIN"/studioMani "$STUDIOMANI_BIN"/sm_browser "$STUDIOMANI_BIN"/sm_email "$STUDIOMANI_BIN"/sm_fm; do
        [ -f "$bin" ] || continue
        ldd "$bin" 2>/dev/null | awk '/=>/ { print $1, $3 }'
    done | grep -v "^$" | sort -u
)
echo "    library entries: $(echo "$ALL_LIB_PAIRS" | wc -l)"

# Copy real file + create SONAME symlink for every dependency
echo "$ALL_LIB_PAIRS" | while read soname libpath; do
    [ -f "$libpath" ] || continue
    real=$(readlink -f "$libpath")
    realbase=$(basename "$real")
    # Copy the real versioned file
    sudo cp -f "$real" "$TLIB/$realbase"
    # Create SONAME symlink if it differs from the real filename
    if [ "$soname" != "$realbase" ]; then
        sudo ln -sf "$realbase" "$TLIB/$soname"
    fi
done

# Copy THATTEOS binaries to /opt/thatteos/bin/
sudo cp "$THATTEOS_BIN" "$TBIN/thatteos"
sudo chmod 755 "$TBIN/thatteos"
for bin in "$USERSPACE_BIN"/*; do
    name=$(basename "$bin")
    sudo cp "$bin" "$TBIN/$name"
    sudo chmod 755 "$TBIN/$name"
done
sudo cp "$LAUNCH_GUI_SH" "$TBIN/launch_gui"
sudo chmod 755 "$TBIN/launch_gui"

# studioMani executables (only the ELF binaries, not .ll/.t3s/.o)
for sm in studioMani sm_browser sm_email sm_fm; do
    [ -f "$STUDIOMANI_BIN/$sm" ] || continue
    sudo cp "$STUDIOMANI_BIN/$sm" "$TBIN/$sm"
    sudo chmod 755 "$TBIN/$sm"
done

# Create wrapper scripts in /bin/ and /usr/local/bin/ that invoke via the loader
# Form: /opt/thatteos/lib/ld-linux.so --library-path /opt/thatteos/lib /opt/thatteos/bin/X "$@"
make_wrapper() {
    local name="$1"
    local dest="$2"
    sudo tee "$dest" <<WRAP >/dev/null
#!/bin/sh
exec /opt/thatteos/lib/${LOADER_NAME} \\
    --library-path /opt/thatteos/lib \\
    /opt/thatteos/bin/${name} "\$@"
WRAP
    sudo chmod 755 "$dest"
}

make_wrapper thatteos "$MNT/bin/thatteos"

sudo mkdir -p "$MNT/usr/local/bin"
for bin in "$USERSPACE_BIN"/*; do
    name=$(basename "$bin")
    make_wrapper "$name" "$MNT/usr/local/bin/$name"
done
make_wrapper launch_gui "$MNT/usr/local/bin/launch_gui"

for sm in studioMani sm_browser sm_email sm_fm; do
    [ -f "$TBIN/$sm" ] && make_wrapper "$sm" "$MNT/usr/local/bin/$sm"
done

# Fonts for SDL2_ttf
if ls /usr/share/fonts/truetype/dejavu/*.ttf 2>/dev/null | grep -q .; then
    sudo mkdir -p "$MNT/usr/share/fonts/truetype/dejavu"
    sudo cp /usr/share/fonts/truetype/dejavu/*.ttf \
        "$MNT/usr/share/fonts/truetype/dejavu/" 2>/dev/null || true
fi

# ── kernel + GRUB ─────────────────────────────────────────────────────────────

echo "[8/8] kernel + GRUB"

# Kernel from apk
VMLINUZ_HOST=$(ls "$MNT/boot"/vmlinuz* 2>/dev/null | head -1)
INITRAMFS_HOST=$(ls "$MNT/boot"/initramfs* 2>/dev/null | head -1)

# Fallback: Alpine VIRT ISO
if [ -z "$VMLINUZ_HOST" ] || [ -z "$INITRAMFS_HOST" ]; then
    echo "    apk kernel missing — fetching Alpine VIRT ISO..."
    [ -f "/tmp/$VIRT_ISO" ] || wget -q --show-progress -O "/tmp/$VIRT_ISO" "$VIRT_URL"
    ISO_MNT=$(mktemp -d)
    sudo mount -o loop,ro "/tmp/$VIRT_ISO" "$ISO_MNT"
    sudo mkdir -p "$MNT/boot"
    K=$(ls "$ISO_MNT/boot"/vmlinuz* 2>/dev/null | head -1)
    I=$(ls "$ISO_MNT/boot"/initramfs* 2>/dev/null | head -1)
    sudo cp "$K" "$MNT/boot/vmlinuz-lts"
    sudo cp "$I" "$MNT/boot/initramfs-lts"
    sudo umount "$ISO_MNT"; rmdir "$ISO_MNT"
    VMLINUZ_HOST="$MNT/boot/vmlinuz-lts"
    INITRAMFS_HOST="$MNT/boot/initramfs-lts"
fi

VMLINUZ="${VMLINUZ_HOST#$MNT}"
INITRAMFS="${INITRAMFS_HOST#$MNT}"
echo "    kernel:    $VMLINUZ"
echo "    initramfs: $INITRAMFS"

sudo grub-install \
    --target=x86_64-efi \
    --efi-directory="$MNT/boot/efi" \
    --boot-directory="$MNT/boot" \
    --removable --no-nvram \
    2>&1 | grep -v "^$" || true

sudo mkdir -p "$MNT/boot/grub"
sudo tee "$MNT/boot/grub/grub.cfg" <<GRUBCFG >/dev/null
serial --unit=0 --speed=115200
terminal_input  serial
terminal_output serial

set default=0
set timeout=3

menuentry "THATTEOS" {
    linux  ${VMLINUZ} root=LABEL=TEOS_ROOT rw console=ttyS0,115200 quiet
    initrd ${INITRAMFS}
}

menuentry "THATTEOS — verbose" {
    linux  ${VMLINUZ} root=LABEL=TEOS_ROOT rw console=ttyS0,115200
    initrd ${INITRAMFS}
}

menuentry "THATTEOS — rescue" {
    linux  ${VMLINUZ} root=LABEL=TEOS_ROOT rw console=ttyS0,115200 init=/bin/sh
    initrd ${INITRAMFS}
}
GRUBCFG

# ── finalize ──────────────────────────────────────────────────────────────────

cp "$VMLINUZ_HOST"   thatteOS/baremetal/thatteos_vmlinuz
cp "$INITRAMFS_HOST" thatteOS/baremetal/thatteos_initramfs
chmod 644 thatteOS/baremetal/thatteos_vmlinuz thatteOS/baremetal/thatteos_initramfs thatteOS/baremetal/thatteos_usb.img
[ -n "${SUDO_USER:-}" ] && \
    chown "$SUDO_USER:$SUDO_USER" thatteOS/baremetal/thatteos_vmlinuz thatteOS/baremetal/thatteos_initramfs thatteOS/baremetal/thatteos_usb.img

sync
sudo umount "$MNT/boot/efi"
sudo umount "$MNT"
sudo losetup -d "$LOOP"; LOOP=""
rmdir "$MNT"; MNT=""

echo ""
echo "=== build complete ==="
echo "  image: $IMG  ($(du -sh $IMG | cut -f1))"
echo "  test:  bash thatteOS/tools/test_qemu.sh"
