--// Fill Propane From Pump
--// Pumps Have Propane, Workshop 2739570406 - Original idea, by Uncle Griz
--// aspctt - 10.08.2026
--// Fills a propane tank at a working fuel pump, drawing on the pump's own supply so it
--// is not free and a pump can be emptied.
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

function QolcFillPropaneAction:update()
	self.character:faceThisObject(self.pump)
	self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

function QolcFillPropaneAction:start()
	self:setActionAnim("Loot")
	self.sound = self.character:playSound("GeneratorAddFuel")
end

function QolcFillPropaneAction:stop()
	if self.sound then self.character:stopOrTriggerSound(self.sound) end
	ISBaseTimedAction.stop(self)
end

function QolcFillPropaneAction:perform()
	if self.sound then self.character:stopOrTriggerSound(self.sound) end

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
