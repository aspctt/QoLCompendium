--// Metalworking Gaps Spec
--// aspctt - 28.08.2026
--// Four things build 42 has items for and no way to make.
--//
--// The reason this feature is worth having is the reason worth guarding: each of these
--// closes a hole that is genuinely open. A recipe duplicating something vanilla already
--// does would be noise in the crafting menu, so the tests care about what is asked for
--// as much as about what comes out.

--// Helpers
local SCRIPT = "qolc_metalworking.txt"

local RECIPES = {
	"QolcCraftWire", "QolcCraftIronPipe",
	"QolcCraftWeldingRod", "QolcCraftElectricalWire"
}

local function Script()
	return Harness.ReadModScript(SCRIPT)
end

local function Block(Name)
	return Script():match("craftRecipe " .. Name .. "\n%s*{(.-)\n\t}")
end

local function SetEnabled(Value)
	SandboxVars.QoLC = SandboxVars.QoLC or {}
	SandboxVars.QoLC.MetalworkingEnabled = Value
end

--// The Recipes
Test("all four recipes are declared", function()
	for _, Name in ipairs(RECIPES) do
		AssertNotNil(Block(Name), Name .. " should be in the script")
	end
end)

Test("each one produces the thing it exists for", function()
	local Outputs = {
		QolcCraftWire = "item 2 Base.Wire",
		QolcCraftIronPipe = "item 1 Base.MetalPipe",
		QolcCraftWeldingRod = "item 2 Base.WeldingRods",
		QolcCraftElectricalWire = "item 2 Base.ElectricWire"
	}

	for Name, Output in pairs(Outputs) do
		AssertContains(Block(Name), Output, Name .. " should make it")
	end
end)

Test("field names match vanilla's lowercase", function()
	-- CraftRecipe compares them with equalsIgnoreCase so capitals would parse, but vanilla
	-- writes time and category lowercase in every one of its uses and matching the game is
	-- worth more than matching whoever typed it first.
	for _, Field in ipairs({ "Time = ", "Category = ", "TimedAction = " }) do
		AssertFalse(string.find(Script(), "\n\t\t" .. Field, 1, true) ~= nil,
			Field .. "should be lowercase")
	end

	for _, Name in ipairs(RECIPES) do
		AssertContains(Block(Name), "time = ", Name .. " needs a time")
		AssertContains(Block(Name), "category = ", Name .. " needs a category")
	end
end)

--// What They Ask For
Test("nothing spends a MetalBar, because nothing in the game makes one", function()
	-- The change from how these were first written. MetalBar has no producer anywhere and
	-- only ever appears on the input side of the blacksmith mappers, so spending it would
	-- have left welding rods capped by loot and the gap still open.
	for _, Name in ipairs(RECIPES) do
		local Text = Block(Name)
		for Line in string.gmatch(Text, "[^\n]+") do
			if string.find(Line, "Base.MetalBar", 1, true) then
				AssertContains(Line, "mode:keep",
					Name .. " may hold a MetalBar as a tool but must not spend one: " .. Line)
			end
		end
	end
end)

Test("the pipe mandrel can be forged rather than only found", function()
	-- It is kept and wears heavily, so it is a tool. Accepting only the unproducible
	-- MetalBar would mean pipe making stops for good once yours wears out.
	local Line = Block("QolcCraftIronPipe"):match("([^\n]*MetalBar[^\n]*)")

	AssertNotNil(Line, "the mandrel line should be there")
	AssertContains(Line, "Base.IronBar", "a forged bar should do")
	AssertContains(Line, "MayDegradeHeavy", "and it should wear out")
end)

--// Made The Way The Thing Is Actually Made
Test("wire is drawn, and drawing multiplies length", function()
	-- A bar is tapered, pulled through the plate and annealed between passes. Drawing turns
	-- a short thick thing into a long thin one, so one bar is worth more than one spool.
	local Text = Block("QolcCraftWire")

	AssertContains(Text, "[Base.DrawPlate] mode:keep", "the plate is what draws it")
	AssertContains(Text, "tags[base:charcoal]", "and it is annealed between passes")
	AssertContains(Text, "item 2 Base.Wire", "one bar, two spools")
end)

Test("pipe is rolled from a flat strip around a mandrel, not wrapped from a bar", function()
	-- Wrought iron pipe was made by rolling a strip round a mandrel and forge welding the
	-- seam. The bar is the mandrel it is formed on, not the stock it is made from.
	local Text = Block("QolcCraftIronPipe")

	AssertContains(Text, "item 1 [Base.SmallSheetMetal]", "a flat strip is the stock")
	AssertContains(Text, "item 1 [Base.Limestone]", "and the seam weld needs flux")
	AssertFalse(string.find(Text, "item 1 [Base.IronBar;Base.SteelBar],", 1, true) ~= nil,
		"a bar is the mandrel here, not the material")
end)

Test("a welding rod is a wire core with a flux coating", function()
	-- Which is what a covered electrode is. The coating was already right: limestone for
	-- the carbonate, the crucible's glass for the silica, and splinters for the cellulose,
	-- which is genuinely how a cellulosic electrode is bound.
	local Text = Block("QolcCraftWeldingRod")

	AssertContains(Text, "item 20 [Base.Wire]", "the core is wire")
	AssertContains(Text, "[Base.Limestone]", "carbonate")
	AssertContains(Text, "[Base.CeramicCrucibleWithGlass]", "silica")
	AssertContains(Text, "[Base.Splinters]", "cellulose")
end)

Test("electrical wire uses a conductor, and steel is not one", function()
	-- Copper or aluminium, drawn on the same plate and insulated. Aluminium house wiring is
	-- not a compromise either: it is what America was wiring houses with in the seventies.
	local Text = Block("QolcCraftElectricalWire")

	AssertContains(Text, "Base.CopperScrap", "copper")
	AssertContains(Text, "Base.Aluminum", "or aluminium")
	AssertContains(Text, "[Base.DrawPlate] mode:keep", "drawn on the plate")
	AssertContains(Text, "[Base.DuctTape]", "and insulated")
	AssertFalse(string.find(Text, "[Base.Wire]", 1, true) ~= nil,
		"steel wire has no business in a cable")
end)

Test("the forge recipes need a forge, and the wiring one does not", function()
	AssertContains(Block("QolcCraftWire"), "Tags = Forge", "a forge")
	AssertContains(Block("QolcCraftIronPipe"), "Tags = AdvancedForge", "a better forge")
	AssertContains(Block("QolcCraftWeldingRod"), "Tags = Forge",
		"rods are a coating baked on, not forging, so an ordinary forge does")
	AssertContains(Block("QolcCraftElectricalWire"), "Tags = AnySurfaceCraft",
		"wiring is bench work, not smithing")
end)

--// In Line With Vanilla
Test("every recipe is held behind a skill and has to be learned", function()
	-- Vanilla's own convention rather than a choice made here. Above Blacksmith 1 the game
	-- gates effectively everything: nine recipes at level 2 need learning and none is free,
	-- thirty at level 4 and none is free. All 106 of the learned ones carry an AutoLearnAll
	-- so they arrive by levelling anyway.
	for _, Name in ipairs(RECIPES) do
		local Text = Block(Name)
		AssertContains(Text, "SkillRequired = ", Name .. " should need some skill")
		AssertContains(Text, "NeedToBeLearn = true", Name .. " should not be free from the start")
		AssertContains(Text, "AutoLearnAll = ", Name .. " should still arrive by levelling")

		-- One level above the requirement, so meeting the skill is nearly enough on its own.
		local Skill, Need = Text:match("SkillRequired = (%w+):(%d+)")
		local Auto = Text:match("AutoLearnAll = " .. Skill .. ":(%d+)")
		AssertEquals(tonumber(Auto), tonumber(Need) + 1, Name .. " should auto learn one level up")
		AssertContains(Text, "xpAward = ", Name .. " should teach while it goes")
	end
end)

Test("the experience paid is inside the band vanilla uses at that level", function()
	-- Measured against every blacksmithing recipe in the game. Below the floor would make
	-- these a waste of a forge trip, above the ceiling would make them the fastest way to
	-- level, and both are worse than being unremarkable.
	local Bands = {
		QolcCraftWire = { Skill = "Blacksmith", Low = 10, High = 35 },
		QolcCraftIronPipe = { Skill = "Blacksmith", Low = 20, High = 45 },
		QolcCraftWeldingRod = { Skill = "Blacksmith", Low = 10, High = 50 },
		QolcCraftElectricalWire = { Skill = "Electricity", Low = 1, High = 30 }
	}

	for Name, Band in pairs(Bands) do
		local Xp = tonumber(Block(Name):match("xpAward = " .. Band.Skill .. ":(%d+)"))

		AssertNotNil(Xp, Name .. " should award " .. Band.Skill)
		AssertTrue(Xp >= Band.Low, Name .. " pays " .. tostring(Xp) .. ", under vanilla's floor of " .. Band.Low)
		AssertTrue(Xp <= Band.High, Name .. " pays " .. tostring(Xp) .. ", over vanilla's ceiling of " .. Band.High)
	end
end)

Test("the tools are kept", function()
	-- A smithing hammer consumed by one craft would be a very short career.
	for _, Name in ipairs(RECIPES) do
		AssertContains(Block(Name), "mode:keep", Name .. " should keep its tools")
	end
end)

--// The Gaps They Close
Test("no recipe here makes sheet metal, though one is glad to spend it", function()
	-- That one already works: Forge_Steel_Sheet takes a SteelBlock at a forge, so there is
	-- a real path up from ore. Adding a shortcut beside it would undercut a tree the game
	-- rebuilt on purpose, and this file is for holes rather than for shortcuts. Consuming a
	-- small sheet as pipe stock is a different thing and is what pipe is really rolled from.
	for _, Name in ipairs(RECIPES) do
		local Outputs = Block(Name):match("outputs%s*{(.-)}")
		AssertNotNil(Outputs, Name .. " should have outputs")
		AssertFalse(string.find(Outputs, "SheetMetal", 1, true) ~= nil,
			Name .. " must not produce sheet metal, which is not a gap")
	end
end)

--// The Switch
Test("the switch is hung on all four recipes", function()
	local Count = 0
	for _ in string.gmatch(Script(), "OnTest = Recipe%.OnTest%.QolcMetalworking") do
		Count = Count + 1
	end

	AssertEquals(Count, 4, "all four, or one stays craftable with the feature off")
end)

Test("on, the recipes are craftable", function()
	SetEnabled(true)

	AssertNotNil(Recipe.OnTest.QolcMetalworking, "the hook the scripts name must exist")
	AssertTrue(Recipe.OnTest.QolcMetalworking(nil, nil), "nothing is refused")
end)

Test("off, every input is refused", function()
	SetEnabled(false)

	AssertFalse(Recipe.OnTest.QolcMetalworking(nil, nil), "off means off")
end)

Test("a save with no setting stored gets the feature", function()
	SandboxVars.QoLC = SandboxVars.QoLC or {}
	SandboxVars.QoLC.MetalworkingEnabled = nil

	AssertTrue(Recipe.OnTest.QolcMetalworking(nil, nil), "the declared default is on")
end)

Test("the switch is a sandbox option, not a tick box", function()
	AssertNotNil(QOLC_SANDBOX_DEFAULTS["MetalworkingEnabled"], "should be server controlled")
end)
