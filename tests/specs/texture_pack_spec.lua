--// Texture Pack Spec
--// aspctt - 26.08.2026
--// The icons ship as one atlas rather than 143 loose files.
--//
--// Verified in the jar rather than assumed: Texture.getSharedTextureInternal normalises
--// the separators, strips the extension at the last dot, strips everything up to the last
--// slash, and asks TexturePackPage.getTexture for what is left, before it ever looks at
--// the file system. So the lua and the scripts still name these the way they always did.
--//
--// What this guards is the split. Three things have to stay in step: the source art in
--// tools/textures, the sprites in the pack, and what is left loose inside the mod. A file
--// in two of those places is two copies of one texture, and only one of them is drawn.

--// Helpers
local function Count(Table)
	local Total = 0
	for _ in pairs(Table or {}) do Total = Total + 1 end
	return Total
end

local function Sorted(Table)
	local Names = {}
	for Name in pairs(Table or {}) do table.insert(Names, Name) end
	table.sort(Names)
	return Names
end

--// The Pack
Test("the pack was built and holds something", function()
	AssertTrue(Count(QOLC_PACKED_SPRITES) > 0,
		"run python tools/pack_textures.py")
end)

Test("the pack and the source art it came from agree", function()
	-- tools/textures is the source of truth and the pack is written from it, so a sprite
	-- in one and not the other means the pass was not run after the art changed.
	local Missing, Extra = {}, {}

	for Name in pairs(QOLC_SOURCE_ART) do
		if not QOLC_PACKED_SPRITES[Name] then table.insert(Missing, Name) end
	end

	for Name in pairs(QOLC_PACKED_SPRITES) do
		if not QOLC_SOURCE_ART[Name] then table.insert(Extra, Name) end
	end

	AssertEquals(#Missing, 0, "art not packed: " .. table.concat(Missing, ", "))
	AssertEquals(#Extra, 0, "packed with no art behind it: " .. table.concat(Extra, ", "))
end)

Test("nothing is both packed and left loose in the mod", function()
	-- The pack is looked at first, so a loose copy of a packed sprite is never drawn. It
	-- would sit there being maintained and shipped for nothing, and drift.
	local Both = {}

	for Path in pairs(QOLC_LOOSE_TEXTURES) do
		local Name = Path:match("([^/]+)%.png$")
		if Name and QOLC_PACKED_SPRITES[Name] then table.insert(Both, Path) end
	end

	AssertEquals(#Both, 0, "packed and loose: " .. table.concat(Both, ", "))
end)

--// What The Scripts Ask For
Test("every skill book icon is in the pack", function()
	-- Named rather than counted, so a family dropped by the generator is not hidden by
	-- another being added in the same pass.
	for _, Family in ipairs({ "Aiming", "Blacksmith", "Butchering", "Carpentry", "Cooking" }) do
		for Volume = 1, 5 do
			local Name = "Item_QolcBook" .. Family .. Volume
			AssertTrue(QOLC_PACKED_SPRITES[Name] ~= nil, Name .. " should be packed")
		end
	end

	AssertTrue(QOLC_PACKED_SPRITES["Item_QolcBookNoTint"] ~= nil,
		"the colour mask has to be there or the tinting falls back to a question mark")
end)

Test("every ammo icon is in the pack", function()
	for _, Calibre in ipairs({ "308", "38", "44", "45", "556", "9mm", "Shotgun" }) do
		local Name = "Item_QolcAmmoBox" .. Calibre
		AssertTrue(QOLC_PACKED_SPRITES[Name] ~= nil, Name .. " should be packed")
	end
end)

Test("the interface glyphs the lua asks for by path are in the pack", function()
	-- These are still fetched as media/textures/GUI/x.png. The lookup throws the
	-- directory and the extension away before it reaches the pack, which is the whole
	-- reason none of the calling code had to change.
	for _, Name in ipairs({
		"qolc_lock_open", "qolc_lock_closed", "qolc_insert", "qolc_swap", "qolc_slot_disc"
	}) do
		AssertTrue(QOLC_PACKED_SPRITES[Name] ~= nil, Name .. " should be packed")
	end
end)

--// What Is Deliberately Not Packed
Test("the full screen overlays are left loose", function()
	-- 1920x1080 each. An atlas holding them would be nine times the width the base game's
	-- own pages stop at, and they are drawn one at a time over the whole screen, so there
	-- is no draw call to save by putting them beside a 32 pixel icon.
	for _, Name in ipairs({
		"qolc_damage", "qolc_hyperthermia", "qolc_hypothermia", "qolc_pain", "qolc_tired"
	}) do
		AssertNil(QOLC_PACKED_SPRITES[Name], Name .. " is a full screen overlay")
		AssertTrue(QOLC_LOOSE_TEXTURES["textures/GUI/" .. Name .. ".png"] ~= nil,
			Name .. " should still be a file")
	end
end)

Test("the sling's model texture is left loose", function()
	-- A model binds its texture whole and samples it with the mesh's own UVs, which run 0
	-- to 1 over the entire image, so a model pointed at an atlas draws a slice of every
	-- other sprite on the page. The base game ships its world item textures loose for the
	-- same reason.
	AssertNil(QOLC_PACKED_SPRITES["SlingTexture"], "a model cannot read an atlas")
	AssertTrue(QOLC_LOOSE_TEXTURES["textures/Clothes/Sling/SlingTexture.png"] ~= nil,
		"it should still be a file")
end)

Test("the moodle quarters plates are left loose", function()
	-- Forty eight files but only eight names, one set per size folder. A pack namespace is
	-- flat, so packing them would keep one size and lose five.
	for _, Size in ipairs({ 32, 48, 64, 80, 96, 128 }) do
		for Level = 1, 4 do
			for _, Kind in ipairs({ "good", "bad" }) do
				local Path = "ui/MoodleQuarters/" .. Size .. "/" .. Kind .. "_" .. Level .. ".png"
				AssertTrue(QOLC_LOOSE_TEXTURES[Path] ~= nil, Path .. " should still be a file")
			end
		end
	end

	for _, Name in ipairs({ "good_1", "bad_4" }) do
		AssertNil(QOLC_PACKED_SPRITES[Name], Name .. " is one name at six sizes")
	end
end)

--// Wiring
Test("the mod declares the pack", function()
	-- Without this line the game never loads the atlas and every icon in it silently
	-- draws nothing, which on a book cover is easy to miss.
	local Info = Harness.ReadModInfo()

	AssertNotNil(Info, "mod.info should be readable")
	AssertContains(Info, "pack=QoLCompendium", "mod.info must name the pack")
end)

Test("the loose textures left in the mod are only the ones named above", function()
	-- A backstop for the three tests before it: anything new that lands loose has to be
	-- a deliberate addition to this list rather than a file that quietly missed the pack.
	local Allowed = 5 + 1 + 48

	AssertEquals(Count(QOLC_LOOSE_TEXTURES), Allowed,
		"unexpected loose textures: " .. table.concat(Sorted(QOLC_LOOSE_TEXTURES), ", "))
end)
