--// Show Clothes Material
--// Show Clothes Material, Workshop 1922750845 - Original idea
--// aspctt - 10.08.2026
--// Adds a coloured "Fabric: Leather" line to the bottom of a garment's tooltip. The
--// game tracks what a garment is made of, and uses it for patching and for what the
--// garment rips into, but never tells you.
--//
--// This was first done through the item script's own Tooltip field, which needed no
--// interface code at all. That is dropped because the field cannot carry a colour:
--// nothing in the game parses colour markup in tooltip text, and the line is only
--// useful at a glance if leather, denim and cotton read differently.
--//
--// The tooltip is built on the Java side, so the only way in is to reserve a row while
--// it measures itself and draw into that row afterwards. setHeight is the one call that
--// happens between the measure and the background being drawn, which is why it is the
--// one wrapped.
--//
--// Client only. It is a tooltip and nothing else reads it.

--// Tuning
-- Read once per item rather than per frame. render runs every frame a tooltip is up.
local Cache = { Item = nil, Text = nil, Colour = nil }

local LABEL_KEY = "IGUI_QoLC_Fabric"
local NAME_PREFIX = "IGUI_QoLC_Fabric_"

-- Padding around the row we add, matching the gap vanilla leaves at the bottom of a
-- tooltip so the line does not sit flush against the border.
local ROW_PADDING = 4

-- Vanilla draws the item name and every stat row at the tooltip's padLeft, so this has
-- to be the same number or the line sits in its own column.
--
-- It is a plain number because padLeft is a public field with no getter and is not
-- reachable from lua. Reading it was tried and silently gave nothing, which is what left
-- the line three pixels adrift. So the value is measured from the game instead: the item
-- name and the stat rows start at eight, not at the five vanilla's own lua uses for the
-- tooltips it builds itself.
local ROW_INSET = 8

-- Each fabric reads as itself. Leather is tan, denim is denim, and cotton is a bright
-- near white so it stands out from the grey the rest of a tooltip is written in rather
-- than blending into it. The faint warmth is what keeps it from being flat white.
local COLOURS = {
	Leather = { r = 0.80, g = 0.52, b = 0.25 },
	Denim = { r = 0.42, g = 0.58, b = 0.82 },
	Cotton = { r = 0.98, g = 0.97, b = 0.92 }
}

-- Anything the game adds later still gets a line, just in the default tooltip white
local COLOUR_UNKNOWN = { r = 0.85, g = 0.85, b = 0.85 }

--// Functions
local function GetFont()
	local Name = getCore() and getCore():getOptionTooltipFont()
	return (Name and UIFont[Name]) or UIFont.Small
end

-- Returns the line to draw and its colour, or nothing for anything that is not clothing
local function GetFabricLine(Item)
	if not Item or not Item.getFabricType then return nil end

	local Fabric = Item:getFabricType()
	if not Fabric or Fabric == "" then return nil end

	-- Falls back to the raw type rather than showing nothing, so a fabric added later
	-- still reads, just untranslated
	local Name = getTextOrNull(NAME_PREFIX .. Fabric) or Fabric
	local Label = getTextOrNull(LABEL_KEY) or "Fabric:"

	return Label .. " " .. Name, COLOURS[Fabric] or COLOUR_UNKNOWN
end

local function GetCachedLine(Item)
	if Cache.Item ~= Item then
		Cache.Item = Item
		Cache.Text, Cache.Colour = GetFabricLine(Item)
	end

	return Cache.Text, Cache.Colour
end

--// Overrides
local VanillaRender = ISToolTipInv.render
function ISToolTipInv:render()
	local Text, Colour = GetCachedLine(self.item)
	if not Text then return VanillaRender(self) end

	local RowHeight = getTextManager():getFontHeight(GetFont()) + ROW_PADDING

	-- Vanilla measures the tooltip, calls setHeight once, then draws the background and
	-- border at that height. Growing it here is what leaves room for our row inside the
	-- box rather than past its bottom edge.
	local Content = nil
	local Own = rawget(self, "setHeight")
	local Base = self.setHeight

	self.setHeight = function(Element, Value, ...)
		if Content == nil then Content = Value end
		return Base(Element, Value + RowHeight, ...)
	end

	VanillaRender(self)

	-- Put back exactly what was there, which is usually nothing of our own
	self.setHeight = Own

	if not Content then return end

	self.tooltip:DrawText(GetFont(), Text, ROW_INSET, Content - ROW_PADDING,
		Colour.r, Colour.g, Colour.b, 1)
end
