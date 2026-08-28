--// Cloth Recycling
--// Def's Long Term Survival, Workshop 1962914415 - Original idea, by DefbeatCZ
--// aspctt - 28.08.2026
--// The switch for the three recipes in qolc_cloth_recycling.txt: tearing a bath towel or
--// a dish cloth into rags, and sewing rags back into a bedsheet.
--//
--// The recipes are ours rather than patches of vanilla's, so switching them off could
--// have been done by simply not shipping them. It is done here instead because a sandbox
--// option has to be answerable at any moment, not only at load: the option lives on the
--// server, a player can be handed a different answer than the one the scripts were parsed
--// under, and a recipe that exists but refuses every input is the shape the rest of this
--// mod already uses.
--//
--// OnTest runs once per candidate item and answers for that item alone. Verified in the
--// jar rather than assumed: CraftRecipe.OnTestItem resolves the name through
--// LuaManager.getFunctionObject and calls protectedCallBoolean(item, character). Since
--// nothing here is a vanilla recipe, the answer does not depend on the item at all.
--//
--// Shared, because a recipe is tested by whichever side is in charge: the client in
--// singleplayer, the server in multiplayer.
--//
--// Balance lives in sandbox options, never mod options, so the server decides for
--// everyone. See 42/media/sandbox-options.txt.

--// Tuning
-- Matches the default declared in 42/media/sandbox-options.txt, used when a save predates
-- this feature and has nothing stored for it.
local DEFAULT_ENABLED = true

--// Functions
local function Enabled()
	local Vars = SandboxVars and SandboxVars.QoLC
	if not Vars then return DEFAULT_ENABLED end

	local Value = Vars.ClothRecyclingEnabled
	if Value == nil then return DEFAULT_ENABLED end

	return Value and true or false
end

--// Recipe Hooks
Recipe = Recipe or {}
Recipe.OnTest = Recipe.OnTest or {}

-- Every input of all three recipes runs through this, the needle and the thread included.
-- Refusing them all is what makes the recipes uncraftable rather than merely unhelpful.
function Recipe.OnTest.QolcClothRecycling(_Item, _Character)
	return Enabled()
end
