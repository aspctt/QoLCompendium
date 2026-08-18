--// Reading Is Not Boring
--// Reading is not boring., Workshop 1949441990 - Original idea
--// aspctt - 18.08.2026
--// Reading a skill book settles a character a little instead of leaving them to stew.
--// Boredom, unhappiness and stress each ease off as the pages turn.
--//
--// The base game does close to the opposite. BodyDamage.UpdateBoredom mentions reading
--// exactly once, in the case of sitting in a stopped vehicle, and there it only slows
--// the rate boredom climbs to a fifth. Everywhere else a skill book does nothing for
--// morale at all, while a comic book fixes it outright. There is a boredomDecreaseFromReading
--// field on BodyDamage with public accessors, but it is written once in the constructor
--// and read only by its own getter, so nothing in the game acts on it.
--//
--// Rewritten rather than ported. Build 42 removed every stat accessor the original used,
--// replacing the named pairs with one keyed by CharacterStat:
--//
--//   getBoredomLevel / setBoredomLevel           CharacterStat.BOREDOM
--//   getUnhappynessLevel / setUnhappynessLevel   CharacterStat.UNHAPPINESS
--//   getStress / setStress                       CharacterStat.STRESS
--//   getStressFromCigarettes                     getNicotineStress
--//   HasTrait("FastReader")                      hasTrait(CharacterTrait.FAST_READER)
--//
--// Three deliberate changes on top of that, each noted where it happens: pages are
--// counted off the action rather than the item, only skill books qualify, and the
--// nicotine part of stress is left alone rather than discarded.
--//
--// Client only. These are the reading player's own stats, and in multiplayer a server
--// has no business editing a player's moodles.

require "TimedActions/ISReadABook"

--// Tuning
-- Shares of what is left, taken once for each update that turns a page, so the effect
-- eases off rather than driving a stat to zero. Under the threshold the smaller share
-- applies, which keeps a nearly settled character from being settled instantly.
local BOREDOM_STEP = { Threshold = 25, Under = 0.05, Over = 0.10 }
local UNHAPPY_STEP = { Threshold = 45, Under = 0.02, Over = 0.05 }
local STRESS_STEP = { Threshold = 0.5, Under = 0.02, Over = 0.05 }

-- A fast reader turns more pages in the same minute, so each page is worth less to them.
-- Without this the trait would quietly double as a morale trait.
local TRAIT_RATE = { Fast = 0.7, Slow = 1.3, Normal = 1.0 }

-- Being ill takes the good out of it. Full effect at 25 apparent infection and below,
-- nothing at 75 and above.
local SICK_FULL, SICK_NONE = 25, 75

local DEFAULT_RATE = 100

--// Functions
local function GetSandbox(Name, Default)
	local Vars = SandboxVars and SandboxVars.QoLC
	local Value = Vars and Vars[Name]

	if Value ~= nil then return Value end
	return Default
end

local function Enabled()
	return GetSandbox("ReadingCalmEnabled", true) and true or false
end

-- Server controlled scale on the whole thing, as a percentage.
local function RateSetting()
	local Percent = tonumber(GetSandbox("ReadingCalmRate", DEFAULT_RATE)) or DEFAULT_RATE
	return Percent / 100
end

-- Only skill books. The original fired on anything with pages, which stacked on top of
-- the morale a comic book or newspaper already gives through its own UnhappyChange, and
-- the mod's own description asks for skill books.
local function IsSkillBook(Item)
	if not Item or not Item.getSkillTrained then return false end

	local Skill = Item:getSkillTrained()
	if not Skill then return false end

	return SkillBook[Skill] ~= nil
end

local function TraitRate(Character)
	if Character:hasTrait(CharacterTrait.FAST_READER) then return TRAIT_RATE.Fast end
	if Character:hasTrait(CharacterTrait.SLOW_READER) then return TRAIT_RATE.Slow end

	return TRAIT_RATE.Normal
end

local function SicknessRate(Character)
	local Body = Character.getBodyDamage and Character:getBodyDamage()
	if not Body then return 1 end

	local Level = Body:getApparentInfectionLevel() or 0
	local Share = (SICK_NONE - Level) / (SICK_NONE - SICK_FULL)

	if Share < 0 then return 0 end
	if Share > 1 then return 1 end

	return Share
end

-- Takes a share of whatever sits above Floor, and leaves Floor itself alone.
local function Ease(Stats, Stat, Step, Rate, Floor)
	Floor = Floor or 0

	local Value = Stats:get(Stat)
	local Above = Value - Floor
	if Above <= 0 then return end

	local Share = (Above < Step.Threshold) and Step.Under or Step.Over
	Stats:set(Stat, Value - (Above * Share * Rate))
end

local function Settle(Character)
	local Stats = Character:getStats()
	if not Stats then return end

	local Rate = TraitRate(Character) * SicknessRate(Character) * RateSetting()
	if Rate <= 0 then return end

	Ease(Stats, CharacterStat.BOREDOM, BOREDOM_STEP, Rate)
	Ease(Stats, CharacterStat.UNHAPPINESS, UNHAPPY_STEP, Rate)

	-- Stress carried by nicotine withdrawal is left where it is. A cigarette fixes that,
	-- a book does not. The original subtracted it and then wrote the remainder back,
	-- which cleared the withdrawal outright rather than protecting it.
	Ease(Stats, CharacterStat.STRESS, STRESS_STEP, Rate, Stats:getNicotineStress())
end

-- Vanilla's own formula out of ISReadABook:update, read off the action rather than the
-- item. The item's page count is only advanced inside "if not isClient()", so on a
-- multiplayer client it never moves and the original never fired at all.
local function PagesRead(Action)
	local Item = Action.item
	local Total = Item and Item:getNumberOfPages() or 0
	if Total <= 0 then return 0 end

	return math.floor(Total * Action:getJobDelta())
end

--// Overrides
local VanillaUpdate = ISReadABook.update

function ISReadABook:update(...)
	local Result = VanillaUpdate(self, ...)

	if Enabled() and self.character and IsSkillBook(self.item) then
		local Read = PagesRead(self)

		-- Once per update that turned at least one page, matching the original, rather
		-- than once per page. A restart can jump the count by more than one.
		if Read > (self.QolcPagesRead or 0) then
			self.QolcPagesRead = Read
			Settle(self.character)
		end
	end

	return Result
end
