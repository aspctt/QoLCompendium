"""Rebuild the mod's texture pack so the icons ship in one file instead of 143.

Project Zomboid loads a .pack as an atlas plus a table of named sprites. Every name
in that table becomes a global texture name, and the lookup throws the path away.
Verified in the jar rather than assumed: Texture.getSharedTextureInternal normalises
the separators, strips the extension at the last dot, strips everything up to the
last slash, and asks TexturePackPage.getTexture for what is left. Only then does it
fall through to the file system. So `getTexture("media/textures/GUI/qolc_swap.png")`
in lua and `Icon = QolcBookAiming1` in a script both resolve out of the pack with no
code change, as long as the sprite is named after the file it replaces.

Two things in that method are worth knowing before adding anything to the pack. A
path ending in .txt is never looked up in a pack, and neither is one containing
"/mods/", so a texture referenced by an absolute mod path would silently keep
reading from disk.

What stays loose, and why:

  The five moodle overlays. They are 1920x1080 each, which is more pixels than
  everything else here put together by a factor of two hundred, and an atlas holding
  them would be nine times the width the base game's own pages stop at. They are
  drawn one at a time over the whole screen, so there is no draw call to save.

  media/textures/Clothes/Sling/SlingTexture.png. A model binds its texture whole and
  samples it with the mesh's own UVs, which run 0 to 1 over the entire image, so a
  model pointed at an atlas would draw a slice of every other sprite on the page. The
  base game ships its world item textures loose for the same reason.

  media/ui/MoodleQuarters. Forty eight files, but only eight names: good_1 through
  good_4 and bad_1 through bad_4, repeated once per size folder. A pack namespace is
  flat, so packing them would leave one size and lose five. They are picked by
  building the path from the size, which is the one lookup shape a pack cannot serve.

The format, little-endian throughout. Build 42 writes the newer of the two:

    "PZPK"                   newer files only, older ones start at the page count
    int32   version          newer files only, must be 1
    int32   page count
    per page:
        int32 len + bytes    page name
        int32 sprite count
        int32 alpha          nonzero if the page has an alpha channel
        per sprite:
            int32 name len + bytes
            int32 x, y, w, h     rect within the atlas PNG
            int32 offX, offY     offset of that rect within the cell
            int32 cellW, cellH   the sprite's full logical size
        newer: int32 png byte length, then the png
        older: the png, terminated by the bytes EF BE AD DE

Older files are read but never written. Terminating the image with a sentinel means
the loader scans for it a byte at a time, and any pack whose compressed image
happened to contain those four bytes would end early.

Source art lives in tools/textures and is what ships. The generators write there:
generate_book_icons.py for the skill books, generate_ui_icons.py for the small
interface icons. Nothing loose is left in the mod for anything named here, because a
loose file that is also packed is a second copy that can quietly disagree.

Run it after changing any source art:  python tools/pack_textures.py
"""

import io
import os
import struct

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
MEDIA = os.path.join(
    HERE, "..", "QoLCompendium", "Contents", "mods", "QoLCompendium", "common", "media",
)
PACK = os.path.join(MEDIA, "texturepacks", "QoLCompendium.pack")
SOURCE = os.path.join(HERE, "textures")

PACK_NAME = "QoLCompendium"
PADDING = 2             # transparent gutter, so filtering cannot bleed neighbours
MAX_WIDTH = 1024        # the width the base game's own atlas pages stop at
SENTINEL = b"\xef\xbe\xad\xde"

# Where a loose copy would still be sitting after a rename or a half finished move.
# Anything the pack names must not also exist here, or the two can disagree and only
# one of them is what the game actually draws.
LOOSE = (
    os.path.join(MEDIA, "textures"),
    os.path.join(MEDIA, "textures", "GUI"),
)


def read_pack(path):
    """Return (page name, alpha, [(name, x, y, w, h, offX, offY, cellW, cellH)], atlas)."""
    d = open(path, "rb").read()

    i = 0
    if d[:4] == b"PZPK":
        i = 4
        version, = struct.unpack_from("<i", d, i)
        i += 4
        if version != 1:
            raise SystemExit("unsupported pack version %d: %s" % (version, path))

    pages, = struct.unpack_from("<i", d, i)
    i += 4
    if pages != 1:
        raise SystemExit("expected a single page, found %d" % pages)

    n, = struct.unpack_from("<i", d, i)
    i += 4
    name = d[i:i + n].decode()
    i += n

    count, alpha = struct.unpack_from("<ii", d, i)
    i += 8

    sprites = []
    for _ in range(count):
        ln, = struct.unpack_from("<i", d, i)
        i += 4
        sprite = d[i:i + ln].decode()
        i += ln
        sprites.append((sprite,) + struct.unpack_from("<8i", d, i))
        i += 32

    if d[:4] == b"PZPK":
        length, = struct.unpack_from("<i", d, i)
        i += 4
        atlas = d[i:i + length]
        i += length
    else:
        end = d.find(SENTINEL, i)
        if end == -1:
            raise SystemExit("no end-of-image marker: %s" % path)
        atlas = d[i:end]
        i = end + 4

    if i != len(d):
        raise SystemExit("%d trailing bytes, format not understood" % (len(d) - i))

    return name, alpha, sprites, Image.open(io.BytesIO(atlas)).convert("RGBA")


def shelf_pack(boxes, max_width):
    """Place (w, h) boxes left to right in rows. Returns positions and size."""
    positions = []
    x = y = row_height = width = 0
    for w, h in boxes:
        if x and x + w + PADDING > max_width:
            x = 0
            y += row_height + PADDING
            row_height = 0
        positions.append((x, y))
        x += w + PADDING
        width = max(width, x - PADDING)
        row_height = max(row_height, h)
    return positions, width, y + row_height


def read_existing():
    """What is already packed, so a rerun keeps trim offsets it did not set itself."""
    if not os.path.isfile(PACK):
        return PACK_NAME + "0", 1, {}

    page_name, alpha, sprites, atlas = read_pack(PACK)
    entries = {}
    for sprite, x, y, w, h, off_x, off_y, cell_w, cell_h in sprites:
        entries[sprite] = {
            "name": sprite,
            "image": atlas.crop((x, y, x + w, y + h)),
            "off": (off_x, off_y),
            "cell": (cell_w, cell_h),
        }

    return page_name, alpha, entries


def main():
    if not os.path.isdir(SOURCE):
        raise SystemExit("no source art at " + SOURCE)

    page_name, alpha, entries = read_existing()

    # Source art wins over whatever is already packed, so this can be run again without
    # sprites piling up or drifting from the files they came from.
    for file in sorted(os.listdir(SOURCE)):
        if not file.endswith(".png"):
            continue
        sprite = os.path.splitext(file)[0]
        image = Image.open(os.path.join(SOURCE, file)).convert("RGBA")
        entries[sprite] = {
            "name": sprite,
            "image": image,
            "off": (0, 0),
            "cell": image.size,
        }

    if not entries:
        raise SystemExit("nothing to pack")

    # A packed sprite and a loose file of the same name are two copies of one texture,
    # and the pack is looked at first, so the loose one would be dead weight that still
    # has to be right. Refuse rather than ship both.
    duplicates = []
    for folder in LOOSE:
        for file in sorted(os.listdir(folder)) if os.path.isdir(folder) else []:
            if file.endswith(".png") and os.path.splitext(file)[0] in entries:
                duplicates.append(os.path.relpath(os.path.join(folder, file), MEDIA))

    if duplicates:
        raise SystemExit(
            "packed and also loose in the mod:\n  " + "\n  ".join(duplicates) +
            "\n\ndelete the loose copies, the source of truth is tools/textures")

    # Tallest first packs a lot tighter than source order does.
    ordered = sorted(entries.values(), key=lambda e: (-e["image"].height, e["name"]))

    positions, width, height = shelf_pack([e["image"].size for e in ordered], MAX_WIDTH)

    sheet = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    for entry, (x, y) in zip(ordered, positions):
        sheet.paste(entry["image"], (x, y))
        entry["pos"] = (x, y)

    buffer = io.BytesIO()
    sheet.save(buffer, format="PNG", optimize=True)
    blob = buffer.getvalue()

    out = bytearray(b"PZPK")
    out += struct.pack("<ii", 1, 1)
    name = page_name.encode()
    out += struct.pack("<i", len(name)) + name
    out += struct.pack("<ii", len(ordered), alpha)
    for entry in ordered:
        sprite = entry["name"].encode()
        out += struct.pack("<i", len(sprite)) + sprite
        out += struct.pack("<8i", *entry["pos"], *entry["image"].size,
                           *entry["off"], *entry["cell"])
    out += struct.pack("<i", len(blob)) + blob

    before = os.path.getsize(PACK) if os.path.isfile(PACK) else 0
    os.makedirs(os.path.dirname(PACK), exist_ok=True)
    open(PACK, "wb").write(out)

    # Read it straight back, so a bad write never reaches the game.
    _n, _a, written, _atlas = read_pack(PACK)
    assert len(written) == len(ordered), "sprite count changed on the way out"
    for entry, got in zip(ordered, written):
        assert got[0] == entry["name"], "%s != %s" % (got[0], entry["name"])
        assert got[3:5] == entry["image"].size, "%s changed size" % got[0]

    print("%d sprites on a %dx%d atlas" % (len(ordered), width, height))
    print("%s.pack  %d -> %d bytes" % (PACK_NAME, before, len(out)))


if __name__ == "__main__":
    main()
