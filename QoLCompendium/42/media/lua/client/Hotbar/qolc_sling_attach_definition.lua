--// Rifle Sling Attach Definition
--// Noir - Original
--// aspctt - 09.08.2026
--// Declares the sling slots and which model attachment point each weapon class
--// hangs from, then teaches the existing back slot to swap to a bag variant.

--// Guards
if not ISHotbarAttachDefinition then return end

--// Slots
-- One per wearable style. Only front and back remain, the two hip variants were
-- dropped along with their items.
local Slots = {
	{
		type = "SlingFront",
		name = "Sling",
		animset = "belt left",
		attachments = {
			BigWeapon = "SlingWeapon",
			BigBlade = "SlingWeapon",
			BigBonk = "SlingWeapon",
			Shovel = "SlingShovel",
			Rifle = "SlingRifle",
		},
	},
	{
		type = "SlingBack",
		name = "Sling",
		animset = "back",
		attachments = {
			BigWeapon = "SlingWeapon Back",
			BigBlade = "SlingWeapon Back",
			BigBonk = "SlingWeapon Back",
			Shovel = "SlingShovel Back",
			Rifle = "SlingRifle Back",
		},
	},
}

for _, Slot in ipairs(Slots) do
	table.insert(ISHotbarAttachDefinition, Slot)
end

--// Bag Replacements
-- When a bag is worn, a slung item moves to its bag variant so the two do not clip
local Replacements = {
	BigWeaponSling = "SlingWeaponBag",
	BigBladeSling = "SlingBladeBag",
	BigBonkSling = "SlingBladeBag",
	ShovelSling = "SlingShovelBag",
	RifleSling = "SlingRifleBag",
}

if ISHotbarAttachDefinition.replacements and ISHotbarAttachDefinition.replacements[1] then
	for Key, Value in pairs(Replacements) do
		ISHotbarAttachDefinition.replacements[1].replacement[Key] = Value
	end
end
