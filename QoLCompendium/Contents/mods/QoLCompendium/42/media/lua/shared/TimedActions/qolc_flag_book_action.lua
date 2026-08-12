--// Flag Book As Seen
--// An Exhilaratingly Organized Literature Mod, Workshop 2071347174 - Original idea
--// aspctt - 11.08.2026
--// Reads the first page of a book that is still too advanced, which is enough for the
--// character to recognise a second copy later.
--//
--// Vanilla tracks how far into a book a character has read, per book type, and shows it
--// in the tooltip. A book too advanced to study reads zero pages forever, so every copy
--// on every shelf looks exactly like one already at home. One page is all it takes to
--// tell them apart, and it costs nothing else: the page count for actually studying the
--// book later is untouched, and the character re-reads that page as normal.
--//
--// Shared, because a timed action has to exist on both sides in multiplayer.

require "TimedActions/ISBaseTimedAction"

QolcFlagBookAction = ISBaseTimedAction:derive("QolcFlagBookAction")

--// Tuning
-- Long enough to read a page and see it happen, short enough not to be a chore. Vanilla
-- times a full read from the page count, which is the wrong scale for one page.
local READ_TIME = 60

-- Vanilla stores progress per book type rather than per copy, which is exactly why this
-- works on a copy found later.
local PAGES_READ = 1

local SAY_LINES = 3

--// Functions
function QolcFlagBookAction:isValid()
	if not self.item then return false end
	if self.character:tooDarkToRead() then return false end

	return self.character:getInventory():contains(self.item)
end

function QolcFlagBookAction:update()
	self.item:setJobDelta(self:getJobDelta())
end

-- Job type, animation and the absence of a metabolic target all follow vanilla's own
-- ISReadABook, so this looks like reading rather than like something else
function QolcFlagBookAction:start()
	self.item:setJobType(getText("ContextMenu_Read") .. " " .. self.item:getName())
	self.item:setJobDelta(0)
	self:setActionAnim(CharacterActionAnims.Read)
end

function QolcFlagBookAction:stop()
	self.item:setJobDelta(0)
	ISBaseTimedAction.stop(self)
end

function QolcFlagBookAction:perform()
	self.item:setJobDelta(0)

	-- Only ever raises it. Studying the book properly later writes a real page count, and
	-- reaching for this afterwards must not throw that away.
	local Type = self.item:getFullType()
	if self.character:getAlreadyReadPages(Type) < PAGES_READ then
		self.character:setAlreadyReadPages(Type, PAGES_READ)
	end

	self.character:Say(getText("IGUI_QoLC_FlaggedBook" .. tostring(ZombRand(SAY_LINES) + 1)))

	ISBaseTimedAction.perform(self)
end

function QolcFlagBookAction:new(Character, Item)
	local Action = ISBaseTimedAction.new(self, Character)
	Action.character = Character
	Action.item = Item
	Action.maxTime = READ_TIME
	Action.stopOnWalk = true
	Action.stopOnRun = true

	if Character:isTimedActionInstant() then Action.maxTime = 1 end

	return Action
end
