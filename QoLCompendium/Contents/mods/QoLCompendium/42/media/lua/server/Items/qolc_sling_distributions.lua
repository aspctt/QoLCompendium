--// Rifle Sling Distributions
--// Noir - Original
--// aspctt - 09.08.2026
--// Where rifle slings spawn. The original scattered them through camping stores,
--// redneck wardrobes, survivor caches and hunter trucks. Narrowed here to the places
--// a sling would plausibly come from: police, gun stores, and the military.
--//
--// Server side, so the tables are built once and authoritatively. Switched from the
--// sandbox page rather than mod options, because loot balance has to match across a
--// multiplayer session.
--//
--// The seeding itself is unconditional, and the switch is handed to qolc_loot_switch.
--// It has to be: the sandbox options are not read from the save until after all three
--// merge events have fired, so a test here reads our own declared default rather than
--// the player's answer. That file has the whole story.

require "qolc_loot_switch"

--// Tuning
-- Weights use the same scale as vanilla ProceduralDistributions.
local ITEM = "Base.SlingAFront"

-- Findable in the two places a sling belongs. Vanilla clothing in these same tables
-- sits between 2 and 10, so 4 to 6 reads as uncommon but not a trophy.
local ProceduralPlaces = {
	-- Military base clothing loot
	ArmyStorageOutfit = 6,
	ArmySurplusOutfit = 6,
	LockerArmyBedroom = 5,

	-- Gun stores. GunStoreShelf, which the original used, is marked DEPRECATED in
	-- build 42 with an empty item list, so it would have spawned nothing at all.
	GunStoreAccessories = 6,
	FirearmWeapons = 4,

	-- Rare everywhere else. Vanilla uses 0.1 to 0.5 here for genuinely scarce things.
	PawnShopGunsSpecial = 1,
	PoliceStorageOutfit = 0.8,
	PoliceLockers = 0.5,
}

-- Vehicles are listed by their flat table name rather than as Parent.Container.
-- Police, PoliceState and PoliceSheriff all alias the same PoliceTruckBed and
-- PoliceGloveBox tables, so going through the parents would add the sling two or
-- three times to the same list. Note a squad car has no truck bed at all, the
-- glovebox and front seat are what actually cover police cars.
local VehiclePlaces = {
	PoliceSheriffSeatFront = 0.25,
	PoliceStateSeatFront = 0.25,
	PoliceSWATGloveBox = 0.3,
	PoliceSWATTruckBed = 0.6,
	PoliceSeatFront = 0.25,
	PoliceGloveBox = 0.25,
	PoliceTruckBed = 0.4,
}

-- Zombies wearing these may be carrying one. Build 42 has no loot table keyed by
-- outfit, so this is applied on death instead, see qolc_sling_zombie_loot.lua.
QolcSlingMilitaryOutfits = {
	"ArmyServiceUniform",
	"ArmyCamoDesert",
	"ArmyInstructor",
	"ArmyCamoGreen",
	"PrivateMilitia",
	"Police_SWAT",
}

--// Functions
local function AddTo(Container, Weight)
	if not Container then return false end
	if not Container.items then return false end
	table.insert(Container.items, ITEM)
	table.insert(Container.items, Weight)
	return true
end

--// Registration
--// Switch
QolcLootSwitch.Withhold("SlingEnabled", { ITEM })

local function OnPreDistributionMerge()
	local Missing = {}

	local Procedural = ProceduralDistributions and ProceduralDistributions.list
	for Key, Weight in pairs(ProceduralPlaces) do
		if not Procedural or not AddTo(Procedural[Key], Weight) then
			table.insert(Missing, "ProceduralDistributions.list." .. Key)
		end
	end

	for Key, Weight in pairs(VehiclePlaces) do
		if not VehicleDistributions or not AddTo(VehicleDistributions[Key], Weight) then
			table.insert(Missing, "VehicleDistributions." .. Key)
		end
	end

	-- A vanilla table renamed by an update should say so, rather than silently
	-- spawning nothing at all
	for _, Name in ipairs(Missing) do
		print("QoL Compendium: rifle sling spawn target not found, " .. Name)
	end
end

--// Connections
Events.OnPreDistributionMerge.Add(OnPreDistributionMerge)
