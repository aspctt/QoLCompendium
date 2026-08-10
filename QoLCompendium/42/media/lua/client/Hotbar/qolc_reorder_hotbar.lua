--// Reorder The Hotbar
--// Reorder The Hotbar, Workshop 2903771337 - Original design, MIT licensed
--// aspctt - 10.08.2026
--// Drag the hotbar slots into the order you want, and click a slot to use it instead of
--// reaching for its hotkey. Two small buttons sit at the right hand end: one locks the
--// order, the other chooses whether dragging swaps two slots or inserts between them.
--//
--// Vanilla rebuilds availableSlot from scratch whenever clothing changes, and always
--// forces the Back slot to position one, so an order cannot simply be left in place. A
--// preferred index per slot type is kept on the character and reapplied after each
--// refresh, which is the only arrangement that survives.
--//
--// Two things the original needed are now in the base game and are used instead of
--// being carried here: ISHotbar:getKeyForIndex replaces a thirty branch lookup from
--// index to hotkey, and ISHotbar:savePosition already persists slot order and transmits
--// it in multiplayer, so reordering ends by calling it rather than by hand rolling the
--// same thing.
--//
--// Client only. The hotbar is a window, and the order in it is stored on the character,
--// so savePosition's own transmit is all multiplayer needs.

require "ISUI/ISHotbar"

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

local function IsLocked(Character)
	return Character:getModData()[LOCK_KEY] and true or false
end

local function IsInsertMode(Character)
	return Character:getModData()[SWAP_KEY] and true or false
end

-- The right hand edge of the last slot, which is where our buttons begin.
local function GetButtonsX(Hotbar)
	return Hotbar.margins + (Hotbar.slotWidth + Hotbar.slotPad) * #Hotbar.availableSlot
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

function QolcHotbarApplyOrder(Hotbar)
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

	for Index, Slot in ipairs(Hotbar.availableSlot) do
		if Slot.item then
			Hotbar.attachedItems[Index] = Slot.item
			Slot.item:setAttachedSlot(Index)
		end
		ModData[GetSlotKey(Slot.slotType)] = Index
	end

	-- Vanilla's own record of the order, which also transmits it in multiplayer
	Hotbar:savePosition()
end

-- Vanilla's refresh drops slots whose clothing has been taken off, and matches items to
-- slots by position while it does. Moving the doomed slots to the back first keeps every
-- surviving slot's item lined up with it.
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
				if NewItems[Next] then NewItems[Next]:setAttachedSlot(Next) end
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

	if Slot.item then Slot.item:setAttachedSlot(Index) end
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
	if X >= GetButtonsX(self) then return -1 end
	return VanillaGetSlotIndexAt(self, X, Y)
end

-- The first refresh runs before anything is attached, so ordering it would fight the
-- game while it is still setting the hotbar up.
local VanillaRefresh = ISHotbar.refresh
function ISHotbar:refresh()
	if not self.QolcReady then
		VanillaRefresh(self)
		self.needsRefresh = true
		self.QolcReady = true
		return
	end

	MoveDepartingSlotsToBack(self)
	VanillaRefresh(self)
	QolcHotbarApplyOrder(self)
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
		if Index > 0 and Index <= #self.availableSlot then SlotIndex = Index end
	end
	VanillaDoMenu(self, SlotIndex)
end

--// Mouse
-- Vanilla has no onMouseDown or onMouseMove on the hotbar, so these are additions
-- rather than overrides.
function ISHotbar:onMouseDown(X, Y)
	self.QolcPressedAt = getTimestampMs()

	local Index = self:getSlotIndexAt(X, Y)
	if Index < 0 or IsLocked(self.character) then return end

	self.QolcDragIndex = Index
	self.QolcDragStartX = X
	self.QolcDragStartY = Y
end

function ISHotbar:onMouseMove(_DX, _DY)
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
function ISHotbar:onMouseUp(X, Y)
	local Index = self:getSlotIndexAt(X, Y)

	-- Vanilla would clamp a click past the last slot onto it, so only let it run when
	-- the release actually landed on a slot
	if Index ~= -1 then
		VanillaMouseUp(self, X, Y)
	end

	if self.QolcDragging then
		if Index ~= -1 and Index ~= self.QolcDragIndex then
			if IsInsertMode(self.character) then
				InsertSlot(self, self.QolcDragIndex, Index)
			else
				SwapSlots(self, self.QolcDragIndex, Index)
			end
		end
	elseif Index > -1 and (getTimestampMs() - (self.QolcPressedAt or 0)) < CLICK_MS then
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

function ISHotbar:onMouseUpOutside(X, Y)
	self:onMouseUp(X, Y)
end

--// Rendering
function ISHotbar:QolcRender()
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
