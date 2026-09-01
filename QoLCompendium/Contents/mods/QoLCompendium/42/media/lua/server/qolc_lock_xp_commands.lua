--// Lock Picking Experience Commands
--// Lockpicking. Just. Lockpicking., Workshop 2056238799
--// aspctt - 31.08.2026
--// Pays a client for a lock it picked.
--//
--// See shared/qolc_lock_xp.lua for why this file has to exist: addXp does nothing at all on a
--// client, so experience a client awards itself is undone by the next sync.
--//
--// The request carries nothing. The perk and the amount are fixed in the shared file, so the
--// only thing a client can say is that it picked something, and the worst a forged one earns
--// is two points of Lightfoot.
--//
--// Server only, in the sense the game means it: this file is skipped on a client, and
--// OnClientCommand only ever fires on the authoritative side.

--// Guard
if isClient() then return end

--// Connections
local function OnClientCommand(Module, Command, Player, _Args)
	if Module ~= QOLC_LOCK_XP_MODULE then return end
	if Command ~= QOLC_LOCK_XP_COMMAND then return end
	if not Player then return end

	-- Only picking pays. Prying pays nothing and never has, so there is one switch to read.
	if not QolcPickingEnabled() then return end

	QolcAwardPickXp(Player)
end

Events.OnClientCommand.Add(OnClientCommand)
