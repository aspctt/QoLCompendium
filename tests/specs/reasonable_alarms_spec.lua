--// Reasonable Crime Prevention Alarm Spec
--// aspctt - 18.08.2026

--// Helpers
-- The mod decides at world load whether it is worth listening at all, so every spec has
-- to go through OnInitWorld rather than calling into the file directly.
local function StartWorld()
	Harness.Fire("OnInitWorld")
end

local function Load(Square)
	Harness.Fire("LoadGridsquare", Square)
end

local function SetRule(Value)
	SandboxVars.QoLC.AlarmHouseRule = Value
end

-- A house with one door on it, the door's own square being inside the building
local function House(DoorValues, Alarmed)
	local Def = Harness.NewBuildingDef(Alarmed ~= false)
	local Square = Harness.NewAlarmSquare(Def, {})
	Square.Objects = { Harness.NewDoor(DoorValues, Square, nil) }

	return Def, Square
end

local function HouseWithWindow(WindowValues, Alarmed)
	local Def = Harness.NewBuildingDef(Alarmed ~= false)
	local Square = Harness.NewAlarmSquare(Def, {})
	Square.Objects = { Harness.NewWindow(WindowValues, Square, nil) }

	return Def, Square
end

-- A vehicle sitting on a square, everything shut unless the spec says otherwise
local function Car(Values, Parts)
	local Vehicle = Harness.NewAlarmVehicle(Values, Parts)
	return Vehicle, Harness.NewAlarmSquare(nil, {}, Vehicle)
end

local LOCKED_TIGHT = { Locked = true, LockedByKey = true }

--// Wiring
Test("nothing listens until the world has loaded", function()
	AssertEquals(Harness.HandlerCount("LoadGridsquare"), 0,
		"registering at file scope would run on the title screen too")
end)

Test("a world with alarms gets a listener", function()
	StartWorld()
	AssertTrue(Harness.HandlerCount("LoadGridsquare") > 0, "should listen once the world exists")
end)

Test("a world with no alarms at all is never listened to", function()
	-- One is Never on both of vanilla's frequency settings. LoadGridsquare fires for
	-- every square that streams in, so the cheapest thing to do is not be there.
	SandboxVars.Alarm = 1
	SandboxVars.CarAlarm = 1
	StartWorld()

	AssertEquals(Harness.HandlerCount("LoadGridsquare"), 0, "no handler should be added")
end)

Test("turning both settings off leaves no listener either", function()
	SetRule(1)
	SandboxVars.QoLC.AlarmVehiclesEnabled = false
	StartWorld()

	AssertEquals(Harness.HandlerCount("LoadGridsquare"), 0, "nothing to do, nothing to hook")
end)

--// Houses
Test("a door standing open disarms the house", function()
	StartWorld()
	local Def, Square = House({ Open = true })

	Load(Square)
	AssertFalse(Def:isAlarmed(), "anyone could have walked in already")
end)

Test("a shut and locked house keeps its alarm", function()
	StartWorld()
	local Def, Square = House(LOCKED_TIGHT)

	Load(Square)
	AssertTrue(Def:isAlarmed(), "nothing about this house is open")
end)

Test("an interior door is not a way in", function()
	StartWorld()
	local Def, Square = House({ Open = true, Exterior = false })

	Load(Square)
	AssertTrue(Def:isAlarmed(), "an open bedroom door says nothing about the front door")
end)

Test("a smashed window disarms the house", function()
	StartWorld()
	local Def, Square = HouseWithWindow({ Destroyed = true })

	Load(Square)
	AssertFalse(Def:isAlarmed(), "the alarm has had its moment already")
end)

Test("an open window disarms the house", function()
	StartWorld()
	local Def, Square = HouseWithWindow({ Open = true })

	Load(Square)
	AssertFalse(Def:isAlarmed(), "open is open")
end)

Test("a closed window leaves the alarm alone", function()
	StartWorld()
	local Def, Square = HouseWithWindow({})

	Load(Square)
	AssertTrue(Def:isAlarmed(), "an intact window is not a way in")
end)

Test("the building on the far side of a door is still found", function()
	-- An exterior door sits in the wall, so the square it is on is often outside the
	-- building and only the opposite square knows which house it belongs to.
	StartWorld()
	local Def = Harness.NewBuildingDef(true)
	local Inside = Harness.NewAlarmSquare(Def, {})
	local Outside = Harness.NewAlarmSquare(nil, {})
	Outside.Objects = { Harness.NewDoor({ Open = true }, Outside, Inside) }

	Load(Outside)
	AssertFalse(Def:isAlarmed(), "the house is through the doorway")
end)

Test("a door belonging to no building is harmless", function()
	StartWorld()
	local Square = Harness.NewAlarmSquare(nil, {})
	Square.Objects = { Harness.NewDoor({ Open = true }, Square, nil) }

	Load(Square)
	AssertTrue(true, "a gate in a field should not throw")
end)

--// The House Rule
Test("an unlocked door disarms the house on the default setting", function()
	-- Vanilla rolls each door against lockedHouses and only a third of the locked ones
	-- need a key, so most exterior doors start unlocked. This is the broad setting.
	StartWorld()
	local Def, Square = House({})

	Load(Square)
	AssertFalse(Def:isAlarmed(), "unlocked counts on the default rule")
end)

Test("the middle setting wants a door actually standing open", function()
	SetRule(2)
	StartWorld()
	local Def, Square = House({})

	Load(Square)
	AssertTrue(Def:isAlarmed(), "unlocked is not open")
end)

Test("the middle setting still disarms an open door", function()
	SetRule(2)
	StartWorld()
	local Def, Square = House({ Open = true })

	Load(Square)
	AssertFalse(Def:isAlarmed(), "open is open on any setting")
end)

Test("the middle setting still disarms a smashed window", function()
	SetRule(2)
	StartWorld()
	local Def, Square = HouseWithWindow({ Destroyed = true })

	Load(Square)
	AssertFalse(Def:isAlarmed(), "a broken window is not a locking question")
end)

Test("turning houses off leaves every alarm alone", function()
	SetRule(1)
	StartWorld()
	local Def, Square = House({ Open = true })

	Load(Square)
	AssertTrue(Def:isAlarmed(), "off means off")
end)

Test("a door needing a key keeps the alarm even on the default rule", function()
	StartWorld()
	local Def, Square = House(LOCKED_TIGHT)

	Load(Square)
	AssertTrue(Def:isAlarmed(), "locked and keyed is the one case that survives")
end)

--// Vehicles
Test("an unlocked door disarms a car", function()
	StartWorld()
	local Vehicle, Square = Car({ DoorsLocked = false })

	Load(Square)
	AssertFalse(Vehicle:isAlarmed(), "left unlocked")
end)

Test("an unlocked trunk disarms a car", function()
	StartWorld()
	local Vehicle, Square = Car({ TrunkLocked = false })

	Load(Square)
	AssertFalse(Vehicle:isAlarmed(), "the trunk counts too")
end)

Test("a locked car with an open window is disarmed", function()
	StartWorld()
	local Vehicle, Square = Car({}, {
		Harness.NewAlarmVehiclePart("window", {}),
		Harness.NewAlarmVehiclePart("window", { Open = true })
	})

	Load(Square)
	AssertFalse(Vehicle:isAlarmed(), "locking the doors does not help with a window down")
end)

Test("a missing window disarms a car", function()
	-- Build 42 reports a smashed out window as the part having no item on it
	StartWorld()
	local Vehicle, Square = Car({}, { Harness.NewAlarmVehiclePart("window", { Missing = true }) })

	Load(Square)
	AssertFalse(Vehicle:isAlarmed(), "there is no window there at all")
end)

Test("a shut and locked car keeps its alarm", function()
	StartWorld()
	local Vehicle, Square = Car({}, {
		Harness.NewAlarmVehiclePart("door", {}),
		Harness.NewAlarmVehiclePart("window", {})
	})

	Load(Square)
	AssertTrue(Vehicle:isAlarmed(), "nothing about this car is open")
end)

Test("a car with no alarm is left alone", function()
	StartWorld()
	local Vehicle, Square = Car({ Alarmed = false, DoorsLocked = false })

	Load(Square)
	AssertFalse(Vehicle:isAlarmed(), "still not alarmed, and nothing threw on the way")
end)

Test("turning vehicles off leaves car alarms alone", function()
	SandboxVars.QoLC.AlarmVehiclesEnabled = false
	StartWorld()
	local Vehicle, Square = Car({ DoorsLocked = false })

	Load(Square)
	AssertTrue(Vehicle:isAlarmed(), "off means off")
end)

Test("a car alarm frequency of never skips vehicles", function()
	SandboxVars.CarAlarm = 1
	StartWorld()
	local Vehicle, Square = Car({ DoorsLocked = false })

	Load(Square)
	AssertTrue(Vehicle:isAlarmed(), "no car in this world should have had one anyway")
end)

--// Housekeeping
Test("a square with nothing on it is harmless", function()
	StartWorld()
	Load(Harness.NewAlarmSquare(nil, {}))
	AssertTrue(true, "most squares in the world look like this")
end)

Test("a save made before this existed still loads", function()
	Harness.ClearSandbox()
	StartWorld()
	local Def, Square = House({ Open = true })

	Load(Square)
	AssertFalse(Def:isAlarmed(), "falls back to the shipped defaults")
end)

Test("both settings are on the sandbox page", function()
	AssertNotNil(QOLC_SANDBOX_DEFAULTS["AlarmHouseRule"], "the house rule")
	AssertNotNil(QOLC_SANDBOX_DEFAULTS["AlarmVehiclesEnabled"], "the vehicle switch")
end)

Test("the house rule reaches lua as a number", function()
	-- An enum is its index in the game, not its text. Comparing a string to a number
	-- throws in lua, so this would be a crash on world load rather than a wrong setting.
	AssertEquals(type(SandboxVars.QoLC.AlarmHouseRule), "number", "enums arrive as numbers")
end)

Test("every label resolves", function()
	local Keys = {
		"Sandbox_QoLC_AlarmHouseRule", "Sandbox_QoLC_AlarmHouseRule_tooltip",
		"Sandbox_QoLC_AlarmHouseRule_option1", "Sandbox_QoLC_AlarmHouseRule_option2",
		"Sandbox_QoLC_AlarmHouseRule_option3",
		"Sandbox_QoLC_AlarmVehiclesEnabled", "Sandbox_QoLC_AlarmVehiclesEnabled_tooltip"
	}

	for _, Key in ipairs(Keys) do
		AssertNotNil(Translations[Key], "missing translation for " .. Key)
	end
end)
