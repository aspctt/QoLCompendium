--// Feature Switches Spec
--// aspctt - 18.08.2026

--// Helpers
local function GetOption(Id)
	local Category = PZAPI.ModOptions:getOptions("QoLC")
	for _, Entry in ipairs(Category.data) do
		if Entry.id == Id then return Entry end
	end
	return nil
end

local function TurnOff(Key)
	local Option = GetOption(Key .. "Enabled")
	AssertNotNil(Option, "no switch called " .. Key .. "Enabled")
	Option:setValue(false)
end

local SWITCHES = {
	"Hotbar", "Capacity", "XpView", "Generator", "Material", "MoodleQuarters",
	"TakeAmount", "FlagBook", "BookIcons", "AmmoIcons", "FoodCategories"
}

--// The Switches Themselves
Test("every feature without its own settings has a switch", function()
	for _, Key in ipairs(SWITCHES) do
		AssertNotNil(GetOption(Key .. "Enabled"), "missing a switch for " .. Key)
	end
end)

Test("every switch starts on", function()
	-- A compendium that arrives with features off is a compendium that looks broken
	for _, Key in ipairs(SWITCHES) do
		AssertTrue(QolcFeatureEnabled(Key), Key .. " should default on")
	end
end)

Test("an unknown key reads as on", function()
	-- Covers the options screen never having been opened, and a build without PZAPI.
	-- Failing open keeps a feature working rather than silently disabling it.
	AssertTrue(QolcFeatureEnabled("NoSuchFeature"), "should fail open, not closed")
end)

Test("every switch label and tooltip resolves", function()
	AssertNotNil(Translations["UI_options_QoLC_Features"], "the section heading")
	AssertNotNil(Translations["UI_options_QoLC_Features_Desc"], "the section description")

	for _, Key in ipairs(SWITCHES) do
		local Label = "UI_options_QoLC_Features_" .. Key
		AssertNotNil(Translations[Label], "no label for " .. Key)
		AssertNotNil(Translations[Label .. "_tooltip"], "no tooltip for " .. Key)
	end
end)

Test("the switches sit under their own heading", function()
	local Category = PZAPI.ModOptions:getOptions("QoLC")
	local Seen = false

	for _, Entry in ipairs(Category.data) do
		if Entry.type == "title" and Entry.name == "UI_options_QoLC_Features" then Seen = true end
		if Entry.id == "HotbarEnabled" then
			AssertTrue(Seen, "the heading has to come before the boxes under it")
			return
		end
	end

	AssertTrue(false, "never found the hotbar switch")
end)

--// Turning Them Off
Test("the hotbar keeps vanilla's order when switched off", function()
	local Player = Harness.NewPlayer(0, true)
	local Hotbar = Harness.NewHotbar(Player, { "Back", "Belt" })
	Harness.Fire("OnLoad")

	Player:getModData()["BeltQolcHotbarIndex"] = 1
	Player:getModData()["BackQolcHotbarIndex"] = 2

	TurnOff("Hotbar")
	QolcHotbarApplyOrder(Hotbar)

	AssertEquals(table.concat(Harness.SlotOrder(Hotbar), ","), "Back,Belt",
		"the stored order should not be applied")
end)

Test("take any amount drops out of the grab menu when switched off", function()
	TurnOff("TakeAmount")

	Harness.SetupTransferWindows(0)
	local Source = Harness.NewContainer("crate")
	local Stack = Harness.NewStack(Source, 10)
	local Context = Harness.NewContextMenu()

	ISInventoryPaneContextMenu.doGrabMenu(Context, { Stack }, 0)

	AssertNil(Context:Find(getText("ContextMenu_QoLC_GrabAmount")), "the entry should be gone")
end)

Test("flagging a book as seen drops out when switched off", function()
	-- A book two levels out of reach is the case vanilla refuses and this feature
	-- converts, so it is the one that has to stop happening
	Harness.NewPlayer(0, true)
	local Book = Harness.NewSkillBook("Carpentry", 3)

	local Before = Harness.NewContextMenu()
	ISInventoryPaneContextMenu.doLiteratureMenu(Before, { Book }, 0)
	AssertNotNil(Before:Find(getText("ContextMenu_QoLC_ReadOnePage")),
		"the option should be there to begin with, or this proves nothing")

	TurnOff("FlagBook")

	local After = Harness.NewContextMenu()
	ISInventoryPaneContextMenu.doLiteratureMenu(After, { Book }, 0)
	AssertNil(After:Find(getText("ContextMenu_QoLC_ReadOnePage")), "and gone once switched off")
end)

--// Balance Switches Are Not Here
Test("balance features are server controlled, not tick boxes", function()
	-- Rifle slings, propane from pumps and the bigger torch change what the world holds
	-- and how far a tank goes, so a per client box would let two players on one server
	-- play to different numbers.
	for _, Key in ipairs({ "Sling", "PropanePump", "Blowtorch" }) do
		AssertNil(GetOption(Key .. "Enabled"), Key .. " should not be a mod option")
		AssertNotNil(QOLC_SANDBOX_DEFAULTS[Key .. "Enabled"], Key .. " should be a sandbox option")
	end
end)

Test("every sandbox switch label resolves", function()
	for _, Key in ipairs({ "Sling", "PropanePump", "Blowtorch" }) do
		local Label = "Sandbox_QoLC_" .. Key .. "Enabled"
		AssertNotNil(Translations[Label], "no label for " .. Key)
		AssertNotNil(Translations[Label .. "_tooltip"], "no tooltip for " .. Key)
	end
end)

Test("moodle quarters hands the stack back when switched off", function()
	Harness.NewMoodlePlayer(0)
	local Vanilla = Harness.NewMoodlePanel(0)
	Harness.Fire("OnTick")

	AssertNotNil(MoodleQuarters.panels[0], "it should have taken the stack to begin with")
	AssertNil(Harness.UIIndex(Vanilla), "and vanilla should have given it up")

	TurnOff("MoodleQuarters")
	Harness.Fire("OnTick")
	Harness.Fire("OnTick")

	AssertNil(MoodleQuarters.panels[0], "our panel should be gone")
	AssertNotNil(Harness.UIIndex(Vanilla), "and vanilla should have the stack back")
end)
