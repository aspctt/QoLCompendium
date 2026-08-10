--// Show Clothes Material Spec
--// aspctt - 10.08.2026

--// Helpers
local function Apply()
	Harness.Fire("OnInitGlobalModData")
end

local function TooltipOf(Name)
	return ScriptManager.instance:getItem(Name):getTooltip()
end

--// Wiring
Test("the tooltips are set on init", function()
	AssertTrue(Harness.HandlerCount("OnInitGlobalModData") > 0, "should listen for OnInitGlobalModData")
end)

Test("clothing starts with no tooltip", function()
	AssertNil(TooltipOf("Base.Tshirt"), "the harness should start from vanilla's own value")
end)

--// Labelling
Test("each fabric gets its own tooltip", function()
	Apply()

	AssertEquals(TooltipOf("Base.Tshirt"), "Tooltip_QoLC_Fabric_Cotton", "cotton")
	AssertEquals(TooltipOf("Base.Jeans"), "Tooltip_QoLC_Fabric_Denim", "denim")
	AssertEquals(TooltipOf("Base.JacketLeather"), "Tooltip_QoLC_Fabric_Leather", "leather")
end)

Test("an item with no fabric is left alone", function()
	Apply()

	AssertNil(TooltipOf("Base.Axe"), "an axe is not made of cloth")
	AssertNil(TooltipOf("Base.Pan"), "nor is a pan")
end)

--// Leaving Vanilla Alone
Test("an item with its own tooltip keeps it", function()
	-- Three vanilla items carry both a fabric and a tooltip. All are ripped strips, and
	-- what theirs says is more useful than ours would be.
	Apply()

	AssertEquals(TooltipOf("Base.RippedSheets"), "Tooltip_RippedSheets",
		"an existing tooltip must not be overwritten")
end)

Test("a fabric with no translation is skipped", function()
	-- Setting the tooltip regardless would put a raw key on screen, which is worse than
	-- saying nothing.
	Apply()

	AssertNil(TooltipOf("Base.SilkShirt"), "an unknown fabric should get no line at all")
end)

Test("running twice changes nothing", function()
	Apply()
	local First = TooltipOf("Base.Tshirt")

	Apply()
	AssertEquals(TooltipOf("Base.Tshirt"), First, "a second pass should be a no op")
end)

Test("a second pass does not overwrite the tooltip we set", function()
	-- After the first pass the item has a tooltip, so the guard that protects vanilla's
	-- own tooltips also protects ours.
	Apply()
	Apply()
	Apply()

	AssertEquals(TooltipOf("Base.Jeans"), "Tooltip_QoLC_Fabric_Denim", "still denim")
end)

--// Translations
Test("every fabric label resolves", function()
	for _, Fabric in ipairs({ "Cotton", "Denim", "Leather" }) do
		local Key = "Tooltip_QoLC_Fabric_" .. Fabric
		AssertNotNil(Translations[Key], "missing translation for " .. Key)
	end
end)

Test("the labels name the fabric", function()
	AssertContains(Translations["Tooltip_QoLC_Fabric_Cotton"], "cotton", "cotton label")
	AssertContains(Translations["Tooltip_QoLC_Fabric_Denim"], "denim", "denim label")
	AssertContains(Translations["Tooltip_QoLC_Fabric_Leather"], "leather", "leather label")
end)
