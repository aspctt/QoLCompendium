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


Options
-------

Anything cosmetic is configurable in **Options -> Mods**, with each feature in its
own section. Settings are per player.

Anything that changes game balance is deliberately not configurable, so a
multiplayer client cannot drift out of step with its server.


Installation
------------

Copy the `QoLCompendium` folder into `%UserProfile%\Zomboid\mods\`, then enable
it in the mod list. For a server, add `QoLCompendium` to `Mods=` in your server
config.


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

The overlay textures are generated, not painted:

```
python tools/generate_overlays.py
```


Licence
-------

All Rights Reserved. See [LICENSE](LICENSE), and [NOTICE](NOTICE) for bundled
third party work.

Project Zomboid is the property of The Indie Stone. This is an unofficial mod and
is not affiliated with or endorsed by them.
