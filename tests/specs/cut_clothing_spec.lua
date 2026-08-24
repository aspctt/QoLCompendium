--// Cut Up Any Clothing Spec
--// aspctt - 23.08.2026
--// Build 42 decides whether a garment can be cut into strips from a tag that is a separate
--// thing from the FabricType saying what it is made of, and the two disagree constantly.

--// Helpers
local SCRIPT = "qolc_cut_clothing.txt"

local function Script()
	return Harness.ReadModScript(SCRIPT)
end

local function NewGarment(FullType)
	local Item = Harness.NewInventoryItem("Garment")
	Item.FullType = FullType

	return Item
end

local function SetEnabled(Value)
	SandboxVars.QoLC = SandboxVars.QoLC or {}
	SandboxVars.QoLC.CutClothingEnabled = Value
end

--// The List
Test("the list and the script name the same garments", function()
	-- Both are written by one pass of tools/generate_cut_clothing.py, so they cannot drift
	-- apart by hand. This is what proves the pass ran for both rather than one.
	local Text = Script()
	local Missing = {}

	for FullType in pairs(QolcCutClothingAdded) do
		-- Wallets are in the list so the switch covers them, but they are containers rather
		-- than clothing and appear in the script as a recipe input, not an item block.
		if not QolcCutClothingWallets[FullType] then
			local Name = FullType:match("[^.]+$")
			if not string.find(Text, "item " .. Name .. "\n", 1, true) then
				table.insert(Missing, Name)
			end
		end
	end

	AssertEquals(#Missing, 0, "in the list but not the script: " .. table.concat(Missing, ", "))
end)

-- Nothing here checks that the names resolve against this build. The generator does it as
-- it writes, refusing to produce a file naming an item the installed game does not have,
-- and checkItemTypes in the runner does it again over the script that came out. The test
-- above ties the lua list to that same script, so a name that stopped existing fails in two
-- places already and a third would only repeat them.

Test("the strips the recipes produce are never made cuttable themselves", function()
	-- All three carry a FabricType, so a pass reading fabric alone would sweep them in and
	-- turn one strip into an endless supply of strips.
	for _, Name in ipairs({ "Base.RippedSheets", "Base.DenimStrips", "Base.LeatherStrips" }) do
		AssertNil(QolcCutClothingAdded[Name], Name .. " must not be an input to its own recipe")
	end
end)

Test("rubber footwear is left uncuttable", function()
	for _, Name in ipairs({ "Base.Shoes_FlipFlop", "Base.Shoes_Wellies", "Base.Shoes_TireSandals" }) do
		AssertNil(QolcCutClothingAdded[Name], Name .. " is rubber and yields nothing to a tailor")
	end
end)

Test("the garments the first pass missed are cuttable", function()
	-- Reported in game after 1.5.0 shipped: shoes, tights, bras, berets and ponchos all still
	-- refused. The first pass only went looking at footwear, so everything else the game had
	-- left unclassified stayed unclassified, and nothing balanced the list against the game
	-- to say so. The generator now refuses to write a file that leaves a garment out.
	--
	-- Shoes_Random is the sharpest of them: the plain shoe a fresh character starts in and
	-- the one foraging turns up, held back as a spawner while every boot beside it went in.
	local Expected = {
		["Base.Bra_Straps_Black"] = "Cotton",
		["Base.Corset"] = "Cotton",
		["Base.Garter"] = "Cotton",
		["Base.Hat_BaseballCap"] = "Cotton",
		["Base.Hat_Beret"] = "Cotton",
		["Base.HolsterSimple"] = "Leather",
		["Base.Jacket_Shellsuit_Black"] = "Cotton",
		["Base.PonchoGreen"] = "Cotton",
		["Base.Shoes_Random"] = "Leather",
		["Base.StockingsWhite"] = "Cotton",
		["Base.SwimTrunks_Blue"] = "Cotton",
		["Base.TightsBlack"] = "Cotton",
		["Base.Tie_Full"] = "Cotton",
		["Base.Trousers_Crafted_Burlap"] = "Cotton",
		["Base.Vest_Hunting_Orange"] = "Cotton"
	}

	for FullType, Fabric in pairs(Expected) do
		AssertEquals(QolcCutClothingAdded[FullType], Fabric, FullType .. " should be cuttable")
	end
end)

Test("hide and cowhide pieces give leather rather than cloth", function()
	-- These sit in families that are otherwise cotton, so a pass that labelled by family
	-- rather than by item would hand back ripped sheets from a cowhide hat.
	for _, Name in ipairs({
		"Base.Bra_Straps_Hide", "Base.Hat_Cowboy_CowHide", "Base.Hat_HideHat",
		"Base.Hat_WinterHat_SheepSkin", "Base.Holster_Hide"
	}) do
		AssertEquals(QolcCutClothingAdded[Name], "Leather", Name .. " is hide")
	end
end)

Test("what is not cloth or leather is left uncuttable", function()
	-- Each of these stands for a family the generator names and gives a reason for. They are
	-- checked here so widening the list again cannot quietly sweep one in.
	local Refused = {
		-- Crafted from a Tarp or two bin liners and duct tape. Cutting one up would convert
		-- tarpaulin into cloth strips rather than recover cloth.
		"Base.PonchoTarp", "Base.PonchoGarbageBag", "Base.Vest_Tarp", "Base.Hat_TarpHat",
		-- Already made of what cutting it would hand back.
		"Base.Briefs_Rag", "Base.Hat_LeatherStripTied",
		-- A hard shell, and armour the game gives no way back from.
		"Base.Hat_CrashHelmet", "Base.Hat_FootballHelmet", "Base.Gorget_Metal",
		"Base.Gloves_MetalArmour",
		-- The only source of aramid thread in the game, harvested rather than cut.
		"Base.Jacket_Fireman", "Base.Trousers_Fireman",
		-- Straw, paper, novelty and plastic.
		"Base.Hat_StrawHat", "Base.Hat_NewspaperHat", "Base.Hat_Spiffo",
		"Base.Hat_Cowboy_Plastic", "Base.AthleticCup",
		-- Rope and duct tape.
		"Base.RopeBelt", "Base.Holster_DuctTape",
		-- Jewellery.
		"Base.Necklace_Choker"
	}

	for _, Name in ipairs(Refused) do
		AssertNil(QolcCutClothingAdded[Name], Name .. " is not cloth or leather")
	end
end)

--// The Tags
Test("each garment is tagged for the fabric it is made of", function()
	local Text = Script()

	local Expected = {
		Cotton = "base:ripclothingcotton",
		Denim = "base:ripclothingdenim",
		Leather = "base:ripclothingleather"
	}

	for _, Fabric in pairs(QolcCutClothingAdded) do
		AssertNotNil(Expected[Fabric], "unknown fabric in the list: " .. tostring(Fabric))
	end

	for _, Tag in pairs(Expected) do
		AssertContains(Text, "Tags = " .. Tag .. ",", "the script should use " .. Tag)
	end
end)

Test("what vanilla never classified is given a fabric as well as a tag", function()
	local Text = Script()

	-- The shoes and the fingerless gloves. Vanilla declares no FabricType at all on these,
	-- and without one RecipeCodeOnCreate.ripClothing has nothing to look the strips up by.
	AssertContains(Text, "FabricType = Leather,", "leather ones need the fabric stating")
	AssertContains(Text, "FabricType = Cotton,", "and so do the cloth ones")

	for _, Name in ipairs({ "Gloves_FingerlessGloves", "Gloves_FingerlessLeatherGloves" }) do
		AssertContains(Text, "item " .. Name .. "\n", Name .. " should be cuttable")
	end
end)

Test("the misspelled vanilla tag is corrected", function()
	-- Tshirt_EMD carries base:ripclothingcoton, one letter short, so it matches nothing.
	AssertEquals(QolcCutClothingAdded["Base.Tshirt_EMD"], "Cotton", "it should be cuttable")
end)

--// The Output Mapper
-- The mapper decides what the crafting screen predicts and nothing else. What a garment
-- actually turns into is settled by RecipeCodeOnCreate.ripClothing, which reads the
-- garment's FabricType and looks the strips up in ClothingRecipesDefinitions without ever
-- consulting the mapper. So none of this is what makes leather boots give leather strips.
-- They do that on their FabricType alone.
Test("every leather garment is added to the fabric mapper", function()
	-- Vanilla's mapper lists eleven jackets and trousers by name and defaults everything
	-- else to denim, so a leather garment missing from it has the screen promise denim and
	-- then hand over leather.
	local Text = Script()
	local Missing = {}

	for FullType, Fabric in pairs(QolcCutClothingAdded) do
		-- Wallets skipped: they never go near RipDenimClothing, so they have no business in
		-- its mapper. Their own recipe has a fixed output instead.
		if Fabric == "Leather" and not QolcCutClothingWallets[FullType] then
			if not string.find(Text, "Base.LeatherStrips = " .. FullType .. ",", 1, true) then
				table.insert(Missing, FullType)
			end
		end
	end

	AssertEquals(#Missing, 0, "leather, but would give denim strips: " .. table.concat(Missing, ", "))
end)

Test("nothing that is not leather is added to the mapper", function()
	local Text = Script()

	for FullType, Fabric in pairs(QolcCutClothingAdded) do
		if Fabric ~= "Leather" then
			AssertFalse(string.find(Text, "Base.LeatherStrips = " .. FullType .. ",", 1, true) ~= nil,
				FullType .. " is " .. Fabric .. " and must not map to leather strips")
		end
	end
end)

Test("the recipe is left with the icon the game gives it", function()
	-- An icon of our own was set for a while, scissors, on the reasoning that a recipe
	-- producing two different things has no honest picture of its output. It came back out
	-- unproven: the icon tracks the output rather than the recipe, so scissors would have
	-- replaced a picture that is right far more often than it is wrong.
	--
	-- Asserted rather than simply deleted, so putting it back is a deliberate act with a
	-- reason attached rather than something that drifts in on the next regeneration.
	AssertFalse(string.find(Script(), "icon = ", 1, true) ~= nil,
		"the recipe should not name an icon until one is shown to be needed")
end)

--// Wallets
Test("wallets are cut by a recipe of their own", function()
	-- A wallet is ItemType = base:container, and RecipeCodeOnCreate.ripClothing casts its
	-- input to Clothing and asks for a FabricType. Sending one through the clothing recipes
	-- would be a cast error rather than a poor result.
	local Text = Script()

	AssertContains(Text, "craftRecipe QolcCutWallet", "wallets need their own recipe")
	AssertContains(Text, "item 1 Base.LeatherStrips,", "and a fixed output rather than a mapper")

	-- The input line lists them separated by semicolons and closed with a bracket, so the
	-- last one has no semicolon after it. Matched against the line rather than a separator.
	local Inputs = Text:match("item 1 %[(Base%.Wallet[^%]]*)%]")
	AssertNotNil(Inputs, "the wallet input line should list them")

	for FullType in pairs(QolcCutClothingWallets) do
		AssertContains(Inputs, FullType, FullType .. " should be an input to it")
	end
end)

Test("a wallet with anything in it is left alone", function()
	-- Shredding a wallet with the car keys still inside would be a poor reward for tidying.
	AssertContains(Script(), "flags[IsEmpty;ItemCount]", "the wallet input must require an empty one")
end)

Test("wallets never reach the clothing recipes", function()
	local Text = Script()

	for FullType in pairs(QolcCutClothingWallets) do
		local Name = FullType:match("[^.]+$")
		AssertFalse(string.find(Text, "item " .. Name .. "\n", 1, true) ~= nil,
			Name .. " must not be tagged as clothing")
	end
end)

--// The Switch
Test("the switch is hung on all three recipes", function()
	local Text = Script()
	local Count = 0

	for _ in string.gmatch(Text, "OnTest = Recipe%.OnTest%.QolcCutClothing") do Count = Count + 1 end
	AssertEquals(Count, 3, "RipClothing, RipDenimClothing and the wallet recipe all need it")
end)

Test("on, every garment we added is allowed through", function()
	SetEnabled(true)

	for FullType in pairs(QolcCutClothingAdded) do
		AssertTrue(Recipe.OnTest.QolcCutClothing(NewGarment(FullType), nil),
			FullType .. " should be cuttable")
	end
end)

Test("off, every garment we added is refused", function()
	SetEnabled(false)

	for FullType in pairs(QolcCutClothingAdded) do
		AssertFalse(Recipe.OnTest.QolcCutClothing(NewGarment(FullType), nil),
			FullType .. " should be refused")
	end
end)

Test("off, what vanilla already allowed is still allowed", function()
	-- The switch is bolted onto two vanilla recipes, so a wrong refusal here would stop a
	-- player cutting up a bedsheet. Everything not ours has to pass either way.
	SetEnabled(false)

	for _, FullType in ipairs({ "Base.Tshirt_White", "Base.Jacket_Leather", "Base.Sheet" }) do
		AssertTrue(Recipe.OnTest.QolcCutClothing(NewGarment(FullType), nil),
			FullType .. " was never ours to refuse")
	end
end)

Test("anything the test cannot identify is allowed through", function()
	SetEnabled(false)

	AssertTrue(Recipe.OnTest.QolcCutClothing(nil, nil), "a missing item must not be refused")
	AssertTrue(Recipe.OnTest.QolcCutClothing({}, nil), "nor one that cannot name itself")
end)

Test("a save with no setting stored gets the feature", function()
	SandboxVars.QoLC = SandboxVars.QoLC or {}
	SandboxVars.QoLC.CutClothingEnabled = nil

	AssertTrue(Recipe.OnTest.QolcCutClothing(NewGarment("Base.Shoes_Black"), nil),
		"the declared default is on")
end)
