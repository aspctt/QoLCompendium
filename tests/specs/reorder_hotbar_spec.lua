--// Reorder The Hotbar Spec
--// aspctt - 10.08.2026

--// Helpers
local function NewHotbar(...)
	local Player = Harness.NewPlayer(0, true)
	local Hotbar = Harness.NewHotbar(Player, { ... })
	Harness.Fire("OnLoad")
	return Hotbar, Player
end

local function Order(Hotbar)
	return table.concat(Harness.SlotOrder(Hotbar), ",")
end

-- The centre of a slot, in the hotbar's own coordinates
local function SlotX(Hotbar, Index)
	return Hotbar.margins + (Hotbar.slotWidth + Hotbar.slotPad) * (Index - 1) + (Hotbar.slotWidth / 2)
end

-- Presses a slot, drags to another, and lets go
local function DragSlot(Hotbar, From, To)
	local StartX = SlotX(Hotbar, From)
	local EndX = SlotX(Hotbar, To)

	Hotbar.MouseX = StartX
	Hotbar.MouseY = 30
	Hotbar:onMouseDown(StartX, 30)

	Hotbar.MouseX = EndX
	Hotbar:onMouseMove(0, 0)
	Hotbar:onMouseUp(EndX, 30)
end

local function ClickSlot(Hotbar, Index)
	local X = SlotX(Hotbar, Index)
	Hotbar.MouseX = X
	Hotbar.MouseY = 30
	Hotbar:onMouseDown(X, 30)
	Hotbar:onMouseUp(X, 30)
end

-- The two buttons past the last slot
local function ClickButton(Hotbar, Which)
	local X = Hotbar.margins + (Hotbar.slotWidth + Hotbar.slotPad) * #Hotbar.availableSlot + 2
	local Y = (Which == "lock") and 9 or 27

	Hotbar.MouseX = X
	Hotbar.MouseY = Y
	Hotbar:onMouseDown(X, Y)
	Hotbar:onMouseUp(X, Y)
end

--// Wiring
Test("the render override is installed on load", function()
	local Hotbar = NewHotbar("Back", "Belt")
	AssertEquals(ISHotbar.render, ISHotbar.QolcRender, "render should be ours after OnLoad")
	AssertNotNil(ISHotbar.QolcVanillaRender, "and the original should have been captured")
end)

Test("loading twice does not capture our own render", function()
	NewHotbar("Back", "Belt")
	Harness.Fire("OnLoad")
	Harness.Fire("OnLoad")

	AssertTrue(ISHotbar.QolcVanillaRender ~= ISHotbar.QolcRender,
		"capturing our own render would recurse forever")
end)

Test("the bar is widened to fit the two buttons", function()
	local Hotbar = NewHotbar("Back", "Belt")
	local Slots = Hotbar.margins * 2 + (Hotbar.slotWidth + Hotbar.slotPad) * 2

	AssertEquals(Hotbar:getWidth(), Slots + 18, "there should be room for the buttons")
end)

--// Rendering
Test("the button icons stay inside their cells", function()
	-- Reported in game: the icons overflowed their 18 pixel buttons and covered the
	-- slots beside them, because drawTexture paints at the texture's own size.
	local Hotbar = NewHotbar("Back", "Belt")
	Hotbar.Drawn = {}
	Hotbar:render()

	local Found = 0
	for _, Draw in ipairs(Hotbar.Drawn) do
		if Draw.Kind == "texture" then
			Found = Found + 1
			AssertTrue(Draw.W <= 18 and Draw.H <= 18,
				"an icon was drawn at " .. tostring(Draw.W) .. "x" .. tostring(Draw.H)
					.. ", larger than its 18 pixel button")
		end
	end

	AssertEquals(Found, 2, "the lock and mode icons should both be drawn")
end)

Test("the icons sit within the button strip", function()
	local Hotbar = NewHotbar("Back", "Belt")
	Hotbar.Drawn = {}
	Hotbar:render()

	local Left = Hotbar.margins + (Hotbar.slotWidth + Hotbar.slotPad) * #Hotbar.availableSlot

	for _, Draw in ipairs(Hotbar.Drawn) do
		if Draw.Kind == "texture" then
			AssertTrue(Draw.X >= Left, "an icon was drawn left of the button strip")
			AssertTrue(Draw.X + Draw.W <= Left + 18, "an icon ran past the right of the strip")
		end
	end
end)

--// Ordering
Test("swapping two slots holds across a refresh", function()
	local Hotbar = NewHotbar("Back", "Belt", "Holster")
	AssertEquals(Order(Hotbar), "Back,Belt,Holster", "the game's own order to start")

	DragSlot(Hotbar, 1, 3)
	AssertEquals(Order(Hotbar), "Holster,Belt,Back", "the two ends should have traded places")

	Hotbar.WornChanged = true
	Hotbar:refresh()
	AssertEquals(Order(Hotbar), "Holster,Belt,Back",
		"and survive the rebuild a change of clothing causes")
end)

Test("the game putting Back first again is undone", function()
	-- Vanilla forces Back to slot one on every refresh, which is the reason a preferred
	-- index has to be kept rather than the order simply left alone.
	local Hotbar = NewHotbar("Back", "Belt")

	DragSlot(Hotbar, 1, 2)
	AssertEquals(Order(Hotbar), "Belt,Back", "Back should have moved second")

	for _ = 1, 5 do
		Hotbar.WornChanged = true
		Hotbar:refresh()
	end

	AssertEquals(Order(Hotbar), "Belt,Back", "and stay there")
end)

Test("insert mode slides the slots between rather than trading ends", function()
	local Hotbar, Player = NewHotbar("Back", "Belt", "Holster", "Sling")
	Player:getModData().QolcHotbarInsert = true

	-- Take the last slot and drop it at the front
	DragSlot(Hotbar, 4, 1)

	AssertEquals(Order(Hotbar), "Sling,Back,Belt,Holster",
		"everything else should shift along by one")
end)

Test("swap mode trades exactly two slots", function()
	local Hotbar = NewHotbar("Back", "Belt", "Holster", "Sling")

	DragSlot(Hotbar, 4, 1)
	AssertEquals(Order(Hotbar), "Sling,Belt,Holster,Back",
		"the middle two should not have moved")
end)

Test("inserting forwards shifts the other way", function()
	local Hotbar, Player = NewHotbar("Back", "Belt", "Holster", "Sling")
	Player:getModData().QolcHotbarInsert = true

	DragSlot(Hotbar, 1, 3)
	AssertEquals(Order(Hotbar), "Belt,Holster,Back,Sling", "the moved slot should land third")
end)

Test("an attached item travels with its slot", function()
	local Hotbar = NewHotbar("Back", "Belt", "Holster")

	local Item = Harness.NewInventoryItem("Axe")
	Item.AttachedSlot = nil
	function Item:setAttachedSlot(Index) self.AttachedSlot = Index end

	Hotbar.attachedItems[3] = Item
	Hotbar.availableSlot[3].item = Item

	DragSlot(Hotbar, 3, 1)

	AssertEquals(Order(Hotbar), "Holster,Belt,Back", "the holster should be first")
	AssertEquals(Hotbar.attachedItems[1], Item, "and its item should have come with it")
	AssertEquals(Item.AttachedSlot, 1, "the item should know its new slot")
end)

Test("a new slot appears at the end rather than the front", function()
	local Hotbar = NewHotbar("Back", "Belt")
	DragSlot(Hotbar, 1, 2)

	Harness.SetHotbarSlots(Hotbar, { "Back", "Belt", "Holster" })
	Hotbar.WornChanged = true
	Hotbar:refresh()

	AssertEquals(Order(Hotbar), "Belt,Back,Holster",
		"putting on new clothing should not disturb the chosen order")
end)

Test("the order is written through the game's own save", function()
	local Hotbar, Player = NewHotbar("Back", "Belt", "Holster")
	DragSlot(Hotbar, 1, 3)

	AssertEquals(table.concat(Player:getModData().hotbar, ","), "Holster,Belt,Back",
		"vanilla's own record should agree with ours")
end)

--// Locking
Test("a locked hotbar refuses to reorder", function()
	local Hotbar = NewHotbar("Back", "Belt", "Holster")
	ClickButton(Hotbar, "lock")

	local Before = Order(Hotbar)
	DragSlot(Hotbar, 1, 3)

	AssertEquals(Order(Hotbar), Before, "dragging should do nothing while locked")
end)

Test("the lock button toggles both ways", function()
	local Hotbar, Player = NewHotbar("Back", "Belt")

	ClickButton(Hotbar, "lock")
	AssertTrue(Player:getModData().QolcHotbarLocked, "should now be locked")

	ClickButton(Hotbar, "lock")
	AssertFalse(Player:getModData().QolcHotbarLocked, "and unlocked again")
end)

Test("the mode button toggles swap and insert", function()
	local Hotbar, Player = NewHotbar("Back", "Belt")

	AssertFalse(Player:getModData().QolcHotbarInsert or false, "swap is the default")
	ClickButton(Hotbar, "mode")
	AssertTrue(Player:getModData().QolcHotbarInsert, "should now be insert mode")
end)

Test("clicking a button plays the tick sound", function()
	local Hotbar = NewHotbar("Back", "Belt")
	local Before = #Harness.UISounds

	ClickButton(Hotbar, "lock")
	AssertTrue(#Harness.UISounds > Before, "a toggle should be audible")
end)

--// Clicking Slots
Test("clicking a slot presses its hotkey", function()
	local Hotbar = NewHotbar("Back", "Belt", "Holster")
	Harness.HotkeyPresses = {}

	ClickSlot(Hotbar, 2)

	AssertEquals(#Harness.HotkeyPresses, 2, "a click is a start and a press")
	AssertEquals(Harness.HotkeyPresses[1].Key, Harness.BoundKeys["Hotbar 2"],
		"slot two should use the Hotbar 2 binding")
end)

Test("clicking a slot with no binding does nothing", function()
	-- Vanilla only ships bindings to Hotbar 8, and getKey returns -1 past that.
	local Types = {}
	for Index = 1, 10 do Types[Index] = "Slot" .. Index end

	local Player = Harness.NewPlayer(0, true)
	local Hotbar = Harness.NewHotbar(Player, Types)
	Harness.Fire("OnLoad")
	Harness.HotkeyPresses = {}

	ClickSlot(Hotbar, 10)
	AssertEquals(#Harness.HotkeyPresses, 0, "an unbound slot should not fire anything")
end)

Test("a drag is not also treated as a click", function()
	local Hotbar = NewHotbar("Back", "Belt", "Holster")
	Harness.HotkeyPresses = {}

	DragSlot(Hotbar, 1, 3)
	AssertEquals(#Harness.HotkeyPresses, 0, "finishing a drag should not use the slot")
end)

--// Button Area
Test("a click past the last slot is not a slot click", function()
	-- Vanilla clamps anything past the end onto the last slot, which would make every
	-- press of our buttons also fire the final hotkey.
	local Hotbar = NewHotbar("Back", "Belt")
	local X = Hotbar.margins + (Hotbar.slotWidth + Hotbar.slotPad) * 2 + 2

	AssertEquals(Hotbar:getSlotIndexAt(X, 9), -1, "the button strip is not a slot")
end)

Test("clicks on real slots still resolve", function()
	local Hotbar = NewHotbar("Back", "Belt", "Holster")

	AssertEquals(Hotbar:getSlotIndexAt(SlotX(Hotbar, 1), 30), 1, "first slot")
	AssertEquals(Hotbar:getSlotIndexAt(SlotX(Hotbar, 3), 30), 3, "third slot")
end)

Test("the vanilla mouse up only runs for real slots", function()
	local Hotbar = NewHotbar("Back", "Belt")
	Hotbar.VanillaMouseUps = 0

	ClickButton(Hotbar, "lock")
	AssertEquals(Hotbar.VanillaMouseUps, 0, "a button press is not a slot press")

	ClickSlot(Hotbar, 1)
	AssertTrue(Hotbar.VanillaMouseUps > 0, "a slot press still reaches the game")
end)

--// Multiplayer
Test("a client transmits the new order", function()
	Harness.IsClient = true
	local Hotbar, Player = NewHotbar("Back", "Belt", "Holster")
	local Before = Player.Transmits

	DragSlot(Hotbar, 1, 3)
	AssertTrue(Player.Transmits > Before, "savePosition should have transmitted it")
end)

Test("singleplayer transmits nothing", function()
	Harness.IsClient = false
	local Hotbar, Player = NewHotbar("Back", "Belt", "Holster")
	local Before = Player.Transmits

	DragSlot(Hotbar, 1, 3)
	AssertEquals(Player.Transmits, Before, "there is no server to tell")
end)

Test("the order is kept per character, not globally", function()
	local One = Harness.NewPlayer(0, true)
	local Two = Harness.NewPlayer(1, true)

	local BarOne = Harness.NewHotbar(One, { "Back", "Belt" })
	local BarTwo = Harness.NewHotbar(Two, { "Back", "Belt" })
	Harness.Fire("OnLoad")

	DragSlot(BarOne, 1, 2)

	AssertEquals(Order(BarOne), "Belt,Back", "the first character reordered")
	AssertEquals(Order(BarTwo), "Back,Belt", "the second should be untouched")
end)
