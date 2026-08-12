--// Fix XP View Spec
--// aspctt - 11.08.2026
--// The numbers come from IsoGameCharacter.XP.AddXP in the installed build: an unboosted
--// skill earns a quarter rate, the first boost is a flat one, the second 1.33 and the
--// third 1.66, except Sprinting's first which is 1.25 and Fitness and Strength which are
--// excluded from the second and third entirely.

--// Helpers
local function Tooltip(Perk, Boost)
	local Bar = Harness.NewSkillBar(Perk, Boost)
	Bar:updateTooltip()
	return Bar
end

local function Creation(Perk, Level)
	local Screen = Harness.NewCreationScreen()
	Screen:drawXpBoostMap(0, { item = { perk = Perk, level = Level } })
	return Screen
end

--// The Ratio
Test("the first boost is four times the unboosted rate", function()
	-- The whole point. Vanilla calls this "+75%", which reads as half again.
	AssertEquals(QolcXpBoostRatio(Perks.Carpentry, 1), 4, "one over a quarter")
end)

Test("the second and third are worth more", function()
	AssertNear(QolcXpBoostRatio(Perks.Carpentry, 2), 5.32, 0.0001, "1.33 over a quarter")
	AssertNear(QolcXpBoostRatio(Perks.Carpentry, 3), 6.64, 0.0001, "1.66 over a quarter")
end)

Test("sprinting's first boost is the best in the game", function()
	-- It multiplies by 1.25 rather than 1, which against the same quarter is five
	AssertEquals(QolcXpBoostRatio(Perks.Sprinting, 1), 5, "sprinting is the exception")
	AssertTrue(QolcXpBoostRatio(Perks.Sprinting, 1) > QolcXpBoostRatio(Perks.Carpentry, 1),
		"and beats every other skill's first boost")
end)

Test("sprinting is ordinary at the second and third", function()
	AssertNear(QolcXpBoostRatio(Perks.Sprinting, 2), 5.32, 0.0001, "no longer special")
	AssertNear(QolcXpBoostRatio(Perks.Sprinting, 3), 6.64, 0.0001, "nor here")
end)

Test("fitness and strength gain nothing past the first boost", function()
	-- isSkillExcludedFromSpeedIncrease returns true for exactly these two, so the second
	-- and third boosts multiply by nothing at all. A trait offering them +125% is worth
	-- precisely what +75% is, which is the thing worth being told.
	for _, Perk in ipairs({ Perks.Fitness, Perks.Strength }) do
		AssertEquals(QolcXpBoostRatio(Perk, 1), 4, "the first boost does apply")
		AssertEquals(QolcXpBoostRatio(Perk, 2), 4, "the second does not")
		AssertEquals(QolcXpBoostRatio(Perk, 3), 4, "nor the third")
	end
end)

Test("no boost is not a boost", function()
	AssertNil(QolcXpBoostRatio(Perks.Carpentry, 0), "zero")
	AssertNil(QolcXpBoostRatio(Perks.Carpentry, nil), "nil")
end)

Test("a boost past the third is treated as the third", function()
	-- The game's own branch is "three or more", so a mod handing out four must not read
	-- as no boost at all
	AssertNear(QolcXpBoostRatio(Perks.Carpentry, 9), 6.64, 0.0001, "clamped to the top rate")
end)

--// The Skills Tooltip
Test("vanilla still builds the tooltip", function()
	local Bar = Tooltip(Perks.Carpentry, 1)
	AssertEquals(Bar.VanillaUpdates, 1, "wrapped, not replaced")
end)

Test("the misleading percentage is gone", function()
	local Bar = Tooltip(Perks.Carpentry, 1)

	AssertEquals(string.find(Bar.message, "75%", 1, true), nil, "no percentage left")
	AssertContains(Bar.message, "x4", "replaced with the real multiple")
end)

Test("each boost level reads correctly", function()
	AssertContains(Tooltip(Perks.Carpentry, 1).message, "x4", "first")
	AssertContains(Tooltip(Perks.Carpentry, 2).message, "x5.32", "second")
	AssertContains(Tooltip(Perks.Carpentry, 3).message, "x6.64", "third")
end)

Test("the rest of the tooltip is left alone", function()
	local Bar = Tooltip(Perks.Carpentry, 1)
	AssertContains(Bar.message, "level 1", "vanilla's own lines must survive")
end)

Test("a skill with no boost is untouched", function()
	local Bar = Tooltip(Perks.Carpentry, 0)

	AssertEquals(string.find(Bar.message, "XP Boost", 1, true), nil, "vanilla adds no line")
	AssertEquals(string.find(Bar.message, "x", 1, true), nil, "and neither do we")
end)

Test("fitness reads as four at every level in the tooltip", function()
	-- Vanilla's tooltip has no exclusion of its own, so it would show +125% here
	AssertContains(Tooltip(Perks.Fitness, 3).message, "x4", "not x6.64")
	AssertEquals(string.find(Tooltip(Perks.Fitness, 3).message, "125%", 1, true), nil, "no percentage")
end)

Test("nothing global is replaced", function()
	-- The original installed its own function over getText for the duration of the
	-- tooltip and lost the interface when anything inside it threw
	local Before = getText
	Tooltip(Perks.Carpentry, 2)
	AssertEquals(getText, Before, "getText must be exactly what it was")
end)

--// The Character Creation Screen
Test("the creation screen shows the multiple", function()
	AssertEquals(Creation(Perks.Carpentry, 1).Drawn[1], "x 4", "first boost")
	AssertEquals(Creation(Perks.Carpentry, 2).Drawn[1], "x 5.32", "second")
	AssertEquals(Creation(Perks.Carpentry, 3).Drawn[1], "x 6.64", "third")
end)

Test("sprinting is called out there too", function()
	AssertEquals(Creation(Perks.Sprinting, 1).Drawn[1], "x 5", "sprinting's first boost")
end)

Test("vanilla still draws the row", function()
	local Screen = Creation(Perks.Carpentry, 1)
	AssertEquals(Screen.VanillaDraws, 1, "wrapped, not replaced")
end)

Test("vanilla's own skipping of fitness and strength is kept", function()
	AssertEquals(#Creation(Perks.Fitness, 3).Drawn, 0, "vanilla draws nothing here")
	AssertEquals(#Creation(Perks.Strength, 3).Drawn, 0, "nor here")
end)

Test("the text override is not left behind", function()
	-- Left in place it would stack on every row drawn
	local Screen = Harness.NewCreationScreen()
	local Before = Screen.drawTextRight

	Screen:drawXpBoostMap(0, { item = { perk = Perks.Carpentry, level = 1 } })
	AssertEquals(Screen.drawTextRight, Before, "whatever was there must be put back")

	Screen:drawXpBoostMap(0, { item = { perk = Perks.Carpentry, level = 1 } })
	AssertEquals(Screen.Drawn[2], "x 4", "and a second row must read the same")
end)

Test("a row with no perk is passed straight through", function()
	local Screen = Harness.NewCreationScreen()
	Screen:drawXpBoostMap(0, { item = { level = 1 } })

	AssertEquals(Screen.VanillaDraws, 1, "vanilla still runs")
	AssertEquals(Screen.Drawn[1], "+ 75%", "and its own text stands")
end)

--// Translations
Test("every label resolves", function()
	AssertNotNil(Translations["IGUI_QoLC_XpBoost"], "the tooltip line")
	AssertNotNil(Translations["IGUI_QoLC_XpBoostShort"], "the creation screen")
end)
