--// Ammo and Magazine Icons
--// falcon33jp - Original icons
--// aspctt - 09.08.2026
--// Build 42 reuses one icon across whole families of ammo. Every handgun ammo box in
--// the game draws as HandgunAmmoBox, all three rifle boxes share RifleAmmo308, and
--// three pistol magazines share BerettaClip. Thirteen items, four icons. This gives
--// each of them its own.
--//
--// Only inventory icons are replaced. Vanilla's world models are fine and are left
--// alone, so nothing here touches WorldStaticModel.
--//
--// Shared rather than client, so a multiplayer server and its clients hold the same
--// item definitions.

--// Tuning
-- Item id -> our icon name. The texture is common/media/textures/Item_<icon>.png,
-- which is how the game resolves an Icon value.
--
-- Deliberately absent: 223Box, 223Clip and 308Clip. Build 42 dropped all three, so the
-- original mod's icons for them have nothing to attach to.
local ICONS = {
	["Base.ShotgunShellsBox"] = "QolcAmmoBoxShotgun",
	["Base.Bullets9mmBox"] = "QolcAmmoBox9mm",
	["Base.Bullets45Box"] = "QolcAmmoBox45",
	["Base.Bullets44Box"] = "QolcAmmoBox44",
	["Base.Bullets38Box"] = "QolcAmmoBox38",
	-- .357 Magnum has no icon of its own in the set. Paired with .38 Special, which
	-- is the right pairing: .357 is a lengthened .38 case, same bullet diameter, and
	-- real boxes for the two look alike. It does mean these two match each other,
	-- but they no longer match the other three handgun boxes.
	["Base.Bullets357Box"] = "QolcAmmoBox38",
	["Base.556Box"] = "QolcAmmoBox556",
	["Base.308Box"] = "QolcAmmoBox308",

	["Base.M14Clip"] = "QolcMagazineM14",
	["Base.556Clip"] = "QolcMagazineM16",
	["Base.9mmClip"] = "QolcMagazine9mm",
	["Base.45Clip"] = "QolcMagazine45",
	["Base.44Clip"] = "QolcMagazine44",
}

--// Functions
local function OnInitGlobalModData()
	if not ScriptManager or not ScriptManager.instance then return end

	for Name, Icon in pairs(ICONS) do
		local Item = ScriptManager.instance:getItem(Name)

		-- A missing item means the base game renamed or removed it, which is worth
		-- knowing about rather than silently skipping
		if not Item then
			print("QoL Compendium: ammo icon target not found, " .. Name)
		elseif Item:getIcon() ~= Icon then
			Item:DoParam("Icon = " .. Icon)
		end
	end
end

--// Connections
Events.OnInitGlobalModData.Add(OnInitGlobalModData)
