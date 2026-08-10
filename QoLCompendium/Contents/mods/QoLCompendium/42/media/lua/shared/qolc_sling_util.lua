--// Rifle Sling Utility
--// Noir - Original
--// aspctt - 09.08.2026
--// Shared because the hotbar override lives in client and the timed action override
--// lives in shared. Both call these, so neither can own them.

--// Functions
-- True when the slot is one of the "on your back" attachment points
function QolcIsBack(Slot)
	if not Slot then return false end
	return string.find(Slot, " Back")
end

-- Slung items get their own attachment type, so a rifle on a sling can hang
-- differently to a rifle on a belt
function QolcIsSling(AttachmentType, Slot)
	if Slot and string.find(Slot, "Sling") then
		return AttachmentType .. "Sling"
	end
	return AttachmentType
end

