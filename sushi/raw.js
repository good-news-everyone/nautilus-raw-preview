// SPDX-License-Identifier: GPL-2.0-or-later

// Sushi plugin: preview camera RAW files.
// glycin has no RAW loader, and since NEF & co. are subclasses of image/tiff
// Sushi hands them to glycin's TIFF decoder, which fails. Instead extract the
// largest embedded JPEG preview with exiv2, copy the RAW's orientation into it
// and let the built-in image renderer load that.

import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import Gly from 'gi://Gly';
import GlyGtk4 from 'gi://GlyGtk4';

import {Klass as ImageRenderer} from 'resource:///org/gnome/NautilusPreviewer/js/viewers/image.js';

Gio._promisify(Gio.Subprocess.prototype, 'communicate_utf8_async', 'communicate_utf8_finish');
Gio._promisify(Gly.Loader.prototype, 'load_async', 'load_finish');

/** @param {string[]} argv
 *  @returns {Promise<string>} stdout */
const run = async (argv, cancellable) => {
    const proc = Gio.Subprocess.new(argv,
        Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENCE);
    const [stdout] = await proc.communicate_utf8_async(null, cancellable);
    if (!proc.get_successful())
        throw new Error(`${argv[0]} failed`);
    return stdout;
};

export const Klass = class RawImageRenderer extends ImageRenderer {
    static {
        GObject.registerClass({GTypeName: 'SushiRawImageRenderer'}, this);
    }

    // Called from the base constructor, before subclass fields exist,
    // so no class fields or #private members in this class.
    async _loadFile(file) {
        const tmpDir = GLib.Dir.make_tmp('sushi-raw-XXXXXX');
        try {
            const path = file.get_path();

            const previews = await run(['exiv2', '-q', '-pp', path], this.cancellable)
                .catch(() => '');
            // "Preview N: image/jpeg, WxH pixels, ..." sorted by size; take the largest
            const index = [...previews.matchAll(/^Preview (\d+): image\/jpeg/gm)].at(-1)?.[1];

            let preview;
            if (index) {
                await run(['exiv2', '-q', '-f', `-ep${index}`, '-l', tmpDir, path], this.cancellable);
                const base = GLib.path_get_basename(path).replace(/\.[^.]*$/, '');
                preview = GLib.build_filenamev([tmpDir, `${base}-preview${index}.jpg`]);

                const orientation = (await run(
                    ['exiv2', '-q', '-K', 'Exif.Image.Orientation', '-Pv', path],
                    this.cancellable).catch(() => '')).trim();
                if (/^[2-8]$/.test(orientation)) {
                    await run(['exiv2', '-q', `-Mset Exif.Image.Orientation Short ${orientation}`, preview],
                        this.cancellable);
                }
            } else {
                // No embedded JPEG: full decode through ImageMagick's libraw coder
                preview = GLib.build_filenamev([tmpDir, 'decoded.jpg']);
                await run(['magick', `dng:${path}`, '-auto-orient', '-depth', '8', '-quality', '92', preview],
                    this.cancellable);
            }

            const loader = Gly.Loader.new(Gio.File.new_for_path(preview));
            const image = await loader.load_async(this.cancellable);
            this._image = image;
            this._imageWidth = image.get_width();
            this._imageHeight = image.get_height();
            await this._showFirstFrame();
        } finally {
            // The frame is already a texture, the extracted file is not needed
            Gio.Subprocess.new(['rm', '-rf', tmpDir], Gio.SubprocessFlags.NONE);
        }
        this.markReady();
    }

    async _showFirstFrame() {
        const frame = await this._image.next_frame_async(this.cancellable);
        this._texture = GlyGtk4.frame_get_texture(frame);
        this.set_paintable(this._texture);
    }
};

export const contentTypes = [
    'image/x-nikon-nef', 'image/x-nikon-nrw', 'image/x-adobe-dng',
    'image/x-canon-cr2', 'image/x-canon-cr3', 'image/x-canon-crw',
    'image/x-sony-arw', 'image/x-sony-sr2', 'image/x-sony-srf',
    'image/x-fuji-raf', 'image/x-olympus-orf', 'image/x-panasonic-rw2',
    'image/x-panasonic-rw', 'image/x-pentax-pef', 'image/x-samsung-srw',
    'image/x-leica-rwl', 'image/x-minolta-mrw', 'image/x-kodak-dcr',
    'image/x-kodak-kdc', 'image/x-sigma-x3f', 'image/x-hasselblad-3fr',
    'image/x-phaseone-iiq',
];
