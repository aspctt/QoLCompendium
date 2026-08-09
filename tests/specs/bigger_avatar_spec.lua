--// Bigger Character Avatar Spec
--// aspctt - 09.08.2026

local OPTIONS_ID = "QoLC"

--// Helpers
local function GetOption(Id)
	local ModOptions = PZAPI.ModOptions:getOptions(OPTIONS_ID)
	AssertNotNil(ModOptions, "the mod did not register options under " .. OPTIONS_ID)
	local Option = ModOptions:getOption(Id)
	AssertNotNil(Option, "no option registered with id " .. Id)
	return Option
end

-- Mirrors how MainOptions applies a value: the handler runs before the option's own
-- value is written, and is given the new value.
local function ApplyOption(Id, Value)
	local Option = GetOption(Id)
	if Option.onChangeApply then Option:onChangeApply(Value) end
	Option.value = Value
end

--// Sizing
Test("avatar is doubled by default", function()
	local Screen = Harness.NewCharacterScreen()
	AssertEquals(Screen.avatarWidth, 256, "avatar width")
	AssertEquals(Screen.avatarHeight, 512, "avatar height")
end)

Test("the avatar panel itself is resized, not just the numbers", function()
	local Screen = Harness.NewCharacterScreen()
	AssertEquals(Screen.avatarPanel:getWidth(), 256, "panel width")
	AssertEquals(Screen.avatarPanel:getHeight(), 512, "panel height")
end)

Test("the vanilla create still runs", function()
	local Screen = Harness.NewCharacterScreen()
	AssertEquals(Harness.CreateCallCount, 1, "vanilla create should be called exactly once")
	AssertNotNil(Screen.avatarX, "vanilla should still have set avatarX")
	AssertNotNil(Screen.avatarPanel, "vanilla should still have built the avatar panel")
end)

Test("the text column shifts by exactly the width gained", function()
	local Vanilla = Harness.VanillaAvatar
	local Expected = Vanilla.BorderSpacing + 1 + Vanilla.Border
		+ Vanilla.Width + Vanilla.BorderSpacing + 2 + Vanilla.TextWidth
		+ (256 - Vanilla.Width)

	local Screen = Harness.NewCharacterScreen()
	AssertEquals(Screen.xOffset, Expected, "xOffset should follow the wider avatar")
end)

Test("avatar position is left where vanilla put it", function()
	local Vanilla = Harness.VanillaAvatar
	local Screen = Harness.NewCharacterScreen()
	AssertEquals(Screen.avatarX, Vanilla.BorderSpacing + 1 + Vanilla.Border, "avatarX")
	AssertEquals(Screen.avatarY, Vanilla.BorderSpacing + 1 + Vanilla.Border, "avatarY")
end)

--// Options
Test("options register one category with the expected ids", function()
	local ModOptions = PZAPI.ModOptions:getOptions(OPTIONS_ID)
	AssertNotNil(ModOptions, "category was not registered")
	AssertEquals(ModOptions.modOptionsID, OPTIONS_ID, "category id")
	GetOption("AvatarEnabled")
	GetOption("AvatarScale")
end)

Test("scale defaults to two hundred percent and is on", function()
	AssertEquals(GetOption("AvatarScale"):getValue(), 200, "scale default")
	AssertEquals(GetOption("AvatarEnabled"):getValue(), true, "enabled default")
end)

Test("every option label and tooltip resolves to a translation", function()
	AssertNotNil(Translations, "translations were not loaded")
	local ModOptions = PZAPI.ModOptions:getOptions(OPTIONS_ID)
	AssertNotNil(Translations[ModOptions.name], "category name has no translation: " .. tostring(ModOptions.name))

	for _, Option in ipairs(ModOptions.data) do
		if Option.name then
			AssertNotNil(Translations[Option.name], "option label has no translation: " .. tostring(Option.name))
		end
		if Option.tooltip then
			AssertNotNil(Translations[Option.tooltip], "tooltip has no translation: " .. tostring(Option.tooltip))
		end
	end
end)

Test("turning it off restores the vanilla size", function()
	local Vanilla = Harness.VanillaAvatar
	GetOption("AvatarEnabled"):setValue(false)

	local Screen = Harness.NewCharacterScreen()
	AssertEquals(Screen.avatarWidth, Vanilla.Width, "avatar width should be vanilla when disabled")
	AssertEquals(Screen.avatarHeight, Vanilla.Height, "avatar height should be vanilla when disabled")
	AssertEquals(Screen.avatarPanel:getWidth(), Vanilla.Width, "panel width should be vanilla when disabled")
end)

Test("a custom scale is honoured", function()
	GetOption("AvatarScale"):setValue(150)
	local Screen = Harness.NewCharacterScreen()
	AssertEquals(Screen.avatarWidth, 192, "avatar width at 150 percent")
	AssertEquals(Screen.avatarHeight, 384, "avatar height at 150 percent")
end)

Test("changing the scale resizes the screen already open", function()
	local Screen = Harness.NewCharacterScreen()
	AssertEquals(Screen.avatarWidth, 256, "avatar should start doubled")

	ApplyOption("AvatarScale", 300)
	AssertEquals(Screen.avatarWidth, 384, "avatar width should update live")
	AssertEquals(Screen.avatarHeight, 768, "avatar height should update live")
	AssertEquals(Screen.avatarPanel:getWidth(), 384, "panel width should update live")
end)

Test("turning it off resizes the screen already open", function()
	local Vanilla = Harness.VanillaAvatar
	local Screen = Harness.NewCharacterScreen()

	ApplyOption("AvatarEnabled", false)
	AssertEquals(Screen.avatarWidth, Vanilla.Width, "avatar should return to vanilla live")
	AssertEquals(Screen.xOffset, Screen.QolcBaseXOffset, "xOffset should return to vanilla live")
end)

Test("rescaling repeatedly does not drift", function()
	local Screen = Harness.NewCharacterScreen()
	local BaseOffset = Screen.QolcBaseXOffset

	ApplyOption("AvatarScale", 300)
	ApplyOption("AvatarScale", 100)
	ApplyOption("AvatarScale", 250)
	ApplyOption("AvatarScale", 200)

	AssertEquals(Screen.avatarWidth, 256, "width should land back on the doubled size")
	AssertEquals(Screen.avatarHeight, 512, "height should land back on the doubled size")
	AssertEquals(Screen.QolcBaseXOffset, BaseOffset, "the remembered vanilla offset should never move")
end)

Test("scale is clamped to its advertised range", function()
	local Screen = Harness.NewCharacterScreen()

	ApplyOption("AvatarScale", 5000)
	AssertEquals(Screen.avatarWidth, 384, "width should clamp at the maximum scale")

	ApplyOption("AvatarScale", -100)
	AssertEquals(Screen.avatarWidth, 128, "width should clamp at the minimum scale")
end)
