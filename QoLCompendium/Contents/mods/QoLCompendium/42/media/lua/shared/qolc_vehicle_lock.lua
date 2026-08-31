--// Vehicle Lock Changes
--// Lockpicking. Just. Lockpicking., Workshop 2056238799
--// FMJ - Original, MeTaLAnGeR - IWBUMS update, Oh God Spiders No - streamlining
--// aspctt - 31.08.2026
--// Changes a car door's lock on the side that is allowed to change it.
--//
--// A car door's lock only travels one way. BaseVehicle.transmitPartDoor returns immediately
--// unless this is the server, and the two packets that carry part state, VehicleUpdate and
--// VehicleFullUpdate, are both sent from VehicleManager.sendVehicles, which only serverUpdate
--// calls. clientUpdate sends no part state at all. So a client that unlocks a car door has
--// unlocked it for itself and for nobody else, and the next update from the server puts the
--// lock straight back.
--//
--// A building door is not like this. IsoDoor.syncIsoObject sends upward as well as down, and
--// that is the whole reason picking a house has worked on a server since this feature landed
--// while picking a car, added later, did not.
--//
--// So the client asks and the server does it, which is what vanilla's own vehicle menu does
--// to open a door. The roll stays on the client because it reads that character's traits and
--// panic, so the server is trusting the outcome rather than repeating the work. The worst a
--// forged request does is open a car the player was already stood beside with a crowbar.
--//
--// Shared, so the server handler and the client actions call the same code and the two cannot
--// drift apart.

--// Tuning
QOLC_VEHICLE_LOCK_MODULE = "QoLC"
QOLC_VEHICLE_LOCK_COMMAND = "VehicleLock"

--// Functions
-- The change itself. Transmitting is what makes it real for everyone else, and it does
-- nothing at all off the server, which is exactly why this has to run there.
function QolcApplyVehicleLock(Vehicle, Part, Unlock, Wreck)
	if not Vehicle or not Part then return false end

	local Door = Part.getDoor and Part:getDoor()
	if not Door then return false end

	if Unlock then Door:setLocked(false) end
	if Wreck then Door:setLockBroken(true) end

	if Vehicle.transmitPartDoor then Vehicle:transmitPartDoor(Part) end
	return true
end

-- Applied here as well as asked for, so the door reads as worked the moment the job finishes
-- rather than a round trip later. The server's copy is the one that lasts, and its next update
-- corrects this one if it refused.
function QolcRequestVehicleLock(Character, Part, Unlock, Wreck, Prying)
	local Vehicle = Part and Part.getVehicle and Part:getVehicle()
	if not Vehicle then return false end

	QolcApplyVehicleLock(Vehicle, Part, Unlock, Wreck)

	if isClient() then
		-- The difficulty rides along. It is rolled on the client when the menu is built and
		-- kept in the part's own mod data, and that mod data only travels server to client
		-- like everything else on a part, so without this every player rolls their own for the
		-- same car and rerolls it on every rejoin. Sending it here means the first person to
		-- actually work the lock settles it for everyone.
		sendClientCommand(Character, QOLC_VEHICLE_LOCK_MODULE, QOLC_VEHICLE_LOCK_COMMAND, {
			vehicle = Vehicle:getId(),
			part = Part:getId(),
			unlock = Unlock and true or false,
			wreck = Wreck and true or false,
			prying = Prying and true or false,
			level = Part:getModData().QolcLockLevel
		})
	end

	return true
end
