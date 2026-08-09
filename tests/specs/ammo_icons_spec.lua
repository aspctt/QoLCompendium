--// Ammo and Magazine Icons Spec
--// aspctt - 09.08.2026

local TARGETS = {
	"Base.Bullets9mmBox", "Base.Bullets45Box", "Base.Bullets44Box", "Base.Bullets38Box",
	"Base.Bullets357Box", "Base.ShotgunShellsBox", "Base.308Box", "Base.556Box",
	"Base.9mmClip", "Base.45Clip", "Base.44Clip", "Base.556Clip", "Base.M14Clip",
}

local function Apply()
	Harness.Fire("OnInitGlobalModData")
end

local function IconOf(Name)
	return ScriptManager.instance:getItem(Name):getIcon()
end

Test("vanilla really does share icons across ammo families", function()
	-- The premise. If a future build fixes this, the whole feature is redundant.
	AssertEquals(IconOf("Base.Bullets9mmBox"), IconOf("Base.Bullets45Box"), "handgun boxes share")
	AssertEquals(IconOf("Base.9mmClip"), IconOf("Base.45Clip"), "pistol magazines share")
	AssertEquals(IconOf("Base.308Box"), IconOf("Base.556Box"), "rifle boxes share")
end)

Test("every targeted item gets its own icon, bar one deliberate pair", function()
	Apply()
	-- .357 intentionally shares with .38, see qolc_ammo_icons.lua. Nothing else may.
	local Allowed = { ["Base.Bullets357Box"] = "Base.Bullets38Box" }
	local Seen = {}
	for _, Name in ipairs(TARGETS) do
		local Icon = IconOf(Name)
		AssertNotNil(Icon, Name .. " has no icon")
		if Seen[Icon] then
			AssertEquals(Allowed[Name], Seen[Icon],
				"icon " .. tostring(Icon) .. " is unexpectedly shared by " .. Name)
		end
		Seen[Icon] = Name
	end
end)

Test("every icon is one of ours", function()
	Apply()
	for _, Name in ipairs(TARGETS) do
		AssertContains(IconOf(Name), "Qolc", Name .. " should use a compendium icon")
	end
end)

Test("items the compendium does not target are left alone", function()
	Apply()
	-- No icon shipped for these, so vanilla's stays. 357 keeps HandgunAmmoBox, but it
	-- is now the only item using it rather than one of five.
	AssertEquals(IconOf("Base.3030Box"), "RifleAmmo308", "30-30 box untouched")
end)

Test("applying twice does not thrash the definitions", function()
	Apply()
	local First = IconOf("Base.Bullets9mmBox")
	Apply()
	AssertEquals(IconOf("Base.Bullets9mmBox"), First, "a second init should be a no op")
end)
