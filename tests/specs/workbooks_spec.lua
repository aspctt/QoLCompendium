--// DIY Workbooks Spec
--// aspctt - 28.08.2026
--// Four practice manuals. Holding one lets you work an exercise from it, spending
--// materials for experience in that trade.
--//
--// The thing worth guarding is that every one of them loses materials. A practice recipe
--// that broke even would be a machine for free experience, and one that gained would be a
--// machine for free goods as well.

--// Helpers
local SCRIPT = "qolc_workbooks.txt"

local BOOKS = {
	"QolcWorkbookCarpentry", "QolcWorkbookElectrical",
	"QolcWorkbookWelding", "QolcWorkbookTailoring"
}

local PRACTICE = {
	QolcPracticeCarpentry = "Woodwork",
	QolcPracticeElectrical = "Electricity",
	QolcPracticeWelding = "MetalWelding",
	QolcPracticeTailoring = "Tailoring"
}

local function Script()
	return Harness.ReadModScript(SCRIPT)
end

local function Block(Name)
	return Script():match("craftRecipe " .. Name .. "\n%s*{(.-)\n\t}")
end

local function SetEnabled(Value)
	SandboxVars.QoLC = SandboxVars.QoLC or {}
	SandboxVars.QoLC.WorkbooksEnabled = Value
end

--// The Books
Test("all four books are declared", function()
	for _, Name in ipairs(BOOKS) do
		AssertContains(Script(), "item " .. Name .. "\n", Name .. " should be in the script")
	end
end)

Test("every book has a name and a tooltip", function()
	-- An item with no ItemName entry shows its internal name in the inventory, and one
	-- with a Tooltip naming nothing shows the key.
	for _, Name in ipairs(BOOKS) do
		AssertNotNil(Translations["Base." .. Name], Name .. " needs a display name")
		AssertNotNil(Translations["Tooltip_QoLC_" .. Name:gsub("^Qolc", "")],
			Name .. " needs the tooltip its script names")
	end
end)

Test("a book cannot be read, because there is nothing to read from it", function()
	-- base:literature would give it a Read entry that teaches nothing, which is the dead
	-- menu entry the Flag A Book As Seen feature exists to fix elsewhere.
	-- Anchored to an indented script line, so the header comment explaining the choice is
	-- not counted as a fifth item.
	local Count = 0
	for _ in string.gmatch(Script(), "\n\t\tItemType = base:normal,") do Count = Count + 1 end

	AssertEquals(Count, #BOOKS, "all four are normal items rather than literature")
	AssertFalse(string.find(Script(), "\n\t\tItemType = base:literature", 1, true) ~= nil,
		"none is literature")
end)

--// The Exercises
Test("every exercise keeps the book rather than consuming it", function()
	-- The book is what gates the recipe. Burning it on the first exercise would make each
	-- one a single use item, which is not what a manual is.
	-- Matched on the workbook's own line rather than anywhere in the block. Every tool in
	-- these recipes is mode:keep too, so a looser test passes while the book burns.
	for Recipe, _Skill in pairs(PRACTICE) do
		local Text = Block(Recipe)
		AssertNotNil(Text, Recipe .. " should be in the script")

		local Line = Text:match("(item 1 %[Base%.QolcWorkbook%w+%][^\n]*)")
		AssertNotNil(Line, Recipe .. " should want a workbook")
		AssertContains(Line, "mode:keep", Recipe .. " should keep it: " .. tostring(Line))
	end
end)

Test("every exercise pays experience, and in the right trade", function()
	for Recipe, Skill in pairs(PRACTICE) do
		AssertContains(Block(Recipe), "xpAward = " .. Skill .. ":25",
			Recipe .. " should teach " .. Skill)
	end
end)

Test("every exercise loses materials", function()
	-- The whole balance of the feature. Two planks become one unusable wood, three rags
	-- become one rag, and so on. Anything that broke even would be free experience.
	local Costs = {
		QolcPracticeCarpentry = { In = "item 2 [Base.Plank] mode:destroy", Out = "item 1 Base.UnusableWood" },
		QolcPracticeElectrical = { In = "item 2 [Base.ElectronicsScrap] mode:destroy", Out = "item 1 Base.ElectronicsScrap" },
		QolcPracticeWelding = { In = "item 2 [Base.ScrapMetal] mode:destroy", Out = "item 1 Base.ScrapMetal" },
		QolcPracticeTailoring = { In = "item 3 [Base.RippedSheets] mode:destroy", Out = "item 1 Base.RippedSheets" }
	}

	for Recipe, Cost in pairs(Costs) do
		local Text = Block(Recipe)
		AssertContains(Text, Cost.In, Recipe .. " should spend more than it returns")
		AssertContains(Text, Cost.Out, Recipe .. " should return less than it spends")
	end
end)

Test("the welding exercise spends torch uses rather than whole torches", function()
	-- A blowtorch is base:drainable, and an input with no mode counts a drainable in uses.
	-- Adding mode:destroy here would burn two entire torches on one exercise. Vanilla's
	-- own MakeMetalSheet writes the identical line.
	AssertContains(Block("QolcPracticeWelding"), "item 2 [Base.BlowTorch],",
		"no mode, so this is two uses")
end)

Test("the tools are kept, and the sharp one is checked", function()
	AssertContains(Block("QolcPracticeCarpentry"), "tags[base:saw] mode:keep", "a saw survives")
	AssertContains(Block("QolcPracticeWelding"), "tags[base:weldingmask] mode:keep", "so does a mask")
	AssertContains(Block("QolcPracticeTailoring"), "tags[base:scissors] mode:keep flags[SharpnessCheck;IsNotDull]",
		"blunt scissors should not do tailoring practice")
end)

--// Where They Come From
Test("the books are seeded into the loot tables", function()
	Harness.Fire("OnPreDistributionMerge")

	for _, Table in ipairs({ "BookstoreBooks", "LibraryBooks", "PostOfficeBooks", "LivingRoomShelf" }) do
		local Room = ProceduralDistributions.list[Table]
		AssertNotNil(Room, Table .. " should be a real table")
		AssertNotNil(Harness.LootWeight(Room, "Base.QolcWorkbookCarpentry"),
			"a workbook should turn up in " .. Table)
	end
end)

Test("merging twice does not double the odds", function()
	Harness.Fire("OnPreDistributionMerge")
	Harness.Fire("OnPreDistributionMerge")

	local _, Count = Harness.LootWeight(ProceduralDistributions.list["BookstoreBooks"],
		"Base.QolcWorkbookCarpentry")

	AssertEquals(Count, 1, "one entry, however often the merge runs")
end)

Test("all four books share one placement", function()
	-- A shop that stocks one DIY manual stocks the lot, and rarer odds on the welding one
	-- would say something about the world that is not true.
	Harness.Fire("OnPreDistributionMerge")
	local Room = ProceduralDistributions.list["BookstoreBooks"]

	for _, Name in ipairs(BOOKS) do
		AssertEquals(Harness.LootWeight(Room, "Base." .. Name), 0.6, Name .. " at the same weight")
	end
end)

--// The Switch
Test("the switch is hung on all four exercises", function()
	local Count = 0
	for _ in string.gmatch(Script(), "OnTest = Recipe%.OnTest%.QolcWorkbooks") do
		Count = Count + 1
	end

	AssertEquals(Count, 4, "all four, or one stays craftable with the feature off")
end)

Test("off, the exercises are refused and the books are held back", function()
	SetEnabled(false)

	AssertFalse(Recipe.OnTest.QolcWorkbooks(nil, nil), "no exercise can be crafted")

	for _, Name in ipairs(BOOKS) do
		AssertTrue(QolcLootSwitch.IsWithheld("Base." .. Name), Name .. " should stop spawning")
	end
end)

Test("on, everything works", function()
	SetEnabled(true)

	AssertTrue(Recipe.OnTest.QolcWorkbooks(nil, nil), "nothing is refused")
	AssertFalse(QolcLootSwitch.IsWithheld("Base.QolcWorkbookCarpentry"), "and they spawn")
end)

Test("a save with no setting stored gets the feature", function()
	SandboxVars.QoLC = SandboxVars.QoLC or {}
	SandboxVars.QoLC.WorkbooksEnabled = nil

	AssertTrue(Recipe.OnTest.QolcWorkbooks(nil, nil), "the declared default is on")
end)

Test("the switch is a sandbox option, not a tick box", function()
	AssertNotNil(QOLC_SANDBOX_DEFAULTS["WorkbooksEnabled"], "should be server controlled")
end)
