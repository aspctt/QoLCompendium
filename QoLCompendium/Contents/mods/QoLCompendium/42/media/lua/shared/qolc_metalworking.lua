--// Metalworking Gaps
--// aspctt - 28.08.2026
--// The switch for the four recipes in qolc_metalworking.txt: wire, iron pipe, welding
--// rods and electrical wire.
--//
--// Each of those is something build 42 has an item for and no way to make. Wire is the
--// clearest: it comes only from barbed wire, barbed wire comes only from wire, and the
--// single way into that loop is pulling wire back out of a broken fishing net.
--//
--// Off leaves all four exactly as the base game has them, which is to say found rather
--// than made. Nothing already crafted is touched.
--//
--// OnTest runs once per candidate item and answers for that item alone. Verified in the
--// jar rather than assumed: CraftRecipe.OnTestItem resolves the name through
--// LuaManager.getFunctionObject and calls protectedCallBoolean(item, character). None of
--// these is a vanilla recipe, so the answer does not depend on the item.
--//
--// Shared, because a recipe is tested by whichever side is in charge: the client in
--// singleplayer, the server in multiplayer.
--//
--// Balance lives in sandbox options, never mod options. Whether wire can be manufactured
--// changes what a base can build without looting, which a server settles for everyone.

--// Tuning
-- Matches the default declared in 42/media/sandbox-options.txt, used when a save predates
-- this feature and has nothing stored for it.
local DEFAULT_ENABLED = true

--// Functions
local function Enabled()
	local Vars = SandboxVars and SandboxVars.QoLC
	if not Vars then return DEFAULT_ENABLED end

	local Value = Vars.MetalworkingEnabled
	if Value == nil then return DEFAULT_ENABLED end

	return Value and true or false
end

-- Read by the spec.
function QolcMetalworkingEnabled()
	return Enabled()
end

--// Recipe Hooks
Recipe = Recipe or {}
Recipe.OnTest = Recipe.OnTest or {}

function Recipe.OnTest.QolcMetalworking(_Item, _Character)
	return Enabled()
end
