--// Moodles In Lua Conflict Spec
--// aspctt - 19.08.2026
--// Run by a later pass in run-tests.ps1, with the whole mod loaded again beside a mod
--// list containing Moodles In Lua, workshop 3395171770, mod id moodlesinlua.
--//
--// Reported by a player running both: two moodle stacks overlaying each other, with the
--// info boxes on top of one another. That mod replaces the whole moodle rendering system
--// and already draws a border per level through its texture packs, so it covers the same
--// ground this feature does. Ours stands aside, exactly as it does for the standalone.

--// The Mod List
Test("the pass really is running beside Moodles In Lua", function()
	-- Everything below checks that something did not happen, so each would pass just as
	-- happily against the wrong mod list
	AssertTrue(getActivatedMods():contains("moodlesinlua"), "the pass is set up wrong")
	AssertTrue(getActivatedMods():contains("QoLCompendium"), "we should still be in the list")
end)

--// Standing Down
Test("our panel class is never defined", function()
	AssertNil(MoodleQuartersUI, "our panel class should not have been created")
end)

Test("the vanilla panel keeps the stack", function()
	Harness.NewMoodlePlayer(0)
	local Vanilla = Harness.NewMoodlePanel(0)

	Harness.Fire("OnTick")
	Harness.Fire("OnCreatePlayer")

	-- The reported bug in one assertion. Taking vanilla off the list is what orphans a
	-- panel when another mod has already replaced it, and that orphan is the second stack.
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
	-- Standing down is about the panel, not the option. The player who reported this went
	-- looking for a tick box and did not find one, so it had better still be on the page.
	local Category = PZAPI.ModOptions:getOptions("QoLC")
	local Found = false

	for _, Entry in ipairs(Category.data) do
		if Entry.id == "MoodleQuartersEnabled" then Found = true end
	end

	AssertTrue(Found, "the tick box should still be on the page")
end)
