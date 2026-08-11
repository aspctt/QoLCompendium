--// Clean HotBar Conflict Spec
--// aspctt - 11.08.2026
--// Run by the second pass in run-tests.ps1, with the whole mod loaded again beside a mod
--// list containing CleanHotBar. That is the only way to reach these: the guards run at
--// file scope and have already decided by the time a spec could set anything.
--//
--// Clean HotBar replaces ISHotbar.render outright and chains ISEquippedItem.render, and
--// ships its own slot reordering. The compendium stands down from both rather than
--// leaving the player with two sets of buttons and two indicators on one slot.

--// The Mod List
Test("the second pass really is running beside Clean HotBar", function()
	-- Everything below is a check that something did not happen, so each one would pass
	-- just as happily against the wrong mod list. This is what makes them mean anything.
	AssertTrue(getActivatedMods():contains("CleanHotBar"), "the pass is set up wrong")
	AssertTrue(getActivatedMods():contains("QoLCompendium"), "we should still be in the list")
end)

--// Reordering
Test("no hotbar reordering is installed", function()
	-- Vanilla ISHotbar has no mouse down or mouse move at all, so these existing is our
	-- reordering and nothing else
	AssertNil(ISHotbar.onMouseDown, "our drag start must not be installed")
	AssertNil(ISHotbar.onMouseMove, "our drag tracking must not be installed")
	AssertNil(ISHotbar.onMouseUpOutside, "our drag cancel must not be installed")
end)

Test("the hotbar render is left entirely alone", function()
	Harness.Fire("OnLoad")

	AssertNil(ISHotbar.QolcRender, "our render must not exist")
	AssertNil(ISHotbar.QolcVanillaRender, "and nothing of vanilla's should have been captured")
end)

Test("nothing of ours reorders slots", function()
	AssertNil(QolcHotbarApplyOrder, "the ordering pass must not be defined at all")
end)

Test("the hotbar is not widened for buttons we do not draw", function()
	-- Our setSizeAndPosition adds room at the right hand end for the lock and mode
	-- buttons. Left installed it would leave a gap beside Clean HotBar's own controls.
	local Hotbar = Harness.NewHotbar(Harness.NewPlayer(0, true), { "Back", "Belt" })
	local Before = Hotbar:getWidth()

	Hotbar:setSizeAndPosition()
	AssertEquals(Hotbar:getWidth(), Before, "no width should be added for absent buttons")
end)

--// Condition
Test("no condition is drawn on the hands", function()
	local Player = Harness.NewPlayer(0, true)
	Player.PrimaryHand = Harness.NewWeapon(5, 10)
	Player.SecondaryHand = Harness.NewWeapon(8, 10)

	local Panel = Harness.NewEquippedItemPanel(Player)
	Panel.Drawn = {}
	Panel:render()

	local Fills = 0
	for _, Draw in ipairs(Panel.Drawn) do
		if Draw.R and Draw.R > 0.1 then Fills = Fills + 1 end
	end

	AssertEquals(Fills, 0, "Clean HotBar draws its own, ours would be the second")
	AssertEquals(Panel.VanillaRenders, 1, "the panel itself must still be drawn")
end)

Test("the condition draw call refuses outright", function()
	local Panel = Harness.NewEquippedItemPanel(Harness.NewPlayer(0, true))
	Panel.Drawn = {}

	AssertFalse(QolcDrawCondition(Panel, 0, 0, 60, 60, Harness.NewWeapon(5, 10)), "should refuse")
	AssertFalse(QolcConditionEnabled(), "and report itself as off")
end)

--// Everything Else
Test("features that do not touch the hotbar are untouched", function()
	-- Standing down from the hotbar must not take the rest of the compendium with it
	AssertNotNil(QolcConditionFraction, "reading condition is still useful elsewhere")
	AssertNotNil(ISToolTipInv.render, "the fabric tooltip is unrelated")
	AssertNotNil(ISHandcraftAction.performRecipe, "so is tailoring experience")

	local Player = Harness.NewPlayer(0, true)
	local Data = Harness.NewCraftRecipeData(nil, Harness.NewGarment("Leather"), nil)
	local Action = Harness.NewHandcraftAction(Player, Harness.NewCraftRecipe("RipDenimClothing"), Data)

	Harness.ClearXp()
	Action:performRecipe()
	AssertNear(Harness.Xp[Perks.Tailoring], 3.5, 0.0001, "tailoring still pays out")
end)
