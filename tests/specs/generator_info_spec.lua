--// Generator Info Spec
--// aspctt - 11.08.2026
--// Fuel runs zero to ten and the generator burns totalPowerUsing times the
--// GeneratorFuelConsumption sandbox setting once an in game hour, both read out of
--// IsoGenerator.update in this build. The range comes from GeneratorTileRange and
--// GeneratorVerticalPowerRange, which build 42 made sandbox options.

--// Helpers
local function Window(Generator)
	local Panel = Harness.NewGeneratorWindow(Generator)
	Panel:setVisible(true)
	return Panel
end

-- getPlayer is what the overlay reads to know which floor to draw, so the stub player is
-- the one that has to be standing somewhere
local function Highlights(Generator, PlayerZ)
	Harness.Player:setSquare(Harness.NewGridSquare(100, 100, PlayerZ or 0))

	Harness.ClearHighlights()
	Window(Generator):prerender()
	return Harness.Highlights
end

--// Time Remaining
Test("a full tank under a small load lasts a long time", function()
	-- Ten fuel burning a tenth an hour is a hundred hours, four days and four
	AssertEquals(QolcGeneratorHoursLeft(Harness.NewGenerator(10, 0.1)), 100, "hours left")
end)

Test("the sandbox consumption rate is applied", function()
	SandboxVars.GeneratorFuelConsumption = 2
	AssertEquals(QolcGeneratorHoursLeft(Harness.NewGenerator(10, 0.1)), 50, "twice the burn, half the time")

	SandboxVars.GeneratorFuelConsumption = 0.5
	AssertEquals(QolcGeneratorHoursLeft(Harness.NewGenerator(10, 0.1)), 200, "half the burn, twice the time")
end)

Test("a generator that is off still gets an answer", function()
	-- Reported in game: nothing showed on a stopped generator, which is exactly when the
	-- number is worth having. It burns the same rate the moment it starts.
	AssertEquals(QolcGeneratorHoursLeft(Harness.NewGenerator(10, 0.1, false)), 100, "switched off")
end)

Test("one that has never run falls back to its own base draw", function()
	-- getTotalPowerUsing is only worked out once the game powers the surroundings, so it
	-- reads zero on a generator that has never been switched on
	local Generator = Harness.NewGenerator(10, 0, false)
	AssertEquals(QolcGeneratorHoursLeft(Generator), 500, "ten fuel over a base of 0.02")
end)

Test("the base draw is not multiplied twice", function()
	-- getBasePowerConsumption already has the sandbox rate in it. Applying it again would
	-- halve or double the answer depending on the setting.
	SandboxVars.GeneratorFuelConsumption = 2
	AssertEquals(QolcGeneratorHoursLeft(Harness.NewGenerator(10, 0)), 250, "0.02 times two, once")
end)

Test("an empty tank is zero rather than nothing", function()
	AssertEquals(QolcGeneratorHoursLeft(Harness.NewGenerator(0, 0.1)), 0, "dry")
end)

--// Reading It
Test("days and hours are split out", function()
	AssertEquals(QolcGeneratorDuration(100), getText("IGUI_QoLC_GeneratorDaysHours", "4", "4"),
		"a hundred hours is four days and four")
end)

Test("under a day reads as hours alone", function()
	AssertEquals(QolcGeneratorDuration(5), getText("IGUI_QoLC_GeneratorHours", "5"), "no days part")
end)

Test("part hours are not shown", function()
	AssertEquals(QolcGeneratorDuration(5.9), getText("IGUI_QoLC_GeneratorHours", "5"), "whole hours only")
end)

Test("the wording says whether it is counting down", function()
	-- "Fuel remaining" on a stopped generator would read as though it were draining
	local Running = QolcGeneratorTimeText(Harness.NewGenerator(10, 0.1, true))
	local Stopped = QolcGeneratorTimeText(Harness.NewGenerator(10, 0.1, false))

	AssertContains(Running, "remaining", "running")
	AssertContains(Stopped, "would last", "stopped")
end)

--// The Window
Test("the line is added to the window text", function()
	local Text = ISGeneratorInfoWindow.getRichText(Harness.NewGenerator(10, 0.1), true)

	AssertContains(Text, "Fuel:", "vanilla's own lines must survive")
	AssertContains(Text, "Condition", "all of them")
	AssertContains(Text, QolcGeneratorDuration(100), "and ours is appended")
end)

Test("a generator that is off gets the line too", function()
	-- Reported in game as the line simply not being there. Standing at a stopped generator
	-- deciding whether to fuel it is the moment the number matters most.
	local Text = ISGeneratorInfoWindow.getRichText(Harness.NewGenerator(10, 0.1, false), true)
	AssertContains(Text, "would last", "worded as a projection rather than a countdown")
end)

Test("the short form drawn on the object is left alone", function()
	-- Called with displayStats false, it has no stats block to append to
	local Text = ISGeneratorInfoWindow.getRichText(Harness.NewGenerator(10, 0.1), false)
	AssertEquals(string.find(Text, "Fuel", 1, true), nil, "not that one")
end)

--// The Range Overlay
Test("the radius comes from the sandbox, not a hardcoded twenty", function()
	-- Visible Generator Range hardcodes twenty. Build 42 made it an option from 1 to 100.
	SandboxVars.GeneratorTileRange = 3
	local Small = #Highlights(Harness.NewGenerator(10, 0.1))

	SandboxVars.GeneratorTileRange = 6
	local Large = #Highlights(Harness.NewGenerator(10, 0.1))

	AssertTrue(Large > Small, "a bigger radius has to cover more ground")
	AssertEquals(Small, 29, "a radius of three covers twenty nine tiles")
end)

Test("the area drawn is a circle, not a square", function()
	SandboxVars.GeneratorTileRange = 3
	local Drawn = Highlights(Harness.NewGenerator(10, 0.1))

	-- Seven by seven would be forty nine. The corners are outside the radius.
	AssertTrue(#Drawn < 49, "the corners must be left out")
end)

Test("the vertical reach is the sandbox value, equally up and down", function()
	-- The original allows two floors up and three down. Build 42 uses one option for both.
	SandboxVars.GeneratorTileRange = 2
	SandboxVars.GeneratorVerticalPowerRange = 3

	local Generator = Harness.NewGenerator(10, 0.1, true, 100, 100, 0)

	AssertTrue(#Highlights(Generator, 3) > 0, "three floors up is in reach")
	AssertTrue(#Highlights(Generator, -3) > 0, "and three floors down")
	AssertEquals(#Highlights(Generator, 4), 0, "four up is not")
	AssertEquals(#Highlights(Generator, -4), 0, "nor four down")
end)

Test("standing outside the reach draws nothing rather than failing", function()
	-- The original indexes its floor table by the player's level and crashes when that
	-- level was never filled in
	SandboxVars.GeneratorVerticalPowerRange = 1
	local Generator = Harness.NewGenerator(10, 0.1, true, 100, 100, 0)

	AssertEquals(#Highlights(Generator, 20), 0, "far above, and no error")
end)

Test("the colour says whether it is running", function()
	SandboxVars.GeneratorTileRange = 2

	local On = Highlights(Harness.NewGenerator(10, 0.1, true))
	AssertEquals(On[1].G, 1, "green while running")
	AssertEquals(On[1].R, 0, "and not red")

	local Off = Highlights(Harness.NewGenerator(10, 0.1, false))
	AssertEquals(Off[1].R, 1, "red while off")
end)

Test("outdoor squares are skipped unless the sandbox allows them", function()
	SandboxVars.GeneratorTileRange = 3
	Harness.DefaultSquare = { Outside = true, Solid = true }

	SandboxVars.AllowExteriorGenerator = false
	AssertEquals(#Highlights(Harness.NewGenerator(10, 0.1)), 0, "nothing indoors to power")

	SandboxVars.AllowExteriorGenerator = true
	AssertTrue(#Highlights(Harness.NewGenerator(10, 0.1)) > 0, "allowed outside now")

	Harness.DefaultSquare = { Outside = false, Solid = true }
end)

Test("closing the window stops the overlay", function()
	-- The player has to be standing somewhere first, or this passes because there was
	-- nothing to draw rather than because it stopped
	SandboxVars.GeneratorTileRange = 2
	local Generator = Harness.NewGenerator(10, 0.1)
	AssertTrue(#Highlights(Generator) > 0, "it should be drawing to begin with")

	local Panel = Window(Generator)
	Panel:setVisible(false)

	Harness.ClearHighlights()
	Panel:prerender()
	AssertEquals(#Harness.Highlights, 0, "nothing drawn once hidden")
end)

Test("being taken off the manager stops it too", function()
	-- A window can be removed without being hidden first
	SandboxVars.GeneratorTileRange = 2
	local Generator = Harness.NewGenerator(10, 0.1)
	AssertTrue(#Highlights(Generator) > 0, "it should be drawing to begin with")

	local Panel = Window(Generator)
	Panel:removeFromUIManager()

	Harness.ClearHighlights()
	Panel:prerender()
	AssertEquals(#Harness.Highlights, 0, "nothing drawn once gone")
end)

Test("vanilla still prerenders the window", function()
	SandboxVars.GeneratorTileRange = 2
	Harness.Player:setSquare(Harness.NewGridSquare(100, 100, 0))

	local Panel = Window(Harness.NewGenerator(10, 0.1))
	Panel:prerender()

	AssertEquals(Panel.VanillaPrerenders, 1, "wrapped, not replaced")
end)

Test("a character not yet in the world draws nothing rather than failing", function()
	-- getPlayer can hand back someone with no square during a load
	SandboxVars.GeneratorTileRange = 2
	Harness.Player:setSquare(nil)

	local Panel = Window(Harness.NewGenerator(10, 0.1))
	Harness.ClearHighlights()
	Panel:prerender()

	AssertEquals(#Harness.Highlights, 0, "nothing drawn, and no error")
	AssertEquals(Panel.VanillaPrerenders, 1, "vanilla still runs")
end)

--// Translations
Test("every label resolves", function()
	AssertNotNil(Translations["IGUI_QoLC_GeneratorDaysHours"], "days and hours")
	AssertNotNil(Translations["IGUI_QoLC_GeneratorHours"], "hours alone")
end)
