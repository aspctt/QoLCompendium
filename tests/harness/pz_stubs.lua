--// Project Zomboid API Stubs
--// aspctt - 09.08.2026
--// Fakes the slice of the game the compendium touches, so mods can run headless.

--// Harness
-- Control surface the specs drive. MoodleType is injected by TestRunner from the
-- shipped jar, so a constant that no longer exists is simply nil here too.
Harness = {}
Harness.EventHandlers = {}
Harness.MissingText = {}
Harness.Moodles = {}
Harness.Draws = {}
Harness.ScreenX = 1920
Harness.ScreenY = 1080
Harness.HasPlayer = true

function Harness.SetMoodle(Type, Level)
	if Type == nil then error("SetMoodle called with a nil MoodleType") end
	Harness.Moodles[Type] = Level
end

function Harness.SetScreenSize(Width, Height)
	Harness.ScreenX = Width
	Harness.ScreenY = Height
end

function Harness.ClearDraws()
	Harness.Draws = {}
end

function Harness.Fire(Name, A, B, C, D)
	local Handlers = Harness.EventHandlers[Name]
	if not Handlers then return 0 end
	for _, Handler in ipairs(Handlers) do
		Handler(A, B, C, D)
	end
	return #Handlers
end

function Harness.FireFrames(Count)
	for _ = 1, Count do
		Harness.Fire("OnPreUIDraw")
	end
end

function Harness.HandlerCount(Name)
	local Handlers = Harness.EventHandlers[Name]
	if not Handlers then return 0 end
	return #Handlers
end

-- Finds the most recent draw whose texture path contains Fragment
function Harness.FindDraw(Fragment)
	for Index = #Harness.Draws, 1, -1 do
		local Draw = Harness.Draws[Index]
		if Draw.Texture and Draw.Texture.Path and string.find(Draw.Texture.Path, Fragment, 1, true) then
			return Draw
		end
	end
	return nil
end

-- Returns the texture path of each draw, in the order they were issued
function Harness.DrawOrder()
	local Order = {}
	for Index, Draw in ipairs(Harness.Draws) do
		Order[Index] = Draw.Texture.Path
	end
	return Order
end

--// Events
-- Auto-creates an event object the first time a mod touches one, so new mods do not
-- need this file updated.
Events = setmetatable({}, {
	__index = function(Table, Name)
		local Event = {}
		Harness.EventHandlers[Name] = Harness.EventHandlers[Name] or {}

		function Event.Add(Handler)
			table.insert(Harness.EventHandlers[Name], Handler)
		end

		function Event.Remove(Handler)
			for Index, Existing in ipairs(Harness.EventHandlers[Name]) do
				if Existing == Handler then
					table.remove(Harness.EventHandlers[Name], Index)
					return
				end
			end
		end

		rawset(Table, Name, Event)
		return Event
	end
})

--// Rendering
UIManager = {}

function UIManager.DrawTexture(Texture, X, Y, Width, Height, Alpha)
	table.insert(Harness.Draws, {
		Texture = Texture,
		Alpha = Alpha,
		Height = Height,
		Width = Width,
		X = X,
		Y = Y
	})
end

function getTexture(Path)
	return { Path = Path }
end

--// Core
local CoreStub = {}

function CoreStub:getScreenWidth()
	return Harness.ScreenX
end

function CoreStub:getScreenHeight()
	return Harness.ScreenY
end

function getCore()
	return CoreStub
end

--// Player
local MoodlesStub = {}

function MoodlesStub:getMoodleLevel(Type)
	if Type == nil then
		error("getMoodleLevel was given a nil MoodleType. The constant does not exist in this build.")
	end
	return Harness.Moodles[Type] or 0
end

local PlayerStub = {}

function PlayerStub:getMoodles()
	return MoodlesStub
end

function getPlayer()
	if not Harness.HasPlayer then return nil end
	return PlayerStub
end

--// Translation
-- UI_EN.txt is itself valid Lua, so the runner loads it and we read the table it sets.
function getText(Key)
	if UI_EN and UI_EN[Key] ~= nil then
		return UI_EN[Key]
	end
	Harness.MissingText[Key] = true
	return Key
end

--// File IO
-- Only reached if a mod calls PZAPI.ModOptions save or load. Reads yield no lines,
-- so options keep their declared defaults during tests.
function getFileReader()
	local Reader = {}
	function Reader:readLine() return nil end
	function Reader:close() end
	return Reader
end

function getFileWriter()
	local Writer = {}
	function Writer:write() end
	function Writer:close() end
	return Writer
end

--// Utility
luautils = luautils or {}

function luautils.split(Text, Separator)
	local Parts = {}
	for Part in string.gmatch(Text, "([^" .. Separator .. "]+)") do
		table.insert(Parts, Part)
	end
	return Parts
end

--// UI Elements
-- Minimal ISUIElement surface. Mods resize panels vanilla built, so width and height
-- have to round trip.
local function NewElement(Width, Height)
	local Element = {}
	Element.Width = Width
	Element.Height = Height

	function Element:setWidth(Value) self.Width = Value end
	function Element:setHeight(Value) self.Height = Value end
	function Element:getWidth() return self.Width end
	function Element:getHeight() return self.Height end
	function Element:setVisible(Value) self.Visible = Value end

	return Element
end

Harness.NewElement = NewElement

--// Character Screen
-- Mirrors what vanilla ISCharacterScreen:create leaves behind, taken from
-- media\lua\client\XpSystem\ISUI\ISCharacterScreen.lua. Only the fields the compendium
-- touches are reproduced. If vanilla changes these, the specs should be updated with it.
Harness.VanillaAvatar = {
	BorderSpacing = 10,
	Border = 2,
	Width = 128,
	Height = 256,
	TextWidth = 40
}

ISCharacterScreen = {}

function ISCharacterScreen:create()
	local Vanilla = Harness.VanillaAvatar
	self.avatarX = Vanilla.BorderSpacing + 1 + Vanilla.Border
	self.avatarY = Vanilla.BorderSpacing + 1 + Vanilla.Border
	self.avatarWidth = Vanilla.Width
	self.avatarHeight = Vanilla.Height
	self.avatarPanel = NewElement(self.avatarWidth, self.avatarHeight)
	self.xOffset = self.avatarX + self.avatarWidth + Vanilla.BorderSpacing + 2 + Vanilla.TextWidth
	Harness.CreateCallCount = (Harness.CreateCallCount or 0) + 1
end

-- Builds a screen instance and runs whatever create chain the mods have layered on
function Harness.NewCharacterScreen()
	local Screen = {}
	ISCharacterScreen.create(Screen)
	return Screen
end

--// Drainable Items
-- Models DrainableComboItem. The game stores fill as a 0 to 1 fraction and derives the
-- integer use count from it, so both views have to stay consistent here too.
function Harness.NewDrainable(MaxUses, Fraction)
	local Item = {}
	Item.MaxUses = MaxUses
	Item.Fraction = Fraction or 1
	Item.Condition = 100
	Item.SyncCount = 0

	function Item:getMaxUses() return self.MaxUses end
	function Item:getCurrentUsesFloat() return self.Fraction end
	function Item:setCurrentUsesFloat(Value) self.Fraction = Value end
	function Item:getCondition() return self.Condition end
	function Item:setCondition(Value) self.Condition = Value end
	function Item:syncItemFields() self.SyncCount = self.SyncCount + 1 end

	function Item:getCurrentUses()
		return math.floor(self.Fraction * self.MaxUses + 0.5)
	end

	function Item:setCurrentUses(Count)
		self.Fraction = Count / self.MaxUses
	end

	return Item
end

--// Crafting
-- Stands in for CraftRecipeData. The real lists are Java ArrayLists, so they are indexed
-- from zero through get().
local function NewItemList(Item)
	local List = {}
	function List:get(Index)
		if Index == 0 then return Item end
		return nil
	end
	return List
end

function Harness.NewCraftRecipeData(Created, Consumed, Kept)
	local Data = {}
	function Data:getAllCreatedItems() return NewItemList(Created) end
	function Data:getAllConsumedItems() return NewItemList(Consumed) end
	function Data:getAllKeepInputItems() return NewItemList(Kept) end
	return Data
end

--// Script Manager
-- Item definitions the compendium patches at runtime. Seeded with the vanilla values
-- from media\scripts\generated\items\drainable.txt.
-- BodyLocation starts nil on the sling items on purpose. Item scripts parse before mod
-- lua runs, so a location registered from lua does not exist yet when the item is read,
-- and the game leaves it null. That is what makes the item unwearable, so the stub has
-- to reproduce it rather than pretend the script value stuck.
Harness.ScriptItems = {
	["Base.BlowTorch"] = { UseDelta = 0.1 },
	["Base.PropaneTank"] = { UseDelta = 0.0002 },
	["Base.SlingAFront"] = { BodyLocation = nil },
	["Base.SlingABack"] = { BodyLocation = nil },
}

local function NewScriptItem(Name)
	local Definition = Harness.ScriptItems[Name]
	if not Definition then return nil end

	local Item = {}
	function Item:getUseDelta() return Definition.UseDelta end
	function Item:getBodyLocation() return Definition.BodyLocation end

	function Item:setBodyLocation(Location)
		if type(Location) ~= "table" or not Location.IsItemBodyLocation then
			error("setBodyLocation expects an ItemBodyLocation, got " .. type(Location))
		end
		Definition.BodyLocation = Location
	end

	-- Real DoParam parses a "Key = Value" string, so parse it here rather than
	-- letting a malformed string quietly pass a test
	function Item:DoParam(Param)
		local Key, Value = string.match(Param, "^%s*(%w+)%s*=%s*(.+)%s*$")
		if not Key then error("DoParam could not parse: " .. tostring(Param)) end
		local Number = tonumber(Value)
		Definition[Key] = Number or Value
		Harness.DoParamCalls = (Harness.DoParamCalls or 0) + 1
	end

	return Item
end

ScriptManager = {}
ScriptManager.instance = {}

function ScriptManager.instance:getItem(Name)
	return NewScriptItem(Name)
end

--// Loot Distributions
-- Seeded with only the tables the compendium touches. Weights are irrelevant here,
-- what matters is that the table exists and carries an items list, exactly as the
-- vanilla ones do.
local function NewLootTable()
	return { rolls = 4, items = {} }
end

Harness.ProceduralNames = {
	"ArmyStorageOutfit", "ArmySurplusOutfit", "LockerArmyBedroom",
	"GunStoreAccessories", "FirearmWeapons",
	"PawnShopGunsSpecial", "PoliceStorageOutfit", "PoliceLockers",
}

Harness.VehicleNames = {
	"PoliceTruckBed", "PoliceGloveBox", "PoliceSeatFront",
	"PoliceStateSeatFront", "PoliceSheriffSeatFront",
	"PoliceSWATTruckBed", "PoliceSWATGloveBox",
}

ProceduralDistributions = { list = {} }
VehicleDistributions = {}

for _, Name in ipairs(Harness.ProceduralNames) do
	ProceduralDistributions.list[Name] = NewLootTable()
end

for _, Name in ipairs(Harness.VehicleNames) do
	VehicleDistributions[Name] = NewLootTable()
end

-- Vanilla aliases several parents onto the same underlying table. Reproduced so a
-- spec can prove the compendium does not add the same item twice through them.
VehicleDistributions.Police = {
	TruckBed = VehicleDistributions.PoliceTruckBed,
	GloveBox = VehicleDistributions.PoliceGloveBox,
	SeatFrontRight = VehicleDistributions.PoliceSeatFront,
}
VehicleDistributions.PoliceState = {
	TruckBed = VehicleDistributions.PoliceTruckBed,
	GloveBox = VehicleDistributions.PoliceGloveBox,
	SeatFrontRight = VehicleDistributions.PoliceStateSeatFront,
}
VehicleDistributions.PoliceSheriff = {
	TruckBed = VehicleDistributions.PoliceTruckBed,
	GloveBox = VehicleDistributions.PoliceGloveBox,
	SeatFrontRight = VehicleDistributions.PoliceSheriffSeatFront,
}

-- Returns the weight an item was registered at, or nil, plus how many times it
-- appears. Items lists are flat pairs of name then weight.
function Harness.LootWeight(Container, ItemName)
	if not Container or not Container.items then return nil, 0 end
	local Weight, Count = nil, 0
	for Index = 1, #Container.items - 1, 2 do
		if Container.items[Index] == ItemName then
			Weight = Container.items[Index + 1]
			Count = Count + 1
		end
	end
	return Weight, Count
end

--// Zombies
function Harness.NewZombie(OutfitName)
	local Items = {}
	local Inventory = {}

	function Inventory:AddItem(Name) table.insert(Items, Name) end
	function Inventory:contains(Name)
		for _, Existing in ipairs(Items) do
			if Existing == Name or Existing == "Base." .. Name then return true end
		end
		return false
	end
	function Inventory:getItems() return Items end

	local Zombie = {}
	function Zombie:getOutfitName() return OutfitName end
	function Zombie:getInventory() return Inventory end
	return Zombie
end

-- Deterministic by default so loot rolls can be tested exactly. Harness.NextRandom
-- is the value ZombRand will return.
Harness.NextRandom = 0

function ZombRand(Low, High)
	if High == nil then
		High = Low
		Low = 0
	end
	local Value = Low + Harness.NextRandom
	if Value >= High then return High - 1 end
	return Value
end

--// Hotbar
ISHotbar = ISHotbar or {}
ISHotbarAttachDefinition = ISHotbarAttachDefinition or {}
ISHotbarAttachDefinition.replacements = { { replacement = {} } }
ISAttachItemHotbar = ISAttachItemHotbar or {}
keyBinding = keyBinding or {}

-- Both are called with a dot and a single argument, BodyLocations.getGroup("Human"),
-- so getGroup takes the name directly rather than a self.
--
-- The two groups take DIFFERENT argument types in build 42, and getting that wrong is
-- a load time crash in game. BodyLocationGroup.getOrCreateLocation takes an
-- ItemBodyLocation object, AttachedLocationGroup.getOrCreateLocation still takes a
-- string. Both are enforced here so a mistake fails a test rather than the game.

--// Item Body Locations
-- A closed registry in build 42. Nothing registers custom entries for a mod, not the
-- item script loader nor ScriptManager, so a mod has to call register itself.
ItemBodyLocation = { Registered = {} }

-- Mirrors ResourceLocation.of: splits on a colon, defaults the namespace to "base",
-- and lowercases both halves.
function Harness.ResourceLocation(Text)
	if not Text or Text == "" then error("Identifier cannot be null or empty") end

	local Namespace, Path = string.match(Text, "^([^:]+):(.+)$")
	if not Namespace then
		Namespace, Path = "base", Text
	end
	return string.lower(Namespace), string.lower(Path)
end

-- Mirrors ItemBodyLocation.register, which passes allowDefault = false into
-- RegistryReset.createLocation and so refuses the base namespace. Vanilla registers
-- its own 114 with allowDefault = true, which is why bare names work only for it.
function ItemBodyLocation.register(Name)
	if type(Name) ~= "string" then
		error("ItemBodyLocation.register expects a string, got " .. type(Name))
	end

	local Namespace, Path = Harness.ResourceLocation(Name)
	if Namespace == "base" then
		error("Default namespace '" .. Namespace .. ":" .. Path .. "' is not allowed!")
	end

	local Location = { Name = Name, Id = Namespace .. ":" .. Path, IsItemBodyLocation = true }
	ItemBodyLocation.Registered[Location.Id] = Location
	return Location
end

BodyLocations = { Groups = {} }

function BodyLocations.getGroup(Name)
	if not BodyLocations.Groups[Name] then
		local Group = { Locations = {} }

		function Group:getOrCreateLocation(Location)
			if type(Location) ~= "table" or not Location.IsItemBodyLocation then
				error("expected argument of type ItemBodyLocation, got "
					.. (type(Location) == "string" and "String" or type(Location)))
			end
			self.Locations[Location.Id] = Location
			return Location
		end

		BodyLocations.Groups[Name] = Group
	end
	return BodyLocations.Groups[Name]
end

AttachedLocations = { Groups = {} }

function AttachedLocations.getGroup(Name)
	if not AttachedLocations.Groups[Name] then
		local Group = { Locations = {} }

		function Group:getOrCreateLocation(Id)
			if type(Id) ~= "string" then
				error("AttachedLocationGroup:getOrCreateLocation expects a string, got " .. type(Id))
			end
			if not self.Locations[Id] then
				local Location = { Id = Id }
				function Location:setAttachmentName(AttachName)
					self.AttachmentName = AttachName
					return self
				end
				self.Locations[Id] = Location
			end
			return self.Locations[Id]
		end

		AttachedLocations.Groups[Name] = Group
	end
	return AttachedLocations.Groups[Name]
end

--// Mods
-- No other mods active unless a spec says otherwise.
Harness.ActiveMods = {}

function getActivatedMods()
	local Mods = {}
	function Mods:contains(Name)
		for _, Active in ipairs(Harness.ActiveMods) do
			if Active == Name then return true end
		end
		return false
	end
	return Mods
end

--// Input
-- Any Keyboard.KEY_* resolves to a stable dummy code, for mods that add keybinds.
Keyboard = setmetatable({}, {
	__index = function(Table, Name)
		rawset(Table, Name, 0)
		return 0
	end
})
