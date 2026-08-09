--// Adrenaline Spec
--// aspctt - 10.08.2026

local TICK_MS = 1000
local ABSORB_FLOOR = 0.55

--// Helpers
-- Advances past the tick interval and fires one player update, so a call here is one
-- pass of the mod's logic rather than one frame.
local function Tick(Player)
	Harness.Advance(TICK_MS)
	Harness.Fire("OnPlayerUpdate", Player)
end

local function TickTimes(Player, Count)
	for _ = 1, Count do
		Tick(Player)
	end
end

local function NewPanicked(Fatigue, PanicLevel)
	local Player = Harness.NewPlayer(0, true)
	Player.Stats:set(CharacterStat.FATIGUE, Fatigue)
	Player:SetMoodle(MoodleType.PANIC, PanicLevel)
	return Player
end

local function Fatigue(Player)
	return Player.Stats:get(CharacterStat.FATIGUE)
end

local function Stored(Player)
	return Player.ModData.QolcAdrenalineFatigue or 0
end

--// Wiring
Test("the mod listens for player updates", function()
	AssertTrue(Harness.HandlerCount("OnPlayerUpdate") > 0, "OnPlayerUpdate should have a handler")
end)

Test("the sandbox page declares every value the mod reads", function()
	Harness.ResetSandbox()
	AssertNotNil(SandboxVars.QoLC.AdrenalineEnabled, "AdrenalineEnabled")
	AssertNotNil(SandboxVars.QoLC.AdrenalineBoostSpeed, "AdrenalineBoostSpeed")
	AssertNotNil(SandboxVars.QoLC.AdrenalineCrashSpeed, "AdrenalineCrashSpeed")
	AssertNotNil(SandboxVars.QoLC.AdrenalineCrashPenalty, "AdrenalineCrashPenalty")
end)

--// Absorbing
Test("panic takes fatigue off a tired character", function()
	local Player = NewPanicked(0.8, 3)
	Tick(Player)

	AssertTrue(Fatigue(Player) < 0.8, "fatigue should have dropped, got " .. tostring(Fatigue(Player)))
	AssertTrue(Stored(Player) > 0, "the absorbed fatigue should be stored")
end)

Test("what leaves the character is exactly what is stored", function()
	local Player = NewPanicked(0.8, 3)
	TickTimes(Player, 5)

	AssertNear(Fatigue(Player) + Stored(Player), 0.8, 0.000001,
		"absorbing must move fatigue, never destroy or create it")
end)

Test("a calm character keeps all their fatigue", function()
	local Player = NewPanicked(0.9, 0)
	TickTimes(Player, 10)

	AssertNear(Fatigue(Player), 0.9, 0.000001, "no panic means no adrenaline")
	AssertEquals(Stored(Player), 0, "nothing should be stored")
end)

Test("a rested character is left alone even in full panic", function()
	local Player = NewPanicked(0.3, 4)
	TickTimes(Player, 10)

	AssertNear(Fatigue(Player), 0.3, 0.000001,
		"below the floor there is no Tired debuff to shed, so nothing should happen")
	AssertEquals(Stored(Player), 0, "nothing should be stored")
end)

Test("absorbing starts once fatigue crosses the floor", function()
	local Below = NewPanicked(ABSORB_FLOOR - 0.01, 4)
	local Above = NewPanicked(ABSORB_FLOOR + 0.01, 4)

	Tick(Below)
	Tick(Above)

	AssertEquals(Stored(Below), 0, "just under the floor should absorb nothing")
	AssertTrue(Stored(Above) > 0, "just over the floor should absorb")
end)

Test("higher panic absorbs faster", function()
	local Low = NewPanicked(0.9, 1)
	local High = NewPanicked(0.9, 4)

	Tick(Low)
	Tick(High)

	AssertTrue(Stored(High) > Stored(Low),
		"level 4 should absorb more per tick than level 1")
end)

Test("each panic level caps how much can be held", function()
	-- Sustained panic must not become a replacement for sleeping.
	local Caps = { [1] = 0.05, [2] = 0.10, [3] = 0.15, [4] = 0.20 }

	for Level, Cap in pairs(Caps) do
		local Player = NewPanicked(0.95, Level)
		TickTimes(Player, 200)
		AssertNear(Stored(Player), Cap, 0.000001, "cap at panic level " .. Level)
	end
end)

Test("absorbing never takes more fatigue than the character has", function()
	local Player = NewPanicked(ABSORB_FLOOR + 0.001, 4)
	TickTimes(Player, 200)

	AssertTrue(Fatigue(Player) >= 0, "fatigue must not go negative, got " .. tostring(Fatigue(Player)))
end)

--// Crashing
Test("calming down gives the fatigue back", function()
	local Player = NewPanicked(0.9, 4)
	TickTimes(Player, 200)

	local Peak = Stored(Player)
	AssertTrue(Peak > 0, "should have absorbed something first")

	Player:SetMoodle(MoodleType.PANIC, 0)
	TickTimes(Player, 200)

	AssertEquals(Stored(Player), 0, "the debt should be paid off")
	AssertTrue(Fatigue(Player) > 0.9, "the crash should leave them more tired than they started")
end)

Test("the crash costs more than adrenaline lent", function()
	local Player = NewPanicked(0.7, 4)
	TickTimes(Player, 200)

	local Borrowed = Stored(Player)
	Player:SetMoodle(MoodleType.PANIC, 0)
	TickTimes(Player, 400)

	local Penalty = SandboxVars.QoLC.AdrenalineCrashPenalty
	AssertNear(Fatigue(Player), 0.7 + (Borrowed * (Penalty - 1)), 0.0001,
		"paying back should overshoot by the penalty multiplier")
end)

Test("dropping to a lower panic level releases down to the new cap", function()
	local Player = NewPanicked(0.95, 4)
	TickTimes(Player, 200)
	AssertNear(Stored(Player), 0.20, 0.000001, "should be holding the level 4 cap")

	Player:SetMoodle(MoodleType.PANIC, 1)
	TickTimes(Player, 200)

	AssertNear(Stored(Player), 0.05, 0.01, "should settle at the level 1 cap")
end)

Test("sleeping settles the whole debt at once", function()
	local Player = NewPanicked(0.9, 4)
	TickTimes(Player, 200)
	AssertTrue(Stored(Player) > 0, "should have absorbed something first")

	Player.Asleep = true
	Tick(Player)

	AssertEquals(Stored(Player), 0, "one tick asleep should clear the debt entirely")
end)

Test("fatigue is clamped rather than overflowing", function()
	local Player = NewPanicked(0.95, 4)
	TickTimes(Player, 200)

	Player.Asleep = true
	Tick(Player)

	AssertTrue(Fatigue(Player) <= 1, "the game clamps fatigue to 1, got " .. tostring(Fatigue(Player)))
end)

--// Pacing
Test("nothing happens between ticks", function()
	local Player = NewPanicked(0.9, 4)
	Tick(Player)

	local After = Stored(Player)
	for _ = 1, 50 do
		Harness.Fire("OnPlayerUpdate", Player)
	end

	AssertEquals(Stored(Player), After, "updates inside the interval should be ignored")
end)

Test("the rate does not depend on frame rate", function()
	-- The original counted sixty updates between ticks, so a player at thirty frames a
	-- second got half the adrenaline of one at sixty. Same elapsed time, same result.
	local Smooth = NewPanicked(0.9, 3)
	local Choppy = NewPanicked(0.9, 3)

	for _ = 1, 10 do
		Harness.Advance(100)
		Harness.Fire("OnPlayerUpdate", Smooth)
	end

	Harness.Advance(1000)
	Harness.Fire("OnPlayerUpdate", Choppy)

	AssertNear(Stored(Smooth), Stored(Choppy), 0.000001,
		"one second of play should absorb the same either way")
end)

--// Multiplayer
Test("remote players are left alone", function()
	-- OnPlayerUpdate fires on a client for every player it can see. Touching a remote
	-- player's stats here would fight the server's own copy.
	local Remote = Harness.NewPlayer(1, false)
	Remote.Stats:set(CharacterStat.FATIGUE, 0.9)
	Remote:SetMoodle(MoodleType.PANIC, 4)

	TickTimes(Remote, 10)

	AssertNear(Fatigue(Remote), 0.9, 0.000001, "a remote player's fatigue must not be touched")
	AssertEquals(Stored(Remote), 0, "nothing should be stored against a remote player")
end)

Test("split screen players are paced independently", function()
	local One = NewPanicked(0.9, 3)
	local Two = Harness.NewPlayer(1, true)
	Two.Stats:set(CharacterStat.FATIGUE, 0.9)
	Two:SetMoodle(MoodleType.PANIC, 3)

	-- One tick's worth of time, but both players are due
	Harness.Advance(TICK_MS)
	Harness.Fire("OnPlayerUpdate", One)
	Harness.Fire("OnPlayerUpdate", Two)

	AssertTrue(Stored(One) > 0, "player one should have absorbed")
	AssertNear(Stored(Two), Stored(One), 0.000001,
		"player two shares no clock with player one")
end)

Test("the debt is stored per character, not globally", function()
	local One = NewPanicked(0.9, 4)
	local Two = Harness.NewPlayer(1, true)
	Two.Stats:set(CharacterStat.FATIGUE, 0.9)
	Two:SetMoodle(MoodleType.PANIC, 1)

	Harness.Advance(TICK_MS)
	Harness.Fire("OnPlayerUpdate", One)
	Harness.Fire("OnPlayerUpdate", Two)

	AssertTrue(Stored(One) ~= Stored(Two), "two characters should not share one debt")
end)

--// Sandbox Control
Test("the server can switch the feature off", function()
	Harness.ResetSandbox()
	SandboxVars.QoLC.AdrenalineEnabled = false

	local Player = NewPanicked(0.9, 4)
	TickTimes(Player, 10)

	AssertNear(Fatigue(Player), 0.9, 0.000001, "disabled means untouched")
	AssertEquals(Stored(Player), 0, "nothing should be stored")
end)

Test("boost speed changes how fast fatigue is absorbed", function()
	Harness.ResetSandbox()
	SandboxVars.QoLC.AdrenalineBoostSpeed = 500
	local Fast = NewPanicked(0.9, 1)
	Tick(Fast)

	Harness.ResetSandbox()
	SandboxVars.QoLC.AdrenalineBoostSpeed = 1
	local Slow = NewPanicked(0.9, 1)
	Tick(Slow)

	AssertTrue(Stored(Fast) > Stored(Slow), "a higher boost speed should absorb more per tick")
end)

Test("crash penalty changes how much extra is paid back", function()
	Harness.ResetSandbox()
	SandboxVars.QoLC.AdrenalineCrashPenalty = 2.0

	local Player = NewPanicked(0.7, 4)
	TickTimes(Player, 200)
	local Borrowed = Stored(Player)

	Player:SetMoodle(MoodleType.PANIC, 0)
	TickTimes(Player, 400)

	AssertNear(Fatigue(Player), 0.7 + Borrowed, 0.0001,
		"a penalty of 2.0 should pay back double what was borrowed")
end)

Test("a save with no sandbox values still works", function()
	-- Characters created before this feature existed have nothing stored for it.
	Harness.ClearSandbox()

	local Player = NewPanicked(0.9, 3)
	Tick(Player)

	AssertTrue(Stored(Player) > 0, "should fall back to the declared defaults, not break")
end)
