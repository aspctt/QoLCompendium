--// Lockpicking Distributions
--// Lockpicking. Just. Lockpicking., Workshop 2056238799
--// Original distribution work by Oh God Spiders No
--// aspctt - 18.08.2026
--// Where the two volumes turn up: bookshops, libraries, magazine racks and the shelves
--// of anyone who owned one. The weights are the original's, and all ten tables it named
--// still exist in build 42. The hairpin rides along here too, since it is the one item
--// this feature adds that a player has to find rather than make.
--//
--// Done from OnPreDistributionMerge rather than at file scope, which is where the
--// original wrote straight into the tables. At file scope the tables may not be built
--// yet, and anything a later mod adds is missed.
--//
--// Server side, so the tables are built once and authoritatively. Switched from the
--// sandbox page rather than mod options, because loot balance has to match across a
--// multiplayer session.
--//
--// The seeding itself is unconditional, and the switch is handed to qolc_loot_switch.
--// It has to be: the sandbox options are not read from the save until after all three
--// merge events have fired, so a test here reads our own declared default rather than
--// the player's answer. That file has the whole story.

require "Items/ProceduralDistributions"
require "qolc_loot_switch"

--// Tuning
local BOOKS = { "Base.QolcLockpickBook1", "Base.QolcLockpickBook2" }
local HAIRPINS = { "Base.QolcHairpin" }

-- Where a locksmithing manual would plausibly sit, at the original's weights. A bookshop
-- or a tool shop is the reliable source; a living room is a lucky find.
local BOOK_PLACES = {
	BookstoreBooks = 2,
	ToolStoreBooks = 2,
	ElectronicStoreMagazines = 4,
	CrateMagazines = 1,
	LibraryBooks = 1,
	PostOfficeMagazines = 1,
	MagazineRackMixed = 0.5,
	LivingRoomShelf = 0.1,
	LivingRoomShelfNoTapes = 0.1,
	ShelfGeneric = 0.1,
}

-- The hairpin keeps the company hairpins keep: bathroom shelves, bedroom dressers, the
-- cosmetics aisle, a salon. It is worth nothing on its own beyond becoming a lockpick, so
-- it is deliberately not in tool boxes or hardware stores, where finding one would say
-- something about the world that is not true. Weights sit near lipstick's in each table,
-- and drop to a token in the furniture where make-up is itself a rare find.
local HAIRPIN_PLACES = {
	BedroomSidetableClassy = 0.5,
	BedroomDresserClassy = 0.5,
	SalonShelfHaircare = 10,
	CrateSalonSupplies = 10,
	GigamartCosmetics = 10,
	StripClubCosmetic = 20,
	PharmacyCosmetics = 10,
	StripClubDressers = 6,
	BackstageDresser = 6,
	BackstageLockers = 6,
	BackstageCounter = 6,
	BathroomCabinet = 6,
	BathroomCounter = 6,
	BedroomDresser = 2,
	WardrobeClassy = 0.5,
	SalonCounter = 10,
	BathroomShelf = 6,
	DresserGeneric = 2,
	BinBathroom = 1,
}

-- Each list against the tables it belongs in.
local SETS = {
	{ Items = BOOKS, Places = BOOK_PLACES },
	{ Items = HAIRPINS, Places = HAIRPIN_PLACES },
}

--// Switch
-- Split the way the feature is split. The first manual teaches making a pick and the
-- hairpins are what you make one from, so both answer to lockpicking. The second manual
-- teaches nothing but the crowbar, so it answers to prying.
QolcLootSwitch.Withhold("LockpickingEnabled", {
	"Base.QolcLockpickBook1",
	"Base.QolcHairpin",
})

QolcLootSwitch.Withhold("PryingEnabled", {
	"Base.QolcLockpickBook2",
})

--// Functions
local function Holds(Items, Name)
	for Index = 1, #Items - 1, 2 do
		if Items[Index] == Name then return true end
	end

	return false
end

local function AddTo(Items, Adding, Weight)
	if type(Items) ~= "table" then return end

	for _, Name in ipairs(Adding) do
		-- OnPreDistributionMerge can fire more than once, and a second copy would double
		-- the odds without anyone noticing
		if not Holds(Items, Name) then
			table.insert(Items, Name)
			table.insert(Items, Weight)
		end
	end
end

--// Connections
local function OnPreDistributionMerge()
	if not ProceduralDistributions or not ProceduralDistributions.list then return end

	for _, Set in ipairs(SETS) do
		for Name, Weight in pairs(Set.Places) do
			local Room = ProceduralDistributions.list[Name]
			if Room then AddTo(Room.items, Set.Items, Weight) end
		end
	end
end

Events.OnPreDistributionMerge.Add(OnPreDistributionMerge)
