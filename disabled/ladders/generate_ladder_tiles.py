"""
Builds the ladder climb tiles for QoL Compendium.

Build 42 has no ladder climbing. Ladders are decorative: IsoPropertyType has no ladder
entry, and nothing in the game reads the ladderN/S/E/W properties the tiles still carry.
That is also why a server log fills with "Property Name not found: ladderW".

What build 42 does have is sheet rope climbing, and every gate on it is a sprite flag
rather than an object:

    IsoPlayer.doContextClimbSheetRope tests IsoFlagType.climbSheetN/S/E/W
    IsoWindow.isSheetRopeHere tests climbSheetTopN/S/E/W

both through IsoGridSquare.has(). No rope object is required anywhere in that chain. So
marking a ladder tile with those flags hands the whole feature to the base game: the
contextual action, the animation, the fall chance, and multiplayer, because it is vanilla's
own mechanic rather than something reimplemented beside it.

Nothing is taken from either ladder mod. The flags, the tiles and the animation are all
the base game's. The original mod ships no animation of its own either: its two files are
AnimSet nodes under player/climbrope and player/climbdownrope, so it drives the same
vanilla rope climb this does.

Both climbSheet and climbSheetTop go on every ladder tile. A sheet rope has a distinct top
sprite; a ladder is the same sprite repeated up a wall, so no tile can be the top one.
Marking each as both makes every rung a place you can get on and off, which is how a ladder
behaves anyway.

A tileset can only be replaced whole, so all 319 tiles of the four sheets holding ladders
are written out to change 18 of them. Everything else is copied verbatim from the installed
build, so this must be re-run after a game update that touches those sheets. checkTileDefs
in tests/harness/TestRunner.java fails the suite when that happens.

Usage:  python tools/generate_ladder_tiles.py
"""
import io
import os
import struct

ROOT = os.path.dirname(os.path.abspath(__file__))

# Beside this script while the feature is held back, so running it cannot put a tiledef
# into the shipping mod by accident. On restoring, point this at
# QoLCompendium/Contents/mods/QoLCompendium/common/media/ and move the script to tools/.
DEST = os.path.join(ROOT, 'qolc_ladders.tiles')

# Every sheet that holds a tile carrying a ladder property.
TILESETS = ['advertising_01', 'carpentry_02', 'industry_railroad_05', 'location_sewer_01']

GAME_DUMP = 'newtiledefinitions.tiles.txt'


def find_game_dir():
    """The install, from the same places tests/run-tests.ps1 looks."""
    if os.environ.get('QOLC_PZ_DIR'):
        return os.environ['QOLC_PZ_DIR']

    for drive in 'CDEFGHS':
        for path in (r'%s:\SteamLibrary\steamapps\common\ProjectZomboid' % drive,
                     r'%s:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid' % drive):
            if os.path.isfile(os.path.join(path, 'projectzomboid.jar')):
                return path

    raise SystemExit('Could not find a Project Zomboid install. Set QOLC_PZ_DIR.')


def read_tileset(lines, tileset):
    """One tileset as a list of property dicts indexed by slot, empties included."""
    start = next(i for i, l in enumerate(lines) if l.strip() == 'file = ' + tileset)
    end = next(i for i in range(start + 2, len(lines)) if lines[i].startswith('tileset'))

    width = height = None
    tiles, current = {}, None

    for line in lines[start:end]:
        text = line.strip()

        if text.startswith('size = '):
            width, height = [int(n) for n in text[7:].split(',')]
        elif text == 'tile':
            current = {}
        elif text.startswith('xy = ') and current is not None:
            x, y = [int(n) for n in text[5:].split(',')]
            tiles[y * width + x] = current
        elif current is not None and ' = ' in text:
            key, value = text.split(' = ', 1)
            if key != 'xy':
                current[key] = value.strip()
        elif current is not None and text.endswith('=') and len(text) > 1:
            current[text[:-1].strip()] = ''

    return width, height, [tiles.get(i, {}) for i in range(width * height)]


def add_climb_flags(tiles):
    """Give every tile carrying a ladder property the matching climb flags."""
    changed = 0

    for props in tiles:
        for key in list(props):
            if not key.startswith('ladder'):
                continue

            side = key[len('ladder'):]
            if side not in ('N', 'S', 'E', 'W'):
                continue

            props['climbSheet' + side] = ''
            props['climbSheetTop' + side] = ''
            changed += 1

    return changed


def encode(sheets):
    """sheets is a list of (name, width, height, tiles)."""
    out = bytearray(b'tdef')
    out += struct.pack('<i', 1)                 # format version
    out += struct.pack('<i', len(sheets))       # how many tilesets follow

    for number, (name, width, height, tiles) in enumerate(sheets, start=1):
        out += name.encode('utf-8') + b'\n'
        out += (name + '.png').encode('utf-8') + b'\n'

        # The third number is this tileset's position within the file, which the loader
        # rejects below 1. It is not the global id the game's own dump prints.
        out += struct.pack('<iiii', width, height, number, len(tiles))

        for props in tiles:
            out += struct.pack('<i', len(props))
            for key in sorted(props):
                out += key.encode('utf-8') + b'\n' + props[key].encode('utf-8') + b'\n'

    return bytes(out)


def main():
    dump = os.path.join(find_game_dir(), 'media', GAME_DUMP)
    if not os.path.isfile(dump):
        raise SystemExit('tile definition dump not found at %s' % dump)

    lines = io.open(dump, encoding='utf-8', errors='replace').read().split('\n')

    sheets, total = [], 0
    for tileset in TILESETS:
        width, height, tiles = read_tileset(lines, tileset)
        changed = add_climb_flags(tiles)
        if changed == 0:
            raise SystemExit('no ladder tile found in %s, this build may have moved them'
                             % tileset)

        total += changed
        sheets.append((tileset, width, height, tiles))
        print('%-24s %dx%d, %d tiles defined, %d made climbable'
              % (tileset, width, height, sum(1 for t in tiles if t), changed))

    data = encode(sheets)
    io.open(DEST, 'wb').write(data)

    print('\n%d ladder tiles across %d tilesets' % (total, len(sheets)))
    print('wrote %s, %d bytes' % (os.path.relpath(DEST, ROOT), len(data)))


if __name__ == '__main__':
    main()
