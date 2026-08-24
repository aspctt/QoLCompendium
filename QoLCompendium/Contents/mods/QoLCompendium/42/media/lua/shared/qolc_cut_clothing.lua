--// Cut Up Any Clothing
--// aspctt - 23.08.2026
--// Lets you cut up the garments build 42 forgot: underwear, socks, bandanas, scarves,
--// gloves, shoes, bras, corsets, tights, stockings, swimwear, shellsuits, hunting vests,
--// ties, holsters, rain ponchos and every cloth hat in the game.
--//
--// The game decides this from a tag, base:ripclothingcotton for what tears by hand and
--// base:ripclothingdenim or base:ripclothingleather for what needs scissors. That tag is a
--// separate thing from FabricType, which is what the garment is actually made of, and the
--// two disagree constantly. Sixty six garments declare a fabric and were never tagged, so
--// the game knows perfectly well they are cotton and still refuses. The rest carry no
--// fabric at all, which is why a leather boot reads as nothing in particular.
--//
--// What is left uncuttable is on the record too, with the reason beside it, and the
--// generator balances the two lists against the installed game as it writes: a garment
--// named by neither stops the pass. The first version had no such check and shipped with
--// the plain shoes, tights, bras, berets and ponchos still refused, which is exactly the
--// hole a list nobody balances against anything develops.
--//
--// The tags themselves are in qolc_cut_clothing.txt and are always applied. They have to
--// be: every recipe input resolves its tags into an itemScriptCache once, in InputScript's
--// OnScriptsLoaded, so a lua tag patch lands after the recipes have stopped looking. This
--// is the same wall qolc_sterile_rags.txt ran into.
--//
--// So the switch is here instead, as the recipes' OnTest. It runs once per candidate item
--// and answers for that item alone, which is exactly the shape needed: refuse the garments
--// this mod added, leave everything vanilla already allowed alone. Verified in the jar
--// rather than assumed, CraftRecipe.OnTestItem resolves the name through
--// LuaManager.getFunctionObject and calls it as protectedCallBoolean(item, character).
--//
--// Nothing here changes how much a garment yields. RecipeCodeOnCreate.ripClothing counts
--// the body parts a garment covers, less its holes and patches, floored at one, so a pair
--// of boots covering one location already gives a fraction of what a jacket does. Vanilla's
--// own rule scales by coverage, and a second rule on top of it would only disagree.
--//
--// Shared, because the recipe is tested by whichever side is in charge: the client in
--// singleplayer, the server in multiplayer.
--//
--// Balance lives in sandbox options, never mod options, so the server decides for everyone.
--// See 42/media/sandbox-options.txt.

require "qolc_cut_clothing_items"

--// Tuning
-- Matches the default declared in 42/media/sandbox-options.txt, used when a save predates
-- this feature and has nothing stored for it.
local DEFAULT_ENABLED = true

--// Functions
local function Enabled()
	local Vars = SandboxVars and SandboxVars.QoLC
	if not Vars then return DEFAULT_ENABLED end

	local Value = Vars.CutClothingEnabled
	if Value == nil then return DEFAULT_ENABLED end

	return Value and true or false
end

-- Read by the spec, and by anything that wants to know whether a garment is ours rather
-- than one the game always allowed.
function QolcCutClothingIsAdded(Item)
	if not Item or not Item.getFullType then return false end

	return QolcCutClothingAdded[Item:getFullType()] ~= nil
end

--// Recipe Hooks
Recipe = Recipe or {}
Recipe.OnTest = Recipe.OnTest or {}

-- True lets the item through, which is the answer for everything except a garment this mod
-- made cuttable while the feature is switched off. Deliberately permissive in every other
-- case: this is bolted onto two vanilla recipes and a wrong no here would stop a player
-- ripping a bedsheet.
function Recipe.OnTest.QolcCutClothing(Item, _Character)
	if Enabled() then return true end

	return not QolcCutClothingIsAdded(Item)
end
