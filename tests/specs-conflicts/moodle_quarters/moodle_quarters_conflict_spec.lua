--// Moodle Quarters Conflict Spec
--// aspctt - 18.08.2026
--// Run by the second pass in run-tests.ps1, with the whole mod loaded again beside a mod
--// list containing the standalone Moodle Quarters.
--//
--// Both do the same job by the same means: take the vanilla moodle panel off UIManager's
--// element list and put their own there. Two of them leaves one panel orphaned and still
--// drawing, which is a second stack sliding around beside the first. Ours stands down
--// before it defines anything, because theirs is the mod a player chose by name.

--// The Mod List
Test("the second pass really is running beside Moodle Quarters", function()
	-- Everything below checks that something did not happen, so each would pass just as
	-- happily against the wrong mod list
	AssertTrue(getActivatedMods():contains("moodle_quarters"), "the pass is set up wrong")
	AssertTrue(getActivatedMods():contains("QoLCompendium"), "we should still be in the list")
end)

--// Standing Down
Test("our panel class is never defined", function()
	-- The file returns before the require, so nothing of it exists at all. That is what
	-- lets the standalone mod define the same global names without a fight.
	AssertNil(MoodleQuartersUI, "our panel class should not have been created")
end)

Test("the vanilla panel keeps the stack", function()
	Harness.NewMoodlePlayer(0)
	local Vanilla = Harness.NewMoodlePanel(0)

	Harness.Fire("OnTick")
	Harness.Fire("OnCreatePlayer")

	AssertNotNil(Harness.UIIndex(Vanilla), "vanilla should still be on the element list")
end)

Test("nothing of ours draws a plate", function()
	Harness.NewMoodlePlayer(0)
	Harness.NewMoodlePanel(0)
	Harness.SetMoodle(MoodleType.HUNGRY, 3)

	Harness.Fire("OnTick")
	Harness.RenderUI()

	AssertEquals(#Harness.FindDraws("MoodleQuarters/"), 0, "no level art from us")
end)

Test("the feature switch is still offered", function()
	-- Standing down is about the panel, not the option. Leaving the box out entirely
	-- would make the feature look missing rather than deferred.
	local Category = PZAPI.ModOptions:getOptions("QoLC")
	local Found = false

	for _, Entry in ipairs(Category.data) do
		if Entry.id == "MoodleQuartersEnabled" then Found = true end
	end

	AssertTrue(Found, "the tick box should still be on the page")
end)
