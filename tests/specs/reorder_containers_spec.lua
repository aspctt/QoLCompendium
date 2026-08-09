--// Reorder Containers Spec
--// aspctt - 10.08.2026

--// Helpers
-- Builds a window holding the player's own inventory plus one bag per name given.
local function NewPage(Player, OnCharacter, ...)
	local Page = Harness.NewInventoryPage(Player.Number, OnCharacter)
	Page.Containers = { Player.Inventory }

	for _, Name in ipairs({ ... }) do
		local Item = Harness.NewInventoryItem(Name)
		table.insert(Page.Containers, Harness.NewContainer(Name, Item, nil))
	end

	Harness.Pages[Player.Number .. (OnCharacter ~= false and ":inventory" or ":loot")] = Page
	Page:refreshBackpacks()
	return Page
end

local function FindButton(Page, TypeName)
	for _, Button in ipairs(Page.backpacks) do
		if Button.inventory:getType() == TypeName then return Button end
	end
	return nil
end

-- Drags a button to a Y position and lets go, the way a player would
local function DragTo(Page, TypeName, Y)
	local Button = FindButton(Page, TypeName)
	if not Button then error("no button for " .. TypeName) end

	Harness.SetMouse(0, Button:getY())
	Button:onMouseDown(0, 0)
	Button.pressed = true

	Harness.SetMouse(0, Y + (Button:getHeight() / 2))
	Button:onMouseMove(0, Y - Button:getY())
	Button:onMouseUp(0, 0)

	return Button
end

-- Comfortably above every button. The mod clamps a drag to -4 and the topmost button
-- already sits at -1, so a smaller number would tie with it and the tie break, not the
-- drag, would decide the order.
local TOP = -10

local function Concat(List)
	return table.concat(List, ",")
end

--// Wiring
Test("the mod hooks the vanilla refresh event", function()
	AssertTrue(Harness.HandlerCount("OnRefreshInventoryWindowContainers") > 0,
		"should listen for OnRefreshInventoryWindowContainers")
end)

Test("nothing is reordered before the player asks for it", function()
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Bag", "Crate")

	AssertEquals(Concat(Harness.ButtonOrderByArray(Page)), "inventory,Bag,Crate",
		"an untouched window keeps the game's own order")
end)

--// Ordering
Test("a dragged container keeps its new place across a refresh", function()
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Bag", "Crate")

	-- Drag the crate above everything
	DragTo(Page, "Crate", TOP)

	AssertEquals(Concat(Harness.ButtonOrderByArray(Page)), "Crate,inventory,Bag",
		"the order should survive the refresh a drag triggers")

	Page:refreshBackpacks()
	AssertEquals(Concat(Harness.ButtonOrderByArray(Page)), "Crate,inventory,Bag",
		"and every refresh after it")
end)

Test("the array and the screen agree after reordering", function()
	-- This is the whole point. Vanilla reads the array, the player reads the screen.
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Bag", "Crate", "Purse")

	DragTo(Page, "Purse", TOP)

	AssertEquals(Concat(Harness.ButtonOrderByArray(Page)),
		Concat(Harness.ButtonOrderByPosition(Page)),
		"array order and on screen order must not diverge")
end)

Test("scroll height follows the bottom-most button", function()
	-- Vanilla sets it from backpacks[#backpacks]:getBottom(). Reordering only the
	-- buttons and not the array is what leaves this wrong.
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Bag", "Crate")

	DragTo(Page, "Crate", TOP)
	Page:refreshBackpacks()

	local Lowest = 0
	for _, Button in ipairs(Page.backpacks) do
		if Button:getBottom() > Lowest then Lowest = Button:getBottom() end
	end

	AssertEquals(Page.containerButtonPanel.ScrollHeight, Lowest,
		"scroll height should reach the lowest button")
end)

Test("buttons are laid out with no gaps", function()
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Bag", "Crate", "Purse")

	DragTo(Page, "Purse", TOP)

	for Index, Button in ipairs(Page.backpacks) do
		AssertEquals(Button:getY(), ((Index - 1) * Page.buttonSize) - 1,
			"button " .. Index .. " should sit at its index")
	end
end)

Test("containers with no saved order keep the game's order", function()
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Bag", "Crate", "Purse")

	-- Give only the purse a position, well after the rest
	QolcReorderSetPriority(Player, FindButton(Page, "Purse").inventory, 500, true)
	Page:refreshBackpacks()

	AssertEquals(Concat(Harness.ButtonOrderByArray(Page)), "Purse,inventory,Bag,Crate",
		"a set priority sorts ahead of anything unset, the rest hold their order")
end)

Test("repeated refreshes do not shuffle an untouched window", function()
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Bag", "Crate", "Purse")

	local First = Concat(Harness.ButtonOrderByArray(Page))
	for _ = 1, 10 do Page:refreshBackpacks() end

	AssertEquals(Concat(Harness.ButtonOrderByArray(Page)), First, "order should be stable")
end)

Test("containers sharing a priority hold a fixed order", function()
	-- Nothing stops someone typing the same number twice in the priority window, and
	-- table.sort is not stable, so equal priorities need a deterministic tie break or
	-- the two swap places at random between refreshes.
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Bag", "Crate", "Purse")

	for _, Name in ipairs({ "Bag", "Crate", "Purse" }) do
		QolcReorderSetPriority(Player, FindButton(Page, Name).inventory, 7, true)
	end

	Page:refreshBackpacks()

	-- Creation order decides it, so the result is the one the player already sees rather
	-- than an arbitrary permutation of the three
	AssertEquals(Concat(Harness.ButtonOrderByArray(Page)), "Bag,Crate,Purse,inventory",
		"equal priorities should fall back to the order the game built them in")

	local First = Concat(Harness.ButtonOrderByArray(Page))
	for _ = 1, 20 do Page:refreshBackpacks() end

	AssertEquals(Concat(Harness.ButtonOrderByArray(Page)), First,
		"and must not drift on later refreshes")
end)

Test("a small nudge is not treated as a reorder", function()
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Bag", "Crate")

	local Before = Concat(Harness.ButtonOrderByArray(Page))
	local Button = FindButton(Page, "Crate")

	Harness.SetMouse(0, Button:getY())
	Button:onMouseDown(0, 0)
	Button.pressed = true
	Harness.SetMouse(0, Button:getY() + 2)
	Button:onMouseMove(0, 2)
	Button:onMouseUp(0, 0)

	AssertEquals(Concat(Harness.ButtonOrderByArray(Page)), Before,
		"a couple of pixels should still count as a click")
end)

--// Locking
Test("a locked window refuses to reorder", function()
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Bag", "Crate")

	QolcReorderToggleLock(Page)
	AssertTrue(QolcReorderIsLocked(Page), "the window should now be locked")

	local Before = Concat(Harness.ButtonOrderByArray(Page))
	DragTo(Page, "Crate", TOP)

	AssertEquals(Concat(Harness.ButtonOrderByArray(Page)), Before, "dragging should do nothing")
end)

Test("the lock toggles back off", function()
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Bag")

	QolcReorderToggleLock(Page)
	QolcReorderToggleLock(Page)

	AssertFalse(QolcReorderIsLocked(Page), "a second click should unlock it")
end)

Test("the inventory and loot windows lock separately", function()
	local Player = Harness.NewPlayer(0, true)
	local Inventory = NewPage(Player, true, "Bag")
	local Loot = NewPage(Player, false, "Crate")

	QolcReorderData.GetOptions(Player).SortLoot = true
	QolcReorderToggleLock(Inventory)

	AssertTrue(QolcReorderIsLocked(Inventory), "the inventory window should be locked")
	AssertFalse(QolcReorderIsLocked(Loot), "the loot window should be untouched")
end)

--// Loot Window
Test("loot sorting is off until it is turned on", function()
	local Player = Harness.NewPlayer(0, true)
	local Loot = NewPage(Player, false, "Crate", "Locker")

	AssertFalse(QolcReorderIsSortingEnabled(Loot), "loot sorting should start off")

	local Before = Concat(Harness.ButtonOrderByArray(Loot))
	DragTo(Loot, "Locker", TOP)
	AssertEquals(Concat(Harness.ButtonOrderByArray(Loot)), Before,
		"dragging in the loot window should do nothing while it is off")
end)

Test("the inventory window always allows sorting", function()
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Bag")

	AssertTrue(QolcReorderIsSortingEnabled(Page), "your own inventory is never opt in")
end)

Test("turning loot sorting on lets it reorder", function()
	local Player = Harness.NewPlayer(0, true)
	local Loot = NewPage(Player, false, "Crate", "Locker")

	QolcReorderData.GetOptions(Player).SortLoot = true
	AssertTrue(QolcReorderIsSortingEnabled(Loot), "loot sorting should now be on")

	DragTo(Loot, "Locker", TOP)
	AssertEquals(Harness.ButtonOrderByArray(Loot)[1], "Locker", "the locker should have moved to the top")
end)

--// Storage
Test("a bag's order is stored on the bag, not the player", function()
	-- So it survives being dropped and picked up again.
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Bag", "Crate")

	DragTo(Page, "Crate", TOP)

	local Crate = FindButton(Page, "Crate").inventory
	local Stored = QolcReorderData.GetSort(Crate:getContainingItem():getModData(), Player:getUsername())

	-- Asserting on the priority, not merely that the section exists. Reading a priority
	-- creates the section as a side effect, so its presence alone proves nothing.
	AssertNotNil(Stored.Priority, "the crate's own mod data should carry its position")
	AssertNil(Player:getModData().QolcReorder[QolcReorderData.GetSortKey(Player:getUsername())],
		"and the player should not be carrying it instead")
end)

Test("the player's own inventory is keyed by container type", function()
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Bag")

	QolcReorderSetPriority(Player, Player.Inventory, 5, true)

	local Key = QolcReorderData.GetSortKey("inventory")
	AssertNotNil(Player:getModData().QolcReorder[Key],
		"should be stored against the container type, not the username")
end)

Test("two players sorting one crate do not overwrite each other", function()
	local One = Harness.NewPlayer(0, true)
	local Two = Harness.NewPlayer(1, true)

	local Item = Harness.NewInventoryItem("Crate")
	local Crate = Harness.NewContainer("Crate", Item, nil)

	QolcReorderSetPriority(One, Crate, 10, true)
	QolcReorderSetPriority(Two, Crate, 90, true)

	AssertEquals(QolcReorderGetPriority(One, Crate, 0), 10, "player one's choice")
	AssertEquals(QolcReorderGetPriority(Two, Crate, 0), 90, "player two's choice")
end)

Test("clearing a priority puts a container back in the game's order", function()
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Bag")

	QolcReorderSetPriority(Player, Player.Inventory, 5, true)
	QolcReorderSetPriority(Player, Player.Inventory, nil, false)

	AssertTrue(QolcReorderGetPriority(Player, Player.Inventory, 0) >= QolcReorderData.PRIORITY_UNSET,
		"an unset priority should sort with the rest")
end)

--// Multiplayer
Test("singleplayer sends nothing to a server", function()
	Harness.IsClient = false
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Bag", "Crate")

	DragTo(Page, "Crate", TOP)
	AssertEquals(#Harness.ClientCommands, 0, "there is no server to tell")
end)

Test("a client asks the server to save a carried bag", function()
	Harness.IsClient = true
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Bag", "Crate")

	DragTo(Page, "Crate", TOP)

	local Command = Harness.LastCommand(QolcReorderData.SAVE_ITEM)
	AssertNotNil(Command, "a carried bag should go through the item command")
	AssertEquals(Command.Module, QolcReorderData.MODULE, "module")
	AssertNotNil(Command.Request.ItemId, "the request must name the item")
	AssertNotNil(Command.Request.Suffix, "the request must carry the key suffix")
end)

Test("a bag on the ground is saved by position", function()
	Harness.IsClient = true
	local Player = Harness.NewPlayer(0, true)

	local WorldObject = Harness.NewWorldObject(120, 340, 0)
	local Item = Harness.NewInventoryItem("Crate", WorldObject)
	local Crate = Harness.NewContainer("Crate", Item, nil)

	QolcReorderSetPriority(Player, Crate, 10, true)

	local Command = Harness.LastCommand(QolcReorderData.SAVE_GROUND)
	AssertNotNil(Command, "a dropped bag should go through the ground command")
	AssertEquals(Command.Request.X, 120, "x")
	AssertEquals(Command.Request.Y, 340, "y")
	AssertEquals(Command.Request.Z, 0, "z")
end)

Test("the player's own order is transmitted, not sent as a command", function()
	Harness.IsClient = true
	local Player = Harness.NewPlayer(0, true)

	QolcReorderSetPriority(Player, Player.Inventory, 5, true)

	AssertTrue(Player.Transmits > 0, "a player owns their own mod data")
	AssertEquals(#Harness.ClientCommands, 0, "so there is nothing to ask the server for")
end)

Test("a world container is transmitted by the object itself", function()
	Harness.IsClient = true
	local Player = Harness.NewPlayer(0, true)

	local Object = Harness.NewIsoObject()
	local Crate = Harness.NewContainer("Crate", nil, Object)

	QolcReorderSetPriority(Player, Crate, 10, true)
	AssertTrue(Object.Transmits > 0, "an IsoObject transmits its own mod data")
end)

--// Server
Test("the server writes an order sent for a carried item", function()
	local Player = Harness.NewPlayer(0, true)
	local Item = Harness.NewInventoryItem("Crate")
	table.insert(Player.Inventory.Items, Item)

	Harness.Fire("OnClientCommand", QolcReorderData.MODULE, QolcReorderData.SAVE_ITEM, Player, {
		ItemId = Item:getID(),
		Suffix = "Player0",
		Sort = { Priority = 30, Manual = true }
	})

	local Stored = QolcReorderData.GetSort(Item:getModData(), "Player0")
	AssertEquals(Stored.Priority, 30, "the priority should have been written")
	AssertEquals(Stored.Manual, true, "and the manual flag with it")
end)

Test("the server ignores an item the sender is not carrying", function()
	local Player = Harness.NewPlayer(0, true)
	local Item = Harness.NewInventoryItem("Crate")

	-- Deliberately reachable some other way. The item command must resolve through the
	-- sender's own inventory and nothing else, or a client could name any id it liked.
	Harness.PlaceItemOnGround(5, 5, 0, Item)

	Harness.Fire("OnClientCommand", QolcReorderData.MODULE, QolcReorderData.SAVE_ITEM, Player, {
		ItemId = Item:getID(),
		Suffix = "Player0",
		Sort = { Priority = 30, Manual = true }
	})

	AssertNil(Item:getModData().QolcReorder,
		"a client must not be able to write to an item it does not hold")
end)

Test("the server writes an order sent for a ground item", function()
	local Player = Harness.NewPlayer(0, true)
	local Item = Harness.NewInventoryItem("Crate")
	Harness.PlaceItemOnGround(10, 20, 0, Item)

	Harness.Fire("OnClientCommand", QolcReorderData.MODULE, QolcReorderData.SAVE_GROUND, Player, {
		ItemId = Item:getID(),
		Suffix = "Player0",
		Sort = { Priority = 40, Manual = false },
		X = 10, Y = 20, Z = 0
	})

	AssertEquals(QolcReorderData.GetSort(Item:getModData(), "Player0").Priority, 40,
		"the ground item should have been found and written")
end)

Test("the server copies only the fields this feature owns", function()
	local Player = Harness.NewPlayer(0, true)
	local Item = Harness.NewInventoryItem("Crate")
	table.insert(Player.Inventory.Items, Item)

	Harness.Fire("OnClientCommand", QolcReorderData.MODULE, QolcReorderData.SAVE_ITEM, Player, {
		ItemId = Item:getID(),
		Suffix = "Player0",
		Sort = { Priority = 30, Manual = false, Injected = "should not be stored" }
	})

	AssertNil(QolcReorderData.GetSort(Item:getModData(), "Player0").Injected,
		"a request must not be able to write arbitrary keys")
end)

Test("the server ignores other modules and malformed requests", function()
	local Player = Harness.NewPlayer(0, true)
	local Item = Harness.NewInventoryItem("Crate")
	table.insert(Player.Inventory.Items, Item)

	Harness.Fire("OnClientCommand", "SomeOtherMod", QolcReorderData.SAVE_ITEM, Player, {
		ItemId = Item:getID(), Suffix = "Player0", Sort = { Priority = 1 }
	})
	Harness.Fire("OnClientCommand", QolcReorderData.MODULE, QolcReorderData.SAVE_ITEM, Player, nil)
	Harness.Fire("OnClientCommand", QolcReorderData.MODULE, QolcReorderData.SAVE_ITEM, Player, {})

	AssertNil(Item:getModData().QolcReorder, "none of those should have written anything")
end)

--// Translations
Test("every label the reorder UI asks for resolves", function()
	local Keys = {
		"UI_QoLC_Reorder_Locked",
		"UI_QoLC_Reorder_Unlocked",
		"UI_QoLC_Reorder_SortLoot",
		"UI_QoLC_Reorder_Priority",
		"UI_QoLC_Reorder_Priority_tooltip"
	}

	for _, Key in ipairs(Keys) do
		AssertNotNil(Translations[Key], "missing translation for " .. Key)
	end
end)
