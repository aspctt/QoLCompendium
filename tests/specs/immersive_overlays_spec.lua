--// Immersive Overlays Spec
--// aspctt - 09.08.2026

local OPTIONS_ID = "QoLC"

--// Helpers
local function Boot()
	Harness.Fire("OnGameBoot")
end

-- Looked up by id rather than by index, so other integrated mods can register their
-- own categories without disturbing this spec.
local function GetCategory()
	local ModOptions = PZAPI.ModOptions:getOptions(OPTIONS_ID)
	AssertNotNil(ModOptions, "the mod did not register options under " .. OPTIONS_ID)
	return ModOptions
end

local function GetOption(Id)
	local Option = GetCategory():getOption(Id)
	AssertNotNil(Option, "no option registered with id " .. Id)
	return Option
end

-- Pain uses a level driven rate and loses its first frame to a clamp, so after
-- FrameCount frames the blend has taken FrameCount - 1 steps.
local function ExpectedPainBlend(Level, FrameCount)
	return (FrameCount - 1) * (Level * 2 / 100)
end

-- Every other overlay steps by a fixed rate from the very first frame.
local function ExpectedBlend(Rate, FrameCount)
	return FrameCount * Rate
end

local function ExpectedAlpha(Blend, Strength)
	return (Blend / 4) * (Strength / 100)
end

--// Wiring
Test("registers handlers for boot, resolution change and render", function()
	AssertEquals(Harness.HandlerCount("OnGameBoot"), 1, "OnGameBoot handler count")
	AssertEquals(Harness.HandlerCount("OnPreUIDraw"), 1, "OnPreUIDraw handler count")
	AssertEquals(Harness.HandlerCount("OnResolutionChange"), 1, "OnResolutionChange handler count")
end)

Test("every MoodleType the mod uses exists in this build", function()
	AssertNotNil(MoodleType.PAIN, "MoodleType.PAIN")
	AssertNotNil(MoodleType.INJURED, "MoodleType.INJURED")
	AssertNotNil(MoodleType.TIRED, "MoodleType.TIRED")
	AssertNotNil(MoodleType.HYPERTHERMIA, "MoodleType.HYPERTHERMIA")
	AssertNotNil(MoodleType.HYPOTHERMIA, "MoodleType.HYPOTHERMIA")
	AssertNil(MoodleType.Pain, "build 41 name MoodleType.Pain should not resolve")
end)

Test("renders without error at every moodle level", function()
	Boot()
	for Level = 0, 4 do
		Harness.SetMoodle(MoodleType.PAIN, Level)
		Harness.SetMoodle(MoodleType.INJURED, Level)
		Harness.SetMoodle(MoodleType.TIRED, Level)
		Harness.SetMoodle(MoodleType.HYPERTHERMIA, Level)
		Harness.SetMoodle(MoodleType.HYPOTHERMIA, Level)
		Harness.FireFrames(5)
	end
end)

Test("draws nothing when the player has not spawned", function()
	Boot()
	Harness.HasPlayer = false
	Harness.SetMoodle(MoodleType.PAIN, 4)
	Harness.FireFrames(20)
	AssertEquals(#Harness.Draws, 0, "draw count with no player")
end)

--// Blending
Test("draws nothing while every moodle is zero", function()
	Boot()
	Harness.FireFrames(30)
	AssertEquals(#Harness.Draws, 0, "draw count with no active moodles")
end)

Test("pain overlay grows while pain is sustained", function()
	Boot()
	Harness.SetMoodle(MoodleType.PAIN, 4)

	Harness.FireFrames(20)
	local Early = Harness.FindDraw("qolc_pain")
	AssertNotNil(Early, "pain overlay was not drawn after 20 frames")

	Harness.FireFrames(10)
	local Later = Harness.FindDraw("qolc_pain")
	AssertTrue(Later.Alpha > Early.Alpha, "pain alpha should keep rising")
end)

Test("pain overlay fades out once pain is gone", function()
	Boot()
	Harness.SetMoodle(MoodleType.PAIN, 4)
	Harness.FireFrames(30)
	AssertNotNil(Harness.FindDraw("qolc_pain"), "pain overlay should be showing while in pain")

	Harness.SetMoodle(MoodleType.PAIN, 0)

	-- It should ease out rather than cut, so it is still on screen shortly after
	Harness.ClearDraws()
	Harness.FireFrames(10)
	local Early = Harness.FindDraw("qolc_pain")
	AssertNotNil(Early, "pain overlay should still be fading, not cut instantly")

	Harness.ClearDraws()
	Harness.FireFrames(10)
	local Later = Harness.FindDraw("qolc_pain")
	AssertNotNil(Later, "pain overlay should still be fading")
	AssertTrue(Later.Alpha < Early.Alpha, "pain alpha should be falling while fading out")

	-- and gone once the fade has had time to finish
	Harness.FireFrames(300)
	Harness.ClearDraws()
	Harness.FireFrames(1)
	AssertNil(Harness.FindDraw("qolc_pain"), "pain overlay should have faded out completely")
end)

Test("pain fades out at the fixed rate", function()
	Boot()
	Harness.SetMoodle(MoodleType.PAIN, 4)
	Harness.FireFrames(30)
	Harness.ClearDraws()
	Harness.FireFrames(1)

	local Before = Harness.FindDraw("qolc_pain")
	AssertNotNil(Before, "pain overlay was not drawn")

	Harness.SetMoodle(MoodleType.PAIN, 0)
	Harness.ClearDraws()
	Harness.FireFrames(1)

	local After = Harness.FindDraw("qolc_pain")
	AssertNotNil(After, "pain overlay should still be fading")
	AssertNear(Before.Alpha - After.Alpha, ExpectedAlpha(0.02, 100), 0.0001, "one frame of fade")
end)

Test("pain alpha follows blend, level and strength", function()
	Boot()
	Harness.SetMoodle(MoodleType.PAIN, 3)
	Harness.FireFrames(20)

	local Draw = Harness.FindDraw("qolc_pain")
	AssertNotNil(Draw, "pain overlay was not drawn")
	AssertNear(Draw.Alpha, ExpectedAlpha(ExpectedPainBlend(3, 20), 100), 0.0001, "pain alpha")
end)

Test("tired alpha honours its fifty percent default", function()
	Boot()
	Harness.SetMoodle(MoodleType.TIRED, 4)
	Harness.FireFrames(20)

	local Draw = Harness.FindDraw("qolc_tired")
	AssertNotNil(Draw, "tired overlay was not drawn")
	AssertNear(Draw.Alpha, ExpectedAlpha(ExpectedBlend(0.01, 20), 50), 0.0001, "tired alpha at default strength")
end)

Test("doubling strength doubles alpha", function()
	GetOption("TiredStrength"):setValue(100)
	Boot()
	Harness.SetMoodle(MoodleType.TIRED, 4)
	Harness.FireFrames(20)

	local Draw = Harness.FindDraw("qolc_tired")
	AssertNotNil(Draw, "tired overlay was not drawn")
	AssertNear(Draw.Alpha, ExpectedAlpha(ExpectedBlend(0.01, 20), 100), 0.0001, "tired alpha at full strength")
end)

Test("alpha never leaves the zero to one range", function()
	Boot()
	Harness.SetMoodle(MoodleType.PAIN, 4)
	Harness.SetMoodle(MoodleType.INJURED, 4)
	Harness.SetMoodle(MoodleType.TIRED, 4)
	Harness.SetMoodle(MoodleType.HYPERTHERMIA, 4)
	Harness.SetMoodle(MoodleType.HYPOTHERMIA, 4)
	Harness.FireFrames(400)

	local Highest = 0
	for _, Draw in ipairs(Harness.Draws) do
		AssertTrue(Draw.Alpha > 0, "alpha should never be drawn at or below zero")
		if Draw.Alpha > Highest then Highest = Draw.Alpha end
	end
	-- The blend can overshoot its target by a single step before reversing,
	-- so the ceiling sits fractionally above one rather than exactly at it.
	AssertTrue(Highest <= 1.02, "peak alpha stayed within bounds, saw " .. tostring(Highest))
end)

--// Options
Test("options register one category with the expected ids", function()
	AssertEquals(GetCategory().modOptionsID, OPTIONS_ID, "category id")

	local Expected = {
		"OverlaysEnabled",
		"PainStrength", "DamageStrength", "TiredStrength",
		"HyperthermiaStrength", "HypothermiaStrength"
	}
	for _, Id in ipairs(Expected) do
		GetOption(Id)
	end
end)

Test("tired strength defaults to fifty and the rest to full", function()
	AssertEquals(GetOption("TiredStrength"):getValue(), 50, "tired strength default")
	AssertEquals(GetOption("PainStrength"):getValue(), 100, "pain strength default")
	AssertEquals(GetOption("DamageStrength"):getValue(), 100, "damage strength default")
	AssertEquals(GetOption("HyperthermiaStrength"):getValue(), 100, "hyperthermia strength default")
	AssertEquals(GetOption("HypothermiaStrength"):getValue(), 100, "hypothermia strength default")
end)

Test("overlays are enabled by default", function()
	AssertEquals(GetOption("OverlaysEnabled"):getValue(), true, "overlays enabled default")
end)

Test("there is exactly one tickbox, not one per overlay", function()
	local Boxes = 0
	for _, Option in ipairs(GetCategory().data) do
		if Option.type == "tickbox" and Option.id and string.find(Option.id, "Overlays") then
			Boxes = Boxes + 1
		end
	end
	AssertEquals(Boxes, 1, "one toggle covers the whole feature")
end)

Test("the toggle suppresses every overlay at once", function()
	GetOption("OverlaysEnabled"):setValue(false)
	Boot()
	Harness.SetMoodle(MoodleType.PAIN, 4)
	Harness.SetMoodle(MoodleType.TIRED, 4)
	Harness.SetMoodle(MoodleType.INJURED, 4)
	Harness.FireFrames(30)

	AssertEquals(#Harness.Draws, 0, "nothing should draw while overlays are off")
end)

Test("a single strength still works on its own", function()
	GetOption("PainStrength"):setValue(0)
	Boot()
	Harness.SetMoodle(MoodleType.PAIN, 4)
	Harness.SetMoodle(MoodleType.TIRED, 4)
	Harness.FireFrames(30)

	AssertNil(Harness.FindDraw("qolc_pain"), "pain is silenced by its own slider")
	AssertNotNil(Harness.FindDraw("qolc_tired"), "tired is unaffected")
end)

Test("zero strength suppresses an overlay", function()
	GetOption("PainStrength"):setValue(0)
	Boot()
	Harness.SetMoodle(MoodleType.PAIN, 4)
	Harness.FireFrames(30)

	AssertNil(Harness.FindDraw("qolc_pain"), "pain overlay should be suppressed at zero strength")
end)

Test("every option label and tooltip resolves to a translation", function()
	AssertNotNil(Translations, "translations were not loaded")
	local Category = GetCategory()
	AssertNotNil(Translations[Category.name], "category name has no translation: " .. tostring(Category.name))

	for _, Option in ipairs(Category.data) do
		if Option.name then
			AssertNotNil(Translations[Option.name], "option label has no translation: " .. tostring(Option.name))
		end
		if Option.tooltip then
			AssertNotNil(Translations[Option.tooltip], "tooltip has no translation: " .. tostring(Option.tooltip))
		end
	end
end)

--// Screen
Test("screen size is taken from the core on boot", function()
	Harness.SetScreenSize(1280, 720)
	Boot()
	Harness.SetMoodle(MoodleType.PAIN, 4)
	Harness.FireFrames(20)

	local Draw = Harness.FindDraw("qolc_pain")
	AssertNotNil(Draw, "pain overlay was not drawn")
	AssertEquals(Draw.Width, 1280, "overlay width")
	AssertEquals(Draw.Height, 720, "overlay height")
end)

Test("resolution change resizes the overlay", function()
	Boot()
	Harness.Fire("OnResolutionChange", 1920, 1080, 800, 600)
	Harness.SetMoodle(MoodleType.PAIN, 4)
	Harness.FireFrames(20)

	local Draw = Harness.FindDraw("qolc_pain")
	AssertNotNil(Draw, "pain overlay was not drawn")
	AssertEquals(Draw.Width, 800, "overlay width after resolution change")
	AssertEquals(Draw.Height, 600, "overlay height after resolution change")
end)

--// Layering
Test("overlays draw bottom to top in the documented order", function()
	Boot()
	Harness.SetMoodle(MoodleType.PAIN, 4)
	Harness.SetMoodle(MoodleType.INJURED, 4)
	Harness.SetMoodle(MoodleType.TIRED, 4)
	Harness.SetMoodle(MoodleType.HYPERTHERMIA, 4)
	Harness.SetMoodle(MoodleType.HYPOTHERMIA, 4)
	Harness.FireFrames(30)

	Harness.ClearDraws()
	Harness.FireFrames(1)

	local Order = Harness.DrawOrder()
	AssertEquals(#Order, 5, "all five overlays should draw")
	AssertContains(Order[1], "qolc_tired", "first overlay")
	AssertContains(Order[2], "qolc_hyperthermia", "second overlay")
	AssertContains(Order[3], "qolc_hypothermia", "third overlay")
	AssertContains(Order[4], "qolc_damage", "fourth overlay")
	AssertContains(Order[5], "qolc_pain", "fifth overlay")
end)
