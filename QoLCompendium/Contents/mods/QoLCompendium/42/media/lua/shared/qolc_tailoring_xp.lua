--// Tailoring Fix
--// Tailoring Fix, Workshop 2138726101 - Original idea and tuning
--// aspctt - 11.08.2026
--// Cutting a garment up for strips teaches tailoring. Vanilla gives nothing at all for
--// it, which leaves repairing clothes and pulling patches back off as the only two ways
--// to level the skill, both worth two experience a go.
--//
--// Confirmed in this build rather than assumed. RecipeCodeOnCreate.ripClothing creates
--// the strips and awards no experience, and neither RipClothing nor RipDenimClothing
--// declares an xpAward, so the skill genuinely moves not at all. Vanilla's own comments
--// in ISRemovePatch say as much: "doubled because the xp gains from ripping clothing was
--// nerfed".
--//
--// Rewritten rather than ported. The original hooked Recipe.OnCreate.RipClothing and
--// counted InventoryItemFactory.CreateItem calls, and build 42 has neither: the legacy
--// recipe system is gone, ripping is a craftRecipe, and its OnCreate lives in java.
--//
--// Adding xpAward to the two recipes in a script file would have been shorter, but a
--// script cannot patch one field of an existing definition, only replace the whole
--// block. That would freeze a copy of vanilla's fabric mapper into this mod and quietly
--// send new leather jackets to the denim table on the next patch, so the award is done
--// from lua instead and the recipes are left alone.
--//
--// Shared, because the recipe is performed by whichever side is in charge: the client in
--// singleplayer, the server in multiplayer. addXp already knows the difference, sending
--// a packet when it runs on a server and doing nothing at all on a multiplayer client,
--// so the same call is correct in all three cases.
--//
--// Balance lives in sandbox options, never mod options, so the server decides it for
--// everyone. See 42/media/sandbox-options.txt.

require "Entity/TimedActions/ISHandcraftAction"

--// Tuning
-- The two recipes that cut a garment into strips. RipClothing takes anything tagged
-- cotton and needs no tool, RipDenimClothing needs scissors or a sharp knife. Matched by
-- name rather than by their shared OnCreate, because CraftRecipe.LuaCall is a nested
-- java enum with no route to it from lua.
local RIP_RECIPES = { RipDenimClothing = true, RipClothing = true }

-- Experience per strip the garment is worth. Cotton pays nothing on purpose: it rips by
-- hand, needs no tool and is the most common thing in the world, so paying for it would
-- make the skill free. Denim and leather both cost a tool and a real garment.
local FABRIC_XP = { Leather = 0.5, Denim = 0.2, Cotton = 0 }

-- A fabric added later by the game or another mod is worth the denim rate rather than
-- nothing, so a new material is visible instead of silently unrewarded. Cotton is the
-- only deliberate zero.
local FABRIC_XP_DEFAULT = 0.2

-- A uniform is cut and stitched far better than a plain shirt, so taking one apart is
-- worth more than the cloth it yields. Flat, on top of the per strip amount.
--
-- Written as full types rather than bare names so the test runner resolves every one of
-- them against this build's item scripts. Clothing does get renamed between builds, and
-- a name that quietly stops matching would cost nothing but silence. The original's
-- Trousers_SantaGReen was a typo and is spelled correctly here.
local UNIFORM_XP = {
	-- Santa, the rarest thing on the list by a distance
	["Base.JacketLong_SantaGreen"] = 24,
	["Base.Trousers_SantaGreen"] = 10,
	["Base.JacketLong_Santa"] = 24,
	["Base.Trousers_Santa"] = 10,

	-- Trades
	["Base.JacketLong_Doctor"] = 8,
	["Base.Shirt_Priest"] = 14,
	["Base.Jacket_Chef"] = 10,

	-- Police
	["Base.Tshirt_Profession_PoliceWhite"] = 2,
	["Base.Tshirt_Profession_PoliceBlue"] = 2,
	["Base.Shirt_OfficerWhite"] = 6,
	["Base.Trousers_PoliceGrey"] = 4,
	["Base.Tshirt_PoliceGrey"] = 2,
	["Base.Tshirt_PoliceBlue"] = 2,
	["Base.Shirt_PoliceGrey"] = 6,
	["Base.Shirt_PoliceBlue"] = 6,
	["Base.Trousers_Police"] = 4,
	["Base.Jacket_Police"] = 10,

	-- Park ranger
	["Base.Tshirt_Profession_RangerBrown"] = 2,
	["Base.Tshirt_Profession_RangerGreen"] = 2,
	["Base.Trousers_Ranger"] = 4,
	["Base.Shirt_Ranger"] = 6,
	["Base.Jacket_Ranger"] = 10,
	["Base.Tshirt_Ranger"] = 2,

	-- Prison guard and hospital
	["Base.Trousers_PrisonGuard"] = 4,
	["Base.Shirt_PrisonGuard"] = 6,
	["Base.Trousers_Scrubs"] = 4,
	["Base.Shirt_Scrubs"] = 6,
	["Base.Tshirt_Scrubs"] = 2
}

-- Sandbox keeps the rate as a whole percentage so the slider stays usable
local PERCENT_SCALE = 100

-- Vanilla shortens a craft by a twentieth of its base time for every skill level above
-- what the recipe asks for, but only counts skills the recipe actually names. Ripping
-- names none, so it takes exactly as long at ten tailoring as at zero. Paying experience
-- for it makes tailoring the relevant skill, so the same rule is applied here. Ten levels
-- at a twentieth each is half the base time, which is the most vanilla ever gives.
local SPEED_STEPS = 20
local SPEED_LEVEL_MAX = 10

-- Used when a save predates this feature and has no sandbox values of its own. These
-- match the defaults declared in 42/media/sandbox-options.txt.
local DEFAULT_CUT_XP = 100

--// Functions
-- The sandbox page is the authority, but a character created before this feature existed
-- has nothing stored, so fall back to the declared default.
local function GetSetting(Name, Default)
	local Vars = SandboxVars and SandboxVars.QoLC
	if not Vars then return Default end

	local Value = Vars[Name]
	if Value == nil then return Default end

	return Value
end

local function IsEnabled()
	return GetSetting("TailoringCutXpEnabled", true) == true
end

local function IsRipRecipe(Recipe)
	if not Recipe or not Recipe.getName then return false end
	return RIP_RECIPES[Recipe:getName()] == true
end

-- The garment being cut up, out of everything the recipe is holding. The scissors are
-- kept rather than consumed and carry no fabric, so the fabric is what tells the two
-- apart without having to know which input slot the clothing sits in.
local function FindGarment(Data)
	if not Data or not Data.getAllInputItems then return nil end

	local Items = Data:getAllInputItems()
	if not Items then return nil end

	for Index = 0, Items:size() - 1 do
		local Item = Items:get(Index)
		local Fabric = Item and Item.getFabricType and Item:getFabricType()

		if Fabric and Fabric ~= "" and Item.getNbrOfCoveredParts then return Item end
	end

	return nil
end

-- How many strips the garment is worth, and how much of it is left. Both come from the
-- same numbers the game itself uses in RecipeCodeOnCreate.ripClothing, where the strip
-- count is the covered body parts less the holes and patches, floored at one. Reusing it
-- means a holed jacket pays less here for exactly the reason it yields less there.
local function Measure(Garment)
	local Covered = Garment:getNbrOfCoveredParts() or 0
	local Damage = (Garment:getHolesNumber() or 0) + (Garment:getPatchesNumber() or 0)

	local Strips = Covered - Damage
	if Strips < 1 then Strips = 1 end

	local Intact = 1
	if Covered > 0 then Intact = Strips / Covered end
	if Intact > 1 then Intact = 1 end

	return Strips, Intact
end

local function GetXp(Garment)
	local Fabric = Garment:getFabricType()
	local Rate = FABRIC_XP[Fabric]
	if Rate == nil then Rate = FABRIC_XP_DEFAULT end

	local Strips, Intact = Measure(Garment)
	local Bonus = UNIFORM_XP[Garment:getFullType()] or 0

	local Percent = tonumber(GetSetting("TailoringCutXp", DEFAULT_CUT_XP)) or DEFAULT_CUT_XP
	if Percent < 0 then Percent = 0 end

	-- The cloth is paid by the strip, the tailoring in the uniform is paid flat. Only
	-- the flat part needs the wear multiplier, because the strip count already carries it.
	return ((Rate * Strips) + (Bonus * Intact)) * (Percent / PERCENT_SCALE)
end

--// Overrides
-- performRecipe rather than perform or complete, because vanilla calls it from whichever
-- of those two is authoritative and calling it is the definition of the craft having
-- happened. Its return value says nothing about success, so a craft that fails at the
-- last instant still pays out. That is deliberate: the alternative is guessing at success
-- from a side effect, and guessing wrong would leave the whole feature silently dead.
local VanillaPerformRecipe = ISHandcraftAction.performRecipe
function ISHandcraftAction:performRecipe()
	if not IsEnabled() or not IsRipRecipe(self.craftRecipe) then
		return VanillaPerformRecipe(self)
	end

	-- Read before, because the garment is destroyed by the time this returns
	local Data = self.logic and self.logic:getRecipeData()
	local Garment = FindGarment(Data)

	VanillaPerformRecipe(self)

	if not Garment then return end
	if not self.character or not self.character.getPerkLevel then return end

	local Xp = GetXp(Garment)
	if Xp <= 0 then return end

	addXp(self.character, Perks.Tailoring, Xp)
end

local VanillaGetDuration = ISHandcraftAction.getDuration
function ISHandcraftAction:getDuration()
	local Base = VanillaGetDuration(self)

	-- One is what vanilla returns for a character crafting instantly, and a negative is
	-- how it reports having no recipe at all. Neither is a length to scale.
	if Base <= 1 then return Base end
	if not IsEnabled() or not IsRipRecipe(self.craftRecipe) then return Base end
	if not self.character or not self.character.getPerkLevel then return Base end

	local Level = self.character:getPerkLevel(Perks.Tailoring) or 0
	if Level > SPEED_LEVEL_MAX then Level = SPEED_LEVEL_MAX end
	if Level < 0 then Level = 0 end

	local Reduced = Base - (math.floor(Base / SPEED_STEPS) * Level)
	if Reduced < 1 then Reduced = 1 end

	return Reduced
end
