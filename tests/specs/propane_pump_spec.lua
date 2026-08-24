--// Propane From Fuel Pumps Spec
--// aspctt - 10.08.2026

local TAKE_PROPANE = "Take Propane"

--// Helpers
-- Number matters. getSpecificPlayer looks a character up by it, so two players built
-- with the same number would leave the second answering for both.
local NextPlayerNumber = 0

local function NewPlayerWithTanks(...)
	local Player = Harness.NewPlayer(NextPlayerNumber, true)
	NextPlayerNumber = NextPlayerNumber + 1

	for _, Fraction in ipairs({ ... }) do
		table.insert(Player.Inventory.Items, Harness.NewPropaneTank(Fraction))
	end

	return Player
end

-- Right clicks the given world objects and returns the context menu that was built
local function RightClick(Player, WorldObjects)
	Harness.ActionQueue = {}
	local Menu = Harness.NewContextMenu()
	Harness.Fire("OnFillWorldObjectContextMenu", Player.Number, Menu, WorldObjects, false)
	return Menu
end

local function RunQueue()
	for _, Action in ipairs(Harness.ActionQueue) do
		if Action:isValid() then Action:perform() end
	end
end

local function Tanks(Player)
	local Found = {}
	for _, Item in ipairs(Player.Inventory.Items) do
		table.insert(Found, Item)
	end
	return Found
end

--// Wiring
Test("the mod hooks the world context menu", function()
	AssertTrue(Harness.HandlerCount("OnFillWorldObjectContextMenu") > 0,
		"should listen for OnFillWorldObjectContextMenu")
end)

--// When The Option Appears
Test("a working pump with an empty tank offers propane", function()
	local Player = NewPlayerWithTanks(0)
	local Menu = RightClick(Player, { Harness.NewFuelPump(22000) })

	AssertNotNil(Menu:Find(TAKE_PROPANE), "the option should be offered")
end)

Test("a dry pump offers nothing", function()
	-- getPipedFuelAmount is zero on a pump with no power or no fuel, which is the same
	-- test vanilla uses before offering to refuel a car.
	local Player = NewPlayerWithTanks(0)
	local Menu = RightClick(Player, { Harness.NewFuelPump(0) })

	AssertNil(Menu:Find(TAKE_PROPANE), "a dead pump should offer nothing")
end)

Test("nothing is offered without a tank to fill", function()
	local Player = Harness.NewPlayer(0, true)
	local Menu = RightClick(Player, { Harness.NewFuelPump(22000) })

	AssertNil(Menu:Find(TAKE_PROPANE), "no tank means no option")
end)

-- A propane tank weighs ten, which is most of a character's spare capacity, so almost
-- nobody carries one loose. A worn bag is a container of its own and getItems does not
-- descend into it, so the option was missing for anyone who packed the tank rather than
-- holding it. Vanilla goes looking for a petrol can with containsEvalRecurse and
-- getAllEvalRecurse for exactly this reason.
local function NewPlayerWithPackedTank(Fraction)
	local Player = Harness.NewPlayer(NextPlayerNumber, true)
	NextPlayerNumber = NextPlayerNumber + 1

	local Bag = Harness.NewBag("Backpack")
	Bag.Container = Player.Inventory
	table.insert(Player.Inventory.Items, Bag)

	local Tank = Harness.NewPropaneTank(Fraction)
	Tank.Container = Bag.Inventory
	table.insert(Bag.Inventory.Items, Tank)

	return Player, Tank, Bag
end

Test("a tank inside a bag is offered too", function()
	local Player = NewPlayerWithPackedTank(0)
	local Menu = RightClick(Player, { Harness.NewFuelPump(22000) })

	AssertNotNil(Menu:Find(TAKE_PROPANE), "a packed tank should still be offered")
end)

Test("a packed tank is fetched out of the bag and put back", function()
	-- The tank is held in hand for the animation, and the game expects a held item to be
	-- in the character's own inventory. Vanilla transfers the petrol can out first for
	-- the same reason, then puts it back where it came from afterwards.
	local Player, Tank, Bag = NewPlayerWithPackedTank(0)
	local Menu = RightClick(Player, { Harness.NewFuelPump(22000) })

	Menu:Find(TAKE_PROPANE).SubMenu.options[1]:Click()

	local Queue = Harness.ActionQueue
	AssertEquals(#Queue, 3, "fetch, fill, put back")
	AssertEquals(Queue[1].destContainer, Player.Inventory, "fetched into the player's own hands")
	AssertEquals(Queue[3].destContainer, Bag.Inventory, "and returned to the bag it came from")

	RunQueue()
	AssertTrue(Tank:getCurrentUsesFloat() > 0, "the fill should still have happened")
	AssertEquals(Tank:getContainer(), Bag.Inventory, "and it ends up back in the bag")
end)

Test("a tank already in hand is not shuffled about", function()
	local Player = NewPlayerWithTanks(0)
	local Menu = RightClick(Player, { Harness.NewFuelPump(22000) })

	Menu:Find(TAKE_PROPANE).SubMenu.options[1]:Click()
	AssertEquals(#Harness.ActionQueue, 1, "nothing to fetch means nothing but the fill")
end)

Test("a full tank is not offered", function()
	local Player = NewPlayerWithTanks(1)
	local Menu = RightClick(Player, { Harness.NewFuelPump(22000) })

	AssertNil(Menu:Find(TAKE_PROPANE), "there is nothing to fill")
end)

Test("the pump is found even when the click lands on something else", function()
	-- A right click hits whichever object is on top, so the rest of the square matters.
	local Pump = Harness.NewFuelPump(22000)
	local Player = NewPlayerWithTanks(0)
	local Menu = RightClick(Player, { Harness.NewSceneryWith({ Pump }) })

	AssertNotNil(Menu:Find(TAKE_PROPANE), "the pump beside the clicked object counts")
end)

Test("a fill all option appears only with more than one tank", function()
	local One = NewPlayerWithTanks(0)
	local Two = NewPlayerWithTanks(0, 0.5)

	local MenuOne = RightClick(One, { Harness.NewFuelPump(22000) })
	local MenuTwo = RightClick(Two, { Harness.NewFuelPump(22000) })

	AssertNil(MenuOne:Find(TAKE_PROPANE).SubMenu:Find("ContextMenu_FillAll"),
		"one tank needs no fill all")
	AssertNotNil(MenuTwo:Find(TAKE_PROPANE).SubMenu:Find("ContextMenu_FillAll"),
		"two tanks should offer it")
end)

--// Filling
Test("an empty tank is filled", function()
	local Player = NewPlayerWithTanks(0)
	local Pump = Harness.NewFuelPump(22000)

	local Menu = RightClick(Player, { Pump })
	Menu:Find(TAKE_PROPANE).SubMenu.options[1]:Click()
	RunQueue()

	AssertNear(Tanks(Player)[1]:getCurrentUsesFloat(), 1, 0.000001, "the tank should be full")
end)

Test("filling draws on the pump", function()
	local Player = NewPlayerWithTanks(0)
	local Pump = Harness.NewFuelPump(22000)

	local Menu = RightClick(Player, { Pump })
	Menu:Find(TAKE_PROPANE).SubMenu.options[1]:Click()
	RunQueue()

	AssertEquals(Pump:getPipedFuelAmount(), 22000 - SandboxVars.QoLC.PropanePumpCost,
		"a full tank should cost the sandbox amount")
end)

Test("a half empty tank costs half as much", function()
	local Player = NewPlayerWithTanks(0.5)
	local Pump = Harness.NewFuelPump(22000)

	local Menu = RightClick(Player, { Pump })
	Menu:Find(TAKE_PROPANE).SubMenu.options[1]:Click()
	RunQueue()

	local Spent = 22000 - Pump:getPipedFuelAmount()
	AssertNear(Spent, SandboxVars.QoLC.PropanePumpCost / 2, 1, "topping up should cost less")
end)

Test("a nearly dry pump gives a partial fill", function()
	Harness.ResetSandbox()
	local Cost = SandboxVars.QoLC.PropanePumpCost

	local Player = NewPlayerWithTanks(0)
	local Pump = Harness.NewFuelPump(math.floor(Cost / 2))

	local Menu = RightClick(Player, { Pump })
	Menu:Find(TAKE_PROPANE).SubMenu.options[1]:Click()
	RunQueue()

	local Filled = Tanks(Player)[1]:getCurrentUsesFloat()
	AssertTrue(Filled > 0.3, "should have taken what was there, got " .. tostring(Filled))
	AssertTrue(Filled < 0.7, "but not filled beyond it, got " .. tostring(Filled))
	AssertEquals(Pump:getPipedFuelAmount(), 0, "the pump should be dry")
end)

Test("filling every tank empties them all into the pump's cost", function()
	local Player = NewPlayerWithTanks(0, 0, 0)
	local Pump = Harness.NewFuelPump(22000)

	local Menu = RightClick(Player, { Pump })
	Menu:Find(TAKE_PROPANE).SubMenu:Find("ContextMenu_FillAll"):Click()
	RunQueue()

	for Index, Tank in ipairs(Tanks(Player)) do
		AssertNear(Tank:getCurrentUsesFloat(), 1, 0.000001, "tank " .. Index .. " should be full")
	end

	AssertEquals(Pump:getPipedFuelAmount(), 22000 - (SandboxVars.QoLC.PropanePumpCost * 3),
		"three tanks should cost three times as much")
end)

Test("the tank is synced for multiplayer", function()
	local Player = NewPlayerWithTanks(0)
	local Pump = Harness.NewFuelPump(22000)

	local Menu = RightClick(Player, { Pump })
	Menu:Find(TAKE_PROPANE).SubMenu.options[1]:Click()
	RunQueue()

	AssertTrue(Tanks(Player)[1].SyncCount > 0, "a drainable carries its charge as an item field")
end)

--// Validity
Test("the action stops if the pump runs dry", function()
	local Player = NewPlayerWithTanks(0)
	local Pump = Harness.NewFuelPump(22000)

	local Menu = RightClick(Player, { Pump })
	Menu:Find(TAKE_PROPANE).SubMenu.options[1]:Click()

	Pump:setPipedFuelAmount(0)
	AssertFalse(Harness.ActionQueue[1]:isValid(), "an empty pump should end the action")
end)

Test("the action stops once the tank is full", function()
	local Player = NewPlayerWithTanks(0)
	local Pump = Harness.NewFuelPump(22000)

	local Menu = RightClick(Player, { Pump })
	Menu:Find(TAKE_PROPANE).SubMenu.options[1]:Click()

	Tanks(Player)[1]:setCurrentUsesFloat(1)
	AssertFalse(Harness.ActionQueue[1]:isValid(), "a full tank should end the action")
end)

--// Sandbox
Test("the server sets what propane costs", function()
	Harness.ResetSandbox()
	SandboxVars.QoLC.PropanePumpCost = 500

	local Player = NewPlayerWithTanks(0)
	local Pump = Harness.NewFuelPump(22000)

	local Menu = RightClick(Player, { Pump })
	Menu:Find(TAKE_PROPANE).SubMenu.options[1]:Click()
	RunQueue()

	AssertEquals(Pump:getPipedFuelAmount(), 22000 - 500, "should have used the sandbox value")
end)

Test("a save with no sandbox value still fills", function()
	Harness.ClearSandbox()

	local Player = NewPlayerWithTanks(0)
	local Pump = Harness.NewFuelPump(22000)

	local Menu = RightClick(Player, { Pump })
	Menu:Find(TAKE_PROPANE).SubMenu.options[1]:Click()
	RunQueue()

	AssertNear(Tanks(Player)[1]:getCurrentUsesFloat(), 1, 0.000001,
		"should fall back to the declared default rather than break")
end)

--// Translations
Test("the context menu label resolves", function()
	AssertNotNil(Translations["ContextMenu_QoLC_TakePropane"], "missing the Take Propane label")
end)

--// Finding The Pump
-- Reported in game: right clicking a gas station pump offered nothing at all. A pump is
-- several tiles and the part under the cursor is usually not the object holding the fuel,
-- which is why vanilla's own getNearbyFuelPump sweeps the tiles around a position rather
-- than testing one square.
Test("a pump on a neighbouring tile is still found", function()
	local Player = Harness.NewPlayer(0, true)
	Player.Inventory.Items = { Harness.NewPropaneTank(0) }

	-- The click lands on bare scenery, the pump is two tiles over
	Harness.NewObjectSquare(12, 10, 0, { Harness.NewFuelPump(22000) })
	local Clicked = Harness.NewSceneryWith({}, 10, 10, 0)

	AssertNotNil(RightClick(Player, { Clicked }):Find(TAKE_PROPANE),
		"the option should appear from the tile beside it")
end)

Test("the sweep does not reach across the street", function()
	local Player = Harness.NewPlayer(0, true)
	Player.Inventory.Items = { Harness.NewPropaneTank(0) }

	Harness.NewObjectSquare(20, 10, 0, { Harness.NewFuelPump(22000) })
	local Clicked = Harness.NewSceneryWith({}, 10, 10, 0)

	AssertNil(RightClick(Player, { Clicked }):Find(TAKE_PROPANE),
		"ten tiles away is not this pump")
end)

Test("a pump on another floor is not offered", function()
	local Player = Harness.NewPlayer(0, true)
	Player.Inventory.Items = { Harness.NewPropaneTank(0) }

	Harness.NewObjectSquare(10, 10, 1, { Harness.NewFuelPump(22000) })
	local Clicked = Harness.NewSceneryWith({}, 10, 10, 0)

	AssertNil(RightClick(Player, { Clicked }):Find(TAKE_PROPANE), "wrong floor")
end)

--// How It Looks
-- Nothing here changes what the action does, but a filling animation that does not match
-- the one vanilla plays at the same pump reads as a bug to a player.
local function StartedAction(Player, Pump)
	local Menu = RightClick(Player, { Pump })
	Menu:Find(TAKE_PROPANE).SubMenu.options[1]:Click()

	local Action = Harness.ActionQueue[1]
	Action:start()
	return Action
end

Test("filling plays the pump animation rather than a generic one", function()
	local Player = NewPlayerWithTanks(0)
	local Action = StartedAction(Player, Harness.NewFuelPump(22000))

	AssertEquals(Action.Anim, "TakeGasFromPump", "the same animation vanilla uses at a pump")
end)

Test("the tank is held while filling", function()
	local Player = NewPlayerWithTanks(0)
	local Action = StartedAction(Player, Harness.NewFuelPump(22000))

	-- A propane tank declares only a WorldStaticModel, so reaching for getStaticModel
	-- alone would leave the character filling with an empty hand.
	AssertEquals(Action.SecondaryHand, "PropaneTank", "the tank goes in the off hand")
	AssertNil(Action.PrimaryHand, "the other hand works the pump")
end)

Test("the tank carries the job bar while it fills", function()
	local Player = NewPlayerWithTanks(0)
	local Pump = Harness.NewFuelPump(22000)
	local Action = StartedAction(Player, Pump)
	local Tank = Tanks(Player)[1]

	AssertEquals(Tank.JobType, TAKE_PROPANE, "named on the icon")

	Action.JobDelta = 0.5
	Action:update()
	AssertEquals(Tank.JobDelta, 0.5, "and filling as the action runs")

	Action:perform()
	AssertEquals(Tank.JobDelta, 0, "cleared when it finishes")
end)

Test("an interrupted fill clears the job bar too", function()
	local Player = NewPlayerWithTanks(0)
	local Action = StartedAction(Player, Harness.NewFuelPump(22000))

	Action.JobDelta = 0.5
	Action:update()
	Action:stop()

	AssertEquals(Tanks(Player)[1].JobDelta, 0, "no bar left stuck on the icon")
end)

Test("the character turns to the pump before filling", function()
	local Player = NewPlayerWithTanks(0)
	local Pump = Harness.NewFuelPump(22000)
	local Menu = RightClick(Player, { Pump })
	Menu:Find(TAKE_PROPANE).SubMenu.options[1]:Click()

	Player.Turning = true
	AssertTrue(Harness.ActionQueue[1]:waitToStart(), "wait while still turning")
	AssertEquals(Player.Facing, Pump, "and turn towards the pump")

	Player.Turning = false
	AssertFalse(Harness.ActionQueue[1]:waitToStart(), "then start")
end)
