--// Rifle Sling Attach Action
--// Noir - Original
--// aspctt - 09.08.2026
--// The animated half of the hotbar override. Build 42 moved ISAttachItemHotbar from
--// client/TimedActions to shared/TimedActions, so this sits in shared to match.

--// Guards
-- Deliberately a local rather than a shared helper. This runs at file scope, and lua
-- file load order between mod files is not guaranteed, so a cross file call here
-- would be a load order landmine.
local function OverrideBlocked()
	if not getActivatedMods then return false end
	local Mods = getActivatedMods()
	if not Mods then return false end
	return Mods:contains("nattachments") or Mods:contains("noirbackpacksattachments")
end

if OverrideBlocked() then return end

function ISAttachItemHotbar:perform()
	local AttachmentType = QolcIsSling(self.item:getAttachmentType(), self.slot)

	-- Clear whatever was already in this slot
	if self.hotbar.attachedItems[self.slotIndex] then
		self.hotbar.chr:removeAttachedItem(self.hotbar.attachedItems[self.slotIndex])
		self.hotbar.attachedItems[self.slotIndex]:setAttachedSlot(-1)
		self.hotbar.attachedItems[self.slotIndex]:setAttachedSlotType(nil)
		self.hotbar.attachedItems[self.slotIndex]:setAttachedToModel(nil)
	end

	-- Swap to the bag variant when something is worn on the back
	if self.hotbar.replacements and self.hotbar.replacements[AttachmentType] and QolcIsBack(self.slot) then
		self.slot = self.hotbar.replacements[AttachmentType]
		if self.slot == "null" then
			self.hotbar:removeItem(self.item)
			return
		end
	end

	self.hotbar.chr:setAttachedItem(self.slot, self.item)
	self.item:setAttachedSlot(self.slotIndex)
	self.item:setAttachedSlotType(self.slotDef.type)
	self.item:setAttachedToModel(self.slot)

	self.hotbar:reloadIcons()

	ISInventoryPage.renderDirty = true
	ISBaseTimedAction.perform(self)
end
