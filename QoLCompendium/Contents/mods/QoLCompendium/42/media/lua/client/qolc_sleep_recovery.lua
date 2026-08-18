--// Sleep On It
--// Sleep On It, Workshop 2673713236, by Stultusaur - Original idea
--// aspctt - 18.08.2026
--// Sleeping wears off boredom and unhappiness, the way a night's sleep does. The base
--// game freezes both instead: BodyDamage.UpdateBoredom returns on its second line when
--// the character is asleep, so neither rises nor falls until morning.
--//
--// Rewritten rather than ported, and the rewrite is mostly deletion.
--//
--// The original is two files and a network protocol. A client notices it is asleep, sends
--// a client command, and the server changes the stat. That is the wrong way round. Vanilla
--// changes a player's stats wherever the code happens to be running and only sends
--// SyncPlayerStats when it is the server doing it, which IsoPlayer.petAnimal shows plainly:
--//
--//   stats.remove(CharacterStat.BOREDOM, ...)
--//   if (GameServer.server) { send SyncPlayerStats ... }
--//
--// So a client changing its own player's stats is complete on its own, while the original's
--// server side handler changes the server's copy and never syncs it back. Doing it here
--// needs no command, no handler and no packet, and behaves the same in both modes.
--//
--// It also covers every local player rather than only the first, so the second player in
--// a split screen game wakes up in the same mood as the first.

--// Tuning
-- Per ten in game minutes, matching the original. An eight hour night is worth 72 boredom
-- and 24 unhappiness, so a full night clears boredom and takes a good bite out of the rest.
local BOREDOM_PER_TICK = 1.5
local UNHAPPINESS_PER_TICK = 0.5

local DEFAULT_RATE = 100
local MAX_PLAYERS = 4

--// Functions
local function GetSandbox(Name, Default)
	local Vars = SandboxVars and SandboxVars.QoLC
	local Value = Vars and Vars[Name]

	if Value ~= nil then return Value end
	return Default
end

local function Enabled()
	return GetSandbox("SleepRecoveryEnabled", true) and true or false
end

local function Rate()
	local Percent = tonumber(GetSandbox("SleepRecoveryRate", DEFAULT_RATE)) or DEFAULT_RATE
	return Percent / 100
end

-- Stats.remove clamps at the stat's own floor, so there is no need to check first. The
-- guard is only here to skip the work entirely on a character who has neither.
local function Recover(Player, Amount)
	local Stats = Player:getStats()
	if not Stats then return end

	if Stats:get(CharacterStat.BOREDOM) > 0 then
		Stats:remove(CharacterStat.BOREDOM, BOREDOM_PER_TICK * Amount)
	end

	if Stats:get(CharacterStat.UNHAPPINESS) > 0 then
		Stats:remove(CharacterStat.UNHAPPINESS, UNHAPPINESS_PER_TICK * Amount)
	end
end

--// Connections
local function OnEveryTenMinutes()
	if not Enabled() then return end

	local Amount = Rate()
	if Amount <= 0 then return end

	-- Every local player, not just the first. getSpecificPlayer returns nil for a slot
	-- nobody is using, which is the ordinary case for all but one of these.
	for Number = 0, MAX_PLAYERS - 1 do
		local Player = getSpecificPlayer(Number)
		if Player and Player:isAsleep() then Recover(Player, Amount) end
	end
end

Events.EveryTenMinutes.Add(OnEveryTenMinutes)
