--// Rifle Sling Hotbar
--// Noir - Original
--// aspctt - 09.08.2026
--// Overrides ISHotbar:attachItem so a slung item resolves to a sling specific
--// attachment point, and so wearing a bag swaps the item to its bag variant rather
--// than clipping through it. Signature verified unchanged against build 42's
--// ISHotbar.lua:348.

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

function ISHotbar:attachItem(item, slot, slotIndex, slotDef, doAnim)
	local AttachmentType = QolcIsSling(item:getAttachmentType(), slot)

	if doAnim then
		if self.replacements and self.replacements[AttachmentType] and QolcOnBack(slotDef, slot) then
			slot = self.replacements[AttachmentType]
		end

		self:setAttachAnim(item, slotDef)
		ISInventoryPaneContextMenu.transferIfNeeded(self.chr, item)

		if self.attachedItems[slotIndex] then
			ISTimedActionQueue.add(ISDetachItemHotbar:new(self.chr, self.attachedItems[slotIndex]))
		end
		ISTimedActionQueue.add(ISAttachItemHotbar:new(self.chr, item, slot, slotIndex, slotDef))
		return
	end

	if self.replacements and self.replacements[AttachmentType] and QolcOnBack(slotDef, slot) then
		slot = self.replacements[AttachmentType]
	end

	-- Vanilla tests this again outside the bag branch, and dropping that was a mistake:
	-- an attachment point can be "null" with no bag in the picture, and without this the
	-- item is handed to setAttachedItem with "null" as its model point instead of coming
	-- off the bar.
	if slot == "null" then
		self:removeItem(item, false)
		return
	end

	self.chr:setAttachedItem(slot, item)
	item:setAttachedSlot(slotIndex)
	item:setAttachedSlotType(slotDef.type)
	item:setAttachedToModel(slot)

	self:reloadIcons()
end
