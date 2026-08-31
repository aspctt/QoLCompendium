--// Project Zomboid API Stubs
--// aspctt - 09.08.2026
--// Fakes the slice of the game the compendium touches, so mods can run headless.

--// Harness
-- Control surface the specs drive. MoodleType is injected by TestRunner from the
-- shipped jar, so a constant that no longer exists is simply nil here too.
Harness = {}
Harness.EventHandlers = {}
Harness.ClientCommands = {}
Harness.TriggeredEvents = {}
Harness.MissingText = {}
Harness.OpenWindows = {}
Harness.Players = {}
Harness.Moodles = {}
Harness.Draws = {}
Harness.Pages = {}
Harness.Squares = {}
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

-- Size stands in for the real texture's pixel dimensions. Kept so a spec can catch an
-- icon being drawn larger than the box it is meant to sit in.
Harness.TextureSize = 32

function getTexture(Path)
	return { Path = Path, Size = Harness.TextureSize }
end

--// Core
local CoreStub = {}

function CoreStub:getScreenWidth()
	return Harness.ScreenX
end

function CoreStub:getScreenHeight()
	return Harness.ScreenY
end

-- Bound keys. Vanilla ships Hotbar 1 to 8, and the game returns -1 for a binding that
-- does not exist, which is what makes clicking an unbound slot do nothing.
Harness.BoundKeys = {
	["Hotbar 1"] = 2, ["Hotbar 2"] = 3, ["Hotbar 3"] = 4, ["Hotbar 4"] = 5,
	["Hotbar 5"] = 6, ["Hotbar 6"] = 7, ["Hotbar 7"] = 8, ["Hotbar 8"] = 9
}

function CoreStub:getKey(Name)
	return Harness.BoundKeys[Name] or -1
end

-- A UIFont name, not a font. Vanilla hands back "Small", "Medium" and so on, which the
-- caller then looks up in the UIFont table.
-- The two highlight colours the game picks between to say yes or no. Only their channels
-- are ever read, so a spec can tell which one a feature chose.
local function NewColour(R, G, B)
	local Colour = {}
	function Colour:getR() return R end
	function Colour:getG() return G end
	function Colour:getB() return B end
	return Colour
end

function CoreStub:getGoodHighlitedColor() return NewColour(0, 1, 0) end
function CoreStub:getBadHighlitedColor() return NewColour(1, 0, 0) end

function CoreStub:getOptionTooltipFont()
	return Harness.TooltipFont
end

Harness.TooltipFont = "Small"

-- Vanilla's tooltip padding at each font, measured from the game. The real field has no
-- getter, so a mod adding a row has to match these or drift as the player changes font.
Harness.TooltipPadLeft = { Small = 8, Medium = 10, Large = 11 }

function getCore()
	return CoreStub
end

--// Clock
-- Mods that pace themselves off elapsed time read this. Specs move it by hand so a
-- test never has to wait on a real second.
Harness.NowMs = 0

function Harness.Advance(Milliseconds)
	Harness.NowMs = Harness.NowMs + Milliseconds
end

function getTimestampMs()
	return Harness.NowMs
end

--// Character Stats
-- Build 42 replaced every named accessor, getFatigue and setFatigue among them, with a
-- keyed pair taking a CharacterStat. Both CharacterStat and the real bounds behind it
-- are injected by TestRunner straight from the shipped jar, so a constant this build no
-- longer has reads nil here exactly as it would in game.
local function NewStats()
	local Values = {}
	local Stats = {}

	local function Bounds(Stat)
		return QOLC_STAT_BOUNDS and QOLC_STAT_BOUNDS[Stat] or nil
	end

	function Stats:get(Stat)
		if Stat == nil then
			error("Stats:get was given a nil CharacterStat. The constant does not exist in this build.")
		end
		if Values[Stat] ~= nil then return Values[Stat] end

		local Limits = Bounds(Stat)
		return Limits and Limits.Default or 0
	end

	-- The real Stats.set runs the value through CharacterStat.clamp before storing it,
	-- so a mod that overshoots sees what the game would keep, not what it asked for.
	function Stats:set(Stat, Value)
		if Stat == nil then
			error("Stats:set was given a nil CharacterStat. The constant does not exist in this build.")
		end

		local Limits = Bounds(Stat)
		if Limits then
			if Value < Limits.Min then Value = Limits.Min end
			if Value > Limits.Max then Value = Limits.Max end
		end

		Values[Stat] = Value
		return true
	end

	-- add and remove go through set, so they land inside the same bounds the game would
	-- clamp them to. Vanilla uses these rather than set wherever it nudges a stat, see
	-- IsoPlayer.petAnimal and BodyDamage.UpdateBoredom.
	function Stats:add(Stat, Value) return self:set(Stat, self:get(Stat) + Value) end
	function Stats:remove(Stat, Value) return self:set(Stat, self:get(Stat) - Value) end

	-- The part of stress that comes from wanting a cigarette. Build 42 renamed this from
	-- getStressFromCigarettes, and it is a component of STRESS rather than a stat of its
	-- own, so anything easing stress has to decide whether to eat into it.
	function Stats:getNicotineStress() return Values.Nicotine or 0 end
	function Stats:setNicotineStress(Value) Values.Nicotine = Value end

	return Stats
end

Harness.NewStats = NewStats

--// Java Collections
-- ArrayList and friends are indexed from zero through get(), which is the single most
-- common way lua written against this API goes wrong.
local function NewJavaList(Items)
	local List = {}
	function List:size() return #Items end
	function List:get(Index) return Items[Index + 1] end
	function List:getItemByIndex(Index) return Items[Index + 1] end

	-- Real ArrayList.contains, which mods use to test for another mod by id
	function List:contains(Value)
		for _, Item in ipairs(Items) do
			if Item == Value then return true end
		end
		return false
	end

	return List
end

Harness.NewJavaList = NewJavaList

--// Containers
-- Declared before the player, which builds one at file scope. ContainingItem is the bag
-- an inventory belongs to, Parent is the world object holding it. A player's own
-- inventory has neither.
function Harness.NewContainer(Type, ContainingItem, Parent)
	local Container = {}
	Container.Class = "ItemContainer"
	Container.Type = Type or "bag"
	Container.Items = {}

	function Container:getType() return self.Type end
	function Container:getContainingItem() return ContainingItem end
	function Container:getParent() return Parent end

	-- Containers can refuse an item outright, which is what build 42's grab menu checks
	-- before offering anything at all
	Container.Allowed = true

	function Container:isItemAllowed(_Item) return self.Allowed end

	-- Vanilla walks up the tree rather than asking what sort of container this is: either
	-- it is the character's own inventory, or the item holding it is somewhere inside
	-- that inventory, checked all the way up. So a worn backpack answers true, which is
	-- the whole reason anything asks. Answering on the container's own type, which is
	-- what this used to do, made every bag look as though it belonged to nobody.
	function Container:isInCharacterInventory(Character)
		if not Character then return false end
		if Character:getInventory() == self then return true end
		if not ContainingItem then return false end

		local Holder = ContainingItem.getContainer and ContainingItem:getContainer()
		if not Holder then return false end

		return Holder:isInCharacterInventory(Character)
	end

	-- Two overloads, and they do not behave the same way. AddItem(String) finds the script
	-- item, creates one, sets its container, adds it, and sets a food's heat from the
	-- container. AddItem(InventoryItem) asks containsID first, and if the container already
	-- holds an item carrying that id it logs "Error, container already has id", returns the
	-- one it already had, and adds nothing at all.
	--
	-- That is not a corner case. A freshly created item's id is zero: InventoryItem.id is
	-- written in three places in the jar, load, setID and createCloneItem, and none of them
	-- runs when an item is made from a script. So handing two fresh items to one container by
	-- object loses the second, in silence but for a line in the log.
	--
	-- This used to add whatever it was given and never look, which is how a loop that could
	-- only ever deliver one piece of meat passed a test asserting three.
	function Container:AddItem(What)
		if type(What) == "string" then
			local Made = instanceItem(What)
			Made.Container = self
			table.insert(self.Items, Made)
			return Made
		end

		for _, Held in ipairs(self.Items) do
			if Held.getID and What.getID and Held:getID() == What:getID() then
				Harness.RefusedDuplicateIds = (Harness.RefusedDuplicateIds or 0) + 1
				return Held
			end
		end

		What.Container = self
		table.insert(self.Items, What)
		return What
	end

	function Container:contains(Item)
		for _, Held in ipairs(self.Items) do
			if Held == Item then return true end
		end
		return false
	end

	function Container:FindAndReturn(Type)
		for _, Held in ipairs(self.Items) do
			if Held.getType and Held:getType() == Type then return Held end
			if Held.getFullType and Held:getFullType() == Type then return Held end
		end
		return nil
	end

	function Container:getItemWithIDRecursiv(Id)
		for _, Item in ipairs(self.Items) do
			if Item:getID() == Id then return Item end
		end
		return nil
	end

	-- A Java ArrayList, indexed from zero through get()
	function Container:getItems()
		local Items = self.Items
		local List = {}
		function List:size() return #Items end
		function List:get(Index) return Items[Index + 1] end
		return List
	end

	-- What vanilla itself reaches for to take back an item it has just rolled: ItemPicker
	-- Java calls this on a NEVER_EMPTY container that came up empty.
	function Container:Remove(Item)
		for Index, Held in ipairs(self.Items) do
			if Held == Item then
				table.remove(self.Items, Index)
				return
			end
		end
	end

	-- Down into the bags as well, which is the whole difference between these and
	-- getItems. A worn bag is its own container, so a heavy thing a player is carrying is
	-- very often not in the one getItems walks. Vanilla reaches for these rather than
	-- looping by hand: ISVehiclePartMenu finds a petrol can with containsEvalRecurse and
	-- getAllEvalRecurse and never touches getItems.
	local function Walk(From, Predicate, Found)
		for _, Item in ipairs(From.Items) do
			if Predicate(Item) then table.insert(Found, Item) end

			local Inner = Item.getInventory and Item:getInventory()
			if Inner and Inner.Items then Walk(Inner, Predicate, Found) end
		end

		return Found
	end

	function Container:getAllEval(Predicate)
		local Found = {}
		for _, Item in ipairs(self.Items) do
			if Predicate(Item) then table.insert(Found, Item) end
		end

		return NewJavaList(Found)
	end

	function Container:getAllEvalRecurse(Predicate)
		return NewJavaList(Walk(self, Predicate, {}))
	end

	function Container:containsEvalRecurse(Predicate)
		return Walk(self, Predicate, {})[1] ~= nil
	end

	-- How build 42 asks for a tool. getFirstTagEvalRecurse is what vanilla's own butchering
	-- menu uses to find a knife, and the Recurse half is the point: a crowbar in a backpack
	-- is in the bag's container, not this one, so the flat FindAndReturn above never sees it.
	-- Harness.TagKey rather than the local, which is declared further down the file and so
	-- is not in scope here. The field is read when this runs, by which point it is set.
	local function FirstTagged(From, Tag, Predicate, Deep)
		if not Harness.TagKey(Tag) then return nil end

		for _, Item in ipairs(From.Items) do
			if Item.hasTag and Item:hasTag(Tag) and (not Predicate or Predicate(Item)) then
				return Item
			end

			if Deep then
				local Inner = Item.getInventory and Item:getInventory()
				if Inner and Inner.Items then
					local Found = FirstTagged(Inner, Tag, Predicate, Deep)
					if Found then return Found end
				end
			end
		end

		return nil
	end

	function Container:getFirstTag(Tag) return FirstTagged(self, Tag, nil, false) end
	function Container:getFirstTagRecurse(Tag) return FirstTagged(self, Tag, nil, true) end

	function Container:getFirstTagEval(Tag, Predicate)
		return FirstTagged(self, Tag, Predicate, false)
	end

	function Container:getFirstTagEvalRecurse(Tag, Predicate)
		return FirstTagged(self, Tag, Predicate, true)
	end

	function Container:containsTagRecurse(Tag)
		return FirstTagged(self, Tag, nil, true) ~= nil
	end

	return Container
end

-- A bag carried or worn, with a container of its own. Anything inside it is out of reach
-- of the owner's getItems and reachable only by recursing.
function Harness.NewBag(Name)
	local Bag = Harness.NewInventoryItem(Name or "Backpack")
	Bag.Inventory = Harness.NewContainer("bag", Bag)

	function Bag:getInventory() return self.Inventory end

	return Bag
end

-- A propane tank, which is a drainable measured in uses rather than a fluid container
function Harness.NewPropaneTank(Fraction)
	local Tank = Harness.NewDrainable(5000, Fraction)
	Tank.Class = "InventoryItem"
	Tank.Id = Harness.NextItemId
	Harness.NextItemId = Harness.NextItemId + 1

	Tank.WorldStaticModel = "PropaneTank"

	function Tank:getFullType() return "Base.PropaneTank" end
	function Tank:getName() return "Propane Tank" end
	function Tank:getID() return self.Id end

	return Tank
end

--// Item Tags
-- Build 42 asks a container for a tool by tag rather than by name, and the two spellings
-- have to meet: a script writes base:sharpknife, the constant is SHARP_KNIFE. Strip the
-- module, drop the underscores, lowercase, and they are the same word.
local function TagKey(Tag)
	if type(Tag) ~= "string" then return nil end
	return Tag:gsub("^.*:", ""):gsub("_", ""):lower()
end

Harness.TagKey = TagKey

Harness.NextItemId = 1

function Harness.NewInventoryItem(Name, WorldItem)
	local Item = {}
	Item.Class = "InventoryItem"
	Item.ModData = {}
	Item.Name = Name or "Bag"
	Item.Id = Harness.NextItemId
	Harness.NextItemId = Harness.NextItemId + 1

	function Item:getModData() return self.ModData end
	function Item:getName() return self.Name end
	function Item:getID() return self.Id end
	function Item:getWorldItem() return WorldItem end

	-- Every InventoryItem answers this, so anything sorting a mixed bag of them can ask
	-- without checking first. Leaving it off meant a stub item behaved as though the call
	-- did not exist, which nothing in the game does.
	Item.FullType = "Base." .. (Name or "Bag")
	function Item:getFullType() return self.FullType end
	function Item:getType() return self.FullType:match("[^.]+$") end

	-- Favourites are skipped by every vanilla transfer, so anything moving items has to
	-- be able to ask
	Item.Favorite = false
	function Item:isFavorite() return self.Favorite end
	function Item:getContainer() return self.Container end

	-- The tags the game itself puts on an item of this name, read out of its own scripts by
	-- the runner rather than listed here. A stub that made them up would agree with whatever
	-- the code under test expects and disagree with the game, which is the one thing a stub
	-- must never do. An item the game does not define simply carries none.
	Item.TagSet = {}

	local Declared = VanillaItemTags and VanillaItemTags[Item.Name]
	if Declared then
		for _, Tag in ipairs(Declared) do Item.TagSet[TagKey(Tag)] = true end
	end

	function Item:addTag(Tag) self.TagSet[TagKey(Tag)] = true end

	function Item:hasTag(Tag)
		local Key = TagKey(Tag)
		return Key ~= nil and self.TagSet[Key] == true
	end

	return Item
end

function Harness.NewWorldObject(X, Y, Z)
	local Square = {}
	function Square:getX() return X or 0 end
	function Square:getY() return Y or 0 end
	function Square:getZ() return Z or 0 end

	local Object = {}
	Object.Class = "IsoWorldInventoryObject"
	function Object:getSquare() return Square end

	return Object, Square
end

-- A crate or a locker. Carries mod data and transmits it, same as any IsoObject.
function Harness.NewIsoObject()
	local Object = {}
	Object.Class = "IsoObject"
	Object.ModData = {}
	Object.Transmits = 0

	function Object:getModData() return self.ModData end
	function Object:transmitModData() self.Transmits = self.Transmits + 1 end

	return Object
end

--// Player
local function NewMoodles(Levels)
	local Moodles = {}

	function Moodles:getMoodleLevel(Type)
		if Type == nil then
			error("getMoodleLevel was given a nil MoodleType. The constant does not exist in this build.")
		end
		return Levels[Type] or 0
	end

	-- The rest of the surface MoodlesUI.render() reads. Good decides which plate a
	-- moodle takes, and the two strings are the hover label.
	function Moodles:getGoodBadNeutral(Type)
		if Type == nil then
			error("getGoodBadNeutral was given a nil MoodleType. The constant does not exist in this build.")
		end
		return Harness.GoodBadNeutral[Type] or Harness.DefaultGoodBadNeutral
	end

	function Moodles:getMoodleDisplayString(Type) return "Name:" .. tostring(Type) end
	function Moodles:getMoodleDescriptionString(Type) return "Desc:" .. tostring(Type) end

	return Moodles
end

Harness.NewMoodles = NewMoodles

-- IsLocal defaults true. On a real client OnPlayerUpdate also fires for every remote
-- player in range, which is what the remote case is here to reproduce.
function Harness.NewPlayer(Number, IsLocal)
	local Player = {}
	Player.Class = "IsoPlayer"
	Player.Levels = {}
	Player.Perks = {}
	Player.Traits = {}
	Player.ReadPages = {}
	Player.Said = {}
	Player.ModData = {}
	Player.Stats = NewStats()
	Player.Moodles = NewMoodles(Player.Levels)
	Player.Number = Number or 0
	Player.IsLocal = IsLocal ~= false
	Player.Username = "Player" .. tostring(Number or 0)
	Player.Asleep = false
	Player.Transmits = 0

	-- BodyDamage, reduced to the reading of infection the character can actually perceive.
	-- Apparent rather than real, because a character does not know they are infected.
	Player.BodyDamage = { Infection = 0 }
	function Player.BodyDamage:getApparentInfectionLevel() return self.Infection end
	function Player.BodyDamage:setFakeInfectionLevel(Value) self.Infection = Value end

	function Player:getBodyDamage() return self.BodyDamage end
	function Player:getMoodles() return self.Moodles end
	function Player:getModData() return self.ModData end
	function Player:getStats() return self.Stats end
	function Player:isLocalPlayer() return self.IsLocal end
	function Player:getPlayerNum() return self.Number end
	function Player:isAsleep() return self.Asleep end
	function Player:getUsername() return self.Username end
	function Player:getInventory() return self.Inventory end
	function Player:transmitModData() self.Transmits = self.Transmits + 1 end
	function Player:getWornItems() return NewJavaList(self.WornItems) end

	-- A bag being carried rather than worn provides no hotbar slots
	function Player:isHandItem(Item) return self.HandItem == Item end

	function Player:getPrimaryHandItem() return self.PrimaryHand end
	function Player:getSecondaryHandItem() return self.SecondaryHand end
	function Player:setPrimaryHandItem(Item) self.PrimaryHand = Item end
	function Player:setSecondaryHandItem(Item) self.SecondaryHand = Item end
	function Player:isTimedActionInstant() return self.InstantActions and true or false end

	-- Build 42 keeps known recipes as a plain list of names on the character. Reading that
	-- back has two forms, and the short one is not a question about this character at all.
	-- It looks the name up in the build 41 recipe table first, finds nothing for anything
	-- declared as a craftRecipe, and falls through to the SeeNotLearntRecipe sandbox option,
	-- which is on by default. So the short form answers true for every recipe this mod adds,
	-- learned or not. isRecipeActuallyKnown skips that, and is what the crafting screen asks.
	Player.Recipes = {}

	function Player:isRecipeKnown(Name, CheckOnly)
		if not CheckOnly and SandboxVars.SeeNotLearntRecipe ~= false then return true end

		return self.Recipes[Name] == true
	end

	function Player:isRecipeActuallyKnown(Name) return self:isRecipeKnown(Name, true) end
	function Player:getKnownRecipes() return NewJavaList(self.Recipes) end

	-- Carries the honest check itself, so a caller has no reason to guard it.
	function Player:learnRecipe(Name)
		if self:isRecipeActuallyKnown(Name) then return false end

		self.Recipes[Name] = true
		return true
	end

	function Player:getXp()
		local Owner = self
		local Xp = {}
		function Xp:AddXP(Perk, Amount)
			Owner.Xp = Owner.Xp or {}
			Owner.Xp[Perk] = (Owner.Xp[Perk] or 0) + Amount
		end
		return Xp
	end

	-- Which vehicle this character is in, is stood at, and is merely near. Vanilla's own
	-- vehicle menu asks for the last two in that order and takes the first answer. All three
	-- are nil unless a spec puts a vehicle there, which is the ordinary case: most of the
	-- world has no car in it.
	function Player:getVehicle() return self.InVehicle end
	function Player:getUseableVehicle() return self.UseableVehicle end
	function Player:getNearVehicle() return self.NearVehicle end

	-- Nil until a spec places them, the same as a character who is not in the world yet.
	-- Anything reading it has to cope with that.
	function Player:getSquare() return self.Square end
	function Player:setSquare(Square) self.Square = Square end

	-- An untrained skill reads zero rather than nil, same as the real getPerkLevel
	function Player:getPerkLevel(Perk)
		if Perk == nil then error("getPerkLevel was given a nil Perk") end
		return self.Perks[Perk] or 0
	end

	function Player:setPerkLevel(Perk, Level) self.Perks[Perk] = Level end

	-- Reading. Pages read are tracked per book type rather than per copy, which is what
	-- lets a character recognise a second copy of one they have already opened.
	function Player:getAlreadyReadPages(Type) return self.ReadPages[Type] or 0 end
	function Player:setAlreadyReadPages(Type, Pages) self.ReadPages[Type] = Pages end
	function Player:tooDarkToRead() return self.TooDark == true end
	function Player:Say(Text) table.insert(self.Said, Text) end

	function Player:hasTrait(Trait)
		if Trait == nil then error("hasTrait was given a nil CharacterTrait") end
		return self.Traits[Trait] == true
	end

	function Player:setTrait(Trait, Value) self.Traits[Trait] = Value end

	-- Build 42 moved traits off the character into their own object. The names are gone
	-- with them: get, set, add and remove all take a CharacterTrait. It reads and writes
	-- the same store hasTrait does, or a trait added at run time would not be seen.
	function Player:getCharacterTraits()
		local Owner = self
		local Traits = {}

		function Traits:get(Trait)
			if Trait == nil then error("CharacterTraits:get was given a nil CharacterTrait") end
			return Owner.Traits[Trait] == true
		end

		function Traits:add(Trait)
			if Trait == nil then error("CharacterTraits:add was given a nil CharacterTrait") end
			Owner.Traits[Trait] = true
		end

		function Traits:remove(Trait) Owner.Traits[Trait] = nil end
		function Traits:set(Trait, Value) Owner.Traits[Trait] = Value and true or nil end

		return Traits
	end

	-- Enough of the character surface for a timed action to run
	function Player:faceThisObject(Object) self.Facing = Object end
	function Player:shouldBeTurning() return self.Turning and true or false end
	function Player:setMetabolicTarget() end
	function Player:playSound(Name) return Name end
	function Player:stopOrTriggerSound() end
	function Player:isTimedActionInstant() return false end

	function Player:getDescriptor()
		local Descriptor = {}
		function Descriptor:getForename() return "Test" end
		function Descriptor:getSurname() return "Survivor" end
		return Descriptor
	end

	function Player:SetMoodle(Type, Level)
		if Type == nil then error("SetMoodle called with a nil MoodleType") end
		self.Levels[Type] = Level
	end

	-- The model side of the hotbar. An item hangs off a named attachment point on the
	-- character, separately from sitting in a hotbar slot, and the two can disagree: a
	-- slot whose point resolves to "null" has nowhere to hang the item and it comes off
	-- the bar entirely.
	--
	-- On every player rather than on request, because ISHotbar:refresh takes every
	-- carried item off and puts it back on its own, so any spec that changes clothing
	-- reaches this whether it asked to or not.
	Player.Attached = {}

	-- IsoGameCharacter.setAttachedItem hands the location to AttachedItems.setItem,
	-- which runs it through AttachedLocationGroup.checkValid before anything else.
	-- Verified in the jar: nil throws NullPointerException, an empty string throws
	-- IllegalArgumentException, and a name the rig does not have throws RuntimeException.
	-- So attaching with no model point is a hard error in game rather than a quiet
	-- no-op, and it has to be one here. The unknown name case is left out, since the rig
	-- point list is not something a spec should have to carry.
	function Player:setAttachedItem(Slot, Item)
		if Slot == nil then error("locationId is null") end
		if Slot == "" then error("locationId is empty") end

		self.Attached[Slot] = Item
	end

	function Player:getAttachedItem(Slot) return self.Attached[Slot] end

	function Player:removeAttachedItem(Item)
		for Slot, Held in pairs(self.Attached) do
			if Held == Item then self.Attached[Slot] = nil end
		end
	end

	Player.Inventory = Harness.NewContainer("inventory")
	Player.WornItems = {}
	Harness.Players[Player.Number] = Player

	return Player
end

-- A worn garment offering hotbar attachment points, e.g. a holster providing "Holster"
function Harness.NewWornItem(Provides)
	local Item = Harness.NewInventoryItem("Clothing")
	Item.Provides = Provides or {}

	function Item:getAttachmentsProvided() return NewJavaList(self.Provides) end
	function Item:setAttachedSlot(Index) self.AttachedSlot = Index end

	return Item
end

-- The player getPlayer() hands back. Its moodles read the shared Harness.Moodles table
-- so Harness.SetMoodle keeps driving it.
local PlayerStub = Harness.NewPlayer(0, true)
PlayerStub.Levels = Harness.Moodles
PlayerStub.Moodles = NewMoodles(Harness.Moodles)

Harness.Player = PlayerStub

function getPlayer()
	if not Harness.HasPlayer then return nil end
	return PlayerStub
end

--// Moodle Stack
-- The slice of the game the moodle quarters panel replaces: the element base class it
-- derives from, the parts of UIManager that own the moodle panels, and the moodle
-- strings its hover label reads. Ported from the standalone mod's own harness, which
-- shares this one's design.
--
-- UI holds the elements in draw order, back to front, the same as the real list. It is
-- separate from Harness.OpenWindows because that one is a set and this one is ordered:
-- the whole point of a stack panel is where it sits relative to the windows above it.
Harness.UI = {}
Harness.MoodlePanels = {}
Harness.FrameMs = 33.3
Harness.ActivePlayers = 1
Harness.MissingTextures = {}
Harness.GoodBadNeutral = {}
Harness.DefaultGoodBadNeutral = 2
Harness.MoodleSizeOption = 2
Harness.FontSizeOption = 1

function getNumActivePlayers() return Harness.ActivePlayers end

function UIManager.getMoodleUI(PlayerNum) return Harness.MoodlePanels[PlayerNum] end
function UIManager.getMillisSinceLastRender() return Harness.FrameMs end

function UIManager.AddUI(Element)
	table.insert(Harness.UI, Element)
end

function UIManager.RemoveElement(Element)
	for Index, Existing in ipairs(Harness.UI) do
		if Existing == Element then
			table.remove(Harness.UI, Index)
			return
		end
	end
end

function Harness.UIIndex(Element)
	for Index, Existing in ipairs(Harness.UI) do
		if Existing == Element then return Index end
	end
	return nil
end

function Harness.MoveBackMost(Element)
	UIManager.RemoveElement(Element)
	table.insert(Harness.UI, 1, Element)
end

function CoreStub:getOptionMoodleSize() return Harness.MoodleSizeOption end
function CoreStub:getOptionFontSizeReal() return Harness.FontSizeOption end

-- A path the install does not have comes back nil rather than raising, which is what
-- makes a mod hand the stack back to vanilla instead of drawing a column of holes.
local InstalledTexture = getTexture

function getTexture(Path)
	for _, Fragment in ipairs(Harness.MissingTextures) do
		if string.find(Path, Fragment, 1, true) then return nil end
	end
	return InstalledTexture(Path)
end

-- A player whose moodles read the shared Harness.Moodles table rather than a table of
-- their own, so Harness.SetMoodle reaches the moodle stack the same way it reaches
-- getPlayer(). Anything driving the stack wants one of these.
function Harness.NewMoodlePlayer(Number)
	local Player = Harness.NewPlayer(Number or 0, true)
	Player.Levels = Harness.Moodles
	Player.Moodles = Harness.NewMoodles(Harness.Moodles)
	return Player
end

function Harness.SetGoodBadNeutral(Type, Value)
	if Type == nil then error("SetGoodBadNeutral called with a nil MoodleType") end
	Harness.GoodBadNeutral[Type] = Value
end

-- The vanilla MoodlesUI panel, as far as a replacement is concerned: a position kept up
-- to date by UIManager.resize() and a visible flag that follows the HUD.
function Harness.NewMoodlePanel(PlayerNum, Y)
	local Panel = {}
	Panel.Class = "MoodlesUI"
	Panel.Y = Y or 120
	Panel.Visible = true

	function Panel:getY() return self.Y end
	function Panel:isVisible() return self.Visible end
	function Panel:setVisible(Value) self.Visible = Value end
	function Panel:backMost() Harness.MoveBackMost(self) end

	Harness.MoodlePanels[PlayerNum] = Panel
	UIManager.AddUI(Panel)
	return Panel
end

-- Enough of ISUIElement for a panel to be built, positioned and drawn. Draws land in
-- Harness.Draws in the order they were issued, which is what lets a spec prove the plate
-- goes down before the icon.
ISUIElement = {}
ISUIElement.__index = ISUIElement

local function RecordDraw(Kind, Texture, X, Y, W, H, A, R, G, B)
	table.insert(Harness.Draws, {
		Kind = Kind,
		Texture = Texture,
		X = X, Y = Y,
		Width = W, Height = H,
		Alpha = A,
		R = R, G = G, B = B
	})
end

function ISUIElement:new(X, Y, Width, Height)
	local Element = Harness.NewUIElement(X, Y, Width, Height)

	function Element:drawTexture(Texture, DrawX, DrawY, Alpha, R, G, B)
		RecordDraw("texture", Texture, DrawX, DrawY,
			Texture and Texture.Size, Texture and Texture.Size, Alpha, R, G, B)
	end

	function Element:drawRect(DrawX, DrawY, W, H, Alpha, R, G, B)
		RecordDraw("rect", nil, DrawX, DrawY, W, H, Alpha, R, G, B)
	end

	function Element:drawTextRight(Text, DrawX, DrawY, R, G, B, Alpha)
		table.insert(Harness.Draws, {
			Kind = "text", Text = Text, X = DrawX, Y = DrawY,
			Alpha = Alpha, R = R, G = G, B = B
		})
	end

	-- Ordered list rather than the window set the shared element uses
	function Element:backMost() Harness.MoveBackMost(self) end
	function Element:addToUIManager() UIManager.AddUI(self) end
	function Element:removeFromUIManager() UIManager.RemoveElement(self) end

	return Element
end

function ISUIElement:derive(Name)
	local Derived = {}
	Derived.__index = Derived
	Derived.Name = Name
	Derived.new = self.new
	Derived.derive = self.derive
	return Derived
end

-- One frame of UIManager.render(): every element on the list, in list order. A spec that
-- calls a panel's render directly cannot see a second panel still on the list, so
-- anything about how many stacks reach the screen has to go through this.
function Harness.RenderUI()
	Harness.ClearDraws()
	for _, Element in ipairs(Harness.UI) do
		if type(Element.render) == "function" then Element:render() end
	end
end

-- Every draw whose texture path contains Fragment, oldest first.
function Harness.FindDraws(Fragment)
	local Found = {}
	for _, Draw in ipairs(Harness.Draws) do
		if Draw.Texture and Draw.Texture.Path
			and string.find(Draw.Texture.Path, Fragment, 1, true) then
			table.insert(Found, Draw)
		end
	end
	return Found
end

--// Sandbox
-- Server controlled balance. Seeded from the defaults TestRunner parsed out of
-- 42/media/sandbox-options.txt, so these numbers are never restated here.
SandboxVars = { QoLC = {}, SeeNotLearntRecipe = true }

-- Vanilla's own frequency settings, which sit beside QoLC rather than inside it. One is
-- never, so four is a world that has alarms in it for a spec to disarm.
local VANILLA_SANDBOX = { Alarm = 4, CarAlarm = 4 }

function Harness.ResetSandbox()
	SandboxVars.QoLC = {}
	for Name, Value in pairs(VANILLA_SANDBOX) do
		SandboxVars[Name] = Value
	end

	if not QOLC_SANDBOX_DEFAULTS then return end
	for Name, Value in pairs(QOLC_SANDBOX_DEFAULTS) do
		SandboxVars.QoLC[Name] = Value
	end
end

-- A save made before a feature existed has no values at all, which the mod has to cope
-- with. This is how a spec reproduces that.
function Harness.ClearSandbox()
	SandboxVars.QoLC = nil
end

Harness.ResetSandbox()

--// Translation
-- Build 42 translations are flat json. TestRunner parses every file in the mod's
-- Translate folder into one Translations table, so a key resolves here the same way it
-- would in game regardless of which file declared it.
function getText(Key, ...)
	local Value = Translations and Translations[Key]
	if Value == nil then
		Harness.MissingText[Key] = true
		return Key
	end

	-- The game runs these through String.format. Only positional %1 and %2 are worth
	-- reproducing, which is all vanilla uses in the strings this mod touches.
	local Args = { ... }
	for Index, Argument in ipairs(Args) do
		Value = string.gsub(Value, "%%" .. Index, tostring(Argument))
	end
	return Value
end

function getTextOrNull(Key)
	if Translations and Translations[Key] ~= nil then return Translations[Key] end
	return nil
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

--// Module Loading
-- Mod files declare their vanilla dependencies with require, e.g. require "ISUI/ISPanel".
-- The runner has already loaded every stub by the time any mod file runs, so this only
-- has to not be nil. Anything genuinely missing fails later on use, with a better error
-- than a require would give.
Harness.Required = {}

function require(Path)
	Harness.Required[Path] = true
	return _G[string.match(tostring(Path), "([^/]+)$")] or {}
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

	-- The bar the game paints across an item's icon while a job runs on it
	function Item:setJobType(Value) self.JobType = Value end
	function Item:setJobDelta(Value) self.JobDelta = Value end

	-- Held and ground models. A drainable declares one or the other, rarely both.
	function Item:getStaticModel() return self.StaticModel end
	function Item:getWorldStaticModel() return self.WorldStaticModel end

	function Item:getCurrentUses()
		return math.floor(self.Fraction * self.MaxUses + 0.5)
	end

	function Item:setCurrentUses(Count)
		self.Fraction = Count / self.MaxUses
	end

	-- Which container is holding it. Every InventoryItem answers this, and a drainable is
	-- one, so leaving it off made a stub drainable behave as though the call did not
	-- exist. It is the question anything moving an item out of a bag has to ask first.
	function Item:getContainer() return self.Container end

	return Item
end

--// Crafting
-- Stands in for CraftRecipeData. The real lists are Java ArrayLists, so they are indexed
-- from zero through get(). Inputs defaults to everything the recipe is holding, consumed
-- and kept alike, which is what the real getAllInputItems returns.
local function NewItemList(Item)
	local List = {}
	function List:size() return Item ~= nil and 1 or 0 end
	function List:get(Index)
		if Index == 0 then return Item end
		return nil
	end
	return List
end

function Harness.NewCraftRecipeData(Created, Consumed, Kept, Inputs)
	local All = Inputs
	if not All then
		All = {}
		if Consumed ~= nil then table.insert(All, Consumed) end
		if Kept ~= nil then table.insert(All, Kept) end
	end

	local Data = {}
	function Data:getAllCreatedItems() return NewItemList(Created) end
	function Data:getAllConsumedItems() return NewItemList(Consumed) end
	function Data:getAllKeepInputItems() return NewItemList(Kept) end
	function Data:getAllInputItems() return NewJavaList(All) end

	-- What processDestroyAndUsedItems leaves behind. A performed recipe has already eaten
	-- its inputs by the time it returns, so anything a mod wants to measure about them has
	-- to be read first. Reproduced here so that ordering is a test rather than a comment.
	function Data:Destroy() All = {} end

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
	-- Ammo boxes and magazines, seeded with the icons vanilla actually ships. Note how
	-- many share one, that duplication is the thing the compendium fixes.
	["Base.Bullets9mmBox"] = { Icon = "HandgunAmmoBox" },
	["Base.Bullets45Box"] = { Icon = "HandgunAmmoBox" },
	["Base.Bullets44Box"] = { Icon = "HandgunAmmoBox" },
	["Base.Bullets38Box"] = { Icon = "HandgunAmmoBox" },
	["Base.Bullets357Box"] = { Icon = "HandgunAmmoBox" },
	["Base.ShotgunShellsBox"] = { Icon = "ShotgunAmmoBox" },
	["Base.308Box"] = { Icon = "RifleAmmo308" },
	["Base.556Box"] = { Icon = "RifleAmmo308" },
	["Base.3030Box"] = { Icon = "RifleAmmo308" },
	["Base.9mmClip"] = { Icon = "BerettaClip" },
	["Base.45Clip"] = { Icon = "BerettaClip" },
	["Base.44Clip"] = { Icon = "BerettaClip" },
	["Base.556Clip"] = { Icon = "m16clip" },
	["Base.M14Clip"] = { Icon = "M14Clip" },

	["Base.SlingAFront"] = { BodyLocation = nil },
	["Base.SlingABack"] = { BodyLocation = nil },

	-- Food, seeded from the real values in media\scripts. Vanilla files all of these
	-- under one Food heading, and the rot time is the only thing separating what spoils
	-- from what keeps. TinnedBeans and Yeast genuinely carry no rot time at all.
	["Base.Tomato"] = { DisplayCategory = "Food", DaysTotallyRotten = 12 },
	["Base.Potato"] = { DisplayCategory = "Food", DaysTotallyRotten = 280 },
	["Base.Cabbage"] = { DisplayCategory = "Food", DaysTotallyRotten = 4 },
	["Base.Honey"] = { DisplayCategory = "Food", DaysTotallyRotten = 730 },
	["Base.TinnedBeans"] = { DisplayCategory = "Food" },
	["Base.Yeast"] = { DisplayCategory = "Food" },

	-- A mod using a large number to mean "never rots" rather than food that spoils
	["Modded.EternalRation"] = { DisplayCategory = "Food", DaysTotallyRotten = 999999999 },

	-- Not food, so it must be left exactly as vanilla filed it
	["Base.Pan"] = { DisplayCategory = "Cooking" },
	["Base.Axe"] = { DisplayCategory = "ToolWeapon" },

	-- Clothing, seeded from the three fabric types build 42 defines. RippedSheets is one
	-- of only three vanilla items carrying both a fabric and a tooltip of its own, which
	-- must not be overwritten.
	["Base.Tshirt"] = { FabricType = "Cotton" },
	["Base.Jeans"] = { FabricType = "Denim" },
	["Base.JacketLeather"] = { FabricType = "Leather" },
	["Base.RippedSheets"] = { FabricType = "Cotton", Tooltip = "Tooltip_RippedSheets" },

	-- A fabric the game might add later, with no translation of ours to show for it
	["Base.SilkShirt"] = { FabricType = "Silk" },
}

-- Skill books, the twenty four families build 42 ships, five volumes each. Generated
-- rather than listed because the shape is entirely regular and a hand written list of a
-- hundred and twenty would rot silently.
--
-- Ten families draw as Book_Generic tinted through IconColorMask, which is exactly the
-- problem the compendium's icons solve, so the stub carries that distinction rather than
-- pretending every book already has art of its own.
Harness.DoParamsFor = {}

Harness.SkillBookFamilies = {
	"Aiming", "Blacksmith", "Butchering", "Carpentry", "Carving", "Cooking",
	"Electrician", "Farming", "FirstAid", "Fishing", "FlintKnapping", "Foraging",
	"Glassmaking", "Husbandry", "LongBlade", "Maintenance", "Masonry", "Mechanic",
	"MetalWelding", "Pottery", "Reloading", "Tailoring", "Tracking", "Trapping"
}

local TINTED = {
	Blacksmith = true, Butchering = true, Carving = true, FlintKnapping = true,
	Glassmaking = true, LongBlade = true, Masonry = true, Pottery = true,
	Tailoring = true, Tracking = true
}

for _, Family in ipairs(Harness.SkillBookFamilies) do
	for Volume = 1, 5 do
		Harness.ScriptItems["Base.Book" .. Family .. tostring(Volume)] = {
			DisplayCategory = "SkillBook",
			Icon = TINTED[Family] and "Book_Generic" or "Book8",
			IconColorMask = TINTED[Family] and "Book_Generic_Mask" or nil
		}
	end
end

local function NewScriptItem(Name)
	local Definition = Harness.ScriptItems[Name]
	if not Definition then return nil end

	local Item = {}
	function Item:getUseDelta() return Definition.UseDelta end
	function Item:getBodyLocation() return Definition.BodyLocation end
	function Item:getIcon() return Definition.Icon end
	function Item:getFullName() return Name end

	function Item:getDisplayCategory() return Definition.DisplayCategory end
	function Item:getFabricType() return Definition.FabricType end
	function Item:getTooltip() return Definition.Tooltip end

	-- The real one is a private field with no getter, so a mod cannot read it back. Only
	-- the stub exposes it, which is what lets a spec prove the tint was turned off.
	function Item:QolcIconColorMask() return Definition.IconColorMask end

	-- Zero on anything that does not spoil, which is how the game distinguishes tinned
	-- food from fresh
	function Item:getDaysTotallyRotten() return Definition.DaysTotallyRotten or 0 end

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

		-- Counted per item as well as in total. A single total is shared by every feature
		-- that patches a script, so one spec asserting "nothing happened on a second pass"
		-- would break the moment an unrelated feature legitimately writes something.
		Harness.DoParamCalls = (Harness.DoParamCalls or 0) + 1
		Harness.DoParamsFor[Name] = (Harness.DoParamsFor[Name] or 0) + 1
	end

	return Item
end

ScriptManager = {}
ScriptManager.instance = {}

function ScriptManager.instance:getItem(Name)
	return NewScriptItem(Name)
end

-- The real getAllItems returns a Java ArrayList of every script item, indexed from zero.
-- Order is not guaranteed by the game, so nothing should depend on it.
function getAllItems()
	local All = {}
	for Name in pairs(Harness.ScriptItems) do
		table.insert(All, Name)
	end
	table.sort(All)

	local List = {}
	function List:size() return #All end
	function List:get(Index) return NewScriptItem(All[Index + 1]) end
	return List
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

-- The hand written list above covers the tables a spec names directly. The rest come
-- from vanilla itself, read out of ProceduralDistributions by the runner, so a mistyped
-- table name has nowhere to land here either.
for _, Name in ipairs(Harness.ProceduralNames) do
	ProceduralDistributions.list[Name] = NewLootTable()
end

for _, Name in ipairs(QOLC_PROCEDURAL_NAMES or {}) do
	if not ProceduralDistributions.list[Name] then
		ProceduralDistributions.list[Name] = NewLootTable()
	end
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

-- A queue for the cases where consecutive rolls mean different things, as in picking a
-- lock: one roll decides whether it opens, the next whether the pick sticks, the next
-- whether it snaps. Seeding one value cannot tell those apart. Once the queue runs dry
-- it falls back to NextRandom, so a spec only states the rolls it cares about.
Harness.RandomQueue = {}

function Harness.SetRandom(Values)
	Harness.RandomQueue = {}
	for Index, Value in ipairs(Values or {}) do Harness.RandomQueue[Index] = Value end
end

function ZombRand(Low, High)
	if High == nil then
		High = Low
		Low = 0
	end

	local Next = Harness.NextRandom
	if #Harness.RandomQueue > 0 then Next = table.remove(Harness.RandomQueue, 1) end

	local Value = Low + Next
	if Value >= High then return High - 1 end
	return Value
end

-- A script this mod ships, by file name. For the handful of things that live in a script
-- rather than in lua, where the only honest assertion is about what was actually written.
-- Handed over by the runner, since Kahlua has no io library of its own.
function Harness.ReadModScript(Name)
	return (QOLC_MOD_SCRIPTS or {})[Name] or ""
end

-- The mod.info this build ships, verbatim. Some things are declared there and nowhere
-- else, and a missing line draws nothing rather than failing.
function Harness.ReadModInfo()
	return QOLC_MOD_INFO
end

--// Hotbar
ISHotbar = ISHotbar or {}
ISHotbarAttachDefinition = ISHotbarAttachDefinition or {}
ISHotbarAttachDefinition.replacements = { { replacement = {} } }

-- The two belt slots as build 42 declares them, verbatim from ISHotbarAttachDefinition
-- down to the rig positions each type hangs from. Anything adding a slot of its own
-- inserts into this same list, and anything widening one of these edits its attachments
-- table in place, so a stub that invented its own shape would prove nothing.
table.insert(ISHotbarAttachDefinition, {
	type = "SmallBeltLeft",
	name = "Belt Left",
	animset = "belt left",
	attachments = {
		Knife = "Belt Left Upside",
		NotKnife = "Belt Left Upside",
		Hammer = "Belt Left",
		HammerRotated = "Belt Rotated Left",
		Nightstick = "Nightstick Left",
		Screwdriver = "Belt Left Screwdriver",
		Wrench = "Wrench Left",
		MeatCleaver = "MeatCleaver Belt Left",
		Walkie = "Walkie Belt Left",
		Sword = "Belt Left Upside",
	},
})

table.insert(ISHotbarAttachDefinition, {
	type = "SmallBeltRight",
	name = "Belt Right",
	animset = "belt right",
	attachments = {
		Knife = "Belt Right Upside",
		NotKnife = "Belt Right Upside",
		Hammer = "Belt Right",
		HammerRotated = "Belt Rotated Right",
		Nightstick = "Nightstick Right",
		Screwdriver = "Belt Right Screwdriver",
		Wrench = "Wrench Right",
		MeatCleaver = "MeatCleaver Belt Right",
		Walkie = "Walkie Belt Right",
		Sword = "Belt Right Upside",
	},
})
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

Harness.MouseX = 0
Harness.MouseY = 0

function Harness.SetMouse(X, Y)
	Harness.MouseX = X
	Harness.MouseY = Y
end

function getMouseX() return Harness.MouseX end
function getMouseY() return Harness.MouseY end

--// Object Identity
-- The real instanceof walks the Java class hierarchy, so a mod testing for IsoObject
-- matches a player. Stubs declare a class name and this walks the same chain, or a
-- mod's IsoObject branch would silently never run in tests.
local CLASS_PARENTS = {
	IsoWorldInventoryObject = "IsoObject",
	IsoGameCharacter = "IsoMovingObject",
	IsoMovingObject = "IsoObject",
	IsoPlayer = "IsoGameCharacter",
	IsoWindow = "IsoObject",
	IsoDoor = "IsoObject"
}

function instanceof(Object, ClassName)
	if type(Object) ~= "table" then return false end

	local Current = Object.Class
	while Current do
		if Current == ClassName then return true end
		Current = CLASS_PARENTS[Current]
	end
	return false
end

--// Events From Java
-- Java side code raises events with triggerEvent rather than Events.X, and build 42's
-- inventory window uses it to announce each phase of a container refresh.
function triggerEvent(Name, A, B, C, D)
	table.insert(Harness.TriggeredEvents, { Name = Name, A = A, B = B })
	return Harness.Fire(Name, A, B, C, D)
end

--// Networking
-- Every sendClientCommand is recorded rather than sent, so a spec can assert on what a
-- client would have asked the server to do without needing a server. Also how a spec
-- proves a feature sends nothing at all.
function sendClientCommand(Player, Module, Command, Request)
	table.insert(Harness.ClientCommands, {
		Player = Player,
		Module = Module,
		Command = Command,
		Request = Request
	})
end

function Harness.LastCommand(Command)
	for Index = #Harness.ClientCommands, 1, -1 do
		local Entry = Harness.ClientCommands[Index]
		if not Command or Entry.Command == Command then return Entry end
	end
	return nil
end

-- isClient is true on a multiplayer client, false in singleplayer. isServer is true only
-- on a dedicated server. Both false is singleplayer, which is the default here.
Harness.IsClient = false
Harness.IsServer = false

function isClient() return Harness.IsClient end
function isServer() return Harness.IsServer end

-- LuaManager.GlobalObject.sendAddItemToContainer. The jar shows it returning immediately
-- unless GameServer.server, and otherwise handing straight to GameServer, so off a server it
-- genuinely does nothing. The call is recorded either way, which is observation rather than
-- behaviour: Sent says whether the real one would have put anything on the wire.
Harness.SentToContainer = {}

function sendAddItemToContainer(Container, Item)
	table.insert(Harness.SentToContainer, { Container = Container, Item = Item, Sent = isServer() })
end

--// Installed Mods
-- getActivatedMods returns a java ArrayList of mod ids, indexed from zero, the ids being
-- the id= line from each mod.info. A spec adds one to stand another mod up beside this
-- one and prove the compendium gets out of its way.
-- Seeded before any mod file loads, because a guard deciding whether a feature installs
-- itself at all runs at file scope and has already made its decision by the time a spec
-- could change this. QOLC_EXTRA_MODS carries the other mods for the run, see the second
-- pass in run-tests.ps1.
Harness.ActivatedMods = { "QoLCompendium" }

if QOLC_EXTRA_MODS then
	for _, Name in ipairs(QOLC_EXTRA_MODS) do
		table.insert(Harness.ActivatedMods, Name)
	end
end

function getActivatedMods()
	return NewJavaList(Harness.ActivatedMods)
end

--// UI Elements
-- Enough of ISUIElement for a mod to lay things out and be measured. Positions are real
-- numbers that round trip, because ordering mods are judged entirely on those.
-- Positions live on the lowercase fields, because vanilla reads self.width, self.height,
-- self.x and self.y directly as often as it calls the getters. Only exposing the
-- accessors leaves those reads nil, and the failure surfaces as a comparison against nil
-- somewhere far from the cause.
local function NewUIElement(X, Y, Width, Height)
	local Element = {}
	Element.x = X or 0
	Element.y = Y or 0
	Element.width = Width or 0
	Element.height = Height or 0
	Element.Children = {}
	Element.Visible = true
	Element.backgroundColor = { r = 0, g = 0, b = 0, a = 1 }

	function Element:setX(Value) self.x = Value end
	function Element:setY(Value) self.y = Value end
	function Element:getX() return self.x end
	function Element:getY() return self.y end
	function Element:setWidth(Value) self.width = Value end
	function Element:setHeight(Value) self.height = Value end
	function Element:getWidth() return self.width end
	function Element:getHeight() return self.height end
	function Element:getBottom() return self.y + self.height end
	function Element:getAbsoluteY() return self.y end
	function Element:getIsVisible() return self.Visible end
	function Element:setVisible(Value) self.Visible = Value end
	function Element:bringToTop() self.OnTop = true end
	function Element:setImage(Texture) self.Image = Texture end
	function Element:setTooltip(Text) self.Tooltip = Text end
	function Element:setOnClick(Handler) self.OnClick = Handler end
	function Element:setAlwaysOnTop(Value) self.AlwaysOnTop = Value end
	function Element:setCapture(Value) self.Capture = Value end
	function Element:setOnlyNumbers(Value) self.OnlyNumbers = Value end
	function Element:setText(Text) self.Text = Text end
	function Element:getText() return self.Text end
	function Element:initialise() end
	function Element:instantiate() end
	-- Vanilla's addChild sets the parent link, and mods rely on it to convert mouse
	-- coordinates. Leaving it off makes any drag silently do nothing.
	function Element:addChild(Child)
		table.insert(self.Children, Child)
		Child.parent = self
	end

	function Element:removeChild(Child)
		for Index, Existing in ipairs(self.Children) do
			if Existing == Child then
				table.remove(self.Children, Index)
				return
			end
		end
	end

	function Element:addToUIManager() Harness.OpenWindows[self] = true end
	function Element:removeFromUIManager() Harness.OpenWindows[self] = nil end

	-- Click a button the way a player would
	function Element:Click()
		if self.OnClick then self.OnClick(self) end
	end

	return Element
end

Harness.NewUIElement = NewUIElement

function Harness.OpenWindowCount()
	local Count = 0
	for _ in pairs(Harness.OpenWindows) do Count = Count + 1 end
	return Count
end

local function NewWidgetClass()
	local Class = {}
	Class.__index = Class

	function Class:new(X, Y, Width, Height, Text, Target, OnClick)
		local Element = NewUIElement(X, Y, Width, Height)
		Element.Text = Text
		Element.Target = Target
		if OnClick then
			Element.OnClick = function() OnClick(Target) end
		end
		return Element
	end

	function Class:derive(Name)
		local Derived = {}
		Derived.__index = Derived
		Derived.Name = Name
		Derived.new = self.new
		Derived.derive = self.derive
		return Derived
	end

	return Class
end

ISPanel = NewWidgetClass()
ISButton = NewWidgetClass()
ISLabel = NewWidgetClass()
ISTextEntryBox = NewWidgetClass()

-- ISLabel measures its own text, which mods use to centre it
function ISLabel:new(X, Y, Height, Text)
	local Element = NewUIElement(X, Y, string.len(tostring(Text or "")) * 6, Height)
	Element.Text = Text
	return Element
end

function ISTextEntryBox:new(Text, X, Y, Width, Height)
	local Element = NewUIElement(X, Y, Width, Height)
	Element.Text = Text
	return Element
end

ISTickBox = NewWidgetClass()

function ISTickBox:new(X, Y, Width, Height)
	local Element = NewUIElement(X, Y, Width, Height)
	Element.selected = {}
	Element.Options = {}

	function Element:addOption(Text)
		table.insert(self.Options, Text)
		return #self.Options
	end

	function Element:setSelected(Index, Value) self.selected[Index] = Value end
	function Element:isSelected(Index) return self.selected[Index] end

	return Element
end

UIFont = setmetatable({}, {
	__index = function(Table, Name)
		rawset(Table, Name, Name)
		return Name
	end
})

--// Inventory Page
-- Models the parts of ISInventoryPage that container ordering depends on, taken from
-- media\lua\client\ISUI\ISInventoryPage.lua. The important detail reproduced here is
-- that vanilla reads the backpacks ARRAY, not the screen: scroll height comes from the
-- last entry, and selection walks it in order. A mod that only moves buttons visually
-- leaves both wrong, and these stubs are what make that visible in a test.
ISInventoryPage = {}
ISInventoryPage.__index = ISInventoryPage

function ISInventoryPage:titleBarHeight() return 16 end

function ISInventoryPage:createChildren() end

-- Vanilla recycles container buttons through a pool rather than building new ones each
-- refresh, so the object showing one container this frame may have been showing another
-- last frame. Reproduced because it is exactly where an icon and an inventory can drift
-- apart, and creating fresh buttons every time hides that entirely.
function ISInventoryPage:addContainerButton(Container, Texture, Name, Tooltip)
	local Index = #self.backpacks + 1
	local Button

	if #self.buttonPool > 0 then
		Button = table.remove(self.buttonPool, 1)
		Button:setX(0)
		Button:setY(((Index - 1) * self.buttonSize) - 1)
	else
		Button = NewUIElement(0, ((Index - 1) * self.buttonSize) - 1, self.buttonSize, self.buttonSize)
		Button.OriginalCalls = {}
		function Button:onMouseDown() table.insert(self.OriginalCalls, "down") end
		function Button:onMouseMove() table.insert(self.OriginalCalls, "move") end
		function Button:onMouseMoveOutside() table.insert(self.OriginalCalls, "moveOutside") end
		function Button:onMouseUpOutside() table.insert(self.OriginalCalls, "upOutside") end

		-- Vanilla's onBackpackMouseUp selects the container. Reproduced because that is
		-- what makes releasing a drag over another button open it, and a stub that
		-- merely records the call cannot show that.
		function Button:onMouseUp()
			table.insert(self.OriginalCalls, "up")
			local Page = self.parent and self.parent.parent
			if Page and Page.onBackpackClick then Page:onBackpackClick(self) end
		end
	end

	Button.Class = "ISButton"
	Button.inventory = Container
	Button.tooltip = Tooltip
	Button.name = Name

	-- The icon vanilla picks is derived from the container, so it always matches the
	-- inventory the button carries. A spec can compare the two to catch a desync.
	Button.Image = "icon:" .. Container:getType()

	self.containerButtonPanel:addChild(Button)
	self.backpacks[Index] = Button
	return Button
end

-- Selecting a container goes through the button, never through its position, which is
-- what makes reordering the array safe in the first place.
function ISInventoryPage:selectContainer(Button)
	self.inventory = Button.inventory
	self.SelectedInventory = Button.inventory
end

function ISInventoryPage:onBackpackClick(Button)
	self:selectContainer(Button)
end

function ISInventoryPage:refreshBackpacks()
	self.buttonPool = self.buttonPool or {}
	for Index, Button in ipairs(self.backpacks) do
		self.containerButtonPanel:removeChild(Button)
		table.insert(self.buttonPool, Index, Button)
	end

	self.backpacks = {}
	self.RefreshCount = (self.RefreshCount or 0) + 1

	triggerEvent("OnRefreshInventoryWindowContainers", self, "begin")

	for _, Container in ipairs(self.Containers) do
		self:addContainerButton(Container, nil, Container:getType(), nil)
	end

	triggerEvent("OnRefreshInventoryWindowContainers", self, "beforeFloor")
	triggerEvent("OnRefreshInventoryWindowContainers", self, "buttonsAdded")

	-- Everything below reads the array, which is the whole point
	for _, Button in ipairs(self.backpacks) do
		if Button.inventory == self.inventory then self.selectedButton = Button end
	end

	local Last = self.backpacks[#self.backpacks]
	self.containerButtonPanel.ScrollHeight = Last and Last:getBottom() or 0

	triggerEvent("OnRefreshInventoryWindowContainers", self, "end")
end

-- OnCharacter false builds a loot window instead of the player's own inventory
function Harness.NewInventoryPage(PlayerNum, OnCharacter)
	local Page = NewUIElement(0, 0, 400, 500)
	setmetatable(Page, ISInventoryPage)

	Page.player = PlayerNum or 0
	Page.onCharacter = OnCharacter ~= false
	Page.buttonSize = 32
	Page.backpacks = {}
	Page.Containers = {}
	Page.containerButtonPanel = NewUIElement(0, 0, 32, 400)

	-- The panel is a child of the page in vanilla, and onBackpackMouseUp reaches the
	-- page through self.parent.parent, so the link has to exist here too.
	Page:addChild(Page.containerButtonPanel)

	return Page
end

-- Mirrors the part of build 42's ISInventoryPage:prerender that draws the weight and the
-- title, which is all the compendium touches. Both go through drawTextRight, the weight
-- anchored to the pin button and the title to a gap measured from a placeholder rather
-- than from the label actually drawn. That placeholder is the bug.
local WEIGHT_PLACEHOLDER = "9999.99 / 9999"

function ISInventoryPage:prerender()
	self.VanillaPrerenders = (self.VanillaPrerenders or 0) + 1

	local Weight = self.weightLabel or "12.34 / 50"
	self:drawTextRight(Weight, self.pinButton:getX() - 1, 0, 1, 1, 1, 1)

	if self.title and not self.onCharacter then
		local Reserved = getTextManager():MeasureStringX(UIFont.Small, WEIGHT_PLACEHOLDER) + 30

		-- Vanilla appends the campfire's remaining fuel, or a note that a vehicle seat is
		-- occupied, to the title before drawing it. A spec sets titleSuffix to get that.
		local Text = self.title .. (self.titleSuffix or "")
		self:drawTextRight(Text, self.width - 20 - Reserved, 4, 1, 1, 1, 1)
	end
end

-- A loot window with a title and a weight, laid out the way vanilla lays one out
function Harness.NewLootWindow(Title, WeightLabel, Width)
	local Page = Harness.NewInventoryPage(0, false)
	Page.width = Width or 400
	Page.title = Title or "Crate"
	Page.weightLabel = WeightLabel
	Page.Drawn = {}

	Page.pinButton = NewUIElement(Page.width - 40, 0, 16, 16)

	function Page:drawTextRight(Text, X, Y)
		table.insert(self.Drawn, {
			Text = Text, X = X, Y = Y,
			Left = X - getTextManager():MeasureStringX(UIFont.Small, Text)
		})
	end

	function Page:Find(Text)
		for _, Draw in ipairs(self.Drawn) do
			if Draw.Text == Text then return Draw end
		end
		return nil
	end

	return Page
end

-- Reads the button order off the screen rather than out of the array, so a spec can
-- prove the two agree
function Harness.ButtonOrderByPosition(Page)
	local Sorted = {}
	for Index, Button in ipairs(Page.backpacks) do
		Sorted[Index] = Button
	end
	table.sort(Sorted, function(A, B) return A:getY() < B:getY() end)

	local Names = {}
	for Index, Button in ipairs(Sorted) do
		Names[Index] = Button.inventory:getType()
	end
	return Names
end

function Harness.ButtonOrderByArray(Page)
	local Names = {}
	for Index, Button in ipairs(Page.backpacks) do
		Names[Index] = Button.inventory:getType()
	end
	return Names
end

--// Text And Sound
function getTextManager()
	local Manager = {}
	function Manager:getFontHeight() return 12 end
	function Manager:MeasureStringX(_Font, Text) return string.len(tostring(Text or "")) * 6 end
	return Manager
end

Harness.UISounds = {}

function getSoundManager()
	local Manager = {}
	function Manager:playUISound(Name) table.insert(Harness.UISounds, Name) end
	return Manager
end

--// Hotbar
-- Models the parts of ISHotbar that slot ordering depends on, transcribed from
-- media\lua\client\Hotbar\ISHotbar.lua rather than summarised from it. The shape of
-- availableSlot is the whole point, and the version of this stub that came before got it
-- wrong: it is a sparse map, not an array, and all sixteen places vanilla touches it walk
-- it with pairs. loadPosition writes an index only when getSlotDef resolves, so a saved
-- slot type belonging to a mod that is no longer loaded leaves a gap. refresh calls
-- savePosition partway through its own prune, while the gaps that prune just made are
-- still open, so a hole in the saved order is an ordinary state rather than a corrupt
-- one. And refresh puts the Back slot in its local survival list and never back into
-- availableSlot, so loadPosition is the only code in the game that ever restores it.
--
-- Rebuilding the bar dense from a canonical list on every refresh, which is what this
-- used to do, made every one of those unreachable, and let thirty eight passing tests sit
-- on top of a hotbar the game takes apart.
ISHotbar = {}
ISHotbar.__index = ISHotbar

Harness.HotkeyPresses = {}

-- What each slot will take. Vanilla maps an attachment type to the model point it hangs
-- from, and both halves matter: an attach with no point reaches the game with a null
-- location, which throws rather than quietly doing nothing.
Harness.SlotAttachments = {}

-- Which slot types have a definition at all. Vanilla answers out of
-- ISHotbarAttachDefinition and returns nil for anything not in it, which is how a slot
-- belonging to a mod that has gone away stops resolving. Seeded from that same list, and
-- added to by whatever a spec names.
Harness.SlotDefs = { Back = true }

for _, Def in ipairs(ISHotbarAttachDefinition) do
	Harness.SlotDefs[Def.type] = true
end

-- Kept rather than rebuilt per call, because vanilla hands back the entry itself and
-- anything registering a new attachment type edits that table in place.
local FabricatedDefs = {}

function Harness.DeclareSlotType(Name)
	if Name then Harness.SlotDefs[Name] = true end
end

-- Models the mod that declared a slot type going away, which is what leaves a hole in a
-- saved order where that slot used to sit.
function Harness.RetireSlotType(Name)
	Harness.SlotDefs[Name] = nil
	FabricatedDefs[Name] = nil
end

function ISHotbar:getSlotDef(Name)
	if not Name then return nil end
	if not Harness.SlotDefs[Name] then return nil end

	for _, Def in ipairs(ISHotbarAttachDefinition) do
		if Def.type == Name then return Def end
	end

	if not FabricatedDefs[Name] then
		local Accepts = Harness.SlotAttachments[Name] or { Name }
		local Attachments = {}
		for _, Type in ipairs(Accepts) do Attachments[Type] = Name end

		FabricatedDefs[Name] = { type = Name, name = Name, animset = Name, attachments = Attachments }
	end

	return FabricatedDefs[Name]
end

function ISHotbar:getSlotDefReplacement(Name)
	for _, Def in ipairs(ISHotbarAttachDefinition.replacements or {}) do
		if Def.type == Name then return Def end
	end

	return nil
end

function ISHotbar:compareWornItems()
	return self.WornChanged and true or false
end

-- pairs, like vanilla. Both are asked about a table with gaps in it constantly.
function ISHotbar:haveThisSlot(SlotType, List)
	for _, Slot in pairs(List or self.availableSlot) do
		if Slot.slotType == SlotType then return true end
	end

	return false
end

function ISHotbar:getThisSlotIndex(SlotType, List)
	for Index, Slot in pairs(List or self.availableSlot) do
		if Slot.slotType == SlotType then return Index end
	end

	return nil
end

function ISHotbar:getKeyForIndex(Index)
	return getCore():getKey("Hotbar " .. tostring(Index))
end

ISHotbar.onKeyStartPressed = function(Key)
	table.insert(Harness.HotkeyPresses, { Key = Key, Phase = "start" })
end

ISHotbar.onKeyPressed = function(Key)
	table.insert(Harness.HotkeyPresses, { Key = Key, Phase = "press" })
end

function ISHotbar:getSlotIndexAt(X, Y)
	if X >= 0 and X < self.width and Y >= 0 and Y < self.height then
		local Index = math.floor((X - self.margins) / (self.slotWidth + self.slotPad)) + 1
		Index = math.max(Index, 1)
		return math.min(Index, #self.availableSlot)
	end
	return -1
end

-- pairs, not ipairs. The order is written exactly as availableSlot stands, gaps included,
-- and refresh calls this while its own gaps are still open.
function ISHotbar:savePosition()
	local ModData = self.chr:getModData()
	ModData.hotbar = {}

	for Index, Slot in pairs(self.availableSlot) do
		ModData.hotbar[Index] = Slot.slotType
	end

	self.SaveCount = (self.SaveCount or 0) + 1
	if isClient() then self.chr:transmitModData() end
end

-- Adds to availableSlot rather than replacing it, skips any saved type it can no longer
-- resolve, and seeds the Back slot only when there is no saved order at all.
function ISHotbar:loadPosition()
	local ModData = self.chr:getModData()

	if ModData.hotbar then
		for Index, SlotType in pairs(ModData.hotbar) do
			local Def = self:getSlotDef(SlotType)
			if Def then
				self.availableSlot[Index] = { slotType = Def.type, name = Def.name, def = Def }
			end
		end
	else
		local Def = self:getSlotDef("Back")
		self.availableSlot[1] = { slotType = Def.type, name = Def.name, def = Def }
	end
end

-- Vanilla's refresh in its own order, including the three things nothing modelled before:
-- the Back slot goes into the local survival list and never into availableSlot, the slots
-- a garment provides are appended at #availableSlot + 1, and savePosition is called
-- partway through the prune while the table still has holes in it.
function ISHotbar:refresh()
	self.needsRefresh = false

	local Changed = false
	if not self.wornItems then
		self.wornItems = {}
		Changed = true
	elseif self:compareWornItems() then
		Changed = true
	end

	if not Changed then return end

	local NewSlots = {}
	local NewIndex = 2
	local SlotIndex = #self.availableSlot + 1

	local BackDef = self:getSlotDef("Back")
	NewSlots[1] = { slotType = BackDef.type, name = BackDef.name, def = BackDef }

	self.replacements = {}
	self.wornItems = {}

	local Worn = self.chr:getWornItems()
	for Index = 0, Worn:size() - 1 do
		local Item = Worn:getItemByIndex(Index)
		table.insert(self.wornItems, Item)

		if Item and self.chr:isHandItem(Item) then Item = nil end

		local Provided = Item and Item:getAttachmentsProvided()
		if Provided then
			for Position = 0, Provided:size() - 1 do
				local Def = self:getSlotDef(Provided:get(Position))

				if Def then
					NewSlots[NewIndex] = { slotType = Def.type, name = Def.name, def = Def }
					NewIndex = NewIndex + 1

					if not self:haveThisSlot(Def.type) then
						self.availableSlot[SlotIndex] = { slotType = Def.type, name = Def.name, def = Def }
						SlotIndex = SlotIndex + 1
						self:savePosition()
					end
				end
			end
		end

		local Replaces = Item and Item.getAttachmentReplacement and Item:getAttachmentReplacement()
		if Replaces then
			local Replacement = self:getSlotDefReplacement(Replaces)
			if Replacement then
				for Type, Model in pairs(Replacement.replacement) do
					self.replacements[Type] = Model
				end
			end
		end
	end

	local Attached = {}
	for Index, Slot in pairs(self.availableSlot) do
		local Item = self.attachedItems[Index]

		if not self:haveThisSlot(Slot.slotType, NewSlots) then
			self.availableSlot[Index] = nil
			if Item then self:removeItem(Item, false) end
		elseif Item then
			Attached[Slot.slotType] = Item
		end
	end

	self:savePosition()

	-- Compacted afterwards, which heals the gaps in memory and leaves the ones already
	-- written to the save behind.
	local Compacted = {}
	local Next = 1
	for _, Slot in pairs(self.availableSlot) do
		Compacted[Next] = Slot
		Next = Next + 1
	end
	self.availableSlot = Compacted

	for SlotType, Item in pairs(Attached) do
		local Index = self:getThisSlotIndex(SlotType)
		local Slot = Index and self.availableSlot[Index]

		if Slot then
			local Def = Slot.def
			self:removeItem(Item, false)

			if self.chr:getInventory():contains(Item) and not Item:isBroken() then
				self:attachItem(Item, Def.attachments[Item:getAttachmentType()], Index, Def, false)
			end
		end
	end

	self.RefreshCount = (self.RefreshCount or 0) + 1
	self:reloadIcons()
end

-- A hotbar item, carrying the two fields the game stores on it and serialises with it.
-- Both travel in SyncItemFieldsPacket as well, which is why a client that updates one
-- and not the other is a multiplayer problem rather than a local one.
-- zombie.Lua.LuaManager$GlobalObject.syncItemFields(player, item). Sends the item's
-- attached slot and slot type to the server, and is a no-op outside a multiplayer client.
function syncItemFields(_Character, Item)
	if not Item then return end

	Item.ServerAttachedSlot = Item.AttachedSlot
	Item.ServerAttachedSlotType = Item.AttachedSlotType
	Harness.SyncedFields = (Harness.SyncedFields or 0) + 1
end

function Harness.NewHotbarItem(AttachmentType, Name)
	local Item = Harness.NewInventoryItem(Name or "Axe")
	Item.AttachmentType = AttachmentType or "Axe"
	Item.AttachedSlot = -1
	Item.AttachedSlotType = nil
	Item.Broken = false

	-- What the server holds. A client changing AttachedSlot changes only its own copy;
	-- the value travels in SyncItemFieldsPacket and nowhere else, so anything that skips
	-- the sync is invisible until a rejoin hands the server's version back.
	Item.ServerAttachedSlot = -1
	Item.ServerAttachedSlotType = nil

	function Item:getAttachmentType() return self.AttachmentType end
	function Item:getAttachedSlot() return self.AttachedSlot end
	function Item:setAttachedSlot(Index) self.AttachedSlot = Index end
	function Item:getAttachedSlotType() return self.AttachedSlotType end
	function Item:setAttachedSlotType(Type) self.AttachedSlotType = Type end
	function Item:getAttachedToModel() return self.AttachedToModel end
	function Item:setAttachedToModel(Slot) self.AttachedToModel = Slot end
	function Item:isBroken() return self.Broken end

	return Item
end

-- Every player carries the model side of the hotbar from the moment it is made, see
-- Harness.NewPlayer. This clears it, for a spec that wants to start from an empty rig.
function Harness.InstallAttachments(Player)
	Player.Attached = {}

	return Player
end

-- Puts an item in the character's inventory. Anything meant to be on the hotbar has to
-- go through here, because reloadIcons builds the bar by scanning the inventory for
-- items whose attached slot is set. An item that is not carried cannot be on the bar,
-- and dropping one into attachedItems by hand only ever held until the next reload.
function Harness.CarryItem(Player, Item)
	Item.Container = Player.Inventory
	table.insert(Player.Inventory.Items, Item)

	return Item
end

-- Carried, then bound to a slot the way an attach leaves it. The pair is what a rejoin
-- rebuilds from.
function Harness.PutOnHotbar(Hotbar, Index, Item)
	Harness.CarryItem(Hotbar.chr, Item)

	Item:setAttachedSlot(Index)
	Item:setAttachedSlotType(Hotbar.availableSlot[Index] and Hotbar.availableSlot[Index].slotType)
	Hotbar.attachedItems[Index] = Item

	if Hotbar.availableSlot[Index] then Hotbar.availableSlot[Index].item = Item end

	return Item
end

-- Which point an item is hanging from, or nil when it is not on the model at all.
function Harness.AttachedAt(Player, Item)
	for Slot, Held in pairs(Player.Attached or {}) do
		if Held == Item then return Slot end
	end

	return nil
end

function ISHotbar:removeItem(Item, _KeepAttached)
	if self.chr then self.chr:removeAttachedItem(Item) end

	Item:setAttachedSlot(-1)
	Item:setAttachedSlotType(nil)
	Item:setAttachedToModel(nil)

	self:reloadIcons()
end

-- Rebuilt from the inventory, the way vanilla does it, rather than counted. An item is on
-- the bar because its own attached slot says so, which is why the binding on the item and
-- the order in mod data are two separate things that can disagree.
function ISHotbar:reloadIcons()
	self.IconReloads = (self.IconReloads or 0) + 1
	self.attachedItems = {}

	local Items = self.chr and self.chr:getInventory() and self.chr:getInventory():getItems()
	if not Items then return end

	for Index = 0, Items:size() - 1 do
		local Item = Items:get(Index)

		if Item and Item.getAttachedSlot and Item:getAttachedSlot() > -1 then
			self.attachedItems[Item:getAttachedSlot()] = Item
		end
	end
end

function ISHotbar:setAttachAnim(_Item, _SlotDef) end

-- Vanilla's attachItem. The sling feature replaces this outright rather than wrapping it,
-- so it has to be here both as what that replaces and as what runs in the passes where
-- the sling stands down. The branch refresh drives is the second one.
function ISHotbar:attachItem(Item, Slot, SlotIndex, SlotDef, DoAnim)
	if DoAnim then
		if SlotDef.name == "Back" and self.replacements and self.replacements[Item:getAttachmentType()] then
			Slot = self.replacements[Item:getAttachmentType()]
		end

		self:setAttachAnim(Item, SlotDef)
		self.AnimAttaches = (self.AnimAttaches or 0) + 1
		return
	end

	if SlotDef.name == "Back" and self.replacements and self.replacements[Item:getAttachmentType()] then
		Slot = self.replacements[Item:getAttachmentType()]

		if Slot == "null" then
			self:removeItem(Item, false)
			return
		end
	end

	if Slot == "null" then
		self:removeItem(Item, false)
		return
	end

	self.chr:setAttachedItem(Slot, Item)
	Item:setAttachedSlot(SlotIndex)
	Item:setAttachedSlotType(SlotDef.type)
	Item:setAttachedToModel(Slot)

	self:reloadIcons()
end

-- Vanilla's canBeAttached, which reads slot.def on its first line and checks nothing. It
-- can afford to: everything that calls it in the base game has already established there
-- is a slot there. Guarding it here, which is what this used to do, hid the fact that
-- calling it without one is a hard error rather than a false.
function ISHotbar:canBeAttached(Slot, Item)
	local Def = Slot.def

	for Type in pairs(Def.attachments) do
		if Item:getAttachmentType() == Type then return true end
	end

	return false
end

-- Mirrors the removal loop in vanilla's ISHotbar:update, which runs every frame. An item
-- whose recorded slot index no longer lands on a slot that accepts it is taken off the
-- hotbar and left in the inventory. This is the path both multiplayer reports go through,
-- and nothing here modelled it before.
function ISHotbar:update()
	for Index, Item in pairs(self.attachedItems) do
		local Slot = self.availableSlot[Item:getAttachedSlot()]

		if not Slot or not self:canBeAttached(Slot, Item)
			or not self.chr:getInventory():contains(Item) or Item:isBroken() then
			self.attachedItems[Index] = nil
			Item:setAttachedSlot(-1)
			Item:setAttachedSlotType(nil)
			self.Detached = (self.Detached or 0) + 1
		end
	end
end

-- Everything the game keeps about the hotbar across a disconnect: the slot order in the
-- player's mod data, and each item's own attached slot and type. Rebuilding from only
-- those is what a rejoin actually does.
function Harness.RejoinHotbar(Hotbar)
	local Player = Hotbar.chr
	local Items = {}

	for _, Item in pairs(Hotbar.attachedItems) do table.insert(Items, Item) end

	local Fresh = Harness.NewUIElement(0, 0, 400, 76)
	setmetatable(Fresh, ISHotbar)

	Fresh.SlotTypes = Hotbar.SlotTypes
	Fresh.character = Player
	Fresh.chr = Player
	Fresh.availableSlot = {}
	Fresh.attachedItems = {}
	Fresh.slotWidth, Fresh.slotHeight = 60, 60
	Fresh.slotPad, Fresh.margins = 4, 4
	Fresh.Drawn = {}

	function Fresh:getMouseX() return 0 end
	function Fresh:getMouseY() return 0 end

	Fresh:loadPosition()

	-- The items come back knowing which slot they were on, and the game puts them where
	-- that says rather than where they were on screen
	-- From the server's copy. reloadIcons rebuilds the bar by scanning the inventory for
	-- items whose attached slot is set, and after a rejoin those items are the server's,
	-- so an index the client never transmitted simply is not there.
	for _, Item in ipairs(Items) do
		Item.AttachedSlot = Item.ServerAttachedSlot or -1
		Item.AttachedSlotType = Item.ServerAttachedSlotType

		local At = Item:getAttachedSlot()
		if Fresh.availableSlot[At] then Fresh.attachedItems[At] = Item end
	end

	return Fresh
end

-- What the inventory is carrying under the cursor mid drag. Set while a stack is being
-- moved from one container to another, and read by anything that wants to know whether a
-- release is a drop rather than a click.
ISMouseDrag = ISMouseDrag or {}

function ISHotbar:isAllowedToActivateSlot() return true end
function ISHotbar:activateSlot(Index) self.ActivatedSlot = Index end

-- Vanilla's onMouseUp, transcribed. Two things about it matter, and neither survived
-- being summarised as a counter. The drag branch reads availableSlot at whatever index
-- getSlotIndexAt returned and hands it to canBeAttached without checking. And
-- getSlotIndexAt answers -1 for a point that is not on the bar, and 0 for one that is
-- when the bar has no slots on it.
--
-- Vanilla meets neither, because the game only dispatches this for a release that landed
-- on the element, and vanilla's bar always has the back slot. Both are reachable from a
-- mod, and the first one was reported: "attempted index: def of non-table: null".
function ISHotbar:onMouseUp(X, Y)
	self.VanillaMouseUps = (self.VanillaMouseUps or 0) + 1

	if ISMouseDrag.dragging then
		local Index = self:getSlotIndexAt(X, Y)
		local Slot = self.availableSlot[Index]

		for _, Item in ipairs(ISInventoryPane.getActualItems(ISMouseDrag.dragging)) do
			if Item ~= self.attachedItems[Index] and self:canBeAttached(Slot, Item) then
				self:attachItem(Item, Slot.def.attachments[Item:getAttachmentType()], Index, Slot.def, true)
				break
			end
		end

		return
	end

	local Index = self:getSlotIndexAt(X, Y)
	if Index > -1 and self:isAllowedToActivateSlot() then self:activateSlot(Index) end
end

-- ISPanelJoypad's, which ISHotbar inherits and never overrides. It lets go of a window
-- being dragged about by its frame, and it is what anything overriding this has to leave
-- working.
function ISHotbar:onMouseUpOutside(_X, _Y)
	self.moving = false
	self.OutsideUps = (self.OutsideUps or 0) + 1
end

-- Kept by name so a spec can tell the difference between the original still being in
-- place and something of ours having taken it over, and so one can be put back to stand
-- in for another mod owning it.
Harness.VanillaHotbarMouseUp = ISHotbar.onMouseUp
Harness.PanelMouseUpOutside = ISHotbar.onMouseUpOutside

function ISHotbar:doMenu(SlotIndex)
	self.LastMenuIndex = SlotIndex
end

function ISHotbar:onRightMouseUp(X, Y)
	self:doMenu(self:getSlotIndexAt(X, Y))
end

function ISHotbar:setSizeAndPosition()
	self:setWidth(self.margins * 2 + (self.slotWidth + self.slotPad) * #self.availableSlot)
end

function ISHotbar:render()
	self.RenderCount = (self.RenderCount or 0) + 1
end

-- SlotTypes is what the character's clothing currently provides, Back included. It is
-- the order the game would rebuild in, which an ordering mod then has to correct.
function Harness.NewHotbar(Player, SlotTypes)
	local Hotbar = Harness.NewUIElement(0, 0, 400, 76)
	setmetatable(Hotbar, ISHotbar)

	Hotbar.SlotTypes = SlotTypes or { "Back" }
	Hotbar.character = Player
	Hotbar.chr = Player
	Hotbar.availableSlot = {}
	Hotbar.attachedItems = {}
	Hotbar.slotWidth = 60
	Hotbar.slotHeight = 60
	Hotbar.slotPad = 4
	Hotbar.margins = 4
	Hotbar.borderColor = { r = 0.8, g = 0.8, b = 0.8, a = 0.8 }
	Hotbar.textColor = { r = 1, g = 1, b = 1, a = 1 }
	Hotbar.font = UIFont.Small
	Hotbar.MouseX = 0
	Hotbar.MouseY = 0
	Hotbar.Drawn = {}

	function Hotbar:getMouseX() return self.MouseX end
	function Hotbar:getMouseY() return self.MouseY end
	function Hotbar:drawRect(...) table.insert(self.Drawn, { Kind = "rect", ... }) end
	function Hotbar:drawRectBorderStatic(...) table.insert(self.Drawn, { Kind = "border", ... }) end
	function Hotbar:drawText(...) table.insert(self.Drawn, { Kind = "text", ... }) end

	-- Width and height are recorded so a spec can prove an icon stays inside its cell.
	-- drawTexture paints at the texture's own size, which is how a 32 pixel glyph ends
	-- up spilling across the slots beside an 18 pixel button.
	function Hotbar:drawTexture(Texture, X, Y)
		local Size = Texture and Texture.Size or 0
		table.insert(self.Drawn, { Kind = "texture", Texture = Texture, X = X, Y = Y, W = Size, H = Size })
	end

	function Hotbar:drawTextureScaled(Texture, X, Y, W, H)
		table.insert(self.Drawn, { Kind = "texture", Texture = Texture, X = X, Y = Y, W = W, H = H })
	end

	Harness.SetHotbarSlots(Hotbar, Hotbar.SlotTypes)

	-- ISHotbar:new loads the saved order before its first refresh, and that call is the
	-- only place in the whole game that ever puts the Back slot into availableSlot.
	Hotbar:loadPosition()

	-- Two refreshes, because the first is the one the mod deliberately sits out while
	-- the game is still building the bar. The second needs clothing to have changed, the
	-- same as any other refresh that does work.
	Hotbar:refresh()
	Hotbar.WornChanged = true
	Hotbar:refresh()
	Hotbar.WornChanged = false
	Hotbar:setSizeAndPosition()

	return Hotbar
end

-- Sets what the bar can show and dresses the character to match, since the game derives
-- one from the other. Back is always available and comes from no garment.
function Harness.SetHotbarSlots(Hotbar, SlotTypes)
	Hotbar.SlotTypes = SlotTypes

	local Provided = {}
	for _, SlotType in ipairs(SlotTypes) do
		-- Naming a slot is what gives it a definition, the same as a mod inserting one
		-- into ISHotbarAttachDefinition. Without this getSlotDef would refuse it.
		Harness.DeclareSlotType(SlotType)
		if SlotType ~= "Back" then table.insert(Provided, SlotType) end
	end

	Hotbar.character.WornItems = { Harness.NewWornItem(Provided) }
end

function Harness.SlotOrder(Hotbar)
	local Names = {}
	for Index, Slot in ipairs(Hotbar.availableSlot) do
		Names[Index] = Slot.slotType
	end
	return Names
end

--// Item Tooltip
-- ObjectTooltip is built on the Java side, so a mod can only reserve room while it
-- measures and draw into that room afterwards. Both halves are reproduced: setHeight is
-- called once with the measured content height, and DrawText records what was written.
local function NewObjectTooltip()
	local Tooltip = {}
	Tooltip.Texts = {}

	-- Where vanilla draws the item name and every stat row, measured from the game per
	-- tooltip font because the real padLeft has no getter and cannot be read from lua.
	-- Anything a mod adds has to land on the same column at every font size.
	Tooltip.padLeft = Harness.TooltipPadLeft[Harness.TooltipFont] or 8

	function Tooltip:DrawText(Font, Text, X, Y, R, G, B, A)
		table.insert(self.Texts, { Font = Font, Text = Text, X = X, Y = Y, R = R, G = G, B = B, A = A })
	end

	return Tooltip
end

ISToolTipInv = {}
ISToolTipInv.__index = ISToolTipInv

-- Mirrors the shape of vanilla's render: measure the item, set the height once, then
-- draw. The measured height is what a mod has to grow to fit a row of its own in.
ISToolTipInv.MeasuredHeight = 120

function ISToolTipInv:render()
	self.VanillaRenders = (self.VanillaRenders or 0) + 1

	-- Vanilla writes the item name and its stat rows at padLeft. Recorded so a spec can
	-- require anything a mod adds to share that column rather than trusting a number.
	self.tooltip:DrawText(UIFont.Small, "Encumbrance:", self.tooltip.padLeft, 20, 1, 1, 1, 1)
	self.VanillaRowX = self.tooltip.padLeft

	self:setHeight(ISToolTipInv.MeasuredHeight)
end

function Harness.NewItemTooltip(Item)
	local Panel = Harness.NewUIElement(0, 0, 200, 0)
	setmetatable(Panel, ISToolTipInv)

	Panel.item = Item
	Panel.tooltip = NewObjectTooltip()

	return Panel
end

--// Clothing
-- Covered parts, holes and patches are what RecipeCodeOnCreate.ripClothing turns into a
-- strip count, max(covered - (holes + patches), 1). The defaults describe a pristine
-- jacket, so a spec only states the ones it is actually about.
function Harness.NewGarment(Fabric, Type, Covered, Holes, Patches)
	local Item = Harness.NewInventoryItem("Jacket")
	Item.Type = Type or "Base.Jacket_Test"
	Item.Covered = Covered or 7
	Item.Holes = Holes or 0
	Item.Patches = Patches or 0

	function Item:getFabricType() return Fabric end
	function Item:getFullType() return self.Type end
	function Item:getNbrOfCoveredParts() return self.Covered end
	function Item:getHolesNumber() return self.Holes end
	function Item:getPatchesNumber() return self.Patches end

	return Item
end

--// Weapons
-- Condition runs 0 to conditionMax, and the max differs per item, which is why anything
-- reading it has to work in fractions rather than raw numbers.
function Harness.NewWeapon(Condition, ConditionMax)
	local Weapon = Harness.NewInventoryItem("Axe")
	Weapon.Condition = Condition or 10
	Weapon.ConditionMax = ConditionMax or 10

	function Weapon:getCondition() return self.Condition end
	function Weapon:setCondition(Value) self.Condition = Value end
	function Weapon:getConditionMax() return self.ConditionMax end
	function Weapon:IsWeapon() return true end
	function Weapon:getTex() return getTexture("media/ui/Axe.png") end

	return Weapon
end

-- Food, books and the like report a max of zero, so they have no condition to show
function Harness.NewPlainItem()
	local Item = Harness.NewInventoryItem("Apple")
	function Item:getCondition() return 0 end
	function Item:getConditionMax() return 0 end
	function Item:IsWeapon() return false end
	return Item
end

--// Equipped Item Panel
-- Mirrors ISEquippedItem, which draws the item in each hand into two boxes and reads
-- getCondition only to decide what may be dragged in. Nothing is drawn for condition.
ISEquippedItem = {}
ISEquippedItem.__index = ISEquippedItem

function ISEquippedItem:render()
	self.VanillaRenders = (self.VanillaRenders or 0) + 1

	-- Vanilla draws the item icon here. Recording how much had already been drawn lets a
	-- spec prove a mod painted behind the icon rather than across it.
	self.DrawnBeforeVanilla = #self.Drawn
end

function Harness.NewEquippedItemPanel(Player)
	local Panel = Harness.NewUIElement(0, 0, 100, 100)
	setmetatable(Panel, ISEquippedItem)

	Panel.chr = Player

	-- Vanilla's own proportions. The main hand box is square and the off hand box is
	-- three quarters as tall as it is wide, TEXTURE_HEIGHT = TEXTURE_WIDTH * 0.75, which
	-- is what turns a box filling fill into an ellipse on the second slot.
	Panel.mainHand = { x = 0, y = 0, width = 48, height = 48 }
	Panel.offHand = { x = 0, y = 60, width = 48, height = 36 }
	Panel.Drawn = {}

	function Panel:drawRect(X, Y, W, H, A, R, G, B)
		table.insert(self.Drawn, { Kind = "rect", X = X, Y = Y, W = W, H = H, A = A, R = R, G = G, B = B })
	end

	-- The round slots are drawn as a disc clipped to the filled band, so a spec has to
	-- see both the texture and the clip that shaped it.
	function Panel:drawTextureScaled(Texture, X, Y, W, H, A, R, G, B)
		table.insert(self.Drawn, {
			Kind = "texture", Texture = Texture,
			X = X, Y = Y, W = W, H = H, A = A, R = R, G = G, B = B,
			Stencil = self.Stencil
		})
	end

	function Panel:setStencilRect(X, Y, W, H)
		self.Stencil = { X = X, Y = Y, W = W, H = H }
	end

	function Panel:clearStencilRect()
		self.Stencil = nil
	end

	return Panel
end

--// World Objects
-- A fuel pump. Vanilla recognises one by getPipedFuelAmount() > 0, which covers both
-- having power and having fuel left, so that is the whole of what a pump needs here.
function Harness.NewFuelPump(Fuel)
	local Pump = {}
	Pump.Class = "IsoObject"
	Pump.Fuel = Fuel or 22000

	function Pump:getPipedFuelAmount() return self.Fuel end
	function Pump:setPipedFuelAmount(Value) self.Fuel = Value end
	function Pump:getSquare() return nil end

	return Pump
end

-- A square carrying objects, registered so getCell():getGridSquare can find it. That is
-- how anything sweeping the tiles around a click reaches its neighbours.
function Harness.NewObjectSquare(X, Y, Z, Objects)
	Objects = Objects or {}

	local Square = {}
	Square.Dropped = {}
	Square.Bodies = {}

	function Square:getX() return X or 0 end
	function Square:getY() return Y or 0 end
	function Square:getZ() return Z or 0 end

	-- What anything dropped on the ground goes through, by full type in the order it landed.
	function Square:AddWorldInventoryItem(Item, _OffX, _OffY, _OffZ)
		table.insert(self.Dropped, Item and Item:getFullType() or nil)
		return Item
	end

	-- The dead bodies on this square. Vanilla's own corpse menus walk this rather than the
	-- object list, because a body is a moving object that has stopped rather than furniture.
	function Square:getStaticMovingObjects()
		local Bodies = self.Bodies
		local List = {}
		function List:size() return #Bodies end
		function List:get(Index) return Bodies[Index + 1] end
		return List
	end

	function Square:getObjects()
		local List = {}
		function List:size() return #Objects end
		function List:get(Index) return Objects[Index + 1] end
		return List
	end

	-- How the game takes a corpse off the map, and not the same thing as removing any other
	-- object. Transcribed from IsoGridSquare.removeCorpse rather than guessed: on a client it
	-- reconciles the body's own container through checkAddedRemovedItems and sends
	-- RemoveCorpseFromMap to the server, on a server it sends the same out to everyone near
	-- it, then it invalidates the render chunk, then it does removeFromWorld and
	-- removeFromSquare, and finally, anywhere but a server, it triggers OnContainerUpdate.
	--
	-- The second argument suppresses the packet when true. Vanilla passes false everywhere.
	Square.CorpsesRemoved = 0

	function Square:removeCorpse(Body, Quiet)
		self.CorpsesRemoved = self.CorpsesRemoved + 1
		self.CorpseSynced = not Quiet

		for Index, Held in ipairs(self.Bodies) do
			if Held == Body then table.remove(self.Bodies, Index) break end
		end

		Body:removeFromWorld()
		Body:removeFromSquare()

		triggerEvent("OnContainerUpdate", self)
	end

	Harness.Squares[tostring(X or 0) .. "," .. tostring(Y or 0) .. "," .. tostring(Z or 0)] = Square
	return Square
end

--// Buildings, Doors And Windows
-- BuildingDef, reduced to the one flag that decides whether an alarm sounds. The game
-- reads it back in AmbientStreamManager:doAlarm, so clearing it is the whole job.
function Harness.NewBuildingDef(Alarmed)
	local Def = {}
	Def.Alarmed = Alarmed and true or false

	function Def:isAlarmed() return self.Alarmed end
	function Def:setAlarmed(Value) self.Alarmed = Value and true or false end

	return Def
end

-- A door or window straddles two squares. Its own square is where it was placed; the
-- opposite square is the other side, and the building can be on either.
local function AttachSides(Object, Square, Opposite)
	function Object:getSquare() return Square end
	function Object:getOppositeSquare() return Opposite end
	return Object
end

-- Values: Open, Locked, LockedByKey, Exterior. Build 42's isExteriorDoor ignores the
-- character it is handed and calls isExterior, which is what this models.
function Harness.NewDoor(Values, Square, Opposite)
	Values = Values or {}

	local Door = {}
	Door.Class = "IsoDoor"

	function Door:IsOpen() return Values.Open and true or false end
	function Door:isLocked() return Values.Locked and true or false end
	function Door:isLockedByKey() return Values.LockedByKey and true or false end

	function Door:isExterior()
		if Values.Exterior == nil then return true end
		return Values.Exterior and true or false
	end

	return AttachSides(Door, Square, Opposite)
end

-- Values: Open, Destroyed. A merely unlocked window is not a state the mod looks at, so
-- there is deliberately no isLocked here: adding one would invite a spec to test it.
function Harness.NewWindow(Values, Square, Opposite)
	Values = Values or {}

	local Window = {}
	Window.Class = "IsoWindow"

	function Window:IsOpen() return Values.Open and true or false end
	function Window:isDestroyed() return Values.Destroyed and true or false end

	return AttachSides(Window, Square, Opposite)
end

--// Vehicles
-- A car door is a VehicleDoor hanging off a VehiclePart, not an IsoDoor, and none of the
-- door stubs above describe one. Transcribed from zombie.vehicles.VehicleDoor, which is four
-- booleans and their accessors and nothing else.
--
-- lockBroken is the field that matters: the jar shows BaseVehicle.canUnlockDoor and
-- canLockDoor both returning false the moment it is set, so a broken lock is a door that
-- can never be unlocked and never be locked again, depending on which side of it you were
-- on when it broke.
function Harness.NewVehicleDoor(Values)
	Values = Values or {}

	local Door = {}
	Door.Open = Values.Open and true or false
	Door.Locked = Values.Locked ~= false
	Door.LockBroken = Values.LockBroken and true or false

	function Door:isOpen() return self.Open end
	function Door:setOpen(Value) self.Open = Value and true or false end
	function Door:isLocked() return self.Locked end
	function Door:setLocked(Value) self.Locked = Value and true or false end
	function Door:isLockBroken() return self.LockBroken end
	function Door:setLockBroken(Value) self.LockBroken = Value and true or false end

	return Door
end

-- One part of a vehicle. Only the parts a lock cares about are modelled: the id, the area
-- used for pathing, the door, whether the part is fitted at all, and the mod data, which
-- VehiclePart.save writes out and so survives a reload.
function Harness.NewVehiclePart(Id, Values)
	Values = Values or {}

	local Part = {}
	Part.ModData = {}
	Part.Door = Values.Door ~= false and Harness.NewVehicleDoor(Values) or nil

	-- getInventoryItem is nil for a part that is not fitted. Vanilla checks it before
	-- offering anything on a door, because a missing door has no lock.
	--
	-- Written out rather than as an and/or, which cannot express nil: the false branch of
	-- "a and nil or b" falls straight through to b, so every part came back fitted.
	if Values.Fitted ~= false then
		Part.Item = Harness.NewInventoryItem(Id or "DoorFrontLeft")
	end

	function Part:getId() return Id or "DoorFrontLeft" end
	function Part:getArea() return Values.Area or "SeatFrontLeft" end
	function Part:getDoor() return self.Door end
	function Part:getInventoryItem() return self.Item end
	function Part:getModData() return self.ModData end
	function Part:getVehicle() return self.Vehicle end
	function Part:getSquare() return self.Vehicle and self.Vehicle:getSquare() end

	return Part
end

-- A vehicle carrying parts. getUseablePart is what vanilla's own radial menu uses to decide
-- which door the player is stood at: the jar shows it answering nil while the character is
-- in a vehicle, nil on another floor, nil beyond six tiles, and otherwise the nearest part
-- that has an area. Distance is not modelled here, so a spec says which part is the useable
-- one; the rule that is modelled is the one our code depends on, that sitting in a vehicle
-- answers nil.
function Harness.NewVehicle(Values)
	Values = Values or {}

	local Vehicle = {}
	Vehicle.Class = "BaseVehicle"
	Vehicle.Parts = {}
	Vehicle.DoorsTransmitted = 0
	Vehicle.ModDataTransmitted = 0
	Vehicle.PartSounds = {}
	Vehicle.Square = Values.Square

	function Vehicle:getSquare() return self.Square end

	function Vehicle:addPart(Part)
		Part.Vehicle = self
		table.insert(self.Parts, Part)
		if not self.Useable then self.Useable = Part end
		return Part
	end

	function Vehicle:getUseablePart(Character)
		if Character and Character.getVehicle and Character:getVehicle() then return nil end
		return self.Useable
	end

	function Vehicle:getPartById(Id)
		for _, Part in ipairs(self.Parts) do
			if Part:getId() == Id then return Part end
		end
		return nil
	end

	-- The two sync calls. Counted rather than performed, since there is no wire here, but
	-- counted so a spec can prove a client is not keeping an unlocked car to itself.
	function Vehicle:transmitPartDoor(_Part) self.DoorsTransmitted = self.DoorsTransmitted + 1 end
	function Vehicle:transmitPartModData(_Part) self.ModDataTransmitted = self.ModDataTransmitted + 1 end

	function Vehicle:playPartSound(_Part, _Character, Name)
		table.insert(self.PartSounds, Name)
	end

	return Vehicle
end

-- A vehicle with one locked door on it, which is what nearly every spec here wants.
function Harness.NewLockedVehicle(Values)
	Values = Values or {}

	local Vehicle = Harness.NewVehicle(Values)
	Vehicle:addPart(Harness.NewVehiclePart(Values.PartId or "DoorFrontLeft", Values))
	Vehicle.Square = Values.Square or Harness.NewObjectSquare(0, 0, 0, {})

	return Vehicle
end

-- Walking to a part of a vehicle. Vanilla queues this before anything that works on a part,
-- and it is the only thing in the queue that is not ours, so a spec can count past it.
ISPathFindAction = ISPathFindAction or {}

function ISPathFindAction:pathToVehicleArea(Character, Vehicle, AreaId)
	local Action = {}
	Action.Class = "ISPathFindAction"
	Action.character = Character
	Action.vehicle = Vehicle
	Action.area = AreaId

	return Action
end

-- A square with special objects on it, which is what LoadGridsquare hands out. Def is
-- the building this square belongs to, or nil for a square standing outside one.
function Harness.NewAlarmSquare(Def, Objects, Vehicle)
	local Square = {}
	Square.Objects = Objects or {}

	function Square:getBuildingDef() return Def end
	function Square:getVehicleContainer() return Vehicle end

	function Square:getSpecialObjects()
		local List = {}
		function List:size() return #Square.Objects end
		function List:get(Index) return Square.Objects[Index + 1] end
		return List
	end

	return Square
end

--// Alarm Vehicles
-- Values: Open, Missing. Missing models a window smashed out or a door taken off, which
-- the game shows as the part having no inventory item on it.
--
-- Named for the alarm rather than for vehicles in general, because it is not a vehicle part:
-- it answers three questions and nothing else. It shared the name NewVehiclePart with the
-- fuller builder above until the two collided, the later definition winning in silence and
-- taking every method the other one had.
function Harness.NewAlarmVehiclePart(Kind, Values)
	Values = Values or {}

	local Openable = {}
	function Openable:isOpen() return Values.Open and true or false end

	local Part = {}
	function Part:getWindow() return Kind == "window" and Openable or nil end
	function Part:getDoor() return Kind == "door" and Openable or nil end
	function Part:getInventoryItem() return (not Values.Missing) and Openable or nil end

	return Part
end

-- getParts() hands back a VehicleParts, and that class is not on LuaManager's exposed
-- list, so lua cannot call anything on it: every access throws "attempted index: size of
-- non-table". This stub used to answer size() and get() on it, which is precisely why a
-- crash shipped with the suite green, so it now throws the way the game does.
--
-- The working route is getPartCount and getPartByIndex. They are default methods on the
-- VehiclePartOwner interface rather than members of BaseVehicle, which is why they do not
-- appear against the class and why they were once taken for removed. Vanilla's own lua
-- uses them, in ISInventoryPage.lua:1583 among others.
function Harness.NewAlarmVehicle(Values, Parts)
	Values = Values or {}

	local Opaque = setmetatable({}, {
		__index = function(_, Key)
			error("attempted index: " .. tostring(Key) .. " of non-table: VehicleParts")
		end,
	})

	local Vehicle = {}
	Vehicle.Alarmed = Values.Alarmed ~= false

	function Vehicle:getParts() return Opaque end
	function Vehicle:getPartCount() return #(Parts or {}) end
	function Vehicle:getPartByIndex(Index) return (Parts or {})[Index + 1] end
	function Vehicle:isAlarmed() return self.Alarmed end
	function Vehicle:setAlarmed(Value) self.Alarmed = Value and true or false end

	function Vehicle:areAllDoorsLocked()
		return Values.DoorsLocked ~= false
	end

	function Vehicle:isTrunkLocked()
		return Values.TrunkLocked ~= false
	end

	return Vehicle
end

-- Anything else on the square, so a spec can prove a right click that lands on a wall
-- or a sign still finds the pump beside it. Coordinates default to the origin, and a
-- spec that cares about neighbours states them.
function Harness.NewSceneryWith(Neighbours, X, Y, Z)
	local Square = Harness.NewObjectSquare(X or 0, Y or 0, Z or 0, Neighbours or {})

	local Object = {}
	Object.Class = "IsoObject"
	function Object:getSquare() return Square end

	return Object
end

--// Timed Actions
-- Queued actions are recorded rather than run. A spec performs them by hand so it can
-- check the state before and after.
Harness.ActionQueue = {}

ISTimedActionQueue = {}

function ISTimedActionQueue.add(Action)
	table.insert(Harness.ActionQueue, Action)
	return Action
end

-- Moving an item between containers, which is a queued action rather than something that
-- happens on the spot. Anything using an item out of a bag has to put it in the player's
-- own inventory first, because that is where the game expects a held item to be.
ISInventoryTransferUtil = ISInventoryTransferUtil or {}

function ISInventoryTransferUtil.newInventoryTransferAction(_Character, Item, From, To)
	local Action = {}
	Action.Class = "ISInventoryTransferAction"
	Action.item = Item
	Action.srcContainer = From
	Action.destContainer = To

	function Action:isValid() return self.item ~= nil end

	function Action:perform()
		for Index, Held in ipairs(self.srcContainer.Items) do
			if Held == self.item then table.remove(self.srcContainer.Items, Index) break end
		end

		table.insert(self.destContainer.Items, self.item)
		self.item.Container = self.destContainer
	end

	return Action
end

-- luautils.haveToBeTransfered: true when the item is not already in the character's own
-- inventory, so it has to be fetched out of whatever bag is holding it.
luautils = luautils or {}

function luautils.haveToBeTransfered(Character, Item)
	local Container = Item.getContainer and Item:getContainer()
	return Container ~= nil and Container ~= Character:getInventory()
end

ISWorldObjectContextMenu = ISWorldObjectContextMenu or {}

function ISWorldObjectContextMenu.transferIfNeeded(Character, Item)
	if not luautils.haveToBeTransfered(Character, Item) then return end

	ISTimedActionQueue.add(ISInventoryTransferUtil.newInventoryTransferAction(
		Character, Item, Item:getContainer(), Character:getInventory()))
end

ISBaseTimedAction = {}
ISBaseTimedAction.__index = ISBaseTimedAction

function ISBaseTimedAction:derive(Name)
	local Class = {}
	Class.__index = Class
	Class.Name = Name
	Class.derive = ISBaseTimedAction.derive
	setmetatable(Class, { __index = ISBaseTimedAction })
	return Class
end

function ISBaseTimedAction.new(Class, Character)
	local Action = setmetatable({}, Class)
	Action.character = Character
	return Action
end

function ISBaseTimedAction:perform() self.Performed = true end
function ISBaseTimedAction:stop() self.Stopped = true end
function ISBaseTimedAction:setActionAnim(Name) self.Anim = Name end
function ISBaseTimedAction:getJobDelta() return self.JobDelta or 0 end
function ISBaseTimedAction:setJobDelta(Delta) self.JobDelta = Delta end

-- Vanilla passes either a model name or an item, and either hand may be left alone
function ISBaseTimedAction:setOverrideHandModels(Primary, Secondary)
	self.PrimaryHand = Primary
	self.SecondaryHand = Secondary
end

function ISBaseTimedAction:setOverrideHandModelsString(Primary, Secondary)
	self.PrimaryHandModel = Primary
	self.SecondaryHandModel = Secondary
end

-- An anim node can take more than the action name. The barricade levering ones want a
-- second variable naming the height, and without it the character stands still.
function ISBaseTimedAction:setAnimVariable(Key, Value)
	self.AnimVariables = self.AnimVariables or {}
	self.AnimVariables[Key] = Value
end

--// Skills
-- Perks are java singletons: compared by identity, never by name, and carrying their own
-- id. getType returns the perk itself, which is what lets vanilla call it on a perk it
-- already holds. Built on demand so a spec never has to declare one.
Perks = setmetatable({}, {
	__index = function(Table, Key)
		local Perk = {}

		function Perk:getId() return Key end
		function Perk:getName() return Key end
		function Perk:getType() return Perk end

		rawset(Table, Key, Perk)
		return Perk
	end
})

Harness.Xp = {}

function Harness.ClearXp()
	Harness.Xp = {}
end

-- Mirrors LuaManager.GlobalObject.addXp, which is the reason a mod may award experience
-- from shared code without checking where it is running. On a server it sends a packet,
-- in singleplayer it applies the experience directly, and on a multiplayer client it
-- deliberately does nothing at all, because the server owns the character's skills.
function addXp(Character, Perk, Amount)
	if isClient() then return end
	if Perk == nil then error("addXp was given a nil Perk") end

	Harness.Xp[Perk] = (Harness.Xp[Perk] or 0) + Amount
end

--// Generators
-- Fuel runs zero to ten and getFuelPercentage is fuel times ten, which is the scale the
-- game itself uses. totalPowerUsing is what the generator burns in an in game hour before
-- the GeneratorFuelConsumption sandbox multiplier is applied.
function Harness.NewGenerator(Fuel, PowerUsing, Activated, X, Y, Z)
	local Generator = {}
	Generator.Class = "IsoGenerator"
	Generator.Fuel = Fuel or 10
	Generator.PowerUsing = PowerUsing or 0.1
	Generator.Activated = Activated ~= false

	function Generator:getFuel() return self.Fuel end
	function Generator:getFuelPercentage() return self.Fuel * 10 end
	function Generator:getTotalPowerUsing() return self.PowerUsing end
	function Generator:isActivated() return self.Activated end
	function Generator:getSquare() return self.Square end

	-- The generator's own draw, and the one place the sandbox multiplier is already
	-- folded in: the real one returns 0.02 times GeneratorFuelConsumption.
	function Generator:getBasePowerConsumption()
		local Rate = SandboxVars and tonumber(SandboxVars.GeneratorFuelConsumption)
		return 0.02 * (Rate or 1)
	end

	Generator.Square = Harness.NewGridSquare(X or 100, Y or 100, Z or 0)
	return Generator
end

-- A square that reports where it is and whether it can carry power
function Harness.NewGridSquare(X, Y, Z, Outside, Solid)
	local Square = {}
	Square.Outside = Outside == true
	Square.Solid = Solid ~= false

	function Square:getX() return X end
	function Square:getY() return Y end
	function Square:getZ() return Z end
	function Square:isOutside() return self.Outside end
	function Square:isSolidFloor() return self.Solid end
	function Square:getFloor() return self.Solid and {} or nil end

	return Square
end

IsoUtils = IsoUtils or {}

function IsoUtils.DistanceToSquared(X1, Y1, X2, Y2)
	local DX = X1 - X2
	local DY = Y1 - Y2
	return (DX * DX) + (DY * DY)
end

-- Every highlight drawn this frame, so a spec can count the area covered and read back
-- the colour the generator's state chose.
Harness.Highlights = {}

function Harness.ClearHighlights()
	Harness.Highlights = {}
end

function addAreaHighlight(X, Y, X2, Y2, Z, R, G, B, A)
	table.insert(Harness.Highlights, { X = X, Y = Y, Z = Z, R = R, G = G, B = B, A = A })
end

-- Mirrors the parts of build 42's ISGeneratorInfoWindow the compendium touches. getRichText
-- is a plain function rather than a method, which is how vanilla declares it.
ISGeneratorInfoWindow = {}
ISGeneratorInfoWindow.__index = ISGeneratorInfoWindow

function ISGeneratorInfoWindow.getRichText(Object, DisplayStats)
	if not DisplayStats then return " <INDENT:10> " end
	return "Fuel: " .. tostring(math.ceil(Object:getFuelPercentage())) .. "% <LINE> Condition: 100"
end

function ISGeneratorInfoWindow:prerender() self.VanillaPrerenders = (self.VanillaPrerenders or 0) + 1 end
function ISGeneratorInfoWindow:setVisible(Visible) self.Visible = Visible end
function ISGeneratorInfoWindow:removeFromUIManager() self.Removed = true end

function Harness.NewGeneratorWindow(Generator)
	local Window = setmetatable({}, ISGeneratorInfoWindow)
	Window.object = Generator
	return Window
end

--// Experience
-- getPerkBoost is the profession and trait boost level, 0 to 3, and is what the skills
-- tooltip and the character creation screen both report.
function Harness.NewXp(Boosts)
	local Xp = {}
	function Xp:getPerkBoost(Perk) return Boosts[Perk] or 0 end
	function Xp:getMultiplier() return 0 end
	return Xp
end

-- Mirrors the tail of build 42's ISSkillProgressBar:updateTooltip, which is the part the
-- compendium rewrites. Vanilla appends the boost line for levels one to three and nothing
-- at all otherwise, and does not exclude Fitness or Strength here even though the game
-- gives them nothing for the second and third.
ISSkillProgressBar = {}
ISSkillProgressBar.__index = ISSkillProgressBar

function ISSkillProgressBar:updateTooltip()
	self.VanillaUpdates = (self.VanillaUpdates or 0) + 1
	self.message = self.perk:getName() .. " level 1"

	local Boost = self.char:getXp():getPerkBoost(self.perk:getType())
	local Percent = nil
	if Boost == 1 then Percent = "75%"
	elseif Boost == 2 then Percent = "100%"
	elseif Boost == 3 then Percent = "125%" end

	if Percent then
		self.message = self.message .. " <LINE> " .. getText("IGUI_XP_tooltipxpboost", Percent)
	end
end

function Harness.NewSkillBar(Perk, Boost, Player)
	Player = Player or Harness.NewPlayer(0, true)
	Player.Xp = Harness.NewXp({ [Perk] = Boost or 0 })
	function Player:getXp() return self.Xp end

	local Bar = setmetatable({}, ISSkillProgressBar)
	Bar.char = Player
	Bar.perk = Perk

	return Bar
end

-- Mirrors CharacterCreationProfession:drawXpBoostMap, which draws the same number through
-- one right aligned call. Vanilla already leaves Fitness and Strength out here.
CharacterCreationProfession = {}
CharacterCreationProfession.__index = CharacterCreationProfession

function CharacterCreationProfession:drawXpBoostMap(Y, Item)
	self.VanillaDraws = (self.VanillaDraws or 0) + 1

	local Level = Item.item.level
	local Percent = "+ 75%"
	if Level == 2 then Percent = "+ 100%"
	elseif Level >= 3 then Percent = "+ 125%" end

	if Item.item.perk ~= Perks.Fitness and Item.item.perk ~= Perks.Strength then
		self:drawTextRight(Percent, 0, Y)
	end

	return Y + 20
end

function Harness.NewCreationScreen()
	local Screen = setmetatable({}, CharacterCreationProfession)
	Screen.Drawn = {}

	function Screen:drawTextRight(Text) table.insert(self.Drawn, Text) end

	return Screen
end

--// Handcraft Action
-- Mirrors media\lua\shared\Entity\TimedActions\ISHandcraftAction.lua. Only the two
-- methods the compendium wraps are reproduced.
--
-- performRecipe is where vanilla actually executes a recipe. It is called from perform in
-- singleplayer and from complete on a server, which is why a mod hooks it rather than
-- either of those and gets the authoritative side for free.
--
-- getDuration returns craftRecipe:getTime(character) * 5. The real getTime shortens a
-- craft by a twentieth of its base time per skill level above the requirement, but only
-- for skills the recipe names in SkillRequired or xpAward. Ripping names none, so it
-- returns the flat script time however good the character is, which is what the stub
-- reproduces and what the compendium is here to change.
local function NewHandcraftLogic(Data)
	local Logic = {}
	function Logic:getRecipeData() return Data end
	return Logic
end

function Harness.NewCraftRecipe(Name, Time)
	local Recipe = {}
	function Recipe:getName() return Name end
	function Recipe:getTime() return Time or 80 end
	return Recipe
end

ISHandcraftAction = ISBaseTimedAction:derive("ISHandcraftAction")

function ISHandcraftAction:performRecipe()
	self.VanillaPerforms = (self.VanillaPerforms or 0) + 1

	local Data = self.logic and self.logic:getRecipeData()
	if Data and Data.Destroy then Data:Destroy() end
end

function ISHandcraftAction:getDuration()
	if self.character:isTimedActionInstant() then return 1 end
	if not self.craftRecipe then return -1 end

	return self.craftRecipe:getTime(self.character) * 5
end

function Harness.NewHandcraftAction(Character, Recipe, Data)
	local Action = ISBaseTimedAction.new(ISHandcraftAction, Character)
	Action.character = Character
	Action.craftRecipe = Recipe
	Action.logic = NewHandcraftLogic(Data)

	return Action
end

--// Context Menus
-- Records what a mod added, so a spec can find an option by name and click it.
-- Options live on a lowercase "options" because that is the field vanilla uses, and mods
-- that adjust an entry vanilla added have to walk it by that name. Click dispatches the
-- way ISContextMenu really does, target first and then the parameters.
local function NewContextMenu()
	local Menu = {}
	Menu.options = {}

	-- Vanilla carries ten parameters, and a submenu entry with a handful of arguments is
	-- ordinary rather than exotic, so all ten are kept and dispatched.
	function Menu:addOption(Name, Target, Handler, P1, P2, P3, P4, P5, P6, P7, P8, P9, P10)
		local Option = {
			name = Name, target = Target, onSelect = Handler,
			param1 = P1, param2 = P2, param3 = P3, param4 = P4, param5 = P5,
			param6 = P6, param7 = P7, param8 = P8, param9 = P9, param10 = P10
		}

		function Option:Click()
			if self.notAvailable or not self.onSelect then return end
			self.onSelect(self.target, self.param1, self.param2, self.param3, self.param4,
				self.param5, self.param6, self.param7, self.param8, self.param9, self.param10)
		end

		table.insert(self.options, Option)
		return Option
	end

	function Menu:addSubMenu(Option, Sub) Option.SubMenu = Sub end
	function Menu:addGetUpOption(Name, Target, Handler) return self:addOption(Name, Target, Handler) end

	function Menu:Find(Name)
		for _, Option in ipairs(self.options) do
			if Option.name == Name then return Option end
		end
		return nil
	end

	return Menu
end

Harness.NewContextMenu = NewContextMenu

ISContextMenu = {}
function ISContextMenu:getNew() return NewContextMenu() end

Metabolics = setmetatable({}, { __index = function(T, K) rawset(T, K, K) return K end })

-- A fresh item from its full type, which is how anything spawns one out of thin air.
--
-- Id zero, because that is what a freshly created item carries. InventoryItem.id is written
-- in three places in the jar, load, setID and createCloneItem, and none of them runs here.
-- Items a spec builds through NewInventoryItem keep a distinct id, standing in for things
-- that came out of a save or off the ground, which have been given one.
function instanceItem(FullType)
	local Item = Harness.NewInventoryItem((FullType or "Base.Thing"):match("[^.]+$"))
	Item.FullType = FullType
	Item.Id = 0
	return Item
end
CharacterActionAnims = setmetatable({}, { __index = function(T, K) rawset(T, K, K) return K end })

--// Transfers
-- Queued rather than performed, so a spec can count what would move and where to.
Harness.Transfers = {}

function Harness.ClearTransfers()
	Harness.Transfers = {}
end

ISInventoryTransferAction = {}

function ISInventoryTransferAction:new(Character, Item, From, To)
	local Action = { character = Character, item = Item, from = From, to = To }
	table.insert(Harness.Transfers, Action)
	return Action
end

-- Vanilla walks to a container once before the first transfer and gives up if it cannot
Harness.CanWalk = true

luautils = luautils or {}

function luautils.walkToContainer(_Container, _PlayerNum)
	return Harness.CanWalk
end

-- A stack as the inventory pane hands one over: a display copy at index one and the real
-- items after it. Anything reading the count has to allow for that.
function Harness.NewStack(Container, Count, Name)
	local Stack = { items = {} }
	table.insert(Stack.items, Harness.NewInventoryItem(Name or "Nail"))

	for _ = 1, Count do
		local Item = Harness.NewInventoryItem(Name or "Nail")
		Item.Container = Container
		function Item:getContainer() return self.Container end
		table.insert(Stack.items, Item)
	end

	return Stack
end

ISInventoryPane = ISInventoryPane or {}

-- Flattens whatever the pane selected into real items, stacks included
function ISInventoryPane.getActualItems(Items)
	local Actual = {}

	for _, Entry in ipairs(Items) do
		if type(Entry) == "table" and type(Entry.items) == "table" then
			for Index = 2, #Entry.items do table.insert(Actual, Entry.items[Index]) end
		else
			table.insert(Actual, Entry)
		end
	end

	return Actual
end

-- Enough of the text box to open it, read what was typed and press its button
ISTextBox = {}
ISTextBox.__index = ISTextBox

function ISTextBox:new(_X, _Y, _W, _H, Text, _Default, Target, OnClick, PlayerNum, P1, P2, P3)
	local Box = setmetatable({}, ISTextBox)
	Box.title = Text
	Box.target = Target
	Box.onclick = OnClick
	Box.player = PlayerNum
	Box.param1, Box.param2, Box.param3 = P1, P2, P3
	Box.Typed = ""

	Box.entry = {}
	function Box.entry:getText() return Box.Typed end
	function Box.entry:focus() Box.Focused = true end

	local Ok = { internal = "OK" }
	function Ok:triggerClick() Box:Confirm() end
	Box.children = { Ok }

	function Box:initialise() end
	function Box:addToUIManager() Harness.OpenBox = self end

	-- The real one calls onclick(target, button, param1, param2, param3, param4)
	function Box:Confirm()
		self.onclick(self.target, { internal = "OK", parent = self },
			self.param1, self.param2, self.param3)
	end

	function Box:Type(Value)
		self.Typed = tostring(Value)
		return self
	end

	return Box
end

JoypadState = { players = {} }

function setJoypadFocus() end

-- An item with the properties the duplicate reordering sorts on. Only the ones a spec
-- states are readable, so asking for the wrong one on the wrong item type errors here the
-- same way it would in game.
function Harness.NewSortable(Kind, Values)
	local Item = Harness.NewInventoryItem(Values.Name or "Knife")
	Values = Values or {}

	function Item:IsWeapon() return Kind == "weapon" end
	function Item:IsDrainable() return Kind == "drainable" end
	function Item:IsClothing() return Kind == "clothing" end
	function Item:IsFood() return Kind == "food" end
	function Item:IsInventoryContainer() return Kind == "bag" end
	function Item:getBloodClothingType() return Values.BloodClothing and {} or nil end

	-- Condition and blood level sit on InventoryItem, so every item answers them whatever
	-- it is. The rest belong to a subclass and are only present on that kind, which is
	-- what makes reading the wrong one fail here as it would in game.
	function Item:getCondition() return Values.Condition or 0 end
	function Item:getBloodLevel() return Values.Blood or 0 end

	if Values.Remaining then function Item:getCurrentUsesFloat() return Values.Remaining end end
	if Values.Hunger then function Item:getHungerChange() return Values.Hunger end end
	if Values.Calories then function Item:getCalories() return Values.Calories end end
	if Values.Dirt then function Item:getDirtiness() return Values.Dirt end end

	Item.Packaged = Values.Packaged == true
	function Item:isPackaged() return self.Packaged end

	return Item
end

-- The two windows every transfer reads: the character's own inventory as the destination
-- for grabbing, and whatever is in the loot window as the destination for putting.
function Harness.SetupTransferWindows(PlayerNum)
	PlayerNum = PlayerNum or 0

	local Player = Harness.Players[PlayerNum] or Harness.NewPlayer(PlayerNum, true)
	local Loot = Harness.NewContainer("crate")

	Harness.Pages[PlayerNum .. ":inventory"] = { inventory = Player.Inventory }
	Harness.Pages[PlayerNum .. ":loot"] = { inventory = Loot, title = "Crate" }

	Harness.ClearTransfers()
	return Player, Loot
end

--// Literature
-- SkillBook maps the skill a book teaches to the perk that skill trains. Vanilla builds
-- it in XPSystem_SkillBook.lua and every literature path indexes it without checking, so
-- a skill missing from here throws exactly where the game would.
-- The real table is built key by key in XPSystem_SkillBook.lua and holds exactly these
-- twenty four. Anything else reads nil, which is what tells a caller the item is not a
-- skill book at all, so auto creating entries here would hide that distinction.
SkillBook = {}

for _, Skill in ipairs({
	"Aiming", "Blacksmith", "Butchering", "Carpentry", "Carving", "Cooking",
	"Electricity", "Farming", "FirstAid", "Fishing", "FlintKnapping", "Foraging",
	"Glassmaking", "Husbandry", "LongBlade", "Maintenance", "Masonry", "Mechanics",
	"MetalWelding", "Pottery", "Reloading", "Tailoring", "Tracking", "Trapping"
}) do
	SkillBook[Skill] = { perk = Perks[Skill] or Skill }
end

ISInventoryPane = ISInventoryPane or {}

function ISInventoryPane.getActualUniqueItems(Items)
	local Seen = {}
	local Unique = {}

	for _, Item in ipairs(Items) do
		local Type = Item.getFullType and Item:getFullType()
		if not Type or not Seen[Type] then
			if Type then Seen[Type] = true end
			table.insert(Unique, Item)
		end
	end

	return Unique
end

--// Reading
-- ISReadABook, cut down to what an override needs to sit on top of: the action carries
-- the book, the reader and a job delta, and update is called once a frame. Vanilla's own
-- body advances the item's page count only inside "if not isClient()", which is modelled
-- here because a mod reading that count breaks in multiplayer without it.
ISReadABook = ISBaseTimedAction:derive("ISReadABook")

function ISReadABook:getJobDelta() return self.JobDelta or 0 end

-- Vanilla's perform is what finishes a read: it clears the job bar and puts the item
-- back or consumes it. Recorded rather than reproduced, so a spec can prove an override
-- let it run.
function ISReadABook:perform()
	self.Performed = true
	if self.item and self.item.setJobDelta then self.item:setJobDelta(0) end
	return true
end

-- complete is the half that teaches. Vanilla calls ReadLiterature here, which hands the
-- reader everything in the item's LearnedRecipes, so anything that grants knowledge from
-- a book hooks this rather than perform.
function ISReadABook:complete()
	self.Completed = true
	return true
end

function ISReadABook:update()
	self.Updates = (self.Updates or 0) + 1

	if isClient() then return end

	local Total = self.item and self.item:getNumberOfPages() or 0
	if Total > 0 then
		self.item:setAlreadyReadPages(math.floor(Total * self:getJobDelta()))
	end
end

function Harness.NewReading(Character, Book)
	local Action = ISBaseTimedAction.new(ISReadABook, Character)
	Action.character = Character
	Action.item = Book
	Action.JobDelta = 0

	-- Winds the action forward to the given fraction and runs one update, the way the
	-- queue would each frame.
	function Action:Advance(Delta)
		self.JobDelta = Delta
		self:update()
		return self
	end

	return Action
end

-- A skill book. LvlSkillTrained is the level needed to learn from it, and vanilla refuses
-- to read one more than a single level above the character.
function Harness.NewSkillBook(Skill, LvlSkillTrained, Pages)
	local Book = Harness.NewInventoryItem("Book")
	Book.Skill = Skill or "Carpentry"
	Book.Lvl = LvlSkillTrained or 3
	Book.Pages = Pages or 220

	function Book:getSkillTrained() return self.Skill end
	function Book:getLvlSkillTrained() return self.Lvl end
	function Book:getNumberOfPages() return self.Pages end
	function Book:getAlreadyReadPages() return self.ReadPages or 0 end
	function Book:setAlreadyReadPages(Value) self.ReadPages = Value end
	function Book:getFullType() return "Base.Book" .. self.Skill .. tostring(self.Lvl) end
	function Book:setJobType(Value) self.JobType = Value end
	function Book:setJobDelta(Value) self.JobDelta = Value end

	return Book
end

-- Mirrors the branches of build 42's ISInventoryPaneContextMenu.doLiteratureMenu that the
-- compendium reacts to: a book whose level is out of reach gets a disabled Read carrying
-- the TooComplicated tooltip, and anything else gets a working one. Vanilla's other cases,
-- too dark, pictures, recently read, empty notebooks and the recipe list, are not
-- reproduced, because nothing here touches them.
ISInventoryPaneContextMenu = ISInventoryPaneContextMenu or {}

function ISInventoryPaneContextMenu.addToolTip()
	return { description = "" }
end

function ISInventoryPaneContextMenu.isAnyAllowed(Container, _Items)
	return Container.AllowsItems ~= false
end

function ISInventoryPaneContextMenu.isAllFav(Items)
	for _, Item in ipairs(ISInventoryPane.getActualItems(Items)) do
		if not Item:isFavorite() then return false end
	end
	return true
end

-- Mirrors build 42.20's doGrabMenu. The destination check is the part the original mod's
-- copy predates: anything the target container refuses is not offered at all.
function ISInventoryPaneContextMenu.doGrabMenu(Context, Items, PlayerNum)
	local Destination = getPlayerInventory(PlayerNum).inventory

	for _, Entry in ipairs(Items) do
		if type(Entry) == "table" and type(Entry.items) == "table" then
			if not Destination:isItemAllowed(Entry.items[1]) then
				-- forbidden in the destination container
			elseif #Entry.items > 2 then
				Context:addOption(getText("ContextMenu_Grab_one"), Items, nil, PlayerNum)
				Context:addOption(getText("ContextMenu_Grab_half"), Items, nil, PlayerNum)
				Context:addOption(getText("ContextMenu_Grab_all"), Items, nil, PlayerNum)
			else
				Context:addOption(getText("ContextMenu_Grab"), Items, nil, PlayerNum)
			end
			return
		elseif not Destination:isItemAllowed(Entry) then
			-- forbidden in the destination container
		else
			Context:addOption(getText("ContextMenu_Grab"), Items, nil, PlayerNum)
			return
		end
	end
end

function ISInventoryPaneContextMenu.onLiteratureItems() end

function ISInventoryPaneContextMenu.doLiteratureMenu(Context, Items, PlayerNum)
	local Player = getSpecificPlayer(PlayerNum)

	for _, Item in ipairs(ISInventoryPane.getActualUniqueItems(Items)) do
		if Item.getLvlSkillTrained and Item:getLvlSkillTrained() ~= -1
			and Item:getLvlSkillTrained() > Player:getPerkLevel(SkillBook[Item:getSkillTrained()].perk) + 1 then

			local Nope = Context:addOption(getText("ContextMenu_Read"))
			Nope.notAvailable = true

			local Tooltip = ISInventoryPaneContextMenu.addToolTip()
			Tooltip.description = getText("ContextMenu_TooComplicated")
			Nope.toolTip = Tooltip
			return
		end
	end

	Context:addOption(getText("ContextMenu_Read"), Items,
		ISInventoryPaneContextMenu.onLiteratureItems, PlayerNum)
end

--// Player Windows
-- Keyed "<playerNum>:inventory" and "<playerNum>:loot", which is how a spec decides
-- which of the two windows it is building.
function getPlayerInventory(PlayerNum)
	return Harness.Pages[(PlayerNum or 0) .. ":inventory"]
end

function getPlayerLoot(PlayerNum)
	return Harness.Pages[(PlayerNum or 0) .. ":loot"]
end

function getSpecificPlayer(PlayerNum)
	return Harness.Players[PlayerNum or 0]
end

--// World
-- Squares the world hands out when nothing was registered for that spot. The generator
-- range walks thousands of them, so the default is a plain indoor floor and a spec only
-- states the ones it is about.
Harness.DefaultSquare = { Outside = false, Solid = true }

function getCell()
	local Cell = {}

	function Cell:getGridSquare(X, Y, Z)
		return Harness.Squares[tostring(X) .. "," .. tostring(Y) .. "," .. tostring(Z)]
	end

	-- The real one creates the square if the chunk is loaded and it does not exist yet,
	-- which is how anything scanning an area reaches ground it has never touched
	function Cell:getOrCreateGridSquare(X, Y, Z)
		local Registered = Harness.Squares[tostring(X) .. "," .. tostring(Y) .. "," .. tostring(Z)]
		if Registered then return Registered end

		return Harness.NewGridSquare(X, Y, Z,
			Harness.DefaultSquare.Outside, Harness.DefaultSquare.Solid)
	end

	return Cell
end

-- Registers a square holding one item, which is how the server side ground save is
-- driven in a spec
function Harness.PlaceItemOnGround(X, Y, Z, Item)
	local Objects = {}
	local WorldObject = {}
	function WorldObject:getItem() return Item end
	table.insert(Objects, WorldObject)

	local Square = {}
	function Square:getX() return X end
	function Square:getY() return Y end
	function Square:getZ() return Z end
	function Square:getWorldObjects()
		local List = {}
		function List:size() return #Objects end
		function List:get(Index) return Objects[Index + 1] end
		return List
	end

	Harness.Squares[tostring(X) .. "," .. tostring(Y) .. "," .. tostring(Z)] = Square
	return Square
end

--// Lockpicking
-- The slice of the world a lock feature touches: doors and windows that can be locked,
-- the sounds it makes, the tools it swaps into your hands, and the walk to get there.
Harness.WorldSounds = {}
Harness.Noises = {}
Harness.Modals = {}
Harness.WalkedTo = nil

-- Build 42 resolves a trait a mod defined by name rather than by constant, get taking a
-- ResourceLocation. Anything the base game ships has a constant instead, which TestRunner
-- injects straight from the jar.
Harness.ModTraits = {}

ResourceLocation = {}

function ResourceLocation.of(Text)
	local Namespace, Path = Harness.ResourceLocation(Text)
	return Namespace .. ":" .. Path
end

function CharacterTrait.get(Location)
	if Location == nil then return nil end
	if Harness.ModTraits[Location] == nil then Harness.ModTraits[Location] = Location end

	return Harness.ModTraits[Location]
end

-- A sound the world hears, as opposed to one only the player hears.
local SoundManagerStub = {}

function SoundManagerStub:playUISound(Name)
	table.insert(Harness.UISounds, Name)
end

function SoundManagerStub:PlayWorldSound(Name, _Loop, Square, _Min, _Radius, _Volume, _Walls)
	local Sound = { Name = Name, Square = Square, Stopped = false }
	function Sound:stop() self.Stopped = true end

	table.insert(Harness.WorldSounds, Sound)
	return Sound
end

function getSoundManager() return SoundManagerStub end

-- What draws zombies. Radius and volume both matter to a spec about being quiet.
function addSound(Object, X, Y, Z, Volume, Radius)
	table.insert(Harness.Noises,
		{ Object = Object, X = X, Y = Y, Z = Z, Volume = Volume, Radius = Radius })
end

function luautils.okModal(Text, _Yes)
	table.insert(Harness.Modals, Text)
end

-- Swaps tools into the hands and hands back what was there, which is what lets an action
-- put the character's own weapon back afterwards.
function luautils.equipItems(Character, Primary, Secondary)
	local WasPrimary = Character:getPrimaryHandItem()
	local WasSecondary = Character:getSecondaryHandItem()

	local function Resolve(Wanted)
		if Wanted == nil then return nil end
		if type(Wanted) ~= "string" then return Wanted end

		local Inventory = Character:getInventory()
		return Inventory and Inventory:FindAndReturn(Wanted) or nil
	end

	Character:setPrimaryHandItem(Resolve(Primary))
	Character:setSecondaryHandItem(Resolve(Secondary))

	return WasPrimary, WasSecondary
end

-- The walk succeeds by default. A spec that cares makes it fail, which is how a player
-- being unable to reach the door is reproduced.
Harness.CanWalk = true

function luautils.walkToObject(_Character, Object)
	Harness.WalkedTo = Object
	return Harness.CanWalk
end

function luautils.walkAdjWindowOrDoor(_Character, _Square, Object)
	Harness.WalkedTo = Object
	return Harness.CanWalk
end

function luautils.weaponLowerCondition(Item, _Character, _Damage)
	if not Item then return end
	Item.Condition = (Item.Condition or 10) - 1
end

-- Values: Open, Locked, LockedByKey, Exterior, Barricaded, KeyId. Doors and windows share
-- most of their surface, so one factory covers both and the class name decides which.
local function NewLockable(Class, Values)
	Values = Values or {}

	local Object = {}
	Object.Class = Class
	Object.ModData = {}
	Object.KeyId = Values.KeyId or 1
	Object.Locked = Values.Locked ~= false
	Object.Opened = Values.Open and true or false
	Object.Toggles = 0
	Object.Refused = 0
	Object.Syncs = 0
	Object.Hits = 0

	-- Inside and Outside say whether each side of the door is in a building. A front door
	-- has one of each; an interior door has a building on both sides.
	local function NewSide(InBuilding)
		local Side = Harness.NewObjectSquare(0, 0, 0, {})
		function Side:getBuilding() return InBuilding and { Def = true } or nil end
		return Side
	end

	-- Exterior says which shape of door this is. A front door has a building on one side
	-- only; an interior door has one on both, which is what makes it not a way in.
	local Interior = Values.Exterior == false
	local Near = NewSide(true)
	local Far = NewSide(Interior)

	function Object:getModData() return self.ModData end
	function Object:getSquare() return Values.Square or Near end
	function Object:getOppositeSquare() return Far end
	function Object:IsOpen() return self.Opened end
	function Object:isLocked() return self.Locked end
	function Object:setIsLocked(Value) self.Locked = Value and true or false end
	function Object:setLocked(Value) self.Locked = Value and true or false end
	function Object:isBarricaded() return Values.Barricaded and true or false end
	function Object:getKeyId() return self.KeyId end
	function Object:setKeyId(Value) self.KeyId = Value end

	if Class == "IsoDoor" then
		function Object:isLockedByKey() return Values.LockedByKey ~= false end
		function Object:setLockedByKey(Value) Values.LockedByKey = Value and true or false end
		-- The game's own rule, which is narrower than the name suggests: this square
		-- flagged exterior and a building on the far side.
		function Object:isExterior()
			if Values.Exterior == nil then return false end
			return Values.Exterior and true or false
		end

		-- Transcribed from the jar rather than summarised, because the difference between
		-- these two is the whole of a bug that shipped.
		--
		-- ToggleDoorSilent bails on a barricade, flips open on this one object, swaps this
		-- one object's sprite, and stops. It does not clear the lock, it does not sync,
		-- and it has never heard of a door that spans more than one tile.
		function Object:ToggleDoorSilent()
			if Values.Barricaded then return end

			self.Opened = not self.Opened
			self.Toggles = self.Toggles + 1
		end

		-- ToggleDoor is one line forwarding to ToggleDoorActual, which is where everything
		-- else lives. Modelled here down to the part that produces the symptom: for a
		-- garage door it reaches toggleGarageDoor, which walks the run with
		-- getGarageDoorPrev and getGarageDoorNext and hands each segment to
		-- toggleGarageDoorObject. That flips each segment from its OWN open state rather
		-- than from the run's, and clears each one's lock, and then the run syncs once.
		--
		-- So a run left out of step stays out of step and flip flops, which is exactly
		-- what a player sees when something opened one segment on its own.
		function Object:ToggleDoor(Character)
			if Character == nil then return end
			if Values.Barricaded then return end

			-- The locked branch of ToggleDoorActual: still locked, still shut, no key, so
			-- it rattles and returns without moving.
			if self.Locked and not self.Opened then
				self.Refused = self.Refused + 1
				return
			end

			for _, Segment in ipairs(self.Run or { self }) do
				Segment.Opened = not Segment.Opened
				Segment.Toggles = Segment.Toggles + 1
				Segment:setIsLocked(false)
				Segment:setLockedByKey(false)
			end

			self.Syncs = self.Syncs + 1
		end
	else
		function Object:isSmashed() return Values.Smashed and true or false end
		function Object:isDestroyed() return Values.Destroyed and true or false end
		function Object:isPermaLocked() return Values.PermaLocked and true or false end
		function Object:setPermaLocked(Value) Values.PermaLocked = Value and true or false end
		function Object:ToggleWindow() self.Opened = true self.Toggles = self.Toggles + 1 end
		function Object:WeaponHit() self.Hits = self.Hits + 1 end
	end

	return Object
end

-- A body on the ground. Not an item in a container: carried it is a grapple, and lying
-- there it is an IsoDeadBody, which is the whole reason butchering one is a world action
-- rather than a recipe.
function Harness.NewDeadBody(Square, Values)
	Values = Values or {}

	local Body = {}
	Body.Class = "IsoDeadBody"
	Body.Removed = false

	function Body:getSquare() return Square end
	function Body:isSkeleton() return Values.Skeleton and true or false end
	function Body:isFemale() return Values.Female and true or false end
	function Body:isZombie() return Values.Zombie ~= false end
	function Body:removeFromWorld() self.Removed = true end
	function Body:removeFromSquare() self.Removed = true end

	if Square and Square.Bodies then table.insert(Square.Bodies, Body) end

	return Body
end

function Harness.NewDoorLock(Values) return NewLockable("IsoDoor", Values) end
function Harness.NewWindowLock(Values) return NewLockable("IsoWindow", Values) end

-- A garage door that spans several tiles, the way a storage unit shutter does. Every
-- segment is its own IsoDoor and they share one run, which is what getGarageDoorPrev and
-- getGarageDoorNext walk. Returns the segments in order; any one of them is what a player
-- would have clicked.
function Harness.NewGarageDoor(Width, Values)
	local Run = {}

	for Index = 1, Width or 3 do
		Run[Index] = NewLockable("IsoDoor", Values)
		Run[Index].Run = Run
	end

	return Run
end

-- A tool, with the condition and door damage a crowbar needs.
function Harness.NewTool(Type, Condition)
	local Item = Harness.NewInventoryItem(Type)
	Item.Condition = Condition or 10
	Item.DoorDamage = 5

	function Item:getType() return Type end
	function Item:getCondition() return self.Condition end
	function Item:setCondition(Value) self.Condition = Value end
	function Item:isBroken() return (self.Condition or 0) <= 0 end
	function Item:getDoorDamage() return self.DoorDamage end
	function Item:setDoorDamage(Value) self.DoorDamage = Value end

	return Item
end
