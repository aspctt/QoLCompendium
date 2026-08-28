--// Food Categories Spec
--// aspctt - 10.08.2026

local PERISHABLE = "FoodPerishable"
local KEEPS = "FoodNonPerishable"

--// Helpers
local function Apply()
	Harness.Fire("OnInitGlobalModData")
end

local function CategoryOf(Name)
	return ScriptManager.instance:getItem(Name):getDisplayCategory()
end

--// Wiring
Test("the split is applied on init", function()
	AssertTrue(Harness.HandlerCount("OnInitGlobalModData") > 0, "should listen for OnInitGlobalModData")
end)

Test("food starts in vanilla's single category", function()
	AssertEquals(CategoryOf("Base.Tomato"), "Food", "the harness should start from vanilla's own value")
end)

--// Splitting
Test("food that rots is marked perishable", function()
	Apply()

	AssertEquals(CategoryOf("Base.Tomato"), PERISHABLE, "a tomato spoils")
	AssertEquals(CategoryOf("Base.Cabbage"), PERISHABLE, "a cabbage spoils")
end)

Test("food with no rot time is marked as keeping", function()
	Apply()

	AssertEquals(CategoryOf("Base.TinnedBeans"), KEEPS, "tinned food does not spoil")
	AssertEquals(CategoryOf("Base.Yeast"), KEEPS, "nor does yeast")
end)

Test("slow rotting food is still perishable", function()
	-- A potato lasts 280 days and honey 730, which is vanilla's longest. Both still
	-- spoil, so both belong with the food you have to get through.
	Apply()

	AssertEquals(CategoryOf("Base.Potato"), PERISHABLE, "280 days is still a rot time")
	AssertEquals(CategoryOf("Base.Honey"), PERISHABLE, "730 days is vanilla's longest")
end)

Test("a modded never-rots value is treated as keeping", function()
	-- Some mods use a huge number to mean "never" rather than leaving it unset. Read
	-- literally that would file a tin of rations next to fresh meat.
	Apply()

	AssertEquals(CategoryOf("Modded.EternalRation"), KEEPS,
		"a decade or more is a mod saying never, not food that spoils")
end)

--// Leaving Vanilla Alone
Test("anything vanilla did not call food is untouched", function()
	Apply()

	AssertEquals(CategoryOf("Base.Pan"), "Cooking", "a pan is not food")
	AssertEquals(CategoryOf("Base.Axe"), "ToolWeapon", "nor is an axe")
end)

Test("running twice does not change the result", function()
	Apply()
	local First = CategoryOf("Base.Tomato")

	Apply()
	AssertEquals(CategoryOf("Base.Tomato"), First,
		"the second pass sees FoodPerishable, not Food, so it should do nothing")
end)

Test("a second pass does not re-file perishable food as keeping", function()
	-- The guard is that only items still reading Food are touched. Without it the
	-- second pass would find no rot time on the already renamed category and flip
	-- everything to the wrong side.
	Apply()
	Apply()
	Apply()

	AssertEquals(CategoryOf("Base.Tomato"), PERISHABLE, "should still be perishable")
	AssertEquals(CategoryOf("Base.TinnedBeans"), KEEPS, "and tinned food should still keep")
end)

--// Translations
Test("both new categories have a label", function()
	-- The inventory header draws getText("IGUI_ItemCat_" .. category), so a missing key
	-- shows the raw category name to the player.
	AssertNotNil(Translations["IGUI_ItemCat_" .. PERISHABLE], "missing label for " .. PERISHABLE)
	AssertNotNil(Translations["IGUI_ItemCat_" .. KEEPS], "missing label for " .. KEEPS)
end)

Test("the labels read as one distinction cut two ways", function()
	-- Both halves say Food, and both say Perishable, so a sorted column reads as one split
	-- rather than as two unrelated headings. The non-perishable one said "Food (Keeps)" for
	-- a while, which was a verb sitting beside an adjective and did not match its own key.
	local Spoils = Translations["IGUI_ItemCat_" .. PERISHABLE]
	local Keeps = Translations["IGUI_ItemCat_" .. KEEPS]

	AssertContains(Spoils, "Food", "perishable label")
	AssertContains(Keeps, "Food", "non-perishable label")
	AssertContains(Spoils, "Perishable", "the word the split turns on")
	AssertContains(Keeps, "Non-Perishable", "and its opposite, spelled the same way")
end)
