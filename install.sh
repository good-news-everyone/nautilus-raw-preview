#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Installs RAW thumbnails for Nautilus and RAW previews for Sushi.
# Usage: sh install.sh [--uninstall]
set -eu

cd "$(dirname "$0")"

# The thumbnailer runs inside GNOME's bwrap sandbox, which only exposes /usr,
# so the script can't live in $HOME
BIN=/usr/local/bin/raw-thumbnailer
DATA=${XDG_DATA_HOME:-$HOME/.local/share}
THUMBNAILER=$DATA/thumbnailers/raw-thumbnailer.thumbnailer
PLUGIN=$DATA/sushi/plugins-1/raw.js
FAILED=${XDG_CACHE_HOME:-$HOME/.cache}/thumbnails/fail/gnome-thumbnail-factory

sudo_() { if [ "$(id -u)" = 0 ]; then "$@"; else sudo "$@"; fi; }

if [ "${1-}" = --uninstall ]; then
    rm -fv "$THUMBNAILER" "$PLUGIN"
    sudo_ rm -fv "$BIN"
    exit 0
fi

missing=
for cmd in exiv2 magick sushi; do
    command -v "$cmd" >/dev/null || missing="$missing $cmd"
done
if [ -n "$missing" ]; then
    echo "Missing:$missing (Arch: pacman -S exiv2 imagemagick sushi)" >&2
    exit 1
fi
if ! magick -list format 2>/dev/null | grep -q '^ *NEF '; then
    echo "Warning: ImageMagick has no libraw coder; RAWs without an embedded preview won't render" >&2
fi

sudo_ install -Dm755 thumbnailer/raw-thumbnailer "$BIN"
install -Dm644 thumbnailer/raw-thumbnailer.thumbnailer "$THUMBNAILER"
install -Dm644 sushi/raw.js "$PLUGIN"

# Let files that failed before get another try
rm -rf "$FAILED"

echo "Installed. Restart Nautilus: nautilus -q"
