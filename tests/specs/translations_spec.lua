--// Translations Spec
--// aspctt - 28.08.2026
--// Every English string we ship spells things the way the game's own English does.
--//
--// Build 42's EN files are not consistently British or American. Armour and behaviour are
--// spelled the British way throughout, while color, recognize and practice are American.
--// There is no single rule to apply, only the game's own choice, word by word.
--//
--// Below are the words where the game is decisive and we had gone the other way. Reported
--// in game against the workbooks, which read "Practise Carpentry" in a crafting screen
--// that spells it the other way everywhere else.

--// Tuning
-- Left, what not to write. Right, what the game writes instead, and how lopsided it is in
-- build 42's own media/lua/shared/Translate/EN.
local WRONG = {
	{ Ours = "practise", Theirs = "practice", Split = "5 to 0" },
	{ Ours = "recognise", Theirs = "recognize", Split = "4 to 0" },
	{ Ours = "colour", Theirs = "color", Split = "46 to 1" }
}

-- Deliberately absent: armour and behaviour. The game spells both the British way, 38 times
-- and 2, so matching it means keeping them that way.

--// The Check
Test("our English matches the game's own English", function()
	local Bad = {}
	local Seen = 0

	for Key, Value in pairs(Translations) do
		if type(Value) == "string" then
			Seen = Seen + 1
			local Lower = Value:lower()

			for _, Word in ipairs(WRONG) do
				if Lower:find(Word.Ours, 1, true) then
					table.insert(Bad, Key .. " writes " .. Word.Ours .. ", the game writes "
						.. Word.Theirs .. ", " .. Word.Split)
				end
			end
		end
	end

	-- Guarded, because a table this walks with pairs returning nothing would make the check
	-- above pass without having read a single string.
	AssertTrue(Seen > 100, "only " .. tostring(Seen) .. " strings were read, so nothing was checked")
	AssertEquals(#Bad, 0, table.concat(Bad, "; "))
end)
