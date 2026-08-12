--// Skill Book Icons Spec
--// aspctt - 11.08.2026

--// Helpers
local function Apply()
	Harness.Fire("OnInitGlobalModData")
end

local function Item(Family, Volume)
	return ScriptManager.instance:getItem("Base.Book" .. Family .. tostring(Volume or 1))
end

--// Coverage
Test("every skill book in this build gets an icon", function()
	-- The original set is build 41 and covers eleven families. Build 42 has twenty four,
	-- which is the whole reason the missing ones were generated.
	Apply()

	for _, Family in ipairs(Harness.SkillBookFamilies) do
		for Volume = 1, 5 do
			AssertEquals(Item(Family, Volume):getIcon(), "QolcBook" .. Family .. tostring(Volume),
				Family .. " volume " .. tostring(Volume) .. " kept the vanilla icon")
		end
	end
end)

Test("every icon it names is actually shipped", function()
	-- The bug this is here for: the original mod's own lua asks for book_rice_Blacksmith1
	-- through 5 and ships no such files. An Icon naming a texture that is not there draws
	-- nothing at all and says nothing about it.
	Apply()

	for _, Family in ipairs(Harness.SkillBookFamilies) do
		for Volume = 1, 5 do
			local Icon = Item(Family, Volume):getIcon()
			AssertTrue(QOLC_ITEM_ICONS[Icon],
				"no texture shipped for " .. tostring(Icon) .. ", it would draw nothing")
		end
	end
end)

Test("each volume of a family gets its own icon", function()
	Apply()

	local Seen = {}
	for _, Family in ipairs(Harness.SkillBookFamilies) do
		for Volume = 1, 5 do
			local Icon = Item(Family, Volume):getIcon()
			AssertNil(Seen[Icon], "two books share the icon " .. tostring(Icon))
			Seen[Icon] = true
		end
	end
end)

--// The Vanilla Tint
Test("the colour mask is replaced on the families that carry one", function()
	-- Build 42 draws ten families as one sprite tinted through a mask. Left alone, that
	-- mask is painted over our icon in vanilla's colour, in the shape of a different book.
	Apply()

	for _, Family in ipairs({ "Blacksmith", "Butchering", "Carving", "Tailoring", "Tracking" }) do
		AssertEquals(Item(Family):QolcIconColorMask(), "QolcBookNoTint",
			Family .. " would still be tinted over the top")
	end
end)

Test("the mask is set even where vanilla has none", function()
	-- It costs a draw of nothing and it means a book the game starts tinting in a later
	-- build is already covered. It also forces the icon itself to be drawn untinted.
	Apply()

	AssertEquals(Item("Carpentry"):QolcIconColorMask(), "QolcBookNoTint", "Carpentry")
	AssertEquals(Item("Aiming"):QolcIconColorMask(), "QolcBookNoTint", "Aiming")
end)

Test("the mask texture exists and is a real file", function()
	AssertTrue(QOLC_ITEM_ICONS["QolcBookNoTint"],
		"without it setTextureColorMask falls back to the question mark texture")
end)

--// Behaviour
Test("the icon is compared before it is written", function()
	-- The mask has no getter, so it is rewritten every pass. The icon does, so it must
	-- not be: a book already carrying our icon should cost nothing on a second init.
	Apply()
	local Before = Harness.DoParamsFor["Base.BookCarpentry1"]

	Apply()
	AssertEquals(Harness.DoParamsFor["Base.BookCarpentry1"], Before + 1,
		"one write for the mask, none for an icon that already matches")
end)

Test("a book the game no longer has is reported, not fatal", function()
	Harness.ScriptItems["Base.BookTrapping5"] = nil

	Apply()
	AssertEquals(Item("Trapping", 1):getIcon(), "QolcBookTrapping1", "the rest still apply")
end)

Test("nothing but skill books is touched", function()
	Apply()

	AssertEquals(ScriptManager.instance:getItem("Base.Tshirt"):getIcon(), nil, "clothing")
	AssertEquals(ScriptManager.instance:getItem("Base.Axe"):getIcon(), nil, "tools")
end)
