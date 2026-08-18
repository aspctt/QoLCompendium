--// Fix Capacity Overlap
--// Fix Capacity Overlap, Workshop 2957932451 - Original idea
--// aspctt - 11.08.2026
--// A loot window's title runs into the weight and capacity printed beside it. This moves
--// the title so it always stops short of them.
--//
--// Vanilla reserves the gap from a placeholder rather than from the text it is actually
--// about to draw, in ISInventoryPage:prerender:
--//
--//   local weightWid = getTextManager():MeasureStringX(UIFont.Small, "9999.99 / 9999") + 30
--//   self:drawTextRight(text, self.width - 20 - weightWid, ...)
--//
--// Anything wider than that placeholder overlaps. On a multiplayer server with
--// ItemNumbersLimitPerContainer set, the label grows an item count, "12.34 / 50 (20 /
--// 100)", and runs straight under the title. The twenty and the thirty are also flat
--// pixel counts that do not scale, so the bigger the font the thinner the margin.
--//
--// Rewritten rather than ported. The original is a copy of the whole build 41 prerender
--// with one line changed, so on build 42 it would undo the campfire fuel readout, the
--// occupied vehicle seat label, the multiplayer item count and the dirty page handling,
--// all of which the base game added since. Here vanilla draws its own window and only the
--// title's position is intercepted.
--//
--// Stands down when Clean UI is installed. That mod ships its own
--// media/lua/client/ISUI/ISInventoryPage.lua, replacing the file outright, so the window
--// is entirely theirs and its title is laid out by their code, not this one.
--//
--// Client only. It is a window and nothing reads it back.

require "ISUI/ISInventoryPage"

--// Guards
-- Deliberately a local rather than a shared helper, for the same reason as the one in
-- qolc_sling_hotbar.lua: this runs at file scope, and lua file load order between mod
-- files is not guaranteed, so a cross file call here would be a load order landmine.
local function OverrideBlocked()
	if not getActivatedMods then return false end

	local Mods = getActivatedMods()
	if not Mods then return false end

	return Mods:contains("CleanUI")
end

if OverrideBlocked() then return end

--// Tuning
-- Space left between the end of the title and the start of the weight. Vanilla pads the
-- same gap with thirty pixels, measured at the placeholder rather than at anything real.
local TITLE_GAP = 10

--// Overrides
-- Vanilla builds the whole window and this repositions one string inside it, by swapping
-- drawTextRight for the length of the call and putting it straight back. The same shape as
-- the fabric tooltip and the experience boost column.
--
-- The title is picked out by its text rather than by counting calls, so another mod adding
-- a line of its own cannot shift which draw this thinks is which.
local VanillaPrerender = ISInventoryPage.prerender
function ISInventoryPage:prerender()
	-- The character's own inventory draws its title on the left with drawText and never
	-- collides with anything, so there is nothing to do there
	if not QolcFeatureEnabled("Capacity") then return VanillaPrerender(self) end
	if self.onCharacter or not self.title then return VanillaPrerender(self) end

	local Own = rawget(self, "drawTextRight")
	local Base = self.drawTextRight
	local Title = self.title
	local WeightLeft = nil

	self.drawTextRight = function(Element, Text, X, Y, ...)
		if Text and string.sub(Text, 1, string.len(Title)) == Title then
			-- Vanilla appends the campfire fuel or the occupied seat note to the title,
			-- so this matches the start of it rather than the whole thing
			if WeightLeft then X = WeightLeft - TITLE_GAP end
		elseif Text then
			-- Right aligned, so the x it is given is where the text ends
			WeightLeft = X - getTextManager():MeasureStringX(UIFont.Small, Text)
		end

		return Base(Element, Text, X, Y, ...)
	end

	local Result = VanillaPrerender(self)

	-- Put back exactly what was there, which is usually nothing of our own
	self.drawTextRight = Own
	return Result
end
