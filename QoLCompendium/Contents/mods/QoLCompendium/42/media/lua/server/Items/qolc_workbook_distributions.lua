--// DIY Workbook Distributions
--// Def's Long Term Survival, Workshop 1962914415 - Original idea, by DefbeatCZ
--// Original distribution work by DefbeatCZ
--// aspctt - 28.08.2026
--// Where the four practice manuals turn up: bookshops, the post office, libraries and the
--// shelves of anyone who owned one. The tables and the weights are the original's, and all
--// four still exist in build 42.
--//
--// All four books share one placement, which is the original's answer and the right one:
--// a shop that stocks one DIY manual stocks the lot, and giving the welding one rarer
--// odds than the carpentry one would say something about the world that is not true.
--//
--// Done from OnPreDistributionMerge rather than at file scope. At file scope the tables
--// may not be built yet, and anything a later mod adds is missed.
--//
--// The seeding is unconditional and the switch is handed to qolc_loot_switch. It has to
--// be: the sandbox options are not read from the save until after all three merge events
--// have fired, so a test here reads our own declared default rather than the player's
--// answer. That file has the whole story.
--//
--// Server side, so the tables are built once and authoritatively.

require "Items/ProceduralDistributions"
require "qolc_loot_switch"

--// Tuning
local BOOKS = {
	"Base.QolcWorkbookCarpentry",
	"Base.QolcWorkbookElectrical",
	"Base.QolcWorkbookTailoring",
	"Base.QolcWorkbookWelding",
}

-- The original's weights. A bookshop is the reliable source and a living room is luck.
local PLACES = {
	BookstoreBooks = 0.6,
	LibraryBooks = 0.5,
	PostOfficeBooks = 0.3,
	LivingRoomShelf = 0.3,
}

--// Switch
QolcLootSwitch.Withhold("WorkbooksEnabled", BOOKS)

--// Functions
local function Holds(Items, Name)
	for Index = 1, #Items - 1, 2 do
		if Items[Index] == Name then return true end
	end

	return false
end

local function AddTo(Items, Weight)
	if type(Items) ~= "table" then return end

	for _, Name in ipairs(BOOKS) do
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

	local Missing = {}

	for Name, Weight in pairs(PLACES) do
		local Room = ProceduralDistributions.list[Name]
		if Room then
			AddTo(Room.items, Weight)
		else
			table.insert(Missing, Name)
		end
	end

	-- A vanilla table renamed by an update should say so, rather than silently spawning
	-- nothing at all
	for _, Name in ipairs(Missing) do
		print("QoL Compendium: workbook spawn target not found, ProceduralDistributions.list." .. Name)
	end
end

Events.OnPreDistributionMerge.Add(OnPreDistributionMerge)
