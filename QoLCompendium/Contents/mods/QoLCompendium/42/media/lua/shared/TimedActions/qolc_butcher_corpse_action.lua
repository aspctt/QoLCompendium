--// Butcher Corpse Action
--// Def's Long Term Survival, Workshop 1962914415 - Original idea, by DefbeatCZ
--// aspctt - 28.08.2026
--// Cuts a body on the ground into flesh, and removes it.
--//
--// This is a world action rather than a crafting recipe, and it took a bug report to find
--// out why. A human corpse never reaches a container the crafting screen can see:
--//
--//   Carried, it is a grapple. ISGrabCorpseItem branches on the full type, and only
--//   Base.CorpseAnimal goes into the inventory and both hands. A human body instead goes
--//   through IsoGameCharacter.pickUpCorpseItem, which the jar shows refusing outright
--//   while already grappling, because dragging a body is the grapple system.
--//
--//   On the ground, it is an IsoDeadBody world object rather than an item on the floor.
--//   Vanilla finds them with square:getStaticMovingObjects, which is what the Grab Corpse
--//   menu walks, and there is no container involved at any point.
--//
--// So a recipe naming Base.CorpseMale could never fire, which is exactly what was
--// reported: the entry appears in the crafting screen and nothing ever satisfies it. The
--// two later stages are ordinary recipes and stay that way, because prepared and cured
--// flesh are ordinary items.
--//
--// Shared, so both sides have it. The action runs wherever it was queued and the body is
--// removed through removeFromWorld, which is what vanilla's own corpse handling calls.

require "TimedActions/ISBaseTimedAction"

QolcButcherCorpseAction = ISBaseTimedAction:derive("QolcButcherCorpseAction")

--// Tuning
local FLESH = "Base.QolcCorpseFlesh"

-- The original's figure. A body is three pieces of anything worth carrying.
local YIELD = 3

-- Vanilla awards butchering experience per item taken off a carcass, through
-- ButcheringUtil.giveItems, and AnimalPartsDefinitions sets the rate per animal: 25 for a
-- deer or a grown cow, 18 for a boar or a calf, 10 for a sheep, 7 for a hen. A body is a
-- boar, near enough, so 18. Three pieces makes 54 for the whole job, against the several
-- hundred a deer gives, which is right: this is a knife in a field, not a full break down
-- on a hook.
local XP_PER_PIECE = 18

--// The Action
function QolcButcherCorpseAction:isValid()
	if not self.body then return false end
	if not self.body:getSquare() then return false end

	return self.character:getInventory():contains(self.knife)
end

function QolcButcherCorpseAction:waitToStart()
	self.character:faceThisObject(self.body)
	return self.character:shouldBeTurning()
end

function QolcButcherCorpseAction:update()
	self.character:faceThisObject(self.body)
	self.character:setMetabolicTarget(Metabolics.HeavyWork)
end

function QolcButcherCorpseAction:start()
	-- Vanilla's own butchering shape: crouched over the thing, looting animation.
	self:setActionAnim("Loot")
	self.character:SetVariable("LootPosition", "Low")
	self:setOverrideHandModels(self.knife, nil)
end

function QolcButcherCorpseAction:stop()
	ISBaseTimedAction.stop(self)
end

function QolcButcherCorpseAction:perform()
	local Inventory = self.character:getInventory()
	local Square = self.body:getSquare()

	-- Handed over rather than dropped. Butchering an animal puts the meat in your hands and
	-- this should not behave differently, and three pieces left in the grass beside a body
	-- you have just removed is easy to walk away from without noticing.
	--
	-- The square is the fallback for a character with no inventory at all, which should not
	-- happen but is cheaper to allow for than to have the flesh vanish if it does.
	--
	-- sendAddItemToContainer after each one, which is what vanilla's own butchering does in
	-- ButcheringUtil.giveItems. It is a no-op unless GameServer.server, so it costs nothing
	-- where it does not apply and is correct where it does.
	for _ = 1, YIELD do
		local Flesh = instanceItem(FLESH)

		if Inventory then
			Inventory:AddItem(Flesh)
			if sendAddItemToContainer then sendAddItemToContainer(Inventory, Flesh) end
		elseif Square then
			Square:AddWorldInventoryItem(Flesh, 0, 0, 0)
		end
	end

	-- getXp():AddXP rather than the addXp global, which is what vanilla's butchering calls.
	-- The global is LuaManager.GlobalObject.addXp, and the jar shows it handing off to
	-- GameServer.addXp when this is the server and otherwise doing nothing at all unless
	-- GameClient.client is false. Vanilla gets away with it because butchering an animal is
	-- driven from the server. This is a client queued action, so on a server it would award
	-- nothing. XP.AddXP takes the local player branch and works on both.
	if self.character.getXp and Perks and Perks.Butchering then
		self.character:getXp():AddXP(Perks.Butchering, XP_PER_PIECE * YIELD)
	end

	-- removeCorpse, not removeFromWorld and removeFromSquare. A corpse is not an ordinary
	-- world object: IsoGridSquare.removeCorpse sends RemoveCorpseFromMap, from a client to
	-- the server and from a server out to everyone near it, calls checkAddedRemovedItems so
	-- the body's own container is reconciled, invalidates the render chunk, and only then
	-- does the same two removals this used to do on its own. It finishes by triggering
	-- OnContainerUpdate, which is how the inventory panel learns to redraw.
	--
	-- Vanilla removes every carcass this way, three times over in ButcheringUtil, and the
	-- one place that tried the bare pair, ISGetAnimalBones, has them commented out.
	if Square and Square.removeCorpse then
		Square:removeCorpse(self.body, false)
	else
		self.body:removeFromWorld()
		self.body:removeFromSquare()
	end

	if self.knife then
		self.knife:setCondition(self.knife:getCondition() - 1)
	end

	ISBaseTimedAction.perform(self)
end

function QolcButcherCorpseAction:new(Character, Body, Knife, Time)
	local Action = ISBaseTimedAction.new(self, Character)
	Action.character = Character
	Action.body = Body
	Action.knife = Knife
	Action.stopOnWalk = true
	Action.stopOnRun = true
	Action.maxTime = Time

	if Character:isTimedActionInstant() then Action.maxTime = 1 end

	return Action
end
