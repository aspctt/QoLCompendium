QoL Compendium
==============

A single mod that collects small quality of life fixes for Project Zomboid and
keeps them working on the current build.

Plenty of good mods stopped being updated when build 42 landed. This rebuilds
them, one at a time, against the game as it is now.

**Build 42.20+ | Singleplayer and multiplayer**


Features
--------

**Immersive Overlays** - The screen tints when you are hurt, exhausted, freezing
or overheating, so you feel your condition instead of reading it off a moodle.
Each overlay can be turned off or dialled down on its own.

**Bigger Character Avatar** - The 3D character in your info panel is doubled in
size, so you can actually see what you are wearing. Scale it however you like,
or turn it off.

**Welding Torch Capacity** - A welding torch holds 16 uses instead of 10, and a
propane tank refills it 30 times instead of 7. Topping up a half full torch only
costs half a tank's worth, rather than a full charge.

**Ammo Icons** - Every ammo box and magazine gets its own inventory icon. The
base game draws all five handgun ammo boxes identically, which makes sorting
ammo needlessly fiddly.

**Rifle Sling** - Wear a rifle, shovel or big weapon on a sling, worn at the
front or across your back. Craftable at Tailoring 4, or found in gun stores and
military lockers.

**Adrenaline** - Panic holds tiredness at bay. A character fighting for their
life sheds the Drowsy debuff and performs properly for a while, then pays it all
back with interest once they calm down. Sleep is still the only real fix.

**Weapon Condition** - Each equipped weapon and each hotbar slot fills with
colour to show how much of it is left, so you can see what is about to break
without hovering it. Green while healthy, amber under half, red under a quarter.

**Propane From Fuel Pumps** - Refill a propane tank at any working fuel pump.
The base game has no way to refill one at all, so a spent tank is dead weight
and welding has a hard ceiling. Costs pump fuel, and the server sets how much.

**Clothing Material** - Every garment's tooltip says what it is made of. The
game already tracks whether something is cotton, denim or leather, and uses it
for patching and for what the garment rips into, but never tells you.

**Food Categories** - Splits the inventory's single Food heading into food that
spoils and food that keeps. The base game files all 707 food items together,
which buries the only question that matters when you open a fridge.

**Reorder The Hotbar** - Drag hotbar slots into the order you want, and click a
slot to use it instead of reaching for the key. Dragging either swaps two slots
or slides one in between, whichever you pick, and the order can be locked. Slots
past the eighth need a key bound before clicking them does anything, which the
extra hotbar bindings above cover.


Options
-------

Anything cosmetic is configurable in **Options -> Mods**, with each feature in
its own section. These settings are per player.

Anything that changes game balance lives in the **QoL Compendium** sandbox page
instead, set when the world is created or by the server admin. That way every
player in a multiplayer game is playing to the same numbers, rather than each
client quietly running its own.


Installation
------------

Subscribe on the Steam Workshop, then enable it in the mod list.

To install by hand, copy `QoLCompendium/Contents/mods/QoLCompendium` into
`%UserProfile%\Zomboid\mods\`. For a server, add `QoLCompendium` to `Mods=` in
your server config, and the Workshop id `3781012462` to `WorkshopItems=`.

This repository is laid out the way Steam expects a Workshop item, so the mod
itself sits at `QoLCompendium/Contents/mods/QoLCompendium/`.


Building on other people's work
-------------------------------

Every mod below inspired a feature here. **With two exceptions, no files or
code were taken from any of them.** Each was read to understand what it did, then
written from scratch against build 42, usually because the original no longer
ran at all.

| Feature | Inspired by | |
| --- | --- | --- |
| Immersive Overlays | [Immersive Overlays](https://steamcommunity.com/sharedfiles/filedetails/?id=533622988) by Stephanus van Zyl | Rewritten. Textures generated from scratch. |
| Bigger Character Avatar | [Bigger Character Avatar](https://steamcommunity.com/sharedfiles/filedetails/?id=3245854570) | Rewritten. The original replaced a whole vanilla file; this changes two numbers. |
| Welding Torch Capacity | [Propane Torch Fix](https://steamcommunity.com/sharedfiles/filedetails/?id=2883755057) | Rewritten. Build 42 already fixed the original bug, so only the economy changed. |
| Rifle Sling | [Actual Realistic Rifle Sling](https://steamcommunity.com/sharedfiles/filedetails/?id=3073937977) | **Bundles the original models and hotbar code.** See below. |
| Ammo Icons | [Ammo & Magazine icon MOD](https://steamcommunity.com/sharedfiles/filedetails/?id=1904952813) by falcon33jp | **Bundles 12 original icons.** Code written from scratch. |
| Adrenaline | [Adrenaline - Panic Counters Tiredness](https://steamcommunity.com/sharedfiles/filedetails/?id=2807001835) | MIT licensed. Rewritten, the stat API it used no longer exists. Balance values kept. |
| Reorder The Hotbar | [Reorder The Hotbar](https://steamcommunity.com/sharedfiles/filedetails/?id=2903771337) | MIT licensed. Rewritten. Build 42 added the key lookup and the order saving it had to carry itself. |
| Food Categories | [Better Sorting](https://steamcommunity.com/sharedfiles/filedetails/?id=2313387159) by ChobitsCrazy | Idea only, see below. Written from scratch against the base game's own data. |
| Propane From Fuel Pumps | [Pumps Have Propane](https://steamcommunity.com/sharedfiles/filedetails/?id=2739570406) by Uncle Griz | Rewritten. Build 42 rebuilt fuel pumps as entities, so only the idea carried over. |
| Weapon Condition | [Weapon Condition Indicator](https://steamcommunity.com/sharedfiles/filedetails/?id=2619072426) by NoctisFalco | Idea only, see below. Built without reading its code. |
| Clothing Material | [Show Clothes Material](https://steamcommunity.com/sharedfiles/filedetails/?id=1922750845) | Rewritten. Uses the base game's own tooltip field, so it overrides no interface code. |

**A note on Weapon Condition Indicator.** Its author does not permit
redistribution or modified versions, so none of its files or code were opened,
and the version here was written against the base game's own `getCondition` with
no artwork at all, the bar being two rectangles. A weapon durability readout is
a common idea implemented many times over; only that idea is shared.

**A note on Better Sorting.** It is GPL-3.0, which cannot be combined with this
project's licence, so none of its code or data is used or referred to here. Only
the idea of separating food that spoils from food that does not was taken, and
ideas are not what a licence covers. Everything else that mod does, build 42 now
does natively and in more detail: 82 item categories covering every item in the
game, where build 41 left many of them filed as a bare "Item".

The exceptions are artwork. A 3D model or an icon cannot be rewritten from a
description, so the sling's models and hotbar code are the originals by **Akyet**
and **Noir**, and the ammo icons are by **falcon33jp**. The sling's recipe and
spawn tables, and all of the ammo icon code, were written for this project. Full
detail is in [NOTICE](NOTICE).

Mods whose authors ask that their work not be redistributed are not included
here, and will not be.

If you are one of these authors and would rather not be involved, say so and
your work comes out.


Development
-----------

The mod runs on Project Zomboid's own Lua VM, so it can be tested without
launching the game:

```
pwsh tests/run-tests.ps1
```

That loads the real mod source into the VM out of `projectzomboid.jar`, stubs the
game API, and runs the specs in `tests/specs`. It also checks every file compiles
and that no code refers to a game constant that the installed build no longer has.
A full run takes under a second. See [tests/README.md](tests/README.md).

The textures are generated, not painted:

```
python tools/generate_overlays.py
```

```
python tools/generate_ui_icons.py
```


Licence
-------

All Rights Reserved. See [LICENSE](LICENSE), and [NOTICE](NOTICE) for bundled
third party work.

Project Zomboid is the property of The Indie Stone. This is an unofficial mod and
is not affiliated with or endorsed by them.
