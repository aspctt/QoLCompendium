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

	-- Tell the server, which vanilla does not do on this branch. Its attach and detach
	-- timed actions both end with syncItemFields, and this path sets the same two fields
	-- without one, so on a server the client ends up right and the server hears nothing.
	--
	-- It is reached constantly: the tail of ISHotbar:refresh takes every attached item
	-- off and puts it back through here, which happens whenever clothing changes, so
	-- putting a bag on is enough to leave an item bound on the client and unbound on the
	-- server. Reported as a freshly attached screwdriver coming back unattached, with
	-- both of its fields unset rather than stale.
	if syncItemFields then syncItemFields(self.chr, item) end

	self:reloadIcons()
end
