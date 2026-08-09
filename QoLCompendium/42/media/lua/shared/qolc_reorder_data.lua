--// Reorder Containers Data
--// Reorder Containers, Workshop 2901962885 - Original design, MIT licensed
--// aspctt - 10.08.2026
--// Where a container's chosen position is stored, and the network contract for saving
--// it. Shared because the client writes these and a multiplayer server reads the same
--// layout back out of the request it is sent.
--//
--// The order lives on whatever owns the container rather than in one global table, so a
--// backpack keeps its place after being dropped and picked up again:
--//   the player's own inventory -> the player's mod data, keyed by container type
--//   a bag, a crate, a corpse   -> the item's or world object's mod data, keyed by name
--// Keying a world container by username stops two players who sort the same crate from
--// overwriting each other.

QolcReorderData = {}

--// Network
-- One module for the whole compendium. Commands carry the qolc prefix so a second
-- feature can share the module without its commands colliding.
QolcReorderData.MODULE = "QoLCompendium"
QolcReorderData.SAVE_GROUND = "QolcReorderSaveGround"
QolcReorderData.SAVE_ITEM = "QolcReorderSaveItem"

--// Tuning
-- Dragging renumbers in steps rather than 1, 2, 3, so a manually typed priority can sit
-- between two dragged containers without having to renumber everything again.
QolcReorderData.PRIORITY_STEP = 10

-- Containers with no chosen position sort after those that have one, in the order the
-- game built them.
QolcReorderData.PRIORITY_UNSET = 100000

local MOD_DATA_KEY = "QolcReorder"
local OPTIONS_KEY = "Options"
local SORT_KEY = "Sort"

local DEFAULT_OPTIONS = {
	LockInventory = false,
	LockLoot = false,
	SortLoot = false
}

local DEFAULT_SORT = {
	Manual = false
}

--// Functions
-- Fills in any field the stored table is missing, so a character saved before an option
-- existed picks up its default instead of reading nil.
local function FillBlanks(Target, Source)
	for Key, Value in pairs(Source) do
		if Target[Key] == nil then
			Target[Key] = Value
		end
	end
end

function QolcReorderData.GetSortKey(Suffix)
	return SORT_KEY .. tostring(Suffix)
end

-- Reads one table out of a mod data root, creating it and the module's own section on
-- the way if either is missing.
function QolcReorderData.GetSection(RootModData, Key, Defaults)
	if not RootModData then return nil end

	local Module = RootModData[MOD_DATA_KEY]
	if not Module then
		Module = {}
		RootModData[MOD_DATA_KEY] = Module
	end

	local Entry = Module[Key]
	if not Entry then
		Entry = {}
		Module[Key] = Entry
	end

	if Defaults then FillBlanks(Entry, Defaults) end
	return Entry
end

function QolcReorderData.GetSort(RootModData, Suffix)
	return QolcReorderData.GetSection(RootModData, QolcReorderData.GetSortKey(Suffix), DEFAULT_SORT)
end

function QolcReorderData.GetOptions(Player)
	if not Player then return nil end
	return QolcReorderData.GetSection(Player:getModData(), OPTIONS_KEY, DEFAULT_OPTIONS)
end
