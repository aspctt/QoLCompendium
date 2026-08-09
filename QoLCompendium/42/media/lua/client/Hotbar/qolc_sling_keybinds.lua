--// Rifle Sling Keybinds
--// Noir - Original
--// aspctt - 09.08.2026
--// Vanilla ships twelve hotbar slots but only binds keys for the first eight, and the
--// sling adds four more on top. This extends the lookup to cover them.
--//
--// Reworked from the original, which was written when vanilla had five slots and so
--// redefined Hotbar 6 through 10 itself. Doing that now would collide with vanilla's
--// own bindings, so this only adds the slots vanilla leaves out, and leaves them
--// unbound for the player to assign rather than taking keys away from anything.

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

--// Tuning
local VANILLA_SLOTS = 8
local TOTAL_SLOTS = 16

--// Overrides
function ISHotbar:getSlotForKey(key)
	for Slot = 1, TOTAL_SLOTS do
		if getCore():isKey("Hotbar " .. tostring(Slot), key) then
			return Slot
		end
	end
	return -1
end

--// Keybinds
local Binding = {}
Binding.value = "[QoLC Extra Hotbar]"
table.insert(keyBinding, Binding)

for Slot = VANILLA_SLOTS + 1, TOTAL_SLOTS do
	Binding = {}
	Binding.value = "Hotbar " .. tostring(Slot)
	Binding.key = 0
	table.insert(keyBinding, Binding)
end
