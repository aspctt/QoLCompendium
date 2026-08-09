--// Bigger Character Avatar
--// Workshop 3245854570 - Original
--// aspctt - 09.08.2026
--// The original shipped a whole copy of the build 41 ISCharacterScreen, which would drag
--// a year of vanilla changes back with it. This patches the two values it actually changed.
--// The character creation screen is left alone, build 42 already draws that one large.

--// Options
-- One shared category for the whole compendium, so the options screen shows a single
-- QoL Compendium heading rather than one per absorbed mod. Every feature adds its own
-- addTitle block inside it.
--
-- This ID is the save key in Zomboid\Lua\ModOptions.ini. Never rename it or players
-- lose their settings.
local OPTIONS_ID = "QoLC"
local Options = {}

--// Tuning
-- Vanilla builds the avatar at 128x256. The original mod doubled both, so 200 is our default.
local SCALE_DEFAULT = 200
local SCALE_STEP = 25
local SCALE_MAX = 300
local SCALE_MIN = 100

--// Variables
-- Held so a scale change can resize the panel that is already on screen.
local CharacterScreen

--// Functions
local function GetScale()
	if Options.Enabled and not Options.Enabled:getValue() then return 100 end
	if not Options.Scale then return SCALE_DEFAULT end

	local Scale = Options.Scale:getValue()
	if Scale < SCALE_MIN then return SCALE_MIN end
	if Scale > SCALE_MAX then return SCALE_MAX end
	return Scale
end

-- Resizes the avatar and shifts the column that vanilla laid out from its width.
-- Everything else reads avatarWidth at render time, so it follows on its own.
local function ApplyAvatarSize(Screen)
	if not Screen then return end
	if not Screen.avatarPanel then return end

	-- Remember what vanilla built, so re-applying a new scale stays exact
	if not Screen.QolcBaseAvatarWidth then
		Screen.QolcBaseAvatarWidth = Screen.avatarWidth
		Screen.QolcBaseAvatarHeight = Screen.avatarHeight
		Screen.QolcBaseXOffset = Screen.xOffset
	end

	local Scale = GetScale() / 100
	local Width = math.floor(Screen.QolcBaseAvatarWidth * Scale)
	local Height = math.floor(Screen.QolcBaseAvatarHeight * Scale)

	Screen.xOffset = Screen.QolcBaseXOffset + (Width - Screen.QolcBaseAvatarWidth)
	Screen.avatarHeight = Height
	Screen.avatarWidth = Width

	Screen.avatarPanel:setHeight(Height)
	Screen.avatarPanel:setWidth(Width)
end

--// Overrides
local OriginalCreate = ISCharacterScreen.create

function ISCharacterScreen:create()
	OriginalCreate(self)
	CharacterScreen = self
	ApplyAvatarSize(self)
end

--// Mod Options
local function CreateModOptions()
	if not PZAPI or not PZAPI.ModOptions then return end

	-- Get or create, so it does not matter which feature's file loads first
	local ModOptions = PZAPI.ModOptions:getOptions(OPTIONS_ID)
	if not ModOptions then
		ModOptions = PZAPI.ModOptions:create(OPTIONS_ID, "UI_options_QoLC")
	end

	ModOptions:addTitle("UI_options_QoLC_BiggerAvatar")
	ModOptions:addDescription("UI_options_QoLC_BiggerAvatar_Desc")

	-- Ids are unique across the whole shared category now, not just this feature
	Options.Enabled = ModOptions:addTickBox("AvatarEnabled", "UI_options_QoLC_BiggerAvatar_Enabled", true, "UI_options_QoLC_BiggerAvatar_Enabled_tooltip")
	Options.Scale = ModOptions:addSlider("AvatarScale", "UI_options_QoLC_BiggerAvatar_Scale", SCALE_MIN, SCALE_MAX, SCALE_STEP, SCALE_DEFAULT)
	ModOptions:addSeparator()

	-- Applied before the option's own value is written, so adopt it early and resize live
	local function OnOptionApplied(Option, Value)
		Option.value = Value
		ApplyAvatarSize(CharacterScreen)
	end

	Options.Enabled.onChangeApply = OnOptionApplied
	Options.Scale.onChangeApply = OnOptionApplied
end

CreateModOptions()
