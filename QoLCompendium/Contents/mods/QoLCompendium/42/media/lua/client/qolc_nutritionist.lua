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
--// Client only. The tooltip is drawn client side and the trait is the reading player's.

require "TimedActions/ISReadABook"

--// Tuning
local MAGAZINE = "Base.QolcNutritionistMag"

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

--// Overrides
-- perform rather than update, so the trait lands when the read finishes rather than on
-- the first page. Anything that stops the action part way leaves the reader as they were.
local VanillaPerform = ISReadABook.perform

function ISReadABook:perform(...)
	local Item = self.item
	local Teachable = Enabled() and Item and Item:getFullType() == MAGAZINE

	-- Vanilla's perform is what consumes or puts back the item, so it goes first and its
	-- return value is handed straight back
	local Result = VanillaPerform(self, ...)

	if Teachable and self.character and Teach(self.character) then
		self.character:Say(getText("IGUI_QoLC_LearnedNutrition"))
	end

	return Result
end
