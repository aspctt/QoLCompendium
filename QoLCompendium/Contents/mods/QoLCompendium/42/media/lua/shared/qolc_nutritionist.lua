--// The Nutritionist
--// The Nutritionist, Workshop 1934095105 - Original idea
--// aspctt - 18.08.2026
--// A magazine that teaches the Nutritionist trait, so food tooltips start showing
--// calories, proteins, fat and carbohydrates.
--//
--// Narrower than it sounds, and narrower than the original's own description. Food.DoTooltip
--// prints the whole breakdown for any packaged item already, to any character who is
--// literate, has light to read by, and whose item carries no NoLabel flag. So the trait
--// only earns its keep on the 595 unpackaged foods, against the 127 that come in a tin or
--// a box: fresh produce, meat, foraged food and everything cooked. That label rule looks
--// like a build 42 addition, which is why a build 41 mod would have promised more.
--//
--// The base game has no way to learn a trait after character creation. Nothing in its
--// lua adds one outside CharacterCreationProfession, so the only routes to this reading
--// are spending two points at the start or taking Fitness Instructor, who gets it free.
--//
--// Rewritten rather than ported, because build 42 replaced the trait API outright:
--//
--//   getTraits()                          getCharacterTraits()
--//   traits:contains("Nutritionist2")     Traits:get(CharacterTrait.NUTRITIONIST2)
--//   traits:add("Nutritionist2")          Traits:add(CharacterTrait.NUTRITIONIST2)
--//
--// The strings are gone with them; every one of those calls now takes a CharacterTrait.
--//
--// The original also swapped ReadLiterature out of the character's metatable for the
--// duration of the read and put it back afterwards, to stop vanilla recording the
--// magazine as read. That is not needed: vanilla recording it is harmless, and a
--// metatable left swapped by an error in between would break reading for the session.
--//
--// Nutritionist2 rather than Nutritionist, matching the original and the Fitness
--// Instructor. The two are mutually exclusive in character_traits.txt, and the second is
--// the free profession version, so granting it cannot refund the two points the first
--// one costs. Food.DoTooltip accepts either.
--//
--// Shared, because the trait has to be taught by whichever side is in charge of the
--// character. The first version was a client file that added it in perform, which only
--// ever ran on the reader's machine. In multiplayer the server never learned of it, and
--// the next trait sync it sent took it away again: every finished read sends one, and
--// CharacterTraits.read resets the list before filling it from the packet.
--//
--// So the teaching moved to complete, which the game only runs on the side in charge.
--// IsoGameCharacter calls it straight after perform unless GameClient.client, and on a
--// server NetTimedAction.perform calls it when the reader's action finishes there. The
--// server then sends the new list itself with PF_Traits. Vanilla's complete already sends
--// the same packet, but before this has added anything, so it carries the old list.
--//
--// A server never calls start or perform, only serverStart and complete, so the line the
--// character says stays in perform, on the reader's side. Whether there is anything to
--// learn is settled in start rather than in perform, because in multiplayer the client
--// waits for the server to finish the action first, and by then the synced trait may
--// already be there and read as known.

require "TimedActions/ISReadABook"

--// Tuning
local MAGAZINE = "Base.QolcNutritionistMag"

-- SyncPlayerFieldsPacket.PF_Traits, which writes the reader's whole trait list
local PF_TRAITS = 0x02

--// Functions
local function Enabled()
	local Vars = SandboxVars and SandboxVars.QoLC
	local Value = Vars and Vars.NutritionistMagEnabled

	if Value ~= nil then return Value and true or false end
	return true
end

local function AlreadyKnows(Character)
	return Character:hasTrait(CharacterTrait.NUTRITIONIST)
		or Character:hasTrait(CharacterTrait.NUTRITIONIST2)
end

local function Teach(Character)
	if AlreadyKnows(Character) then return false end

	local Traits = Character.getCharacterTraits and Character:getCharacterTraits()
	if not Traits then return false end

	Traits:add(CharacterTrait.NUTRITIONIST2)
	return true
end

local function IsTeachingRead(Action)
	local Item = Action.item
	if not Item or not Item.getFullType then return false end

	return Enabled() and Item:getFullType() == MAGAZINE
end

--// Overrides
-- Taken after vanilla's start, which on a multiplayer client swaps the item for the copy
-- in the reader's own inventory
local VanillaStart = ISReadABook.start

function ISReadABook:start(...)
	local Result = VanillaStart(self, ...)

	self.QolcLearnsNutrition = IsTeachingRead(self)
		and self.character ~= nil
		and not AlreadyKnows(self.character)

	return Result
end

local VanillaPerform = ISReadABook.perform

function ISReadABook:perform(...)
	-- Vanilla's perform is what consumes or puts back the item, so it goes first and its
	-- return value is handed straight back
	local Result = VanillaPerform(self, ...)

	if self.QolcLearnsNutrition and self.character then
		self.character:Say(getText("IGUI_QoLC_LearnedNutrition"))
	end

	return Result
end

-- complete rather than update, so the trait lands when the read finishes rather than on
-- the first page. Anything that stops the action part way leaves the reader as they were.
local VanillaComplete = ISReadABook.complete

function ISReadABook:complete(...)
	local Result = VanillaComplete(self, ...)

	-- Vanilla bails out of a read the server stopped without syncing anything, so this
	-- does too
	if self.forceStopped then return Result end
	if not self.character or not IsTeachingRead(self) then return Result end
	if not Teach(self.character) then return Result end

	-- A no-op anywhere but a server, where it goes to the reader alone
	sendSyncPlayerFields(self.character, PF_TRAITS)

	return Result
end
