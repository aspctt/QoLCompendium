--// Flashlight On The Belt
--// Common Sense, Workshop 2875848298, by BitBraven. Idea only, no files or code taken.
--// aspctt - 20.08.2026
--// Hang a torch off either belt slot, the way a screwdriver or a walkie already can.
--//
--// The attachment type is stamped onto the three torches in qolc_flashlight_belt.txt.
--// This half says which slots will take it, which is the half that can be switched off:
--// with no slot listing the type, canBeAttached finds no match and the torch simply
--// cannot be hung.
--//
--// The model point is the screwdriver's. Points are named positions on the character rig
--// rather than anything a mod can invent, so a new one would need art we have no right
--// to and do not need: a torch is the same size and shape as the tool already hanging
--// there. Attaching does not switch it on, so this is somewhere to put it, not free light.
--//
--// Registered from OnGameBoot rather than at file scope. The tick box is created by
--// qolc_feature_switches.lua, also at file scope, and lua file load order between mod
--// files is not guaranteed, so reading the switch during load would be a load order
--// landmine of exactly the kind called out in qolc_reorder_hotbar.lua. By the time any
--// event fires, every file has loaded.
--//
--// Client only. Where a player hangs their torch is a client concern.

require "Hotbar/ISHotbarAttachDefinition"

--// Tuning
local ATTACHMENT = "Flashlight"

-- Slot type, then the rig position a torch hangs from on that side.
local SLOTS = {
	SmallBeltRight = "Belt Right Screwdriver",
	SmallBeltLeft = "Belt Left Screwdriver",
}

--// Functions
local function FindSlot(SlotType)
	for _, Slot in ipairs(ISHotbarAttachDefinition or {}) do
		if Slot.type == SlotType then return Slot end
	end

	return nil
end

--// Connections
local function OnGameBoot()
	if QolcFeatureEnabled and not QolcFeatureEnabled("Flashlight") then return end

	for SlotType, Point in pairs(SLOTS) do
		local Slot = FindSlot(SlotType)

		-- Left alone if something else already claimed the type, so a mod that got here
		-- first keeps whatever position it chose rather than being quietly overwritten.
		if Slot and Slot.attachments and not Slot.attachments[ATTACHMENT] then
			Slot.attachments[ATTACHMENT] = Point
		end
	end
end

Events.OnGameBoot.Add(OnGameBoot)
