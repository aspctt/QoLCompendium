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
--// Client only. Mod data on the player travels with them.

require "TimedActions/ISReadABook"

--// Tuning
local BOOK = "Base.QolcLockpickBook2"
local FLAG = "QolcKnowsForcing"

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

--// Overrides
local VanillaComplete = ISReadABook.complete

function ISReadABook:complete(...)
	local Result = VanillaComplete(self, ...)

	if QolcPryingEnabled() and self.item and self.character
		and self.item:getFullType() == BOOK and QolcLearnForcing(self.character) then
		self.character:Say(getText("IGUI_QoLC_LearnedForcing"))
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

function QolcGrantBurglar(Player)
	Grant(Player or getSpecificPlayer(0))
end

Events.OnGameStart.Add(function() QolcGrantBurglar() end)
Events.OnNewGame.Add(function(Player) QolcGrantBurglar(Player) end)
Events.OnCreatePlayer.Add(function(_Index, Player) QolcGrantBurglar(Player) end)
