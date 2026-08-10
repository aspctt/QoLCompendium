--// Weapon Condition Indicator
--// aspctt - 10.08.2026
--// Draws a small condition bar under the weapon in each hand and under every item on
--// the hotbar, so a weapon about to break is visible without hovering it.
--//
--// Vanilla knows an item's condition and uses it, but never shows it. ISHotbar:render
--// draws the slot border, its number, the item icon and an equipped marker and stops
--// there, and ISEquippedItem:render only reads getCondition to decide whether an item
--// can be dragged into a hand at all.
--//
--// Written from scratch against getCondition and getConditionMax. Nothing is bundled
--// and no art is needed, because a bar is two rectangles.
--//
--// The hotbar half is drawn from qolc_reorder_hotbar.lua rather than by overriding
--// ISHotbar.render again. That file already owns the render, and a second override of
--// the same function is how mods end up silently erasing each other.

--// Tuning
-- Thin enough to sit under an icon without crowding it.
local BAR_HEIGHT = 3
local BAR_INSET = 3

-- Condition runs 0 to getConditionMax, which differs per item, so it is always compared
-- as a fraction. Below these the bar turns amber, then red.
local LEVEL_CAUTION = 0.5
local LEVEL_DANGER = 0.25

-- Green drains out of the bar as the weapon wears, rather than the three being three
-- unrelated colours. That way the change reads even to someone who cannot separate red
-- from green, because the bar also gets visibly duller.
local COLOUR_BACKGROUND = { r = 0, g = 0, b = 0, a = 0.55 }
local COLOUR_HEALTHY = { r = 0.30, g = 0.78, b = 0.30, a = 0.9 }
local COLOUR_CAUTION = { r = 0.85, g = 0.68, b = 0.20, a = 0.9 }
local COLOUR_DANGER = { r = 0.85, g = 0.22, b = 0.22, a = 0.9 }

--// Options
local OPTIONS_ID = "QoLC"
local Options = {}

--// Functions
-- Returns 0 to 1, or nil when the item has no condition to speak of. Food, books and
-- most everything that is not a weapon or a tool report a max of zero.
function QolcConditionFraction(Item)
	if not Item or not Item.getConditionMax then return nil end

	local Max = Item:getConditionMax()
	if not Max or Max <= 0 then return nil end

	local Current = Item:getCondition() or 0
	local Fraction = Current / Max

	if Fraction < 0 then return 0 end
	if Fraction > 1 then return 1 end

	return Fraction
end

local function ColourFor(Fraction)
	if Fraction <= LEVEL_DANGER then return COLOUR_DANGER end
	if Fraction <= LEVEL_CAUTION then return COLOUR_CAUTION end

	return COLOUR_HEALTHY
end

function QolcConditionEnabled()
	if not Options.Enabled then return true end
	return Options.Enabled:getValue() and true or false
end

-- Draws the bar along the bottom of the box given. Silently does nothing for an item
-- with no condition, which is most of them.
function QolcDrawConditionBar(Panel, X, Y, Width, Height, Item)
	if not Panel or not QolcConditionEnabled() then return false end

	local Fraction = QolcConditionFraction(Item)
	if not Fraction then return false end

	local BarWidth = Width - (BAR_INSET * 2)
	if BarWidth <= 0 then return false end

	local BarX = X + BAR_INSET
	local BarY = Y + Height - BAR_INSET - BAR_HEIGHT

	local Back = COLOUR_BACKGROUND
	Panel:drawRect(BarX, BarY, BarWidth, BAR_HEIGHT, Back.a, Back.r, Back.g, Back.b)

	-- A weapon on its last legs still shows a sliver, so "nearly gone" reads
	-- differently from "gone"
	local Filled = BarWidth * Fraction
	if Fraction > 0 and Filled < 1 then Filled = 1 end

	if Filled > 0 then
		local Colour = ColourFor(Fraction)
		Panel:drawRect(BarX, BarY, Filled, BAR_HEIGHT, Colour.a, Colour.r, Colour.g, Colour.b)
	end

	return true
end

--// Equipped Hands
-- Wrapped rather than replaced, so whatever else vanilla draws in the panel still runs.
local VanillaEquippedRender = ISEquippedItem.render
function ISEquippedItem:render()
	VanillaEquippedRender(self)

	if not self.chr then return end

	local Hands = {
		{ Box = self.mainHand, Item = self.chr:getPrimaryHandItem() },
		{ Box = self.offHand, Item = self.chr:getSecondaryHandItem() }
	}

	for _, Hand in ipairs(Hands) do
		local Box = Hand.Box
		if Box and Hand.Item then
			QolcDrawConditionBar(self, Box.x, Box.y, Box.width, Box.height, Hand.Item)
		end
	end
end

--// Mod Options
-- One shared category for the whole compendium, see qolc_immersive_overlays.lua.
local function CreateModOptions()
	if not PZAPI or not PZAPI.ModOptions then return end

	local ModOptions = PZAPI.ModOptions:getOptions(OPTIONS_ID)
	if not ModOptions then
		ModOptions = PZAPI.ModOptions:create(OPTIONS_ID, "UI_options_QoLC")
	end

	ModOptions:addTitle("UI_options_QoLC_Condition")
	ModOptions:addDescription("UI_options_QoLC_Condition_Desc")

	Options.Enabled = ModOptions:addTickBox("ConditionEnabled", "UI_options_QoLC_Condition_Enabled", true, "UI_options_QoLC_Condition_Enabled_tooltip")
end

CreateModOptions()
