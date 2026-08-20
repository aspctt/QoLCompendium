--// TEMPORARY Hotbar Diagnostics
--// aspctt - 20.08.2026
--// Not a feature. Delete this one file and the build is clean again: nothing else in the
--// mod references anything in it.
--//
--// Reported on a dedicated server, twice now, as an item leaving the hotbar on rejoin.
--// The second report has an axe on the back going while a screwdriver on the belt and a
--// flashlight in a bag stay. Every path that takes an item off the bar goes through
--// ISHotbar:removeItem, so that is wrapped, and when it fires this prints the state that
--// decides it: the four conditions in ISHotbar:update, the slot the item thinks it is
--// on, what is actually at that index, and the saved order the rejoin was rebuilt from.
--//
--// Named to sort last in this folder so it wraps our own refresh override rather than
--// being wrapped by it, which means the order it prints is the order the player sees.

require "Hotbar/ISHotbar"

--// Tuning
local PREFIX = "QOLC HOTBAR: "

--// Functions
local function Safe(Value)
	if Value == nil then return "nil" end
	return tostring(Value)
end

-- Never the item itself as a fallback. Printing a table prints every field and closure
-- on it, which buries the line that matters in a log someone else has to read.
local function Name(Item)
	if not Item then return "nil" end
	if Item.getFullType then return Safe(Item:getFullType()) end
	if Item.getName then return Safe(Item:getName()) end

	return "unnamed"
end

-- The order on screen, as slot types, so a rejoin can be compared against what was saved.
local function SlotOrder(Hotbar)
	local Parts = {}
	for Index, Slot in ipairs(Hotbar.availableSlot or {}) do
		Parts[#Parts + 1] = Index .. ":" .. Safe(Slot.slotType)
	end

	if #Parts == 0 then return "(none)" end
	return table.concat(Parts, ",")
end

-- What the game will rebuild availableSlot from on the next join.
local function SavedOrder(Hotbar)
	local Character = Hotbar.chr or Hotbar.character
	local ModData = Character and Character:getModData()
	local Saved = ModData and ModData["hotbar"]
	if not Saved then return "(none)" end

	local Indexes = {}
	for Index in pairs(Saved) do Indexes[#Indexes + 1] = Index end
	table.sort(Indexes)

	local Parts = {}
	for _, Index in ipairs(Indexes) do
		Parts[#Parts + 1] = Safe(Index) .. ":" .. Safe(Saved[Index])
	end

	if #Parts == 0 then return "(empty)" end
	return table.concat(Parts, ",")
end

local function WornBag(Character)
	if not Character or not Character.getWornItems then return "?" end

	local Worn = Character:getWornItems()
	if not Worn then return "none" end

	for Index = 0, Worn:size() - 1 do
		local Item = Worn:getItemByIndex(Index)
		if Item and Item.getAttachmentReplacement and Item:getAttachmentReplacement() then
			return Safe(Item:getFullType()) .. " -> " .. Safe(Item:getAttachmentReplacement())
		end
	end

	return "none"
end

--// Overrides
local VanillaRemove = ISHotbar.removeItem

function ISHotbar:removeItem(Item, DoAnim)
	-- Evaluated here rather than guessed at afterwards. These are the four tests in
	-- ISHotbar:update, in its order, so exactly one of them being true names the cause.
	local Character = self.chr or self.character
	local At = Item and Item.getAttachedSlot and Item:getAttachedSlot()
	local Slot = At and self.availableSlot and self.availableSlot[At]

	local NoSlot = Slot == nil
	local CannotAttach = (not NoSlot) and not self:canBeAttached(Slot, Item)
	local NotHeld = Character and Character:getInventory()
		and not Character:getInventory():contains(Item)
	local Broken = Item and Item.isBroken and Item:isBroken()

	print(PREFIX .. "removeItem " .. Name(Item)
		.. " doAnim=" .. Safe(DoAnim)
		.. " attachedSlot=" .. Safe(At)
		.. " attachedSlotType=" .. Safe(Item and Item.getAttachedSlotType and Item:getAttachedSlotType())
		.. " attachedToModel=" .. Safe(Item and Item.getAttachedToModel and Item:getAttachedToModel())
		.. " attachmentType=" .. Safe(Item and Item.getAttachmentType and Item:getAttachmentType()))

	print(PREFIX .. "  why: noSlot=" .. Safe(NoSlot)
		.. " cannotAttach=" .. Safe(CannotAttach)
		.. " notInInventory=" .. Safe(NotHeld)
		.. " broken=" .. Safe(Broken)
		.. " slotHere=" .. Safe(Slot and Slot.slotType) .. "/" .. Safe(Slot and Slot.name))

	print(PREFIX .. "  order=" .. SlotOrder(self)
		.. " saved=" .. SavedOrder(self)
		.. " bag=" .. WornBag(Character))

	return VanillaRemove(self, Item, DoAnim)
end

-- Refresh is where slots are rebuilt and where an item can be dropped for its slot type
-- no longer being provided. Printed on both sides so a change in the order is visible.
local VanillaRefresh = ISHotbar.refresh

function ISHotbar:refresh()
	local Before = SlotOrder(self)
	local Result = VanillaRefresh(self)

	local After = SlotOrder(self)
	if Before ~= After then
		print(PREFIX .. "refresh reordered " .. Before .. " -> " .. After
			.. " saved=" .. SavedOrder(self))
	end

	return Result
end

--// The Settled State
-- Installed from OnGameBoot rather than at file scope. Doing it at load time meant this
-- wrapper only existed if this file happened to load after qolc_reorder_hotbar.lua, and
-- when it did not the guard below skipped in silence and no settled line was ever printed
-- again. A whole test run was wasted on a log that could not have said anything. Mod file
-- load order is not guaranteed; by the time any event fires, every file has loaded.
local Wrapped = false

local function InstallWrapper()
	if Wrapped or not QolcHotbarApplyOrder then return end
	Wrapped = true

	local Vanilla = QolcHotbarApplyOrder

	function QolcHotbarApplyOrder(Hotbar, ForceSave)
		local Result = Vanilla(Hotbar, ForceSave)

		local Order = SlotOrder(Hotbar)
		local Saved = SavedOrder(Hotbar)

		print(PREFIX .. "settled order=" .. Order .. " saved=" .. Saved
			.. " forceSave=" .. Safe(ForceSave)
			.. (Order == Saved and " MATCH" or " MISMATCH"))

		return Result
	end
end

--// What Came Back
-- The question a rejoin actually turns on: does each item still carry the slot it was
-- attached to. reloadIcons rebuilds the bar by scanning the inventory for exactly this,
-- so an item arriving with -1 is one the server never knew about, whatever the client
-- believed before it disconnected.
local function ReportAttached(Player)
	local Inventory = Player and Player:getInventory()
	if not Inventory then return end

	local Items = Inventory:getItems()
	if not Items then return end

	local Found = 0
	for Index = 0, Items:size() - 1 do
		local Item = Items:get(Index)
		local Type = Item and Item.getAttachmentType and Item:getAttachmentType()

		if Type then
			Found = Found + 1
			print(PREFIX .. "  holds " .. Name(Item)
				.. " attachmentType=" .. Safe(Type)
				.. " attachedSlot=" .. Safe(Item:getAttachedSlot())
				.. " attachedSlotType=" .. Safe(Item.getAttachedSlotType and Item:getAttachedSlotType()))
		end
	end

	if Found == 0 then print(PREFIX .. "  holds nothing that can be attached") end
end

--// The Reconciler
-- Called by qolc_hotbar_sync.lua whenever it actually sends something, so a log shows
-- the binding being repaired rather than leaving it to be inferred from a rejoin.
function QolcHotbarSyncReport(Item, Binding)
	print(PREFIX .. "reconciled " .. Name(Item) .. " -> " .. Safe(Binding))
end

--// Connections
-- One line per join, so a log can be read from the moment the character arrives and it is
-- obvious the build really is the instrumented one.
local function OnCreatePlayer(_Index, Player)
	if not Player then return end

	InstallWrapper()
	print(PREFIX .. "joined, bag=" .. WornBag(Player)
		.. " wrapper=" .. tostring(Wrapped))
	ReportAttached(Player)
end

Events.OnGameBoot.Add(InstallWrapper)
Events.OnCreatePlayer.Add(OnCreatePlayer)
