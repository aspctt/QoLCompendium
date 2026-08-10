--// Show Clothes Material Spec
--// aspctt - 10.08.2026

--// Helpers
local function Render(Fabric)
	local Item = Fabric and Harness.NewGarment(Fabric) or Harness.NewPlainItem()
	local Panel = Harness.NewItemTooltip(Item)
	Panel:render()
	return Panel
end

local function Line(Panel)
	return Panel.tooltip.Texts[1]
end

--// Wiring
Test("the tooltip render is wrapped, not replaced", function()
	local Panel = Render("Cotton")
	AssertEquals(Panel.VanillaRenders, 1, "vanilla still has to draw the tooltip itself")
end)

--// The Line
Test("a garment gets a fabric line", function()
	local Panel = Render("Leather")

	AssertEquals(#Panel.tooltip.Texts, 1, "one line, not more")
	AssertEquals(Line(Panel).Text, "Fabric: Leather", "label, a space, then the fabric")
end)

Test("each fabric names itself", function()
	AssertEquals(Line(Render("Cotton")).Text, "Fabric: Cotton", "cotton")
	AssertEquals(Line(Render("Denim")).Text, "Fabric: Denim", "denim")
	AssertEquals(Line(Render("Leather")).Text, "Fabric: Leather", "leather")
end)

Test("anything that is not clothing gets no line", function()
	local Panel = Render(nil)
	AssertEquals(#Panel.tooltip.Texts, 0, "an apple is not made of cloth")
end)

Test("an empty fabric is treated as none", function()
	local Panel = Render("")
	AssertEquals(#Panel.tooltip.Texts, 0, "an empty string is not a fabric")
end)

Test("a fabric the game adds later still gets a line", function()
	-- Untranslated rather than missing, so a new fabric is visible instead of silent.
	local Panel = Render("Silk")
	AssertEquals(Line(Panel).Text, "Fabric: Silk", "falls back to the raw type")
end)

--// Colour
Test("each fabric reads as itself", function()
	local Leather = Line(Render("Leather"))
	local Denim = Line(Render("Denim"))
	local Cotton = Line(Render("Cotton"))

	-- Leather is tan, so warm: more red than blue
	AssertTrue(Leather.R > Leather.B, "leather should be warm")

	-- Denim is blue, so the reverse
	AssertTrue(Denim.B > Denim.R, "denim should be blue")

	-- Cotton is a pale off white, so bright and near neutral
	AssertTrue(Cotton.R > 0.8 and Cotton.G > 0.8, "cotton should be pale")
	AssertTrue(math.abs(Cotton.R - Cotton.B) < 0.25, "and close to neutral")
end)

Test("every fabric is readable against a dark tooltip", function()
	-- The tooltip background is nearly black, so nothing may be too dark to read.
	for _, Fabric in ipairs({ "Cotton", "Denim", "Leather" }) do
		local Colour = Line(Render(Fabric))
		local Brightness = (Colour.R + Colour.G + Colour.B) / 3
		AssertTrue(Brightness > 0.4, Fabric .. " is too dark to read, got " .. tostring(Brightness))
	end
end)

Test("an unknown fabric is drawn in plain white", function()
	local Colour = Line(Render("Silk"))
	AssertNear(Colour.R, Colour.G, 0.001, "no tint")
	AssertNear(Colour.G, Colour.B, 0.001, "on either channel")
end)

--// Fitting In The Box
Test("the tooltip is grown to make room for the line", function()
	local Panel = Render("Cotton")

	AssertTrue(Panel:getHeight() > ISToolTipInv.MeasuredHeight,
		"without this the line would be drawn past the bottom border")
end)

Test("the line sits inside the box", function()
	local Panel = Render("Cotton")
	local Text = Line(Panel)

	AssertTrue(Text.Y >= ISToolTipInv.MeasuredHeight - 8, "below the item's own content")
	AssertTrue(Text.Y < Panel:getHeight(), "and above the bottom of the tooltip")
end)

Test("an item with no line does not grow the tooltip", function()
	local Panel = Render(nil)
	AssertEquals(Panel:getHeight(), ISToolTipInv.MeasuredHeight, "nothing added, nothing reserved")
end)

Test("the height override is not left behind", function()
	-- It is swapped in for one render. Left in place it would stack every frame and the
	-- tooltip would grow without bound.
	local Panel = Harness.NewItemTooltip(Harness.NewGarment("Denim"))
	local Before = Panel.setHeight

	Panel:render()
	AssertEquals(Panel.setHeight, Before, "whatever was there must be put back")

	local First = Panel:getHeight()
	Panel:render()
	AssertEquals(Panel:getHeight(), First, "and a second render must not grow it further")
end)

--// Translations
Test("every label resolves", function()
	local Keys = {
		"IGUI_QoLC_Fabric",
		"IGUI_QoLC_Fabric_Cotton",
		"IGUI_QoLC_Fabric_Denim",
		"IGUI_QoLC_Fabric_Leather"
	}

	for _, Key in ipairs(Keys) do
		AssertNotNil(Translations[Key], "missing translation for " .. Key)
	end
end)
