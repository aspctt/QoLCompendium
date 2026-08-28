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
