--// Welding Torch Capacity Spec
--// aspctt - 09.08.2026

local TANK_MAX_USES = 5000
local TORCH_USES = 16

--// Helpers
local function NewTorch(Fraction)
	return Harness.NewDrainable(TORCH_USES, Fraction)
end

local function NewTank(Fraction)
	return Harness.NewDrainable(TANK_MAX_USES, Fraction)
end

-- Runs one refill, returning the torch the recipe produced. The created torch is the same
-- size as the consumed one, as it is in game, because vanilla's refill is sized from it.
local function Refill(Torch, Tank)
	local Created = Harness.NewDrainable(Torch:getMaxUses(), 0)
	local Data = Harness.NewCraftRecipeData(Created, Torch, Tank)
	Recipe.OnCreate.QolcRefillBlowTorch(Data, nil)
	return Created
end

-- Empties a full tank, returning how many complete refills it managed. Uses is the size of
-- the torch being refilled, ours unless a test says otherwise.
local function CountRefillsPerTank(Uses)
	local Tank = NewTank(1)
	local Refills = 0

	for _ = 1, 200 do
		if Tank:getCurrentUses() <= 0 then break end
		local Result = Refill(Harness.NewDrainable(Uses or TORCH_USES, 0), Tank)
		if Result:getCurrentUsesFloat() < 0.999 then break end
		Refills = Refills + 1
	end

	return Refills
end

--// Capacity
Test("the torch is patched to sixteen uses on init", function()
	Harness.Fire("OnInitGlobalModData")
	local Item = ScriptManager.instance:getItem("Base.BlowTorch")
	AssertNear(Item:getUseDelta(), 1 / TORCH_USES, 0.0000005, "torch UseDelta")
end)

Test("patching twice does not stack", function()
	-- Counted on the torch alone. Other features patch their own items on the same event
	-- and some of them write every time by design, so a total across all items would
	-- report their work as this one failing.
	Harness.Fire("OnInitGlobalModData")
	local CallsAfterFirst = Harness.DoParamsFor["Base.BlowTorch"]

	Harness.Fire("OnInitGlobalModData")
	AssertEquals(Harness.DoParamsFor["Base.BlowTorch"], CallsAfterFirst,
		"a second init should be a no op")
end)

Test("the propane tank itself is left alone", function()
	Harness.Fire("OnInitGlobalModData")
	AssertEquals(Harness.ScriptItems["Base.PropaneTank"].UseDelta, 0.0002,
		"tank stats must stay vanilla so other mods can change them")
end)

--// Economy
Test("a full tank gives thirty refills", function()
	AssertEquals(CountRefillsPerTank(), 30, "refills per tank")
end)

Test("a full tank gives four hundred and eighty welding uses", function()
	AssertEquals(CountRefillsPerTank() * TORCH_USES, 480, "total welding uses per tank")
end)

Test("one refill from empty fills the torch completely", function()
	local Tank = NewTank(1)
	local Result = Refill(NewTorch(0), Tank)
	AssertNear(Result:getCurrentUsesFloat(), 1, 0.000001, "torch should be full")
end)

Test("one refill from empty costs a thirtieth of the tank", function()
	local Tank = NewTank(1)
	Refill(NewTorch(0), Tank)

	local Remaining = Tank:getCurrentUsesFloat() * TANK_MAX_USES
	AssertNear(Remaining, TANK_MAX_USES - (TANK_MAX_USES / 30), 0.001,
		"tank should lose exactly one refill's worth")
end)

--// Proportional Refill
Test("a half empty torch costs half a refill", function()
	local Tank = NewTank(1)
	Refill(NewTorch(0.5), Tank)

	local Spent = TANK_MAX_USES - (Tank:getCurrentUsesFloat() * TANK_MAX_USES)
	AssertNear(Spent, (TANK_MAX_USES / 30) / 2, 0.001, "half a torch should cost half the propane")
end)

Test("topping up a nearly full torch is nearly free", function()
	local Tank = NewTank(1)
	Refill(NewTorch(0.95), Tank)

	local Spent = TANK_MAX_USES - (Tank:getCurrentUsesFloat() * TANK_MAX_USES)
	AssertTrue(Spent < 10, "a small top up should cost very little, spent " .. tostring(Spent))
end)

Test("draining a tank one refill at a time loses nothing to rounding", function()
	local Tank = NewTank(1)
	for _ = 1, 30 do
		Refill(NewTorch(0), Tank)
	end

	local Remaining = Tank:getCurrentUsesFloat() * TANK_MAX_USES
	AssertNear(Remaining, 0, 0.001, "thirty refills should consume the tank exactly")
end)

Test("the torch keeps its charge when the tank is empty", function()
	local Tank = NewTank(0)
	local Result = Refill(NewTorch(0.4), Tank)
	AssertNear(Result:getCurrentUsesFloat(), 0.4, 0.000001, "charge should carry over untouched")
end)

Test("a nearly empty tank gives a partial fill rather than a full one", function()
	-- Half of what one refill needs
	local Tank = NewTank((TANK_MAX_USES / 30) / 2 / TANK_MAX_USES)
	local Result = Refill(NewTorch(0), Tank)

	AssertTrue(Result:getCurrentUsesFloat() > 0.4, "should have taken what was left")
	AssertTrue(Result:getCurrentUsesFloat() < 0.6, "should not have filled beyond what was left")
	AssertEquals(Tank:getCurrentUses(), 0, "tank should be drained")
end)

Test("condition carries from the consumed torch", function()
	local Tank = NewTank(1)
	local Old = NewTorch(0.2)
	Old:setCondition(37)

	local Result = Refill(Old, Tank)
	AssertEquals(Result:getCondition(), 37, "condition should follow the torch, not reset")
end)

--// Multiplayer
Test("both items are synced for multiplayer", function()
	local Tank = NewTank(1)
	local Result = Refill(NewTorch(0), Tank)

	AssertTrue(Result.SyncCount > 0, "the created torch must be synced")
	AssertTrue(Tank.SyncCount > 0, "the drained tank must be synced")
end)

Test("nothing is synced when there was nothing to do", function()
	local Tank = NewTank(0)
	local Result = Refill(NewTorch(1), Tank)
	AssertEquals(Tank.SyncCount, 0, "an untouched tank should not be synced")
	AssertTrue(Result.SyncCount > 0, "the created torch is always synced")
end)

--// Compatibility
Test("refills per tank hold when another mod changes tank capacity", function()
	-- Real Metalworking and friends resize the tank. Refill count should not move.
	local BigTank = Harness.NewDrainable(20000, 1)
	local Refills = 0

	for _ = 1, 200 do
		if BigTank:getCurrentUses() <= 0 then break end
		local Result = Refill(NewTorch(0), BigTank)
		if Result:getCurrentUsesFloat() < 0.999 then break end
		Refills = Refills + 1
	end

	AssertEquals(Refills, 30, "refills should stay at thirty regardless of tank size")
end)

Test("the recipe hook is registered where the script file points", function()
	AssertNotNil(Recipe, "Recipe table")
	AssertNotNil(Recipe.OnCreate, "Recipe.OnCreate table")
	AssertEquals(type(Recipe.OnCreate.QolcRefillBlowTorch), "function",
		"media/scripts/qolc_blowtorch.txt points OnCreate at this function")
end)

--// Sandbox Numbers
-- Asked for by a player. Both default to what this feature always shipped, so the tests
-- above read the defaults and these read a server that changed them.
Test("the torch takes its uses from the sandbox", function()
	SandboxVars.QoLC.BlowtorchUses = 25
	Harness.Fire("OnInitGlobalModData")

	local Item = ScriptManager.instance:getItem("Base.BlowTorch")
	AssertNear(Item:getUseDelta(), 1 / 25, 0.0000005, "torch UseDelta")
end)

Test("a tank gives as many refills as the sandbox asks", function()
	SandboxVars.QoLC.BlowtorchRefills = 12
	AssertEquals(CountRefillsPerTank(), 12, "refills per tank")
end)

Test("a save from before the numbers existed keeps sixteen and thirty", function()
	SandboxVars.QoLC.BlowtorchUses = nil
	SandboxVars.QoLC.BlowtorchRefills = nil
	Harness.Fire("OnInitGlobalModData")

	local Item = ScriptManager.instance:getItem("Base.BlowTorch")
	AssertNear(Item:getUseDelta(), 1 / 16, 0.0000005, "torch UseDelta")
	AssertEquals(CountRefillsPerTank(), 30, "refills per tank")
end)

--// Switched Off
-- Off has to mean vanilla. The hook is named in a script file, so it runs whatever the
-- switch says, and it used to refill a vanilla torch at our rate: about three hundred
-- welds a tank against vanilla's seventy one.
Test("switched off, the torch keeps vanilla's ten uses", function()
	SandboxVars.QoLC.BlowtorchEnabled = false
	Harness.Fire("OnInitGlobalModData")

	local Item = ScriptManager.instance:getItem("Base.BlowTorch")
	AssertEquals(Item:getUseDelta(), 0.1, "the script is left as vanilla wrote it")
end)

Test("switched off, a refill costs what vanilla charges", function()
	-- RecipeCodeOnCreate.refillBlowTorch: the torch's uses times 70 tank units each
	SandboxVars.QoLC.BlowtorchEnabled = false

	local Tank = NewTank(1)
	Refill(Harness.NewDrainable(10, 0), Tank)

	local Spent = TANK_MAX_USES - (Tank:getCurrentUsesFloat() * TANK_MAX_USES)
	AssertNear(Spent, 700, 0.001, "ten uses at seventy each")
	AssertEquals(CountRefillsPerTank(10), 7, "so a tank gives vanilla's seven")
end)

Test("switched off, the sandbox numbers are ignored", function()
	SandboxVars.QoLC.BlowtorchEnabled = false
	SandboxVars.QoLC.BlowtorchRefills = 100

	AssertEquals(CountRefillsPerTank(10), 7, "still vanilla's seven")
end)
