--// Vehicle Lock Commands
--// Lockpicking. Just. Lockpicking., Workshop 2056238799
--// aspctt - 31.08.2026
--// Works a car lock on the side that is allowed to.
--//
--// See shared/qolc_vehicle_lock.lua for why this file has to exist: a car door's lock only
--// travels server to client, so a client that unlocks one has unlocked it for itself alone.
--//
--// The vehicle and the part are resolved the way vanilla's own vehicle commands resolve
--// them, with getVehicleById and getPartById, so a request naming something that is not there
--// falls out rather than throwing.
--//
--// The switch is read again here. A client with the feature on locally, or one still running
--// an older build, should not be able to open a car on a server that has said no, and picking
--// and prying are separate switches so the request has to say which it was.
--//
--// Server only, in the sense the game means it: this file is skipped on a client, and
--// OnClientCommand only ever fires on the authoritative side.

--// Guard
if isClient() then return end

--// Connections
local function OnClientCommand(Module, Command, _Player, Args)
	if Module ~= QOLC_VEHICLE_LOCK_MODULE then return end
	if Command ~= QOLC_VEHICLE_LOCK_COMMAND then return end
	if not Args then return end

	-- Written out rather than as an and/or, which cannot carry a false: the true branch of
	-- "a and b or c" falls straight through to c when b is false, so a server with prying off
	-- would have answered with whether picking was on.
	local Allowed
	if Args.prying then Allowed = QolcPryingEnabled() else Allowed = QolcPickingEnabled() end
	if not Allowed then return end

	local Vehicle = getVehicleById(Args.vehicle)
	if not Vehicle then return end

	local Part = Vehicle:getPartById(Args.part)
	if not Part then return end

	-- Kept so the same car is the same difficulty for everyone, and cannot be rerolled by
	-- rejoining. Clamped, because a level outside the five has no name to show and this one
	-- came off the wire.
	local Level = tonumber(Args.level)
	if Level and Level >= 1 and Level <= 5 then
		Part:getModData().QolcLockLevel = Level
		if Vehicle.transmitPartModData then Vehicle:transmitPartModData(Part) end
	end

	QolcApplyVehicleLock(Vehicle, Part, Args.unlock, Args.wreck)
end

Events.OnClientCommand.Add(OnClientCommand)
