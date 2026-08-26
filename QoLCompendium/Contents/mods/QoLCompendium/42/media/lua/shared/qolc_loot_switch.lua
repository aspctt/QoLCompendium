--// The Loot Switch
--// aspctt - 25.08.2026
--// Holds a feature's items out of the world when its sandbox option is off.
--//
--// This exists because the obvious place to do it does not work. Seeding a loot table
--// happens in OnPreDistributionMerge, and at that moment the save's sandbox options have
--// not been read yet, so a switch tested there is not the player's switch.
--//
--// Verified in the jar rather than assumed. IsoWorld.init fires OnPreDistributionMerge,
--// OnDistributionMerge and OnPostDistributionMerge, and only then calls
--// SandboxOptions.load. That is the one and only place map_sand.bin is ever read, and its
--// last act is toLua, which is what fills the SandboxVars table. Before it runs,
--// SandboxVars holds what initSandboxVars wrote when the lua loaded, and initSandboxVars
--// is fromTable followed by toTable over each option, so what it wrote is every option's
--// declared default. A merge time test therefore reads our own default and never the
--// player's answer, which is why turning a feature off still filled the world with its
--// items.
--//
--// Nor can the tables simply be edited later. ItemPickerJava.Parse runs straight after
--// SandboxOptions.load with no lua event between the two, and it reads the lua tables into
--// java structures that every container is filled from afterwards. So by the time the
--// options are real, the tables have already been taken.
--//
--// The switch is applied at OnFillContainer instead, which fires after each container is
--// filled and long after the options are true. Vanilla does the same thing in the same
--// place: ItemPickerJava calls ItemContainer.Remove on an item it has just rolled when a
--// NEVER_EMPTY container came up empty. Every fill path leads here, room containers,
--// zombies, zombie bags, nested bags and vehicles, so nothing gets past it.
--//
--// Cost when a feature is on, which is every feature by default, is one sandbox lookup
--// per registered feature per container. The container itself is only walked when
--// something is actually being withheld.
--//
--// Shared rather than server, which is where a loot file would otherwise belong, because
--// the three distribution files call Withhold at their own file scope and lua has to be
--// loaded by then. LuaManager.LoadDirBase takes shared before client before server, so
--// this is a guarantee rather than a matter of what the file names happen to sort as.
--// It costs nothing on a client: OnFillContainer only ever fires where containers are
--// actually filled, which is the authoritative side, so there the handler is never run.

--// State
-- Each entry is { Option = "SomethingEnabled", Items = { ["Base.Thing"] = true } }.
local Registered = {}

--// Functions
local function Enabled(Option)
	local Vars = SandboxVars and SandboxVars.QoLC
	local Value = Vars and Vars[Option]

	if Value ~= nil then return Value and true or false end
	return true
end

-- Read on every fill rather than worked out once and kept. Three table lookups is nothing
-- beside rolling a container's loot, and a cached answer would be a second thing that can
-- disagree with the sandbox page.
local function AnythingWithheld()
	for _, Entry in ipairs(Registered) do
		if not Enabled(Entry.Option) then return true end
	end

	return false
end

local function IsWithheld(FullType)
	for _, Entry in ipairs(Registered) do
		if Entry.Items[FullType] and not Enabled(Entry.Option) then return true end
	end

	return false
end

--// Interface
QolcLootSwitch = QolcLootSwitch or {}

-- Called at file scope by each distribution file, beside the tables it seeds, so the list
-- of what a switch covers sits with the code that put it in the world.
function QolcLootSwitch.Withhold(Option, FullTypes)
	local Items = {}
	for _, FullType in ipairs(FullTypes) do Items[FullType] = true end

	table.insert(Registered, { Option = Option, Items = Items })
end

-- Read by the spec.
function QolcLootSwitch.IsWithheld(FullType)
	return IsWithheld(FullType)
end

--// Connections
local function OnFillContainer(_RoomName, _ContainerType, Container)
	if not Container or not Container.getItems then return end
	if not AnythingWithheld() then return end

	local Items = Container:getItems()
	if not Items then return end

	-- Backwards, because removing shortens the list under the index.
	for Index = Items:size() - 1, 0, -1 do
		local Item = Items:get(Index)
		if Item and Item.getFullType and IsWithheld(Item:getFullType()) then
			Container:Remove(Item)
		end
	end
end

Events.OnFillContainer.Add(OnFillContainer)
