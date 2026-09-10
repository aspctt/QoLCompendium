--// Welding Torch Capacity
--// Workshop 3044705007 - Original
--// aspctt - 09.08.2026
--// Build 42 already refills the torch correctly in Java, proportionally, so the original
--// mod's refill would be a downgrade. This keeps vanilla's proportional behaviour and only
--// changes the economy: a larger torch, and more welding out of a propane tank.
--//
--// Shared rather than server, so a multiplayer client and its server agree on the numbers.
--// Switched from the sandbox page rather than mod options: this is balance, not
--// cosmetics, and a per client setting would desync from the server. Both numbers are set
--// there too, since a player asked for them.
--//
--// Off has to mean vanilla, and for a while it did not. The recipe hook below is named in
--// a script file, so it replaces vanilla's for good whatever the switch says, and it used
--// to size every refill at a thirtieth of a tank regardless. Switched off, a vanilla torch
--// of ten uses was being refilled at our rate, around three hundred welds a tank against
--// vanilla's seventy one. It now does vanilla's own sum while the feature is off.

--// Tuning
-- Defaults for the two sandbox numbers, and what a save that predates them gets. 16 uses
-- per torch and 30 refills per tank, so 480 welding uses out of a full tank. Vanilla is 10
-- uses and roughly 7.1 refills, so 71 uses per tank.
local DEFAULT_TORCH_USES = 16
local DEFAULT_REFILLS_PER_TANK = 30

-- What vanilla charges per torch use, in tank units. RecipeCodeOnCreate.refillBlowTorch
-- sizes a refill as the torch's getMaxUses times ZomboidGlobals.refillBlowtorchPropaneAmount,
-- which the jar initialises to 70. The class is not exposed to lua, so it is mirrored here,
-- and only ever used to hand vanilla's refill back while the feature is off.
local VANILLA_PROPANE_PER_USE = 70

--// Switch
-- Server controlled, because this is balance rather than presentation. A per client
-- setting would let one player on a server play to different numbers than the rest.
local function QolcEnabled()
	local Vars = SandboxVars and SandboxVars.QoLC
	local Value = Vars and Vars.BlowtorchEnabled

	if Value ~= nil then return Value and true or false end
	return true
end

-- A whole number from the sandbox page, or the default when the save has none. The page
-- itself never offers less than one.
local function SandboxNumber(Name, Default)
	local Vars = SandboxVars and SandboxVars.QoLC
	local Value = Vars and tonumber(Vars[Name])

	if not Value or Value < 1 then return Default end
	return Value
end

--// Functions
-- How much of the tank one full torch holds. Vanilla stores drainables as a 0 to 1
-- fraction, so this is in tank units.
--
-- On, it is derived from the tank rather than hard coded, so mods that change propane
-- tank stats, Real Metalworking for one, still get the same number of refills. Off, it is
-- vanilla's own sum, taken from the torch.
local function GetPropanePerTorch(Tank, Torch)
	if not QolcEnabled() then
		local Uses = Torch:getMaxUses()
		if not Uses or Uses <= 0 then return nil end
		return Uses * VANILLA_PROPANE_PER_USE
	end

	local MaxUses = Tank:getMaxUses()
	if not MaxUses or MaxUses <= 0 then return nil end
	return MaxUses / SandboxNumber("BlowtorchRefills", DEFAULT_REFILLS_PER_TANK)
end

--// Recipe Hooks
Recipe = Recipe or {}
Recipe.OnCreate = Recipe.OnCreate or {}

-- Mirrors zombie.scripting.logic.RecipeCodeOnCreate.refillBlowTorch, but sized from the
-- sandbox's refills per tank instead of ZomboidGlobals.refillBlowtorchPropaneAmount,
-- which Lua cannot reach.
function Recipe.OnCreate.QolcRefillBlowTorch(CraftRecipeData, Character)
	local Created = CraftRecipeData:getAllCreatedItems():get(0)
	local Consumed = CraftRecipeData:getAllConsumedItems():get(0)
	local Tank = CraftRecipeData:getAllKeepInputItems():get(0)
	if not Created then return end
	if not Consumed then return end
	if not Tank then return end

	-- Carry the old torch's state onto the one the recipe just created
	Created:setCurrentUsesFloat(Consumed:getCurrentUsesFloat())
	Created:setCondition(Consumed:getCondition())

	local Capacity = GetPropanePerTorch(Tank, Created)
	if not Capacity then return end

	-- Kept in floats throughout. Vanilla writes the tank back through setCurrentUses,
	-- which rounds to whole units and quietly loses a fraction on every refill. Vanilla
	-- gets away with it at seven refills a tank, at thirty it costs a whole one.
	local MaxUses = Tank:getMaxUses()
	local Available = Tank:getCurrentUsesFloat() * MaxUses
	local Current = Created:getCurrentUsesFloat() * Capacity
	local Take = Capacity - Current

	-- Only ever draw what the torch is actually short of, and never more than is left
	if Take > Available then Take = Available end

	if Take > 0 then
		Created:setCurrentUsesFloat((Current + Take) / Capacity)
		Tank:setCurrentUsesFloat((Available - Take) / MaxUses)
		Tank:syncItemFields()
	end

	Created:syncItemFields()
end

--// Script Patches
-- Applied through ScriptManager rather than a script file, because the item is already
-- defined by the base game and this is the form the build 42 mod shipped with.
local function OnInitGlobalModData()
	if not QolcEnabled() then return end

	if not ScriptManager or not ScriptManager.instance then return end

	local Item = ScriptManager.instance:getItem("Base.BlowTorch")
	if not Item then return end

	local Target = 1 / SandboxNumber("BlowtorchUses", DEFAULT_TORCH_USES)
	if Item:getUseDelta() ~= Target then
		Item:DoParam(string.format("UseDelta = %.6f", Target))
	end
end

--// Connections
Events.OnInitGlobalModData.Add(OnInitGlobalModData)
