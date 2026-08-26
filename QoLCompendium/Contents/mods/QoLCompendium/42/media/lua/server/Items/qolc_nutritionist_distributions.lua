--// The Nutritionist Distributions
--// The Nutritionist, Workshop 1934095105 - Original idea
--// aspctt - 18.08.2026
--// Where the nutrition magazine spawns: beside the cooking magazines, which is where
--// the original put it and where a reader would look for it.
--//
--// The original walked every distribution table looking for an item whose name starts
--// with "CookingMag", then inserted itself at half that weight. That is kept, because
--// it means the magazine follows vanilla wherever cooking magazines are, rather than
--// naming a list of rooms that build 42 has since renamed. It is done from
--// OnPreDistributionMerge here rather than at file scope, so it runs after the game has
--// finished building the tables and after any other mod has added its own.
--//
--// Server side, so the tables are built once and authoritatively. Switched from the
--// sandbox page rather than mod options, because loot balance has to match across a
--// multiplayer session.
--//
--// The seeding itself is unconditional, and the switch is handed to qolc_loot_switch.
--// It has to be: the sandbox options are not read from the save until after all three
--// merge events have fired, so a test here reads our own declared default rather than
--// the player's answer. That file has the whole story.

require "Items/ProceduralDistributions"
require "qolc_loot_switch"

--// Tuning
local ITEM = "QolcNutritionistMag"

-- Vanilla's cooking magazines sit at 2 in every table that has them. Half of that keeps
-- this rarer than any one of them without making it a trophy, which is the original's
-- own ratio.
local SHARE = 0.5

-- The same floor and ceiling the original clamped to, so a table that weights cooking
-- magazines oddly cannot make this one absurd either way.
local MIN_WEIGHT, MAX_WEIGHT = 0.1, 2

--// Switch
QolcLootSwitch.Withhold("NutritionistMagEnabled", { "Base." .. ITEM })

--// Functions
local function Clamp(Weight)
	if Weight < MIN_WEIGHT then return MIN_WEIGHT end
	if Weight > MAX_WEIGHT then return MAX_WEIGHT end
	return Weight
end

-- An items list is a flat name, weight, name, weight sequence, so the weight belongs to
-- the entry before it.
local function AddBesideCookingMags(Items)
	if type(Items) ~= "table" then return false end

	for Index = 1, #Items - 1, 2 do
		local Name = Items[Index]

		if type(Name) == "string" and Name == ITEM then return false end
	end

	for Index = 1, #Items - 1, 2 do
		local Name = Items[Index]

		if type(Name) == "string" and string.sub(Name, 1, 10) == "CookingMag" then
			local Weight = tonumber(Items[Index + 1]) or 2
			table.insert(Items, ITEM)
			table.insert(Items, Clamp(Weight * SHARE))
			return true
		end
	end

	return false
end

--// Connections
local function OnPreDistributionMerge()
	if not ProceduralDistributions or not ProceduralDistributions.list then return end

	for _, Room in pairs(ProceduralDistributions.list) do
		if type(Room) == "table" then AddBesideCookingMags(Room.items) end
	end
end

Events.OnPreDistributionMerge.Add(OnPreDistributionMerge)
