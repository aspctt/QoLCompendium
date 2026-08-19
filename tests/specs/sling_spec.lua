--// Rifle Sling Spec
--// aspctt - 09.08.2026

local ITEM = "Base.SlingAFront"

--// Helpers
local function Register()
	Harness.Fire("OnPreDistributionMerge")
end

local function Procedural(Name)
	return ProceduralDistributions.list[Name]
end

local function WeightIn(Container)
	local Weight = Harness.LootWeight(Container, ITEM)
	return Weight
end

--// Spawn Locations
Test("spawns in military base clothing loot at a findable weight", function()
	Register()
	AssertEquals(WeightIn(Procedural("ArmyStorageOutfit")), 6, "ArmyStorageOutfit")
	AssertEquals(WeightIn(Procedural("ArmySurplusOutfit")), 6, "ArmySurplusOutfit")
	AssertEquals(WeightIn(Procedural("LockerArmyBedroom")), 5, "LockerArmyBedroom")
end)

Test("spawns in gun stores at a findable weight", function()
	Register()
	AssertEquals(WeightIn(Procedural("GunStoreAccessories")), 6, "GunStoreAccessories")
	AssertEquals(WeightIn(Procedural("FirearmWeapons")), 4, "FirearmWeapons")
end)

Test("is rare everywhere else", function()
	Register()
	for _, Name in ipairs({ "PawnShopGunsSpecial", "PoliceStorageOutfit", "PoliceLockers" }) do
		local Weight = WeightIn(Procedural(Name))
		AssertNotNil(Weight, Name .. " should still spawn some slings")
		AssertTrue(Weight <= 1, Name .. " should be rare, got " .. tostring(Weight))
	end

	for _, Name in ipairs(Harness.VehicleNames) do
		local Weight = WeightIn(VehicleDistributions[Name])
		AssertNotNil(Weight, Name .. " should still spawn some slings")
		AssertTrue(Weight <= 1, Name .. " should be rare, got " .. tostring(Weight))
	end
end)

Test("gun stores and military outspawn police by a clear margin", function()
	Register()
	local Best = math.min(WeightIn(Procedural("GunStoreAccessories")),
		WeightIn(Procedural("ArmyStorageOutfit")))
	local Police = math.max(WeightIn(Procedural("PoliceLockers")),
		WeightIn(Procedural("PoliceStorageOutfit")))
	AssertTrue(Best >= Police * 4, "the intended sources should dominate")
end)

Test("police cars are covered, not just police trucks", function()
	Register()
	-- A squad car has no truck bed, so the glovebox and front seat are what matter
	AssertNotNil(WeightIn(VehicleDistributions.PoliceGloveBox), "PoliceGloveBox")
	AssertNotNil(WeightIn(VehicleDistributions.PoliceSeatFront), "PoliceSeatFront")
	AssertNotNil(WeightIn(VehicleDistributions.PoliceStateSeatFront), "PoliceStateSeatFront")
	AssertNotNil(WeightIn(VehicleDistributions.PoliceSheriffSeatFront), "PoliceSheriffSeatFront")
end)

Test("aliased vehicle tables are not added to twice", function()
	Register()
	-- Police, PoliceState and PoliceSheriff all share PoliceTruckBed and PoliceGloveBox
	local _, TruckBedCount = Harness.LootWeight(VehicleDistributions.PoliceTruckBed, ITEM)
	local _, GloveBoxCount = Harness.LootWeight(VehicleDistributions.PoliceGloveBox, ITEM)
	AssertEquals(TruckBedCount, 1, "PoliceTruckBed entry count")
	AssertEquals(GloveBoxCount, 1, "PoliceGloveBox entry count")

	-- and the alias really is the same table
	AssertEquals(VehicleDistributions.Police.TruckBed, VehicleDistributions.PoliceTruckBed,
		"the stub should mirror vanilla's aliasing")
end)

-- These three were dropped as spawn locations. The test used to say the tables themselves
-- were gone from build 42, which was never true: it passed only because the harness built
-- its loot tables from a hand written list that happened to leave them out. All three are
-- still in vanilla. What matters is that no sling is put in them.
Test("the retired camping and redneck spawns hold no sling", function()
	Register()
	for _, Name in ipairs({ "CampingStoreGear", "CampingStoreBackpacks", "WardrobeRedneck" }) do
		AssertNotNil(ProceduralDistributions.list[Name], Name .. " is still a real table")
		AssertNil(WeightIn(Procedural(Name)), Name .. " should no longer be targeted")
	end
end)

--// Military Zombies
Test("a military zombie can drop a sling", function()
	Harness.NextRandom = 0
	local Zombie = Harness.NewZombie("ArmyCamoGreen")
	Harness.Fire("OnZombieDead", Zombie)
	AssertTrue(Zombie:getInventory():contains("SlingAFront"), "soldier should have dropped one")
end)

Test("a civilian zombie never drops a sling", function()
	Harness.NextRandom = 0
	local Zombie = Harness.NewZombie("Waitress")
	Harness.Fire("OnZombieDead", Zombie)
	AssertFalse(Zombie:getInventory():contains("SlingAFront"), "civilians should never carry one")
end)

Test("the zombie drop is rare", function()
	-- The roll must fail well below a one in twenty chance
	Harness.NextRandom = 5
	local Zombie = Harness.NewZombie("ArmyCamoGreen")
	Harness.Fire("OnZombieDead", Zombie)
	AssertFalse(Zombie:getInventory():contains("SlingAFront"), "a roll of 5 should not pass")
end)

Test("a zombie with no outfit is handled", function()
	Harness.NextRandom = 0
	local Zombie = Harness.NewZombie(nil)
	Harness.Fire("OnZombieDead", Zombie)
	AssertFalse(Zombie:getInventory():contains("SlingAFront"), "no outfit means no drop")
end)

Test("every military outfit named is one vanilla actually uses", function()
	AssertNotNil(QolcSlingMilitaryOutfits, "outfit list")
	local Vanilla = {
		ArmyCamoDesert = true, ArmyCamoGreen = true, ArmyInstructor = true,
		ArmyServiceUniform = true, PrivateMilitia = true, Police_SWAT = true,
	}
	for _, Name in ipairs(QolcSlingMilitaryOutfits) do
		AssertTrue(Vanilla[Name], Name .. " is not a vanilla outfit name")
	end
end)

--// Locations
Test("the sling body location is registered under our own namespace", function()
	-- Three things have to line up here, and all three crash the game at load or
	-- leave the item unwearable if they do not. See qolc_sling_locations.lua.
	local Location = ItemBodyLocation.Registered["qolc:sling"]
	AssertNotNil(Location, "Sling should be registered as qolc:sling")

	local Body = BodyLocations.getGroup("Human")
	local InGroup = Body.Locations["qolc:sling"]
	AssertNotNil(InGroup, "it should be added to the Human group")
	AssertTrue(InGroup.IsItemBodyLocation, "the group must hold the object, not a name")
end)

Test("the base namespace is refused, as the game refuses it", function()
	local Ok = pcall(ItemBodyLocation.register, "Sling")
	AssertFalse(Ok, "an unnamespaced name must be rejected")
end)

Test("the item script BodyLocation matches what was registered", function()
	-- Item parses its BodyLocation value through the same ResourceLocation.of, so a
	-- bare "Sling" in the script would resolve to base:sling and never match.
	local Namespace, Path = Harness.ResourceLocation("qolc:Sling")
	AssertEquals(Namespace .. ":" .. Path, "qolc:sling", "item script value resolves here")
	AssertNotNil(ItemBodyLocation.Registered[Namespace .. ":" .. Path],
		"the script value must resolve to a registered location")
end)

Test("every sling item ends up with the body location applied", function()
	-- Item scripts parse before mod lua, so the script's BodyLocation value resolves
	-- to nothing and the game leaves it null. Without re-applying it the item can be
	-- spawned but never worn, which is exactly how this failed in game.
	for _, Name in ipairs({ "Base.SlingAFront", "Base.SlingABack" }) do
		local Item = ScriptManager.instance:getItem(Name)
		AssertNotNil(Item, Name .. " should exist")

		local Location = Item:getBodyLocation()
		AssertNotNil(Location, Name .. " has no body location, so it cannot be worn")
		AssertEquals(Location.Id, "qolc:sling", Name .. " body location")
	end
end)

Test("the sling attachment points register", function()
	local Body = BodyLocations.getGroup("Human")
	AssertNotNil(Body.Locations["qolc:sling"], "Sling body location")

	local Attached = AttachedLocations.getGroup("Human")
	AssertEquals(Attached.Locations["SlingRifle"].AttachmentName, "sling_rifle", "rifle point")
	AssertEquals(Attached.Locations["SlingRifle Back"].AttachmentName, "sling_rifleback", "back point")
	AssertEquals(Attached.Locations["SlingShovelBag"].AttachmentName, "sling_shovelbag", "bag point")
end)

--// Hotbar
Test("two sling slots are added to the hotbar", function()
	local Found = 0
	for _, Slot in ipairs(ISHotbarAttachDefinition) do
		if Slot.name == "Sling" then Found = Found + 1 end
	end
	AssertEquals(Found, 2, "sling slot count")
end)

Test("the back sling slot uses the back animset", function()
	for _, Slot in ipairs(ISHotbarAttachDefinition) do
		if Slot.type == "SlingBack" then
			AssertEquals(Slot.animset, "back", "back slot animset")
			AssertEquals(Slot.attachments.Rifle, "SlingRifle Back", "back slot rifle point")
			return
		end
	end
	Fail("SlingBack slot was not registered")
end)

Test("bag replacements are registered", function()
	local Replacements = ISHotbarAttachDefinition.replacements[1].replacement
	AssertEquals(Replacements.RifleSling, "SlingRifleBag", "rifle bag swap")
	AssertEquals(Replacements.BigBladeSling, "SlingBladeBag", "blade bag swap")
end)

Test("sling attachment types resolve", function()
	AssertEquals(QolcIsSling("Rifle", "SlingRifle"), "RifleSling", "slung rifle")
	AssertEquals(QolcIsSling("Rifle", "Back"), "Rifle", "a rifle not on a sling is unchanged")
	AssertTrue(QolcIsBack("SlingRifle Back") ~= nil and QolcIsBack("SlingRifle Back") ~= false,
		"back slot detected")
	AssertFalse(QolcIsBack(nil), "nil slot is not a back slot")
end)

--// Keybinds
Test("extra hotbar slots are added without stealing vanilla keys", function()
	local Added = {}
	for _, Binding in ipairs(keyBinding) do
		if Binding.value then Added[Binding.value] = Binding end
	end

	-- Vanilla owns 1 through 8, we must not redefine them
	for Slot = 1, 8 do
		AssertNil(Added["Hotbar " .. tostring(Slot)],
			"Hotbar " .. Slot .. " belongs to vanilla and must not be rebound")
	end

	for Slot = 9, 16 do
		local Binding = Added["Hotbar " .. tostring(Slot)]
		AssertNotNil(Binding, "Hotbar " .. Slot .. " should be added")
		AssertEquals(Binding.key, 0, "Hotbar " .. Slot .. " should default to unbound")
	end
end)


--// The Back Slot And A Bag
-- Vanilla swaps a back slung item to a bag variant when a bag is worn, and takes off the
-- ones that cannot hang beside it. Our override widened that test to cover the sling
-- slots and, in widening it, narrowed it for one vanilla case.
local function BackSlotDef()
	return {
		name = "Back",
		type = "Bag",
		attachments = { BigBlade = "Blade On Back", Guitar = "Guitar" }
	}
end

local function AttachOnBack(Item, Slot, Replacements)
	local Player = Harness.InstallAttachments(Harness.NewPlayer(0, true))
	local Hotbar = Harness.NewHotbar(Player, { "Back" })

	Hotbar.replacements = Replacements
	Hotbar.attachedItems[1] = Item
	Hotbar:attachItem(Item, Slot, 1, BackSlotDef(), false)

	return Hotbar, Player
end

Test("an axe on the back swaps to its bag variant", function()
	local Axe = Harness.NewHotbarItem("BigBlade", "Axe")
	local Hotbar, Player = AttachOnBack(Axe, "Blade On Back",
		{ BigBlade = "Big Blade On Back with Bag" })

	AssertEquals(Harness.AttachedAt(Player, Axe), "Big Blade On Back with Bag",
		"it should hang off the bag variant")
	AssertEquals(Hotbar.attachedItems[1], Axe, "and stay on the bar")
end)

Test("a guitar comes off the back when a bag is worn", function()
	-- The back slot's guitar attachment point is named "Guitar", with no " Back" in it,
	-- so testing the model point alone skipped the replacement and left the guitar
	-- hanging through the backpack instead of being taken off.
	local Guitar = Harness.NewHotbarItem("Guitar", "Guitar")
	local Hotbar, Player = AttachOnBack(Guitar, "Guitar", { Guitar = "null" })

	AssertNil(Hotbar.attachedItems[1], "it should have come off the bar")
	AssertNil(Harness.AttachedAt(Player, Guitar), "and off the model")
end)

Test("a point that is null with no bag in sight still takes the item off", function()
	-- Vanilla tests this outside the bag branch as well. With only the inner test, the
	-- item was handed to setAttachedItem with "null" as its model point.
	local Guitar = Harness.NewHotbarItem("Guitar", "Guitar")
	local Hotbar, Player = AttachOnBack(Guitar, "null", nil)

	AssertNil(Hotbar.attachedItems[1], "no bag, but still nowhere to hang it")
	AssertNil(Harness.AttachedAt(Player, Guitar), "and nothing hanging off null")
end)
