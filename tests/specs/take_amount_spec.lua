--// Take Any Amount Spec
--// aspctt - 12.08.2026

--// Helpers
local GRAB_AMOUNT = "ContextMenu_QoLC_GrabAmount"
local PUT_AMOUNT = "ContextMenu_QoLC_PutAmount"

local function GrabMenu(StackSize)
	local Player, _Loot = Harness.SetupTransferWindows(0)
	local Source = Harness.NewContainer("crate")
	local Stack = Harness.NewStack(Source, StackSize or 10)

	local Context = Harness.NewContextMenu()
	ISInventoryPaneContextMenu.doGrabMenu(Context, { Stack }, 0)

	return Context, Stack, Player, Source
end

local function Names(Context)
	local Found = {}
	for Index, Option in ipairs(Context.options) do Found[Index] = Option.name end
	return table.concat(Found, " | ")
end

local function Take(Context, Amount)
	Context:Find(getText(GRAB_AMOUNT)):Click()
	Harness.OpenBox:Type(Amount):Confirm()
	return Harness.Transfers
end

--// The Grab Menu
Test("vanilla still builds the menu", function()
	local Context = GrabMenu(10)
	AssertContains(Names(Context), getText("ContextMenu_Grab_one"), "vanilla's own entries stand")
	AssertContains(Names(Context), getText("ContextMenu_Grab_all"), "all of them")
end)

Test("the amount option sits between half and all", function()
	local Context = GrabMenu(10)
	AssertEquals(Names(Context),
		getText("ContextMenu_Grab_one") .. " | " .. getText("ContextMenu_Grab_half")
		.. " | " .. getText(GRAB_AMOUNT) .. " | " .. getText("ContextMenu_Grab_all"),
		"order")
end)

Test("option ids follow their new positions", function()
	-- addOptionOnTop renumbers when it reorders, so moving one has to as well
	local Context = GrabMenu(10)
	for Index, Option in ipairs(Context.options) do
		AssertEquals(Option.id, Index, "id at position " .. tostring(Index))
	end
end)

Test("a stack too small to split is left alone", function()
	-- Vanilla offers a single Grab there and no halves, so there is nothing to divide
	local Context = GrabMenu(1)
	AssertNil(Context:Find(getText(GRAB_AMOUNT)), "nothing to ask an amount for")
	AssertNotNil(Context:Find(getText("ContextMenu_Grab")), "vanilla's single grab stands")
end)

Test("a container that refuses the item is not offered an amount", function()
	-- Build 42.20 added this check to doGrabMenu. The original mod replaces that function
	-- with a copy predating it, which puts the refused options back.
	local Player = Harness.SetupTransferWindows(0)
	Player.Inventory.Allowed = false

	local Stack = Harness.NewStack(Harness.NewContainer("crate"), 10)
	local Context = Harness.NewContextMenu()
	ISInventoryPaneContextMenu.doGrabMenu(Context, { Stack }, 0)

	AssertEquals(#Context.options, 0, "vanilla offers nothing, so neither do we")
end)

--// Taking
Test("asking for three moves three", function()
	local Context = GrabMenu(10)
	AssertEquals(#Take(Context, 3), 3, "three transfers queued")
end)

Test("asking for more than there is takes the lot", function()
	local Context = GrabMenu(10)
	AssertEquals(#Take(Context, 999), 10, "capped at what is there")
end)

Test("nonsense does nothing", function()
	for _, Entered in ipairs({ "abc", "", "-5", "0" }) do
		local Context = GrabMenu(10)
		AssertEquals(#Take(Context, Entered), 0, "entered " .. tostring(Entered))
	end
end)

Test("a fraction is rounded down rather than refused", function()
	local Context = GrabMenu(10)
	AssertEquals(#Take(Context, "3.7"), 3, "three, not four and not nothing")
end)

Test("cancelling takes nothing", function()
	local Context = GrabMenu(10)
	Context:Find(getText(GRAB_AMOUNT)):Click()

	Harness.OpenBox:Type(5)
	Harness.OpenBox.onclick(nil, { internal = "CANCEL", parent = Harness.OpenBox },
		Harness.OpenBox.param1, Harness.OpenBox.param2, Harness.OpenBox.param3)

	AssertEquals(#Harness.Transfers, 0, "only OK moves anything")
end)

Test("the count is a total, not per stack", function()
	-- The original takes the asked amount from every stack selected, so asking for two
	-- across three stacks moves six
	Harness.SetupTransferWindows(0)
	local Source = Harness.NewContainer("crate")
	local Items = {
		Harness.NewStack(Source, 10), Harness.NewStack(Source, 10), Harness.NewStack(Source, 10)
	}

	local Context = Harness.NewContextMenu()
	ISInventoryPaneContextMenu.doGrabMenu(Context, Items, 0)

	AssertEquals(#Take(Context, 2), 2, "two in total")
end)

Test("giving up on the walk moves nothing", function()
	local Context = GrabMenu(10)
	Harness.CanWalk = false

	AssertEquals(#Take(Context, 3), 0, "could not reach the container")
	Harness.CanWalk = true
end)

Test("everything goes to the player's own inventory", function()
	local Context, _Stack, Player = GrabMenu(10)
	local Moved = Take(Context, 2)

	AssertEquals(Moved[1].to, Player.Inventory, "destination")
	AssertEquals(Moved[1].character, Player, "and the character carrying it")
end)

--// Putting
local function PutMenu(Count, Favourite)
	local Player, Loot = Harness.SetupTransferWindows(0)
	local Items = {}

	for Index = 1, Count do
		local Item = Harness.NewInventoryItem("Nail")
		Item.Container = Player.Inventory
		Item.Favorite = Favourite == true
		Items[Index] = Item
	end

	local Context = Harness.NewContextMenu()
	Harness.Fire("OnFillInventoryObjectContextMenu", 0, Context, Items)

	return Context, Items, Player, Loot
end

Test("putting an amount away is offered", function()
	local Context, _Items, _Player, Loot = PutMenu(5)
	AssertNotNil(Context:Find(getText(PUT_AMOUNT, Loot.Type and "Crate" or "Crate")), "the option")
end)

Test("it names the container it would go to", function()
	local Context = PutMenu(5)
	AssertContains(Context.options[1].name, "Crate", "so you know where it lands")
end)

Test("a single item is not offered an amount", function()
	AssertEquals(#PutMenu(1).options, 0, "nothing to divide")
end)

Test("asking for two puts two", function()
	local Context, _Items, _Player, Loot = PutMenu(5)

	Context.options[1]:Click()
	Harness.OpenBox:Type(2):Confirm()

	AssertEquals(#Harness.Transfers, 2, "two transfers")
	AssertEquals(Harness.Transfers[1].to, Loot, "into the loot container")
end)

Test("favourites are left where they are", function()
	AssertEquals(#PutMenu(5, true).options, 0, "all favourite, nothing offered")
end)

Test("a container that allows nothing is not offered", function()
	local _Player, Loot = Harness.SetupTransferWindows(0)
	Loot.AllowsItems = false

	local Items = {}
	for Index = 1, 5 do
		local Item = Harness.NewInventoryItem("Nail")
		Item.Container = Harness.Players[0].Inventory
		Items[Index] = Item
	end

	local Context = Harness.NewContextMenu()
	Harness.Fire("OnFillInventoryObjectContextMenu", 0, Context, Items)

	AssertEquals(#Context.options, 0, "it would refuse them all")
end)

--// Namespace
Test("nothing of ours leaks into the global namespace", function()
	-- The original leaves AMOUNT, MAX and three callbacks as globals, where another mod
	-- can collide with them
	for _, Name in ipairs({ "AMOUNT", "MAX", "createAndOpenTextbox",
		"setAmountAndGrab", "setAmountAndPut" }) do
		AssertNil(_G[Name], Name .. " should not be global")
	end
end)

--// Translations
Test("every label resolves", function()
	for _, Key in ipairs({ GRAB_AMOUNT, PUT_AMOUNT, "ContextMenu_QoLC_TransferAmount" }) do
		AssertNotNil(Translations[Key], "missing translation for " .. Key)
	end
end)
