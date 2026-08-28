--// DIY Workbooks
--// Def's Long Term Survival, Workshop 1962914415 - Original idea, by DefbeatCZ
--// aspctt - 28.08.2026
--// The switch for the four practice recipes in qolc_workbooks.txt.
--//
--// Off refuses every input, which makes the recipes uncraftable, and the four books stop
--// spawning through qolc_workbook_distributions. Books already found stay in the world
--// and turn back into working ones the moment the option goes on again, which is the same
--// bargain every other switch here offers.
--//
--// OnTest runs once per candidate item and answers for that item alone. Verified in the
--// jar rather than assumed: CraftRecipe.OnTestItem resolves the name through
--// LuaManager.getFunctionObject and calls protectedCallBoolean(item, character). Since
--// none of these is a vanilla recipe, the answer does not depend on the item.
--//
--// Shared, because a recipe is tested by whichever side is in charge: the client in
--// singleplayer, the server in multiplayer.
--//
--// Balance lives in sandbox options, never mod options. Turning experience into something
--// materials can be spent on is the kind of thing a server has to settle for everyone.

--// Tuning
-- Matches the default declared in 42/media/sandbox-options.txt, used when a save predates
-- this feature and has nothing stored for it.
local DEFAULT_ENABLED = true

--// Functions
local function Enabled()
	local Vars = SandboxVars and SandboxVars.QoLC
	if not Vars then return DEFAULT_ENABLED end

	local Value = Vars.WorkbooksEnabled
	if Value == nil then return DEFAULT_ENABLED end

	return Value and true or false
end

-- Read by qolc_workbook_distributions and by the spec.
function QolcWorkbooksEnabled()
	return Enabled()
end

--// Recipe Hooks
Recipe = Recipe or {}
Recipe.OnTest = Recipe.OnTest or {}

function Recipe.OnTest.QolcWorkbooks(_Item, _Character)
	return Enabled()
end
