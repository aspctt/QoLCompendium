--// Pick A Vehicle Lock
--// Lockpicking. Just. Lockpicking., Workshop 2056238799
--// FMJ - Original, MeTaLAnGeR - IWBUMS update, Oh God Spiders No - streamlining
--// aspctt - 29.08.2026
--// Works a lockpick into a car door or a boot lock. Asked for in game, the original
--// having only ever done buildings.
--//
--// The odds, the timing and the two ways a pick is lost are the door action's, called
--// rather than copied, so a car lock is exactly as hard as a house lock and stays that way
--// if either is ever retuned.
--//
--// What differs is what a lock is. A house door carries its jam in our own mod data; a
--// vehicle door has the game's VehicleDoor.lockBroken, and the jar shows both canUnlockDoor
--// and canLockDoor returning false the moment it is set. So one field of vanilla's own says
--// everything our mod data said, and vanilla already honours it: a wrecked lock will not
--// open for the key either, and the halo text for it is already written.
--//
--// Client only, same as the door action, and every change is handed to
--// BaseVehicle.transmitPartDoor, which is how vanilla's own unlocking reaches a server.

require "TimedActions/ISBaseTimedAction"

QolcPickVehicleLockAction = ISBaseTimedAction:derive("QolcPickVehicleLockAction")

--// The Action
-- Both hands are checked every tick, because dropping either one mid pick should stop it.
function QolcPickVehicleLockAction:isValid()
	local Primary = self.character:getPrimaryHandItem()
	local Secondary = self.character:getSecondaryHandItem()
	if not Primary or not Secondary then return false end
	if not QolcIsScrewdriver(Primary) then return false end
	if Secondary:getType() ~= "QolcLockpick" then return false end

	local Door = self.part and self.part:getDoor()
	return Door ~= nil and Door:isLocked()
end

function QolcPickVehicleLockAction:update()
	self.character:faceThisObject(self.vehicle)
end

function QolcPickVehicleLockAction:start()
	self:setActionAnim("Disassemble")

	-- The item rather than a model name, so a multitool is drawn as a multitool.
	self:setOverrideHandModels(self.character:getPrimaryHandItem(), nil)

	self.sound = getSoundManager():PlayWorldSound(
		"QolcLockpicking", false, self.part:getSquare(), 0, 8, 1, true)
end

function QolcPickVehicleLockAction:stop()
	if self.sound then self.sound:stop() end

	luautils.equipItems(self.character, self.storedPrim, self.storedScnd)
	ISBaseTimedAction.stop(self)
end

function QolcPickVehicleLockAction:perform()
	if self.sound then self.sound:stop() end

	local Player = self.character
	local Part = self.part
	local Vehicle = self.vehicle
	local Pick = Player:getSecondaryHandItem()
	local Level = Player:getPerkLevel(Perks.Lightfoot)
	local Chance = QolcPickLockChance(Player, Part:getModData().QolcLockLevel)

	-- Whichever way it went, the change goes through the shared request rather than being
	-- written here. A car door's lock only travels server to client, so a client writing it
	-- has changed the lock for itself alone and the server's next update puts it back. See
	-- shared/qolc_vehicle_lock.lua.
	if ZombRand(Chance) == 0 then
		-- Wrecked. lockBroken is the game's own word for it, and nothing opens this door
		-- again, the key included, which is what a jammed house lock already means here.
		QolcRequestVehicleLock(Player, Part, false, true, false)
		Vehicle:playPartSound(Part, Player, "IsLocked")
	else
		QolcRequestVehicleLock(Player, Part, true, false, false)
		Vehicle:playPartSound(Part, Player, "Unlock")

		-- Asked for rather than taken, the same as the house door action and for the same
		-- reason. See shared/qolc_lock_xp.lua.
		QolcRequestPickXp(Player)
	end

	-- Two separate rolls, as the door action has them: the pick can stick in the lock, or
	-- snap. Either way it is gone, and a higher Lightfoot makes snapping rarer.
	if ZombRand(Chance) == 0 then
		Player:Say(getText("IGUI_QoLC_PickStuck"))
		QolcDestroyPick(Player, Pick)
	elseif ZombRand(100) <= 30 - (Level * 2) then
		getSoundManager():PlayWorldSound("ArmourBreakMetal", false, Player:getSquare(), 0, 10, 1, true)
		Player:Say(getText("IGUI_QoLC_PickBroken"))
		QolcDestroyPick(Player, Pick)
	end

	luautils.equipItems(Player, self.storedPrim, self.storedScnd)
	ISBaseTimedAction.perform(self)
end

function QolcPickVehicleLockAction:new(Character, Part, Time, StoredPrim, StoredScnd)
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
