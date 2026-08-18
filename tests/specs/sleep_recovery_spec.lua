--// Sleep On It Spec
--// aspctt - 18.08.2026

--// Helpers
local function Sleeper(Number, Boredom, Unhappiness)
	local Player = Harness.NewPlayer(Number or 0, true)
	Player.Asleep = true

	Player:getStats():set(CharacterStat.BOREDOM, Boredom or 50)
	Player:getStats():set(CharacterStat.UNHAPPINESS, Unhappiness or 50)

	return Player
end

local function Tick(Count)
	for _ = 1, Count or 1 do Harness.Fire("EveryTenMinutes") end
end

local function Boredom(Player) return Player:getStats():get(CharacterStat.BOREDOM) end
local function Unhappy(Player) return Player:getStats():get(CharacterStat.UNHAPPINESS) end

--// Wiring
Test("it listens on the ten minute tick", function()
	AssertTrue(Harness.HandlerCount("EveryTenMinutes") > 0, "should be on EveryTenMinutes")
end)

Test("it sends no client command", function()
	-- The original notices on the client, sends a command, and has the server change the
	-- stat without ever syncing it back. Changing the local player's own stats is
	-- complete on its own, the way vanilla's petAnimal does it.
	local Player = Sleeper()
	Tick(1)

	AssertEquals(#(Harness.ClientCommands or {}), 0, "no network round trip is needed")
	AssertTrue(Boredom(Player) < 50, "and it still worked")
end)

--// Sleeping
Test("a sleeping character loses boredom", function()
	local Player = Sleeper()
	Tick(1)

	AssertNear(Boredom(Player), 48.5, 0.001, "50 less 1.5")
end)

Test("a sleeping character loses unhappiness", function()
	local Player = Sleeper()
	Tick(1)

	AssertNear(Unhappy(Player), 49.5, 0.001, "50 less 0.5")
end)

Test("a full night clears boredom", function()
	-- Eight hours is forty eight ticks, worth 72 boredom
	local Player = Sleeper(0, 50, 50)
	Tick(48)

	AssertEquals(Boredom(Player), 0, "slept it off")
	AssertNear(Unhappy(Player), 26, 0.001, "50 less 24")
end)

Test("an awake character is left alone", function()
	local Player = Sleeper()
	Player.Asleep = false
	Tick(1)

	AssertNear(Boredom(Player), 50, 0.001, "awake, so nothing")
	AssertNear(Unhappy(Player), 50, 0.001, "neither stat")
end)

Test("it never drops below zero", function()
	local Player = Sleeper(0, 1, 0.2)
	Tick(3)

	AssertEquals(Boredom(Player), 0, "floored, not negative")
	AssertEquals(Unhappy(Player), 0, "same")
end)

--// Split Screen
Test("every local player recovers, not just the first", function()
	-- The original only ever read getPlayer, so a second player slept for nothing
	local One = Sleeper(0)
	local Two = Sleeper(1)
	Tick(1)

	AssertNear(Boredom(One), 48.5, 0.001, "the first player")
	AssertNear(Boredom(Two), 48.5, 0.001, "and the second")
end)

Test("an empty player slot is harmless", function()
	local Player = Sleeper(0)
	Tick(1)

	AssertNear(Boredom(Player), 48.5, 0.001, "the three unused slots should not throw")
end)

--// Options
Test("turning it off changes nothing", function()
	SandboxVars.QoLC.SleepRecoveryEnabled = false

	local Player = Sleeper()
	Tick(1)

	AssertNear(Boredom(Player), 50, 0.001, "off means off")
end)

Test("the rate scales what a night is worth", function()
	SandboxVars.QoLC.SleepRecoveryRate = 200

	local Player = Sleeper()
	Tick(1)

	AssertNear(Boredom(Player), 47, 0.001, "twice the usual 1.5")
end)

Test("a rate of zero is the same as off", function()
	SandboxVars.QoLC.SleepRecoveryRate = 0

	local Player = Sleeper()
	Tick(1)

	AssertNear(Boredom(Player), 50, 0.001, "nothing at all")
end)

Test("a save made before this existed still sleeps", function()
	Harness.ClearSandbox()

	local Player = Sleeper()
	Tick(1)

	AssertNear(Boredom(Player), 48.5, 0.001, "falls back to the shipped defaults")
end)

Test("both settings are on the sandbox page", function()
	AssertNotNil(QOLC_SANDBOX_DEFAULTS["SleepRecoveryEnabled"], "the switch")
	AssertNotNil(QOLC_SANDBOX_DEFAULTS["SleepRecoveryRate"], "the rate")
end)

Test("every label resolves", function()
	local Keys = {
		"Sandbox_QoLC_SleepRecoveryEnabled", "Sandbox_QoLC_SleepRecoveryEnabled_tooltip",
		"Sandbox_QoLC_SleepRecoveryRate", "Sandbox_QoLC_SleepRecoveryRate_tooltip"
	}

	for _, Key in ipairs(Keys) do
		AssertNotNil(Translations[Key], "missing translation for " .. Key)
	end
end)
