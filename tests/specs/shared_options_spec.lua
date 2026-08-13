Test("both features share one options category", function()
	AssertEquals(#PZAPI.ModOptions.Data, 1, "there should be exactly one heading on the Mods page")
	AssertEquals(PZAPI.ModOptions.Data[1].modOptionsID, "QoLC", "shared category id")

	-- Every feature with client settings contributes one title into the shared category.
	-- Named rather than counted, so adding a feature fails here until it is listed, and
	-- a feature that quietly loses its heading fails too.
	local Expected = {
		"UI_options_QoLC_BiggerAvatar",
		"UI_options_QoLC_Overlays",
		"UI_options_QoLC_Condition",
		"UI_options_QoLC_Reorder"
	}

	local Category = PZAPI.ModOptions:getOptions("QoLC")
	local Titles = {}
	for _, Entry in ipairs(Category.data) do
		if Entry.type == "title" then Titles[Entry.name] = true end
	end

	local Count = 0
	for Name in pairs(Titles) do
		Count = Count + 1
		AssertNotNil(Translations[Name], "title has no translation: " .. tostring(Name))
	end

	for _, Name in ipairs(Expected) do
		AssertTrue(Titles[Name], "missing the heading for " .. Name)
	end

	AssertEquals(Count, #Expected, "one title per feature, and no strays")
	AssertNotNil(Translations["UI_options_QoLC"], "the category heading needs a translation")
end)

Test("option ids are unique across the shared category", function()
	local Category = PZAPI.ModOptions:getOptions("QoLC")
	local Seen = {}
	for _, Option in ipairs(Category.data) do
		if Option.id then
			AssertNil(Seen[Option.id], "duplicate option id in the shared category: " .. tostring(Option.id))
			Seen[Option.id] = true
		end
	end
end)
