#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Installs RAW thumbnails for Nautilus and RAW previews for Sushi.
# Usage: sh install.sh [--uninstall]
#    or: wget -qO- https://raw.githubusercontent.com/good-news-everyone/nautilus-raw-preview/main/install.sh | sh
set -eu

REPO_URL=https://raw.githubusercontent.com/good-news-everyone/nautilus-raw-preview/main
FILES="thumbnailer/raw-thumbnailer thumbnailer/raw-thumbnailer.thumbnailer sushi/raw.js"

# The thumbnailer runs inside GNOME's bwrap sandbox, which only exposes /usr,
# so the script can't live in $HOME
BIN=/usr/local/bin/raw-thumbnailer
DATA=${XDG_DATA_HOME:-$HOME/.local/share}
THUMBNAILER=$DATA/thumbnailers/raw-thumbnailer.thumbnailer
PLUGIN=$DATA/sushi/plugins-1/raw.js
FAILED=${XDG_CACHE_HOME:-$HOME/.cache}/thumbnails/fail/gnome-thumbnail-factory

sudo_() { if [ "$(id -u)" = 0 ]; then "$@"; else sudo "$@"; fi; }

fetch() {
    if command -v wget >/dev/null; then
        wget -qO "$2" "$1"
    else
        curl -fsSLo "$2" "$1"
    fi
}

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

# Install from the checkout next to this script, or download the files
# when the script itself was piped in
src=$(dirname "$0")
if [ ! -f "$src/sushi/raw.js" ]; then
    src=$(mktemp -d)
    trap 'rm -rf "$src"' EXIT
    for f in $FILES; do
        mkdir -p "$src/$(dirname "$f")"
        fetch "$REPO_URL/$f" "$src/$f"
    done
fi

sudo_ install -Dm755 "$src/thumbnailer/raw-thumbnailer" "$BIN"
install -Dm644 "$src/thumbnailer/raw-thumbnailer.thumbnailer" "$THUMBNAILER"
install -Dm644 "$src/sushi/raw.js" "$PLUGIN"

# Let files that failed before get another try
rm -rf "$FAILED"

echo "Installed. Restart Nautilus: nautilus -q"
