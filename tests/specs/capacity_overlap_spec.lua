--// Fix Capacity Overlap Spec
--// aspctt - 11.08.2026
--// The harness measures six pixels a character, so every position below is exact rather
--// than approximate. A 400 wide window puts the pin button at 360, so vanilla draws the
--// weight ending at 359 and reserves 114 for it, "9999.99 / 9999" at 84 plus 30.

--// Helpers
local function Render(WeightLabel, Title, Width)
	local Page = Harness.NewLootWindow(Title or "Crate", WeightLabel, Width)
	Page:prerender()
	return Page
end

local function TitleDraw(Page)
	return Page:Find(Page.title)
end

local function WeightDraw(Page)
	for _, Draw in ipairs(Page.Drawn) do
		if Draw.Text ~= Page.title then return Draw end
	end
	return nil
end

--// Wiring
Test("vanilla still draws the window", function()
	local Page = Render()
	AssertEquals(Page.VanillaPrerenders, 1, "wrapped, not replaced")
	AssertEquals(#Page.Drawn, 2, "the weight and the title, both still drawn")
end)

Test("the weight is left exactly where vanilla put it", function()
	-- Only the title moves. The weight is anchored to the pin button and is not ours.
	local Page = Render("12.34 / 50")
	AssertEquals(WeightDraw(Page).X, 359, "still ending at the pin button")
end)

--// The Overlap
Test("a long weight no longer runs under the title", function()
	-- What a multiplayer server with ItemNumbersLimitPerContainer prints. Twenty one
	-- characters is 126 wide, so it starts at 233, well left of the 266 vanilla reserves.
	local Page = Render("12.34 / 50 (20 / 100)")

	local Title = TitleDraw(Page)
	local Weight = WeightDraw(Page)

	AssertEquals(Weight.Left, 233, "the weight starts here")
	AssertTrue(Title.X <= Weight.Left, "and the title has to end before it")
	AssertEquals(Title.X, 223, "a ten pixel gap short of it")
end)

Test("vanilla really does overlap without this", function()
	-- Proves the test above is measuring a real fault rather than an arbitrary number.
	-- Vanilla reserves from a placeholder, so it puts the title's end at 266 while the
	-- weight begins at 233.
	local Reserved = getTextManager():MeasureStringX(UIFont.Small, "9999.99 / 9999") + 30
	local VanillaTitleEnd = 400 - 20 - Reserved

	AssertEquals(VanillaTitleEnd, 266, "where vanilla would have ended the title")
	AssertTrue(VanillaTitleEnd > 233, "which is past where a long weight starts")
end)

Test("a short weight gives the title more room, not less", function()
	-- The fix is not simply "move it left". A short label should free space up.
	local Page = Render("12.34 / 50")
	AssertEquals(TitleDraw(Page).X, 289, "further right than vanilla's fixed 266")
end)

Test("the gap holds whatever the weight says", function()
	for _, Label in ipairs({ "1 / 2", "12.34 / 50", "9999.99 / 9999 (999 / 999)" }) do
		local Page = Render(Label)
		AssertEquals(TitleDraw(Page).X, WeightDraw(Page).Left - 10,
			"ten pixels clear of " .. Label)
	end
end)

--// Leaving Things Alone
Test("the character's own inventory is untouched", function()
	local Page = Harness.NewLootWindow("Bob's Inventory", "12.34 / 50")
	Page.onCharacter = true
	Page:prerender()

	AssertEquals(Page.VanillaPrerenders, 1, "still drawn")
	AssertNil(TitleDraw(Page), "vanilla draws that title on the left, not right aligned")
end)

Test("a window with no title is passed straight through", function()
	local Page = Harness.NewLootWindow(nil, "12.34 / 50")
	Page.title = nil
	Page:prerender()

	AssertEquals(Page.VanillaPrerenders, 1, "vanilla still runs")
end)

Test("a title vanilla has added to is still recognised", function()
	-- Vanilla appends the campfire's fuel and the occupied seat note to the title before
	-- drawing it, so matching the whole string rather than its start would miss it
	local Page = Harness.NewLootWindow("Campfire", "12.34 / 50")
	Page.titleSuffix = ": 3 hours"
	Page:prerender()

	local Title = Page:Find("Campfire: 3 hours")
	AssertNotNil(Title, "the appended title should still have been drawn")
	AssertEquals(Title.X, 289, "and moved with the rest")
end)

Test("the draw override is not left behind", function()
	-- Left in place it would stack on every frame the window is open
	local Page = Harness.NewLootWindow("Crate", "12.34 / 50")
	local Before = Page.drawTextRight

	Page:prerender()
	AssertEquals(Page.drawTextRight, Before, "whatever was there must be put back")

	Page:prerender()
	AssertEquals(TitleDraw(Page).X, 289, "and a second frame reads the same")
end)
