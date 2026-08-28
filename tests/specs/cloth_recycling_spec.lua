--// Cloth Recycling Spec
--// aspctt - 28.08.2026
--// Build 42 rips a bedsheet into ten rags through RipSheets, which takes anything
--// carrying base:sheet, and only the bedsheet carries it. A bath towel and a dish cloth
--// cannot be torn up by any route in the game, and nothing turns rags back into cloth.

--// Helpers
local SCRIPT = "qolc_cloth_recycling.txt"

local function Script()
	return Harness.ReadModScript(SCRIPT)
end

local function Block(Name)
	-- The block for one recipe, so a rule about one is not satisfied by another.
	return Script():match("craftRecipe " .. Name .. "\n%s*{(.-)\n\t}")
end

local function SetEnabled(Value)
	SandboxVars.QoLC = SandboxVars.QoLC or {}
	SandboxVars.QoLC.ClothRecyclingEnabled = Value
end

--// The Recipes Exist
Test("all three recipes are declared", function()
	for _, Name in ipairs({ "QolcRipBathTowel", "QolcRipDishCloth", "QolcSewSheet" }) do
		AssertNotNil(Block(Name), Name .. " should be in the script")
	end
end)

-- Nothing here checks that each recipe has a display name. checkRecipeNames in the runner
-- already reads Recipes.json against every craftRecipe this mod ships and fails the suite
-- when one is missing, which is how QolcCutWallet was caught. A second check would only
-- repeat it.

--// Ripping
Test("a towel and a dish cloth are consumed whole rather than by the wipe", function()
	-- Load bearing, not decoration. Both are base:drainable with UseDelta 0.1, so ten
	-- wipes to a towel. InputScript.isUsesPartialItem returns false as soon as the input
	-- is destroy, keep or ItemCount, and only otherwise counts a drainable in uses. Drop
	-- the mode and "item 1" takes a tenth of the towel and leaves the rest behind.
	AssertContains(Block("QolcRipBathTowel"), "item 1 [Base.BathTowel] mode:destroy",
		"a tenth of a towel is not a recipe")
	AssertContains(Block("QolcRipDishCloth"), "item 1 [Base.DishCloth] mode:destroy",
		"nor a tenth of a dish cloth")
end)

Test("the yield is smaller than a bedsheet's, and sized to the thing", function()
	-- The reason these are recipes rather than the base:sheet tag: RipSheets pays a flat
	-- ten for anything carrying it, and a dish cloth is not ten rags of cloth.
	AssertContains(Block("QolcRipBathTowel"), "item 3 Base.RippedSheets", "a towel is three")
	AssertContains(Block("QolcRipDishCloth"), "item 1 Base.RippedSheets", "a cloth is one")
end)

Test("no item is reopened, so the tag that would have paid ten is never added", function()
	-- Tagging a towel base:sheet would have been one line and the wrong answer: RipSheets
	-- pays a flat ten to anything carrying it. This script adds recipes and touches no
	-- item, which is the whole shape of the decision.
	for Name in string.gmatch(Script(), "\n\titem (%w+)") do
		AssertTrue(false, "reopens " .. Name .. ", which the yields are meant to avoid")
	end
end)

Test("the wet towels are left alone", function()
	-- They dry back into the dry ones on their own, which is the game's own answer.
	for _, Name in ipairs({ "BathTowelWet", "DishClothWet" }) do
		AssertFalse(string.find(Script(), Name, 1, true) ~= nil,
			Name .. " should not be a second path to the same rags")
	end
end)

--// Sewing
Test("sewing a sheet costs more rags than a sheet rips into", function()
	-- Vanilla's RipSheets pays ten. Anything at or under ten here is a machine for making
	-- cloth out of nothing, so the round trip has to lose.
	local Sewing = Block("QolcSewSheet")
	local Count = tonumber(Sewing:match("item (%d+) %[Base%.RippedSheets%]"))

	AssertNotNil(Count, "the recipe should consume ripped sheets")
	AssertTrue(Count > 10, "ten in and ten out would be a free sheet, this asks " .. tostring(Count))
end)

Test("sewing needs a needle and thread, and the needle survives", function()
	local Sewing = Block("QolcSewSheet")

	AssertContains(Sewing, "tags[base:sewingneedle] mode:keep", "a needle is not consumed")
	AssertContains(Sewing, "tags[base:thread]", "and thread is")
end)

Test("sewing is held behind a little tailoring", function()
	-- Not a day one recipe. This is for a base with a pile of rags and no sheets left.
	AssertContains(Block("QolcSewSheet"), "SkillRequired = Tailoring:2", "some skill needed")
	AssertContains(Block("QolcSewSheet"), "xpAward = Tailoring:", "and it teaches while it goes")
end)

Test("sewing produces a sheet", function()
	AssertContains(Block("QolcSewSheet"), "item 1 Base.Sheet", "one sheet out")
end)

--// The Switch
Test("the switch is hung on all three recipes", function()
	local Count = 0
	for _ in string.gmatch(Script(), "OnTest = Recipe%.OnTest%.QolcClothRecycling") do
		Count = Count + 1
	end

	AssertEquals(Count, 3, "all three need it, or one stays craftable with the feature off")
end)

Test("on, the recipes are craftable", function()
	SetEnabled(true)

	AssertNotNil(Recipe.OnTest.QolcClothRecycling, "the hook the scripts name must exist")
	AssertTrue(Recipe.OnTest.QolcClothRecycling(nil, nil), "nothing is refused")
end)

Test("off, every input is refused", function()
	-- Refusing the needle and the thread as well as the rags is what makes the recipe
	-- uncraftable rather than merely awkward.
	SetEnabled(false)

	AssertFalse(Recipe.OnTest.QolcClothRecycling(nil, nil), "off means off")
end)

Test("a save with no setting stored gets the feature", function()
	SandboxVars.QoLC = SandboxVars.QoLC or {}
	SandboxVars.QoLC.ClothRecyclingEnabled = nil

	AssertTrue(Recipe.OnTest.QolcClothRecycling(nil, nil), "the declared default is on")
end)

Test("the switch is a sandbox option, not a tick box", function()
	-- Balance, so the server decides for everyone rather than each client for itself.
	AssertNotNil(QOLC_SANDBOX_DEFAULTS["ClothRecyclingEnabled"], "should be server controlled")
end)
