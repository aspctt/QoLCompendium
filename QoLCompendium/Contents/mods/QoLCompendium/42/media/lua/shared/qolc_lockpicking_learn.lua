--// Learning To Force A Lock
--// Lockpicking. Just. Lockpicking., Workshop 2056238799
--// FMJ - Original, MeTaLAnGeR - IWBUMS update, Oh God Spiders No - streamlining
--// aspctt - 18.08.2026
--// The second volume teaches forcing a lock with a crowbar, and a burglar already knows.
--//
--// Picking rides on a real recipe, QolcMakeLockpickFromHairpin, which the first volume
--// teaches through LearnedRecipes the way build 42 handles any recipe magazine. Forcing
--// is not a recipe at all, and there is no way to record it as one: LearnedRecipes is
--// checked against the recipes that exist and a name matching none of them is refused
--// outright, with "Learnable CraftRecipe QolcBreakLocks does not exist" in the log and
--// nothing learned. learnRecipe refuses it just as quietly.
--//
--// So it is kept as a flag on the character's own mod data, which nothing validates and
--// which saves and loads with them.
--//
--// Hooked on complete rather than perform. complete is where the base game finishes a
--// read, calls ReadLiterature and hands over the recipes; an earlier version of this file
--// wrapped perform instead and never fired.
--//
--// Shared, because complete only runs on the side in charge of the character. This was a
--// client file, which worked alone and taught nothing at all in multiplayer: a client
--// never runs complete, LuaTimedActionNew skips it there, and the server that does run it
--// never loads client files.
--//
--// On a server the flag goes on the server's copy of the reader, then a command carries
--// it to the reader's own game, where the menu that reads it is drawn. The server could
--// call transmitModData instead, but that overwrites the client's whole mod data with the
--// server's copy, hotbar layout included, to deliver one flag.
--//
--// The reader's game then sends its mod data back. Every transmitModData from a client
--// replaces the server's table outright, and the hotbar sends one on every rearrangement.
--// One landing between the server setting the flag and the command arriving would wipe it
--// from the server's copy, which is the one that comes back on the next join.

require "TimedActions/ISReadABook"

--// Tuning
local BOOK = "Base.QolcLockpickBook2"
local FLAG = "QolcKnowsForcing"

-- The server's word to the reader's game that the second volume was read
local MODULE = "QoLC"
local LEARNED_COMMAND = "LearnedForcing"

local PICKING = {
	"QolcMakeLockpickFromHairpin",
	"QolcMakeLockpickFromPaperclip",
	"QolcMakeLockpickFromWire"
}

--// Functions
-- Both switches live in shared/qolc_lock_tools.lua, so this file, the menu and the server
-- command cannot disagree about what off means. Everything about the crowbar is prying and
-- everything about the pick is lockpicking, including which manual spawns and which half of a
-- burglar's head start survives one of them being off.

-- Read by the menu, so both halves agree on what knowing means.
function QolcKnowsForcing(Player)
	if not Player then return false end

	local ModData = Player:getModData()
	return ModData and ModData[FLAG] == true
end

function QolcLearnForcing(Player)
	if QolcKnowsForcing(Player) then return false end

	Player:getModData()[FLAG] = true
	return true
end

local function Announce(Player)
	Player:Say(getText("IGUI_QoLC_LearnedForcing"))
end

--// Overrides
local VanillaComplete = ISReadABook.complete

function ISReadABook:complete(...)
	local Result = VanillaComplete(self, ...)

	-- Sanity check
	if self.forceStopped or not QolcPryingEnabled() then return Result end
	if not self.item or not self.character then return Result end
	if self.item:getFullType() ~= BOOK then return Result end
	if not QolcLearnForcing(self.character) then return Result end

	-- Tell the reader's own game, or say it here when this is that game
	if isServer() then
		sendServerCommand(self.character, MODULE, LEARNED_COMMAND, {
			playerOnlineId = self.character:getOnlineID(),
		})
	else
		Announce(self.character)
	end

	return Result
end

--// Connections
-- A burglar has done this before, so they start knowing rather than hunting two manuals.
--
-- learnRecipe is called plainly, with nothing guarding it. It used to sit behind an
-- isRecipeKnown check, which read as harmless and was the whole of why a burglar never
-- learned anything: the one argument form of that call answers true for every recipe here
-- whether or not the character knows it, so the guard concluded there was nothing to do
-- every single time. learnRecipe already refuses to learn something twice, using the check
-- that tells the truth, so calling it outright is both correct and idempotent.
--
-- Hung on three events rather than one. OnGameStart alone was not enough: for a character
-- made moments earlier it can run before the profession's traits are on them, and the
-- grant then finds no burglar and does nothing for the life of that save.
local function Grant(Player)
	if not Player then return end
	if not Player:hasTrait(CharacterTrait.BURGLAR) then return end

	if QolcPickingEnabled() then
		for _, Recipe in ipairs(PICKING) do
			Player:learnRecipe(Recipe)
		end
	end

	if QolcPryingEnabled() then QolcLearnForcing(Player) end
end

-- Kept to the player's own game, as it was while this was a client file. A server fires
-- OnNewGame as well, from CreatePlayerPacket, and nothing here was written for that.
function QolcGrantBurglar(Player)
	if isServer() then return end

	Grant(Player or getSpecificPlayer(0))
end

Events.OnGameStart.Add(function() QolcGrantBurglar() end)
Events.OnNewGame.Add(function(Player) QolcGrantBurglar(Player) end)
Events.OnCreatePlayer.Add(function(_Index, Player) QolcGrantBurglar(Player) end)

-- The reader's half of a read the server finished. Only ever fires on a client. Sending
-- the mod data straight back is explained in the header.
local function OnServerCommand(Module, Command, Args)
	if Module ~= MODULE or Command ~= LEARNED_COMMAND then return end

	local Player = Args and Args.playerOnlineId and getPlayerByOnlineID(Args.playerOnlineId)
	if not Player or not Player:isLocalPlayer() then return end
	if not QolcLearnForcing(Player) then return end

	Player:transmitModData()
	Announce(Player)
end

Events.OnServerCommand.Add(OnServerCommand)
