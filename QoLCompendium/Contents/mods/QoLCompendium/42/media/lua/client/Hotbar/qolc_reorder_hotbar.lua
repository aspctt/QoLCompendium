--// Reorder The Hotbar
--// Reorder The Hotbar, Workshop 2903771337 - Original design, MIT licensed
--// aspctt - 10.08.2026
--// Drag the hotbar slots into the order you want, and click a slot to use it instead of
--// reaching for its hotkey. Two small buttons sit at the right hand end: one locks the
--// order, the other chooses whether dragging swaps two slots or inserts between them.
--//
--// Vanilla rebuilds the bar whenever clothing changes and puts the Back slot first each
--// time, so an order cannot simply be left in place. A preferred index per slot type is
--// kept on the character and reapplied after each refresh, which is the only arrangement
--// that survives.
--//
--// It rebuilds by mutating availableSlot rather than replacing it, and the distinction
--// is the whole of what went wrong here once. That table is a map with gaps in it as an
--// ordinary state, and the Back slot goes into a local survival list rather than back
--// into it, so the bar keeps that slot only because loadPosition put it there when the
--// hotbar was built. See the note above SlotCount.
--//
--// Two things the original needed are now in the base game and are used instead of
--// being carried here: ISHotbar:getKeyForIndex replaces a thirty branch lookup from
--// index to hotkey, and ISHotbar:savePosition already persists slot order and transmits
--// it in multiplayer, so reordering ends by calling it rather than by hand rolling the
--// same thing.
--//
--// Client only. The hotbar is a window, and the order in it is stored on the character,
--// so savePosition's own transmit is all multiplayer needs.

require "Hotbar/ISHotbar"

--// Guards
-- Deliberately a local rather than a shared helper, for the same reason as the one in
-- qolc_sling_hotbar.lua: this runs at file scope, and lua file load order between mod
-- files is not guaranteed, so a cross file call here would be a load order landmine.
--
-- Clean HotBar ships its own reordering and replaces ISHotbar.render outright. Standing
-- down before anything is installed is what makes load order stop mattering: whichever
-- of the two loads first, the hotbar ends up entirely theirs. Leaving both in would give
-- the player two sets of buttons and two drag systems fighting over one slot order, which
-- is the overlap their own description warns about.
local function OverrideBlocked()
	if not getActivatedMods then return false end

	local Mods = getActivatedMods()
	if not Mods then return false end

	return Mods:contains("CleanHotBar")
end

if OverrideBlocked() then return end

--// Textures
local TextureUnlocked = getTexture("media/textures/GUI/qolc_lock_open.png")
local TextureLocked = getTexture("media/textures/GUI/qolc_lock_closed.png")
local TextureInsert = getTexture("media/textures/GUI/qolc_insert.png")
local TextureSwap = getTexture("media/textures/GUI/qolc_swap.png")

--// Tuning
-- The two buttons are stacked at the right hand end of the bar, past the last slot.
local BUTTON_SIZE = 18

-- One pixel of padding inside each button. The icons are drawn scaled to this rather
-- than at their own size, because drawTexture paints a texture at its native dimensions
-- and anything bigger than the cell spills out across the slots beside it.
local ICON_SIZE = BUTTON_SIZE - 2

-- How far the mouse has to travel before a press becomes a drag rather than a click.
local DRAG_THRESHOLD = 16

-- A press shorter than this with no movement counts as a click on the slot.
local CLICK_MS = 150

local INDEX_KEY = "QolcHotbarIndex"
local SWAP_KEY = "QolcHotbarInsert"
local LOCK_KEY = "QolcHotbarLocked"

local FontHeight = getTextManager():getFontHeight(UIFont.Small)

--// Functions
-- Keyed by slot type rather than position, so a slot keeps its place even when another
-- appears or disappears with a change of clothing.
local function GetSlotKey(SlotType)
	return SlotType .. INDEX_KEY
end

-- An item's slot index lives on the item, not in our record, and in multiplayer the
-- authoritative copy is the server's. Vanilla's attach and detach actions both follow
-- setAttachedSlot with syncItemFields, and not doing the same here is why a reordered
-- hotbar came back empty on rejoin: the slot order is in character mod data, which
-- savePosition transmits, but the item to slot binding rides on the item and travels in
-- SyncItemFieldsPacket. Sending one and not the other left the server holding indexes
-- that no longer matched, so reloadIcons found nothing to put back on the bar.
--
-- Sent when the index moved, and once per item besides. Sending only on a change was
-- half a fix: it asks what this client just did, which is not the same question as what
-- the server already knows. An item renumbered by a build without the sync, or by any
-- other route that skipped it, sits on the server with a stale index that no later
-- reorder will ever touch, because from here it looks like nothing changed. Reported as
-- the slot that was dragged surviving a rejoin while the one left alone did not.
--
-- Once per item per hotbar, not once per refresh, so the reconciliation costs one packet
-- an item on the first pass and nothing after. syncItemFields is a no-op outside a
-- multiplayer client, so it needs no guard of its own.
local function SetItemSlot(Hotbar, Item, Index)
	if not Item then return false end

	local Moved = Item:getAttachedSlot() ~= Index
	if Moved then Item:setAttachedSlot(Index) end

	-- Keyed by id rather than by the item itself, since the key has to survive the item
	-- being handed back as a different object.
	local Key = Item.getID and Item:getID() or Item
	Hotbar.QolcTold = Hotbar.QolcTold or {}

	if Moved or not Hotbar.QolcTold[Key] then
		if syncItemFields then syncItemFields(Hotbar.character, Item) end
		Hotbar.QolcTold[Key] = true
	end

	return Moved
end

local function IsLocked(Character)
	return Character:getModData()[LOCK_KEY] and true or false
end

local function IsInsertMode(Character)
	return Character:getModData()[SWAP_KEY] and true or false
end

--// Slots
-- availableSlot is a map, not an array, and vanilla treats it as one: all sixteen places
-- it touches the table walk it with pairs, and not one uses ipairs. Two ordinary things
-- put gaps in it. loadPosition writes an index only when the saved slot type still
-- resolves, so a slot belonging to a mod that has gone away leaves one. And refresh nils
-- the slots a departing garment provided, calls savePosition, and only compacts
-- afterwards, so between those two the table has a gap for every slot just dropped and
-- the order written to the character has the same gaps.
--
-- ipairs stops at the first one. Where the result was written back over the table, as it
-- was in MoveDepartingSlotsToBack, every slot past the gap was silently thrown away, and
-- since refresh never puts the Back slot into availableSlot, losing that one is not
-- something the game can undo: loadPosition is the only code that ever restores it, out
-- of a saved order our own savePosition had by then overwritten. Reported as a hotbar
-- that stopped working entirely, showing an empty frame and offering nothing to attach.
local function SlotCount(Hotbar)
	local Count = 0
	for _ in pairs(Hotbar.availableSlot) do Count = Count + 1 end

	return Count
end

-- Closes the gaps, keeping the slots in the order their indexes put them and carrying
-- each one's item with it. Vanilla compacts the same way at the end of its own refresh,
-- so this is the shape the bar is meant to be in rather than one of our own devising.
--
-- Renumbering a slot renumbers the item on it, which is why the items go through
-- SetItemSlot rather than being moved on their own: the binding lives on the item and in
-- multiplayer the server holds the copy that matters.
local function Compact(Hotbar)
	local Indexes = {}
	local Highest = 0

	for Index in pairs(Hotbar.availableSlot) do
		table.insert(Indexes, Index)
		if Index > Highest then Highest = Index end
	end

	-- Dense already, which is the ordinary case, so nothing is touched and no item is
	-- told anything it already knows.
	if Highest == #Indexes then return end
	table.sort(Indexes)

	local Slots = {}
	local Items = {}

	for Position, Index in ipairs(Indexes) do
		Slots[Position] = Hotbar.availableSlot[Index]
		Items[Position] = Hotbar.attachedItems[Index]
		SetItemSlot(Hotbar, Items[Position], Position)
	end

	Hotbar.availableSlot = Slots
	Hotbar.attachedItems = Items
end

-- Vanilla promises the bar always has a back attachment and then keeps only half of it.
-- Its refresh puts the Back slot into the local list it prunes against and never into
-- availableSlot, so the bar has that slot only because loadPosition put it there when the
-- hotbar was built, out of the saved order. Lose it once and nothing in the game brings
-- it back: the order it would be read from next time is the one savePosition has since
-- overwritten without it.
--
-- Vanilla can never lose it, because it forces Back to index one and its prune only ever
-- drops a slot some garment provided. Letting that slot be moved is this whole feature,
-- so holding on to it is this feature's job as well.
--
-- Added at the end rather than the front. Where it belongs is whatever position the
-- player chose, and QolcHotbarApplyOrder puts it there on the same pass.
local function RestoreBackSlot(Hotbar)
	if Hotbar:haveThisSlot("Back") then return end

	local Def = Hotbar:getSlotDef("Back")
	if not Def then return end

	Compact(Hotbar)
	Hotbar.availableSlot[SlotCount(Hotbar) + 1] = { slotType = Def.type, name = Def.name, def = Def }
end

-- The right hand edge of the last slot, which is where our buttons begin. Counted rather
-- than measured with #, so a gap cannot put the buttons on top of a slot.
local function GetButtonsX(Hotbar)
	return Hotbar.margins + (Hotbar.slotWidth + Hotbar.slotPad) * SlotCount(Hotbar)
end

--// Ordering
-- A slot with no stored index falls back to where it currently sits, so a new slot
-- lands at the end rather than jumping to the front.
local function GetPreferredIndexes(Character, Slots)
	local ModData = Character:getModData()
	local Preferred = {}

	for Index, Slot in ipairs(Slots) do
		Preferred[Slot] = ModData[GetSlotKey(Slot.slotType)] or Index
	end

	return Preferred
end

function QolcHotbarApplyOrder(Hotbar, ForceSave)
	if not QolcFeatureEnabled("Hotbar") then return end

	-- Before the sort, not after. table.sort works off # and the comparator reads a
	-- preferred index per slot, so a gap would leave it comparing two nils.
	Compact(Hotbar)

	local Preferred = GetPreferredIndexes(Hotbar.character, Hotbar.availableSlot)

	-- Items travel with their slot rather than their position, so the mapping has to be
	-- taken before the sort and rebuilt after it
	for Index, Slot in ipairs(Hotbar.availableSlot) do
		Slot.item = Hotbar.attachedItems[Index]
	end

	table.sort(Hotbar.availableSlot, function(A, B)
		if Preferred[A] == Preferred[B] then return A.slotType < B.slotType end
		return Preferred[A] < Preferred[B]
	end)

	Hotbar.attachedItems = {}
	local ModData = Hotbar.character:getModData()
	local Saved = ModData["hotbar"]
	local Moved = ForceSave and true or false

	for Index, Slot in ipairs(Hotbar.availableSlot) do
		if Slot.item then
			Hotbar.attachedItems[Index] = Slot.item

			-- Only the index. An item's other half, its slot type, never goes stale here
			-- because every path moves a slot with its item still on it.
			SetItemSlot(Hotbar, Slot.item, Index)
		end

		local Key = GetSlotKey(Slot.slotType)
		if ModData[Key] ~= Index then
			ModData[Key] = Index
			Moved = true
		end

		-- Vanilla's own record has to agree with the order on screen even when none of
		-- our own numbers changed.
		--
		-- Reported on a dedicated server as items going back into the inventory on
		-- rejoin. Every vanilla refresh rebuilds availableSlot in vanilla's order and
		-- writes that to modData.hotbar, and this sorts it back afterwards. When the
		-- preferred indexes were already stored, nothing above sets Moved, so vanilla's
		-- record kept vanilla's order while the screen showed ours. On rejoin the slots
		-- come back in vanilla's order, each item's stored index points at whatever now
		-- sits there, and ISHotbar:update takes off everything that no longer fits.
		if not Saved or Saved[Index] ~= Slot.slotType then Moved = true end
	end

	-- savePosition calls transmitModData, which sends a player's whole mod data, and this
	-- runs on every hotbar refresh. Hence saving only when the order really did change.
	if Moved then Hotbar:savePosition() end
end

-- Vanilla's refresh drops slots whose clothing has been taken off, and matches items to
-- slots by position while it does. Moving the doomed slots to the back first keeps every
-- surviving slot's item lined up with it.
--
-- Walks by position and writes what it collected back over the table, so it has to be
-- handed a bar with no gaps in it. Its one caller compacts first.
local function MoveDepartingSlotsToBack(Hotbar)
	if not Hotbar.wornItems then return end
	if not Hotbar:compareWornItems() then return end

	local Available = {}
	local BackDef = Hotbar:getSlotDef("Back")
	if BackDef then Available[BackDef.type] = true end

	local Worn = Hotbar.chr:getWornItems()
	for Index = 0, Worn:size() - 1 do
		local Item = Worn:getItemByIndex(Index)
		if Item and Hotbar.chr:isHandItem(Item) then Item = nil end

		local Provided = Item and Item:getAttachmentsProvided()
		if Provided then
			for Slot = 0, Provided:size() - 1 do
				local Def = Hotbar:getSlotDef(Provided:get(Slot))
				if Def then Available[Def.type] = true end
			end
		end
	end

	local NewSlots = {}
	local NewItems = {}
	local Next = 1

	-- Survivors first, in their current order, then the rest
	for _, Keep in ipairs({ true, false }) do
		for Index, Slot in ipairs(Hotbar.availableSlot) do
			if (Available[Slot.slotType] and true or false) == Keep then
				NewSlots[Next] = Slot
				NewItems[Next] = Hotbar.attachedItems[Index]
				SetItemSlot(Hotbar, NewItems[Next], Next)
				Next = Next + 1
			end
		end
	end

	Hotbar.availableSlot = NewSlots
	Hotbar.attachedItems = NewItems
end

--// Reordering
local function WriteSlot(Hotbar, Index, Slot)
	Hotbar.character:getModData()[GetSlotKey(Slot.slotType)] = Index
	Hotbar.availableSlot[Index] = Slot
	Hotbar.attachedItems[Index] = Slot.item

	SetItemSlot(Hotbar, Slot.item, Index)
end

local function CaptureItems(Hotbar)
	for Index, Slot in ipairs(Hotbar.availableSlot) do
		Slot.item = Hotbar.attachedItems[Index]
	end
end

local function SwapSlots(Hotbar, From, To)
	if From == To then return end
	CaptureItems(Hotbar)

	local FromSlot = Hotbar.availableSlot[From]
	local ToSlot = Hotbar.availableSlot[To]
	if not FromSlot or not ToSlot then return end

	WriteSlot(Hotbar, To, FromSlot)
	WriteSlot(Hotbar, From, ToSlot)

	Hotbar.wornItems = nil
	Hotbar:refresh()
end

-- Takes the slot out and puts it back at the new position, sliding everything between
-- along by one rather than exchanging the two ends.
local function InsertSlot(Hotbar, From, To)
	if From == To then return end
	CaptureItems(Hotbar)

	local Moving = Hotbar.availableSlot[From]
	if not Moving then return end

	if To < From then
		for Index = From - 1, To, -1 do
			WriteSlot(Hotbar, Index + 1, Hotbar.availableSlot[Index])
		end
	else
		for Index = From + 1, To do
			WriteSlot(Hotbar, Index - 1, Hotbar.availableSlot[Index])
		end
	end

	WriteSlot(Hotbar, To, Moving)

	Hotbar.wornItems = nil
	Hotbar:refresh()
end

--// Overrides
-- Vanilla clamps a click past the last slot onto the last slot. Our two buttons sit
-- past it, so without this every click on them would also fire the final slot.
local VanillaGetSlotIndexAt = ISHotbar.getSlotIndexAt
function ISHotbar:getSlotIndexAt(X, Y)
	if not QolcFeatureEnabled("Hotbar") then return VanillaGetSlotIndexAt(self, X, Y) end
	if X >= GetButtonsX(self) then return -1 end
	return VanillaGetSlotIndexAt(self, X, Y)
end

-- The first refresh runs before anything is attached, so ordering it would fight the
-- game while it is still setting the hotbar up.
local VanillaRefresh = ISHotbar.refresh
function ISHotbar:refresh()
	-- The switch is read here rather than deeper in, and that matters. Everything below
	-- is one piece: vanilla's own savePosition is held back for the length of its refresh
	-- and the call that replaces it comes afterwards, in QolcHotbarApplyOrder. That is
	-- where the switch used to be read, so turning the tick box off left the first half
	-- running and took the second half away. Vanilla's refresh then ran with saving
	-- switched off and nothing put it back, and the order quietly stopped being written
	-- for the rest of the session.
	--
	-- The back slot repair still runs, because putting back a slot an earlier session
	-- dropped is not a feature anyone would want to switch off.
	if not QolcFeatureEnabled("Hotbar") then
		VanillaRefresh(self)
		RestoreBackSlot(self)
		return
	end

	if not self.QolcReady then
		VanillaRefresh(self)
		RestoreBackSlot(self)
		self.needsRefresh = true
		self.QolcReady = true
		return
	end

	-- Whatever the last pass left behind, the bar starts this one whole. A refresh that
	-- failed partway leaves the gaps its prune opened, and nothing else closes them.
	Compact(self)

	-- Vanilla's refresh does nothing at all unless worn items actually changed, because
	-- OnClothingUpdated also fires for blood, holes and wetness. Its own comment calls
	-- that "quite often". Reordering regardless meant a sort, a mod data write and, in
	-- multiplayer, a transmitModData on every one of those, which is a flood of whole
	-- player mod data to the server during any fight or rain.
	local Changed = (not self.wornItems) or self:compareWornItems()
	if not Changed then
		VanillaRefresh(self)
		RestoreBackSlot(self)
		return
	end

	MoveDepartingSlotsToBack(self)

	-- Vanilla saves the order partway through its own rebuild, before we have sorted it,
	-- so the record it leaves behind is vanilla's order and not the player's. Holding that
	-- save back until the order is final keeps a clothing change at one transmit rather
	-- than two, and leaves the saved record agreeing with the bar on screen.
	local Own = rawget(self, "savePosition")
	local Pending = false
	self.savePosition = function() Pending = true end

	-- Through pcall, because leaving that stub behind is worse than whatever put it
	-- there. It sits on the instance, so it wins over the real one for the rest of the
	-- session: the order would quietly stop being saved and, in multiplayer, stop being
	-- transmitted, and nothing would say so. The error is raised again once the real
	-- savePosition is back, so it still reaches the log rather than being swallowed.
	local Ok, Failure = pcall(VanillaRefresh, self)

	self.savePosition = Own
	if not Ok then error(Failure) end

	RestoreBackSlot(self)
	QolcHotbarApplyOrder(self, Pending)
end

local VanillaLoadPosition = ISHotbar.loadPosition
function ISHotbar:loadPosition()
	VanillaLoadPosition(self)
	if self.QolcReady then QolcHotbarApplyOrder(self) end
end

-- Room at the right hand end for the lock and mode buttons
local VanillaSetSizeAndPosition = ISHotbar.setSizeAndPosition
function ISHotbar:setSizeAndPosition()
	VanillaSetSizeAndPosition(self)
	if not QolcFeatureEnabled("Hotbar") then return end

	self:setWidth(self:getWidth() + BUTTON_SIZE)
end

-- Vanilla resolves a right click to a slot index before this point, and it uses the
-- clamped index, so the menu can open on the wrong slot. Recomputing from the mouse
-- fixes it, and only while a right click is actually being handled.
local VanillaRightMouseUp = ISHotbar.onRightMouseUp
function ISHotbar:onRightMouseUp(X, Y)
	self.QolcRightClicking = true
	VanillaRightMouseUp(self, X, Y)
	self.QolcRightClicking = false
end

local VanillaDoMenu = ISHotbar.doMenu
function ISHotbar:doMenu(SlotIndex)
	if self.QolcRightClicking then
		local Index = self:getSlotIndexAt(self:getMouseX(), self:getMouseY())
		if Index > 0 and Index <= SlotCount(self) then SlotIndex = Index end
	end
	VanillaDoMenu(self, SlotIndex)
end

--// Mouse
-- Vanilla has no onMouseDown or onMouseMove on the hotbar, so these are additions
-- rather than overrides.
function ISHotbar:onMouseDown(X, Y)
	if not QolcFeatureEnabled("Hotbar") then return end

	self.QolcPressedAt = getTimestampMs()

	local Index = self:getSlotIndexAt(X, Y)
	if Index < 0 or IsLocked(self.character) then return end

	self.QolcDragIndex = Index
	self.QolcDragStartX = X
	self.QolcDragStartY = Y
end

function ISHotbar:onMouseMove(_DX, _DY)
	if not QolcFeatureEnabled("Hotbar") then return end
	if not self.QolcDragIndex then return end

	local DX = self:getMouseX() - self.QolcDragStartX
	local DY = self:getMouseY() - self.QolcDragStartY

	if math.abs(DX) + math.abs(DY) > DRAG_THRESHOLD then
		self.QolcDragging = true
	end
end

-- Captured here rather than in OnLoad, because by then the name refers to the function
-- below and calling it would recurse forever.
local VanillaMouseUp = ISHotbar.onMouseUp

-- Handles the three things a release can mean: finishing a drag, clicking a slot, or
-- clicking one of the two buttons past the end of the bar.
--
-- The other end of this, onMouseDown, already stands aside when the tick box is off. This
-- did not, and with the buttons neither drawn nor made room for, a release past the last
-- slot still landed in the strip they would have occupied and toggled one of them.
function ISHotbar:onMouseUp(X, Y)
	local Index = self:getSlotIndexAt(X, Y)

	-- Only when the release really did land on a slot. Vanilla clamps a point past the
	-- last one onto it, so ours answers minus one for the strip the buttons sit in.
	--
	-- Greater than zero rather than not minus one, because zero is reachable too:
	-- vanilla's own getSlotIndexAt clamps to the number of slots, so a bar with none
	-- answers zero for a point on it. Its drag branch then reads availableSlot at that
	-- index and hands the nil to canBeAttached, which indexes it without checking.
	if Index > 0 then VanillaMouseUp(self, X, Y) end
	if not QolcFeatureEnabled("Hotbar") then return end

	if self.QolcDragging then
		if Index > 0 and Index ~= self.QolcDragIndex then
			if IsInsertMode(self.character) then
				InsertSlot(self, self.QolcDragIndex, Index)
			else
				SwapSlots(self, self.QolcDragIndex, Index)
			end
		end
	elseif Index > 0 and (getTimestampMs() - (self.QolcPressedAt or 0)) < CLICK_MS then
		-- Clicking a slot stands in for its hotkey, which is why a slot past the
		-- vanilla five does nothing unless that key has been bound
		local Key = self:getKeyForIndex(Index)
		if Key and Key ~= -1 then
			ISHotbar.onKeyStartPressed(Key)
			ISHotbar.onKeyPressed(Key)
		end
	else
		local ButtonsX = GetButtonsX(self)
		if X > ButtonsX and X < ButtonsX + BUTTON_SIZE then
			local ModData = self.character:getModData()

			if Y > 0 and Y < BUTTON_SIZE then
				ModData[LOCK_KEY] = not ModData[LOCK_KEY]
				getSoundManager():playUISound("UIToggleTickBox")
			elseif Y > BUTTON_SIZE and Y < BUTTON_SIZE * 2 then
				ModData[SWAP_KEY] = not ModData[SWAP_KEY]
				getSoundManager():playUISound("UIToggleTickBox")
			end
		end
	end

	self.QolcDragging = false
	self.QolcDragIndex = nil
	self.QolcDragStartX = nil
	self.QolcDragStartY = nil
end

-- Only ever called for a release that landed somewhere other than this element, which is
-- exactly why it must not be handed to onMouseUp. Vanilla's is written for a release on
-- the bar: its drag branch reads self.availableSlot[self:getSlotIndexAt(x, y)] and passes
-- the result to canBeAttached, which indexes it without checking. Out here getSlotIndexAt
-- answers minus one and there is nothing at that index.
--
-- Reported from dragging a stack of branches out of a bag onto the floor, as "attempted
-- index: def of non-table: null" at ISHotbar.lua:291, with this file named as the caller.
-- Ours guards the index and so never reached it, but the trace names vanilla's, so by
-- then something else owned onMouseUp. Whose it is was never ours to decide. Whether an
-- outside release is handed to it is.
--
-- Nothing needs finishing either way. A drag that ends off the bar has no slot under it,
-- so it is simply let go of. The panel's own handler still runs, since that is what drops
-- a window being dragged around by its frame.
local VanillaMouseUpOutside = ISHotbar.onMouseUpOutside

function ISHotbar:onMouseUpOutside(X, Y)
	if VanillaMouseUpOutside then VanillaMouseUpOutside(self, X, Y) end

	self.QolcDragging = false
	self.QolcDragIndex = nil
	self.QolcDragStartX = nil
	self.QolcDragStartY = nil
	self.QolcPressedAt = nil
end

--// Rendering
function ISHotbar:QolcRender()
	if not QolcFeatureEnabled("Hotbar") then return ISHotbar.QolcVanillaRender(self) end

	-- Condition fills, if that feature is present. Drawn from here rather than by
	-- overriding ISHotbar.render a second time, because this file already owns it and
	-- two overrides of one function is how mods quietly erase each other.
	--
	-- Before the vanilla render, so the colour sits behind the item icon instead of
	-- washing over it. Vanilla only draws slot borders and the icon itself, so there is
	-- nothing underneath that would hide it.
	--
	-- The slot geometry matches vanilla's own loop in ISHotbar:render, which starts at
	-- margins + 1 and steps by the slot width plus its padding.
	if QolcDrawCondition then
		local SlotX = self.margins + 1

		for Index, _Slot in ipairs(self.availableSlot) do
			local Item = self.attachedItems[Index]
			if Item then
				QolcDrawCondition(self, SlotX, self.margins + 1, self.slotWidth, self.slotHeight, Item)
			end
			SlotX = SlotX + self.slotWidth + self.slotPad
		end
	end

	ISHotbar.QolcVanillaRender(self)

	local ModData = self.character:getModData()
	local X = GetButtonsX(self)
	local Border = self.borderColor

	self:drawRect(X, 0, BUTTON_SIZE, BUTTON_SIZE, 0.8, 0, 0, 0)
	self:drawRectBorderStatic(X, 0, BUTTON_SIZE, BUTTON_SIZE, Border.a, Border.r, Border.g, Border.b)
	self:drawTextureScaled(ModData[LOCK_KEY] and TextureLocked or TextureUnlocked,
		X + 1, 1, ICON_SIZE, ICON_SIZE, 1, 1, 1, 1)

	self:drawRect(X, BUTTON_SIZE, BUTTON_SIZE, BUTTON_SIZE, 0.8, 0, 0, 0)
	self:drawRectBorderStatic(X, BUTTON_SIZE, BUTTON_SIZE, BUTTON_SIZE, Border.a, Border.r, Border.g, Border.b)
	self:drawTextureScaled(ModData[SWAP_KEY] and TextureInsert or TextureSwap,
		X + 1, BUTTON_SIZE + 1, ICON_SIZE, ICON_SIZE, 1, 1, 1, 1)

	if not self.QolcDragging then return end

	-- The slot being dragged follows the mouse, drawn on top of everything else
	local Slot = self.availableSlot[self.QolcDragIndex]
	local Item = self.attachedItems[self.QolcDragIndex]
	if not Slot then return end

	local DragX = self:getMouseX() - (self.slotWidth / 2)
	local DragY = self:getMouseY() - (self.slotHeight / 2)

	self:drawRectBorderStatic(DragX, DragY, self.slotWidth, self.slotHeight, Border.a, Border.r, Border.g, Border.b)

	local Name = getTextOrNull("IGUI_HotbarAttachment_" .. Slot.slotType) or Slot.name
	local Width = getTextManager():MeasureStringX(UIFont.Small, Name)
	local Text = self.textColor

	self:drawText(Name, DragX + ((self.slotWidth - Width) / 2), DragY - FontHeight,
		Text.r, Text.g, Text.b, Text.a, self.font)

	if Item then
		local Texture = Item:getTexture()
		if Texture then
			self:drawTexture(Texture, DragX + (Texture:getWidth() / 2), DragY + (Texture:getHeight() / 2), 1, 1, 1, 1)
		end
	end
end

--// Connections
-- Taken on load rather than at file scope. Rendering the hotbar is the kind of thing a
-- mod replaces wholesale, so capturing the original here means whatever ends up in
-- ISHotbar.render still runs, instead of being dropped.
local function OnLoad()
	if ISHotbar.render == ISHotbar.QolcRender then return end

	ISHotbar.QolcVanillaRender = ISHotbar.render
	ISHotbar.render = ISHotbar.QolcRender
end

Events.OnLoad.Add(OnLoad)
