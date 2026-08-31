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

Test("a forged crowbar is a crowbar", function()
	-- Reported in game as a question about other people's mods, and the answer was worse
	-- than that: build 42 forges its own CrowbarForged, and the name check this used to do
	-- refused it. Both carry base:crowbar, which is what the menu asks for now, so anything
	-- a mod adds with that tag works as well.
	local Player = Burglar()
	Player.Inventory.Items = { Harness.NewTool("CrowbarForged") }

	AssertContains(Names(Menu(Player, { Harness.NewDoorLock() })), getText(FORCE_LOCK),
		"the one you made yourself should work")
end)

Test("a multitool is a screwdriver", function()
	-- The same fix seen from the other end. base:screwdriver is on the multitool, the
	-- handiknife, the improvised screwdriver and the old one, and every one of them was
	-- turned away while this looked for an item literally called Screwdriver.
	local Player = Burglar()
	Player.Inventory.Items = { Harness.NewTool("Multitool"), Harness.NewTool("QolcLockpick") }

	AssertContains(Names(Menu(Player, { Harness.NewDoorLock() })), getText(PICK_LOCK),
		"it has a screwdriver in it")
end)

Test("a crowbar in a backpack is still a crowbar", function()
	-- The old lookup was ItemContainer.FindAndReturn, which the jar shows forwarding to
	-- getFirstType: this container and no further. A worn bag is its own container, so the
	-- crowbar most people actually carry was invisible. The tag lookup recurses.
	local Player = Burglar()
	local Bag = Harness.NewBag("Backpack")
	Bag:getInventory():AddItem(Harness.NewTool("Crowbar"))
	Player.Inventory.Items = { Bag }

	AssertContains(Names(Menu(Player, { Harness.NewDoorLock() })), getText(FORCE_LOCK),
		"it is right there in the bag")
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

Test("forcing a door breaks the lock rather than leaving it set", function()
	-- It used to open the door and leave both fields set, so you walked through, pulled it
	-- shut behind you, and it was locked again. Picking has always cleared the lock; this
	-- is the same door, opened with more noise.
	local Player = Burglar()
	local Door = Harness.NewDoorLock()
	Player:setPrimaryHandItem(Harness.NewTool("Crowbar"))

	Harness.SetRandom({ 1 })
	QolcBreakLockAction:new(Player, Door, 10, nil, nil, false):perform()

	AssertFalse(Door:isLocked(), "the lock is off")
	AssertFalse(Door:isLockedByKey(), "and its key no longer holds it")
	AssertEquals(Door.Refused, 0, "so vanilla never rattles at us instead of opening it")
end)

Test("forcing a door hands the opening to vanilla, so it syncs", function()
	-- ToggleDoorSilent does not sync. ToggleDoorActual does, which is what carries a
	-- forced door to everyone else on a server rather than only the one who forced it.
	local Player = Burglar()
	local Door = Harness.NewDoorLock()
	Player:setPrimaryHandItem(Harness.NewTool("Crowbar"))

	Harness.SetRandom({ 1 })
	QolcBreakLockAction:new(Player, Door, 10, nil, nil, false):perform()

	AssertEquals(Door.Syncs, 1, "the change went out once")
end)

Test("forcing one panel of a wide garage door opens the whole run", function()
	-- Reported with screenshots against 1.5.0: a three wide storage shutter forced with a
	-- crowbar had one panel open like an ordinary doorway while the two beside it stayed
	-- shut. That is what a lone segment drawn with its open sprite looks like.
	local Player = Burglar()
	local Run = Harness.NewGarageDoor(3)
	Player:setPrimaryHandItem(Harness.NewTool("Crowbar"))

	Harness.SetRandom({ 1 })
	QolcBreakLockAction:new(Player, Run[2], 10, nil, nil, false):perform()

	for Index, Segment in ipairs(Run) do
		AssertTrue(Segment:IsOpen(), "panel " .. Index .. " should be open")
	end
end)

Test("a forced garage door closes again in one piece", function()
	-- The half that made it permanent. toggleGarageDoorObject flips each segment from its
	-- own state, not the run's, so a run left out of step never comes back: closing it
	-- shut the one panel that was open and opened the other two. Reported as closing it
	-- opening the other two sides.
	local Player = Burglar()
	local Run = Harness.NewGarageDoor(3)
	Player:setPrimaryHandItem(Harness.NewTool("Crowbar"))

	Harness.SetRandom({ 1 })
	QolcBreakLockAction:new(Player, Run[2], 10, nil, nil, false):perform()

	-- Now shut it the way a player would, by hand, on any panel of the run.
	Run[1]:ToggleDoor(Player)

	for Index, Segment in ipairs(Run) do
		AssertFalse(Segment:IsOpen(), "panel " .. Index .. " should be shut again")
	end
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
Test("turning both off takes every option away", function()
	SandboxVars.QoLC.LockpickingEnabled = false
	SandboxVars.QoLC.PryingEnabled = false
	local Player = Burglar()

	AssertEquals(#Menu(Player, { Harness.NewDoorLock() }).options, 0, "off means off")
	AssertEquals(#Menu(Player, { Harness.NewWindowLock() }).options, 0, "windows too")
end)

Test("the two halves are switched apart", function()
	-- Asked for in game: picking wants two tools, a manual and a recipe, prying wants a
	-- crowbar and a shoulder, and a server can reasonably want one and not the other. Each
	-- switch has to take its own option away and leave the other standing.
	SandboxVars.QoLC.LockpickingEnabled = false
	SandboxVars.QoLC.PryingEnabled = true

	local Names = Names(Menu(Burglar(), { Harness.NewDoorLock() }))
	AssertTrue(string.find(Names, getText(PICK_LOCK), 1, true) == nil, "picking is off")
	AssertContains(Names, getText(FORCE_LOCK), "prying is not")
end)

Test("prying off leaves picking alone, and takes the window with it", function()
	SandboxVars.QoLC.LockpickingEnabled = true
	SandboxVars.QoLC.PryingEnabled = false

	local Player = Burglar()
	local Names = Names(Menu(Player, { Harness.NewDoorLock() }))

	AssertContains(Names, getText(PICK_LOCK), "picking is still there")
	AssertTrue(string.find(Names, getText(FORCE_LOCK), 1, true) == nil, "prying is off")
	AssertEquals(#Menu(Player, { Harness.NewWindowLock() }).options, 0,
		"a window has only ever been pried")
end)

Test("both switches are sandbox options", function()
	AssertNotNil(QOLC_SANDBOX_DEFAULTS["LockpickingEnabled"], "server controlled")
	AssertNotNil(QOLC_SANDBOX_DEFAULTS["PryingEnabled"], "and so is the other half")

	-- On by default, both, so a save made before the split keeps what it had.
	AssertTrue(QOLC_SANDBOX_DEFAULTS["PryingEnabled"], "nobody should lose prying on update")
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

Test("the crowbar in hand is the one that is drawn", function()
	-- The item, not the model name "Crowbar". Those were the same thing until the tools were
	-- looked up by tag, and now they are not: forcing a lock with a forged crowbar drew a
	-- plain one, and a multitool drew a screwdriver.
	local Player = Burglar()
	local Crowbar = Harness.NewTool("CrowbarForged")
	Player:setPrimaryHandItem(Crowbar)

	local Action = QolcBreakLockAction:new(Player, Harness.NewDoorLock(), 10, nil, nil, false)
	Action:start()

	AssertEquals(Action.PrimaryHand, Crowbar, "levering an empty hand looks wrong")
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

Test("the tables are seeded whatever the switch says", function()
	-- Deliberate, and the opposite of what this file used to assert. The merge events all
	-- fire before SandboxOptions.load, which is the only thing that ever fills SandboxVars
	-- from the save, so a switch tested here reads our own declared default and not the
	-- player's answer. Testing it here was worse than not testing it: it looked like a
	-- working switch and was not one. See qolc_loot_switch.lua.
	SandboxVars.QoLC.LockpickingEnabled = false
	Register()

	AssertEquals(Weight("BathroomCabinet"), 6, "seeded regardless")
	AssertNotNil(Harness.LootWeight(ProceduralDistributions.list["BookstoreBooks"],
		"Base.QolcLockpickBook1"), "and so are the volumes")
end)


--// Vehicles
-- A car door is a VehicleDoor on a VehiclePart, reached through the vehicle rather than
-- through the objects under the cursor, which is why none of the door tests above touch one.
local PICK_VEHICLE = "ContextMenu_QoLC_PickVehicleLock"
local FORCE_VEHICLE = "ContextMenu_QoLC_ForceVehicleLock"

local function AtVehicle(Player, Values)
	local Vehicle = Harness.NewLockedVehicle(Values)
	Player.UseableVehicle = Vehicle
	return Vehicle
end

Test("a locked car offers both ways in", function()
	local Player = Burglar()
	AtVehicle(Player)

	local Found = Names(Menu(Player, {}))
	AssertContains(Found, getText(PICK_VEHICLE), "picking")
	AssertContains(Found, getText(FORCE_VEHICLE), "forcing")
end)

Test("the car options are named apart from the house ones", function()
	-- A car parked against a locked front door would otherwise put two identical lines on
	-- the menu with no way to tell which was which.
	AssertTrue(getText(PICK_VEHICLE) ~= getText(PICK_LOCK), "picking reads differently")
	AssertTrue(getText(FORCE_VEHICLE) ~= getText(FORCE_LOCK), "so does forcing")

	local Player = Burglar()
	AtVehicle(Player)

	local Found = Names(Menu(Player, { Harness.NewDoorLock() }))
	for _, Key in ipairs({ PICK_LOCK, FORCE_LOCK, PICK_VEHICLE, FORCE_VEHICLE }) do
		AssertContains(Found, getText(Key), "a door and a car should each offer their own")
	end
end)

Test("an unlocked car is left alone", function()
	local Player = Burglar()
	AtVehicle(Player, { Locked = false })

	AssertEquals(#Menu(Player, {}).options, 0, "it already opens")
end)

Test("an open car door is left alone", function()
	local Player = Burglar()
	AtVehicle(Player, { Open = true })

	AssertEquals(#Menu(Player, {}).options, 0, "there is nothing to work on")
end)

Test("a door that is not fitted is left alone", function()
	-- getInventoryItem is nil for a part that was taken off, and a missing door has no lock.
	-- Vanilla checks the same thing before offering its own open and lock options.
	local Player = Burglar()
	AtVehicle(Player, { Fitted = false })

	AssertEquals(#Menu(Player, {}).options, 0, "no door, no lock")
end)

Test("the bonnet is left alone", function()
	-- It is a door part like any other, and picking it makes no sense: vanilla opens it for
	-- anyone who can get inside the car, so its lock is not what is stopping you.
	local Player = Burglar()
	AtVehicle(Player, { PartId = "EngineDoor" })

	AssertEquals(#Menu(Player, {}).options, 0, "not a way in")
end)

Test("the boot is offered, being a door like the rest", function()
	local Player = Burglar()
	AtVehicle(Player, { PartId = "TrunkDoor" })

	AssertContains(Names(Menu(Player, {})), getText(FORCE_VEHICLE), "a boot has a lock on it")
end)

Test("a car lock keeps its difficulty, and the roll is announced", function()
	-- Rolled once and remembered, the same as a house door, in the part's own mod data,
	-- which VehiclePart.save writes out. transmitPartModData carries the roll to a server so
	-- the lock is as hard for everyone as it is for whoever looked first.
	local Player = Burglar()
	local Vehicle = AtVehicle(Player)
	local Part = Vehicle:getPartById("DoorFrontLeft")

	Menu(Player, {})
	local First = Part:getModData().QolcLockLevel

	AssertNotNil(First, "a lock should have a difficulty")
	AssertTrue(First >= 1 and First <= 5, "one of the five, never the jammed sixth")
	AssertEquals(Vehicle.ModDataTransmitted, 1, "and the roll should have been sent")

	Menu(Player, {})
	AssertEquals(Part:getModData().QolcLockLevel, First, "as hard the second time as the first")
	AssertEquals(Vehicle.ModDataTransmitted, 1, "and not rolled again")
end)

Test("the difficulty is shown with the car options", function()
	local Player = Burglar()
	local Vehicle = AtVehicle(Player)
	Vehicle:getPartById("DoorFrontLeft"):getModData().QolcLockLevel = 3

	AssertContains(Names(Menu(Player, {})), getText("IGUI_QoLC_LockLevel3"), "medium")
end)

Test("sitting in the car offers nothing", function()
	-- getUseablePart answers nil for a character who is in a vehicle, so the menu never sees
	-- a part. Worth pinning, because the option would be absurd from the driver's seat.
	local Player = Burglar()
	local Vehicle = AtVehicle(Player)
	Player.InVehicle = Vehicle

	AssertEquals(#Menu(Player, {}).options, 0, "you are already inside it")
end)

Test("the two switches reach the car as well", function()
	local Player = Burglar()
	AtVehicle(Player)

	SandboxVars.QoLC.LockpickingEnabled = false
	SandboxVars.QoLC.PryingEnabled = true

	local Found = Names(Menu(Player, {}))
	AssertTrue(string.find(Found, getText(PICK_VEHICLE), 1, true) == nil, "picking is off")
	AssertContains(Found, getText(FORCE_VEHICLE), "prying is not")

	SandboxVars.QoLC.LockpickingEnabled = true
	SandboxVars.QoLC.PryingEnabled = false

	Found = Names(Menu(Player, {}))
	AssertContains(Found, getText(PICK_VEHICLE), "picking is back")
	AssertTrue(string.find(Found, getText(FORCE_VEHICLE), 1, true) == nil, "prying is off")
end)

--// Working A Car Lock
local function VehicleAction(Player, Vehicle, Tool, Second)
	Player:setPrimaryHandItem(Tool)
	if Second then Player:setSecondaryHandItem(Second) end

	return Vehicle:getPartById("DoorFrontLeft")
end

Test("forcing a car lock unlocks it and takes the lock with it", function()
	-- The jar shows canLockDoor refusing a broken lock, so setting it means the door can
	-- never be locked again. That is the same thing this already does to a window by perma
	-- locking the latch: you have taken the lock out of it.
	local Player = Burglar()
	local Vehicle = Harness.NewLockedVehicle()
	local Part = VehicleAction(Player, Vehicle, Harness.NewTool("Crowbar"))

	-- BreakLockChance is a one in N roll and a zero is the lock holding, so anything else
	-- is the lock giving way.
	Harness.SetRandom({ 1 })

	local Action = QolcBreakVehicleLockAction:new(Player, Part, 10, nil, nil)
	Action:perform()

	AssertFalse(Part:getDoor():isLocked(), "the door should open now")
	AssertTrue(Part:getDoor():isLockBroken(), "and never lock again")
	AssertEquals(Vehicle.DoorsTransmitted, 1, "a client keeping that to itself has forced nothing")
end)

Test("a car lock that holds stays locked", function()
	local Player = Burglar()
	local Vehicle = Harness.NewLockedVehicle()
	local Part = VehicleAction(Player, Vehicle, Harness.NewTool("Crowbar"))

	Harness.SetRandom({ 0 })

	QolcBreakVehicleLockAction:new(Player, Part, 10, nil, nil):perform()

	AssertTrue(Part:getDoor():isLocked(), "it held")
	AssertFalse(Part:getDoor():isLockBroken(), "and nothing was broken")
end)

Test("picking a car lock opens it", function()
	local Player = Burglar()
	local Vehicle = Harness.NewLockedVehicle()
	local Part = VehicleAction(Player, Vehicle,
		Harness.NewTool("Screwdriver"), Harness.NewTool("QolcLockpick"))

	Harness.SetRandom({ 1, 1, 99 })

	QolcPickVehicleLockAction:new(Player, Part, 10, nil, nil):perform()

	AssertFalse(Part:getDoor():isLocked(), "picked")
	AssertFalse(Part:getDoor():isLockBroken(), "and the lock survived")
	AssertEquals(Vehicle.DoorsTransmitted, 1, "the change has to reach the server")
end)

Test("failing a car pick wrecks the lock for good", function()
	-- lockBroken is vanilla's own field, and the jar shows canUnlockDoor refusing it, so the
	-- key stops working too. That is what a jammed house lock already means here, said in the
	-- game's own words rather than ours.
	local Player = Burglar()
	local Vehicle = Harness.NewLockedVehicle()
	local Part = VehicleAction(Player, Vehicle,
		Harness.NewTool("Screwdriver"), Harness.NewTool("QolcLockpick"))

	Harness.SetRandom({ 0, 1, 99 })

	QolcPickVehicleLockAction:new(Player, Part, 10, nil, nil):perform()

	AssertTrue(Part:getDoor():isLocked(), "still shut")
	AssertTrue(Part:getDoor():isLockBroken(), "and nothing will open it now")
end)

Test("a multitool and a forged crowbar are accepted by the car actions too", function()
	-- The menu offers these, so an action that refused them would be worse than no option.
	local Player = Burglar()
	local Vehicle = Harness.NewLockedVehicle()
	local Part = Vehicle:getPartById("DoorFrontLeft")

	Player:setPrimaryHandItem(Harness.NewTool("CrowbarForged"))
	AssertTrue(QolcBreakVehicleLockAction:new(Player, Part, 10, nil, nil):isValid(), "forged")

	Player:setPrimaryHandItem(Harness.NewTool("Multitool"))
	Player:setSecondaryHandItem(Harness.NewTool("QolcLockpick"))
	AssertTrue(QolcPickVehicleLockAction:new(Player, Part, 10, nil, nil):isValid(), "multitool")
end)

Test("dropping either tool stops the car pick", function()
	local Player = Burglar()
	local Vehicle = Harness.NewLockedVehicle()
	local Part = Vehicle:getPartById("DoorFrontLeft")

	Player:setPrimaryHandItem(Harness.NewTool("Screwdriver"))
	local Action = QolcPickVehicleLockAction:new(Player, Part, 10, nil, nil)

	AssertFalse(Action:isValid(), "one hand is empty")
end)

Test("a lock that is already open stops the car actions", function()
	local Player = Burglar()
	local Vehicle = Harness.NewLockedVehicle({ Locked = false })
	local Part = Vehicle:getPartById("DoorFrontLeft")

	Player:setPrimaryHandItem(Harness.NewTool("Crowbar"))

	AssertFalse(QolcBreakVehicleLockAction:new(Player, Part, 10, nil, nil):isValid(),
		"there is nothing left to force")
end)

Test("the player walks to the door before working on it", function()
	local Player = Burglar()
	AtVehicle(Player)

	local Context = Menu(Player, {})
	local Forcing = nil
	for _, Option in ipairs(Context.options) do
		if string.find(Option.name, getText(FORCE_VEHICLE), 1, true) == 1 then Forcing = Option end
	end

	AssertNotNil(Forcing, "the option should be there to click")

	Harness.ActionQueue = {}
	Forcing:Click()

	AssertTrue(#Harness.ActionQueue >= 2, "a path and the work")
	AssertEquals(Harness.ActionQueue[1].Class, "ISPathFindAction", "the path comes first")
	AssertEquals(Harness.ActionQueue[#Harness.ActionQueue].Name, "QolcBreakVehicleLockAction",
		"and the work comes last")
end)

--// Asking The Server About A Car Lock
-- A car door's lock only travels one way. BaseVehicle.transmitPartDoor returns immediately
-- unless this is the server, and the two packets that carry part state, VehicleUpdate and
-- VehicleFullUpdate, are both sent from VehicleManager.sendVehicles, which only serverUpdate
-- calls. clientUpdate sends no part state at all. So a client that unlocks a car door has
-- unlocked it for itself and the server's next update puts the lock straight back.
--
-- A building door is not like this: IsoDoor.syncIsoObject sends upward as well as down, which
-- is why picking a house has always worked on a server and picking a car did not.
local LOCK_MODULE = "QoLC"
local LOCK_COMMAND = "VehicleLock"

Test("forcing a car lock on a client asks the server", function()
	Harness.IsClient = true

	local Player = Burglar()
	local Vehicle = Harness.NewLockedVehicle()
	local Part = VehicleAction(Player, Vehicle, Harness.NewTool("Crowbar"))

	Harness.SetRandom({ 1 })
	QolcBreakVehicleLockAction:new(Player, Part, 10, nil, nil):perform()

	local Sent = Harness.LastCommand(LOCK_COMMAND)
	AssertNotNil(Sent, "the server has to be told")
	AssertEquals(Sent.Module, LOCK_MODULE, "under our own module")
	AssertEquals(Sent.Request.vehicle, Vehicle:getId(), "which car")
	AssertEquals(Sent.Request.part, "DoorFrontLeft", "which door")
	AssertTrue(Sent.Request.unlock, "open it")
	AssertTrue(Sent.Request.wreck, "and take the lock with it")
	AssertTrue(Sent.Request.prying, "this was the crowbar")
end)

Test("picking a car lock on a client asks the server", function()
	Harness.IsClient = true

	local Player = Burglar()
	local Vehicle = Harness.NewLockedVehicle()
	local Part = VehicleAction(Player, Vehicle,
		Harness.NewTool("Screwdriver"), Harness.NewTool("QolcLockpick"))

	Harness.SetRandom({ 1, 1, 99 })
	QolcPickVehicleLockAction:new(Player, Part, 10, nil, nil):perform()

	local Sent = Harness.LastCommand(LOCK_COMMAND)
	AssertNotNil(Sent, "the server has to be told")
	AssertTrue(Sent.Request.unlock, "open it")
	AssertFalse(Sent.Request.wreck, "a clean pick leaves the lock alone")
	AssertFalse(Sent.Request.prying, "this was the pick")
end)

Test("a wrecked car lock is reported too", function()
	Harness.IsClient = true

	local Player = Burglar()
	local Vehicle = Harness.NewLockedVehicle()
	local Part = VehicleAction(Player, Vehicle,
		Harness.NewTool("Screwdriver"), Harness.NewTool("QolcLockpick"))

	Harness.SetRandom({ 0, 1, 99 })
	QolcPickVehicleLockAction:new(Player, Part, 10, nil, nil):perform()

	local Sent = Harness.LastCommand(LOCK_COMMAND)
	AssertNotNil(Sent, "a wrecked lock is a change like any other")
	AssertFalse(Sent.Request.unlock, "it did not open")
	AssertTrue(Sent.Request.wreck, "but it is ruined")
end)

Test("nothing is asked of anyone in singleplayer", function()
	local Player = Burglar()
	local Vehicle = Harness.NewLockedVehicle()
	local Part = VehicleAction(Player, Vehicle, Harness.NewTool("Crowbar"))

	Harness.SetRandom({ 1 })
	QolcBreakVehicleLockAction:new(Player, Part, 10, nil, nil):perform()

	AssertNil(Harness.LastCommand(LOCK_COMMAND), "there is nobody to ask")
	AssertFalse(Part:getDoor():isLocked(), "and it is open all the same")
end)

Test("the client still sees its own work at once", function()
	-- Applied locally as well as asked for, so the door reads as forced the moment the job
	-- finishes rather than a round trip later. The server's copy is the one that lasts.
	Harness.IsClient = true

	local Player = Burglar()
	local Vehicle = Harness.NewLockedVehicle()
	local Part = VehicleAction(Player, Vehicle, Harness.NewTool("Crowbar"))

	Harness.SetRandom({ 1 })
	QolcBreakVehicleLockAction:new(Player, Part, 10, nil, nil):perform()

	AssertFalse(Part:getDoor():isLocked(), "no waiting for the answer")
end)

--// The Server Half
Test("the server works the lock when a client asks", function()
	local Vehicle = Harness.NewLockedVehicle()
	local Part = Vehicle:getPartById("DoorFrontLeft")

	Harness.Fire("OnClientCommand", LOCK_MODULE, LOCK_COMMAND, Harness.NewPlayer(0, true), {
		vehicle = Vehicle:getId(), part = "DoorFrontLeft",
		unlock = true, wreck = true, prying = true
	})

	AssertFalse(Part:getDoor():isLocked(), "open")
	AssertTrue(Part:getDoor():isLockBroken(), "and ruined")
	AssertEquals(Vehicle.DoorsTransmitted, 1, "and sent on, which is the whole point")
end)

Test("the server ignores a request for something that is not there", function()
	local Vehicle = Harness.NewLockedVehicle()
	local Part = Vehicle:getPartById("DoorFrontLeft")

	Harness.Fire("OnClientCommand", LOCK_MODULE, LOCK_COMMAND, Harness.NewPlayer(0, true), {
		vehicle = Vehicle:getId(), part = "NoSuchDoor", unlock = true, prying = true
	})
	Harness.Fire("OnClientCommand", LOCK_MODULE, LOCK_COMMAND, Harness.NewPlayer(0, true), {
		vehicle = 9999, part = "DoorFrontLeft", unlock = true, prying = true
	})

	AssertTrue(Part:getDoor():isLocked(), "neither of those names anything real")
end)

Test("the server ignores a command that is not ours", function()
	local Vehicle = Harness.NewLockedVehicle()
	local Part = Vehicle:getPartById("DoorFrontLeft")

	Harness.Fire("OnClientCommand", "SomeOtherMod", LOCK_COMMAND, Harness.NewPlayer(0, true), {
		vehicle = Vehicle:getId(), part = "DoorFrontLeft", unlock = true, prying = true
	})
	Harness.Fire("OnClientCommand", LOCK_MODULE, "SomethingElse", Harness.NewPlayer(0, true), {
		vehicle = Vehicle:getId(), part = "DoorFrontLeft", unlock = true, prying = true
	})

	AssertTrue(Part:getDoor():isLocked(), "neither of those is ours")
end)

Test("the server refuses the half that is switched off", function()
	-- A client with the feature on locally, or one still running an older build, should not be
	-- able to open a car on a server that has said no. Picking and prying are separate
	-- switches, so the request has to say which it was.
	SandboxVars.QoLC.PryingEnabled = false
	SandboxVars.QoLC.LockpickingEnabled = true

	local Vehicle = Harness.NewLockedVehicle()
	local Part = Vehicle:getPartById("DoorFrontLeft")

	Harness.Fire("OnClientCommand", LOCK_MODULE, LOCK_COMMAND, Harness.NewPlayer(0, true), {
		vehicle = Vehicle:getId(), part = "DoorFrontLeft", unlock = true, prying = true
	})
	AssertTrue(Part:getDoor():isLocked(), "prying is off here")

	Harness.Fire("OnClientCommand", LOCK_MODULE, LOCK_COMMAND, Harness.NewPlayer(0, true), {
		vehicle = Vehicle:getId(), part = "DoorFrontLeft", unlock = true, prying = false
	})
	AssertFalse(Part:getDoor():isLocked(), "picking is not")
end)

Test("what the client sends is what the server answers to", function()
	-- End to end, because the request and the handler are in different files and a spec that
	-- only checked one of them would not notice them drifting apart.
	Harness.IsClient = true

	local Player = Burglar()
	local Asked = Harness.NewLockedVehicle()
	local Part = VehicleAction(Player, Asked, Harness.NewTool("Crowbar"))

	Harness.SetRandom({ 1 })
	QolcBreakVehicleLockAction:new(Player, Part, 10, nil, nil):perform()

	local Sent = Harness.LastCommand(LOCK_COMMAND)
	AssertNotNil(Sent, "it should have asked")

	Harness.IsClient = false

	-- A second car standing in for the server's own copy, which is the one that was never
	-- being changed.
	local Server = Harness.NewLockedVehicle()
	local Mine = Server:getPartById("DoorFrontLeft")

	local Request = {}
	for Key, Value in pairs(Sent.Request) do Request[Key] = Value end
	Request.vehicle = Server:getId()

	Harness.Fire("OnClientCommand", Sent.Module, Sent.Command, Player, Request)

	AssertFalse(Mine:getDoor():isLocked(), "the server's copy opens too")
	AssertTrue(Mine:getDoor():isLockBroken(), "and its lock is ruined too")
end)

Test("the difficulty is settled by whoever works the lock first", function()
	-- Part mod data only travels server to client like everything else on a part, so without
	-- this every player rolls their own difficulty for the same car and rerolls it on every
	-- rejoin, which is both inconsistent and a way to shorten the job.
	local Vehicle = Harness.NewLockedVehicle()
	local Part = Vehicle:getPartById("DoorFrontLeft")

	Harness.Fire("OnClientCommand", LOCK_MODULE, LOCK_COMMAND, Harness.NewPlayer(0, true), {
		vehicle = Vehicle:getId(), part = "DoorFrontLeft",
		unlock = true, prying = true, level = 4
	})

	AssertEquals(Part:getModData().QolcLockLevel, 4, "the server keeps it")
	AssertEquals(Vehicle.ModDataTransmitted, 1, "and hands it on")
end)

Test("a difficulty outside the five is thrown away", function()
	-- It came off the wire, and a level with no name to show would put a raw key on the menu.
	local Vehicle = Harness.NewLockedVehicle()
	local Part = Vehicle:getPartById("DoorFrontLeft")

	for _, Bad in ipairs({ 0, 6, 99, -3 }) do
		Harness.Fire("OnClientCommand", LOCK_MODULE, LOCK_COMMAND, Harness.NewPlayer(0, true), {
			vehicle = Vehicle:getId(), part = "DoorFrontLeft",
			unlock = true, prying = true, level = Bad
		})
	end

	AssertNil(Part:getModData().QolcLockLevel, "none of those is one of the five")
	AssertFalse(Part:getDoor():isLocked(), "though the door still opened")
end)
