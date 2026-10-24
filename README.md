# nautilus-raw-preview

Thumbnails and quick previews (Space key) for camera RAW files in GNOME Files (Nautilus).

GNOME decodes images with [glycin](https://gitlab.gnome.org/GNOME/glycin), which has no RAW loader. As a result:

- Nautilus shows **no thumbnails** for NEF, CR2, ARW and other RAW files;
- the **Space-key preview** (Sushi) fails with an error like
  `Format error decoding Tiff: format error: required tag 'ImageWidth' not found`.
  Most RAW MIME types are subtypes of `image/tiff`, so Sushi hands them to
  glycin's TIFF decoder.

Nearly every camera embeds a ready-made JPEG in the RAW file, often at full
resolution. This project extracts it with `exiv2` and displays it with the
orientation taken from the RAW. If there is no embedded JPEG, the RAW is
decoded in full through ImageMagick (libraw).

## Contents

| File | Installed to | Purpose |
|---|---|---|
| `thumbnailer/raw-thumbnailer` | `/usr/local/bin/` | Makes a thumbnail: takes the smallest embedded preview that is at least the requested size and scales it down |
| `thumbnailer/raw-thumbnailer.thumbnailer` | `~/.local/share/thumbnailers/` | Registers it for RAW MIME types |
| `sushi/raw.js` | `~/.local/share/sushi/plugins-1/` | Sushi plugin: shows the largest embedded preview in Sushi's built-in image viewer |

The thumbnailer script goes to `/usr/local/bin` rather than your home directory
because GNOME runs thumbnailers in a bwrap sandbox that only exposes `/usr` plus
the input and output files.

## Dependencies

| What | Why | Package (Arch) |
|---|---|---|
| Nautilus (glycin-based) | — | `nautilus` |
| Sushi ≥ 51 | user plugin directory `plugins-1` | `sushi` |
| `exiv2` | extracting the embedded JPEG, reading/writing orientation | `exiv2` |
| `magick` (ImageMagick 7) | scaling thumbnails; full decode of RAWs without a preview | `imagemagick` |
| libraw | ImageMagick's RAW coder, only needed for files without an embedded preview | `libraw` (pulled in by `imagemagick`) |

```sh
sudo pacman -S --needed exiv2 imagemagick sushi
```

Tested with Nautilus 51.1, Sushi 51.2, glycin 2.2.3, exiv2 0.28.9,
ImageMagick 7.1.2 + libraw 0.22.2, on Nikon Z f NEF files.

## Installation

```sh
sh install.sh
nautilus -q
```

The script checks dependencies, installs the thumbnailer to `/usr/local/bin`
(via `sudo`) and everything else to `~/.local/share`, and clears the
failed-thumbnail cache so Nautilus retries files it gave up on.

Uninstall:

```sh
sh install.sh --uninstall
```

## Limitations

- **The Sushi plugin depends on Sushi internals.** It subclasses the built-in
  `ImageRenderer` (`resource:///org/gnome/NautilusPreviewer/js/viewers/image.js`)
  and overrides its `_loadFile`, rather than using the public plugin API.
  A Sushi update may break it: `journalctl --user` will then show
  `failed to load renderer`, and RAW files fall back to the original error.
  Other file types are unaffected.
- **Existing thumbnails are not regenerated.** If `~/.cache/thumbnails`
  already has a thumbnail for a file (for example, one made by another
  application), Nautilus keeps showing it. Delete the cached thumbnail to get
  a new one.
- **RAWs without an embedded preview** are decoded in full: about 1.5 s per
  thumbnail and 2.5 s per preview for a 24 MP file. There is no camera tone
  curve, so they look darker than the in-camera JPEG.
- The list of RAW MIME types is duplicated in `raw-thumbnailer.thumbnailer` and
  `sushi/raw.js`. When adding a format, update both.

## Debugging

```sh
# generate a thumbnail by hand
raw-thumbnailer photo.NEF /tmp/t.png 256

# open a preview by hand and follow Sushi's log
sushi photo.NEF
journalctl --user -f | grep NautilusPreviewer
```

## License

GPL-2.0-or-later, the same as Sushi, whose code the plugin subclasses.
