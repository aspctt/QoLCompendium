--// Tailoring Fix Spec
--// aspctt - 11.08.2026

--// Helpers
-- A garment defaults to a pristine seven part jacket, which is seven strips
local function Garment(Fabric, Type, Covered, Holes, Patches)
	return Harness.NewGarment(Fabric, Type, Covered, Holes, Patches)
end

-- Runs one craft the way the game does, through the method vanilla performs a recipe in
local function Cut(RecipeName, Item, Tool)
	local Player = Harness.NewPlayer(0, true)
	local Data = Harness.NewCraftRecipeData(nil, Item, Tool)
	local Action = Harness.NewHandcraftAction(Player, Harness.NewCraftRecipe(RecipeName), Data)

	Action:performRecipe()
	return Action, Player
end

local function XpFor(RecipeName, Item, Tool)
	Harness.ClearXp()
	Cut(RecipeName, Item, Tool)
	return Harness.Xp[Perks.Tailoring] or 0
end

local function DurationAt(RecipeName, Level, Time)
	local Player = Harness.NewPlayer(0, true)
	Player:setPerkLevel(Perks.Tailoring, Level)

	local Action = Harness.NewHandcraftAction(Player, Harness.NewCraftRecipe(RecipeName, Time), nil)
	return Action:getDuration()
end

--// Wiring
Test("the craft is still performed, exactly once", function()
	local Action = Cut("RipDenimClothing", Garment("Denim"))
	AssertEquals(Action.VanillaPerforms, 1, "vanilla still has to make the strips itself")
end)

Test("a recipe that is not a rip is left alone", function()
	-- Leather rather than cotton on purpose. Cotton is worth nothing anyway, so a cotton
	-- garment here would pass whether the recipe was checked or not.
	Harness.ClearXp()
	local Action = Cut("SewRagBandana", Garment("Leather"))

	AssertEquals(Action.VanillaPerforms, 1, "still performed")
	AssertEquals(Harness.Xp[Perks.Tailoring], nil, "vanilla already awards its own experience")
end)

Test("the garment is measured before the craft destroys it", function()
	-- performRecipe eats its own inputs, so reading the garment afterwards finds nothing
	-- and the award silently collapses to zero
	Harness.ClearXp()
	local Data = Harness.NewCraftRecipeData(nil, Garment("Leather"), nil)
	local Action = Harness.NewHandcraftAction(Harness.NewPlayer(0, true),
		Harness.NewCraftRecipe("RipDenimClothing"), Data)

	Action:performRecipe()

	AssertEquals(Data:getAllInputItems():size(), 0, "the stub has to consume them, or this proves nothing")
	AssertNear(Harness.Xp[Perks.Tailoring], 3.5, 0.0001, "measured while the garment still existed")
end)

Test("a rip with nothing to cut awards nothing", function()
	-- Scissors alone carry no fabric, so there is no garment to measure
	AssertEquals(XpFor("RipDenimClothing", nil, Harness.NewInventoryItem("Scissors")), 0,
		"no garment, no experience")
end)

--// The Award
Test("cutting denim pays by the strip", function()
	-- Seven covered parts is seven strips, at the denim rate of a fifth each
	AssertNear(XpFor("RipDenimClothing", Garment("Denim")), 1.4, 0.0001, "seven strips of denim")
end)

Test("leather is worth more than denim", function()
	local Leather = XpFor("RipDenimClothing", Garment("Leather"))
	local Denim = XpFor("RipDenimClothing", Garment("Denim"))

	AssertNear(Leather, 3.5, 0.0001, "seven strips of leather")
	AssertTrue(Leather > Denim, "leather is the harder material to work")
end)

Test("cotton pays nothing", function()
	-- Deliberate. Cotton rips by hand with no tool at all and is the most common thing
	-- in the world, so paying for it would make the skill free.
	AssertEquals(XpFor("RipClothing", Garment("Cotton")), 0, "ripping a t-shirt teaches nothing")
end)

Test("a fabric the game adds later is worth something", function()
	-- Untranslated rather than unrewarded, the same call the fabric tooltip makes. Cotton
	-- is the only deliberate zero, so a new material must not silently join it.
	AssertTrue(XpFor("RipDenimClothing", Garment("Silk")) > 0, "an unknown fabric still pays")
end)

Test("a bigger garment is worth more than a smaller one", function()
	local Jacket = XpFor("RipDenimClothing", Garment("Denim", "Base.Jacket_Test", 7))
	local Shorts = XpFor("RipDenimClothing", Garment("Denim", "Base.Shorts_Test", 2))

	AssertTrue(Jacket > Shorts, "seven parts of denim beats two")
end)

--// Wear
Test("holes and patches cut the strip count the way the game does", function()
	-- max(covered - (holes + patches), 1), taken from RecipeCodeOnCreate.ripClothing.
	-- Paying for strips the garment will not actually yield would reward wrecking clothes.
	local Whole = XpFor("RipDenimClothing", Garment("Denim", "Base.Jacket_Test", 7, 0, 0))
	local Holed = XpFor("RipDenimClothing", Garment("Denim", "Base.Jacket_Test", 7, 3, 0))
	local Patched = XpFor("RipDenimClothing", Garment("Denim", "Base.Jacket_Test", 7, 0, 3))

	AssertNear(Holed, 0.8, 0.0001, "four strips left")
	AssertEquals(Patched, Holed, "a patch costs the same as the hole under it")
	AssertTrue(Whole > Holed, "an intact garment is worth more")
end)

Test("a garment past saving still yields one strip and no more", function()
	local Ruined = XpFor("RipDenimClothing", Garment("Denim", "Base.Jacket_Test", 7, 20, 0))
	AssertNear(Ruined, 0.2, 0.0001, "floored at one strip, never negative")
end)

--// Uniforms
Test("a uniform pays a bonus on top of its cloth", function()
	-- A police jacket is cotton, so without the bonus it would be worth nothing at all.
	-- That is the whole reason the bonus exists.
	local Uniform = XpFor("RipClothing", Garment("Cotton", "Base.Jacket_Police"))
	local Plain = XpFor("RipClothing", Garment("Cotton", "Base.Jacket_Test"))

	AssertEquals(Plain, 0, "a plain cotton jacket teaches nothing")
	AssertNear(Uniform, 10, 0.0001, "a police jacket is worth the work in it")
end)

Test("the bonus stacks with the cloth rather than replacing it", function()
	-- Nothing on the list is denim today, but a mod retexturing one would be
	local Both = XpFor("RipDenimClothing", Garment("Denim", "Base.Jacket_Police"))
	AssertNear(Both, 11.4, 0.0001, "ten for the uniform, one and two fifths for the denim")
end)

Test("a wrecked uniform is not worth a whole one", function()
	-- The strip count already carries wear, but the bonus is flat, so without scaling it
	-- a ruined police jacket would pay exactly what a pristine one does.
	local Whole = XpFor("RipClothing", Garment("Cotton", "Base.Jacket_Police", 7, 0, 0))
	local Ruined = XpFor("RipClothing", Garment("Cotton", "Base.Jacket_Police", 7, 6, 0))

	AssertNear(Ruined, 10 / 7, 0.0001, "one seventh of it is left")
	AssertTrue(Ruined < Whole, "rags are not tailoring lessons")
end)

-- Whether every uniform on the list is still a real item in this build is checked by the
-- runner, which resolves each one against the game's own scripts before any test runs.
-- See checkItemTypes in tests/harness/TestRunner.java.

--// Speed
Test("cutting gets quicker as tailoring rises", function()
	-- Vanilla only shortens a craft for skills the recipe names, and ripping names none,
	-- so without this it takes as long at ten tailoring as at zero.
	local Novice = DurationAt("RipDenimClothing", 0, 80)
	local Expert = DurationAt("RipDenimClothing", 10, 80)

	AssertEquals(Novice, 400, "level zero is untouched, the vanilla eighty times five")
	AssertEquals(Expert, 200, "ten levels at a twentieth each is half, vanilla's own most")
end)

Test("the speed up stops at ten levels", function()
	-- A mod raising the level cap must not be able to drive this to zero or below
	AssertEquals(DurationAt("RipDenimClothing", 40, 80), DurationAt("RipDenimClothing", 10, 80),
		"clamped at ten the way vanilla's own skills are")
end)

Test("other recipes keep vanilla timing", function()
	AssertEquals(DurationAt("SewRagBandana", 10, 80), 400, "not ours to speed up")
end)

Test("an instant craft stays instant", function()
	local Player = Harness.NewPlayer(0, true)
	Player:setPerkLevel(Perks.Tailoring, 10)
	function Player:isTimedActionInstant() return true end

	local Action = Harness.NewHandcraftAction(Player, Harness.NewCraftRecipe("RipDenimClothing", 80), nil)
	AssertEquals(Action:getDuration(), 1, "debug instant crafting must survive the override")
end)

Test("a recipe that reports no length is left alone", function()
	local Player = Harness.NewPlayer(0, true)
	local Action = Harness.NewHandcraftAction(Player, nil, nil)

	AssertEquals(Action:getDuration(), -1, "vanilla's own no-recipe answer must come back intact")
end)

--// Sandbox
Test("the rate scales what is awarded", function()
	Harness.ClearXp()
	SandboxVars.QoLC.TailoringCutXp = 50
	Cut("RipDenimClothing", Garment("Denim"))

	AssertNear(Harness.Xp[Perks.Tailoring], 0.7, 0.0001, "half of the usual one and two fifths")
end)

Test("a rate of zero awards nothing but still performs the craft", function()
	Harness.ClearXp()
	SandboxVars.QoLC.TailoringCutXp = 0
	local Action = Cut("RipDenimClothing", Garment("Leather"))

	AssertEquals(Harness.Xp[Perks.Tailoring], nil, "no experience at all")
	AssertEquals(Action.VanillaPerforms, 1, "the strips are still made")
end)

Test("turning the feature off returns ripping to vanilla", function()
	Harness.ClearXp()
	SandboxVars.QoLC.TailoringCutXpEnabled = false

	local Action = Cut("RipDenimClothing", Garment("Leather"))
	AssertEquals(Harness.Xp[Perks.Tailoring], nil, "no experience")
	AssertEquals(Action.VanillaPerforms, 1, "still performed")

	AssertEquals(DurationAt("RipDenimClothing", 10, 80), 400, "and no speed up either")
end)

Test("a save made before this feature existed still works", function()
	-- Sandbox values are written when a save is made, so an older one has none of these
	Harness.ClearSandbox()
	Harness.ClearXp()

	Cut("RipDenimClothing", Garment("Denim"))
	AssertNear(Harness.Xp[Perks.Tailoring], 1.4, 0.0001, "falls back to the declared defaults")
end)

--// Multiplayer
Test("a multiplayer client awards nothing itself", function()
	-- The server owns skills. addXp is deliberately a no-op on a client, which is what
	-- lets this live in shared code and be correct on all three of client, server and
	-- singleplayer without asking where it is running.
	Harness.ClearXp()
	Harness.IsClient = true

	local Action = Cut("RipDenimClothing", Garment("Leather"))
	AssertEquals(Harness.Xp[Perks.Tailoring], nil, "the server sends the experience back")
	AssertEquals(Action.VanillaPerforms, 1, "and the craft is untouched")

	Harness.IsClient = false
end)

Test("a server awards the experience for the crafting player", function()
	Harness.ClearXp()
	Harness.IsServer = true

	Cut("RipDenimClothing", Garment("Leather"))
	AssertNear(Harness.Xp[Perks.Tailoring], 3.5, 0.0001, "the server is the authority")

	Harness.IsServer = false
end)

Test("nothing is transmitted by hand", function()
	-- addXp already carries itself over the network. A transmitModData on top would send
	-- the player's entire mod data on every cut.
	local Player = Harness.NewPlayer(0, true)
	local Data = Harness.NewCraftRecipeData(nil, Garment("Leather"), nil)
	local Action = Harness.NewHandcraftAction(Player, Harness.NewCraftRecipe("RipDenimClothing"), Data)

	Action:performRecipe()
	AssertEquals(Player.Transmits, 0, "no mod data goes over the wire for this")
end)
