--// Take Any Amount
--// Take Any Amount, Workshop 2985394645 - Original idea, permission granted with credit
--// Build 42 version, Workshop 3389115640, by KaliLynx
--// aspctt - 12.08.2026
--// Vanilla offers one, half, or all. There is no way to say twelve. This adds a box you
--// type a number into, both for taking out of a container and putting into one.
--//
--// Rewritten rather than ported, for three reasons.
--//
--// The original replaces ISInventoryPaneContextMenu.doGrabMenu with a copy of an older
--// one. Build 42.20 added a destination check to that function, so anything the target
--// container refuses is no longer offered at all. Installing the copy puts those options
--// back. Here vanilla builds the menu and one entry is inserted into it.
--//
--// It keeps the amount and the maximum in two file level variables, written while the
--// menu is built and read when the box is confirmed. In split screen both players share
--// them, so whoever opened a menu last decides the other's limit. Both travel with the
--// option here instead.
--//
--// It also declares its callbacks and both variables without local, leaving five names in
--// the global namespace for another mod to collide with.
--//
--// One deliberate change of behaviour: asking for twelve takes twelve in total, not
--// twelve from every stack selected. The original counts per stack when taking and in
--// total when putting, which cannot both be right.
--//
--// Client only. It is a context menu and the transfers it queues are vanilla's own.

require "ISUI/ISInventoryPaneContextMenu"
require "ISUI/ISTextBox"

--// Tuning
local BOX_WIDTH = 280
local BOX_HEIGHT = 180

--// Functions
-- A stack entry holds a display copy at index one and the real items after it, so the
-- count is one short of the table length.
local function StackCount(Entry)
	if not Entry or instanceof(Entry, "InventoryItem") then return 0 end
	if type(Entry.items) ~= "table" then return 0 end

	return #Entry.items - 1
end

local function ReadAmount(Button, Max)
	if not Button or Button.internal ~= "OK" then return nil end

	local Entered = tonumber(Button.parent.entry:getText())
	if not Entered then return nil end

	-- Anything above the maximum takes the lot, anything below one does nothing
	if Entered > Max then Entered = Max end
	if Entered < 1 then return nil end

	return math.floor(Entered)
end

-- Vanilla walks to a container once before the first transfer, then queues the rest
local function WalkedTo(Container, PlayerNum, Walked)
	if Walked then return true end
	return luautils.walkToContainer(Container, PlayerNum) and true or false
end

--// Transfers
local function TakeAmount(_Target, Button, Items, PlayerNum, Max)
	local Wanted = ReadAmount(Button, Max)
	if not Wanted then return end

	local Player = getSpecificPlayer(PlayerNum)
	local Destination = getPlayerInventory(PlayerNum).inventory
	local Walked = false
	local Taken = 0

	for _, Entry in ipairs(Items) do
		local Stack = StackCount(Entry)

		for Index = 1, Stack do
			if Taken >= Wanted then return end

			local Item = Entry.items[Index + 1]
			if Item and Item:getContainer() ~= Destination then
				if not WalkedTo(Item:getContainer(), PlayerNum, Walked) then return end
				Walked = true

				ISTimedActionQueue.add(ISInventoryTransferAction:new(
					Player, Item, Item:getContainer(), Destination))
				Taken = Taken + 1
			end
		end

		if Stack == 0 and Entry:getContainer() ~= Destination then
			if Taken >= Wanted then return end
			if not WalkedTo(Entry:getContainer(), PlayerNum, Walked) then return end
			Walked = true

			ISTimedActionQueue.add(ISInventoryTransferAction:new(
				Player, Entry, Entry:getContainer(), Destination))
			Taken = Taken + 1
		end
	end
end

local function PutAmount(_Target, Button, Items, PlayerNum, Max)
	local Wanted = ReadAmount(Button, Max)
	if not Wanted then return end

	local Player = getSpecificPlayer(PlayerNum)
	local Destination = getPlayerLoot(PlayerNum).inventory
	local Walked = false
	local Put = 0

	for _, Item in ipairs(ISInventoryPane.getActualItems(Items)) do
		if Put >= Wanted then return end

		-- Favourites are left alone, the same as every other vanilla transfer
		if Destination:isItemAllowed(Item) and not Item:isFavorite() then
			if not WalkedTo(Destination, PlayerNum, Walked) then return end
			Walked = true

			ISTimedActionQueue.add(ISInventoryTransferAction:new(
				Player, Item, Item:getContainer(), Destination))
			Put = Put + 1
		end
	end
end

--// The Box
local function OpenBox(Items, PlayerNum, Max, OnConfirm)
	local Title = getText("ContextMenu_QoLC_TransferAmount", tostring(Max))
	local Box = ISTextBox:new(0, 0, BOX_WIDTH, BOX_HEIGHT, Title, "", nil, OnConfirm,
		PlayerNum, Items, PlayerNum, Max)

	Box:initialise()
	Box:addToUIManager()

	-- Typing a number and pressing enter should confirm, rather than needing the mouse
	local Ok = nil
	for _, Child in ipairs(Box.children) do
		if Child.internal == "OK" then Ok = Child break end
	end

	if Ok then
		Box.entry.onCommandEntered = function() Ok:triggerClick() end
	end

	Box.entry:focus()

	if JoypadState.players[PlayerNum + 1] then setJoypadFocus(PlayerNum, Box) end
end

local function OpenTakeBox(Items, PlayerNum, Max) OpenBox(Items, PlayerNum, Max, TakeAmount) end
local function OpenPutBox(Items, PlayerNum, Max) OpenBox(Items, PlayerNum, Max, PutAmount) end

--// Menus
-- Vanilla adds one, half and all together for a stack worth splitting, and a single Grab
-- otherwise. Ours belongs between half and all, so it is placed by finding half rather
-- than by counting entries.
local function InsertAfter(Context, Option, AfterName)
	local At = nil
	for Index, Entry in ipairs(Context.options) do
		if Entry.name == AfterName then At = Index break end
	end

	if not At or Context.options[At + 1] == Option then return end

	for Index, Entry in ipairs(Context.options) do
		if Entry == Option then table.remove(Context.options, Index) break end
	end
	table.insert(Context.options, At + 1, Option)

	-- ids track position, the same way addOptionOnTop maintains them
	for Index, Entry in ipairs(Context.options) do
		Entry.id = Index
	end
end

local VanillaGrabMenu = ISInventoryPaneContextMenu.doGrabMenu
function ISInventoryPaneContextMenu.doGrabMenu(Context, Items, PlayerNum)
	VanillaGrabMenu(Context, Items, PlayerNum)

	-- Only where vanilla decided the stack was worth splitting. That decision already
	-- accounts for heavy items and for containers refusing the item.
	local Half = getText("ContextMenu_Grab_half")
	local Offered = false
	for _, Entry in ipairs(Context.options) do
		if Entry.name == Half then Offered = true break end
	end
	if not Offered then return end

	local Max = 0
	for _, Entry in ipairs(Items) do
		Max = Max + StackCount(Entry)
	end
	if Max < 1 then return end

	local Option = Context:addOption(getText("ContextMenu_QoLC_GrabAmount"),
		Items, OpenTakeBox, PlayerNum, Max)

	InsertAfter(Context, Option, Half)
end

local function OnFillInventoryObjectContextMenu(PlayerNum, Context, Items)
	local Player = getSpecificPlayer(PlayerNum)
	local Loot = getPlayerLoot(PlayerNum)
	if not Player or not Loot or not Loot.inventory then return end

	local Moving = ISInventoryPane.getActualItems(Items)
	local Max = #Moving
	if Max < 2 then return end

	-- Only from the character's own inventory. Vanilla's own put options are added under
	-- the same condition, and the first item decides it the same way.
	local First = Moving[1]
	if not First or not First:getContainer():isInCharacterInventory(Player) then return end

	if not ISInventoryPaneContextMenu.isAnyAllowed(Loot.inventory, Items) then return end
	if ISInventoryPaneContextMenu.isAllFav(Items) then return end

	Context:addOption(getText("ContextMenu_QoLC_PutAmount", Loot.title),
		Items, OpenPutBox, PlayerNum, Max)
end

--// Connections
Events.OnFillInventoryObjectContextMenu.Add(OnFillInventoryObjectContextMenu)
