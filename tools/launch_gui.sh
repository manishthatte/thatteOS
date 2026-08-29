#!/bin/sh
# thatteos/tools/launch_gui.sh — Launch a THATTEOS SDL2 GUI app on bare metal
#
# Tries display backends in order:
#   1. Existing X11/Wayland display (if $DISPLAY or $WAYLAND_DISPLAY is set)
#   2. KMS/DRM direct rendering (no compositor needed)
#   3. fbcon framebuffer
#   4. offscreen (headless fallback — no output but won't crash)
#
# Usage:
#   launch_gui.sh gui_fm
#   launch_gui.sh gui_browser
#
# Author: Manish Jagdish Thatte

BIN_DIR="/usr/local/bin/thatteos-userspace"
APP="$1"
shift

if [ -z "$APP" ]; then
    echo "Usage: launch_gui.sh <app> [args...]"
    exit 1
fi

BINARY="$BIN_DIR/$APP"
if [ ! -x "$BINARY" ]; then
    echo "launch_gui: not found or not executable: $BINARY"
    exit 1
fi

# ── pick the best SDL video driver ───────────────────────────────────────────

if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
    # X11 / Wayland already running — use it directly
    exec "$BINARY" "$@"
fi

# Try KMS/DRM (works on bare metal with no X server)
if [ -e /dev/dri/card0 ] || [ -e /dev/dri/card1 ]; then
    export SDL_VIDEODRIVER=kmsdrm
    export SDL_AUDIODRIVER=dummy
    # Need root or video group membership for DRM
    exec "$BINARY" "$@" 2>/tmp/gui_kmsdrm.log
    EXIT=$?
    if [ $EXIT -eq 0 ]; then exit 0; fi
    # If kmsdrm fails, fall through
fi

# Try fbdev (framebuffer console)
if [ -e /dev/fb0 ]; then
    export SDL_VIDEODRIVER=fbdev
    export SDL_FBDEV=/dev/fb0
    export SDL_AUDIODRIVER=dummy
    exec "$BINARY" "$@" 2>/tmp/gui_fbdev.log
    EXIT=$?
    if [ $EXIT -eq 0 ]; then exit 0; fi
fi

# Last resort: offscreen (for testing — no visible output)
export SDL_VIDEODRIVER=offscreen
export SDL_AUDIODRIVER=dummy
exec "$BINARY" "$@"
