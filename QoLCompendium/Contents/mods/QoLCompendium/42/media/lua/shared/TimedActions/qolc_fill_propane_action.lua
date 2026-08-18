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
--// Shared, because a timed action has to exist on both sides in multiplayer.

require "TimedActions/ISBaseTimedAction"

QolcFillPropaneAction = ISBaseTimedAction:derive("QolcFillPropaneAction")

--// Tuning
-- Matches the default declared in 42/media/sandbox-options.txt, used when a save has no
-- value stored for it.
local DEFAULT_COST = 20

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

	local Missing = 1 - self.tank:getCurrentUsesFloat()
	if Missing <= 0 then
		ISBaseTimedAction.perform(self)
		return
	end

	-- Never take more than the pump has left, so a nearly dry pump gives a part fill
	-- rather than a free full one
	local Available = self.pump:getPipedFuelAmount()
	local Wanted = QolcFillPropaneAction.GetCost() * Missing
	local Spent = Wanted

	if Spent > Available then Spent = Available end

	local Filled = Missing
	if Wanted > 0 then Filled = Missing * (Spent / Wanted) end

	self.tank:setCurrentUsesFloat(self.tank:getCurrentUsesFloat() + Filled)
	self.pump:setPipedFuelAmount(math.floor(Available - Spent))

	-- Drainables carry their charge across the network as an item field
	if self.tank.syncItemFields then self.tank:syncItemFields() end

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
