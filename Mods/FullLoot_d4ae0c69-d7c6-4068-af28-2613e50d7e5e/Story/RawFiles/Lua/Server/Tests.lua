local Tests = {}

local _cleanupFunctions = {}
local function CleanupTests()
	for i=1,#_cleanupFunctions do
		pcall(_cleanupFunctions[i])
	end
	_cleanupFunctions = {}
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
	Mods.LeaderLib.Timer.StartOneshot("", 30000, cleanup)
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
	return host,character
end

---@param self LuaTest
local function TestDeathGeneration(self)
	local GameHelpers = Mods.LeaderLib.GameHelpers
	local host,character = SetupTrader(self, GameHelpers)
	self:Wait(250)
	local trader = Ext.Entity.GetCharacter(character)
	trader.RootTemplate.TradeTreasures[#trader.RootTemplate.TradeTreasures+1] = "ST_ArmorGenMagicTrader"
	trader.RootTemplate.TradeTreasures[#trader.RootTemplate.TradeTreasures+1] = "ST_WeaponGenMagicTrader"
	trader.TreasureGeneratedForTrader = false
	self:Wait(250)
	ApplyDamage(character, 9999, "Physical", host)
	self:Wait(3000)
	trader = Ext.Entity.GetCharacter(character)
	local items = {}
	for _,v in pairs(trader:GetInventoryItems()) do
		local item = Ext.Entity.GetItem(v)
		if item and item.Slot > 14 and not LootHelpers.ItemIsNPCItem(item) then
			self:AssertEquals(item.UnsoldGenerated, false, "Item is still trade treasure")
			items[#items+1] = item.StatsId
		end
	end
	self:AssertEquals(#items > 0, true, "Failed to generate any trade treasure")
	Ext.Utils.Print("[TestDeathGeneration] Generated treasure:")
	Ext.Utils.Print("==========")
	Ext.Dump(items)
	Ext.Utils.Print("==========")
	self:Wait(1000)
	return true
end

---@param self LuaTest
local function TestPreDeathGeneration(self)
	local GameHelpers = Mods.LeaderLib.GameHelpers
	local host,character = SetupTrader(self, GameHelpers)
	self:Wait(250)
	local trader = Ext.Entity.GetCharacter(character)
	trader.RootTemplate.TradeTreasures[#trader.RootTemplate.TradeTreasures+1] = "ST_ArmorGenMagicTrader"
	trader.RootTemplate.TradeTreasures[#trader.RootTemplate.TradeTreasures+1] = "ST_WeaponGenMagicTrader"
	self:Wait(500)
	GenerateItems(host, character)
	self:Wait(1500)
	ApplyDamage(character, 9999, "Physical", host)
	self:Wait(3000)
	trader = Ext.Entity.GetCharacter(character)
	local items = {}
	for _,v in pairs(trader:GetInventoryItems()) do
		local item = Ext.Entity.GetItem(v)
		if item and item.Slot > 14 and not LootHelpers.ItemIsNPCItem(item) then
			self:AssertEquals(item.UnsoldGenerated, false, string.format("Item (%s) is still UnsoldGenerated", item.StatsId))
			items[#items+1] = item.StatsId
		end
	end
	self:AssertEquals(#items > 0, true, "Failed to generate any trade treasure")
	Ext.Utils.Print("[TestPreDeathGeneration] Generated treasure:")
	Ext.Utils.Print("==========")
	Ext.Dump(items)
	Ext.Utils.Print("==========")
	self:Wait(1000)
	return true
end

function Tests.Init()
	local test = Mods.LeaderLib.Classes.LuaTest.Create("FullLoot.TraderTest", {TestDeathGeneration, TestPreDeathGeneration})
	test.Cleanup = CleanupTests
	Mods.LeaderLib.Testing.RegisterConsoleCommandTest("FullLoot", test, "Tests generating trader treasure / making it fully lootable when a trader dies.")
end

return Tests