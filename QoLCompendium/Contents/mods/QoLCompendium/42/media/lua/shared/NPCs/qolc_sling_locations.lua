--// Rifle Sling Locations
--// Noir - Original
--// aspctt - 09.08.2026
--// Registers the body location the sling occupies, and every model attachment point
--// a slung item can hang from. Both APIs are unchanged in build 42.

--// Body Location
-- Build 42 closed the body location list, and getting one registered has three rules
-- that all have to line up. Confirmed by disassembling the game, not guessed:
--
--   1. BodyLocationGroup:getOrCreateLocation takes an ItemBodyLocation object, not a
--      name. Passing a string throws at load.
--   2. Nothing registers custom locations for you. Only ItemBodyLocation itself ever
--      calls register, so the item script loader will not do it.
--   3. ItemBodyLocation.register passes allowDefault = false to
--      RegistryReset.createLocation, which rejects the "base" namespace outright.
--      Mods must namespace their own. Vanilla is exempt because it registers with
--      allowDefault = true.
--
-- ResourceLocation.of splits on ":" and lowercases both halves, so this ends up as
-- "qolc:sling". The item scripts have to say BodyLocation = qolc:Sling to match,
-- because Item parses that value through the very same ResourceLocation.of call.
--
-- AttachedLocations below is unaffected, that one still takes a plain string.
local SLING_LOCATION_ID = "qolc:Sling"

local SlingLocation = ItemBodyLocation.register(SLING_LOCATION_ID)
BodyLocations.getGroup("Human"):getOrCreateLocation(SlingLocation)

--// Item Body Location
-- Item scripts are parsed in GameWindow.initShared, which runs at offset 243, while
-- mod lua does not load until LoadDirBase at 259. So when the sling items were read,
-- BodyLocation = qolc:Sling resolved through ItemBodyLocation.get to nothing, and the
-- items ended up with no body location at all, which is why they could be spawned but
-- never worn.
--
-- There is no script block type for body locations, ScriptType has no such entry, so
-- lua is the only place to register one. Re-applying it to the items here is the fix.
local SLING_ITEMS = {
	"Base.SlingAFront",
	"Base.SlingABack",
}

local function ApplyBodyLocation()
	if not ScriptManager or not ScriptManager.instance then return end

	for _, Name in ipairs(SLING_ITEMS) do
		local Item = ScriptManager.instance:getItem(Name)
		if Item and Item.setBodyLocation then
			Item:setBodyLocation(SlingLocation)
		end
	end
end

ApplyBodyLocation()

--// Attachment Points
local AttachGroup = AttachedLocations.getGroup("Human")

-- Rifles
AttachGroup:getOrCreateLocation("SlingRifle Back"):setAttachmentName("sling_rifleback")
AttachGroup:getOrCreateLocation("SlingRifleBag"):setAttachmentName("sling_riflebag")
AttachGroup:getOrCreateLocation("SlingRifle3"):setAttachmentName("sling_rifle3")
AttachGroup:getOrCreateLocation("SlingRifle2"):setAttachmentName("sling_rifle2")
AttachGroup:getOrCreateLocation("SlingRifle"):setAttachmentName("sling_rifle")

-- Large weapons
AttachGroup:getOrCreateLocation("SlingWeapon Back"):setAttachmentName("sling_weaponback")
AttachGroup:getOrCreateLocation("SlingWeaponBag"):setAttachmentName("sling_weaponbag")
AttachGroup:getOrCreateLocation("SlingBladeBag"):setAttachmentName("sling_bladebag")
AttachGroup:getOrCreateLocation("SlingWeapon3"):setAttachmentName("sling_weapon3")
AttachGroup:getOrCreateLocation("SlingWeapon2"):setAttachmentName("sling_weapon2")
AttachGroup:getOrCreateLocation("SlingWeapon"):setAttachmentName("sling_weapon")

-- Shovels
AttachGroup:getOrCreateLocation("SlingShovel Back"):setAttachmentName("sling_shovelback")
AttachGroup:getOrCreateLocation("SlingShovelBag"):setAttachmentName("sling_shovelbag")
AttachGroup:getOrCreateLocation("SlingShovel3"):setAttachmentName("sling_shovel3")
AttachGroup:getOrCreateLocation("SlingShovel2"):setAttachmentName("sling_shovel2")
AttachGroup:getOrCreateLocation("SlingShovel"):setAttachmentName("sling_shovel")
