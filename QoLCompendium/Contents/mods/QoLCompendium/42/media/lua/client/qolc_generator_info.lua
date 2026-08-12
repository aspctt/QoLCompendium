--// Generator Info
--// Generator Time Remaining, Workshop 2883397918 - Original idea
--// Visible Generator Range, Workshop 2972289937 - Original idea
--// aspctt - 11.08.2026
--// Two things the generator window will not tell you: how long the fuel lasts, and how
--// far the power reaches. Vanilla shows a fuel percentage, a condition and a list of what
--// is drawing power, and leaves you to guess the rest.
--//
--// Written from the game rather than ported from either mod. Better Generator Info is
--// still maintained for this build and carries its own options system on top of Mod
--// Config Menu, and Visible Generator Range is build 41 code whose numbers are now wrong,
--// so both are here as ideas only.
--//
--// The fuel maths, read out of IsoGenerator.update in this build: fuel runs zero to ten,
--// getFuelPercentage is fuel times ten, and once per in game hour the generator burns
--// totalPowerUsing multiplied by the GeneratorFuelConsumption sandbox setting. So the
--// hours left are simply the fuel over that.
--//
--// The range, read out of IsoGenerator.setGeneratorRange: build 42 turned both the tile
--// radius and the vertical reach into sandbox options, GeneratorTileRange and
--// GeneratorVerticalPowerRange, and the vertical one applies equally up and down. Visible
--// Generator Range predates all of that and hardcodes twenty tiles, two floors up and
--// three down, so it draws the wrong area for anyone who changed the setting and is a
--// floor short upwards for everybody.
--//
--// Client only. Both halves are a window and nothing reads them back.

require "ISUI/ISGeneratorInfoWindow"

--// Tuning
-- Sandbox defaults, used when a save predates the option or the table is not up yet.
-- Matching zombie.SandboxOptions: tile range 20 of 1 to 100, vertical 3 of 1 to 15.
local DEFAULT_TILE_RANGE = 20
local DEFAULT_VERTICAL_RANGE = 3
local DEFAULT_FUEL_CONSUMPTION = 1

-- The world's own floor limits, which the game clamps the vertical reach to
local WORLD_MIN_Z = -32
local WORLD_MAX_Z = 31

local HOURS_PER_DAY = 24

-- Faint enough to read the floor through. The whole radius is covered, so anything
-- stronger turns the room into a solid block of colour.
local HIGHLIGHT_ALPHA = 0.1

--// Variables
-- The tiles last worked out, and what they were worked out for. Rebuilt only when one of
-- those changes, because the radius is a couple of thousand squares at the default and
-- this is reached from prerender.
local Tiles = {}
local BuiltFor = { Generator = nil, Z = nil }
local Active = false

--// Functions
local function GetSandbox(Name, Default)
	local Value = SandboxVars and tonumber(SandboxVars[Name])
	if not Value or Value <= 0 then return Default end

	return Value
end

-- Hours before the tank runs dry, or nil when it is not burning anything
function QolcGeneratorHoursLeft(Generator)
	if not Generator or not Generator.getFuel then return nil end
	if not Generator:isActivated() then return nil end

	local Burn = Generator:getTotalPowerUsing()
	if not Burn or Burn <= 0 then return nil end

	Burn = Burn * GetSandbox("GeneratorFuelConsumption", DEFAULT_FUEL_CONSUMPTION)
	if Burn <= 0 then return nil end

	local Fuel = Generator:getFuel()
	if not Fuel or Fuel <= 0 then return 0 end

	return Fuel / Burn
end

-- Days and whole hours, so "2 days, 5 hours" rather than a bare 53
function QolcGeneratorTimeText(Hours)
	if not Hours then return nil end

	local Whole = math.floor(Hours)
	local Days = math.floor(Whole / HOURS_PER_DAY)
	local Rest = Whole - (Days * HOURS_PER_DAY)

	if Days > 0 then
		return getText("IGUI_QoLC_GeneratorDaysHours", tostring(Days), tostring(Rest))
	end

	return getText("IGUI_QoLC_GeneratorHours", tostring(Rest))
end

-- Every floor tile the generator reaches on one level. Only the player's own level is
-- ever drawn, so only that one is worked out.
local function BuildTiles(Generator, Z)
	local Square = Generator and Generator:getSquare()
	if not Square then return {} end

	local Radius = GetSandbox("GeneratorTileRange", DEFAULT_TILE_RANGE)
	local Vertical = GetSandbox("GeneratorVerticalPowerRange", DEFAULT_VERTICAL_RANGE)

	-- The same clamp the game applies, equally up and down
	local MinZ = math.max(WORLD_MIN_Z, Square:getZ() - Vertical)
	local MaxZ = math.min(WORLD_MAX_Z, Square:getZ() + Vertical)
	if Z < MinZ or Z > MaxZ then return {} end

	local CentreX = Square:getX()
	local CentreY = Square:getY()
	local Reach = Radius * Radius

	local Outside = SandboxVars and SandboxVars.AllowExteriorGenerator
	local Found = {}
	local Cell = getCell()

	for X = CentreX - Radius, CentreX + Radius do
		for Y = CentreY - Radius, CentreY + Radius do
			if math.floor(IsoUtils.DistanceToSquared(X + 0.5, Y + 0.5, CentreX + 0.5, CentreY + 0.5)) <= Reach then
				local Target = Cell:getOrCreateGridSquare(X, Y, Z)

				if Target and (Outside or not Target:isOutside())
					and Target:getFloor() and Target:isSolidFloor() then
					table.insert(Found, { X = X, Y = Y })
				end
			end
		end
	end

	return Found
end

local function Draw(Generator)
	local Player = getPlayer()
	local Square = Player and Player:getSquare()
	if not Square then return end

	local Z = Square:getZ()

	-- The player walking to another floor changes which tiles are drawn, so it is part of
	-- what the cache is keyed on
	if BuiltFor.Generator ~= Generator or BuiltFor.Z ~= Z then
		Tiles = BuildTiles(Generator, Z)
		BuiltFor.Generator = Generator
		BuiltFor.Z = Z
	end

	local Colour = Generator:isActivated()
		and getCore():getGoodHighlitedColor()
		or getCore():getBadHighlitedColor()

	for _, Tile in ipairs(Tiles) do
		addAreaHighlight(Tile.X, Tile.Y, Tile.X + 1, Tile.Y + 1, Z,
			Colour:getR(), Colour:getG(), Colour:getB(), HIGHLIGHT_ALPHA)
	end
end

local function Stop()
	Active = false
	Tiles = {}
	BuiltFor.Generator = nil
	BuiltFor.Z = nil
end

--// Overrides
-- The window builds its own text and this appends one line to it. Static rather than a
-- method, so it is wrapped as a plain function.
local VanillaRichText = ISGeneratorInfoWindow.getRichText
function ISGeneratorInfoWindow.getRichText(Object, DisplayStats)
	local Text = VanillaRichText(Object, DisplayStats)

	-- The short form, drawn on the object rather than in the window, has no stats to
	-- add a line to
	if not DisplayStats then return Text end

	local Time = QolcGeneratorTimeText(QolcGeneratorHoursLeft(Object))
	if not Time then return Text end

	return Text .. " <LINE> " .. Time
end

local VanillaPrerender = ISGeneratorInfoWindow.prerender
function ISGeneratorInfoWindow:prerender(...)
	if Active and self.object then Draw(self.object) end
	return VanillaPrerender(self, ...)
end

-- Closing the window is the only reliable point to stop. setVisible covers hiding it and
-- removeFromUIManager covers it being taken away entirely, which does not always hide it
-- first.
local VanillaSetVisible = ISGeneratorInfoWindow.setVisible
function ISGeneratorInfoWindow:setVisible(Visible, ...)
	if Visible then Active = true else Stop() end
	return VanillaSetVisible(self, Visible, ...)
end

local VanillaRemove = ISGeneratorInfoWindow.removeFromUIManager
function ISGeneratorInfoWindow:removeFromUIManager(...)
	Stop()
	return VanillaRemove(self, ...)
end
