--// Weapon Condition Indicator Spec
--// aspctt - 10.08.2026

--// Helpers
-- One coloured rectangle per item, filling its box from the bottom in proportion to
-- what condition is left.
local function Bars(Panel)
	local Found = {}
	for _, Rect in ipairs(Panel.Drawn) do
		if Rect.R and Rect.R > 0.1 then table.insert(Found, Rect) end
	end
	return Found
end

local function NewPanel(Primary, Secondary)
	local Player = Harness.NewPlayer(0, true)
	Player.PrimaryHand = Primary
	Player.SecondaryHand = Secondary

	local Panel = Harness.NewEquippedItemPanel(Player)
	Panel.Drawn = {}
	return Panel, Player
end

--// Fraction
Test("condition is read as a fraction of the item's own maximum", function()
	-- Max differs per item, so a raw number means nothing on its own.
	AssertNear(QolcConditionFraction(Harness.NewWeapon(5, 10)), 0.5, 0.000001, "half of ten")
	AssertNear(QolcConditionFraction(Harness.NewWeapon(5, 20)), 0.25, 0.000001, "a quarter of twenty")
end)

Test("a full weapon reads as one and a broken one as zero", function()
	AssertEquals(QolcConditionFraction(Harness.NewWeapon(10, 10)), 1, "full")
	AssertEquals(QolcConditionFraction(Harness.NewWeapon(0, 10)), 0, "broken")
end)

Test("an item with no condition reads as nothing", function()
	AssertNil(QolcConditionFraction(Harness.NewPlainItem()), "food has no condition to show")
	AssertNil(QolcConditionFraction(nil), "and nil is not an item")
end)

Test("condition beyond the maximum is clamped", function()
	AssertEquals(QolcConditionFraction(Harness.NewWeapon(30, 10)), 1, "should not exceed one")
	AssertEquals(QolcConditionFraction(Harness.NewWeapon(-5, 10)), 0, "nor drop below zero")
end)

--// Drawing
Test("a bar is drawn for a weapon in hand", function()
	local Panel = NewPanel(Harness.NewWeapon(5, 10))
	Panel:render()

	AssertEquals(#Bars(Panel), 1, "one weapon, one bar")
end)

Test("both hands get their own bar", function()
	local Panel = NewPanel(Harness.NewWeapon(5, 10), Harness.NewWeapon(2, 10))
	Panel:render()

	AssertEquals(#Bars(Panel), 2, "a bar per hand")
end)

Test("empty hands draw nothing", function()
	local Panel = NewPanel(nil, nil)
	Panel:render()

	AssertEquals(#Bars(Panel), 0, "nothing equipped, nothing to show")
end)

Test("an item with no condition draws nothing", function()
	local Panel = NewPanel(Harness.NewPlainItem())
	Panel:render()

	AssertEquals(#Bars(Panel), 0, "an apple has no condition bar")
end)

Test("the vanilla panel still renders underneath", function()
	local Panel = NewPanel(Harness.NewWeapon(5, 10))
	Panel:render()

	AssertEquals(Panel.VanillaRenders, 1, "wrapping must not replace what vanilla draws")
end)

--// Bar Shape
Test("the fill grows and shrinks with condition", function()
	local Full = NewPanel(Harness.NewWeapon(10, 10))
	local Half = NewPanel(Harness.NewWeapon(5, 10))

	Full:render()
	Half:render()

	AssertNear(Bars(Half)[1].H, Bars(Full)[1].H / 2, 0.5, "half condition, half the box")
end)

Test("a full weapon fills the whole box", function()
	local Panel, Player = NewPanel(Harness.NewWeapon(10, 10))
	Panel:render()

	local Bar = Bars(Panel)[1]
	AssertEquals(Bar.H, Panel.mainHand.height, "a full weapon should fill top to bottom")
	AssertEquals(Bar.W, Panel.mainHand.width, "and the full width")
end)

Test("the fill rises from the bottom", function()
	local Panel = NewPanel(Harness.NewWeapon(5, 10))
	Panel:render()

	local Bar = Bars(Panel)[1]
	local Box = Panel.mainHand
	AssertNear(Bar.Y + Bar.H, Box.y + Box.height, 0.001, "it should sit against the bottom edge")
	AssertTrue(Bar.Y > Box.y, "and not reach the top at half condition")
end)

Test("a nearly broken weapon still shows a sliver", function()
	-- "Nearly gone" has to look different from "gone", or the warning arrives too late.
	local Panel = NewPanel(Harness.NewWeapon(1, 1000))
	Panel:render()

	AssertTrue(#Bars(Panel) == 1, "a fill should still be drawn")
	AssertTrue(Bars(Panel)[1].H >= 1, "and be at least a pixel tall")
end)

Test("the fill stays inside the box it is given", function()
	local Panel = NewPanel(Harness.NewWeapon(10, 10))
	Panel:render()

	local Bar = Bars(Panel)[1]
	local Box = Panel.mainHand

	AssertTrue(Bar.X >= Box.x, "should not run off the left")
	AssertTrue(Bar.X + Bar.W <= Box.x + Box.width, "nor off the right")
	AssertTrue(Bar.Y + Bar.H <= Box.y + Box.height, "nor below the bottom")
end)

--// Colour
Test("colour changes as the weapon wears down", function()
	local Healthy = NewPanel(Harness.NewWeapon(10, 10))
	local Caution = NewPanel(Harness.NewWeapon(4, 10))
	local Danger = NewPanel(Harness.NewWeapon(1, 10))

	Healthy:render()
	Caution:render()
	Danger:render()

	-- Green drains as condition falls, so the three are ordered rather than merely
	-- different. That also keeps them apart for anyone who cannot separate red from green.
	AssertTrue(Bars(Healthy)[1].G > Bars(Caution)[1].G, "healthy should be greener than caution")
	AssertTrue(Bars(Caution)[1].G > Bars(Danger)[1].G, "caution should be greener than danger")
	AssertTrue(Bars(Caution)[1].R > Bars(Healthy)[1].R, "caution should be warmer than healthy")
	AssertTrue(Bars(Danger)[1].R > Bars(Danger)[1].G, "danger should read red")
end)

--// Hotbar
Test("the hotbar draws a bar for each attached item", function()
	local Player = Harness.NewPlayer(0, true)
	local Hotbar = Harness.NewHotbar(Player, { "Back", "Belt" })
	Harness.Fire("OnLoad")

	Hotbar.attachedItems[1] = Harness.NewWeapon(5, 10)
	Hotbar.attachedItems[2] = Harness.NewWeapon(2, 10)
	Hotbar.Drawn = {}
	Hotbar:render()

	local Found = 0
	for _, Draw in ipairs(Hotbar.Drawn) do
		if Draw.Kind == "rect" then Found = Found + 1 end
	end

	AssertTrue(Found >= 2, "one fill per occupied slot, got " .. tostring(Found))
end)

Test("the hotbar is drawn through the one render override", function()
	-- Overriding ISHotbar.render twice is how two mods erase each other. The condition
	-- bars are drawn from the reorder feature's render, not a second wrapper.
	Harness.Fire("OnLoad")
	AssertEquals(ISHotbar.render, ISHotbar.QolcRender, "there should be exactly one override")
end)

--// Options
local function FindOption(Id)
	local Category = PZAPI.ModOptions:getOptions("QoLC")
	if not Category then return nil end

	for _, Entry in ipairs(Category.data) do
		if Entry.id == Id then return Entry end
	end
	return nil
end

Test("the toggle is registered in the shared category", function()
	AssertNotNil(PZAPI.ModOptions:getOptions("QoLC"), "the shared category should exist")
	AssertNotNil(FindOption("ConditionEnabled"), "the tickbox should be registered")
end)

Test("turning it off draws nothing", function()
	FindOption("ConditionEnabled"):setValue(false)

	local Panel = NewPanel(Harness.NewWeapon(5, 10))
	Panel:render()

	AssertEquals(#Bars(Panel), 0, "disabled means nothing is drawn")
end)

Test("it is on by default", function()
	AssertTrue(QolcConditionEnabled(), "should be on unless turned off")
end)

--// Translations
Test("every option label resolves", function()
	local Keys = {
		"UI_options_QoLC_Condition",
		"UI_options_QoLC_Condition_Desc",
		"UI_options_QoLC_Condition_Enabled",
		"UI_options_QoLC_Condition_Enabled_tooltip"
	}

	for _, Key in ipairs(Keys) do
		AssertNotNil(Translations[Key], "missing translation for " .. Key)
	end
end)
