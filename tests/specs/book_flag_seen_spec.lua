--// Flag Books As Seen Spec
--// aspctt - 11.08.2026

--// Helpers
local READ_ONE_PAGE = "ContextMenu_QoLC_ReadOnePage"

-- A book two levels out of reach, which is what makes vanilla refuse it
local function Menu(Book, Player)
	Player = Player or Harness.NewPlayer(0, true)
	Book = Book or Harness.NewSkillBook("Carpentry", 3)

	local Context = Harness.NewContextMenu()
	ISInventoryPaneContextMenu.doLiteratureMenu(Context, { Book }, 0)

	return Context, Book, Player
end

local function Option(Context)
	for _, Entry in ipairs(Context.options) do
		if Entry.name == getText(READ_ONE_PAGE) then return Entry end
	end
	return nil
end

local function Perform()
	local Action = Harness.ActionQueue[#Harness.ActionQueue]
	Action:start()
	Action:perform()
	return Action
end

--// Wiring
Test("vanilla still builds the menu", function()
	-- Build 42's literature menu also handles darkness, illiteracy, pictures, books
	-- already read, empty notebooks and the recipe list. Replacing it would drop all of
	-- that, so it has to be wrapped.
	local Context = Menu()
	AssertTrue(#Context.options > 0, "vanilla's own entries must still be there")
end)

Test("a book within reach is left completely alone", function()
	local Context = Menu(Harness.NewSkillBook("Carpentry", 1))

	AssertNil(Option(Context), "nothing to flag, the character can just read it")
	AssertEquals(Context.options[1].name, getText("ContextMenu_Read"), "vanilla's read stands")
end)

--// The Option
Test("a book out of reach offers its first page", function()
	local Context = Menu()
	local Entry = Option(Context)

	AssertNotNil(Entry, "the dead read entry should have become this")
	AssertFalse(Entry.notAvailable, "and it has to be clickable")
end)

Test("the option explains itself", function()
	local Entry = Option((Menu()))
	AssertEquals(Entry.toolTip.description, getText("Tooltip_QoLC_ReadOnePage"), "tooltip")
end)

Test("an illiterate character is not offered it", function()
	local Player = Harness.NewPlayer(0, true)
	Player:setTrait(CharacterTrait.ILLITERATE, true)

	AssertNil(Option((Menu(nil, Player))), "a page teaches them nothing")
end)

Test("a sleeping character is not offered it", function()
	local Player = Harness.NewPlayer(0, true)
	Player.Asleep = true

	AssertNil(Option((Menu(nil, Player))), "vanilla refuses every other read while asleep")
end)

Test("a book already seen is not offered it again", function()
	local Player = Harness.NewPlayer(0, true)
	local Book = Harness.NewSkillBook("Carpentry", 3)
	Player:setAlreadyReadPages(Book:getFullType(), 1)

	AssertNil(Option((Menu(Book, Player))), "nothing left to gain, vanilla's refusal stands")
end)

Test("a book with no pages is not offered it", function()
	-- Progress is counted in pages, so there is nothing to record on one that has none
	AssertNil(Option((Menu(Harness.NewSkillBook("Carpentry", 3, 0)))), "no pages, no flag")
end)

--// Reading It
Test("choosing it queues the read", function()
	local Context, Book = Menu()
	Harness.ActionQueue = {}

	Option(Context):Click()
	AssertEquals(#Harness.ActionQueue, 1, "one action queued")
	AssertEquals(Harness.ActionQueue[1].item, Book, "for the book that was refused")
end)

Test("reading the page marks the book", function()
	local Context, Book, Player = Menu()
	Harness.ActionQueue = {}

	Option(Context):Click()
	Perform()

	AssertEquals(Player:getAlreadyReadPages(Book:getFullType()), 1, "one page, on the book type")
end)

Test("the character says something about it", function()
	local Context, _Book, Player = Menu()
	Harness.ActionQueue = {}

	Option(Context):Click()
	Perform()

	AssertEquals(#Player.Said, 1, "exactly one line")
	AssertNotNil(Translations[Player.Said[1]] or Player.Said[1], "and it resolves")
end)

Test("real progress is never thrown away", function()
	-- Studying the book properly writes a real page count. Reaching for this afterwards
	-- must not reset it to one.
	local Player = Harness.NewPlayer(0, true)
	local Book = Harness.NewSkillBook("Carpentry", 3)
	Player:setAlreadyReadPages(Book:getFullType(), 90)

	ISTimedActionQueue.add(QolcFlagBookAction:new(Player, Book))
	Perform()

	AssertEquals(Player:getAlreadyReadPages(Book:getFullType()), 90, "ninety pages stay ninety")
end)

Test("it stops if the book leaves the inventory", function()
	local Player = Harness.NewPlayer(0, true)
	local Book = Harness.NewSkillBook("Carpentry", 3)
	local Action = QolcFlagBookAction:new(Player, Book)

	AssertFalse(Action:isValid(), "the book was never in a bag here")

	Player.Inventory.Items = { Book }
	AssertTrue(Action:isValid(), "and valid once it is")
end)

Test("it stops when it is too dark to read", function()
	local Player = Harness.NewPlayer(0, true)
	local Book = Harness.NewSkillBook("Carpentry", 3)
	Player.Inventory.Items = { Book }
	Player.TooDark = true

	AssertFalse(QolcFlagBookAction:new(Player, Book):isValid(), "vanilla refuses reading in the dark")
end)

--// Translations
Test("every label resolves", function()
	local Keys = {
		"ContextMenu_QoLC_ReadOnePage",
		"Tooltip_QoLC_ReadOnePage",
		"IGUI_QoLC_FlaggedBook1",
		"IGUI_QoLC_FlaggedBook2",
		"IGUI_QoLC_FlaggedBook3"
	}

	for _, Key in ipairs(Keys) do
		AssertNotNil(Translations[Key], "missing translation for " .. Key)
	end
end)
