--// Weapon Condition Indicator Spec
--// aspctt - 10.08.2026

--// Helpers
-- One coloured fill per item. The hand slots are round, so those are a disc clipped to
-- the filled band rather than a rectangle; the clip is what carries the shape, so that
-- is what the geometry assertions read.
local function Bars(Panel)
	local Found = {}
	for _, Draw in ipairs(Panel.Drawn) do
		if Draw.R and Draw.R > 0.1 then
			local Shape = Draw.Stencil or Draw
			table.insert(Found, {
				X = Shape.X, Y = Shape.Y, W = Shape.W, H = Shape.H,
				R = Draw.R, G = Draw.G, B = Draw.B,
				Kind = Draw.Kind, Texture = Draw.Texture
			})
		end
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

Test("the vanilla panel still renders", function()
	local Panel = NewPanel(Harness.NewWeapon(5, 10))
	Panel:render()

	AssertEquals(Panel.VanillaRenders, 1, "wrapping must not replace what vanilla draws")
end)

Test("the fill is drawn before the icon, not over it", function()
	-- Vanilla draws the item icon in this same call. Painting after it washes colour
	-- across the icon; painting first puts the colour behind, where it belongs.
	local Panel = NewPanel(Harness.NewWeapon(5, 10))
	Panel.RenderOrder = {}

	local Vanilla = ISEquippedItem.render
	Panel:render()

	AssertTrue(#Panel.Drawn > 0, "the fill should have been drawn")
	AssertEquals(Panel.DrawnBeforeVanilla, #Panel.Drawn,
		"every fill must land before the vanilla render runs")
end)

Test("the hand slots are filled as a disc, not a rectangle", function()
	-- The equipped hand slots are circles. A rectangle spills out at the corners, which
	-- is what it looked like in game.
	local Panel = NewPanel(Harness.NewWeapon(5, 10))
	Panel:render()

	local Fill = Bars(Panel)[1]
	AssertEquals(Fill.Kind, "texture", "a round slot should be filled with the disc")
	AssertNotNil(Fill.Texture, "and that disc needs a texture")
	AssertContains(Fill.Texture.Path, "qolc_slot_disc", "specifically the slot disc")
end)

Test("the disc is clipped to the filled band", function()
	-- Without the clip the whole disc lights up regardless of condition.
	local Half = NewPanel(Harness.NewWeapon(5, 10))
	local Full = NewPanel(Harness.NewWeapon(10, 10))

	Half:render()
	Full:render()

	AssertNear(Bars(Half)[1].H, Bars(Full)[1].H / 2, 0.5, "half condition, half the disc")
end)

--// Bar Shape
Test("the fill grows and shrinks with condition", function()
	local Full = NewPanel(Harness.NewWeapon(10, 10))
	local Half = NewPanel(Harness.NewWeapon(5, 10))

	Full:render()
	Half:render()

	AssertNear(Bars(Half)[1].H, Bars(Full)[1].H / 2, 0.5, "half condition, half the box")
end)

Test("a full weapon fills the whole disc", function()
	local Panel = NewPanel(Harness.NewWeapon(10, 10))
	Panel:render()

	local Bar = Bars(Panel)[1]
	AssertEquals(Bar.W, Bar.H, "the fill should be as wide as it is tall")
end)

Test("the fill rises from the bottom of the disc", function()
	local Panel = NewPanel(Harness.NewWeapon(5, 10))
	Panel:render()

	local Bar = Bars(Panel)[1]
	local Full = NewPanel(Harness.NewWeapon(10, 10))
	Full:render()
	local Disc = Bars(Full)[1]

	AssertNear(Bar.Y + Bar.H, Disc.Y + Disc.H, 0.001, "it should sit on the bottom of the disc")
	AssertTrue(Bar.Y > Disc.Y, "and not reach the top at half condition")
end)

Test("the off hand fill is a circle, not an ellipse", function()
	-- The off hand box is three quarters as tall as it is wide. Filling the box would
	-- squash the disc, which is what it looked like in game.
	--
	-- The texture itself is checked here, not the clip. Clipping a stretched disc to a
	-- round band still draws an ellipse, and reading only the clip would miss it.
	local Panel = NewPanel(Harness.NewWeapon(10, 10), Harness.NewWeapon(10, 10))
	Panel:render()

	AssertTrue(Panel.offHand.width ~= Panel.offHand.height, "the box itself is not square")

	local Found = 0
	for _, Draw in ipairs(Panel.Drawn) do
		if Draw.Kind == "texture" then
			Found = Found + 1
			AssertNear(Draw.W, Draw.H, 0.001,
				"the disc drawn for fill " .. Found .. " should be square, not squashed")
			AssertNotNil(Draw.Stencil, "and clipped to how much is filled")
			AssertNear(Draw.X, Draw.Stencil.X, 0.001, "the clip should sit on the disc")
			AssertNear(Draw.W, Draw.Stencil.W, 0.001, "and be as wide as it")
		end
	end

	AssertEquals(Found, 2, "one disc per hand")
end)

Test("the fill sits inside the slot's own circle", function()
	-- Vanilla draws the circle inset from the edge of its box, so filling the whole box
	-- spills a pixel or two past the ring.
	local Panel = NewPanel(Harness.NewWeapon(10, 10), Harness.NewWeapon(10, 10))
	Panel:render()

	local Boxes = { Panel.mainHand, Panel.offHand }
	for Index, Bar in ipairs(Bars(Panel)) do
		local Box = Boxes[Index]
		local Smallest = math.min(Box.width, Box.height)

		AssertTrue(Bar.W < Smallest, "fill " .. Index .. " should be inset from the box")
		AssertTrue(Bar.X > Box.x, "and centred, not flush left")
		AssertTrue(Bar.X + Bar.W < Box.x + Box.width, "nor flush right")
	end
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

--// Conflicting Mods
-- Clean HotBar draws its own condition on the same two hand slots and chains
-- ISEquippedItem.render rather than replacing it, so ours keeps running underneath and
-- the player gets two indicators on one slot.
Test("nothing is drawn when Clean HotBar is installed", function()
	table.insert(Harness.ActivatedMods, "CleanHotBar")

	local Panel = NewPanel(Harness.NewWeapon(5, 10), Harness.NewWeapon(8, 10))
	Panel:render()

	AssertEquals(#Bars(Panel), 0, "Clean HotBar already draws this, ours must stand down")
	AssertEquals(Panel.VanillaRenders, 1, "and vanilla must still draw the panel itself")
end)

Test("the hotbar half stands down too", function()
	-- One gate covers both halves, because the hotbar draws through the same call
	table.insert(Harness.ActivatedMods, "CleanHotBar")

	local Panel = Harness.NewEquippedItemPanel(Harness.NewPlayer(0, true))
	Panel.Drawn = {}

	AssertFalse(QolcDrawCondition(Panel, 0, 0, 60, 60, Harness.NewWeapon(5, 10)),
		"the shared draw call is what both halves go through")
	AssertEquals(#Panel.Drawn, 0, "nothing reaches the screen")
end)

Test("the conflict beats the tick box rather than the other way round", function()
	-- Otherwise a player with both mods sees two bars and no way to tell which tick box
	-- belongs to which
	table.insert(Harness.ActivatedMods, "CleanHotBar")
	FindOption("ConditionEnabled"):setValue(true)

	AssertFalse(QolcConditionEnabled(), "on is not on when another mod owns the slot")
end)

Test("an unrelated mod changes nothing", function()
	-- NeatUI Framework is additive only: it defines its own NeatTool and NI* globals,
	-- registers no events, and only fills in ISUIElement methods that do not already
	-- exist. Nothing it does touches what this draws.
	table.insert(Harness.ActivatedMods, "NeatUI_Framework")

	local Panel = NewPanel(Harness.NewWeapon(5, 10))
	Panel:render()

	AssertEquals(#Bars(Panel), 1, "a mod we do not conflict with must not disable us")
end)

Test("the mod list is read once, not every frame", function()
	-- Asked for every drawn slot on every frame otherwise, and the list cannot change
	-- without restarting the game
	local Calls = 0
	local Vanilla = getActivatedMods
	getActivatedMods = function() Calls = Calls + 1 return Vanilla() end

	QolcConditionEnabled()
	QolcConditionEnabled()
	QolcConditionEnabled()

	getActivatedMods = Vanilla
	AssertTrue(Calls <= 1, "should be answered once and remembered, got " .. tostring(Calls))
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
