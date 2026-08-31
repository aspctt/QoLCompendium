--// Lock Tools
--// Lockpicking. Just. Lockpicking., Workshop 2056238799
--// FMJ - Original, MeTaLAnGeR - IWBUMS update, Oh God Spiders No - streamlining
--// aspctt - 29.08.2026
--// What counts as a crowbar, and what counts as a screwdriver.
--//
--// By tag, because the type name was never the question. Build 42 forges its own
--// CrowbarForged, and base:screwdriver sits on the multitool, the handiknife, the
--// improvised screwdriver and the old one as well as the plain Screwdriver. A name check
--// turned every one of them away. Anything a mod adds with either tag counts now too,
--// which is what a player asked for.
--//
--// One file rather than a rule in each place, because the menu and the actions must not
--// drift apart: a menu that offers an option the action then refuses is worse than a menu
--// that never offered it.
--//
--// Shared, so it is loaded before every client file that reads it, and so a server holds
--// the same answer as its clients.

--// Tuning
-- Tag first, name second. The name is the fallback for a build with no such tag rather
-- than the answer, and it is the whole of the answer for our own lockpick, which nothing
-- else in the game is.
local CROWBAR = { Tag = ItemTag.CROWBAR, Type = "Crowbar" }
local SCREWDRIVER = { Tag = ItemTag.SCREWDRIVER, Type = "Screwdriver" }
local LOCKPICK = { Type = "QolcLockpick" }

--// Functions
-- A usable one, not merely one in the bag. The original checked condition, which matters
-- for a crowbar and does nothing for a hairpin, so both are checked the same way.
--
-- A named global rather than a closure built per call: getFirstTagEvalRecurse takes a
-- LuaClosure, and a fresh one on every context menu is a fresh closure handed to java.
function QolcToolIsUsable(Item)
	if not Item then return false end
	return not Item.getCondition or Item:getCondition() > 0
end

local function Is(Item, Rule)
	if not Item then return false end
	if Rule.Tag and Item.hasTag and Item:hasTag(Rule.Tag) then return true end

	return Item.getType and Item:getType() == Rule.Type
end

-- Recursive, unlike what this replaced. ItemContainer.FindAndReturn forwards to
-- getFirstType, which the jar shows walking this container and no further, so a crowbar in
-- a worn backpack was invisible to the menu.
local function Find(Inventory, Rule)
	if not Inventory then return nil end

	if Rule.Tag and Inventory.getFirstTagEvalRecurse then
		local Found = Inventory:getFirstTagEvalRecurse(Rule.Tag, QolcToolIsUsable)
		if Found then return Found end
	end

	local Item = Inventory.FindAndReturn and Inventory:FindAndReturn(Rule.Type)
	if Item and QolcToolIsUsable(Item) then return Item end

	return nil
end

--// Switches
-- Two switches since a player asked for the halves apart. Picking is the pick, the
-- screwdriver and the recipe; prying is the crowbar. Both default on, so a save that predates
-- the split keeps what it already had.
--
-- Here rather than in each file that wants them. The menu, the reading of the second manual
-- and the server command all have to agree on what off means, and three copies of the same
-- three lines is three chances to disagree.
local function Switch(Name)
	local Vars = SandboxVars and SandboxVars.QoLC
	local Value = Vars and Vars[Name]

	if Value ~= nil then return Value and true or false end
	return true
end

function QolcPickingEnabled() return Switch("LockpickingEnabled") end
function QolcPryingEnabled() return Switch("PryingEnabled") end

--// Answers
function QolcIsCrowbar(Item) return Is(Item, CROWBAR) end
function QolcIsScrewdriver(Item) return Is(Item, SCREWDRIVER) end

function QolcFindCrowbar(Inventory) return Find(Inventory, CROWBAR) end
function QolcFindScrewdriver(Inventory) return Find(Inventory, SCREWDRIVER) end
function QolcFindLockpick(Inventory) return Find(Inventory, LOCKPICK) end
