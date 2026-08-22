--// Hotbar Survival Spec
--// aspctt - 21.08.2026
--// The bar coming back intact after a clothing change and after a fresh session.
--//
--// Reported on the workshop: the hotbar stopped working entirely, showing an empty frame
--// with no slots in it and offering nothing to attach to belt, holster or back. All of
--// these drive availableSlot into a shape vanilla tolerates and this mod did not.

--// Helpers
local function NewBar(Player, ...)
	local Hotbar = Harness.NewHotbar(Player, { ... })
	Harness.Fire("OnLoad")
	return Hotbar
end

local function Order(Hotbar)
	return table.concat(Harness.SlotOrder(Hotbar), ",")
end

local function Held(Hotbar)
	local Count = 0
	for _ in pairs(Hotbar.availableSlot) do Count = Count + 1 end
	return Count
end

local function SlotX(Hotbar, Index)
	return Hotbar.margins + (Hotbar.slotWidth + Hotbar.slotPad) * (Index - 1) + (Hotbar.slotWidth / 2)
end

local function DragSlot(Hotbar, From, To)
	local StartX, EndX = SlotX(Hotbar, From), SlotX(Hotbar, To)

	Hotbar.MouseX, Hotbar.MouseY = StartX, 30
	Hotbar:onMouseDown(StartX, 30)
	Hotbar.MouseX = EndX
	Hotbar:onMouseMove(0, 0)
	Hotbar:onMouseUp(EndX, 30)
end

-- What the character is wearing changed, so the bar rebuilds. The same call the game
-- makes off OnClothingUpdated.
local function Wear(Hotbar, ...)
	Harness.SetHotbarSlots(Hotbar, { ... })
	Hotbar.WornChanged = true
	Hotbar:refresh()
	Hotbar.WornChanged = false
end

--// A Lost Back Slot
-- The Back slot is the one the game guarantees, and refresh never puts it into
-- availableSlot: it goes into the local survival list and nowhere else. loadPosition is
-- the only code in the game that ever restores it, out of the saved order, so a saved
-- order that has lost it never gets it back.
Test("the back slot survives being moved off the front", function()
	local Player = Harness.NewPlayer(0, true)
	local Hotbar = NewBar(Player, "Back", "Belt")

	DragSlot(Hotbar, 1, 2)
	AssertEquals(Order(Hotbar), "Belt,Back", "the drag should have taken")

	Wear(Hotbar, "Back")

	AssertTrue(Hotbar:haveThisSlot("Back"), "the back slot should still be on the bar")
	AssertEquals(Held(Hotbar), 1, "and be the only thing left")
end)

Test("the back slot survives into the next session", function()
	local Player = Harness.NewPlayer(0, true)
	local Hotbar = NewBar(Player, "Back", "Belt")

	DragSlot(Hotbar, 1, 2)
	Wear(Hotbar, "Back")

	-- A new session for the same character: the bar is rebuilt from the saved order and
	-- nothing else.
	local Fresh = NewBar(Player, "Back")

	AssertTrue(Fresh:haveThisSlot("Back"), "the back slot should have come back")
	AssertTrue(Held(Fresh) > 0, "the bar should not be empty")
end)

Test("a saved order with a gap in it does not empty the bar", function()
	-- Vanilla writes exactly this. refresh nils the slots a departing garment provided
	-- and calls savePosition before compacting, so the order it saves has holes wherever
	-- those slots sat. With Back moved off the front, one of those holes is at index one.
	local Player = Harness.NewPlayer(0, true)
	Player:getModData().hotbar = { [2] = "Back", [3] = "Holster" }

	Harness.DeclareSlotType("Belt")
	Harness.DeclareSlotType("Holster")

	local Hotbar = NewBar(Player, "Back", "Holster")

	AssertTrue(Hotbar:haveThisSlot("Back"), "the back slot should have been read back")
	AssertTrue(Hotbar:haveThisSlot("Holster"), "and so should the holster")
	AssertEquals(Held(Hotbar), 2, "nothing should have been dropped past the gap")
end)

Test("a slot type that no longer resolves does not take the rest with it", function()
	-- A slot from a mod that has since been removed. getSlotDef stops answering for it,
	-- loadPosition skips it, and the order comes back with a hole where it was.
	local Player = Harness.NewPlayer(0, true)

	Harness.DeclareSlotType("Belt")
	Harness.DeclareSlotType("Sling")
	Player:getModData().hotbar = { "Sling", "Back", "Belt" }
	Harness.RetireSlotType("Sling")

	local Hotbar = NewBar(Player, "Back", "Belt")

	AssertTrue(Hotbar:haveThisSlot("Back"), "the back slot should have survived")
	AssertTrue(Hotbar:haveThisSlot("Belt"), "and so should the belt")
	AssertEquals(Held(Hotbar), 2, "the two that still resolve should both be there")
end)

Test("a clothing change on a bar with a gap keeps every slot that still applies", function()
	local Player = Harness.NewPlayer(0, true)
	local Hotbar = NewBar(Player, "Back", "Belt", "Holster")

	-- Straight into availableSlot, which is the shape vanilla leaves behind between its
	-- own prune and its own compaction, and the shape any refresh can be handed. The one
	-- taken out is the Back slot, because every other slot comes from a garment and a
	-- garment still worn puts its slot back. Back is the one nothing restores.
	Hotbar.availableSlot[1] = nil

	Wear(Hotbar, "Back", "Belt", "Holster")

	AssertEquals(Held(Hotbar), 3, "the bar should have been rebuilt whole")
	AssertTrue(Hotbar:haveThisSlot("Back"), "including the back slot")
end)

Test("a gap does not stop the order being reapplied", function()
	-- The sort reads a preferred index per slot and table.sort works off #, so a gap
	-- leaves it comparing two nils. This is what the compaction in front of it is for,
	-- as opposed to the back slot repair, which is what the test above is for.
	local Player = Harness.NewPlayer(0, true)
	local Hotbar = NewBar(Player, "Back", "Belt", "Holster")

	Hotbar.availableSlot[2] = nil

	local Ok, Failure = pcall(function() QolcHotbarApplyOrder(Hotbar, true) end)

	AssertTrue(Ok, "reapplying the order must not throw over it, got " .. tostring(Failure))
	AssertEquals(Held(Hotbar), 2, "both of the slots left should still be on the bar")
	AssertEquals(Order(Hotbar), "Back,Holster", "closed up, in the order they were in")
end)

Test("an item past a gap does not end up on somebody else's slot", function()
	-- The walk that moves departing slots to the back renumbers each item as it goes.
	-- Stopping at a gap leaves every item past it holding the index it had, and those
	-- indexes now point at whatever ended up there. reloadIcons rebuilds the bar from
	-- exactly those numbers, so a holster item lands on the back slot and ISHotbar:update
	-- then takes it off the bar entirely, since that slot will not have it.
	local Player = Harness.NewPlayer(0, true)
	local Hotbar = NewBar(Player, "Back", "Belt", "Holster")

	local Item = Harness.PutOnHotbar(Hotbar, 3, Harness.NewHotbarItem("Holster"))
	Hotbar.availableSlot[1] = nil

	Wear(Hotbar, "Back", "Belt", "Holster")

	local At = Item:getAttachedSlot()
	AssertTrue(At > 0, "the item should still be on the bar")
	AssertEquals(Hotbar.availableSlot[At].slotType, "Holster",
		"and still on the holster it was hanging from")
end)

--// The Switch
local function TurnHotbarOff()
	local Category = PZAPI.ModOptions:getOptions("QoLC")
	for _, Entry in ipairs(Category.data) do
		if Entry.id == "HotbarEnabled" then Entry:setValue(false) end
	end
end

Test("turning the feature off leaves the order still being saved", function()
	-- The override holds vanilla's own savePosition back for the length of its refresh
	-- and calls the real one afterwards. Reading the switch between those two halves left
	-- the first running and the second gone, so saving was switched off and never
	-- switched back on, for the rest of the session.
	local Player = Harness.NewPlayer(0, true)
	local Hotbar = NewBar(Player, "Back", "Belt")
	TurnHotbarOff()

	local Saves = Hotbar.SaveCount or 0
	Wear(Hotbar, "Back", "Belt", "Holster")

	AssertTrue((Hotbar.SaveCount or 0) > Saves, "vanilla should still be recording the order")
	AssertNotNil(Player:getModData().hotbar, "and it should have reached the character")
end)

Test("turning the feature off leaves no room for buttons that are not drawn", function()
	local Player = Harness.NewPlayer(0, true)
	local Hotbar = NewBar(Player, "Back", "Belt")
	TurnHotbarOff()

	local Width = Hotbar:getWidth()
	Hotbar:setSizeAndPosition()

	AssertTrue(Hotbar:getWidth() < Width, "the bar should have given the button strip back")
end)

--// Letting Go Away From The Bar
-- Reported on the workshop with a stack trace, from dragging tree branches out of a bag
-- onto the floor:
--
--   java.lang.RuntimeException: attempted index: def of non-table: null
--   Lua(Vanilla).canBeAttached(ISHotbar.lua:291)
--   Lua(Vanilla).onMouseUp(ISHotbar.lua:637)
--   Lua((MOD:QoL Compendium)).onMouseUpOutside(qolc_reorder_hotbar.lua)
--
-- onMouseUpOutside is only ever called for a release that landed somewhere other than
-- this element, and vanilla's onMouseUp is written for one that landed on it. Handing the
-- first to the second gives getSlotIndexAt a point off the bar, it answers -1, and the
-- drag branch reads availableSlot[-1] and hands the nil to canBeAttached.
Test("a drag let go away from the bar does not reach vanilla's mouse up", function()
	local Player = Harness.NewPlayer(0, true)
	local Hotbar = NewBar(Player, "Back", "Belt")

	-- The trace names vanilla's onMouseUp rather than ours, so by the time that release
	-- arrived ours was not the one installed. The reporter runs a second hotbar mod
	-- alongside this one, which is the likely reason, and there is nothing to be done
	-- about who owns onMouseUp. Handing it an outside release is the part that is ours,
	-- so the original is put back here and the question asked that way.
	ISHotbar.onMouseUp = Harness.VanillaHotbarMouseUp

	ISMouseDrag.dragging = { Harness.NewHotbarItem("Belt") }
	local Ups = Hotbar.VanillaMouseUps or 0

	local Ok, Failure = pcall(function() Hotbar:onMouseUpOutside(-40, -40) end)
	ISMouseDrag.dragging = nil

	AssertTrue(Ok, "letting go off the bar must not throw, got " .. tostring(Failure))
	AssertEquals(Hotbar.VanillaMouseUps or 0, Ups, "and must not run the mouse up at all")
end)

Test("letting go away from the bar still lets go of the window", function()
	-- ISPanelJoypad handles this to drop a window being dragged by its frame. Replacing
	-- it outright rather than adding to it left that undone.
	local Player = Harness.NewPlayer(0, true)
	local Hotbar = NewBar(Player, "Back", "Belt")

	local Outside = Hotbar.OutsideUps or 0
	Hotbar:onMouseUpOutside(-40, -40)

	AssertTrue((Hotbar.OutsideUps or 0) > Outside, "the panel's own handler should still run")
end)

Test("letting go away from the bar ends the drag", function()
	local Player = Harness.NewPlayer(0, true)
	local Hotbar = NewBar(Player, "Back", "Belt")

	Hotbar.MouseX, Hotbar.MouseY = SlotX(Hotbar, 1), 30
	Hotbar:onMouseDown(SlotX(Hotbar, 1), 30)
	Hotbar.MouseX = SlotX(Hotbar, 2)
	Hotbar:onMouseMove(0, 0)

	AssertTrue(Hotbar.QolcDragging, "the drag should be under way")
	Hotbar:onMouseUpOutside(-40, -40)

	AssertTrue(not Hotbar.QolcDragging, "and should have been let go of")
	AssertNil(Hotbar.QolcDragIndex, "with nothing still held")
end)

Test("a drag let go on a bar with no slots does not throw", function()
	-- getSlotIndexAt clamps to #availableSlot, which is zero here, so the index is zero
	-- and availableSlot[0] is nil. The same crash from a release that really did land on
	-- the bar. Reachable while the bar is empty, which is the state the report before
	-- this one described.
	local Player = Harness.NewPlayer(0, true)
	local Hotbar = NewBar(Player, "Back")
	Hotbar.availableSlot = {}
	TurnHotbarOff()

	ISMouseDrag.dragging = { Harness.NewHotbarItem("Back") }
	local Ok, Failure = pcall(function() Hotbar:onMouseUp(20, 30) end)
	ISMouseDrag.dragging = nil

	AssertTrue(Ok, "a drop on an empty bar must not throw, got " .. tostring(Failure))
end)

--// A Refresh That Throws
Test("a refresh that fails leaves the order still saveable", function()
	local Player = Harness.NewPlayer(0, true)
	local Hotbar = NewBar(Player, "Back", "Belt")

	-- Anything at all going wrong inside vanilla's refresh. What matters is what is left
	-- behind afterwards, not what threw.
	local Own = ISHotbar.reloadIcons
	ISHotbar.reloadIcons = function() error("refresh blew up") end

	Hotbar.WornChanged = true
	pcall(function() Hotbar:refresh() end)
	Hotbar.WornChanged = false

	ISHotbar.reloadIcons = Own

	local Saves = Hotbar.SaveCount or 0
	Hotbar:savePosition()

	AssertTrue((Hotbar.SaveCount or 0) > Saves,
		"savePosition should be the real one again, not the stub the override installs")
end)
