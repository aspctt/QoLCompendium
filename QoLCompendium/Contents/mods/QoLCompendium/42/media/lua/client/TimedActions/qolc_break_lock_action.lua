--// Force A Lock With A Crowbar
--// Lockpicking. Just. Lockpicking., Workshop 2056238799
--// FMJ - Original, MeTaLAnGeR - IWBUMS update, Oh God Spiders No - streamlining
--// aspctt - 18.08.2026
--// Levers a door or window lock open with a crowbar. Loud either way, louder when it
--// goes wrong, and it wears the crowbar down.
--//
--// One file for both, where the original had two that differed in about ten lines: the
--// chance, the noise and the wear are identical, and only what happens on success is
--// not. A door has its lock broken off and is then opened by vanilla's own route; a
--// window is unlocked, opened, and then perma locked so it cannot be shut and relocked
--// behind you.
--//
--// Client only, same as the picking action. The door half hands off to ToggleDoor, which
--// syncs the change itself, so a forced door reaches everyone on a server.

require "TimedActions/ISBaseTimedAction"

QolcBreakLockAction = ISBaseTimedAction:derive("QolcBreakLockAction")

--// Tuning
-- The original's numbers. Chance is a one in N roll, so smaller is better.
local BASE_CHANCE = 4
local WORST_CHANCE = 4

-- Noise carries further when it goes wrong, because that is the sound of a crowbar
-- bouncing off a lock rather than a lock giving way.
local NOISE_SUCCESS = 25
local NOISE_FAILURE = 35
local NOISE_RADIUS = 30

-- Endurance runs zero to one and falls as a character tires: the debug readout works it
-- out as starting minus current. The original added 0.7 to it while its own comment said
-- it was adding exhaustion, which on this scale would hand back most of a character's
-- stamina for forcing one lock. Taken off instead, and at a size that reads as effort
-- rather than a day's work.
local EXERTION = 0.04

--// Functions
local function PanicSteps(Player)
	local Panic = Player:getStats():get(CharacterStat.PANIC) or 0
	return math.floor(Panic / 28)
end

-- Chance to force it, affected by panic and Nimble Fingers. The original also read Lucky
-- and Unlucky, which build 42 removed from the game outright.
function QolcBreakLockChance(Player)
	local Chance = BASE_CHANCE - PanicSteps(Player)
	if QolcHasNimbleFingers(Player) then Chance = Chance + 2 end

	return math.max(WORST_CHANCE, Chance)
end

-- How far the noise carries beyond the base. Panic makes a character clumsier with the
-- bar, and the traits pull either way.
function QolcBreakLockNoise(Player)
	local Noise = PanicSteps(Player)
	if QolcHasNimbleFingers(Player) then Noise = Noise - 3 end

	if Player:hasTrait(CharacterTrait.CLUMSY) then
		Noise = Noise + 6
	elseif Player:hasTrait(CharacterTrait.GRACEFUL) then
		Noise = Noise - 5
	end

	return Noise
end

local function Shout(Object, Volume)
	local Square = Object:getSquare()
	if not Square then return end

	addSound(Object, Square:getX(), Square:getY(), Square:getZ(), Volume, NOISE_RADIUS)
end

-- A window is smashed by hitting it with the crowbar at full door damage, which is what
-- the original did, restoring the weapon's own figure afterwards so nothing is left
-- permanently stronger.
local function SmashWindow(Player, Window, Weapon)
	local Stored = Weapon:getDoorDamage()
	Weapon:setDoorDamage(100)
	Window:WeaponHit(Player, Weapon)
	Weapon:setDoorDamage(Stored)
end

--// The Action
function QolcBreakLockAction:isValid()
	-- Whatever counts as a crowbar, not an item literally called one. Build 42 forges its
	-- own, and the menu offers this for it.
	return QolcIsCrowbar(self.character:getPrimaryHandItem())
end

function QolcBreakLockAction:start()
	-- Bob_IdleLeverOpenMid and its High twin, the same levering vanilla uses to pull a
	-- barricade off. The node takes two conditions rather than one: the action name, and
	-- a RemoveBarricade variable choosing the height. Setting only the first plays nothing.
	self:setActionAnim("RemoveBarricade")
	self:setAnimVariable("RemoveBarricade", self.isWindow and "CrowbarHigh" or "CrowbarMid")

	-- The item rather than a model name, so a forged crowbar is drawn as itself.
	self:setOverrideHandModels(self.character:getPrimaryHandItem(), nil)
end

function QolcBreakLockAction:stop()
	luautils.equipItems(self.character, self.storedPrim, self.storedScnd)
	ISBaseTimedAction.stop(self)
end

function QolcBreakLockAction:perform()
	local Player = self.character
	local Object = self.object
	local Square = Object:getSquare()
	local Weapon = Player:getPrimaryHandItem()
	local Noise = QolcBreakLockNoise(Player)

	if ZombRand(QolcBreakLockChance(Player)) == 0 then
		-- It held. The bar rings off it and every zombie in earshot hears.
		getSoundManager():PlayWorldSound("CrowbarHit", false, Square, 0, 15, 20, true)
		Shout(Object, NOISE_FAILURE + Noise)

		if self.isWindow then SmashWindow(Player, Object, Weapon) end
	else
		getSoundManager():PlayWorldSound(
			self.isWindow and "QolcForceWindow" or "RemoveBarricadeMetal",
			false, Square, 0, 15, 20, true)
		Shout(Object, NOISE_SUCCESS + Noise)

		if self.isWindow then
			Object:setIsLocked(false)
			Object:ToggleWindow(Player)

			-- The catch is levered off, so it can never be locked again
			Object:setPermaLocked(true)
		else
			-- The lock is off first, then the door is opened by vanilla's own route.
			--
			-- This used to be ToggleDoorSilent, which is a trap. Read in the jar, that
			-- method flips open on the one object it is called on, swaps that object's
			-- sprite, and stops. Everything else is in ToggleDoorActual: the garage door
			-- and double door runs, the obstruction check, and the sync. So a three tile
			-- storage shutter had one panel opened on its own, drawn with the shutter up
			-- frame meant to be seen as part of a whole open run. Reported as the door
			-- glitching out and opening like an ordinary door.
			--
			-- Worse on the way back. toggleGarageDoorObject flips each segment from its
			-- own open state rather than the run's, so closing it normally shut the panel
			-- we opened and opened the other two, and the run stayed out of step for good.
			--
			-- Unlocking first matters: ToggleDoorActual refuses a door that is still
			-- locked and still shut, and rattles at you instead. Both fields, because
			-- locked and lockedByKey are separate and the menu tests either.
			Object:setLocked(false)
			Object:setLockedByKey(false)
			Object:ToggleDoor(Player)
		end
	end

	local Stats = Player:getStats()
	Stats:set(CharacterStat.ENDURANCE, Stats:get(CharacterStat.ENDURANCE) - EXERTION)

	luautils.weaponLowerCondition(Weapon, Player, false)
	luautils.equipItems(Player, self.storedPrim, self.storedScnd)
	ISBaseTimedAction.perform(self)
end

function QolcBreakLockAction:new(Character, Object, Time, StoredPrim, StoredScnd, IsWindow)
	local Action = ISBaseTimedAction.new(self, Character)
	Action.character = Character
	Action.object = Object
	Action.storedPrim = StoredPrim
	Action.storedScnd = StoredScnd
	Action.isWindow = IsWindow and true or false
	Action.stopOnWalk = true
	Action.stopOnRun = true
	Action.maxTime = Time

	if Character:isTimedActionInstant() then Action.maxTime = 1 end

	return Action
end
