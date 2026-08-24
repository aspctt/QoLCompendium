"""Builds the cut up clothing patch for QoL Compendium.

Build 42 decides whether a garment can be cut into strips from a tag, base:ripclothingcotton
for the ones that tear by hand and base:ripclothingdenim or base:ripclothingleather for the
ones that need scissors. That tag is separate from FabricType, which is what the garment is
actually made of, and the two disagree constantly.

Two different gaps come out of that, and this closes both.

The first needs no judgement at all. Sixty six garments carry a FabricType and were never
given a rip tag, so the game already knows what they are made of and simply will not let you
cut them up: every pair of underwear, every sock, the bandanas, the shemagh scarves, the
cloth and leather gloves, the hide trousers, Belt2 and Shoes_LeatherWrap. Those are read
straight out of the installed scripts rather than listed here, so the material is always the
game's own answer and never ours.

The second is the shoes. Vanilla gives twenty nine of them no FabricType whatsoever, so
there is nothing to read and a material has to be chosen. That is the table below, and it is
written out by hand precisely because it is a judgement rather than a fact.

Rubber is left alone. Wellies, flip flops and tyre sandals are not cloth and yield nothing a
tailor could use, so they stay uncuttable rather than being quietly called leather.

Three items that carry a FabricType are excluded on purpose: RippedSheets, DenimStrips and
LeatherStrips are what the recipes produce, and tagging an output as an input is a loop that
turns one strip into an endless supply.

Reads the installed game rather than a copy, so a rename between builds fails here loudly
instead of shipping a line that matches nothing. checkItemTypes in
tests/harness/TestRunner.java is the second net under that.

    python tools/generate_cut_clothing.py            write the script
    python tools/generate_cut_clothing.py --check    report without writing
"""

import argparse
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME = r"S:\SteamLibrary\steamapps\common\ProjectZomboid\media\scripts"
DEST = os.path.join(
    ROOT, "QoLCompendium", "Contents", "mods", "QoLCompendium",
    "42", "media", "scripts", "qolc_cut_clothing.txt")

# The same garments again, as a table lua can read. The sandbox switch has to tell what this
# mod made cuttable from what always was, and the obvious way to ask, the marker tag, is not
# reachable: InventoryItem.hasTag takes ItemTag objects rather than strings. Written by the
# same pass as the script so the two cannot drift apart.
DEST_LUA = os.path.join(
    ROOT, "QoLCompendium", "Contents", "mods", "QoLCompendium",
    "42", "media", "lua", "shared", "qolc_cut_clothing_items.lua")

# The tag each fabric is cut with. Cotton tears by hand, the other two need scissors or a
# sharp knife, which is vanilla's own split and not one of ours.
TAG = {
    "Cotton": "base:ripclothingcotton",
    "Denim": "base:ripclothingdenim",
    "Leather": "base:ripclothingleather",
}

# No marker tag of our own is added alongside vanilla's. One was, and it was dead weight:
# the sandbox switch cannot read it back, because InventoryItem.hasTag takes ItemTag objects
# rather than strings, so the switch reads the generated list in DEST_LUA instead. A tag
# nothing tests is a tag that quietly stops matching what it was meant to mark.

# What the recipes turn each fabric into, for the output mapper.
STRIPS = {
    "Cotton": "Base.RippedSheets",
    "Denim": "Base.DenimStrips",
    "Leather": "Base.LeatherStrips",
}

# The outputs themselves, which must never become inputs.
EXCLUDE = ("RippedSheets", "DenimStrips", "LeatherStrips")

# Garments vanilla never gave a fabric to at all, so one is chosen here. Leather unless the
# thing is plainly something else: trainers and slippers are cloth, burlap and twine are
# plant fibre and go in with cotton for want of a fibre of their own, and everything rubber
# is left out entirely.
CHOSEN = {
    "Gloves_FingerlessGloves": "Cotton",
    "Gloves_FingerlessLeatherGloves": "Leather",
    "Gloves_FingerlessLeatherGloves_Black": "Leather",
    "Gloves_FingerlessLeatherGloves_Brown": "Leather",

    "Shoes_ArmyBoots": "Leather",
    "Shoes_ArmyBootsDesert": "Leather",
    "Shoes_Black": "Leather",
    "Shoes_BlackBoots": "Leather",
    "Shoes_Bowling": "Leather",
    "Shoes_Brown": "Leather",
    "Shoes_CowboyBoots": "Leather",
    "Shoes_CowboyBoots_Black": "Leather",
    "Shoes_CowboyBoots_Brown": "Leather",
    "Shoes_CowboyBoots_Fancy": "Leather",
    "Shoes_CowboyBoots_SnakeSkin": "Leather",
    "Shoes_CrudeLeatherFootwear": "Leather",
    "Shoes_Fancy": "Leather",
    "Shoes_HideBoots": "Leather",
    "Shoes_HikingBoots": "Leather",
    "Shoes_RidingBoots": "Leather",
    "Shoes_Sandals": "Leather",
    "Shoes_Strapped": "Leather",
    "Shoes_WorkBoots": "Leather",

    "Shoes_BlueTrainers": "Cotton",
    "Shoes_RedTrainers": "Cotton",
    "Shoes_TrainerTINT": "Cotton",
    "Shoes_Slippers": "Cotton",
    "Shoes_BurlapWrap": "Cotton",
    "Shoes_Twine": "Cotton",
}

# Wallets. Not clothing at all, ItemType = base:container, so they cannot go anywhere near
# RipClothing or RipDenimClothing: RecipeCodeOnCreate.ripClothing casts its input to Clothing
# and asks it for a FabricType, which a container has not got. They get a recipe of their own
# below instead, and an empty one at that, so nobody shreds a wallet with the car keys in it.
WALLETS = ("Wallet", "Wallet_Male", "Wallet_Female", "Wallet_Hide")

# What one wallet is worth. Small, and the leather in it is thin.
WALLET_STRIPS = 1

# Named so the reason they are absent is on the record rather than looking like an oversight.
RUBBER = ("Shoes_FlipFlop", "Shoes_Wellies", "Shoes_TireSandals")

# A spawner rather than a garment anybody wears.
NOT_A_GARMENT = ("Shoes_Random",)

# Vanilla misspells the tag on this one, so it can never be ripped however it is approached.
TYPO = {"Tshirt_EMD": "Cotton"}


def read_items():
    """Every item block in the installed game, by name."""
    items = {}

    for root, _dirs, files in os.walk(GAME):
        for name in files:
            if not name.endswith(".txt"):
                continue

            text = io.open(os.path.join(root, name), encoding="utf-8", errors="replace").read()
            for match in re.finditer(r"^\s*item\s+(\w+)\s*$", text, re.M):
                depth = 0
                start = text.index("{", match.end())

                for index in range(start, len(text)):
                    if text[index] == "{":
                        depth += 1
                    elif text[index] == "}":
                        depth -= 1
                        if depth == 0:
                            items[match.group(1)] = text[start:index + 1]
                            break

    return items


def classify(items):
    """The two tiers, as (name, fabric) pairs sorted by name."""
    declared = []
    for name, body in sorted(items.items()):
        if name in EXCLUDE:
            continue

        fabric = re.search(r"FabricType\s*=\s*(\w+)", body)
        if not fabric or fabric.group(1) not in TAG:
            continue
        if re.search(r"base:ripclothing\w+", body):
            continue

        declared.append((name, fabric.group(1)))

    chosen = []
    for name, fabric in sorted(CHOSEN.items()):
        if name not in items:
            raise SystemExit("no such item in this build: " + name)
        chosen.append((name, fabric))

    return declared, chosen


def block(name, fabric, needs_fabric):
    lines = ["\titem " + name, "\t{"]
    if needs_fabric:
        lines.append("\t\tFabricType = " + fabric + ",")
    lines.append("\t\tTags = " + TAG[fabric] + ",")
    lines.append("\t}")

    return "\n".join(lines)


def build(declared, chosen):
    out = []
    out.append("/*")
    out.append(" * Cut Up Any Clothing")
    out.append(" * aspctt - 23.08.2026")
    out.append(" * Generated by tools/generate_cut_clothing.py, do not edit by hand.")
    out.append(" *")
    out.append(" * Build 42 decides whether a garment can be cut into strips from a tag, and that tag")
    out.append(" * is separate from the FabricType saying what the garment is made of. The two disagree")
    out.append(" * constantly: underwear, socks, bandanas, scarves and gloves all declare a fabric and")
    out.append(" * were never tagged, so the game knows they are cotton and still will not let you cut")
    out.append(" * them up. Shoes have it worse and carry no fabric at all.")
    out.append(" *")
    out.append(" * Reopening an item merges rather than replaces, and a Tags value is added to the set")
    out.append(" * rather than overwriting it, so everything that makes these garments work is untouched.")
    out.append(" *")
    out.append(" * The tags cannot be switched off from here, because a lua tag patch lands after the")
    out.append(" * recipes have already cached their inputs. The sandbox switch is the recipes' OnTest")
    out.append(" * instead, reading the same list this pass writes to qolc_cut_clothing_items.lua.")
    out.append(" *")
    out.append(" * Rubber footwear is deliberately absent: " + ", ".join(RUBBER) + ".")
    out.append(" */")
    out.append("module Base")
    out.append("{")

    out.append("\t/* Vanilla declares the fabric and never tagged them. " + str(len(declared)) + " garments. */")
    for name, fabric in declared:
        out.append(block(name, fabric, needs_fabric=False))
        out.append("")

    out.append("\t/* Vanilla gives these no fabric at all, so one is chosen. " + str(len(chosen)) + " garments. */")
    for name, fabric in chosen:
        out.append(block(name, fabric, needs_fabric=True))
        out.append("")

    out.append("\t/* Vanilla spells this one base:ripclothingcoton, so it matches nothing. */")
    for name, fabric in sorted(TYPO.items()):
        out.append(block(name, fabric, needs_fabric=False))
        out.append("")

    out.append(recipes(declared, chosen))
    out.append("}")

    return "\n".join(out).rstrip() + "\n"


def recipes(declared, chosen):
    """The two recipe patches, reopened rather than rewritten."""
    leather = sorted(name for name, fabric in declared + chosen if fabric == "Leather")

    out = []
    out.append("\t/*")
    out.append("\t * The mapper decides what the crafting screen predicts, and nothing else. What a")
    out.append("\t * garment actually turns into is settled by RecipeCodeOnCreate.ripClothing, which")
    out.append("\t * reads the garment's FabricType and looks the strips up in")
    out.append("\t * ClothingRecipesDefinitions. The mapper is never consulted for that.")
    out.append("\t *")
    out.append("\t * So this is not what makes leather boots give leather strips. They would do that")
    out.append("\t * on the strength of their FabricType alone. It is here because vanilla's mapper")
    out.append("\t * lists eleven jackets and pairs of trousers by name and defaults everything else")
    out.append("\t * to denim strips, so without it the screen promised denim and handed over leather.")
    out.append("\t *")
    out.append("\t * Reopening the recipe adds to that mapper rather than replacing it. Verified in the")
    out.append("\t * jar: LoadOutputMapper calls getOrCreateOutputMapper, which returns the existing")
    out.append("\t * mapper when one is already registered under that name, and PreReloadScripts runs as")
    out.append("\t * one pass over every script before any file is parsed rather than per block. So")
    out.append("\t * vanilla's eleven stay and these are added to them, and a leather item the game adds")
    out.append("\t * later still arrives on its own.")
    out.append("\t *")
    out.append("\t * No icon is set. One was, scissors, on the reasoning that a recipe producing two")
    out.append("\t * different things cannot have one honest picture of its output. It is held back")
    out.append("\t * until the icon is actually seen to be wrong in game: with the mapper above in")
    out.append("\t * place a leather garment now reports leather strips rather than denim, which was")
    out.append("\t * the whole of the complaint, and replacing a correct icon with a tool would be a")
    out.append("\t * loss. See tools/generate_cut_clothing.py to put it back.")
    out.append("\t *")
    out.append("\t * OnTest is the sandbox switch. It runs per candidate item and refuses the ones this")
    out.append("\t * mod tagged when the option is off, leaving everything vanilla allows untouched.")
    out.append("\t */")
    out.append("\tcraftRecipe RipDenimClothing")
    out.append("\t{")
    out.append("\t\tOnTest = Recipe.OnTest.QolcCutClothing,")
    out.append("")
    out.append("\t\titemMapper fabricType")
    out.append("\t\t{")
    for name in leather:
        out.append("\t\t\t" + STRIPS["Leather"] + " = Base." + name + ",")
    out.append("\t\t}")
    out.append("\t}")
    out.append("")
    out.append("\t/* Cotton tears by hand and has one fixed output, so only the switch is needed. */")
    out.append("\tcraftRecipe RipClothing")
    out.append("\t{")
    out.append("\t\tOnTest = Recipe.OnTest.QolcCutClothing,")
    out.append("\t}")
    out.append("")
    out.append("\t/*")
    out.append("\t * Wallets, which are containers rather than clothing. They cannot join the two")
    out.append("\t * recipes above at any price: RecipeCodeOnCreate.ripClothing casts its input to")
    out.append("\t * Clothing and asks for a FabricType, and a container has neither. So this is a")
    out.append("\t * recipe of its own, with a fixed output and no OnCreate to go wrong.")
    out.append("\t *")
    out.append("\t * IsEmpty because a wallet holds things, and shredding one with the car keys still")
    out.append("\t * inside would be a poor reward for tidying up.")
    out.append("\t */")
    out.append("\tcraftRecipe QolcCutWallet")
    out.append("\t{")
    out.append("\t\ttimedAction = CutClothing,")
    out.append("\t\ttime = 60,")
    out.append("\t\tTags = InHandCraft;RemoveResultItems,")
    out.append("\t\tOnTest = Recipe.OnTest.QolcCutClothing,")
    out.append("\t\tcategory = Tailoring,")
    out.append("")
    out.append("\t\tinputs")
    out.append("\t\t{")
    out.append("\t\t\titem 1 tags[base:scissors;base:sharpknife] mode:keep flags[MayDegradeLight;Prop1;IsNotDull],")
    out.append("\t\t\titem 1 [" + ";".join("Base." + name for name in WALLETS) + "] mode:destroy flags[IsEmpty;ItemCount],")
    out.append("\t\t}")
    out.append("")
    out.append("\t\toutputs")
    out.append("\t\t{")
    out.append("\t\t\titem " + str(WALLET_STRIPS) + " " + STRIPS["Leather"] + ",")
    out.append("\t\t}")
    out.append("\t}")

    return "\n".join(out)


def lua_table(declared, chosen):
    out = []
    out.append("--// Cut Up Any Clothing, The List")
    out.append("--// aspctt - 23.08.2026")
    out.append("--// Generated by tools/generate_cut_clothing.py, do not edit by hand.")
    out.append("--//")
    out.append("--// Every garment qolc_cut_clothing.txt made cuttable, which is the only thing the")
    out.append("--// sandbox switch needs to know: with the feature off these go back to being")
    out.append("--// uncuttable and everything vanilla already allowed carries on untouched.")
    out.append("--//")
    out.append("--// A list rather than a tag test. Both halves carry qolc:cutclothing and reading it")
    out.append("--// back would be tidier, but InventoryItem.hasTag takes ItemTag objects rather than")
    out.append("--// strings and there is no route to one from lua. Written by the same pass that")
    out.append("--// writes the script, so the two cannot disagree.")
    out.append("--//")
    out.append("--// Shared, because the recipe is tested by whichever side is in charge.")
    out.append("")
    out.append("-- Wallets are in the table below as well, so the switch covers them, but they are")
    out.append("-- not clothing and are cut by a recipe of their own. Kept here separately so anything")
    out.append("-- reasoning about the clothing recipes can leave them out.")
    out.append("QolcCutClothingWallets = {")
    for name in WALLETS:
        out.append('\t["Base.' + name + '"] = true,')
    out.append("}")
    out.append("")
    out.append("QolcCutClothingAdded = {")

    for name, fabric in declared + chosen + sorted(TYPO.items()):
        out.append('\t["Base.' + name + '"] = "' + fabric + '",')

    for name in WALLETS:
        out.append('\t["Base.' + name + '"] = "Leather",')

    out.append("}")

    return "\n".join(out) + "\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    if not os.path.isdir(GAME):
        raise SystemExit("the installed game is not where this expects it: " + GAME)

    items = read_items()
    declared, chosen = classify(items)

    for name in RUBBER + NOT_A_GARMENT + WALLETS:
        if name not in items:
            raise SystemExit("no such item in this build: " + name)

    text = build(declared, chosen)

    print("read from the fabric the game already declares: %d" % len(declared))
    print("given a fabric here:                            %d" % len(chosen))
    print("left rubber:                                    %d" % len(RUBBER))
    print("total garments made cuttable:                   %d" % (len(declared) + len(chosen) + len(TYPO)))

    if args.check:
        return

    io.open(DEST, "w", encoding="utf-8", newline="\n").write(text)
    print("wrote " + DEST)

    io.open(DEST_LUA, "w", encoding="utf-8", newline="\n").write(lua_table(declared, chosen))
    print("wrote " + DEST_LUA)


if __name__ == "__main__":
    main()
