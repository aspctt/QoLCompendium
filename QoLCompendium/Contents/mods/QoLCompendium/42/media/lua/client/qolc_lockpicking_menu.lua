--// Lockpicking Menu
--// Lockpicking. Just. Lockpicking., Workshop 2056238799
--// FMJ - Original, MeTaLAnGeR - IWBUMS update, Oh God Spiders No - streamlining
--// aspctt - 18.08.2026
--// Right click a locked exterior door or a locked window and, with the tools and the
--// know how, pick it or force it.
--//
--// One file where the original had two, because a door and a window ask the same three
--// questions: is it locked and shut, do you have the tool, and have you learned how.
--//
--// Every lock gets a difficulty the first time it is looked at, kept in the door's mod
--// data, so a door is as hard the second time as the first. Level six means jammed,
--// which is what a failed pick leaves behind.
--//
--// Client only. The menu is a client concern and the actions it queues are client side.

require "luautils"

--// Tuning
-- What counts as a crowbar or a screwdriver lives in shared/qolc_lock_tools.lua, so the
-- menu and the actions it queues cannot disagree about it.

-- Picking is gated on a real recipe the first volume teaches. Forcing cannot be, because
-- the game refuses a LearnedRecipes entry that matches no recipe, so it is a flag on the
-- character read through QolcKnowsForcing in qolc_lockpicking_learn.lua.
local KNOWS_PICKING = "QolcMakeLockpickFromHairpin"

local LOCK_LEVELS = 5
local JAMMED = 6

-- The original's timings, in the same shape: a base, a step per level of difficulty, and
-- a spread, all multiplied by how badly the character is panicking.
local PICK_BASE, PICK_STEP, PICK_SPREAD = 250, 10, 75
local BREAK_BASE, BREAK_STEP = 150, 10
local WINDOW_TIME = 60

local TIME_FLOOR, TIME_CEILING = 10, 500

--// Functions
local function GetSandbox(Name, Default)
	local Vars = SandboxVars and SandboxVars.QoLC
	local Value = Vars and Vars[Name]

	if Value ~= nil then return Value end
	return Default
end

-- Two switches rather than one, since a player asked for the halves apart. Picking is the
-- pick, the screwdriver and the recipe; prying is the crowbar. Both default on, so a save
-- that predates the split keeps what it already had.
local function PickingEnabled()
	return GetSandbox("LockpickingEnabled", true) and true or false
end

local function PryingEnabled()
	return GetSandbox("PryingEnabled", true) and true or false
end

local function Clamp(Time)
	if Time < TIME_FLOOR then return TIME_FLOOR end
	if Time > TIME_CEILING then return TIME_CEILING end

	return math.floor(Time)
end

-- isRecipeActuallyKnown, not isRecipeKnown. The short name looks the recipe up in the
-- build 41 table, finds nothing because everything here is a craftRecipe, and falls back
-- on the SeeNotLearntRecipe sandbox option, which ships on. It says yes to anyone. This
-- form skips it and reads the character's own list, the way the crafting screen does.
local function Knows(Player, Recipe)
	return Player:isRecipeActuallyKnown(Recipe)
end

-- Locks are rolled once and remembered. Reading it here rather than at spawn means only
-- the doors a player actually looks at ever get one.
local function LockLevel(Object)
	local ModData = Object:getModData()

	if not ModData.QolcLockLevel or ModData.QolcLockLevel < 1 then
		ModData.QolcLockLevel = ZombRand(LOCK_LEVELS) + 1
	end

	return ModData.QolcLockLevel
end

local function LevelName(Level)
	return getText("IGUI_QoLC_LockLevel" .. tostring(Level))
end

--// Doors
-- Not isExterior. That reads like "a door on the outside of a house" and is not: it wants
-- this door's own square to carry the exterior flag and the square opposite to be inside
-- a building. Which of the two squares a door object belongs to is invisible to a player,
-- so a good half of the front doors in the world answer false, which showed up in game as
-- a locked double door offering nothing with every tool in hand.
--
-- The question worth asking is whether the door is the way in: one side inside a building
-- and the other not. isExterior is still taken as a fast yes where the game offers one.
local function IsWayIn(Object)
	if Object.isExterior and Object:isExterior() then return true end

	local Square = Object.getSquare and Object:getSquare()
	local Opposite = Object.getOppositeSquare and Object:getOppositeSquare()
	if not Square or not Opposite then return false end

	local Near = Square:getBuilding() ~= nil
	local Far = Opposite:getBuilding() ~= nil

	return Near ~= Far
end

local function IsPickableDoor(Object, Player)
	if not Object then return false end
	if Object:IsOpen() then return false end
	if not Object:isLocked() and not Object:isLockedByKey() then return false end
	if Object:isBarricaded() then return false end

	return IsWayIn(Object)
end

local function PickDoor(_WorldObjects, Door, Player, Screwdriver, Lockpick)
	if LockLevel(Door) >= JAMMED then
		luautils.okModal(getText("IGUI_QoLC_LockJammed"), true)
		return
	end

	local Panic = Player:getStats():get(CharacterStat.PANIC) or 0
	local Steps = math.floor((Panic / 25) + 1)
	local Time = (PICK_BASE + (LockLevel(Door) + 1) * PICK_STEP + ZombRand(PICK_SPREAD)) * Steps

	if QolcHasNimbleFingers(Player) then Time = Time - 50 end
	if Player:hasTrait(CharacterTrait.HANDY) then Time = Time - ZombRand(50) end

	if luautils.walkAdjWindowOrDoor(Player, Door:getSquare(), Door) then
		local Primary, Secondary = luautils.equipItems(Player, Screwdriver, Lockpick)
		ISTimedActionQueue.add(
			QolcPickLockAction:new(Player, Door, Clamp(Time), Primary, Secondary))
	end
end

-- The original read eleven traits here to shift the timing. Out of Shape keeps its name
-- only as a constant now, and every one of these is a hasTrait call rather than a string.
local function BreakTime(Player, Level)
	local Panic = Player:getStats():get(CharacterStat.PANIC) or 0
	local Steps = math.floor((Panic / 40) + 1)
	local Time = BREAK_BASE + (Level + 1) * BREAK_STEP * Steps

	if QolcHasNimbleFingers(Player) then Time = Time / 2 end

	for _, Trait in ipairs({ CharacterTrait.ATHLETIC, CharacterTrait.HANDY, CharacterTrait.STRONG }) do
		if Player:hasTrait(Trait) then Time = Time - ZombRand(25) end
	end

	for _, Trait in ipairs({ CharacterTrait.STOUT, CharacterTrait.FIT }) do
		if Player:hasTrait(Trait) then Time = Time - ZombRand(15) end
	end

	for _, Trait in ipairs({ CharacterTrait.OUT_OF_SHAPE, CharacterTrait.FEEBLE }) do
		if Player:hasTrait(Trait) then Time = Time + ZombRand(15) end
	end

	for _, Trait in ipairs({ CharacterTrait.WEAK, CharacterTrait.ASTHMATIC, CharacterTrait.UNFIT }) do
		if Player:hasTrait(Trait) then Time = Time + ZombRand(25) end
	end

	return Clamp(Time)
end

local function BreakDoor(_WorldObjects, Door, Player, Crowbar)
	if luautils.walkToObject(Player, Door) then
		local Primary, Secondary = luautils.equipItems(Player, Crowbar)
		ISTimedActionQueue.add(
			QolcBreakLockAction:new(Player, Door, BreakTime(Player, LockLevel(Door)),
				Primary, Secondary, false))
	end
end

--// Windows
local function IsForceableWindow(Object)
	if not Object then return false end
	if Object:IsOpen() then return false end
	if Object:isSmashed() or Object:isDestroyed() then return false end
	if Object:isBarricaded() then return false end
	if Object:isPermaLocked() then return false end

	return Object:isLocked()
end

local function ForceWindow(_WorldObjects, Window, Player, Crowbar)
	if luautils.walkToObject(Player, Window) then
		local Primary, Secondary = luautils.equipItems(Player, Crowbar)
		ISTimedActionQueue.add(
			QolcBreakLockAction:new(Player, Window, WINDOW_TIME, Primary, Secondary, true))
	end
end

--// Vehicles
-- Asked for in game, the original having only ever done buildings. A car door is not an
-- IsoDoor: it is a VehicleDoor hanging off a VehiclePart, reached through the vehicle
-- rather than through the objects under the cursor, which is why nothing above ever saw one.
--
-- getUseablePart is what vanilla's own radial menu uses to decide which door you are stood
-- at, and the jar shows it refusing anything over six tiles away, on another floor, or while
-- you are sitting in a vehicle. So standing near the car is the whole of the reach test,
-- exactly as it is for vanilla's own open and lock options.
local ENGINE_DOOR = "EngineDoor"

local function VehiclePartUnder(Player)
	local Vehicle = Player:getUseableVehicle() or Player:getNearVehicle()
	if not Vehicle then return nil end

	local Part = Vehicle:getUseablePart(Player)
	if not Part then return nil end

	-- The bonnet is a door part as well, and picking it makes no sense: vanilla opens it for
	-- anyone who can get inside the car, so its lock is not what is stopping you.
	if Part:getId() == ENGINE_DOOR then return nil end

	-- Not fitted, so there is no lock on it to work.
	if not Part:getInventoryItem() then return nil end

	local Door = Part:getDoor()
	if not Door then return nil end
	if Door:isOpen() then return nil end
	if not Door:isLocked() then return nil end

	return Part, Door
end

-- Rolled once and remembered, the same as a house door. Kept in the part's own mod data,
-- which VehiclePart.save writes out and transmitPartModData carries to a server, so the
-- lock is as hard the second time as the first and as hard for everyone.
local function VehicleLockLevel(Part)
	local ModData = Part:getModData()

	if not ModData.QolcLockLevel or ModData.QolcLockLevel < 1 then
		ModData.QolcLockLevel = ZombRand(LOCK_LEVELS) + 1

		local Vehicle = Part:getVehicle()
		if Vehicle and Vehicle.transmitPartModData then Vehicle:transmitPartModData(Part) end
	end

	return ModData.QolcLockLevel
end

local function WalkToPart(Player, Part)
	ISTimedActionQueue.add(
		ISPathFindAction:pathToVehicleArea(Player, Part:getVehicle(), Part:getArea()))
end

local function PickVehicle(_WorldObjects, Part, Player, Screwdriver, Lockpick)
	-- lockBroken is vanilla's own field and the jar shows canUnlockDoor refusing it, so this
	-- is the same dead end a jammed house lock is, said in the game's own words.
	if Part:getDoor():isLockBroken() then
		luautils.okModal(getText("IGUI_QoLC_LockJammed"), true)
		return
	end

	local Panic = Player:getStats():get(CharacterStat.PANIC) or 0
	local Steps = math.floor((Panic / 25) + 1)
	local Time = (PICK_BASE + (VehicleLockLevel(Part) + 1) * PICK_STEP + ZombRand(PICK_SPREAD)) * Steps

	if QolcHasNimbleFingers(Player) then Time = Time - 50 end
	if Player:hasTrait(CharacterTrait.HANDY) then Time = Time - ZombRand(50) end

	WalkToPart(Player, Part)

	local Primary, Secondary = luautils.equipItems(Player, Screwdriver, Lockpick)
	ISTimedActionQueue.add(
		QolcPickVehicleLockAction:new(Player, Part, Clamp(Time), Primary, Secondary))
end

local function BreakVehicle(_WorldObjects, Part, Player, Crowbar)
	WalkToPart(Player, Part)

	local Primary, Secondary = luautils.equipItems(Player, Crowbar)
	ISTimedActionQueue.add(
		QolcBreakVehicleLockAction:new(Player, Part,
			BreakTime(Player, VehicleLockLevel(Part)), Primary, Secondary))
end

--// Connections
local function FindOne(WorldObjects, Test)
	for _, Object in ipairs(WorldObjects) do
		if Test(Object) then return Object end
	end

	return nil
end

local function OnFillWorldObjectContextMenu(PlayerNum, Context, WorldObjects, Test)
	if Test then return end

	local Picking = PickingEnabled()
	local Prying = PryingEnabled()
	if not Picking and not Prying then return end

	local Player = getSpecificPlayer(PlayerNum)
	if not Player then return end

	local Inventory = Player:getInventory()
	if not Inventory then return end

	local Door = FindOne(WorldObjects, function(Object)
		return instanceof(Object, "IsoDoor")
			or (instanceof(Object, "IsoThumpable") and Object:isDoor())
	end)

	local Crowbar = QolcFindCrowbar(Inventory)
	local Screwdriver = QolcFindScrewdriver(Inventory)
	local Lockpick = QolcFindLockpick(Inventory)

	if Door and IsPickableDoor(Door, Player) then
		local Level = LockLevel(Door)

		if Picking and Screwdriver and Lockpick and Knows(Player, KNOWS_PICKING) then
			Context:addOption(
				getText("ContextMenu_QoLC_PickLock") .. " (" .. LevelName(Level) .. ")",
				WorldObjects, PickDoor, Door, Player, Screwdriver, Lockpick)
		end

		if Prying and Crowbar and QolcKnowsForcing(Player) then
			Context:addOption(
				getText("ContextMenu_QoLC_ForceLock") .. " (" .. LevelName(Level) .. ")",
				WorldObjects, BreakDoor, Door, Player, Crowbar)
		end
	end

	local Window = FindOne(WorldObjects, function(Object)
		return instanceof(Object, "IsoWindow")
	end)

	if Prying and Window and IsForceableWindow(Window) and Crowbar and QolcKnowsForcing(Player) then
		Context:addOption(getText("ContextMenu_QoLC_ForceWindow"),
			WorldObjects, ForceWindow, Window, Player, Crowbar)
	end

	-- Named apart from the house options rather than sharing their text, because a car
	-- parked against a locked front door would otherwise put two identical lines on the menu
	-- with no way to tell which was which.
	local Part = VehiclePartUnder(Player)
	if not Part then return end

	local VehicleLevel = VehicleLockLevel(Part)

	if Picking and Screwdriver and Lockpick and Knows(Player, KNOWS_PICKING) then
		Context:addOption(
			getText("ContextMenu_QoLC_PickVehicleLock") .. " (" .. LevelName(VehicleLevel) .. ")",
			WorldObjects, PickVehicle, Part, Player, Screwdriver, Lockpick)
	end

	if Prying and Crowbar and QolcKnowsForcing(Player) then
		Context:addOption(
			getText("ContextMenu_QoLC_ForceVehicleLock") .. " (" .. LevelName(VehicleLevel) .. ")",
			WorldObjects, BreakVehicle, Part, Player, Crowbar)
	end
end

Events.OnFillWorldObjectContextMenu.Add(OnFillWorldObjectContextMenu)
