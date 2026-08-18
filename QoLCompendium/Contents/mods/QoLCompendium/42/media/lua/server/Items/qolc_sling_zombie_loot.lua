--// Rifle Sling Zombie Loot
--// aspctt - 09.08.2026
--// Build 42 has no loot table keyed by zombie outfit, and OnZombieDead is the only
--// zombie event vanilla exposes to lua, so soldiers are given a small chance of
--// carrying a sling at the moment they drop rather than at spawn.
--//
--// Server side so the roll is authoritative, one result for everyone in multiplayer.

--// Switch
-- Server controlled, because this is balance rather than presentation. A per client
-- setting would let one player on a server play to different numbers than the rest.
local function QolcEnabled()
	local Vars = SandboxVars and SandboxVars.QoLC
	local Value = Vars and Vars.SlingEnabled

	if Value ~= nil then return Value and true or false end
	return true
end

--// Tuning
-- Rare on purpose. A military base wardrobe is meant to be the reliable source.
local CHANCE_PERCENT = 2
local ITEM = "Base.SlingAFront"

--// Functions
local function IsMilitary(OutfitName)
	if not OutfitName then return false end
	if not QolcSlingMilitaryOutfits then return false end

	for _, Name in ipairs(QolcSlingMilitaryOutfits) do
		if OutfitName == Name then return true end
	end
	return false
end

local function OnZombieDead(Zombie)
	if not Zombie then return end
	if not Zombie.getOutfitName then return end
	if not QolcEnabled() then return end
	if not IsMilitary(Zombie:getOutfitName()) then return end
	if ZombRand(100) >= CHANCE_PERCENT then return end

	local Inventory = Zombie:getInventory()
	if not Inventory then return end

	-- Nothing if they already picked one up from somewhere else
	if Inventory:contains("SlingAFront") then return end

	Inventory:AddItem(ITEM)
end

--// Connections
Events.OnZombieDead.Add(OnZombieDead)
