--// Clean UI Conflict Spec
--// aspctt - 11.08.2026
--// Run by the second pass in run-tests.ps1, with the whole mod loaded again beside a mod
--// list containing CleanUI.
--//
--// Clean UI ships its own media/lua/client/ISUI/ISInventoryPage.lua, replacing the file
--// outright rather than overriding a function in it. The loot window, its title and its
--// weight are all laid out by their code, so the capacity fix has nothing of vanilla's to
--// correct and must not reposition their text.

--// The Mod List
Test("the second pass really is running beside Clean UI", function()
	-- Everything below checks that something did not happen, so each would pass just as
	-- happily against the wrong mod list
	AssertTrue(getActivatedMods():contains("CleanUI"), "the pass is set up wrong")
	AssertTrue(getActivatedMods():contains("QoLCompendium"), "we should still be in the list")
end)

--// Standing Down
Test("the title is left exactly where the window put it", function()
	local Page = Harness.NewLootWindow("Crate", "12.34 / 50")
	Page:prerender()

	-- 266 is what the stub's own prerender computes. Ours would have moved it to 289.
	local Title = Page:Find("Crate")
	AssertNotNil(Title, "the window still draws its title")
	AssertEquals(Title.X, 266, "and nothing of ours has moved it")
end)

Test("a long weight is not corrected either", function()
	-- The overlap is real here, but it is Clean UI's window and their business
	local Page = Harness.NewLootWindow("Crate", "12.34 / 50 (20 / 100)")
	Page:prerender()

	AssertEquals(Page:Find("Crate").X, 266, "untouched")
end)

Test("the title does not move with the weight", function()
	-- The tell. Our fix anchors the title to where the weight actually starts, so with it
	-- installed these two land in different places. Standing down, the window's own fixed
	-- reservation puts both at the same x whatever the label says.
	local Short = Harness.NewLootWindow("Crate", "1 / 2")
	local Long = Harness.NewLootWindow("Crate", "9999.99 / 9999 (999 / 999)")

	Short:prerender()
	Long:prerender()

	AssertEquals(Short:Find("Crate").X, Long:Find("Crate").X,
		"the window reserves a fixed gap, and nothing of ours is adjusting it")
end)

--// Everything Else
Test("features that do not touch the loot window are untouched", function()
	AssertNotNil(QolcXpBoostRatio, "the experience boost display is unrelated")
	AssertEquals(QolcXpBoostRatio(Perks.Carpentry, 1), 4, "and still correct")

	AssertNotNil(QolcConditionFraction, "so is reading an item's condition")
	AssertNotNil(ISHandcraftAction.performRecipe, "and tailoring experience")
end)
