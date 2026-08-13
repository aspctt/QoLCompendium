--// Reorder Duplicates by Condition Spec
--// aspctt - 12.08.2026

--// Helpers
local function Knives(Conditions, Container)
	local Items = {}
	for Index, Value in ipairs(Conditions) do
		local Item = Harness.NewSortable("weapon", { Condition = Value, Name = "Knife" })
		Item.Container = Container
		Items[Index] = Item
	end
	return Items
end

local function Menu(Items, Player)
	Player = Player or Harness.Players[0] or Harness.NewPlayer(0, true)
	local Context = Harness.NewContextMenu()
	Harness.Fire("OnFillInventoryObjectContextMenu", 0, Context, Items)
	return Context
end

local function Sort(Context, Label, Descending)
	local Option = Context:Find(getText(Label))
	local Direction = getText(Descending and "IGUI_invpanel_descending" or "IGUI_invpanel_ascending")

	Harness.ClearTransfers()
	Option.SubMenu:Find(Direction):Click()
	return Harness.Transfers
end

local function Read(Item) return Item:getCondition() end

--// The Move Set
Test("an order already correct costs nothing", function()
	local A, B, C = "a", "b", "c"
	AssertEquals(#QolcReorderMoves({ A, B, C }, { A, B, C }), 0, "no moves at all")
end)

Test("a reversal moves everything but one", function()
	-- Only the back of a container can be reached, so the first of the wanted order stays
	-- and the rest follow it
	local A, B, C = "a", "b", "c"
	local Moves = QolcReorderMoves({ A, B, C }, { C, B, A })

	AssertEquals(#Moves, 2, "two moves, not three")
	AssertEquals(Moves[1], B, "in the order they should end up")
	AssertEquals(Moves[2], A, "second")
end)

Test("one item out of place costs one move", function()
	local A, B, C = "a", "b", "c"
	AssertEquals(#QolcReorderMoves({ A, B, C }, { A, C, B }), 1, "just the one")
end)

Test("the run that can stay is the longest one", function()
	-- A naive pass would move everything after the first mismatch. The kept run is a
	-- subsequence, so it can skip over items that are moving anyway.
	local A, B, C, D = "a", "b", "c", "d"
	AssertEquals(#QolcReorderMoves({ A, C, B, D }, { A, B, D, C }), 1, "only C has to move")
end)

--// Sorting
Test("descending puts the best first", function()
	local Items = { "x", "y", "z" }
	local Values = { x = 3, y = 9, z = 6 }
	local Order = QolcReorderSort(Items, function(I) return Values[I] end, true)

	AssertEquals(Order[1], "y", "nine")
	AssertEquals(Order[3], "x", "three")
end)

Test("equal values keep the order they were in", function()
	-- Unstable sorting shuffles identical items and queues transfers that achieve nothing.
	-- Enough of them to be sure: three would sit still by luck whatever the comparator.
	local Items = {}
	for Index = 1, 10 do Items[Index] = "item" .. tostring(Index) end

	local Order = QolcReorderSort(Items, function() return 5 end, true)

	for Index = 1, 10 do
		AssertEquals(Order[Index], Items[Index], "position " .. tostring(Index) .. " moved")
	end
end)

Test("ties in a sorted container are still no work", function()
	-- The case that reaches the player: several items reading the same, already in order
	local Container = Harness.NewContainer("crate")
	local Items = Knives({ 9, 9, 5, 5, 1, 1 }, Container)

	local Wanted = QolcReorderSort(Items, Read, true)
	AssertEquals(#QolcReorderMoves(Items, Wanted), 0, "nothing needs to move")
end)

Test("sorting twice is not work twice", function()
	local Container = Harness.NewContainer("crate")
	local Items = Knives({ 3, 9, 6 }, Container)

	local Once = QolcReorderSort(Items, Read, true)
	AssertEquals(#QolcReorderMoves(Once, QolcReorderSort(Once, Read, true)), 0,
		"already sorted, nothing to do")
end)

--// The Menu
Test("duplicates in a container are offered a sort", function()
	local Container = Harness.NewContainer("crate")
	local Context = Menu(Knives({ 3, 9, 6 }, Container))

	AssertNotNil(Context:Find(getText("ContextMenu_QoLC_ReorderByCondition")), "the option")
end)

Test("items that all read the same are not offered one", function()
	local Container = Harness.NewContainer("crate")
	local Context = Menu(Knives({ 5, 5, 5 }, Container))

	AssertNil(Context:Find(getText("ContextMenu_QoLC_ReorderByCondition")), "nothing to sort")
end)

Test("a single item is not offered one", function()
	local Container = Harness.NewContainer("crate")
	AssertEquals(#Menu(Knives({ 5 }, Container)).options, 0, "one is already in order")
end)

Test("a mixed selection is not offered one", function()
	-- Two different items have no single order to sort by
	local Container = Harness.NewContainer("crate")
	local Items = Knives({ 3, 9 }, Container)
	Items[2].Name = "Axe"

	AssertEquals(#Menu(Items).options, 0, "not duplicates")
end)

Test("the character's own inventory is left alone", function()
	local Player = Harness.NewPlayer(0, true)
	local Items = Knives({ 3, 9, 6 }, Player.Inventory)

	AssertEquals(#Menu(Items, Player).options, 0, "nowhere to move them to")
end)

--// Doing It
Test("sorting queues two transfers for each item moved", function()
	local Container = Harness.NewContainer("crate")
	local Context = Menu(Knives({ 3, 9, 6 }, Container))

	-- Descending wants 9, 6, 3 from 3, 9, 6. The kept run is 9 then 6, so only 3 moves.
	AssertEquals(#Sort(Context, "ContextMenu_QoLC_ReorderByCondition", true), 2, "out and back")
end)

Test("an already sorted container queues nothing and says so", function()
	local Player = Harness.NewPlayer(0, true)
	local Container = Harness.NewContainer("crate")
	local Context = Menu(Knives({ 9, 6, 3 }, Container), Player)

	AssertEquals(#Sort(Context, "ContextMenu_QoLC_ReorderByCondition", true), 0, "no work")
	AssertEquals(#Player.Said, 1, "the character mentions it")
end)

Test("items go out to the player and straight back", function()
	local Player = Harness.NewPlayer(0, true)
	local Container = Harness.NewContainer("crate")
	local Context = Menu(Knives({ 3, 9, 6 }, Container), Player)
	local Moved = Sort(Context, "ContextMenu_QoLC_ReorderByCondition", true)

	AssertEquals(Moved[1].from, Container, "out of the container")
	AssertEquals(Moved[1].to, Player.Inventory, "into the player")
	AssertEquals(Moved[2].from, Player.Inventory, "then back out")
	AssertEquals(Moved[2].to, Container, "into the container, at the end")
end)

--// Item Types
Test("drainables sort by what is left in them", function()
	-- getUsedDelta is gone in build 42, it is getCurrentUsesFloat
	local Container = Harness.NewContainer("crate")
	local Items = {}
	for Index, Value in ipairs({ 0.2, 0.9 }) do
		Items[Index] = Harness.NewSortable("drainable", { Remaining = Value, Name = "Bleach" })
		Items[Index].Container = Container
	end

	AssertNotNil(Menu(Items):Find(getText("ContextMenu_QoLC_ReorderByRemaining")), "offered")
end)

Test("clothing sorts by dirtiness", function()
	-- getDirtyness is gone in build 42, the accessor is getDirtiness
	local Container = Harness.NewContainer("crate")
	local Items = {}
	for Index, Value in ipairs({ 10, 60 }) do
		Items[Index] = Harness.NewSortable("clothing",
			{ Condition = 5, Dirt = Value, Name = "Shirt" })
		Items[Index].Container = Container
	end

	AssertNotNil(Menu(Items):Find(getText("ContextMenu_QoLC_ReorderByDirtiness")), "offered")
end)

Test("calories are hidden from someone who cannot read a label", function()
	-- getCharacterTraits():contains is gone, it is hasTrait(CharacterTrait.NUTRITIONIST)
	local Player = Harness.NewPlayer(0, true)
	local Container = Harness.NewContainer("crate")

	local Items = {}
	for Index, Value in ipairs({ 100, 400 }) do
		Items[Index] = Harness.NewSortable("food",
			{ Hunger = -10 * Index, Calories = Value, Name = "Stew" })
		Items[Index].Container = Container
	end

	AssertNil(Menu(Items, Player):Find(getText("ContextMenu_QoLC_ReorderByCalories")),
		"no trait and not packaged")

	Player:setTrait(CharacterTrait.NUTRITIONIST, true)
	AssertNotNil(Menu(Items, Player):Find(getText("ContextMenu_QoLC_ReorderByCalories")),
		"a nutritionist can read them")
end)

Test("a packaged food shows its calories to anyone", function()
	local Container = Harness.NewContainer("crate")
	local Items = {}
	for Index, Value in ipairs({ 100, 400 }) do
		Items[Index] = Harness.NewSortable("food",
			{ Hunger = -10 * Index, Calories = Value, Packaged = true, Name = "Beans" })
		Items[Index].Container = Container
	end

	AssertNotNil(Menu(Items):Find(getText("ContextMenu_QoLC_ReorderByCalories")), "it is on the tin")
end)

--// Options
Test("both settings are in the shared category", function()
	local Category = PZAPI.ModOptions:getOptions("QoLC")
	local Found = {}
	for _, Entry in ipairs(Category.data) do
		if Entry.id then Found[Entry.id] = true end
	end

	AssertTrue(Found["ReorderSpeak"], "the speak setting")
	AssertTrue(Found["ReorderExtras"], "the extras setting")
end)

Test("turning the extras off shortens the menu", function()
	local Container = Harness.NewContainer("crate")
	local Items = {}
	for Index, Value in ipairs({ 10, 60 }) do
		Items[Index] = Harness.NewSortable("clothing",
			{ Condition = Index, Dirt = Value, Name = "Shirt" })
		Items[Index].Container = Container
	end

	AssertNotNil(Menu(Items):Find(getText("ContextMenu_QoLC_ReorderByDirtiness")), "on by default")

	local Category = PZAPI.ModOptions:getOptions("QoLC")
	for _, Entry in ipairs(Category.data) do
		if Entry.id == "ReorderExtras" then Entry:setValue(false) end
	end

	AssertNil(Menu(Items):Find(getText("ContextMenu_QoLC_ReorderByDirtiness")), "gone")
	AssertNotNil(Menu(Items):Find(getText("ContextMenu_QoLC_ReorderByCondition")), "condition stays")
end)

--// Translations
Test("every label resolves", function()
	local Keys = {
		"ContextMenu_QoLC_ReorderByCondition", "ContextMenu_QoLC_ReorderByRemaining",
		"ContextMenu_QoLC_ReorderByHunger", "ContextMenu_QoLC_ReorderByCalories",
		"ContextMenu_QoLC_ReorderByBloodiness", "ContextMenu_QoLC_ReorderByDirtiness",
		"IGUI_QoLC_AlreadyInOrder", "UI_options_QoLC_Reorder",
		"UI_options_QoLC_Reorder_Speak", "UI_options_QoLC_Reorder_Extras"
	}

	for _, Key in ipairs(Keys) do
		AssertNotNil(Translations[Key], "missing translation for " .. Key)
	end
end)
