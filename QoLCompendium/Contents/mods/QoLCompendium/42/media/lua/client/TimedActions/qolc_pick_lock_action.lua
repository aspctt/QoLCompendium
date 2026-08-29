--// Pick A Door Lock
--// Lockpicking. Just. Lockpicking., Workshop 2056238799
--// FMJ - Original, MeTaLAnGeR - IWBUMS update, Oh God Spiders No - streamlining
--// aspctt - 18.08.2026
--// Works a lockpick into a door lock. Succeeding unlocks it for good, failing jams the
--// lock so nothing will ever open it again, and either way the pick can bend or snap.
--//
--// The chance and the timing are the original's, kept whole. What changed is everything
--// underneath: build 42 removed the string form of HasTrait, moved every named stat
--// accessor onto CharacterStat, and dropped four of the five sounds this played.
--//
--// Client only. The action is queued by the player who started it, and vanilla's own
--// door unlocking is client driven in the same way.

require "TimedActions/ISBaseTimedAction"

QolcPickLockAction = ISBaseTimedAction:derive("QolcPickLockAction")

--// Tuning
-- The original's numbers. Chance is a one in N roll, so smaller is better, and the floor
-- of four keeps even a panicking novice from being certain to fail.
local BASE_CHANCE = 8
local WORST_CHANCE = 4

-- A jammed lock is recorded as level six, one past the five real difficulties.
local JAMMED = 6

-- Vanilla's own key ids run from zero upwards, so a negative one can never match.
local NO_KEY = -2

local XP_PER_PICK = 2

--// Functions
-- Panic is one to a hundred. Every ten points costs a point of chance, as the original
-- had it, rounded rather than truncated.
local function PanicPenalty(Player, Divisor)
	local Panic = Player:getStats():get(CharacterStat.PANIC) or 0
	return math.floor((Panic / Divisor) + 0.5)
end

-- The original carried its own Nimble Fingers trait. Build 42 will not take one: a
-- character_trait_definition binds to a CharacterTrait, and those are compiled constants
-- on the java class with no script type that registers a new one, so a definition naming
-- an unknown trait loads with a null type and takes every script after it down with it.
--
-- The bonus rides on Burglar instead, which exists, is granted by the profession of the
-- same name, and is who the original's trait described anyway.
function QolcHasNimbleFingers(Player)
	return Player:hasTrait(CharacterTrait.BURGLAR)
end

local function HasNimbleFingers(Player)
	return QolcHasNimbleFingers(Player)
end

-- Chance to pick, affected by Lightfoot, the lock, panic, and four traits.
function QolcPickLockChance(Player, LockLevel)
	local Chance = math.floor(
		(BASE_CHANCE + Player:getPerkLevel(Perks.Lightfoot)) - (LockLevel or 0))

	Chance = Chance - PanicPenalty(Player, 10)

	if HasNimbleFingers(Player) then Chance = Chance + 4 end
	if Player:hasTrait(CharacterTrait.KEEN_HEARING) then Chance = Chance + 3 end

	-- The original also swung this by Lucky and Unlucky. Build 42 removed both traits
	-- outright, so there is nothing left to read and the roll is that much flatter.
	if Player:hasTrait(CharacterTrait.HARD_OF_HEARING) then Chance = Chance - 2 end

	return math.max(WORST_CHANCE, Chance)
end

--// The Action
-- Both hands are checked every tick, because dropping either one mid pick should stop it.
function QolcPickLockAction:isValid()
	local Primary = self.character:getPrimaryHandItem()
	local Secondary = self.character:getSecondaryHandItem()
	if not Primary or not Secondary then return false end

	-- Whatever counts as a screwdriver, not an item literally called one. The menu offers
	-- this for a multitool, and an action that then refused would be worse than no option.
	return QolcIsScrewdriver(Primary) and Secondary:getType() == "QolcLockpick"
end

function QolcPickLockAction:start()
	self:setActionAnim("Disassemble")

	-- The item rather than a model name, so a multitool is drawn as a multitool.
	self:setOverrideHandModels(self.character:getPrimaryHandItem(), nil)

	self.sound = getSoundManager():PlayWorldSound(
		"QolcLockpicking", false, self.object:getSquare(), 0, 8, 1, true)
end

function QolcPickLockAction:stop()
	if self.sound then self.sound:stop() end

	luautils.equipItems(self.character, self.storedPrim, self.storedScnd)
	ISBaseTimedAction.stop(self)
end

function QolcPickLockAction:perform()
	if self.sound then self.sound:stop() end

	local Player = self.character
	local Door = self.object
	local ModData = Door:getModData()
	local Pick = Player:getSecondaryHandItem()
	local Level = Player:getPerkLevel(Perks.Lightfoot)
	local Chance = QolcPickLockChance(Player, ModData.QolcLockLevel)

	if ZombRand(Chance) == 0 then
		-- Jammed. The key id is invalidated too, so the door's own key stops working:
		-- the lock is wrecked, not merely still locked.
		ModData.QolcLockLevel = JAMMED
		Door:setKeyId(NO_KEY)
		getSoundManager():PlayWorldSound("DoorIsLocked", false, Door:getSquare(), 0, 12, 1, true)
	else
		Door:setLockedByKey(false)
		getSoundManager():PlayWorldSound("UnlockDoor", false, Door:getSquare(), 0, 6, 1, true)
		Player:getXp():AddXP(Perks.Lightfoot, XP_PER_PICK)
	end

	-- Two separate rolls, as the original had them: the pick can stick in the lock, or
	-- snap. Either way it is gone, and a higher Lightfoot makes snapping rarer.
	if ZombRand(Chance) == 0 then
		Player:Say(getText("IGUI_QoLC_PickStuck"))
		QolcDestroyPick(Player, Pick)
	elseif ZombRand(100) <= 30 - (Level * 2) then
		getSoundManager():PlayWorldSound("ArmourBreakMetal", false, Player:getSquare(), 0, 10, 1, true)
		Player:Say(getText("IGUI_QoLC_PickBroken"))
		QolcDestroyPick(Player, Pick)
	end

	luautils.equipItems(Player, self.storedPrim, self.storedScnd)
	ISBaseTimedAction.perform(self)
end

-- Out of the hand and out of the bag. The original took it out of both and would throw if
-- the item had no container, which happens when it is the one in your hands.
function QolcDestroyPick(Player, Pick)
	if not Pick then return end

	Player:setSecondaryHandItem(nil)

	local Container = Pick:getContainer()
	if Container then Container:Remove(Pick) end
end

function QolcPickLockAction:new(Character, Object, Time, StoredPrim, StoredScnd)
	local Action = ISBaseTimedAction.new(self, Character)
	Action.character = Character
	Action.object = Object
	Action.storedPrim = StoredPrim
	Action.storedScnd = StoredScnd
	Action.stopOnWalk = true
	Action.stopOnRun = true
	Action.maxTime = Time

	if Character:isTimedActionInstant() then Action.maxTime = 1 end

	return Action
end
