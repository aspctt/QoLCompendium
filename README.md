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

**Cut Up Any Clothing** - Underwear, socks, bras, corsets, tights, swimwear,
shoes, gloves, holsters, ties, hunting vests, shellsuits, rain ponchos and every
cloth hat in the game can be cut into strips. The base game decides that from a
tag that has nothing to do with what a garment is made of, so three hundred and
forty two items it already knows the fabric of, or could have, were simply
refused. Each yields whatever it is made of, so leather boots give leather
strips. An empty wallet cuts down for leather too, through a recipe of its own,
since a wallet is a container rather than clothing. Rubber, tarpaulin, straw and
armour still yield nothing, and firefighter gear is harvested for aramid thread
rather than cut.

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
spoils and food that does not. The base game files all 707 food items together,
which buries the only question that matters when you open a fridge.

**Reorder The Hotbar** - Drag hotbar slots into the order you want, and click a
slot to use it instead of reaching for the key. Dragging either swaps two slots
or slides one in between, whichever you pick, and the order can be locked. Slots
past the eighth need a key bound before clicking them does anything, which the
extra hotbar bindings above cover.

**Generator Info** - The generator window says how long the fuel will last, and
highlights every square the power reaches. Build 42 made the range a sandbox
setting, so a fixed number is wrong for anyone who changed it, and the fuel
figure is shown whether or not the generator is currently running.

**XP Boost Multipliers** - The skills panel says what a boost is really worth.
"+75%" is four times the experience, and Sprinting's first boost is five.
Fitness and Strength stay at four however many boosts they are given.

**Container Titles** - A container's name no longer runs into the weight printed
beside it.

**Flamingos** - Lawn flamingos are defined as a floor tile, so furniture placed
behind them or snow settling on them makes them disappear. They are objects
here, and render like every other ornament.

**Tailoring From Cutting Clothes** - Cutting a garment into strips teaches
tailoring, which the base game pays nothing for. Denim and leather pay per
strip, uniforms pay a bonus, and cutting gets quicker as the skill rises.

**Skill Book Icons** - Build 42 draws ten of the twenty four skill book families
with the same tinted sprite, so a shelf of them is hard to read. All twenty four
have their own icon.

**Flag A Book As Seen** - A book too advanced to learn from has a dead "Read"
entry on its menu. It now reads the first page instead, so a second copy found
later is recognisable as one you already own.

**Take Any Amount** - Vanilla offers one, half, or all. This adds a box you type
a number into, for taking out of a container and for putting into one.

**Reorder Duplicates By Condition** - Twenty knives in a crate sit in whatever
order they were dropped. This sorts them by how worn they are, how full, how
dirty or what they are worth eating, so the best or worst comes to hand first.

**Reasonable Alarms** - A house whose door already stands open, or whose window
is smashed, does not sound its alarm, and neither does a car left unlocked.
Anyone could have walked in long before you did. How far this goes is a sandbox
setting, because counting unlocked doors covers far more houses than open ones.

**Reading Settles The Mind** - Working through a skill book slowly eases
boredom, unhappiness and stress. The base game gives skill books no morale value
at all, only comics and newspapers. Each page takes a share of what is left, so
it settles a character without ever finishing the job, and illness weakens it.

**Sleep On It** - Boredom and unhappiness wear off while a character sleeps. The
base game freezes both instead, so a night's sleep changes neither. A full eight
hours clears boredom outright, and the rate is a server setting.

**Moodle Quarters** - One more quarter of a moodle's plate squares off for each
level it climbs, so the stack tells you how bad each moodle is at a glance
rather than by counting icons. Stands down on its own if you already run the
standalone mod, or Moodles in Lua, since both replace the same panel.

**The Nutritionist** - A magazine that teaches the Nutritionist trait, so food
tooltips start showing calories and the rest of the breakdown. The base game has
no way to learn a trait after character creation at all, so otherwise it costs
two points at the start or means taking Fitness Instructor. It spawns wherever
cooking magazines do, at half their odds.

**Flashlight On The Belt** - The base game hangs a screwdriver, a wrench, a walkie
talkie and a meat cleaver off a belt, but not a torch, so the thing you reach for
most in the dark is the one thing that has to live in a bag. All three torches
now hang from either belt slot. Attaching one does not switch it on.

**Sterilized Rag Uses** - A sterilized rag is the same cloth as a ripped sheet, but
the base game gives it one tag where the plain rag gets six, so it is refused as
binding, as fire fuel, as tinder and as weapon binding. It now carries those
tags, and works wherever a ripped sheet works.

**Cloth Recycling** - Tear a bath towel or a dish cloth into rags, and sew rags
back into a bedsheet. The base game can do neither: only the bedsheet itself
carries the tag that makes cloth rippable, so the two cloth things in every
bathroom and kitchen cannot be torn up at all. A towel gives three rags and a
dish cloth one, against a bedsheet's ten, and sewing costs twelve so the round
trip loses rather than gains.

**DIY Workbooks** - Four practice manuals, for carpentry, electrical, welding and
tailoring, found where books are. Holding one lets you work an exercise from it,
spending materials for experience in that trade. Every exercise is a net loss of
goods, so this is somewhere to put a surplus of planks or scrap once the world
has stopped offering anything else to build, not a way to make anything.

**Corpse Disposal** - Butcher a body for flesh that can be composted, and at
Cooking 7 prepare and then salt cure it over three days into meat a pot will
accept. Butchering pays butchering experience, at the rate the game gives for a
boar. The base game can burn, bury or dump a corpse but never get anything
back from one. Eating it before it is cured will make you very ill. Off by
default, being the one thing here that adds something rather than repairing it.

**Metalworking Gaps** - Forge recipes for four things the base game has items for
and no way to make: wire, metal pipe, welding rods and electrical wire. Wire is
the plainest case, being craftable only from barbed wire, which is craftable only
from wire. Sheet metal is left alone, since that one genuinely works.

**Lockpicking** - Pick a locked door with a screwdriver and a lockpick, or lever a
door or window open with a crowbar. Car doors and boots too, where a wrecked lock
never works again for anyone, the key included. Failing a pick jams the lock for
good, and the pick can stick or snap. Two manuals teach it, and a burglar already
knows. Hairpins spawn with the make-up. The base game has no lockpicking at all.
Picking and prying are separate sandbox switches, so a server can have one
without the other. Both tools are found by tag, so a forged crowbar, a multitool,
and anything a mod adds all count.


Options
-------

Anything cosmetic is configurable in **Options -> Mods**, with each feature in
its own section. These settings are per player.

Every feature can be turned off on its own bar one. Features with nothing else to
configure share a **Features** list of tick boxes at the top; features with
settings of their own keep their switch beside those settings. The exception is
**Sterilized Rag Uses**, which widens an item's tags as the scripts load. Recipe
inputs resolve their tags into a fixed list at that moment, so the change has to
land before any setting is known and there is nowhere to hang a switch. Skill book icons,
ammo icons and the split food categories are stamped onto item scripts as the
game loads them, so those three take effect on the next start rather than
immediately.

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

Every mod below inspired a feature here. **With four exceptions, no files or
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
| Generator Info | [Generator Time Remaining](https://steamcommunity.com/sharedfiles/filedetails/?id=2883397918) and [Visible Generator Range](https://steamcommunity.com/sharedfiles/filedetails/?id=2972289937) | Idea only from both, written from the game's own fuel maths. Build 42 moved the range into sandbox options, so the original's fixed number is wrong. |
| XP Boost Multipliers | [Fix XP View](https://steamcommunity.com/sharedfiles/filedetails/?id=2341974040) | Rewritten. The original crashes the skills panel on build 42 via `HasTrait`, and its multipliers were wrong. Rebuilt from `AddXP`. |
| Container Titles | [Fix Capacity Overlap](https://steamcommunity.com/sharedfiles/filedetails/?id=2957932451) | Rewritten. Wraps `prerender` rather than replacing it, and stands down for Clean UI. |
| Flamingos | [Flamingo Fix](https://steamcommunity.com/sharedfiles/filedetails/?id=2913993465) | Open source, see [NOTICE](NOTICE). Rebuilt from build 42 tile data; the original file is a build 41 subset. |
| Tailoring From Cutting Clothes | [Tailoring Fix](https://steamcommunity.com/sharedfiles/filedetails/?id=2138726101) | Rewritten. Hooks the recipe action, so it awards on both sides in multiplayer. |
| Skill Book Icons, Flag A Book As Seen | [An Exhilaratingly Organized Literature Mod](https://steamcommunity.com/sharedfiles/filedetails/?id=2071347174) | Idea only. Icons generated by `tools/generate_book_icons.py`. Its sorting and renaming are obsolete: build 42 categorises and names literature natively. |
| Take Any Amount | [Take Any Amount](https://steamcommunity.com/sharedfiles/filedetails/?id=2985394645) | Permission granted with credit, see [NOTICE](NOTICE). Rewritten; the original replaces a vanilla function build 42 has since added a destination check to. |
| Reorder Duplicates By Condition | [Reorder Duplicates by Condition](https://steamcommunity.com/sharedfiles/filedetails/?id=2766834021) | Rewritten. Three accessors it uses are gone in build 42, and this queues the fewest moves rather than rewriting the whole container. |
| Reasonable Alarms | [Reasonable Crime Preventation Alarm](https://steamcommunity.com/sharedfiles/filedetails/?id=1967450889) | Rewritten. Its vehicle half throws on build 42, which moved vehicle parts behind a new accessor, and its settings file is a sandbox page here. |
| Reading Settles The Mind | [Reading is not boring.](https://steamcommunity.com/sharedfiles/filedetails/?id=1949441990) | Rewritten. Build 42 removed every stat accessor it used. Skill books only, and it counts pages off the action so it works on a multiplayer client. |
| Sleep On It | [Sleep On It](https://steamcommunity.com/sharedfiles/filedetails/?id=2673713236) by Stultusaur | Rewritten. Already a build 42 version, so this is for shape: its client command round trip changed the server's copy without syncing it back, and it only ever covered the first player. |
| Moodle Quarters | [Moodle Quarters](https://steamcommunity.com/sharedfiles/filedetails/?id=2854030563) by DahakaMVl | **Bundles the original plate art.** Explicit permission. The build 42 support is this project author's own work, merged upstream, so it is carried across unchanged. See [NOTICE](NOTICE). |
| The Nutritionist | [The Nutritionist](https://steamcommunity.com/sharedfiles/filedetails/?id=1934095105) | Rewritten. Build 42 replaced the trait API, so every call it made is gone. Its metatable swap of ReadLiterature is dropped as unnecessary. |
| Flashlight On The Belt | [Common Sense](https://steamcommunity.com/sharedfiles/filedetails/?id=2875848298) by BitBraven | Idea only, built without reading its code, the same as Weapon Condition Indicator. Its author forbids redistribution and cannot be reached for permission. The torches, the belt slots and the rig positions are all the base game's. |
| Sterilized Rag Uses | [Desterilize Rags - Use Them In Other Recipes](https://steamcommunity.com/sharedfiles/filedetails/?id=2036923155) by Oh God Spiders No | Rewritten, and to a different design. The original added a recipe to downgrade a sterilized rag back to a plain one. This gives the rag the tags it was missing instead, so no conversion step is needed. |
| Lockpicking | [Lockpicking. Just. Lockpicking.](https://steamcommunity.com/sharedfiles/filedetails/?id=2056238799) by FMJ, MeTaLAnGeR and Oh God Spiders No | **Bundles its icons and two sounds.** Included with permission. Rebuilt: build 42 removed TraitFactory, ProfessionFactory and the old recipe format outright. See [NOTICE](NOTICE). |

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

Two of the exceptions are artwork. A 3D model or an icon cannot be rewritten from
a description, so the sling's models and hotbar code are the originals by **Akyet**
and **Noir**, and the ammo icons are by **falcon33jp**. The sling's recipe and
spawn tables, and all of the ammo icon code, were written for this project.

The third is **Moodle Quarters** by **DahakaMVl**, included with explicit
permission. Its plate art is the original, and so is the code that draws the
stack, because that build 42 support was written for this project and merged
upstream: the two copies are meant to stay the same file.

The fourth is **Lockpicking. Just. Lockpicking.** by **FMJ**, **MeTaLAnGeR** and
**Oh God Spiders No**, whose icons and two sound files are the originals. Its
code was rebuilt against build 42, which deleted the trait and profession
factories and the old recipe format it was written on. Full detail is in
[NOTICE](NOTICE).

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

The icons ship as one atlas rather than as loose files. Source art lives in
`tools/textures`, and this lays it out and writes
`common/media/texturepacks/QoLCompendium.pack`:

```
python tools/pack_textures.py
```

The full screen overlays, the sling's model texture and the moodle plates stay
loose on purpose. The reasons are at the top of the script.


Licence
-------

All Rights Reserved. See [LICENSE](LICENSE), and [NOTICE](NOTICE) for bundled
third party work.

Project Zomboid is the property of The Indie Stone. This is an unofficial mod and
is not affiliated with or endorsed by them.
