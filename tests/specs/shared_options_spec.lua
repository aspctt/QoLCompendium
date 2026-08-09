Test("both features share one options category", function()
	AssertEquals(#PZAPI.ModOptions.Data, 1, "there should be exactly one heading on the Mods page")
	AssertEquals(PZAPI.ModOptions.Data[1].modOptionsID, "QoLC", "shared category id")

	local Category = PZAPI.ModOptions:getOptions("QoLC")
	local Titles = {}
	for _, Entry in ipairs(Category.data) do
		if Entry.type == "title" then table.insert(Titles, Entry.name) end
	end
	AssertEquals(#Titles, 2, "one title per feature")
	AssertNotNil(Translations[Titles[1]], "title has no translation: " .. tostring(Titles[1]))
	AssertNotNil(Translations[Titles[2]], "title has no translation: " .. tostring(Titles[2]))
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
