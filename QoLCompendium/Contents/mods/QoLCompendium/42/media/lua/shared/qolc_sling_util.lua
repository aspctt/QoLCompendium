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

-- Whether this attachment is on the character's back, for the purpose of swapping a
-- slung or slotted item to its bag variant.
--
-- Vanilla asks slotDef.name == "Back" and nothing else. Asking only whether the model
-- point reads " Back" is not the same question and gets one case wrong: the back slot's
-- guitar attachment point is named "Guitar", so a guitar skipped the bag replacement and
-- stayed hanging through the backpack. The sling slots are named "Sling" rather than
-- "Back", so the slot string still has to be tested as well as, not instead of, the name.
function QolcOnBack(SlotDef, Slot)
	if SlotDef and SlotDef.name == "Back" then return true end

	return QolcIsBack(Slot) and true or false
end

-- Slung items get their own attachment type, so a rifle on a sling can hang
-- differently to a rifle on a belt
function QolcIsSling(AttachmentType, Slot)
	if Slot and string.find(Slot, "Sling") then
		return AttachmentType .. "Sling"
	end
	return AttachmentType
end

