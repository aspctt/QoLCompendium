--// Food Categories
--// aspctt - 10.08.2026
--// Build 42 files every one of its 707 food items under a single Food heading. This
--// splits that in two: food that spoils, and food that keeps. It is the most useful cut
--// there is in a survival inventory, because it answers the only question that matters
--// when you open a fridge, which is what has to be eaten first.
--//
--// Vanilla is left to categorise everything else. It already does that well in build 42,
--// with 82 categories covering every item in the game, so nothing here second guesses
--// it. Only the Food heading is touched, and only to divide it.
--//
--// Shared rather than client, matching qolc_ammo_icons.lua, so a server and its clients
--// hold the same item definitions. The field is display only either way.

--// Tuning
local CATEGORY_NONPERISHABLE = "FoodNonPerishable"
local CATEGORY_PERISHABLE = "FoodPerishable"
local CATEGORY_FOOD = "Food"

-- Anything with a rot time spoils. Tinned food, dried herbs, powders and cooking
-- ingredients have none at all, so they keep indefinitely.
--
-- The upper bound is for modded items. Vanilla's longest lived food rots in 730 days,
-- so anything claiming a decade or more is a mod using a large number to mean "never"
-- rather than food that genuinely spoils. Measured, not guessed.
local ROT_DAYS_SENTINEL = 3650

--// Functions
local function OnInitGlobalModData()
	if QolcFeatureEnabled and not QolcFeatureEnabled("FoodCategories") then return end
	if not getAllItems then return end

	local Items = getAllItems()
	if not Items then return end

	for Index = 0, Items:size() - 1 do
		local Item = Items:get(Index)

		-- Only items vanilla itself calls Food, so a category another mod has already
		-- chosen is left alone
		if Item and Item:getDisplayCategory() == CATEGORY_FOOD then
			local Rots = Item:getDaysTotallyRotten()
			local Perishable = Rots and Rots > 0 and Rots < ROT_DAYS_SENTINEL

			Item:DoParam("DisplayCategory = " .. (Perishable and CATEGORY_PERISHABLE or CATEGORY_NONPERISHABLE))
		end
	end
end

--// Connections
Events.OnInitGlobalModData.Add(OnInitGlobalModData)
