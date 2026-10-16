--// The Nutritionist Spec
--// aspctt - 18.08.2026

--// Helpers
local MAGAZINE = "Base.QolcNutritionistMag"

local function Reader()
	return Harness.NewPlayer(0, true)
end

local function NewReading(Player, FullType)
	local Book = Harness.NewInventoryItem("Magazine")
	function Book:getFullType() return FullType or MAGAZINE end
	function Book:getNumberOfPages() return 0 end
	function Book:setJobDelta() end

	return Harness.NewReading(Player, Book)
end

-- A finished read of the given item, the way IsoGameCharacter runs one: start, perform,
-- then complete straight after unless this is a multiplayer client
local function Read(Player, FullType)
	local Action = NewReading(Player, FullType)
	Action:start()
	Action:perform()
	if not isClient() then Action:complete() end
	return Action
end

-- The same read as a server sees it. NetTimedAction calls serverStart and complete, and
-- never start or perform.
local function ServerRead(Player, FullType)
	Harness.IsServer = true
	local Action = NewReading(Player, FullType)
	Action:complete()
	return Action
end

local function Knows(Player)
	return Player:hasTrait(CharacterTrait.NUTRITIONIST2)
end

-- The packets a server sent the reader carrying their traits, PF_Traits being 0x02
local function TraitSyncs(Player)
	local Found = {}
	for _, Sync in ipairs(Harness.PlayerFieldSyncs) do
		local CarriesTraits = math.floor(Sync.Fields / 2) % 2 == 1
		if Sync.Sent and Sync.Character == Player and CarriesTraits then
			table.insert(Found, Sync)
		end
	end
	return Found
end

-- A loot table holding cooking magazines, as vanilla ships them
local function CookingRoom(Weight)
	local Room = { rolls = 4, items = { "CookingMag1", Weight or 2, "Bread", 8 } }
	ProceduralDistributions.list["QolcTestKitchen"] = Room
	return Room
end

local function Merge()
	Harness.Fire("OnPreDistributionMerge")
end

local function WeightOf(Room, Name)
	for Index = 1, #Room.items - 1, 2 do
		if Room.items[Index] == Name then return Room.items[Index + 1] end
	end
	return nil
end

--// Learning It
Test("reading the magazine teaches the trait", function()
	local Player = Reader()
	AssertFalse(Knows(Player), "should not know it to begin with")

	Read(Player)
	AssertTrue(Knows(Player), "the trait should have been added")
end)

Test("the trait goes on through the build 42 api", function()
	-- getTraits and its string names are gone. Anything still calling them errors, so
	-- this proves the trait is readable the way the game reads it.
	local Player = Reader()
	Read(Player)

	AssertTrue(Player:getCharacterTraits():get(CharacterTrait.NUTRITIONIST2), "on the object")
	AssertTrue(Player:hasTrait(CharacterTrait.NUTRITIONIST2), "and to hasTrait")
end)

Test("reading anything else teaches nothing", function()
	local Player = Reader()
	Read(Player, "Base.CookingMag1")

	AssertFalse(Knows(Player), "only our own magazine teaches this")
end)

Test("the character mentions it", function()
	local Player = Reader()
	Read(Player)

	AssertEquals(#Player.Said, 1, "one line on learning it")
end)

Test("reading it twice says nothing the second time", function()
	local Player = Reader()
	Read(Player)
	Read(Player)

	AssertEquals(#Player.Said, 1, "there is nothing new to learn")
end)

Test("someone who chose the trait at creation is left alone", function()
	-- Nutritionist and Nutritionist2 are mutually exclusive in character_traits.txt, so
	-- adding the second to someone holding the first would leave them with both
	local Player = Reader()
	Player:setTrait(CharacterTrait.NUTRITIONIST, true)

	Read(Player)

	AssertFalse(Knows(Player), "the profession version must not be added on top")
	AssertEquals(#Player.Said, 0, "and nothing to say about it")
end)

Test("vanilla's own perform still runs", function()
	local Player = Reader()
	local Action = Read(Player)

	AssertTrue(Action.Performed, "the read has to finish the way vanilla finishes it")
	AssertTrue(Action.Completed, "and vanilla's complete with it")
end)

--// Multiplayer
Test("on a server, finishing the read teaches it", function()
	-- The first version taught it from perform in a client file, which no server runs, so
	-- the server's copy of the reader never had the trait
	local Player = Reader()
	ServerRead(Player)

	AssertTrue(Knows(Player), "the server's character should hold the trait")
end)

Test("the server sends the new trait to the reader", function()
	-- Vanilla's complete syncs traits too, but before ours has added anything. Every later
	-- sync replaces the client's list wholesale, so the trait has to be in one of them.
	local Player = Reader()
	ServerRead(Player)

	local Carried = false
	for _, Sync in ipairs(TraitSyncs(Player)) do
		if Sync.Traits[CharacterTrait.NUTRITIONIST2] then Carried = true end
	end

	AssertTrue(Carried, "a trait sync should carry it to the client")
end)

Test("a server says nothing out loud", function()
	-- The line belongs to the reader's own screen, and a server never runs perform
	local Player = Reader()
	ServerRead(Player)

	AssertEquals(#Player.Said, 0, "nothing said on the server")
end)

Test("a multiplayer client leaves the trait to the server", function()
	-- A client adding it on its own would be overwritten by the next sync anyway, and
	-- would show the reader a trait the server does not think they have
	Harness.IsClient = true
	local Player = Reader()
	Read(Player)

	AssertFalse(Knows(Player), "only the server teaches it")
	AssertEquals(#Player.Said, 1, "but the reader still hears about it")
end)

Test("the line comes even when the server's sync lands first", function()
	-- The client waits for the server to finish before it performs, so the trait is
	-- often already there by the time perform runs
	Harness.IsClient = true
	local Player = Reader()
	local Action = NewReading(Player)

	Action:start()
	Player:getCharacterTraits():add(CharacterTrait.NUTRITIONIST2)
	Action:perform()

	AssertEquals(#Player.Said, 1, "one line on learning it")
end)

Test("a reader who already knew hears nothing in multiplayer either", function()
	Harness.IsClient = true
	local Player = Reader()
	Player:getCharacterTraits():add(CharacterTrait.NUTRITIONIST2)

	Read(Player)

	AssertEquals(#Player.Said, 0, "there was nothing to learn")
end)

Test("a server with the magazine switched off teaches nothing", function()
	SandboxVars.QoLC.NutritionistMagEnabled = false
	local Player = Reader()
	ServerRead(Player)

	AssertFalse(Knows(Player), "the switch holds on the server too")
	AssertEquals(#TraitSyncs(Player), 1, "vanilla's own sync, and nothing of ours")
end)

--// Where It Spawns
Test("it is added beside the cooking magazines", function()
	local Room = CookingRoom(2)
	Merge()

	AssertNotNil(WeightOf(Room, "QolcNutritionistMag"), "it should be in the table")
end)

Test("it spawns at half a cooking magazine's odds", function()
	local Room = CookingRoom(2)
	Merge()

	AssertEquals(WeightOf(Room, "QolcNutritionistMag"), 1, "half of two")
end)

Test("a table with no cooking magazines is left alone", function()
	local Room = { rolls = 4, items = { "Bread", 8 } }
	ProceduralDistributions.list["QolcTestEmpty"] = Room
	Merge()

	AssertNil(WeightOf(Room, "QolcNutritionistMag"), "nothing to sit beside")
end)

Test("merging twice does not add it twice", function()
	-- OnPreDistributionMerge can fire more than once, and a second copy would double
	-- the odds without anyone noticing
	local Room = CookingRoom(2)
	Merge()
	Merge()

	local Count = 0
	for Index = 1, #Room.items - 1, 2 do
		if Room.items[Index] == "QolcNutritionistMag" then Count = Count + 1 end
	end

	AssertEquals(Count, 1, "one entry, however many merges")
end)

Test("an absurd weight is clamped", function()
	local Room = CookingRoom(40)
	Merge()

	AssertEquals(WeightOf(Room, "QolcNutritionistMag"), 2, "the ceiling holds")
end)

Test("a tiny weight is floored", function()
	local Room = CookingRoom(0.02)
	Merge()

	AssertEquals(WeightOf(Room, "QolcNutritionistMag"), 0.1, "the floor holds")
end)

--// The Switch
Test("the table is seeded whatever the switch says", function()
	-- Deliberate, and the reverse of what this asserted before. The merge events fire
	-- before SandboxOptions.load, the only thing that ever fills SandboxVars from the save,
	-- so a switch read here is our own declared default rather than the player's answer.
	-- The switch is applied at fill time instead. See qolc_loot_switch.lua.
	SandboxVars.QoLC.NutritionistMagEnabled = false
	local Room = CookingRoom(2)
	Merge()

	AssertEquals(WeightOf(Room, "QolcNutritionistMag"), 1, "seeded regardless")
end)

Test("turning it off stops it spawning", function()
	SandboxVars.QoLC.NutritionistMagEnabled = false

	AssertTrue(QolcLootSwitch.IsWithheld("Base.QolcNutritionistMag"), "held out of the world")
end)

Test("turning it off stops it teaching", function()
	SandboxVars.QoLC.NutritionistMagEnabled = false
	local Player = Reader()
	Read(Player)

	AssertFalse(Knows(Player), "a copy found earlier should do nothing either")
end)

Test("a save made before this existed still reads", function()
	Harness.ClearSandbox()
	local Player = Reader()
	Read(Player)

	AssertTrue(Knows(Player), "falls back to the shipped default")
end)

--// Wiring
Test("the switch is a sandbox option, not a tick box", function()
	AssertNotNil(QOLC_SANDBOX_DEFAULTS["NutritionistMagEnabled"], "should be server controlled")
end)

Test("every label resolves", function()
	local Keys = {
		"Sandbox_QoLC_NutritionistMagEnabled", "Sandbox_QoLC_NutritionistMagEnabled_tooltip",
		"IGUI_QoLC_LearnedNutrition"
	}

	for _, Key in ipairs(Keys) do
		AssertNotNil(Translations[Key], "missing translation for " .. Key)
	end

	AssertNotNil(Translations["Base.QolcNutritionistMag"], "the magazine needs a name")
end)
