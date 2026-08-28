--// Butcher Corpse Menu
--// Def's Long Term Survival, Workshop 1962914415 - Original idea, by DefbeatCZ
--// aspctt - 28.08.2026
--// Puts "Butcher Corpse" on a body lying on the ground.
--//
--// A body is an IsoDeadBody world object, not an item in a container, so this is the only
--// place the option can go. See qolc_butcher_corpse_action.lua for why the recipe that
--// used to do this could never fire.
--//
--// Bodies are found with square:getStaticMovingObjects, which is what vanilla's own Grab
--// Corpse menu walks. The clicked square only: adjacent squares are what Grab Corpse
--// searches because you can reach across for something you are picking up, and butchering
--// one you are not stood over would be a surprise.
--//
--// Client only. The context menu is a client concern and the timed action it queues is
--// shared, which is where the work happens.

require "TimedActions/qolc_butcher_corpse_action"

--// Tuning
-- The same edge the recipes ask for, so a cleaver works on the body and on the flesh after.
-- ItemTag objects rather than strings: getFirstTagEvalRecurse takes the constant, which is
-- how vanilla's own animal butchering menu finds its knife.
local BLADE_TAGS = { ItemTag.SHARP_KNIFE, ItemTag.MEAT_CLEAVER }

-- Long enough to feel like work, and the same figure the original used.
local BUTCHER_TIME = 240

--// Switch
local function QolcEnabled()
	if QolcCorpseDisposalEnabled then return QolcCorpseDisposalEnabled() end

	local Vars = SandboxVars and SandboxVars.QoLC
	local Value = Vars and Vars.CorpseDisposalEnabled

	if Value ~= nil then return Value and true or false end
	return false
end

--// Functions
-- Hoisted rather than built per call. getFirstTagEvalRecurse takes a LuaClosure, and a
-- fresh one on every context menu is a fresh closure handed across to java each time.
local function NotBroken(Item)
	return not Item:isBroken()
end

local function FindBlade(Player)
	local Inventory = Player:getInventory()
	if not Inventory then return nil end

	for _, Tag in ipairs(BLADE_TAGS) do
		local Found = Inventory:getFirstTagEvalRecurse(Tag, NotBroken)
		if Found then return Found end
	end

	return nil
end

-- Every body on the square, skeletons excluded. There is nothing on a skeleton to cut off,
-- and offering the option would be a promise the action could not keep.
local function BodiesOn(Square)
	local Found = {}
	if not Square then return Found end

	local Objects = Square:getStaticMovingObjects()
	if not Objects then return Found end

	for Index = 0, Objects:size() - 1 do
		local Body = Objects:get(Index)
		if Body and Body.isSkeleton and not Body:isSkeleton() then
			table.insert(Found, Body)
		end
	end

	return Found
end

local function Butcher(Player, Body, Knife)
	if luautils.walkAdj(Player, Body:getSquare()) then
		ISTimedActionQueue.add(QolcButcherCorpseAction:new(Player, Body, Knife, BUTCHER_TIME))
	end
end

--// Connections
local function OnFillWorldObjectContextMenu(PlayerNum, Context, WorldObjects, Test)
	if Test then return end
	if not QolcEnabled() then return end

	local Player = getSpecificPlayer(PlayerNum)
	if not Player then return end

	local Square = nil
	for _, Object in ipairs(WorldObjects) do
		Square = Object.getSquare and Object:getSquare()
		if Square then break end
	end

	local Bodies = BodiesOn(Square)
	if #Bodies == 0 then return end

	local Knife = FindBlade(Player)
	local Option = Context:addOption(getText("ContextMenu_QoLC_ButcherCorpse"), WorldObjects,
		function() Butcher(Player, Bodies[1], Knife) end)

	-- Shown but refused without an edge, so the reason is on screen rather than the option
	-- simply not being there and looking like the feature is missing.
	if not Knife then
		Option.notAvailable = true
		local Tip = ISWorldObjectContextMenu.addToolTip()
		Tip.description = getText("Tooltip_QoLC_ButcherCorpseNoKnife")
		Option.toolTip = Tip
	end
end

Events.OnFillWorldObjectContextMenu.Add(OnFillWorldObjectContextMenu)
