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
