--// Lockpicking Spec
--// aspctt - 18.08.2026

--// Helpers
local PICK_LOCK = "ContextMenu_QoLC_PickLock"
local FORCE_LOCK = "ContextMenu_QoLC_ForceLock"
local FORCE_WINDOW = "ContextMenu_QoLC_ForceWindow"

local PICKING = "QolcMakeLockpickFromHairpin"

-- Knows is a list of what to grant: PICKING is a real recipe, "forcing" is the mod data
-- flag. They are recorded differently because the game refuses to learn a recipe name
-- that matches no recipe, which is what the second volume would otherwise have taught.
local function Burglar(Knows)
	local Player = Harness.NewPlayer(0, true)

	for _, What in ipairs(Knows or { PICKING, "forcing" }) do
		if What == "forcing" then QolcLearnForcing(Player) else Player:learnRecipe(What) end
	end

	Player.Inventory.Items = {
		Harness.NewTool("Screwdriver"), Harness.NewTool("QolcLockpick"), Harness.NewTool("Crowbar")
	}

	return Player
end

-- A finished read of the given item, the way the queue runs one
local function ReadBook(Player, FullType)
	local Book = Harness.NewInventoryItem("Magazine")
	function Book:getFullType() return FullType end
	function Book:getNumberOfPages() return 0 end
	function Book:setJobDelta() end

	local Action = Harness.NewReading(Player, Book)
	Action:complete()
	return Action
end

local function Menu(Player, Objects)
	local Context = Harness.NewContextMenu()
	Harness.Fire("OnFillWorldObjectContextMenu", Player.Number, Context, Objects, false)
	return Context
end

local function Names(Context)
	local Found = {}
	for _, Option in ipairs(Context.options) do table.insert(Found, Option.name) end
	return table.concat(Found, " | ")
end

--// The Menu
Test("a locked exterior door offers both ways in", function()
	local Player = Burglar()
	local Context = Menu(Player, { Harness.NewDoorLock() })

	AssertContains(Names(Context), getText(PICK_LOCK), "picking")
	AssertContains(Names(Context), getText(FORCE_LOCK), "forcing")
end)

Test("the lock's difficulty is shown with the option", function()
	local Player = Burglar()
	local Door = Harness.NewDoorLock()
	Door:getModData().QolcLockLevel = 3

	AssertContains(Names(Menu(Player, { Door })), getText("IGUI_QoLC_LockLevel3"), "medium")
end)

Test("an open door is left alone", function()
	local Player = Burglar()
	AssertEquals(#Menu(Player, { Harness.NewDoorLock({ Open = true }) }).options, 0, "nothing to pick")
end)

Test("an unlocked door is left alone", function()
	local Player = Burglar()
	local Door = Harness.NewDoorLock({ Locked = false, LockedByKey = false })

	AssertEquals(#Menu(Player, { Door }).options, 0, "it already opens")
end)

Test("an interior door is left alone", function()
	local Player = Burglar()
	AssertEquals(#Menu(Player, { Harness.NewDoorLock({ Exterior = false }) }).options, 0,
		"the original only ever offered this on the way in")
end)

Test("a barricaded door is left alone", function()
	local Player = Burglar()
	AssertEquals(#Menu(Player, { Harness.NewDoorLock({ Barricaded = true }) }).options, 0,
		"the lock is the least of it")
end)

--// Tools And Knowing How
Test("picking needs the knowledge, not just the tools", function()
	local Player = Burglar({ "forcing" })
	local Names = Names(Menu(Player, { Harness.NewDoorLock() }))

	AssertTrue(string.find(Names, getText(PICK_LOCK), 1, true) == nil, "not learned yet")
	AssertContains(Names, getText(FORCE_LOCK), "but forcing is")
end)

Test("picking needs both tools", function()
	local Player = Burglar()
	Player.Inventory.Items = { Harness.NewTool("Screwdriver"), Harness.NewTool("Crowbar") }

	local Names = Names(Menu(Player, { Harness.NewDoorLock() }))
	AssertTrue(string.find(Names, getText(PICK_LOCK), 1, true) == nil, "no pick, no picking")
end)

Test("a broken crowbar is no crowbar", function()
	local Player = Burglar()
	Player.Inventory.Items = { Harness.NewTool("Crowbar", 0) }

	AssertEquals(#Menu(Player, { Harness.NewDoorLock() }).options, 0, "worn out")
end)

--// Windows
Test("a locked window offers forcing", function()
	local Player = Burglar()
	AssertContains(Names(Menu(Player, { Harness.NewWindowLock() })), getText(FORCE_WINDOW), "offered")
end)

Test("a window already forced is left alone", function()
	local Player = Burglar()
	local Window = Harness.NewWindowLock({ PermaLocked = true })

	AssertEquals(#Menu(Player, { Window }).options, 0, "the catch is already off")
end)

Test("a smashed window is left alone", function()
	local Player = Burglar()
	AssertEquals(#Menu(Player, { Harness.NewWindowLock({ Smashed = true }) }).options, 0,
		"climb through it")
end)

--// Picking
local function Pick(Player, Door, Level)
	Door:getModData().QolcLockLevel = Level or 1
	Player:setPrimaryHandItem(Harness.NewTool("Screwdriver"))
	Player:setSecondaryHandItem(Harness.NewTool("QolcLockpick"))

	local Action = QolcPickLockAction:new(Player, Door, 10)
	Action:start()
	Action:perform()
	return Action
end

Test("a picked lock opens and pays experience", function()
	local Player = Burglar()
	local Door = Harness.NewDoorLock()

	-- Chance is a one in N roll and N is never below four, so seeding it away from zero
	-- is what makes this the success case rather than the jam
	Harness.SetRandom({ 1, 1, 99 })
	Pick(Player, Door)

	AssertFalse(Door:isLockedByKey(), "the door should be unlocked")
	AssertTrue((Player.Xp or {})[Perks.Lightfoot] ~= nil, "and Lightfoot should have gone up")
end)

Test("a failed pick wrecks the lock for good", function()
	local Player = Burglar()
	local Door = Harness.NewDoorLock()

	Harness.SetRandom({ 0, 1, 99 })
	Pick(Player, Door)

	AssertEquals(Door:getModData().QolcLockLevel, 6, "jammed")
	AssertTrue(Door:getKeyId() < 0, "and its own key is no good either")
end)

Test("a jammed lock cannot be picked again", function()
	local Player = Burglar()
	local Door = Harness.NewDoorLock()
	Door:getModData().QolcLockLevel = 6

	Menu(Player, { Door }):Find(getText(PICK_LOCK) .. " (" .. getText("IGUI_QoLC_LockLevel6") .. ")"):Click()

	AssertEquals(#Harness.Modals, 1, "the character is told, rather than wasting the time")
end)

--// Forcing
Test("forcing a door opens it", function()
	local Player = Burglar()
	local Door = Harness.NewDoorLock()
	Player:setPrimaryHandItem(Harness.NewTool("Crowbar"))

	Harness.SetRandom({ 1 })
	local Action = QolcBreakLockAction:new(Player, Door, 10, nil, nil, false)
	Action:perform()

	AssertTrue(Door:IsOpen(), "the door should be open")
end)

Test("forcing a window opens it and kills the catch", function()
	local Player = Burglar()
	local Window = Harness.NewWindowLock()
	Player:setPrimaryHandItem(Harness.NewTool("Crowbar"))

	Harness.SetRandom({ 1 })
	QolcBreakLockAction:new(Player, Window, 10, nil, nil, true):perform()

	AssertTrue(Window:IsOpen(), "open")
	AssertTrue(Window:isPermaLocked(), "and it can never be locked again")
end)

Test("forcing makes a noise the dead can hear", function()
	local Player = Burglar()
	Player:setPrimaryHandItem(Harness.NewTool("Crowbar"))

	Harness.Noises = {}
	Harness.SetRandom({ 1 })
	QolcBreakLockAction:new(Player, Harness.NewDoorLock(), 10, nil, nil, false):perform()

	AssertEquals(#Harness.Noises, 1, "one noise")
	AssertTrue(Harness.Noises[1].Volume > 0, "and it carries")
end)

Test("failing is louder than succeeding", function()
	local Player = Burglar()
	Player:setPrimaryHandItem(Harness.NewTool("Crowbar"))

	Harness.Noises = {}
	Harness.SetRandom({ 1 })
	QolcBreakLockAction:new(Player, Harness.NewDoorLock(), 10, nil, nil, false):perform()
	local Quiet = Harness.Noises[1].Volume

	Harness.Noises = {}
	Harness.SetRandom({ 0 })
	QolcBreakLockAction:new(Player, Harness.NewDoorLock(), 10, nil, nil, false):perform()

	AssertTrue(Harness.Noises[1].Volume > Quiet, "a bar bouncing off a lock carries further")
end)

--// The Switch
Test("turning it off takes every option away", function()
	SandboxVars.QoLC.LockpickingEnabled = false
	local Player = Burglar()

	AssertEquals(#Menu(Player, { Harness.NewDoorLock() }).options, 0, "off means off")
	AssertEquals(#Menu(Player, { Harness.NewWindowLock() }).options, 0, "windows too")
end)

Test("the switch is a sandbox option", function()
	AssertNotNil(QOLC_SANDBOX_DEFAULTS["LockpickingEnabled"], "server controlled")
end)

--// Learning
Test("a burglar already knows how", function()
	local Player = Harness.NewPlayer(0, true)
	Player:setTrait(CharacterTrait.BURGLAR, true)

	Harness.Fire("OnGameStart")

	AssertTrue(Player:isRecipeActuallyKnown(PICKING), "how to make a pick")
	AssertTrue(QolcKnowsForcing(Player), "and how to force a lock")
end)

Test("anyone else starts knowing nothing", function()
	local Player = Harness.NewPlayer(0, true)
	Harness.Fire("OnGameStart")

	AssertFalse(Player:isRecipeActuallyKnown(PICKING), "no head start without the trait")
	AssertFalse(QolcKnowsForcing(Player), "it has to be learned")
end)

-- Both of these cover the same mistake, made in two places. isRecipeKnown, in the short
-- one argument form, does not answer for this character: it looks the name up as a build
-- 41 recipe, finds nothing because every recipe here is a craftRecipe, and falls through
-- to the SeeNotLearntRecipe sandbox option, which is on by default. It said yes to
-- everyone. Guarding learnRecipe with it meant a burglar was never taught anything, and
-- gating the menu on it meant the first volume taught nothing you could notice.
Test("a burglar is taught even while the sandbox says every recipe is known", function()
	SandboxVars.SeeNotLearntRecipe = true

	local Player = Harness.NewPlayer(0, true)
	Player:setTrait(CharacterTrait.BURGLAR, true)

	Harness.Fire("OnGameStart")

	AssertTrue(Player:isRecipeActuallyKnown(PICKING), "learned for real, not merely visible")
end)

Test("picking a lock needs the first volume, whatever that sandbox option says", function()
	SandboxVars.SeeNotLearntRecipe = true

	local Player = Burglar({ "forcing" })
	local Names = Names(Menu(Player, { Harness.NewDoorLock() }))

	AssertTrue(string.find(Names, getText(PICK_LOCK), 1, true) == nil,
		"the tools are in the bag, the knowledge is not")
end)

--// Reading The Second Volume
-- The gap that let a broken feature reach a player: every test here covered the burglar's
-- head start, and none of them read the book the rest of us have to find.
Test("reading the second volume teaches forcing", function()
	local Player = Harness.NewPlayer(0, true)
	AssertFalse(QolcKnowsForcing(Player), "should not know it to begin with")

	ReadBook(Player, "Base.QolcLockpickBook2")
	AssertTrue(QolcKnowsForcing(Player), "reading it should be enough")
end)

Test("the character mentions learning it", function()
	local Player = Harness.NewPlayer(0, true)
	ReadBook(Player, "Base.QolcLockpickBook2")

	AssertEquals(#Player.Said, 1, "one line on learning it")
end)

Test("reading it twice says nothing the second time", function()
	local Player = Harness.NewPlayer(0, true)
	ReadBook(Player, "Base.QolcLockpickBook2")
	ReadBook(Player, "Base.QolcLockpickBook2")

	AssertEquals(#Player.Said, 1, "there is nothing new to learn")
end)

Test("reading anything else teaches nothing", function()
	local Player = Harness.NewPlayer(0, true)
	ReadBook(Player, "Base.CookingMag1")

	AssertFalse(QolcKnowsForcing(Player), "only the second volume teaches this")
end)

Test("a door offers forcing once the book is read", function()
	-- End to end, because the two halves record and read the same flag and a spec that
	-- only checks one of them would not notice them drifting apart
	local Player = Burglar({ PICKING })
	AssertEquals(#Menu(Player, { Harness.NewDoorLock() }).options, 1, "only picking so far")

	ReadBook(Player, "Base.QolcLockpickBook2")
	AssertContains(Names(Menu(Player, { Harness.NewDoorLock() })), getText(FORCE_LOCK), "now offered")
end)

--// Labels
Test("every label resolves", function()
	local Keys = {
		PICK_LOCK, FORCE_LOCK, FORCE_WINDOW,
		"IGUI_QoLC_LockJammed", "IGUI_QoLC_PickStuck", "IGUI_QoLC_PickBroken",
		"IGUI_QoLC_LearnedForcing",
		"Sandbox_QoLC_LockpickingEnabled", "Sandbox_QoLC_LockpickingEnabled_tooltip",
		"Base.QolcLockpick", "Base.QolcLockpickBook1", "Base.QolcLockpickBook2"
	}

	for _, Key in ipairs(Keys) do
		AssertNotNil(Translations[Key], "missing translation for " .. Key)
	end

	for Level = 1, 6 do
		AssertNotNil(Translations["IGUI_QoLC_LockLevel" .. Level], "lock level " .. Level)
	end
end)

--// The Crowbar Animation
Test("forcing plays the levering animation, not a generic one", function()
	local Player = Burglar()
	Player:setPrimaryHandItem(Harness.NewTool("Crowbar"))

	local Action = QolcBreakLockAction:new(Player, Harness.NewDoorLock(), 10, nil, nil, false)
	Action:start()

	-- The node takes two conditions. Setting only the action name plays nothing at all.
	AssertEquals(Action.Anim, "RemoveBarricade", "vanilla's own levering action")
	AssertEquals((Action.AnimVariables or {})["RemoveBarricade"], "CrowbarMid", "at door height")
end)

Test("a window is levered at the higher position", function()
	local Player = Burglar()
	Player:setPrimaryHandItem(Harness.NewTool("Crowbar"))

	local Action = QolcBreakLockAction:new(Player, Harness.NewWindowLock(), 10, nil, nil, true)
	Action:start()

	AssertEquals((Action.AnimVariables or {})["RemoveBarricade"], "CrowbarHigh", "a latch sits higher")
end)

Test("the crowbar is in hand while forcing", function()
	local Player = Burglar()
	Player:setPrimaryHandItem(Harness.NewTool("Crowbar"))

	local Action = QolcBreakLockAction:new(Player, Harness.NewDoorLock(), 10, nil, nil, false)
	Action:start()

	AssertEquals(Action.PrimaryHandModel, "Crowbar", "levering an empty hand looks wrong")
end)

--// The Burglar's Head Start
Test("a burglar is granted the recipes when the player is created", function()
	-- OnGameStart alone was not enough. For a character made moments earlier it can run
	-- before the profession's traits are on them, and the grant then finds no burglar.
	local Player = Harness.NewPlayer(0, true)
	Player:setTrait(CharacterTrait.BURGLAR, true)

	Harness.Fire("OnCreatePlayer", 0, Player)

	AssertTrue(Player:isRecipeActuallyKnown(PICKING), "how to make a pick")
	AssertTrue(QolcKnowsForcing(Player), "and how to force a lock")
end)

Test("a burglar is granted them on a new game too", function()
	local Player = Harness.NewPlayer(0, true)
	Player:setTrait(CharacterTrait.BURGLAR, true)

	Harness.Fire("OnNewGame", Player)

	AssertTrue(Player:isRecipeActuallyKnown(PICKING), "how to make a pick")
end)

Test("granting twice leaves one of each", function()
	local Player = Harness.NewPlayer(0, true)
	Player:setTrait(CharacterTrait.BURGLAR, true)

	Harness.Fire("OnGameStart")
	Harness.Fire("OnCreatePlayer", 0, Player)
	Harness.Fire("OnNewGame", Player)

	AssertTrue(QolcKnowsForcing(Player), "still known, and nothing threw on the way")
end)

--// Where The Hairpin Comes From
-- The one thing this feature adds that has to be found rather than made. Build 42 has no
-- hairpin of its own, so without a home in the loot tables the recipe that turns one into
-- a lockpick could never be run.
local HAIRPIN = "Base.QolcHairpin"
local HAIRPIN_TABLES = 19

local function Register()
	Harness.Fire("OnPreDistributionMerge")
end

local function Weight(Name)
	return Harness.LootWeight(ProceduralDistributions.list[Name], HAIRPIN)
end

Test("a hairpin turns up where the make-up does", function()
	Register()

	AssertEquals(Weight("BathroomCabinet"), 6, "a bathroom cabinet")
	AssertEquals(Weight("GigamartCosmetics"), 10, "the cosmetics aisle")
	AssertEquals(Weight("SalonCounter"), 10, "a salon")
	AssertEquals(Weight("BedroomDresser"), 2, "and a dresser, less often")
end)

Test("a hairpin is not in with the tools", function()
	Register()

	-- Both volumes sit on a tool shop shelf. The hairpin has no business there: it is
	-- worth nothing until it is bent into a pick, and finding one among the hammers would
	-- say something about the world that is not true.
	AssertNil(Weight("ToolStoreBooks"), "a tool shop stocks the manual, not the pin")
	AssertNotNil(Harness.LootWeight(ProceduralDistributions.list["ToolStoreBooks"],
		"Base.QolcLockpickBook1"), "the manual is still there")
end)

Test("every table the hairpin names is a real one", function()
	Register()

	-- The game skips a table name that does not exist without a word, so a typo is
	-- invisible in play. The harness builds its list from vanilla's own file, which means
	-- a mistyped name lands nowhere and this count comes up short.
	local Found = 0
	for _, Room in pairs(ProceduralDistributions.list) do
		if Harness.LootWeight(Room, HAIRPIN) then Found = Found + 1 end
	end

	AssertEquals(Found, HAIRPIN_TABLES, "one per table named")
end)

Test("merging twice does not double the odds", function()
	Register()
	Register()

	local _, Count = Harness.LootWeight(ProceduralDistributions.list["BathroomCabinet"], HAIRPIN)
	AssertEquals(Count, 1, "one entry, however often the merge runs")
end)

Test("the volumes still land where they did", function()
	Register()

	local Books = ProceduralDistributions.list["BookstoreBooks"]
	AssertEquals(Harness.LootWeight(Books, "Base.QolcLockpickBook1"), 2, "volume one")
	AssertEquals(Harness.LootWeight(Books, "Base.QolcLockpickBook2"), 2, "volume two")
end)

Test("the sandbox switch holds the hairpin back too", function()
	SandboxVars.QoLC.LockpickingEnabled = false
	Register()

	AssertNil(Weight("BathroomCabinet"), "off means off")
end)

