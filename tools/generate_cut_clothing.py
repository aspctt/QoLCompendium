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

The second is everything the game never classified at all. Shoes are the clearest case and
were the whole of the first pass, but they are not alone: bras, corsets, tights, stockings,
swimwear, shellsuits, hunting vests, ties, ponchos and the better part of two hundred hats
all carry no FabricType, so there is nothing to read and a material has to be chosen. That
is the table below, and it is written out by hand precisely because it is a judgement rather
than a fact.

What is deliberately left uncuttable is written out too, with the reason attached, and the
two lists together have to account for every garment in the game. Anything the installed
scripts add that neither list names stops this pass with an error. The first pass had no
such check and shipped with tights, bras, berets, ponchos and the plain shoes still refused,
which is exactly the sort of hole a list nobody balances against anything develops.

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

# Where a tailor would recognise the thing as clothing. The completeness check below runs
# over these locations only.
#
# Everything absent from this is absent on purpose: armour plate, greaves, vambraces,
# shoulderpads, thigh and knee and elbow pads and chainmail are crafted from a material and
# vanilla offers no way back from any of them; jewellery, makeup, bandages, wounds, zombie
# damage overlays and glasses are not garments; gas masks, hockey masks, welding masks, SCBA
# rigs and the hazmat suit are equipment with a hard shell.
GARMENT_SLOTS = frozenset("""
	ankleholster belt beltextra dress fullsuit fulltop gorget hands hat fullhat jacket
	jacket_bulky jacket_down jackethat jackethat_bulky legs1 longdress longskirt mask neck
	neck_texture pants shoes shortpants shortsleeveshirt shortsshort skirt tanktop torsoextra
	torsoextravest tshirt underwear underwearbottom underwearextra1 underwearextra2
	underweartop
""".split())

#//////////////////////////////////////////////////////////////////////////////////////////
# Given a fabric here
#
# Vanilla declares none on any of these, so one is chosen. Leather unless the thing is
# plainly something else. Grouped by family, because the choice is a judgement and the
# reason for it belongs next to the names rather than in a flat alphabetical list.
#//////////////////////////////////////////////////////////////////////////////////////////
CHOSEN = {}

# Footwear. Trainers and slippers are cloth, burlap and twine are plant fibre and go in with
# cotton for want of a fibre of their own, and the rest is leather.
#
# Shoes_Random is the plain black or brown shoe a fresh character starts in and the one
# foraging turns up, so it is a garment players wear rather than a spawner. It was left out
# of the first pass as a spawner, which is why the commonest shoes in the game stayed
# uncuttable while the boots beside them did not. ClothingSelectionDefinitions.lua lists it
# twice and Foraging/Categories/Clothing.lua once.
CHOSEN.update(dict.fromkeys((
    "Shoes_ArmyBoots",
    "Shoes_ArmyBootsDesert",
    "Shoes_Black",
    "Shoes_BlackBoots",
    "Shoes_Bowling",
    "Shoes_Brown",
    "Shoes_CowboyBoots",
    "Shoes_CowboyBoots_Black",
    "Shoes_CowboyBoots_Brown",
    "Shoes_CowboyBoots_Fancy",
    "Shoes_CowboyBoots_SnakeSkin",
    "Shoes_CrudeLeatherFootwear",
    "Shoes_Fancy",
    "Shoes_HideBoots",
    "Shoes_HikingBoots",
    "Shoes_Random",
    "Shoes_RidingBoots",
    "Shoes_Sandals",
    "Shoes_Strapped",
    "Shoes_WorkBoots",
), "Leather"))

CHOSEN.update(dict.fromkeys((
    "Shoes_BlueTrainers",
    "Shoes_BurlapWrap",
    "Shoes_RedTrainers",
    "Shoes_Slippers",
    "Shoes_TrainerTINT",
    "Shoes_Twine",
), "Cotton"))

# Gloves. The fingerless pairs are the only ones vanilla left unclassified; every other pair
# in the game declares a fabric and is picked up by the first tier.
CHOSEN.update(dict.fromkeys((
    "Gloves_FingerlessLeatherGloves",
    "Gloves_FingerlessLeatherGloves_Black",
    "Gloves_FingerlessLeatherGloves_Brown",
), "Leather"))

CHOSEN["Gloves_FingerlessGloves"] = "Cotton"

# Boxing gear, which is leather over padding. The ice hockey gloves next to it are left out:
# those are a plastic shell and belong with the armour.
CHOSEN.update(dict.fromkeys((
    "Gloves_BoxingBlue",
    "Gloves_BoxingRed",
    "Hat_BoxingBlue",
    "Hat_BoxingRed",
), "Leather"))

# Underwear the game classified for everything except the bras. Every pair of pants, every
# sock and the hide underwear all declare a fabric and come through the first tier; the bras
# beside them declare nothing.
CHOSEN.update(dict.fromkeys((
    "Bra_Strapless_AnimalPrint",
    "Bra_Strapless_Black",
    "Bra_Strapless_FrillyBlack",
    "Bra_Strapless_FrillyPink",
    "Bra_Strapless_FrillyRed",
    "Bra_Strapless_RedSpots",
    "Bra_Strapless_White",
    "Bra_Straps_AnimalPrint",
    "Bra_Straps_Black",
    "Bra_Straps_FrillyBlack",
    "Bra_Straps_FrillyPink",
    "Bra_Straps_FrillyRed",
    "Bra_Straps_White",
    "Corset",
    "Corset_Black",
    "Corset_Medical",
    "Corset_Red",
    "Garter",
), "Cotton"))

CHOSEN.update(dict.fromkeys((
    "Bra_Strapless_Hide",
    "Bra_Straps_Hide",
), "Leather"))

# Hosiery and swimwear.
CHOSEN.update(dict.fromkeys((
    "Bikini_Pattern01",
    "Bikini_TINT",
    "BunnySuitBlack",
    "BunnySuitPink",
    "StockingsBlack",
    "StockingsBlackSemiTrans",
    "StockingsBlackTrans",
    "StockingsWhite",
    "SwimTrunks_Blue",
    "SwimTrunks_Green",
    "SwimTrunks_Red",
    "SwimTrunks_Yellow",
    "Swimsuit_TINT",
    "TightsBlack",
    "TightsBlackSemiTrans",
    "TightsBlackTrans",
    "TightsFishnets",
), "Cotton"))

# The burlap half of the crafted clothing line. Every one of these has a cotton and a denim
# sibling made by the same recipe from a different bolt, and vanilla tagged the siblings and
# not these: Shirt_Crafted_Burlap and LongJohns_Crafted_Burlap even declare FabricType =
# Cotton and rip cleanly, while Shirt_NoSleeves_Crafted_Burlap beside them declares nothing.
# So this is the game's own classification finished rather than a call of ours.
CHOSEN.update(dict.fromkeys((
    "Bandeau_Burlap",
    "Briefs_Burlap",
    "Dress_Knees_Crafted_Burlap",
    "Dress_Long_Crafted_Burlap",
    "LongJohns_Bottoms_Crafted_Burlap",
    "Shirt_NoSleeves_Crafted_Burlap",
    "Skirt_Knees_Crafted_Burlap",
    "Skirt_Long_Crafted_Burlap",
    "Trousers_Crafted_Burlap",
), "Cotton"))

# Sportswear and outerwear. The padded and shellsuit sets are nylon, the hunting and work
# vests are polyester, and the ghillie suit is sacking and netting.
CHOSEN.update(dict.fromkeys((
    "Ghillie_Top",
    "Ghillie_Trousers",
    "Jacket_Padded",
    "Jacket_PaddedDOWN",
    "Jacket_Padded_HuntingCamo",
    "Jacket_Padded_HuntingCamoDOWN",
    "Shorts_BoxingBlue",
    "Shorts_BoxingRed",
    "Shorts_FootballPants",
    "Shorts_FootballPants_Black",
    "Shorts_FootballPants_Gold",
    "Shorts_FootballPants_White",
    "SpiffoSuit",
    "Trousers_Padded",
    "Trousers_Padded_HuntingCamo",
    "Vest_Foreman",
    "Vest_HighViz",
    "Vest_Hunting_Camo",
    "Vest_Hunting_CamoGreen",
    "Vest_Hunting_Grey",
    "Vest_Hunting_Khaki",
    "Vest_Hunting_Orange",
    "Vest_Trucker",
), "Cotton"))

# Rain ponchos, which are a coated cloth. The tarpaulin and bin liner ponchos beside them
# are left out: those are crafted from a Tarp or two garbage bags and duct tape, and both
# materials have uses of their own that cutting them into rag strips would quietly convert.
CHOSEN.update(dict.fromkeys((
    "PonchoGreen",
    "PonchoGreenDOWN",
    "PonchoYellow",
    "PonchoYellowDOWN",
), "Cotton"))

# Neckwear. The _Worn names are the same ties hung loose rather than knotted.
CHOSEN.update(dict.fromkeys((
    "Tie_BowTieFull",
    "Tie_BowTieWorn",
    "Tie_Full",
    "Tie_Full_Spiffo",
    "Tie_Worn",
    "Tie_Worn_Spiffo",
), "Cotton"))

# Holsters, which are leather. Holster_DuctTape is not and is left out.
CHOSEN.update(dict.fromkeys((
    "HolsterAnkle",
    "HolsterDouble",
    "HolsterSimple",
    "HolsterSimple_Black",
    "HolsterSimple_Brown",
    "HolsterSimple_Green",
    "Holster_Hide",
), "Leather"))

# Hats. The largest group by far and the one vanilla ignored completely: not one hat in the
# game carries a rip tag, helmets and knitted beanies alike. These are the cloth ones.
CHOSEN.update(dict.fromkeys((
    "Hat_Army",
    "Hat_ArmyDesert",
    "Hat_ArmyDesertNew",
    "Hat_ArmyWWII",
    "Hat_BalaclavaFace",
    "Hat_BalaclavaFull",
    "Hat_Beany",
    "Hat_Beret",
    "Hat_BeretArmy",
    "Hat_BucketHat",
    "Hat_BucketHatFishing",
    "Hat_ChefHat",
    "Hat_EarMuffs",
    "Hat_FastFood",
    "Hat_FastFood_IceCream",
    "Hat_FastFood_Spiffo",
    "Hat_Fedora",
    "Hat_Fedora_Delmonte",
    "Hat_FishermanRainHat",
    "Hat_GolfHat",
    "Hat_GolfHatTINT",
    "Hat_HeadSack_Burlap",
    "Hat_HeadSack_Cotton",
    "Hat_PeakedCapArmy",
    "Hat_PeakedCapYacht",
    "Hat_Pilgrim",
    "Hat_Pirate",
    "Hat_Police",
    "Hat_Police_Grey",
    "Hat_Ranger",
    "Hat_SWAT",
    "Hat_SantaHat",
    "Hat_SantaHatGreen",
    "Hat_ShemaghFace",
    "Hat_ShemaghFace_Burlap",
    "Hat_ShemaghFace_Cotton",
    "Hat_ShemaghFace_Green",
    "Hat_ShemaghFull",
    "Hat_ShemaghFull_Burlap",
    "Hat_ShemaghFull_Cotton",
    "Hat_ShemaghFull_Green",
    "Hat_Sheriff",
    "Hat_Stovepipe",
    "Hat_Stovepipe_Black",
    "Hat_Stovepipe_UncleSam",
    "Hat_SurgicalCap",
    "Hat_SurgicalMask",
    "Hat_Sweatband",
    "Hat_VisorBlack",
    "Hat_VisorRed",
    "Hat_Visor_WhiteTINT",
    "Hat_WeddingVeil",
    "Hat_WinterHat",
    "Hat_Witch",
    "Hat_Wizard",
    "Hat_WoolyHat",
), "Cotton"))

# Hats of hide and fur. Hat_Cowboy_Plastic is not one of them and is left out.
CHOSEN.update(dict.fromkeys((
    "Hat_Cowboy",
    "Hat_Cowboy_Angus",
    "Hat_Cowboy_Black",
    "Hat_Cowboy_CowHide",
    "Hat_Cowboy_Holstein",
    "Hat_Cowboy_Simmental",
    "Hat_Cowboy_White",
    "Hat_HideHat",
    "Hat_Raccoon",
    "Hat_WinterHat_SheepSkin",
), "Leather"))

# Families too large and too regular to be worth a name at a time. Expanded against the
# installed game as this runs, and a pattern that matches nothing stops the pass, so a
# rename fails here rather than quietly shrinking the list.
CHOSEN_PATTERNS = (
    (r"^Hat_BaseballCap(_|[A-Z]|$)", "Cotton"),
    (r"^Hat_BonnieHat", "Cotton"),
    (r"^Jacket_Shellsuit_", "Cotton"),
    (r"^Trousers_Shellsuit_", "Cotton"),
)

#//////////////////////////////////////////////////////////////////////////////////////////
# Left uncuttable on purpose
#
# Named so the reason is on the record rather than looking like an oversight, and so the
# completeness check below has something to balance against. Every garment the installed
# game declares must be either already cuttable, given a fabric above, or named here.
#//////////////////////////////////////////////////////////////////////////////////////////
LEFT_OUT = {}

LEFT_OUT.update(dict.fromkeys((
    "AthleticCup",
    "Gloves_Dish",
    "Gloves_Surgical",
    "Hat_BuildersRespirator",
    "Hat_BuildersRespirator_nofilter",
    "Hat_Cowboy_Plastic",
    "Hat_ShowerCap",
    "Shoes_FlipFlop",
    "Shoes_TireSandals",
    "Shoes_Wellies",
), "rubber or plastic, which yields a tailor nothing"))

# The Tarp and garbage bag line. Both materials are crafted into these and both have uses of
# their own, so cutting the clothing up would be a quiet converter from tarpaulin and bin
# liners into cloth strips rather than a tailor recovering cloth.
LEFT_OUT.update(dict.fromkeys((
    "Apron_Garbage",
    "Apron_Tarp",
    "Bandeau_Garbage",
    "Bandeau_Tarp",
    "Briefs_Garbage",
    "Briefs_Tarp",
    "Dress_SmallGarbageStrapless",
    "Dress_SmallTarpStrapless",
    "Hat_HeadSack_Garbage",
    "Hat_HeadSack_Tarp",
    "Hat_TarpHat",
    "PonchoGarbageBag",
    "PonchoGarbageBagDOWN",
    "PonchoTarp",
    "PonchoTarpDOWN",
    "Skirt_Knees_Garbage",
    "Skirt_Knees_Tarp",
    "Skirt_Long_Garbage",
    "Skirt_Long_Tarp",
    "Skirt_Normal_Garbage",
    "Skirt_Normal_Tarp",
    "Skirt_Short_Garbage",
    "Skirt_Short_Tarp",
    "Vest_Garbage",
    "Vest_Tarp",
), "tarpaulin or bin liner, which the game crafts them from"))

LEFT_OUT.update(dict.fromkeys((
    "Briefs_Rag",
    "Gorget_LeatherWrap",
    "Hat_LeatherStripTied",
), "already made of what cutting it would hand back"))

LEFT_OUT.update(dict.fromkeys((
    "Holster_DuctTape",
    "RopeBelt",
), "duct tape and rope rather than cloth"))

LEFT_OUT.update(dict.fromkeys((
    "Hat_StrawHat",
    "Hat_SummerFlowerHat",
    "Hat_SummerHat",
), "woven straw"))

LEFT_OUT.update(dict.fromkeys((
    "Hat_NewspaperHat",
    "Hat_PartyHat_Stars",
    "Hat_PartyHat_TINT",
    "Hat_TinFoilHat",
    "Hat_DustMask",
), "paper, card and foil"))

LEFT_OUT.update(dict.fromkeys((
    "Hat_Antlers",
    "Hat_BunnyEarsBlack",
    "Hat_BunnyEarsWhite",
    "Hat_DeerHeadress",
    "Hat_FurryEars",
    "Hat_GoldStar",
    "Hat_Jay",
    "Hat_JokeArrow",
    "Hat_JokeKnife",
    "Hat_Spiffo",
), "novelty and mascot pieces built on a frame"))

# Armour. Every piece of it is crafted from a material and vanilla offers no way back from
# any of it, so cutting one up would be an uncraft the rest of the game does not have.
LEFT_OUT.update(dict.fromkeys((
    "Gloves_BoneGloves",
    "Gloves_IceHockeyGloves",
    "Gloves_IceHockeyGloves_Black",
    "Gloves_IceHockeyGloves_Blue",
    "Gloves_IceHockeyGloves_White",
    "Gloves_MetalArmour",
    "Gloves_MetalScrapArmour",
    "Gorget_Burlap",
    "Gorget_Leather",
    "Gorget_Metal",
    "IceHockeyNeckGuard",
), "armour, which the game gives no way back from"))

LEFT_OUT.update(dict.fromkeys((
    "Necklace_Choker",
    "Necklace_Choker_Amber",
    "Necklace_Choker_Bone",
    "Necklace_Choker_Diamond",
    "Necklace_Choker_Sapphire",
), "jewellery"))

# Firefighter turnout gear, which the game already harvests: all three carry
# base:pickaramidthread and are the only source of aramid thread in the game. Cutting them
# into rag strips would compete with that.
LEFT_OUT.update(dict.fromkeys((
    "Hat_Fireman",
    "Jacket_Fireman",
    "Trousers_Fireman",
), "harvested for aramid thread instead"))

LEFT_OUT_PATTERNS = {
    r"^Hat_BaseballHelmet": "a hard shell rather than a garment",
    r"^Hat_BicycleHelmet$": "a hard shell rather than a garment",
    r"^Hat_CrashHelmet": "a hard shell rather than a garment",
    r"^Hat_EarMuff_Protectors$": "a hard shell rather than a garment",
    r"^Hat_FootballHelmet": "a hard shell rather than a garment",
    r"^Hat_HardHat": "a hard shell rather than a garment",
    r"^Hat_HeadMirror": "a hard shell rather than a garment",
    r"^Hat_HockeyHelmet": "a hard shell rather than a garment",
    r"^Hat_JockeyHelmet": "a hard shell rather than a garment",
    r"^Hat_MetalHelmet$": "a hard shell rather than a garment",
    r"^Hat_MetalScrapHelmet$": "a hard shell rather than a garment",
    r"^Hat_NBCmask": "a hard shell rather than a garment",
    r"^Hat_RidingHelmet$": "a hard shell rather than a garment",
    r"^Hat_RiotHelmet$": "a hard shell rather than a garment",
    r"^Hat_SPHhelmet$": "a hard shell rather than a garment",
}

# Wallets. Not clothing at all, ItemType = base:container, so they cannot go anywhere near
# RipClothing or RipDenimClothing: RecipeCodeOnCreate.ripClothing casts its input to Clothing
# and asks it for a FabricType, which a container has not got. They get a recipe of their own
# below instead, and an empty one at that, so nobody shreds a wallet with the car keys in it.
WALLETS = ("Wallet", "Wallet_Male", "Wallet_Female", "Wallet_Hide")

# What one wallet is worth. Small, and the leather in it is thin.
WALLET_STRIPS = 1

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


def expand(items, patterns):
    """A pattern table against the installed game, refusing any pattern that matches none."""
    found = {}

    for pattern, value in sorted(patterns.items() if isinstance(patterns, dict) else patterns):
        matched = [name for name in items if re.search(pattern, name)]
        if not matched:
            raise SystemExit("nothing in this build matches: " + pattern)

        for name in matched:
            found[name] = value

    return found


def check_complete(items, chosen, left_out):
    """Every garment the game declares is cuttable, chosen above, or left out with a reason."""
    missing = []

    for name, body in sorted(items.items()):
        if not re.search(r"ItemType\s*=\s*base:clothing", body):
            continue

        location = re.search(r"BodyLocation\s*=\s*base:(\w+)", body)
        if not location or location.group(1) not in GARMENT_SLOTS:
            continue
        if name in EXCLUDE or name in chosen or name in left_out:
            continue
        if re.search(r"base:ripclothing\w+", body):
            continue
        if re.search(r"FabricType\s*=\s*(\w+)", body):
            continue

        missing.append("%s (%s)" % (name, location.group(1)))

    if missing:
        raise SystemExit(
            "neither made cuttable nor left out on purpose:\n  " + "\n  ".join(missing) +
            "\n\nadd each to CHOSEN or to LEFT_OUT in " + os.path.basename(__file__))


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

    picked = dict(CHOSEN)
    picked.update(expand(items, CHOSEN_PATTERNS))

    left_out = dict(LEFT_OUT)
    left_out.update(expand(items, LEFT_OUT_PATTERNS))

    overlap = sorted(set(picked) & set(left_out))
    if overlap:
        raise SystemExit("both chosen and left out: " + ", ".join(overlap))

    for name in sorted(picked):
        if name not in items:
            raise SystemExit("no such item in this build: " + name)

    check_complete(items, picked, left_out)

    chosen = [(name, picked[name]) for name in sorted(picked)]

    return declared, chosen, left_out


def block(name, fabric, needs_fabric):
    lines = ["\titem " + name, "\t{"]
    if needs_fabric:
        lines.append("\t\tFabricType = " + fabric + ",")
    lines.append("\t\tTags = " + TAG[fabric] + ",")
    lines.append("\t}")

    return "\n".join(lines)


def build(declared, chosen, left_out):
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
    out.append(" * them up. Shoes, bras, tights, ties, vests and every hat in the game have it worse")
    out.append(" * and carry no fabric at all.")
    out.append(" *")
    out.append(" * Reopening an item merges rather than replaces, and a Tags value is added to the set")
    out.append(" * rather than overwriting it, so everything that makes these garments work is untouched.")
    out.append(" *")
    out.append(" * The tags cannot be switched off from here, because a lua tag patch lands after the")
    out.append(" * recipes have already cached their inputs. The sandbox switch is the recipes' OnTest")
    out.append(" * instead, reading the same list this pass writes to qolc_cut_clothing_items.lua.")
    out.append(" *")
    out.append(" * Left uncuttable on purpose, and checked against the installed game as this is")
    out.append(" * written so nothing new can slip between the two lists:")

    reasons = {}
    for name, reason in left_out.items():
        reasons.setdefault(reason, []).append(name)

    for reason in sorted(reasons):
        out.append(" *   %d %s" % (len(reasons[reason]), reason))

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
    out.append("--// A list rather than a tag test. Both halves carry vanilla's rip tags and reading")
    out.append("--// one back would be tidier, but InventoryItem.hasTag takes ItemTag objects rather")
    out.append("--// than strings and there is no route to one from lua. Written by the same pass that")
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
    declared, chosen, left_out = classify(items)

    for name in WALLETS:
        if name not in items:
            raise SystemExit("no such item in this build: " + name)

    text = build(declared, chosen, left_out)

    print("read from the fabric the game already declares: %d" % len(declared))
    print("given a fabric here:                            %d" % len(chosen))
    print("left uncuttable on purpose:                     %d" % len(left_out))
    print("total garments made cuttable:                   %d" % (len(declared) + len(chosen) + len(TYPO)))

    if args.check:
        return

    io.open(DEST, "w", encoding="utf-8", newline="\n").write(text)
    print("wrote " + DEST)

    io.open(DEST_LUA, "w", encoding="utf-8", newline="\n").write(lua_table(declared, chosen))
    print("wrote " + DEST_LUA)


if __name__ == "__main__":
    main()
