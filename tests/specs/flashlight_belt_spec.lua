--// Flashlight On The Belt Spec
--// aspctt - 20.08.2026
--// Build 42 hangs a screwdriver, a wrench, a walkie and a meat cleaver off a belt, and
--// not a torch. The item side of this is a script patch giving the three torches an
--// attachment type; this covers the half that decides which slots accept it, which is
--// also the half the tick box controls.

--// Helpers
local ATTACHMENT = "Flashlight"

local function SlotByType(SlotType)
	for _, Slot in ipairs(ISHotbarAttachDefinition) do
		if Slot.type == SlotType then return Slot end
	end

	return nil
end

local function Boot()
	Harness.Fire("OnGameBoot")
end

--// Registering
Test("a torch hangs from either belt slot", function()
	Boot()

	AssertEquals(SlotByType("SmallBeltLeft").attachments[ATTACHMENT], "Belt Left Screwdriver",
		"left belt should take one")
	AssertEquals(SlotByType("SmallBeltRight").attachments[ATTACHMENT], "Belt Right Screwdriver",
		"right belt should take one")
end)

Test("the position is one the character rig already has", function()
	Boot()

	-- A rig position is not something a mod can invent, so the one named here has to be
	-- a position some vanilla type already hangs from. The screwdriver's is the same
	-- size and shape as a torch.
	local Left = SlotByType("SmallBeltLeft").attachments
	AssertEquals(Left[ATTACHMENT], Left.Screwdriver, "reuses the screwdriver's position")
end)

Test("nothing else about the slot is disturbed", function()
	local Before = SlotByType("SmallBeltLeft").attachments.Knife
	Boot()

	local After = SlotByType("SmallBeltLeft").attachments
	AssertEquals(After.Knife, Before, "a knife still hangs where it did")
	AssertEquals(After.Walkie, "Walkie Belt Left", "and so does a walkie")
end)

Test("booting twice leaves one entry", function()
	Boot()
	Boot()

	AssertEquals(SlotByType("SmallBeltRight").attachments[ATTACHMENT], "Belt Right Screwdriver",
		"still the one position")
end)

--// Standing Aside
Test("a mod that got there first keeps its position", function()
	SlotByType("SmallBeltLeft").attachments[ATTACHMENT] = "Somewhere Else"
	Boot()

	AssertEquals(SlotByType("SmallBeltLeft").attachments[ATTACHMENT], "Somewhere Else",
		"theirs should not be quietly overwritten")
end)

--// The Switch
Test("turning the feature off leaves nowhere to hang it", function()
	local Category = PZAPI.ModOptions:getOptions("QoLC")
	for _, Entry in ipairs(Category.data) do
		if Entry.id == "FlashlightEnabled" then Entry:setValue(false) end
	end

	Boot()

	-- The attachment type stays on the item either way, since that is a script. With no
	-- slot listing it, canBeAttached finds no match and it simply cannot be hung.
	AssertNil(SlotByType("SmallBeltLeft").attachments[ATTACHMENT], "no slot should take it")
	AssertNil(SlotByType("SmallBeltRight").attachments[ATTACHMENT], "on either side")
end)

-- The item script is not switchable, only this half is, so turning the box off leaves a
-- torch already hanging on a belt whose slot no longer lists its type. Vanilla's refresh
-- takes every carried item off and puts it back through
-- attachItem(item, slotDef.attachments[type], ...), which is nil here, and that reaches
-- IsoGameCharacter.setAttachedItem with a null location. AttachedLocationGroup.checkValid
-- throws on it, so the refresh dies partway rather than the torch quietly coming off.
Test("a torch already hung survives the feature being turned off", function()
	Boot()

	local Player = Harness.NewPlayer(0, true)
	local Hotbar = Harness.NewHotbar(Player, { "Back", "SmallBeltLeft" })
	Harness.Fire("OnLoad")

	local Torch = Harness.PutOnHotbar(Hotbar, 2, Harness.NewHotbarItem("Flashlight", "Torch"))
	Hotbar:attachItem(Torch, "Belt Left Screwdriver", 2, Hotbar.availableSlot[2].def, false)

	local Category = PZAPI.ModOptions:getOptions("QoLC")
	for _, Entry in ipairs(Category.data) do
		if Entry.id == "FlashlightEnabled" then Entry:setValue(false) end
	end

	SlotByType("SmallBeltLeft").attachments[ATTACHMENT] = nil

	Hotbar.WornChanged = true
	local Ok, Err = pcall(function() Hotbar:refresh() end)
	Hotbar.WornChanged = false

	AssertTrue(Ok, "a refresh must not throw over it, got " .. tostring(Err))
	AssertEquals(Torch:getAttachedSlot(), -1, "the torch should have come off the bar")
	AssertNil(Harness.AttachedAt(Player, Torch), "and off the model")
end)

--// The Item Script
Test("all three torches are given the type", function()
	-- Torch is the ordinary flashlight, not a burning brand: its model is FlashLight.
	local Script = Harness.ReadModScript("qolc_flashlight_belt.txt")

	for _, Name in ipairs({ "Torch", "HandTorch", "Flashlight_Crafted" }) do
		AssertContains(Script, "item " .. Name, Name .. " should be given an attachment type")
	end
	AssertContains(Script, "AttachmentType = Flashlight", "and the type itself")
end)
