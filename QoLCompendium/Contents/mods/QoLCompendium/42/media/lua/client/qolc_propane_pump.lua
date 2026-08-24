--// Propane From Fuel Pumps
--// Pumps Have Propane, Workshop 2739570406 - Original idea, by Uncle Griz
--// aspctt - 10.08.2026
--// Adds "Take Propane" to a working fuel pump, so an empty propane tank can be filled.
--//
--// Build 42 has no way at all to refill a propane tank. Nothing in the game produces a
--// filled one from an empty one, which leaves the tank as dead weight once it is spent
--// and puts a hard ceiling on welding. This is the gap that fills it.
--//
--// Rewritten rather than ported. The original is build 41 only, and build 42 rebuilt
--// fuel pumps as entities with a FluidContainer component. What survived the change is
--// how vanilla recognises a working pump, getPipedFuelAmount() > 0, which is the same
--// test ISVehiclePartMenu.getNearbyFuelPump uses to find one for refuelling a car.
--//
--// Client only. The context menu is a client concern and the timed action it queues is
--// shared, which is where the actual work happens.

--// Tuning
local TANK_TYPE = "Base.PropaneTank"

-- Roughly the pace of filling a jerry can, scaled by how empty the tank is.
local FILL_TIME_FULL = 300

-- How far around the clicked square to look for the pump itself.
--
-- Reported in game as no option appearing at all. A fuel pump is several tiles and the
-- part you right click is usually not the object carrying the fuel, so looking only at
-- the square under the cursor finds nothing. Vanilla has the same problem and solves it
-- the same way: ISVehiclePartMenu.getNearbyFuelPump sweeps minus two to plus two around
-- the vehicle's tank rather than testing one square.
local PUMP_SEARCH = 2

--// Switch
-- Server controlled, because this is balance rather than presentation. A per client
-- setting would let one player on a server play to different numbers than the rest.
local function QolcEnabled()
	local Vars = SandboxVars and SandboxVars.QoLC
	local Value = Vars and Vars.PropanePumpEnabled

	if Value ~= nil then return Value and true or false end
	return true
end

--// Functions
-- Vanilla's own test for a pump worth using, taken from getNearbyFuelPump. Covers both
-- having power and having fuel left, so nothing else has to be checked.
local function IsWorkingPump(Object)
	if not Object or not Object.getPipedFuelAmount then return false end
	return Object:getPipedFuelAmount() > 0
end

local function PumpOnSquare(Square)
	local Objects = Square and Square:getObjects()
	if not Objects then return nil end

	for Index = 0, Objects:size() - 1 do
		local Candidate = Objects:get(Index)
		if IsWorkingPump(Candidate) then return Candidate end
	end

	return nil
end

local function FindPump(WorldObjects)
	local Origin = nil

	for _, Object in ipairs(WorldObjects) do
		if IsWorkingPump(Object) then return Object end

		local Square = Object.getSquare and Object:getSquare()
		local Found = PumpOnSquare(Square)
		if Found then return Found end

		Origin = Origin or Square
	end

	-- Nothing under the cursor, so sweep the tiles around it
	if not Origin then return nil end

	local Cell = getCell()
	if not Cell then return nil end

	for X = -PUMP_SEARCH, PUMP_SEARCH do
		for Y = -PUMP_SEARCH, PUMP_SEARCH do
			local Found = PumpOnSquare(Cell:getGridSquare(
				Origin:getX() + X, Origin:getY() + Y, Origin:getZ()))

			if Found then return Found end
		end
	end

	return nil
end

local function IsFillableTank(Item)
	if not Item or Item:getFullType() ~= TANK_TYPE then return false end
	return Item:getCurrentUsesFloat() < 1
end

-- Recursed, not a walk over getItems. A worn bag is a container of its own and getItems
-- does not descend into it, so a tank that had been packed rather than carried loose was
-- invisible and no option appeared at all. A propane tank weighs ten, which is most of a
-- character's spare capacity, so packing it is the normal thing to do and the bug was in
-- everybody's way. Reported as the refill not working on an existing save.
--
-- getAllEvalRecurse is what vanilla reaches for here. ISVehiclePartMenu finds the petrol
-- can to refuel a car with containsEvalRecurse and getAllEvalRecurse and never touches
-- getItems, for exactly this reason.
local function FindTanks(Player)
	local Found = {}

	local Inventory = Player:getInventory()
	if not Inventory or not Inventory.getAllEvalRecurse then return Found end

	local All = Inventory:getAllEvalRecurse(IsFillableTank)
	for Index = 0, All:size() - 1 do
		table.insert(Found, All:get(Index))
	end

	return Found
end

-- Fetched out of whatever bag is holding it, filled, then put back where it was found.
-- The tank is held in hand for the animation and the game expects a held item to be in
-- the character's own inventory, so a tank still sitting in a backpack cannot simply be
-- worked on where it lies.
--
-- The same three steps vanilla queues to fill a petrol can, in the same order, from
-- ISWorldObjectContextMenu.onTakeFuelNew. Returning it is the courtesy half: without it
-- a full tank is left loose in the main inventory, which for something weighing ten is
-- the difference between walking home and not.
local function Fill(Player, Pump, Tanks)
	local Inventory = Player:getInventory()

	for _, Tank in ipairs(Tanks) do
		local Missing = 1 - Tank:getCurrentUsesFloat()

		local From = Tank:getContainer()
		local Packed = From and From ~= Inventory and From:isInCharacterInventory(Player)

		ISWorldObjectContextMenu.transferIfNeeded(Player, Tank)
		ISTimedActionQueue.add(QolcFillPropaneAction:new(Player, Pump, Tank, FILL_TIME_FULL * Missing))

		if Packed then
			ISTimedActionQueue.add(ISInventoryTransferUtil.newInventoryTransferAction(
				Player, Tank, Inventory, From))
		end
	end
end

local function OnFillWorldObjectContextMenu(PlayerNum, Context, WorldObjects, Test)
	if Test then return end
	if not QolcEnabled() then return end

	local Player = getSpecificPlayer(PlayerNum)
	if not Player then return end

	local Pump = FindPump(WorldObjects)
	if not Pump then return end

	local Tanks = FindTanks(Player)
	if #Tanks == 0 then return end

	local Option = Context:addOption(getText("ContextMenu_QoLC_TakePropane"), WorldObjects, nil)
	local SubMenu = ISContextMenu:getNew(Context)
	Context:addSubMenu(Option, SubMenu)

	if #Tanks > 1 then
		SubMenu:addOption(getText("ContextMenu_FillAll"), WorldObjects, function()
			Fill(Player, Pump, Tanks)
		end)
	end

	for _, Tank in ipairs(Tanks) do
		local Percent = math.floor(Tank:getCurrentUsesFloat() * 100)
		local Label = Tank:getName() .. " (" .. tostring(Percent) .. "%)"

		local Entry = SubMenu:addOption(Label, WorldObjects, function()
			Fill(Player, Pump, { Tank })
		end)
		Entry.itemForTexture = Tank
	end
end

--// Connections
Events.OnFillWorldObjectContextMenu.Add(OnFillWorldObjectContextMenu)
