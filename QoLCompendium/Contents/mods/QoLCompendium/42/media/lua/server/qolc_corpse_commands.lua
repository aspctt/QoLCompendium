--// Corpse Disposal Commands
--// Def's Long Term Survival, Workshop 1962914415 - Original idea, by DefbeatCZ
--// aspctt - 31.08.2026
--// Hands out butchered flesh on the side that is allowed to.
--//
--// Reported twice from a self hosted server: the meat could not be dropped or moved, and it
--// was gone again after a reload. Both are the same fault. The butchering action ran on the
--// client and made the flesh there, so the server never heard of the item. Every transfer a
--// client attempts is checked against the server, which has no such item and refuses it, and
--// the next time the server hands the inventory back the piece is simply not in it.
--//
--// Vanilla does not hit this because butchering an animal is driven from the server. This is
--// a context menu action, so the client has to ask instead, which is what camping does to
--// give a tent kit back and what trapping does to give a trap back.
--//
--// Nothing is taken off the wire. The count and the item come from QOLC_CORPSE_YIELD and
--// QOLC_CORPSE_FLESH in the shared action file, because a count sent by a client is a count
--// a client chose. There are no arguments at all, so there is nothing to forge.
--//
--// Server only, in the sense the game means it: this file is skipped on a client, and
--// OnClientCommand only ever fires on the authoritative side.

--// Guard
if isClient() then return end

--// Tuning
local MODULE = "QoLC"
local COMMAND = "ButcherCorpse"

--// Connections
local function OnClientCommand(Module, Command, Player, _Args)
	if Module ~= MODULE then return end
	if Command ~= COMMAND then return end
	if not Player then return end

	-- The switch is read here as well as at the menu. A client with the feature turned off
	-- locally, or an older client, should not be able to ask for flesh on a server that has
	-- said no.
	if QolcCorpseDisposalEnabled and not QolcCorpseDisposalEnabled() then return end

	QolcGiveCorpseFlesh(Player, Player.getSquare and Player:getSquare())
end

Events.OnClientCommand.Add(OnClientCommand)
