--// Reorder Duplicates by Condition
--// Reorder Duplicates by Condition, Workshop 2766834021 - Original idea
--// aspctt - 12.08.2026
--// Twenty survival knives in a crate sit in whatever order they were dropped in. This
--// sorts them by how worn they are, how full they are, or what they are worth eating.
--//
--// Vanilla sorts a container by name, category and weight, and that is a display sort
--// laid over the pane. It cannot reach inside a collapsed stack of duplicates, whose
--// order is the order the container happens to hold them in. This changes that order.
--//
--// Rewritten rather than ported. Three of the accessors the original uses are gone:
--//
--//   getDirtyness       is getDirtiness now, the typo was fixed on the accessor while
--//                      the private field kept it
--//   getUsedDelta       is getCurrentUsesFloat
--//   getCharacterTraits():contains("Nutritionist")
--//                      CharacterTraits has no contains at all, it is
--//                      hasTrait(CharacterTrait.NUTRITIONIST)
--//
--// So on build 42 the original sorts weapons by condition and throws on clothing,
--// drainables and food. It also depends on the separate Mod Options mod, which this does
--// not, and its own reordering moves more items than it needs to.
--//
--// The reordering itself: an item can only be sent to the back of a container, by taking
--// it out and putting it back. Achieving an order with only that move costs one move per
--// item that is out of place. The fewest possible is the total less the longest run of
--// items already in the order you asked for, taken as a subsequence, so that run stays
--// where it is and everything else follows it. See QolcReorderMoves.
--//
--// Client only. The transfers it queues are vanilla's own and sync themselves.

require "ISUI/ISInventoryPaneContextMenu"

--// Tuning
local OPTIONS_ID = "QoLC"
local Options = {}

-- Each way of sorting: when it applies, and what it reads. Kept as a list rather than as
-- repeated blocks so adding one is a line.
local KEYS = {
	{
		Id = "Condition",
		Applies = function(Type) return Type.Weapon or Type.Clothing end,
		Value = function(Item) return Item:getCondition() end
	},
	{
		Id = "Remaining",
		Applies = function(Type) return Type.Drainable end,
		Value = function(Item) return Item:getCurrentUsesFloat() end
	},
	{
		Id = "Hunger",
		Applies = function(Type) return Type.Food end,
		Value = function(Item) return math.abs(Item:getHungerChange()) end
	},
	{
		Id = "Calories",
		Applies = function(Type) return Type.Food end,
		Value = function(Item) return Item:getCalories() end,
		-- Someone who cannot read a label has no way of knowing, which is the same rule
		-- the game uses for showing the number at all
		Visible = function(Player, Item)
			if Player:hasTrait(CharacterTrait.NUTRITIONIST) then return true end
			if Player:hasTrait(CharacterTrait.NUTRITIONIST2) then return true end
			return Item:isPackaged() and true or false
		end
	},
	{
		Id = "Bloodiness",
		Applies = function(Type) return Type.Weapon or Type.BloodClothing end,
		Value = function(Item) return Item:getBloodLevel() end,
		Extra = true
	},
	{
		Id = "Dirtiness",
		Applies = function(Type) return Type.Clothing end,
		Value = function(Item) return Item:getDirtiness() end,
		Extra = true
	}
}

--// Functions
local function GetOption(Name, Default)
	local Setting = Options[Name]
	if not Setting then return Default end

	return Setting:getValue() and true or false
end

local function ItemType(Item)
	return {
		Weapon = Item:IsWeapon(),
		Drainable = Item:IsDrainable(),
		Clothing = Item:IsClothing(),
		Food = Item:IsFood(),
		BloodClothing = Item:getBloodClothingType() ~= nil
			and (Item:IsClothing() or Item:IsInventoryContainer())
	}
end

-- The real items behind whatever the pane handed over. A collapsed stack keeps a display
-- copy at index one, an expanded selection is the items themselves.
local function Selected(Items)
	if not Items[1] then return nil end

	if instanceof(Items[1], "InventoryItem") then
		-- A mixed selection is not a set of duplicates and has no single order to sort by
		local Name = Items[1]:getName()
		local Found = {}

		for _, Item in ipairs(Items) do
			if not instanceof(Item, "InventoryItem") then return nil end
			if Item:getName() ~= Name then return nil end
			table.insert(Found, Item)
		end

		return Found
	end

	-- Only one collapsed row at a time, otherwise there are two orders being asked for
	if #Items > 1 or type(Items[1].items) ~= "table" then return nil end

	local Found = {}
	for Index = 2, #Items[1].items do table.insert(Found, Items[1].items[Index]) end

	return Found
end

--// Ordering
-- The fewest items that have to be sent to the back to reach the wanted order.
--
-- Everything up to the longest run of Wanted that already appears in Current, in the same
-- relative order, can stay where it is. Everything after it moves, in the wanted order.
-- Sorting a container that is already sorted therefore costs nothing at all.
function QolcReorderMoves(Current, Wanted)
	local Kept = 0
	local At = 1

	for _, Item in ipairs(Wanted) do
		local Found = nil

		for Index = At, #Current do
			if Current[Index] == Item then Found = Index break end
		end

		if not Found then break end

		Kept = Kept + 1
		At = Found + 1
	end

	local Moves = {}
	for Index = Kept + 1, #Wanted do table.insert(Moves, Wanted[Index]) end

	return Moves
end

-- Sorted by the value, then by where it started, so items that read the same never swap
-- and sorting twice does nothing the second time.
function QolcReorderSort(Items, Read, Descending)
	local Order = {}
	local Position = {}

	for Index, Item in ipairs(Items) do
		Order[Index] = Item
		Position[Item] = Index
	end

	table.sort(Order, function(A, B)
		local Left, Right = Read(A), Read(B)
		if Left == Right then return Position[A] < Position[B] end
		if Descending then return Left > Right end
		return Left < Right
	end)

	return Order
end

local function Reorder(Player, Items, Read, Descending, Container)
	local Wanted = QolcReorderSort(Items, Read, Descending)
	local Moves = QolcReorderMoves(Items, Wanted)

	if #Moves == 0 then
		if GetOption("ReorderSpeak", true) then
			Player:Say(getText("IGUI_QoLC_AlreadyInOrder"))
		end
		return
	end

	local Inventory = Player:getInventory()

	-- Out and back is the only move a container offers. Each one is a real timed action,
	-- so it takes the character time and carries itself over the network.
	for _, Item in ipairs(Moves) do
		ISTimedActionQueue.add(ISInventoryTransferAction:new(Player, Item, Container, Inventory))
		ISTimedActionQueue.add(ISInventoryTransferAction:new(Player, Item, Inventory, Container))
	end
end

--// Menu
local function AddSort(Context, Key, Player, Items, Container)
	local Read = Key.Value

	-- Nothing to sort by when every one of them reads the same
	local First = Read(Items[1])
	local Differs = false
	for _, Item in ipairs(Items) do
		if Read(Item) ~= First then Differs = true break end
	end
	if not Differs then return end

	local Option = Context:addOption(getText("ContextMenu_QoLC_ReorderBy" .. Key.Id))
	local Sub = ISContextMenu:getNew(Context)
	Context:addSubMenu(Option, Sub)

	Sub:addOption(getText("IGUI_invpanel_descending"), Player, Reorder, Items, Read, true, Container)
	Sub:addOption(getText("IGUI_invpanel_ascending"), Player, Reorder, Items, Read, false, Container)
end

local function OnFillInventoryObjectContextMenu(PlayerNum, Context, Items)
	local Player = getSpecificPlayer(PlayerNum)
	if not Player then return end

	local Found = Selected(Items)
	if not Found or #Found < 2 then return end

	-- The character's own inventory is not a container with an order worth arranging, and
	-- moving items out of it and back would have nowhere to go
	local Container = Found[1]:getContainer()
	if not Container or Container == Player:getInventory() then return end

	local Type = ItemType(Found[1])
	local Extras = GetOption("ReorderExtras", true)

	for _, Key in ipairs(KEYS) do
		local Wanted = Key.Applies(Type)
		if Wanted and Key.Extra and not Extras then Wanted = false end
		if Wanted and Key.Visible and not Key.Visible(Player, Found[1]) then Wanted = false end

		if Wanted then AddSort(Context, Key, Player, Found, Container) end
	end
end

--// Mod Options
-- One shared category for the whole compendium, see qolc_immersive_overlays.lua.
local function CreateModOptions()
	if not PZAPI or not PZAPI.ModOptions then return end

	local ModOptions = PZAPI.ModOptions:getOptions(OPTIONS_ID)
	if not ModOptions then
		ModOptions = PZAPI.ModOptions:create(OPTIONS_ID, "UI_options_QoLC")
	end

	ModOptions:addTitle("UI_options_QoLC_Reorder")
	ModOptions:addDescription("UI_options_QoLC_Reorder_Desc")

	Options.ReorderSpeak = ModOptions:addTickBox("ReorderSpeak",
		"UI_options_QoLC_Reorder_Speak", true, "UI_options_QoLC_Reorder_Speak_tooltip")
	Options.ReorderExtras = ModOptions:addTickBox("ReorderExtras",
		"UI_options_QoLC_Reorder_Extras", true, "UI_options_QoLC_Reorder_Extras_tooltip")
end

CreateModOptions()

--// Connections
Events.OnFillInventoryObjectContextMenu.Add(OnFillInventoryObjectContextMenu)
