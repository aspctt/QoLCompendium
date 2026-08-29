--// Force A Vehicle Lock With A Crowbar
--// Lockpicking. Just. Lockpicking., Workshop 2056238799
--// FMJ - Original, MeTaLAnGeR - IWBUMS update, Oh God Spiders No - streamlining
--// aspctt - 29.08.2026
--// Levers a car door or a boot open with a crowbar. Asked for in game.
--//
--// The odds, the noise and the wear are the door action's, called rather than copied, so a
--// car is no easier than a house and stays that way if either is retuned.
--//
--// Succeeding sets lockBroken as well as unlocking, which is not spite: the jar shows
--// canLockDoor refusing a broken lock, so it can never be locked again. That is the same
--// thing this already does to a window by perma locking the latch. You have taken the lock
--// out of it.
--//
--// The door is left shut. Vanilla's own open option works the moment it is unlocked, and
--// queueing an open from in here would fight whatever the player does next.
--//
--// Client only, with every change handed to BaseVehicle.transmitPartDoor.

require "TimedActions/ISBaseTimedAction"

QolcBreakVehicleLockAction = ISBaseTimedAction:derive("QolcBreakVehicleLockAction")

--// Tuning
-- The door action's figures, written again rather than reached for, because they describe
-- this action rather than that one.
local NOISE_SUCCESS = 25
local NOISE_FAILURE = 35
local NOISE_RADIUS = 30

local EXERTION = 0.04

--// Functions
local function Shout(Object, Square, Volume)
	if not Square then return end
	addSound(Object, Square:getX(), Square:getY(), Square:getZ(), Volume, NOISE_RADIUS)
end

--// The Action
function QolcBreakVehicleLockAction:isValid()
	if not QolcIsCrowbar(self.character:getPrimaryHandItem()) then return false end

	local Door = self.part and self.part:getDoor()
	return Door ~= nil and Door:isLocked()
end

function QolcBreakVehicleLockAction:update()
	self.character:faceThisObject(self.vehicle)
end

function QolcBreakVehicleLockAction:start()
	-- The same levering vanilla uses to pull a barricade off. The node takes two conditions
	-- rather than one: the action name, and a RemoveBarricade variable choosing the height.
	-- A car lock is at door height.
	self:setActionAnim("RemoveBarricade")
	self:setAnimVariable("RemoveBarricade", "CrowbarMid")

	-- The item rather than a model name, so a forged crowbar is drawn as itself.
	self:setOverrideHandModels(self.character:getPrimaryHandItem(), nil)
end

function QolcBreakVehicleLockAction:stop()
	luautils.equipItems(self.character, self.storedPrim, self.storedScnd)
	ISBaseTimedAction.stop(self)
end

function QolcBreakVehicleLockAction:perform()
	local Player = self.character
	local Part = self.part
	local Vehicle = self.vehicle
	local Door = Part:getDoor()
	local Square = Part:getSquare()
	local Weapon = Player:getPrimaryHandItem()
	local Noise = QolcBreakLockNoise(Player)

	if ZombRand(QolcBreakLockChance(Player)) == 0 then
		-- It held. The bar rings off it and every zombie in earshot hears.
		getSoundManager():PlayWorldSound("CrowbarHit", false, Square, 0, 15, 20, true)
		Shout(Vehicle, Square, NOISE_FAILURE + Noise)
	else
		getSoundManager():PlayWorldSound("RemoveBarricadeMetal", false, Square, 0, 15, 20, true)
		Shout(Vehicle, Square, NOISE_SUCCESS + Noise)

		-- Unlocked, and the lock left in pieces so it can never be locked again.
		Door:setLocked(false)
		Door:setLockBroken(true)
		Vehicle:transmitPartDoor(Part)
	end

	local Stats = Player:getStats()
	Stats:set(CharacterStat.ENDURANCE, Stats:get(CharacterStat.ENDURANCE) - EXERTION)

	luautils.weaponLowerCondition(Weapon, Player, false)
	luautils.equipItems(Player, self.storedPrim, self.storedScnd)
	ISBaseTimedAction.perform(self)
end

function QolcBreakVehicleLockAction:new(Character, Part, Time, StoredPrim, StoredScnd)
	local Action = ISBaseTimedAction.new(self, Character)
	Action.character = Character
	Action.part = Part
	Action.vehicle = Part and Part:getVehicle()
	Action.storedPrim = StoredPrim
	Action.storedScnd = StoredScnd
	Action.stopOnWalk = true
	Action.stopOnRun = true
	Action.maxTime = Time

	if Character:isTimedActionInstant() then Action.maxTime = 1 end

	return Action
end
