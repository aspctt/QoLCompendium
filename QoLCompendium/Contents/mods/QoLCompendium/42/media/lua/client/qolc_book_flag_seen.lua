--// Flag Books As Seen
--// An Exhilaratingly Organized Literature Mod, Workshop 2071347174 - Original idea
--// aspctt - 11.08.2026
--// Turns the dead "Read" entry on a book that is too advanced into one that reads its
--// first page, so a second copy found later is recognisable as one already owned.
--//
--// Rebuilt rather than ported. The original replaced ISInventoryPaneContextMenu's whole
--// literature menu, which on build 42 would be a large regression: that function now
--// also handles reading in the dark, the illiterate trait through CharacterTrait and the
--// picture book and picture tags, books already read recently, books too simple to learn
--// anything from, empty notebooks, sleeping, and the recipe list. The original returns
--// early in the too advanced case and all of that would be lost. It also tested for the
--// trait with HasTrait("Illiterate"), a string form build 42 no longer accepts.
--//
--// So vanilla builds the menu untouched and this changes the one entry it means to, found
--// by the tooltip vanilla put on it rather than by its position.
--//
--// Client only. It is a context menu, and the action it queues is shared.

require "ISUI/ISInventoryPaneContextMenu"

--// Functions
-- The entry vanilla adds for a book whose skill level is out of reach. Matched on the
-- tooltip because that is the only thing distinguishing it: the label is the same plain
-- "Read" as the too simple and empty notebook cases, all three disabled.
local function FindTooComplicated(Context)
	local Wanted = getText("ContextMenu_TooComplicated")

	for _, Option in ipairs(Context.options) do
		if Option.notAvailable and Option.toolTip
			and Option.toolTip.description == Wanted then
			return Option
		end
	end

	return nil
end

-- The book the entry was about. Vanilla resolves the selection the same way before
-- deciding the option was out of reach at all.
local function FindBook(Items)
	for _, Item in ipairs(ISInventoryPane.getActualUniqueItems(Items)) do
		if Item:getLvlSkillTrained() ~= -1 and SkillBook[Item:getSkillTrained()]
			and SkillBook[Item:getSkillTrained()].perk then
			return Item
		end
	end

	return nil
end

local function OnRead(Items, PlayerNum, Book)
	local Player = getSpecificPlayer(PlayerNum)
	if not Player or not Book then return end

	ISTimedActionQueue.add(QolcFlagBookAction:new(Player, Book))
end

--// Overrides
local VanillaLiteratureMenu = ISInventoryPaneContextMenu.doLiteratureMenu
function ISInventoryPaneContextMenu.doLiteratureMenu(Context, Items, PlayerNum)
	VanillaLiteratureMenu(Context, Items, PlayerNum)
	if not QolcFeatureEnabled("FlagBook") then return end

	local Option = FindTooComplicated(Context)
	if not Option then return end

	local Player = getSpecificPlayer(PlayerNum)
	if not Player then return end

	-- An illiterate character cannot take anything from a page, and asleep is vanilla's
	-- own refusal for every other read
	if Player:hasTrait(CharacterTrait.ILLITERATE) then return end
	if Player:isAsleep() then return end

	local Book = FindBook(Items)
	if not Book or Book:getNumberOfPages() <= 0 then return end

	-- Nothing to gain from doing it twice, so leave vanilla's refusal in place
	if Player:getAlreadyReadPages(Book:getFullType()) > 0 then return end

	-- onSelect is called as (target, param1, param2, ...), which is why the item list
	-- goes in target rather than in the first parameter
	Option.name = getText("ContextMenu_QoLC_ReadOnePage")
	Option.notAvailable = false
	Option.onSelect = OnRead
	Option.target = Items
	Option.param1 = PlayerNum
	Option.param2 = Book
	Option.itemForTexture = Book

	local Tooltip = ISInventoryPaneContextMenu.addToolTip()
	Tooltip.description = getText("Tooltip_QoLC_ReadOnePage")
	Option.toolTip = Tooltip
end
