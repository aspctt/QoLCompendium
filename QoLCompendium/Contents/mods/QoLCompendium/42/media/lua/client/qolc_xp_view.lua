--// Fix XP View
--// Fix XP View, Workshop 2341974040 - Original idea
--// aspctt - 11.08.2026
--// The game advertises a profession's experience boost as "+75%", which reads as "a bit
--// over half again". It is nothing of the sort. An unboosted skill earns a quarter rate,
--// so the first boost is four times what you would otherwise get. This shows the number
--// people actually want.
--//
--// Read out of IsoGameCharacter.XP.AddXP in this build rather than carried over:
--//
--//   boost 0                                  xp * 0.25
--//   boost 1 and the perk is Sprinting        xp * 1.25
--//   boost 1                                  xp * 1.0
--//   boost 2, unless excluded                 xp * 1.33
--//   boost 3 or more, unless excluded         xp * 1.66
--//
--// where excluded means Fitness or Strength. Against the unboosted quarter that gives
--// x4, x5.32 and x6.64 for most skills, x5 for Sprinting's first boost, and a flat x4 at
--// every level for Fitness and Strength, which gain nothing from the second and third.
--//
--// Rewritten rather than ported, and the original is worth not copying twice over.
--//
--// It crashes build 42. It installs its own function over the global getText for the
--// duration of the tooltip, and inside that function calls player:HasTrait("Pacifist"),
--// which build 42 removed in favour of hasTrait(CharacterTrait). The error escapes before
--// the original getText is put back, so every later call to it fails and the interface
--// stops responding while the game keeps running. Nothing here touches a global.
--//
--// Its numbers are also wrong now. It shows Sprinting's first boost as x1.25, which is
--// the raw multiplier rather than the ratio, and shows nothing at all for Fitness and
--// Strength when their first boost is a real x4.
--//
--// Only the boost is reported, not the character's whole experience rate. Vanilla labels
--// this line "XP Boost" and fills it from getPerkBoost alone, so folding in Fast Learner,
--// Pacifist or build 42's new Crafty trait would answer a different question than the one
--// being asked, against three separate exclusion lists that visibly churn between builds.
--//
--// Client only. It is display text and nothing reads it back.

require "XpSystem/ISUI/ISSkillProgressBar"

--// Tuning
-- An unboosted skill earns a quarter rate. Everything here is expressed against it.
local BASE_RATE = 0.25

-- What the game multiplies experience by at each boost level
local BOOST_RATE = { [1] = 1.0, [2] = 1.33, [3] = 1.66 }
local SPRINTING_FIRST_BOOST = 1.25

-- The strings vanilla puts in front of the player, which is what has to be found and
-- replaced. ISSkillProgressBar uses the first, CharacterCreationProfession the second.
local TOOLTIP_PERCENT = { [1] = "75%", [2] = "100%", [3] = "125%" }
local CREATION_PERCENT = { ["+ 75%"] = 1, ["+ 100%"] = 2, ["+ 125%"] = 3 }

--// Functions
-- Compared by identity rather than by name, the way the game does it. A perk id is a
-- string that could be renamed without anything failing loudly.
local function IsExcluded(Perk)
	return Perk == Perks.Fitness or Perk == Perks.Strength
end

-- How many times the unboosted rate this boost is actually worth, or nil when there is no
-- boost to describe.
function QolcXpBoostRatio(Perk, Boost)
	if not Boost or Boost < 1 then return nil end

	if Boost == 1 and Perk == Perks.Sprinting then
		return SPRINTING_FIRST_BOOST / BASE_RATE
	end

	-- Fitness and Strength are excluded from the second and third boosts, so they never
	-- pass the first. That is the whole reason this is worth showing.
	if Boost >= 2 and IsExcluded(Perk) then
		return BOOST_RATE[1] / BASE_RATE
	end

	local Rate = BOOST_RATE[Boost] or BOOST_RATE[3]
	return Rate / BASE_RATE
end

-- Four rather than 4.0, and 5.32 rather than 5.32000000001
local function Format(Ratio)
	local Rounded = math.floor((Ratio * 100) + 0.5) / 100

	if Rounded == math.floor(Rounded) then
		return string.format("%d", Rounded)
	end

	return string.format("%.2f", Rounded)
end

-- Plain find and splice rather than gsub, because the text being replaced contains both a
-- plus and a percent sign and both are special to lua patterns.
local function ReplaceOnce(Text, Find, With)
	local At = string.find(Text, Find, 1, true)
	if not At then return Text, false end

	return string.sub(Text, 1, At - 1) .. With .. string.sub(Text, At + string.len(Find)), true
end

--// Overrides
-- The finished message is rewritten rather than the game's text lookup being replaced
-- while it is built. Nothing global is touched, so an error in here cannot take the rest
-- of the interface down with it.
local VanillaUpdateTooltip = ISSkillProgressBar.updateTooltip
function ISSkillProgressBar:updateTooltip(...)
	VanillaUpdateTooltip(self, ...)

	if not self.message or not self.perk or not self.char then return end

	local Perk = self.perk:getType()
	local Boost = self.char:getXp():getPerkBoost(Perk)

	local Percent = TOOLTIP_PERCENT[Boost]
	local Ratio = QolcXpBoostRatio(Perk, Boost)
	if not Percent or not Ratio then return end

	-- Rebuilt through getText rather than assumed, so this finds the line whatever the
	-- language is and however the string is worded
	self.message = ReplaceOnce(self.message,
		getText("IGUI_XP_tooltipxpboost", Percent),
		getText("IGUI_QoLC_XpBoost", Format(Ratio)))
end

-- The character creation screen draws the same number, right aligned, through one call to
-- drawTextRight. Swapping that for the length of the call and putting it straight back is
-- the same shape the fabric tooltip uses, and keeps vanilla's layout entirely its own.
local VanillaDrawXpBoostMap = CharacterCreationProfession.drawXpBoostMap
function CharacterCreationProfession:drawXpBoostMap(Y, Item, ...)
	local Entry = Item and Item.item
	local Perk = Entry and Entry.perk

	if not Perk then return VanillaDrawXpBoostMap(self, Y, Item, ...) end

	local Own = rawget(self, "drawTextRight")
	local Base = self.drawTextRight

	self.drawTextRight = function(Element, Text, ...)
		local Boost = CREATION_PERCENT[Text]
		local Ratio = Boost and QolcXpBoostRatio(Perk, Boost)

		if Ratio then Text = getText("IGUI_QoLC_XpBoostShort", Format(Ratio)) end
		return Base(Element, Text, ...)
	end

	local Result = VanillaDrawXpBoostMap(self, Y, Item, ...)

	-- Put back exactly what was there, which is usually nothing of our own
	self.drawTextRight = Own
	return Result
end
