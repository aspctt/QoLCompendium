Ladders, held back
==================

Nothing in this folder is loaded. The mod itself lives at
`QoLCompendium/Contents/mods/QoLCompendium/`, and Project Zomboid only reads `42/media`
and `common/media` inside it, so these files sit outside the mod entirely. They are kept
here rather than deleted because the generator works and the investigation behind it took
a while.

What it does
------------

Build 42 has no ladder climbing at all. `IsoPropertyType` has no ladder entry and nothing
reads the `ladderN/S/E/W` properties the tiles still carry, which is also why a server log
fills with `Property Name not found: ladderW`. Ladders are decorative.

Build 42 does have sheet rope climbing, and every gate on it is a sprite flag rather than
an object:

    IsoPlayer.doContextClimbSheetRope  tests IsoFlagType.climbSheetN/S/E/W
    IsoWindow.isSheetRopeHere          tests climbSheetTopN/S/E/W

both through `IsoGridSquare.has()`. No rope object appears anywhere in that chain, which
was checked rather than assumed. So marking a ladder tile with those flags hands the whole
feature to the base game: the contextual action, the animation, the fall chance, and
multiplayer, because it is vanilla's own mechanic rather than something reimplemented.

Nothing is taken from either ladder mod. The original forbids redistribution in terms that
name this case twice, "distribution as part of another mod or modpack" and "distribution
of modified versions", and the unofficial build 42 port is itself a modified version, so
it is not an independent source either. None of that matters here: the flags, the tiles
and the animation are all the base game's.

Worth knowing, because it was the reason for wanting their code: the original ships no
animation of its own. Its only two files are AnimSet nodes under `player/climbrope` and
`player/climbdownrope`, and it ships zero `.X` assets, so it drives exactly the same
vanilla rope climb this approach does. There is no bespoke ladder animation to lose.

State
-----

The generator runs and produces a valid 37,940 byte tiledef covering 18 ladder tiles
across four tilesets:

    advertising_01         2 tiles
    carpentry_02           4 tiles
    industry_railroad_05   8 tiles
    location_sewer_01      4 tiles

Each gets `climbSheet` and `climbSheetTop` on the side its existing `ladder` property
names. A tileset can only be replaced whole, so all 319 tiles of those four sheets are
written out to change 18 of them.

What is left to do
------------------

`checkTileDefs` in `tests/harness/TestRunner.java` is written for the flamingo case alone.
It permits one named property to be **removed** from a named tile and nothing else, so
every added climb flag is reported as drift and the suite fails. It needs generalising so
each tiledef declares its own intended edit rather than the rule living in the
`DROPPED_PROPERTY` and `DROPPED_FROM` constants. Roughly twenty lines.

Unverified, and the reason this was not finished: whether the top of a ladder works. A
sheet rope has a distinct top sprite; a ladder is the same sprite repeated up a wall, so
no tile can be the top one. Marking every rung as both body and top is the attempt at
that, on the reasoning that a ladder can be got off at any floor, but only an in game test
settles it. The unofficial port's own description reports trouble here too, saying ladders
do not work with a staircase above.

Restoring
---------

    qolc_ladders.tiles          -> QoLCompendium/Contents/mods/QoLCompendium/common/media/
    generate_ladder_tiles.py    -> tools/

Point `DEST` in the generator back at the mod folder, it currently writes beside itself so
that running it while held back cannot ship anything by accident. Then add the tiledef to
`42/mod.info`, on its own line after the flamingo one:

    tiledef=qolc_ladders 3782

The number is the file number the loader keys the tileset ids from, and has to differ from
the flamingo file's 3781.

Re-run the generator after any game update that touches those four sheets, the same as the
flamingo one, or the shipped copy silently reverts someone else's work.
