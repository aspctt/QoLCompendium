--// Reorder Containers Server
--// Reorder Containers, Workshop 2901962885 - Original design, MIT licensed
--// aspctt - 10.08.2026
--// A client owns its own mod data but not a shared bag's or a crate's, so the order it
--// chose for those has to be written here to survive a relog.
--//
--// Server only. In singleplayer this file never loads and none of it is needed, because
--// the client is already writing straight into the save.
--//
--// Nothing here trusts the request beyond the item it names. Only the fields this
--// feature owns are copied across, so a malformed or hostile command cannot write
--// arbitrary keys into an item's mod data.

--// Functions
-- Copies only the two fields this feature stores. Anything else in the request is
-- ignored rather than merged.
local function WriteSort(RootModData, Suffix, Sort)
	if not RootModData or not Sort then return end

	local Stored = QolcReorderData.GetSort(RootModData, Suffix)
	if not Stored then return end

	local Priority = tonumber(Sort.Priority)
	Stored.Priority = Priority
	Stored.Manual = Sort.Manual and true or false
end

local function FindOnSquare(Square, ItemId)
	if not Square then return nil end

	local Objects = Square:getWorldObjects()
	if not Objects then return nil end

	for Index = 0, Objects:size() - 1 do
		local Object = Objects:get(Index)
		local Item = Object and Object:getItem()
		if Item and Item:getID() == ItemId then return Item end
	end

	return nil
end

local function OnSaveItem(Player, Request)
	local Inventory = Player and Player:getInventory()
	if not Inventory then return end

	-- Looked up through the sender's own inventory, so a client can only ever write to
	-- an item it is actually carrying
	local Item = Inventory:getItemWithIDRecursiv(Request.ItemId)
	if not Item then return end

	WriteSort(Item:getModData(), Request.Suffix, Request.Sort)
end

local function OnSaveGround(Request)
	local Square = getCell():getGridSquare(Request.X, Request.Y, Request.Z)
	local Item = FindOnSquare(Square, Request.ItemId)
	if not Item then return end

	WriteSort(Item:getModData(), Request.Suffix, Request.Sort)
end

local function OnClientCommand(Module, Command, Player, Request)
	if Module ~= QolcReorderData.MODULE then return end
	if type(Request) ~= "table" or not Request.ItemId or not Request.Suffix then return end

	if Command == QolcReorderData.SAVE_ITEM then
		OnSaveItem(Player, Request)
	elseif Command == QolcReorderData.SAVE_GROUND then
		OnSaveGround(Request)
	end
end

--// Connections
Events.OnClientCommand.Add(OnClientCommand)
