--// Feature Switches
--// aspctt - 18.08.2026
--// One tick box per feature, for the features that have nothing else to configure. A
--// compendium is a bundle of other people's mods, and a player who wants nine of them
--// should not have to take the tenth.
--//
--// Features that carry settings of their own keep their switch beside those settings
--// instead, in their own section further down the page. Features that change balance are
--// not here at all: those are sandbox options, so a server sets them for everyone rather
--// than each client quietly running its own rules.
--//
--// Held in one file rather than repeated in eleven. Every feature reads its switch at
--// run time, inside an event handler or an override body, never at file scope, so this
--// file does not have to load before any of them.

--// Tuning
local OPTIONS_ID = "QoLC"

-- Key, then the translation suffix used for its label and tooltip. Order here is the
-- order they appear on the page, so related features sit together.
local SWITCHES = {
	{ Key = "Hotbar", Name = "Hotbar" },
	{ Key = "Flashlight", Name = "Flashlight" },
	{ Key = "Capacity", Name = "Capacity" },
	{ Key = "XpView", Name = "XpView" },
	{ Key = "Generator", Name = "Generator" },
	{ Key = "Material", Name = "Material" },
	{ Key = "TakeAmount", Name = "TakeAmount" },
	{ Key = "FlagBook", Name = "FlagBook" },
	{ Key = "MoodleQuarters", Name = "MoodleQuarters" },

	-- These three stamp item scripts as the game loads them, so a change only shows on
	-- the next start. Their tooltips say so.
	{ Key = "BookIcons", Name = "BookIcons" },
	{ Key = "AmmoIcons", Name = "AmmoIcons" },
	{ Key = "FoodCategories", Name = "FoodCategories" }
}

local Options = {}

--// Functions
-- Missing option means on. That covers the options screen never having been opened, a
-- build without PZAPI, and the test harness, and it keeps a feature working rather than
-- silently disabling it because a setting could not be read.
function QolcFeatureEnabled(Key)
	local Option = Options[Key]
	if not Option then return true end

	return Option:getValue() and true or false
end

--// Mod Options
-- One shared category for the whole compendium, see qolc_immersive_overlays.lua.
local function CreateModOptions()
	if not PZAPI or not PZAPI.ModOptions then return end

	local ModOptions = PZAPI.ModOptions:getOptions(OPTIONS_ID)
	if not ModOptions then
		ModOptions = PZAPI.ModOptions:create(OPTIONS_ID, "UI_options_QoLC")
	end

	ModOptions:addTitle("UI_options_QoLC_Features")
	ModOptions:addDescription("UI_options_QoLC_Features_Desc")

	for _, Switch in ipairs(SWITCHES) do
		local Label = "UI_options_QoLC_Features_" .. Switch.Name
		Options[Switch.Key] = ModOptions:addTickBox(
			Switch.Key .. "Enabled", Label, true, Label .. "_tooltip")
	end
end

CreateModOptions()
