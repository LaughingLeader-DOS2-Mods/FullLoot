local Tests = {}

local _testing = false
local _cleanupFunctions = {}

local function CleanupTests()
	for i=1,#_cleanupFunctions do
		pcall(_cleanupFunctions[i])
	end
	_cleanupFunctions = {}
	_testing = false
end

local function SetupTrader(test, GameHelpers)
	local host = CharacterGetHostCharacter()
	local pos = {GameHelpers.Grid.GetValidPositionInRadius(GameHelpers.Math.ExtendPositionWithForwardDirection(host, 6), 6.0)}
	--LLWEAPONEX_Debug_MasteryDummy_2ac80a2a-8326-4131-a03c-53906927f935
	local character = TemporaryCharacterCreateAtPosition(pos[1], pos[2], pos[3], "fa7e070a-8590-48ee-af56-90dbae39580b", 0)
	local cleanup = function ()
		if ObjectExists(character) == 1 then
			RemoveTemporaryCharacter(character)
		end
	end
	_cleanupFunctions[#_cleanupFunctions+1] = cleanup
	Mods.LeaderLib.Timer.StartOneshot("", 60000, cleanup)
	SetStoryEvent(character, "ClearPeaceReturn")
	CharacterSetReactionPriority(character, "StateManager", 0)
	CharacterSetReactionPriority(character, "ResetInternalState", 0)
	CharacterSetReactionPriority(character, "ReturnToPeacePosition", 0)
	CharacterSetReactionPriority(character, "CowerIfNeutralSeeCombat", 0)
	SetTag(character, "LeaderLib_TemporaryCharacter")
	SetTag(character, "NO_ARMOR_REGEN")
	SetFaction(character, "PVP_1")
	SetCanJoinCombat(character, 0)
	SetCanFight(character, 0)
	CharacterDisableAllCrimes(character)
	CharacterEnableCrimeWarnings(character, 0)
	CharacterSetCustomName(character, "Test Trader")
	return host,character
end

---@param self LuaTest
local function TestTradeDeath(self, doGenerateTreasure)
	local GameHelpers = Mods.LeaderLib.GameHelpers
	local host,character = SetupTrader(self, GameHelpers)
	self:Wait(250)
	local trader = Ext.Entity.GetCharacter(character) --[[@as EsvCharacter]]
	trader.CurrentTemplate.TradeTreasures[#trader.CurrentTemplate.TradeTreasures+1] = "ST_ArmorGenMagicTrader"
	trader.CurrentTemplate.TradeTreasures[#trader.CurrentTemplate.TradeTreasures+1] = "ST_WeaponGenMagicTrader"
	if doGenerateTreasure then
		GenerateItems(host, character)
		trader.TreasureGeneratedForTrader = true
	else
		trader.TreasureGeneratedForTrader = false
	end
	self:Wait(250)
	local totalItems = 0
	trader = Ext.Entity.GetCharacter(character) --[[@as EsvCharacter]]
	for _,v in pairs(trader:GetInventoryItems()) do
		local item = Ext.Entity.GetItem(v) --[[@as EsvItem]]
		if item and item.Slot > 14 and not LootHelpers.ItemIsNPCItem(item) then
			totalItems = totalItems + 1
		end
	end
	ApplyDamage(character, 9999, "Physical", host)
	self:Wait(3000)
	trader = Ext.Entity.GetCharacter(character) --[[@as EsvCharacter]]
	local items = {}
	local nextTotal = 0
	for _,v in pairs(trader:GetInventoryItems()) do
		local item = Ext.Entity.GetItem(v) --[[@as EsvItem]]
		if item and item.Slot > 14 and not LootHelpers.ItemIsNPCItem(item) then
			self:AssertNotEquals(item.UnsoldGenerated, true, string.format("Item %s is still trade treasure UnsoldGenerated(%s)", item.StatsId, item.UnsoldGenerated))
			nextTotal = nextTotal + 1
			items[nextTotal] = item.StatsId
		end
	end
	self:AssertEquals(nextTotal > 0, true, "Failed to generate any trade treasure")
	self:AssertEquals(nextTotal >= totalItems, true, string.format("Lost items from death before(%s) => after(%s)", totalItems, nextTotal))
	--table.sort(items)
	local calculatedItems = {}
	for i=1,nextTotal do
		local id = items[i]
		if calculatedItems[id] then
			calculatedItems[id] = calculatedItems[id] + 1
		else
			calculatedItems[id] = 1
		end
	end
	Ext.Utils.Print("Generated treasure:")
	Ext.Utils.Print("==========")
	Ext.Dump(calculatedItems)
	Ext.Utils.Print("==========")
	self:Wait(1000)
	return true
end

---@param self LuaTest
local function TestDeathGeneration(self)
	_testing = true
	Ext.Utils.Print("[TestDeathGeneration] Testing generating trade treasure on death.")
	TestTradeDeath(self, false)
	return true
end

---@param self LuaTest
local function TestPreDeathGeneration(self)
	_testing = true
	Ext.Utils.Print("[TestDeathGeneration] Testing making pre-generated trade treasure lootable.")
	TestTradeDeath(self, true)
	return true
end

function Tests.Init()
	local test = Mods.LeaderLib.Classes.LuaTest:Create("FullLoot.TraderTest", {TestDeathGeneration, TestPreDeathGeneration})
	test.Cleanup = CleanupTests
	Mods.LeaderLib.Testing.RegisterConsoleCommandTest("fullloot", test, "Tests generating trader treasure / making it fully lootable when a trader dies.")
end

return Tests