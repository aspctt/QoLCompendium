--// Reading Is Not Boring Spec
--// aspctt - 18.08.2026

--// Helpers
local function Reader(Stats)
	local Player = Harness.NewPlayer(0, true)

	for Stat, Value in pairs(Stats or {}) do
		Player:getStats():set(CharacterStat[Stat], Value)
	end

	return Player
end

-- Turns enough of the book to pass at least one page, then hands back the stats
local function ReadAPage(Player, Book, Delta)
	local Action = Harness.NewReading(Player, Book or Harness.NewSkillBook("Carpentry", 1, 100))
	Action:Advance(Delta or 0.05)
	return Action
end

local function Boredom(Player) return Player:getStats():get(CharacterStat.BOREDOM) end
local function Unhappy(Player) return Player:getStats():get(CharacterStat.UNHAPPINESS) end
local function Stress(Player) return Player:getStats():get(CharacterStat.STRESS) end

--// Easing The Stats
Test("turning a page eases boredom", function()
	local Player = Reader({ BOREDOM = 50 })
	ReadAPage(Player)

	-- Over the threshold, so a tenth of what is there
	AssertNear(Boredom(Player), 45, 0.001, "50 less a tenth")
end)

Test("a nearly settled character eases more slowly", function()
	-- Under the threshold the smaller share applies, so the last of the boredom is not
	-- wiped out by one page
	local Player = Reader({ BOREDOM = 20 })
	ReadAPage(Player)

	AssertNear(Boredom(Player), 19, 0.001, "20 less a twentieth")
end)

Test("turning a page eases unhappiness", function()
	local Player = Reader({ UNHAPPINESS = 50 })
	ReadAPage(Player)

	AssertNear(Unhappy(Player), 47.5, 0.001, "50 less a twentieth")
end)

Test("turning a page eases stress", function()
	local Player = Reader({ STRESS = 0.8 })
	ReadAPage(Player)

	AssertNear(Stress(Player), 0.76, 0.0001, "0.8 less a twentieth")
end)

Test("easing never reaches zero", function()
	-- Proportional, so a hundred pages settles a character without ever finishing
	local Player = Reader({ BOREDOM = 100 })
	local Book = Harness.NewSkillBook("Carpentry", 1, 100)
	local Action = Harness.NewReading(Player, Book)

	for Page = 1, 100 do Action:Advance(Page / 100) end

	AssertTrue(Boredom(Player) > 0, "should still be above zero, got " .. tostring(Boredom(Player)))
	AssertTrue(Boredom(Player) < 1, "but well down, got " .. tostring(Boredom(Player)))
end)

--// What Counts As Reading
Test("no page turned changes nothing", function()
	local Player = Reader({ BOREDOM = 50 })
	local Action = Harness.NewReading(Player, Harness.NewSkillBook("Carpentry", 1, 100))

	Action:Advance(0.001)
	AssertNear(Boredom(Player), 50, 0.001, "not far enough in for a page")
end)

Test("the same page twice only counts once", function()
	local Player = Reader({ BOREDOM = 50 })
	local Action = Harness.NewReading(Player, Harness.NewSkillBook("Carpentry", 1, 100))

	Action:Advance(0.05)
	Action:Advance(0.05)
	Action:Advance(0.05)

	AssertNear(Boredom(Player), 45, 0.001, "three updates, one page")
end)

Test("a book that is not a skill book is left alone", function()
	-- The original fired on anything with pages, which stacked on top of the morale a
	-- comic already gives through its own UnhappyChange
	local Player = Reader({ BOREDOM = 50 })
	local Comic = Harness.NewSkillBook("Carpentry", 1, 100)
	Comic.Skill = "ComicBook"

	ReadAPage(Player, Comic)
	AssertNear(Boredom(Player), 50, 0.001, "not a skill book, not our business")
end)

Test("a book with no pages is harmless", function()
	local Player = Reader({ BOREDOM = 50 })
	ReadAPage(Player, Harness.NewSkillBook("Carpentry", 1, 0))

	AssertNear(Boredom(Player), 50, 0.001, "nothing to turn")
end)

--// Multiplayer
Test("it still works on a multiplayer client", function()
	-- The reason this is not a port. Vanilla only advances the item's page count inside
	-- "if not isClient()", so a mod reading that count never fires on a client at all.
	Harness.IsClient = true

	local Player = Reader({ BOREDOM = 50 })
	local Book = Harness.NewSkillBook("Carpentry", 1, 100)
	ReadAPage(Player, Book)

	AssertEquals(Book:getAlreadyReadPages(), 0, "the item's own count should not have moved")
	AssertNear(Boredom(Player), 45, 0.001, "but the page still counted")
end)

--// Traits And Illness
Test("a fast reader gets less from each page", function()
	local Player = Reader({ BOREDOM = 50 })
	Player:setTrait(CharacterTrait.FAST_READER, true)
	ReadAPage(Player)

	-- Seven tenths of the usual five, because they turn more pages in the same minute
	AssertNear(Boredom(Player), 46.5, 0.001, "reduced share")
end)

Test("a slow reader gets more from each page", function()
	local Player = Reader({ BOREDOM = 50 })
	Player:setTrait(CharacterTrait.SLOW_READER, true)
	ReadAPage(Player)

	AssertNear(Boredom(Player), 43.5, 0.001, "raised share")
end)

Test("illness takes the good out of it", function()
	local Player = Reader({ BOREDOM = 50 })
	Player:getBodyDamage():setFakeInfectionLevel(50)
	ReadAPage(Player)

	-- Halfway between full effect and none, so half of five
	AssertNear(Boredom(Player), 47.5, 0.001, "half the usual")
end)

Test("a character who feels really ill gets nothing", function()
	local Player = Reader({ BOREDOM = 50 })
	Player:getBodyDamage():setFakeInfectionLevel(75)
	ReadAPage(Player)

	AssertNear(Boredom(Player), 50, 0.001, "no comfort in a book at this point")
end)

--// Nicotine
Test("stress from wanting a cigarette is left where it is", function()
	-- A cigarette fixes withdrawal, a book does not. The original subtracted it and wrote
	-- the remainder back, which cleared the withdrawal outright.
	local Player = Reader({ STRESS = 0.8 })
	Player:getStats():setNicotineStress(0.6)
	ReadAPage(Player)

	-- Only the 0.2 above the nicotine floor is touched, and it is under the threshold
	AssertNear(Stress(Player), 0.796, 0.0001, "0.8 less a fiftieth of 0.2")
end)

Test("a character whose stress is all nicotine gets no relief", function()
	local Player = Reader({ STRESS = 0.5 })
	Player:getStats():setNicotineStress(0.5)
	ReadAPage(Player)

	AssertNear(Stress(Player), 0.5, 0.0001, "nothing above the floor to ease")
end)

--// Options
Test("turning it off changes nothing", function()
	SandboxVars.QoLC.ReadingCalmEnabled = false

	local Player = Reader({ BOREDOM = 50 })
	ReadAPage(Player)

	AssertNear(Boredom(Player), 50, 0.001, "off means off")
end)

Test("the rate scales the whole effect", function()
	SandboxVars.QoLC.ReadingCalmRate = 200

	local Player = Reader({ BOREDOM = 50 })
	ReadAPage(Player)

	AssertNear(Boredom(Player), 40, 0.001, "twice the usual five")
end)

Test("a rate of zero is the same as off", function()
	SandboxVars.QoLC.ReadingCalmRate = 0

	local Player = Reader({ BOREDOM = 50 })
	ReadAPage(Player)

	AssertNear(Boredom(Player), 50, 0.001, "nothing at all")
end)

Test("a save made before this existed still reads", function()
	Harness.ClearSandbox()

	local Player = Reader({ BOREDOM = 50 })
	ReadAPage(Player)

	AssertNear(Boredom(Player), 45, 0.001, "falls back to the shipped defaults")
end)

Test("both settings are on the sandbox page", function()
	AssertNotNil(QOLC_SANDBOX_DEFAULTS["ReadingCalmEnabled"], "the switch")
	AssertNotNil(QOLC_SANDBOX_DEFAULTS["ReadingCalmRate"], "the rate")
end)

Test("every label resolves", function()
	local Keys = {
		"Sandbox_QoLC_ReadingCalmEnabled", "Sandbox_QoLC_ReadingCalmEnabled_tooltip",
		"Sandbox_QoLC_ReadingCalmRate", "Sandbox_QoLC_ReadingCalmRate_tooltip"
	}

	for _, Key in ipairs(Keys) do
		AssertNotNil(Translations[Key], "missing translation for " .. Key)
	end
end)
