--// Propane Pump Commands
--// Pumps Have Propane, Workshop 2739570406 - Original idea, by Uncle Griz
--// aspctt - 23.09.2026
--// Fills a propane tank at a pump on the side that is allowed to.
--//
--// See shared/TimedActions/qolc_fill_propane_action.lua for why this file has to exist: a
--// tank a client fills is filled for that client alone, because the server never takes a
--// drainable's uses from one.
--//
--// The request names a tank and a square and nothing else. The tank is looked for in the
--// sender's own inventory, bags and all, with getItemWithIDRecursiv, so it cannot name
--// somebody else's. The pump is whichever working one stands on that square, found the way
--// the menu found it. What it costs and how much goes in are worked out here, from this
--// server's sandbox and this server's pump.
--//
--// The switch is read again here. A client with the feature on locally, or one still running
--// an older build, should not be able to fill a tank on a server that has said no.
--//
--// Server only, in the sense the game means it: this file is skipped on a client, and
--// OnClientCommand only ever fires on the authoritative side.

--// Guard
if isClient() then return end

--// Connections
local function OnClientCommand(Module, Command, Player, Args)
	if Module ~= QOLC_PROPANE_MODULE then return end
	if Command ~= QOLC_PROPANE_COMMAND then return end
	if not Player or not Args then return end

	if not QolcPropanePumpEnabled() then return end

	local Id = tonumber(Args.tank)
	local Inventory = Player:getInventory()
	if not Id or not Inventory then return end

	local Tank = Inventory:getItemWithIDRecursiv(Id)
	if not QolcIsFillableTank(Tank) then return end

	local X = tonumber(Args.x)
	local Y = tonumber(Args.y)
	local Z = tonumber(Args.z)
	if not X or not Y or not Z then return end

	local Cell = getCell()
	local Pump = Cell and QolcPumpOnSquare(Cell:getGridSquare(X, Y, Z))
	if not Pump then return end

	QolcFillPropane(Tank, Pump)
end

Events.OnClientCommand.Add(OnClientCommand)
