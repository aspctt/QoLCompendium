--// Corpse Disposal
--// Def's Long Term Survival, Workshop 1962914415 - Original idea, by DefbeatCZ
--// aspctt - 28.08.2026
--// The switch for the three recipes in qolc_corpse_disposal.txt: butchering a body for
--// flesh, preparing that flesh at Cooking 7, and packing it in salt to cure.
--//
--// Off refuses all three, so a body is back to being something you burn or bury and
--// nothing more. Flesh already butchered stays in the world: it still composts, and it
--// still cures if it was already packed in salt, because that half is the game's own
--// rotting clock rather than anything this file can reach. That is deliberate. A switch
--// that reached into a save and voided food already in a fridge would be worse than one
--// that simply stops offering the recipes.
--//
--// OnTest runs once per candidate item and answers for that item alone. Verified in the
--// jar rather than assumed: CraftRecipe.OnTestItem resolves the name through
--// LuaManager.getFunctionObject and calls protectedCallBoolean(item, character). None of
--// these is a vanilla recipe, so the answer does not depend on the item.
--//
--// Shared, because a recipe is tested by whichever side is in charge: the client in
--// singleplayer, the server in multiplayer.
--//
--// Balance lives in sandbox options, never mod options. Whether the dead are a food
--// source is not a thing one player on a server should settle for themselves.

--// Tuning
-- Matches the default declared in 42/media/sandbox-options.txt, used when a save predates
-- this feature and has nothing stored for it.
--
-- Off by default, which is the only feature here that is. Everything else in this mod
-- fixes something the base game got wrong; this one adds cannibalism to a game that has
-- none, and a compendium that turns that on without being asked has overstepped.
local DEFAULT_ENABLED = false

--// Functions
local function Enabled()
	local Vars = SandboxVars and SandboxVars.QoLC
	if not Vars then return DEFAULT_ENABLED end

	local Value = Vars.CorpseDisposalEnabled
	if Value == nil then return DEFAULT_ENABLED end

	return Value and true or false
end

-- Read by the spec.
function QolcCorpseDisposalEnabled()
	return Enabled()
end

--// Recipe Hooks
Recipe = Recipe or {}
Recipe.OnTest = Recipe.OnTest or {}

function Recipe.OnTest.QolcCorpseDisposal(_Item, _Character)
	return Enabled()
end
