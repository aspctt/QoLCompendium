--// Fill Propane From Pump
--// Pumps Have Propane, Workshop 2739570406 - Original idea, by Uncle Griz
--// aspctt - 10.08.2026
--// Fills a propane tank at a working fuel pump, drawing on the pump's own supply so it
--// is not free and a pump can be emptied.
--//
--// It borrows its whole presentation from vanilla's ISTakeFuel, because to a player it
--// is the same job at the same pump: the same animation, the tank held in hand the way
--// a petrol can is, the same pump sound, and the same job bar across the item's icon.
--//
--// A propane tank is a drainable, measured in uses, while a pump holds fluid measured
--// in units. The two are bridged by a sandbox value giving the cost in pump units of
--// filling one tank from empty, so a server decides what it is worth.
--//
--// The fill itself happens on the side that owns the tank. On a server it used to happen
--// on the client and never went any further, which turned up while looking into a report
--// of a full tank weighing less than a used one. Nothing carried it. An action with no
--// complete is marked by LuaTimedActionNew as syncing itself, so the server is never told
--// it ran, and the syncItemFields that followed does not help either:
--// SyncItemFieldsPacket.processServer takes the condition, the name and a dozen other
--// fields from a client but never its uses. So the server kept the tank as it was, and the
--// player was left holding a copy only their own machine believed in. It is the mistake
--// the butchered flesh and the lock experience made, and it is fixed the same way: the
--// client asks, see server/qolc_propane_commands.lua.
--//
--// Shared, so the server handler and the action fill the same way and cannot drift apart.

require "TimedActions/ISBaseTimedAction"

QolcFillPropaneAction = ISBaseTimedAction:derive("QolcFillPropaneAction")

--// Tuning
-- Matches the default declared in 42/media/sandbox-options.txt, used when a save has no
-- value stored for it.
local DEFAULT_COST = 20

local TANK_TYPE = "Base.PropaneTank"

QOLC_PROPANE_MODULE = "QoLC"
QOLC_PROPANE_COMMAND = "FillPropane"

--// Switch
-- Server controlled, because this is balance rather than presentation. A per client
-- setting would let one player on a server play to different numbers than the rest.
function QolcPropanePumpEnabled()
	local Vars = SandboxVars and SandboxVars.QoLC
	local Value = Vars and Vars.PropanePumpEnabled

	if Value ~= nil then return Value and true or false end
	return true
end

--// Functions
-- The model to put in the character's hand while filling. Vanilla's ISTakeFuel passes
-- the petrol can's StaticModel, but a propane tank declares only a WorldStaticModel, so
-- fall back to that rather than animating an empty hand. Both resolve to the same mesh
-- key, and the fallback keeps working if a tank ever gains a proper held model.
local function HandModel(Item)
	return Item:getStaticModel() or Item:getWorldStaticModel()
end

-- How many pump units a full tank costs. Server controlled, see the sandbox page.
function QolcFillPropaneAction.GetCost()
	local Vars = SandboxVars and SandboxVars.QoLC
	local Value = Vars and tonumber(Vars.PropanePumpCost)
	if Value and Value > 0 then return Value end

	return DEFAULT_COST
end

-- Vanilla's own test for a pump worth using, taken from getNearbyFuelPump. Covers both
-- having power and having fuel left, so nothing else has to be checked.
function QolcIsWorkingPump(Object)
	if not Object or not Object.getPipedFuelAmount then return false end
	return Object:getPipedFuelAmount() > 0
end

function QolcPumpOnSquare(Square)
	local Objects = Square and Square:getObjects()
	if not Objects then return nil end

	for Index = 0, Objects:size() - 1 do
		local Candidate = Objects:get(Index)
		if QolcIsWorkingPump(Candidate) then return Candidate end
	end

	return nil
end

function QolcIsFillableTank(Item)
	if not Item or not Item.getFullType or Item:getFullType() ~= TANK_TYPE then return false end
	return Item:getCurrentUsesFloat() < 1
end

-- The fill itself. Called on whichever side is in charge: directly in singleplayer, and
-- from the server command when a client asked. Never on a client.
--
-- Never takes more than the pump has left, so a nearly dry pump gives a part fill rather
-- than a free full one.
function QolcFillPropane(Tank, Pump)
	if not QolcIsFillableTank(Tank) then return 0 end
	if not QolcIsWorkingPump(Pump) then return 0 end

	local Missing = 1 - Tank:getCurrentUsesFloat()
	local Available = Pump:getPipedFuelAmount()
	local Wanted = QolcFillPropaneAction.GetCost() * Missing
	local Spent = Wanted

	if Spent > Available then Spent = Available end

	local Filled = Missing
	if Wanted > 0 then Filled = Missing * (Spent / Wanted) end

	-- setCurrentUsesFloat works the tank's weight out again as it goes, and so does
	-- processClient when the sync below lands, which sets the uses through setCurrentUses.
	-- setPipedFuelAmount keeps the pump's fuel in its mod data and transmits it itself.
	Tank:setCurrentUsesFloat(Tank:getCurrentUsesFloat() + Filled)
	Pump:setPipedFuelAmount(math.floor(Available - Spent))

	-- Drainables carry their charge across the network as an item field. From the server
	-- this reaches the player holding the tank, and that is the direction that carries uses.
	if Tank.syncItemFields then Tank:syncItemFields() end

	return Filled
end

-- Asked for on a client, done on the spot anywhere else.
--
-- Nothing is filled here on a client, not even for show. A lock the client opens early is
-- corrected by the car's next update, but nothing ever corrects an item, so a fill the
-- server turned down would be the very copy this exists to stop. The server's sync is what
-- fills the tank on screen, a moment later.
--
-- The tank goes by id, which client and server share, and is looked for again in that
-- player's own inventory. The pump goes by its square, and the server finds the working pump
-- on it the way the menu did. The cost and the amount never travel: both are worked out on
-- the server from its own sandbox and its own pump.
function QolcRequestPropane(Character, Tank, Pump)
	if not Character or not Tank or not Pump then return false end

	if not isClient() then return QolcFillPropane(Tank, Pump) > 0 end

	local Square = Pump.getSquare and Pump:getSquare()
	if not Square then return false end

	sendClientCommand(Character, QOLC_PROPANE_MODULE, QOLC_PROPANE_COMMAND, {
		tank = Tank:getID(),
		x = Square:getX(),
		y = Square:getY(),
		z = Square:getZ()
	})

	return true
end

--// The Action
-- A tank that is not full, and a pump with something left in it, are the whole of what
-- this needs. Rechecked every tick so walking away or emptying the pump stops it.
function QolcFillPropaneAction:isValid()
	if not self.tank or not self.pump then return false end
	if self.tank:getCurrentUsesFloat() >= 1 then return false end

	return self.pump:getPipedFuelAmount() > 0
end

-- Turn to the pump before the animation starts, rather than filling side on
function QolcFillPropaneAction:waitToStart()
	self.character:faceThisObject(self.pump)
	return self.character:shouldBeTurning()
end

function QolcFillPropaneAction:update()
	self.character:faceThisObject(self.pump)
	self.tank:setJobDelta(self:getJobDelta())
	self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

-- The same shape as vanilla's ISTakeFuel, because it is the same job at the same pump:
-- the tank held in the off hand, the nozzle animation in the other, and the pump's own
-- sound rather than the generator one that stood in for it.
function QolcFillPropaneAction:start()
	self.tank:setJobType(getText("ContextMenu_QoLC_TakePropane"))
	self.tank:setJobDelta(0.0)

	self:setOverrideHandModels(nil, HandModel(self.tank))
	self:setActionAnim("TakeGasFromPump")

	self.sound = self.character:playSound("CanisterAddFuelFromGasPump")
end

function QolcFillPropaneAction:stop()
	if self.sound then self.character:stopOrTriggerSound(self.sound) end
	self.tank:setJobDelta(0.0)
	ISBaseTimedAction.stop(self)
end

function QolcFillPropaneAction:perform()
	if self.sound then self.character:stopOrTriggerSound(self.sound) end
	self.tank:setJobDelta(0.0)

	QolcRequestPropane(self.character, self.tank, self.pump)

	ISBaseTimedAction.perform(self)
end

function QolcFillPropaneAction:new(Character, Pump, Tank, Time)
	local Action = ISBaseTimedAction.new(self, Character)
	Action.character = Character
	Action.pump = Pump
	Action.tank = Tank
	Action.maxTime = Time or 120
	Action.stopOnWalk = true
	Action.stopOnRun = true

	if Character:isTimedActionInstant() then Action.maxTime = 1 end

	return Action
end
