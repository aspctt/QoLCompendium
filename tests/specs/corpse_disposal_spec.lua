--// Corpse Disposal Spec
--// aspctt - 28.08.2026
--// Butcher a body for flesh, prepare it at Cooking 7, then cure it in salt for three days
--// into meat a pot will accept.
--//
--// Build 42 can burn, bury, throw or campfire a corpse but never get anything back from
--// one. A corpse is still an inventory item here, CorpseMale and CorpseFemale, which is
--// why this is a recipe rather than a ground context menu.

--// Helpers
local SCRIPT = "qolc_corpse_disposal.txt"

local CHAIN = {
	"QolcCorpseFlesh", "QolcPreparedCorpseFlesh",
	"QolcCuringCorpseFlesh", "QolcCuredCorpseFlesh"
}

local function Script()
	return Harness.ReadModScript(SCRIPT)
end

local function Item(Name)
	return Script():match("item " .. Name .. "\n%s*{(.-)\n\t}")
end

local function Block(Name)
	return Script():match("craftRecipe " .. Name .. "\n%s*{(.-)\n\t}")
end

local function Number(Text, Field)
	return tonumber((Text or ""):match(Field .. " = (%-?%d+)"))
end

-- The raw text of a field, decimals and all, so -30.0 and 220.0 compare as written rather
-- than being rounded down to whole numbers by Number above.
local function Value(Text, Field)
	return (Text or ""):match("%s" .. Field .. " = ([^,]+),")
end

local function SetEnabled(Value)
	SandboxVars.QoLC = SandboxVars.QoLC or {}
	SandboxVars.QoLC.CorpseDisposalEnabled = Value
end

--// The Chain
Test("all four stages exist and every one has a name", function()
	for _, Name in ipairs(CHAIN) do
		AssertNotNil(Item(Name), Name .. " should be in the script")
		AssertNotNil(Translations["Base." .. Name], Name .. " needs a display name")
	end
end)

Test("the whole chain composts", function()
	-- The point of butchering rather than burning. IsoCompost.update walks the bin's
	-- contents and ages anything tagged base:iscompostable over getCompostHours, so this
	-- tag is the entire hook. A stage that missed it would be a dead end in the chain.
	for _, Name in ipairs(CHAIN) do
		AssertContains(Item(Name), "Tags = base:iscompostable", Name .. " should compost")
	end
end)

--// Poison
Test("raw flesh is badly poisonous, and preparing it only helps", function()
	-- BodyDamage.JustAteFood adds PoisonPower times the fraction eaten straight to the
	-- POISON stat, which CharacterStat caps at 100. So these are points of a hundred.
	local Raw = Number(Item("QolcCorpseFlesh"), "PoisonPower")
	local Prepared = Number(Item("QolcPreparedCorpseFlesh"), "PoisonPower")

	AssertNotNil(Raw, "raw flesh should carry PoisonPower")
	AssertNotNil(Prepared, "so should the prepared stage")
	AssertTrue(Raw >= 50, "half the poison bar from a whole portion, which is the original's figure")
	AssertTrue(Prepared < Raw, "preparing it should help")
	AssertTrue(Prepared > 0, "but not make it safe")
end)

Test("curing is the only thing that takes the poison out", function()
	-- The whole shape of the feature. If the cured stage kept any poison the chain would
	-- have no payoff, and if the prepared stage lost it the salt would be pointless.
	AssertNil(Number(Item("QolcCuredCorpseFlesh"), "PoisonPower"), "cured meat is not poisonous")
	AssertFalse(string.find(Item("QolcCuredCorpseFlesh"), "Poison = true", 1, true) ~= nil,
		"nor flagged as poison")
end)

--// Curing
Test("cured meat arrives fresh rather than already stale", function()
	-- Reported in game. Food.updateRotting builds the replacement and then calls setAge
	-- with the old item's age, so the cured item is born aged however long curing took.
	-- isFresh is age < offAge, so its fresh window has to start beyond that or it arrives
	-- at the end of its own life.
	local Cures = Number(Item("QolcCuringCorpseFlesh"), "DaysTotallyRotten")
	local Fresh = Number(Item("QolcCuredCorpseFlesh"), "DaysFresh")
	local Rots = Number(Item("QolcCuredCorpseFlesh"), "DaysTotallyRotten")

	AssertNotNil(Cures, "the curing stage needs a clock")
	AssertTrue(Fresh > Cures,
		"cured meat is born aged " .. tostring(Cures) .. " and stops being fresh at "
			.. tostring(Fresh))
	AssertTrue(Rots > Fresh, "and it should have somewhere to rot to after that")
end)

Test("the curing stage carries the cured stage's hunger and nutrition", function()
	-- Reported in game: the cured meat had no eat option at all, raw or cooked.
	--
	-- Food.updateRotting builds the replacement with InventoryItemFactory.CreateItem(String,
	-- Food), which creates the new item from its own script and then overwrites baseHunger,
	-- hungChange, boredom, unhappiness, calories, carbohydrates, lipids and proteins with the
	-- old item's. So the cured meat's own numbers are discarded and the curing stage's are
	-- used in their place. With none declared there every one arrived as zero, and
	-- ISInventoryPaneContextMenu only offers Eat for food whose getHungChange is below zero.
	--
	-- Vanilla mirrors these for the same reason. Icecream and IcecreamMelted carry the same
	-- four nutrition lines and the same -30.0, as do SugarBeetSyrupPot and SugarBeetSugarPot.
	local Curing = Item("QolcCuringCorpseFlesh")
	local Cured = Item("QolcCuredCorpseFlesh")

	local Copied = { "HungerChange", "UnhappyChange", "Calories", "Carbohydrates",
		"Lipids", "Proteins" }

	for _, Field in ipairs(Copied) do
		local Wanted = Value(Cured, Field)
		AssertNotNil(Wanted, "the cured stage should declare " .. Field)
		AssertEquals(Value(Curing, Field), Wanted,
			Field .. " is handed forward from the curing stage, so the two have to match")
	end

	AssertTrue(tonumber(Value(Cured, "HungerChange")) < 0,
		"and it has to be worth eating for the option to appear")
end)

Test("the curing stage turns into the cured one when it rots", function()
	-- The game has no timer running over days except rotting, so ReplaceOnRotten is the
	-- clock. Vanilla melts ice cream this way and turns a sugar beet pot into sugar.
	local Curing = Item("QolcCuringCorpseFlesh")

	AssertContains(Curing, "ReplaceOnRotten = Base.QolcCuredCorpseFlesh", "three days and it is meat")
	AssertNotNil(Number(Curing, "DaysTotallyRotten"), "it needs a clock to run down")
	AssertEquals(Number(Curing, "DaysTotallyRotten"), 3, "three days, as asked")
end)

Test("nothing part way through curing can be eaten", function()
	-- A fistful of salted raw flesh is not a meal and should not be offered as one.
	AssertContains(Item("QolcCuringCorpseFlesh"), "CantEat = true", "it is not food yet")
end)

Test("curing costs salt", function()
	AssertContains(Block("QolcCureCorpseFlesh"), "[Base.Salt]", "salt is what cures it")
end)

Test("the flesh is counted in pieces rather than in hunger", function()
	-- Build 42 counts a food input in hunger, not items: isUsesPartialItem is true for a
	-- base:food item whose HungerChange exceeds one, and the crafting widget then labels it
	-- in Uses. This flesh is worth 25 hunger, so it read as 25 whatever was held.
	--
	-- Destroy, keep and ItemCount each suppress that, so vanilla was always right. Both are
	-- asserted so a replacement crafting menu testing only one still agrees.
	for _, Name in ipairs({ "QolcPrepareCorpseFlesh", "QolcCureCorpseFlesh" }) do
		local Line = Block(Name):match("(item [^\n]*Flesh[^\n]*)")
		AssertNotNil(Line, Name .. " should take flesh")
		AssertContains(Line, "mode:destroy", Name .. " should spend it whole")
		AssertContains(Line, "flags[ItemCount]", Name .. " should say so twice over")
	end
end)

--// The Cured Meat
Test("cured flesh behaves as raw meat rather than as a snack", function()
	-- DangerousUncooked is how the game says raw meat: eating it uncooked makes you ill,
	-- cooking it does not. Steak is the model.
	local Cured = Item("QolcCuredCorpseFlesh")

	AssertContains(Cured, "DangerousUncooked = true", "raw meat, so raw")
	AssertContains(Cured, "IsCookable = true", "and cooking it fixes that")
	AssertContains(Cured, "EvolvedRecipe = ", "a pot has to accept it")
	AssertContains(Cured, "Stew:", "a stew in particular")
end)

--// Butchering
Test("butchering the body is not a recipe, because it could never be one", function()
	-- Reported in game: the entry showed in the crafting screen and nothing ever satisfied
	-- it. A human corpse never reaches a container crafting can see. Carried it is a
	-- grapple, since ISGrabCorpseItem sends only Base.CorpseAnimal to the inventory and
	-- routes a human body through pickUpCorpseItem, which the jar shows refusing while
	-- already grappling. On the ground it is an IsoDeadBody rather than an item on a floor.
	AssertNil(Block("QolcButcherCorpse"), "a recipe naming a corpse can never fire")

	-- The recipe bodies rather than the file, since the header explains the corpse item by
	-- naming it and that is the one place the words belong.
	for Name in string.gmatch(Script(), "craftRecipe (%w+)") do
		AssertFalse(string.find(Block(Name) or "", "Base.Corpse", 1, true) ~= nil,
			Name .. " must not ask for a corpse item")
	end
end)

Test("the world action exists and takes the body apart", function()
	AssertNotNil(QolcButcherCorpseAction, "the action the menu queues must exist")

	local Player = Harness.NewPlayer(0, true)
	local Knife = Harness.NewTool("HuntingKnife")
	Player:getInventory():AddItem(Knife)

	local Square = Harness.NewObjectSquare(0, 0, 0, {})
	local Body = Harness.NewDeadBody(Square)

	QolcButcherCorpseAction:new(Player, Body, Knife, 10):perform()

	AssertTrue(Body.Removed, "the body should be gone")
end)

Test("the flesh is handed over rather than left in the grass", function()
	-- Butchering an animal puts the meat in your hands and this should not behave
	-- differently. Three pieces beside a body you have just removed is easy to walk away
	-- from without noticing.
	local Player = Harness.NewPlayer(0, true)
	local Knife = Harness.NewTool("HuntingKnife")
	Player:getInventory():AddItem(Knife)

	local Square = Harness.NewObjectSquare(0, 0, 0, {})
	QolcButcherCorpseAction:new(Player, Harness.NewDeadBody(Square), Knife, 10):perform()

	local Held = {}
	for _, Item in ipairs(Player:getInventory().Items) do
		if Item.getFullType and Item:getFullType() == "Base.QolcCorpseFlesh" then
			table.insert(Held, Item)
		end
	end

	AssertEquals(#Held, 3, "three pieces, carried")
	AssertEquals(#Square.Dropped, 0, "and nothing left on the ground")
end)

Test("the body is taken off the map the way a corpse is taken off the map", function()
	-- Reported in game alongside the missing experience. A corpse is not an ordinary world
	-- object. IsoGridSquare.removeCorpse sends RemoveCorpseFromMap, from a client up to the
	-- server and from a server out to everyone nearby, reconciles the body's own container
	-- through checkAddedRemovedItems, invalidates the render chunk, does removeFromWorld and
	-- removeFromSquare, and then triggers OnContainerUpdate so the panel redraws.
	--
	-- Calling the last two on their own, which this used to do, skips all of that. Vanilla
	-- removes every carcass through removeCorpse, three times in ButcheringUtil, and the one
	-- place that tried the bare pair has them commented out.
	local Player = Harness.NewPlayer(0, true)
	local Knife = Harness.NewTool("HuntingKnife")
	Player:getInventory():AddItem(Knife)

	local Square = Harness.NewObjectSquare(0, 0, 0, {})
	local Body = Harness.NewDeadBody(Square)

	QolcButcherCorpseAction:new(Player, Body, Knife, 10):perform()

	AssertEquals(Square.CorpsesRemoved, 1, "removeCorpse, once")
	AssertTrue(Square.CorpseSynced, "and told to sync it, which is what false in the second argument means")
	AssertTrue(Body.Removed, "the body should still be gone")
end)

Test("every piece is announced to the container", function()
	-- What vanilla's own butchering does after each AddItem in ButcheringUtil.giveItems. The
	-- global is inert unless this is the server, so it costs nothing where it does not apply.
	local Player = Harness.NewPlayer(0, true)
	local Knife = Harness.NewTool("HuntingKnife")
	Player:getInventory():AddItem(Knife)

	QolcButcherCorpseAction:new(Player, Harness.NewDeadBody(Harness.NewObjectSquare(0, 0, 0, {})),
		Knife, 10):perform()

	AssertEquals(#Harness.SentToContainer, 3, "one per piece")
end)

Test("butchering is worth butchering experience", function()
	-- Asked in game, and the answer was no. Vanilla awards per item taken off a carcass,
	-- through ButcheringUtil.giveItems, at a rate AnimalPartsDefinitions sets per animal: 25
	-- for a deer, 18 for a boar, 10 for a sheep, 7 for a hen. A body is a boar, near enough.
	local Player = Harness.NewPlayer(0, true)
	local Knife = Harness.NewTool("HuntingKnife")
	Player:getInventory():AddItem(Knife)

	QolcButcherCorpseAction:new(Player, Harness.NewDeadBody(Harness.NewObjectSquare(0, 0, 0, {})),
		Knife, 10):perform()

	-- Harness.Xp, because the award goes through the game's own addXp now rather than straight
	-- at the character. That is the whole of the fix: addXp does nothing on a client, so the
	-- award has to happen on the side that owns the skill.
	AssertEquals(Harness.Xp[Perks.Butchering], 54, "three pieces at the boar rate")
end)

Test("no piece is lost to the container refusing a repeated id", function()
	-- Reported in game twice, the second time as meat that could not be dropped or moved.
	--
	-- ItemContainer has two AddItem overloads and they do not behave the same way.
	-- AddItem(InventoryItem) asks containsID first, and if the container already holds an
	-- item carrying that id it logs "Error, container already has id", hands back the one it
	-- already had, and adds nothing. AddItem(String) has no such check.
	--
	-- A freshly created item's id is zero. InventoryItem.id is written in three places in the
	-- jar, load, setID and createCloneItem, and none of them runs when an item is made from a
	-- script. So three fresh pieces handed over by object collide on id zero and two of them
	-- are dropped in silence.
	local Player = Harness.NewPlayer(0, true)
	local Knife = Harness.NewTool("HuntingKnife")
	Player:getInventory():AddItem(Knife)

	QolcButcherCorpseAction:new(Player, Harness.NewDeadBody(Harness.NewObjectSquare(0, 0, 0, {})),
		Knife, 10):perform()

	AssertEquals(Harness.RefusedDuplicateIds or 0, 0,
		"a piece was refused for carrying an id the container already had")

	-- Every piece its own item, rather than the same one counted three times, which is what
	-- the refusing overload hands back.
	local Seen = {}
	for _, Item in ipairs(Player:getInventory().Items) do
		if Item.getFullType and Item:getFullType() == "Base.QolcCorpseFlesh" then
			AssertFalse(Seen[Item], "the same piece should not be in the inventory twice")
			Seen[Item] = true
		end
	end
end)

--// Asking The Server
-- Reported from a self hosted server twice over: the meat could not be dropped or moved, and
-- it was gone again after a reload. Both are one fault. A client that makes an item and puts
-- it in its own inventory has made an item the server never heard of, so every transfer is
-- checked against a server with no such item and refused, and the next handover of the
-- inventory does not contain it.
local function Butcher(Player)
	local Knife = Harness.NewTool("HuntingKnife")
	Player:getInventory():AddItem(Knife)

	QolcButcherCorpseAction:new(Player, Harness.NewDeadBody(Harness.NewObjectSquare(0, 0, 0, {})),
		Knife, 10):perform()
end

local function FleshHeld(Player)
	local Count = 0
	for _, Item in ipairs(Player:getInventory().Items) do
		if Item.getFullType and Item:getFullType() == "Base.QolcCorpseFlesh" then
			Count = Count + 1
		end
	end
	return Count
end

Test("a client asks rather than helping itself", function()
	Harness.IsClient = true

	local Player = Harness.NewPlayer(0, true)
	Butcher(Player)

	AssertEquals(FleshHeld(Player), 0, "a client must not make the flesh itself")

	local Sent = Harness.LastCommand("ButcherCorpse")
	AssertNotNil(Sent, "it should have asked the server instead")
	AssertEquals(Sent.Module, "QoLC", "under our own module")
end)

Test("the request carries nothing, so there is nothing to forge", function()
	-- The count and the item come from the shared file on the server side. A count sent by a
	-- client is a count a client chose.
	Harness.IsClient = true

	local Player = Harness.NewPlayer(0, true)
	Butcher(Player)

	local Sent = Harness.LastCommand("ButcherCorpse")
	AssertNotNil(Sent, "it should have asked")

	local Count = 0
	for _ in pairs(Sent.Request or {}) do Count = Count + 1 end
	AssertEquals(Count, 0, "the request should be empty")
end)

Test("nothing is asked of anyone in singleplayer", function()
	-- There is nobody to ask, so the round trip is skipped and the flesh is handed over on
	-- the spot. The branch exists only to save that trip.
	local Player = Harness.NewPlayer(0, true)
	Butcher(Player)

	AssertEquals(FleshHeld(Player), 3, "three pieces, carried")
	AssertNil(Harness.LastCommand("ButcherCorpse"), "and no command sent")
end)

Test("a client pays itself nothing", function()
	-- Reported in game: butchering experience appeared and went away again a moment later.
	-- Skills belong to the server, and addXp does nothing at all on a client for exactly that
	-- reason, so an award made there is undone by the next sync.
	Harness.ClearXp()
	Harness.IsClient = true

	local Player = Harness.NewPlayer(0, true)
	Butcher(Player)

	AssertEquals(Harness.Xp[Perks.Butchering], nil, "the server pays, not the client")
end)

Test("the experience comes with the flesh", function()
	-- One place, one award. The side that hands over the meat is the side that owns the skill,
	-- so there is no second thing to keep in step with the first.
	SetEnabled(true)
	Harness.ClearXp()

	local Player = Harness.NewPlayer(0, true)
	Harness.Fire("OnClientCommand", "QoLC", "ButcherCorpse", Player, {})

	AssertEquals(Harness.Xp[Perks.Butchering], 54, "paid by the server that gave the flesh")
end)

Test("the server hands over three pieces when a client asks", function()
	SetEnabled(true)

	local Player = Harness.NewPlayer(0, true)

	Harness.Fire("OnClientCommand", "QoLC", "ButcherCorpse", Player, {})

	AssertEquals(FleshHeld(Player), 3, "three pieces, from the side that is allowed to")
end)

Test("the server ignores a command that is not ours", function()
	local Player = Harness.NewPlayer(0, true)

	Harness.Fire("OnClientCommand", "SomeOtherMod", "ButcherCorpse", Player, {})
	Harness.Fire("OnClientCommand", "QoLC", "SomethingElse", Player, {})

	AssertEquals(FleshHeld(Player), 0, "neither of those is ours")
end)

Test("the server refuses when the feature is switched off", function()
	-- A client with the feature on locally, or an older client, should not be able to ask for
	-- flesh on a server that has said no.
	SetEnabled(false)

	local Player = Harness.NewPlayer(0, true)
	Harness.Fire("OnClientCommand", "QoLC", "ButcherCorpse", Player, {})

	AssertEquals(FleshHeld(Player), 0, "off means off on the server too")
end)

Test("both halves name the same command", function()
	-- End to end, because the request and the handler are in different files and a spec that
	-- only checked one of them would not notice them drifting apart.
	SetEnabled(true)
	Harness.IsClient = true

	local Player = Harness.NewPlayer(0, true)
	Butcher(Player)

	local Sent = Harness.LastCommand("ButcherCorpse")
	AssertNotNil(Sent, "it should have asked")

	Harness.IsClient = false

	local Receiver = Harness.NewPlayer(1, true)
	Harness.Fire("OnClientCommand", Sent.Module, Sent.Command, Receiver, Sent.Request)

	AssertEquals(FleshHeld(Receiver), 3, "what was sent is what the server answers to")
end)

Test("a body with no square is refused rather than throwing", function()
	local Player = Harness.NewPlayer(0, true)
	local Knife = Harness.NewTool("HuntingKnife")
	Player:getInventory():AddItem(Knife)

	local Body = Harness.NewDeadBody(nil)
	local Action = QolcButcherCorpseAction:new(Player, Body, Knife, 10)

	AssertFalse(Action:isValid(), "nothing to stand over")
end)

Test("preparing is gated behind Cooking 7", function()
	-- The gate the whole chain hangs on. Below it a body is only ever compost.
	AssertContains(Block("QolcPrepareCorpseFlesh"), "SkillRequired = Cooking:7", "the gate")
	AssertContains(Block("QolcCureCorpseFlesh"), "SkillRequired = Cooking:7", "and it holds for curing")
end)

--// The Switch
Test("the switch is hung on both recipes", function()
	local Count = 0
	for _ in string.gmatch(Script(), "OnTest = Recipe%.OnTest%.QolcCorpseDisposal") do
		Count = Count + 1
	end

	AssertEquals(Count, 2, "both recipes, the butchering being a world action instead")
end)

Test("this one ships off, unlike every other feature here", function()
	-- Everything else in this mod repairs something the base game got wrong. This adds
	-- cannibalism to a game that has none, and turning that on for someone who wanted
	-- their hotbar sorted would be overstepping.
	Harness.ClearSandbox()

	AssertFalse(Recipe.OnTest.QolcCorpseDisposal(nil, nil), "the declared default is off")
	AssertFalse(QOLC_SANDBOX_DEFAULTS["CorpseDisposalEnabled"],
		"and the sandbox file says so too")
end)

Test("on, the recipes are craftable", function()
	SetEnabled(true)

	AssertTrue(Recipe.OnTest.QolcCorpseDisposal(nil, nil), "nothing is refused")
end)

Test("off, every input is refused", function()
	SetEnabled(false)

	AssertFalse(Recipe.OnTest.QolcCorpseDisposal(nil, nil), "off means off")
end)
