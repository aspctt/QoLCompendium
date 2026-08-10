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

--// Functions
-- Vanilla's own test for a pump worth using, taken from getNearbyFuelPump. Covers both
-- having power and having fuel left, so nothing else has to be checked.
local function IsWorkingPump(Object)
	if not Object or not Object.getPipedFuelAmount then return false end
	return Object:getPipedFuelAmount() > 0
end

local function FindPump(WorldObjects)
	for _, Object in ipairs(WorldObjects) do
		if IsWorkingPump(Object) then return Object end

		-- The square's other objects are worth a look, since a right click lands on
		-- whichever one happens to be on top
		local Square = Object.getSquare and Object:getSquare()
		local Objects = Square and Square:getObjects()

		if Objects then
			for Index = 0, Objects:size() - 1 do
				local Candidate = Objects:get(Index)
				if IsWorkingPump(Candidate) then return Candidate end
			end
		end
	end

	return nil
end

local function IsFillableTank(Item)
	if not Item or Item:getFullType() ~= TANK_TYPE then return false end
	return Item:getCurrentUsesFloat() < 1
end

local function FindTanks(Player)
	local Found = {}

	local Inventory = Player:getInventory()
	if not Inventory then return Found end

	local All = Inventory:getItems()
	for Index = 0, All:size() - 1 do
		local Item = All:get(Index)
		if IsFillableTank(Item) then table.insert(Found, Item) end
	end

	return Found
end

local function Fill(Player, Pump, Tanks)
	for _, Tank in ipairs(Tanks) do
		local Missing = 1 - Tank:getCurrentUsesFloat()
		ISTimedActionQueue.add(QolcFillPropaneAction:new(Player, Pump, Tank, FILL_TIME_FULL * Missing))
	end
end

local function OnFillWorldObjectContextMenu(PlayerNum, Context, WorldObjects, Test)
	if Test then return end

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
