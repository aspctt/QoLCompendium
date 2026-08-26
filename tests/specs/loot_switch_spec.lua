--// The Loot Switch Spec
--// aspctt - 25.08.2026
--// Three features seed their items into the loot tables, and all three had a sandbox
--// switch that did nothing at all.
--//
--// The seeding runs in OnPreDistributionMerge. IsoWorld.init fires that, then the other
--// two merge events, and only afterwards calls SandboxOptions.load, which is the one
--// place the save's sandbox file is ever read and whose last act, toLua, is what fills
--// SandboxVars. Before that, SandboxVars holds what initSandboxVars wrote when the lua
--// loaded, which is each option's declared default. So every one of those switches was
--// reading our own default and reporting it as the player's choice.
--//
--// The switch now runs at OnFillContainer, which fires after each container is filled
--// and long after the options are real.

--// Helpers
local BOOKS = { "Base.QolcLockpickBook1", "Base.QolcLockpickBook2" }
local HAIRPIN = "Base.QolcHairpin"
local SLING = "Base.SlingAFront"
local MAGAZINE = "Base.QolcNutritionistMag"

local function Holding(...)
	local Container = Harness.NewContainer("crate")

	for _, FullType in ipairs({ ... }) do
		local Item = Harness.NewInventoryItem(FullType:match("[^.]+$"))
		Item.FullType = FullType
		table.insert(Container.Items, Item)
	end

	return Container
end

local function Fill(Container)
	Harness.Fire("OnFillContainer", "bathroom", "crate", Container)
end

local function Types(Container)
	local Found = {}

	for _, Item in ipairs(Container.Items) do
		table.insert(Found, Item:getFullType())
	end

	return table.concat(Found, ",")
end

local function SetSwitch(Option, Value)
	SandboxVars.QoLC = SandboxVars.QoLC or {}
	SandboxVars.QoLC[Option] = Value
end

--// On, Which Is Every Feature By Default
Test("nothing is taken out of a container while the switches are on", function()
	local Container = Holding(BOOKS[1], BOOKS[2], HAIRPIN, SLING, MAGAZINE, "Base.Nails")
	Fill(Container)

	AssertEquals(#Container.Items, 6, "every one of them stays")
end)

Test("a save with nothing stored keeps the shipped default", function()
	Harness.ClearSandbox()

	local Container = Holding(HAIRPIN)
	Fill(Container)

	AssertEquals(#Container.Items, 1, "the default is on")
end)

--// Off
Test("turning lockpicking off takes its items back out", function()
	SetSwitch("LockpickingEnabled", false)

	local Container = Holding(BOOKS[1], BOOKS[2], HAIRPIN)
	Fill(Container)

	AssertEquals(#Container.Items, 0, "nothing of ours is left: " .. Types(Container))
end)

Test("a switch reaches only its own items", function()
	-- Three features share one handler, so a switch that swept the lot would look like it
	-- worked while quietly emptying the other two.
	SetSwitch("LockpickingEnabled", false)

	local Container = Holding(HAIRPIN, SLING, MAGAZINE)
	Fill(Container)

	AssertEquals(Types(Container), SLING .. "," .. MAGAZINE, "only the hairpin goes")
end)

Test("the sling and the magazine have switches of their own", function()
	SetSwitch("SlingEnabled", false)
	SetSwitch("NutritionistMagEnabled", false)

	local Container = Holding(SLING, MAGAZINE, HAIRPIN)
	Fill(Container)

	AssertEquals(Types(Container), HAIRPIN, "and lockpicking is still on")
end)

Test("what was never ours is left alone", function()
	SetSwitch("LockpickingEnabled", false)

	local Container = Holding("Base.Nails", HAIRPIN, "Base.Screwdriver")
	Fill(Container)

	AssertEquals(Types(Container), "Base.Nails,Base.Screwdriver", "vanilla loot untouched")
end)

Test("several copies of the same item all go", function()
	-- Removing shortens the list under the index, which is why the walk runs backwards.
	SetSwitch("LockpickingEnabled", false)

	local Container = Holding(HAIRPIN, HAIRPIN, HAIRPIN)
	Fill(Container)

	AssertEquals(#Container.Items, 0, "all three: " .. Types(Container))
end)

Test("the last item in a container is reached", function()
	SetSwitch("LockpickingEnabled", false)

	local Container = Holding("Base.Nails", HAIRPIN)
	Fill(Container)

	AssertEquals(Types(Container), "Base.Nails", "the walk covers the end of the list")
end)

--// Robustness
-- This runs after every container the game fills, so anything it is handed has to be
-- survivable rather than merely unlikely.
Test("a container the game hands us empty or missing is not an error", function()
	SetSwitch("LockpickingEnabled", false)

	Harness.Fire("OnFillContainer", "bathroom", "crate", nil)
	Fill(Holding())

	AssertTrue(true, "nothing threw")
end)

--// Wiring
Test("all three features are registered against the one handler", function()
	AssertEquals(Harness.HandlerCount("OnFillContainer"), 1, "one handler, not one each")

	SetSwitch("LockpickingEnabled", false)
	SetSwitch("SlingEnabled", false)
	SetSwitch("NutritionistMagEnabled", false)

	for _, FullType in ipairs({ BOOKS[1], BOOKS[2], HAIRPIN, SLING, MAGAZINE }) do
		AssertTrue(QolcLootSwitch.IsWithheld(FullType), FullType .. " should be covered")
	end
end)

Test("the seeding ignores the switch, because at that moment it cannot see it", function()
	-- The bug stated as the behaviour that replaced it. All three seed unconditionally,
	-- and the one test that matters is that turning a feature off does not stop them:
	-- a switch honoured here would be honouring our own declared default.
	SetSwitch("LockpickingEnabled", false)
	SetSwitch("SlingEnabled", false)
	SetSwitch("NutritionistMagEnabled", false)

	Harness.Fire("OnPreDistributionMerge")

	local Bathroom = ProceduralDistributions.list["BathroomCabinet"]
	AssertNotNil(Harness.LootWeight(Bathroom, HAIRPIN), "the hairpin is seeded")

	local Army = ProceduralDistributions.list["ArmyStorageOutfit"]
	AssertNotNil(Harness.LootWeight(Army, SLING), "and the sling")
end)
