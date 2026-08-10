--// Show Clothes Material
--// Show Clothes Material, Workshop 1922750845 - Original idea
--// aspctt - 10.08.2026
--// Puts the fabric a garment is made of on its tooltip. The game tracks it, uses it for
--// patching and for what a garment rips into, and never tells you what it is.
--//
--// Rewritten rather than ported, and the interesting part is that no interface code is
--// needed at all. Build 42 item scripts carry a Tooltip field, which 412 vanilla items
--// already use, and the fabric type sits on the same script item. So this reads one
--// field and writes the other at boot, exactly as qolc_ammo_icons.lua does, and vanilla
--// renders the line itself.
--//
--// The original had to intercept ISToolTipInv:render and temporarily replace two of its
--// methods mid call to squeeze a line in, because the tooltip is built on the Java side.
--// Nothing here touches the tooltip at render time, so it cannot collide with another
--// mod doing the same, and costs nothing per frame.
--//
--// Shared, matching the other item script patches, so a server and its clients hold the
--// same item definitions.

--// Tuning
-- One key per fabric. Build 42 defines exactly three in ClothingRecipesDefinitions:
-- Cotton, Denim and Leather, covering 417 items. A fabric added later simply gets no
-- line rather than a raw key on screen, which is checked for below.
local KEY_PREFIX = "Tooltip_QoLC_Fabric_"

--// Functions
local function OnInitGlobalModData()
	if not getAllItems then return end

	local Items = getAllItems()
	if not Items then return end

	for Index = 0, Items:size() - 1 do
		local Item = Items:get(Index)
		local Fabric = Item and Item.getFabricType and Item:getFabricType()

		-- Only garments that have no tooltip of their own. Three vanilla items carry
		-- both a fabric and a tooltip, all of them ripped strips rather than clothing,
		-- and theirs says something more useful than ours would.
		if Fabric and Fabric ~= "" and (not Item:getTooltip() or Item:getTooltip() == "") then
			local Key = KEY_PREFIX .. Fabric

			-- A fabric the game adds later would otherwise show its own key on screen
			if getTextOrNull(Key) then
				Item:DoParam("Tooltip = " .. Key)
			end
		end
	end
end

--// Connections
Events.OnInitGlobalModData.Add(OnInitGlobalModData)
