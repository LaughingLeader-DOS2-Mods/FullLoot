
---@param item EsvItem
local function GetItemOwner(item)
	if Ext.Utils.IsValidHandle(item.OwnerHandle) then
		return Ext.Entity.GetGameObject(item.OwnerHandle)
	end
	if Ext.Utils.IsValidHandle(item.InUseByCharacterHandle) then
		return Ext.Entity.GetGameObject(item.InUseByCharacterHandle)
	end
	return nil
end

---@param str string
---@return string
local function GetGUID(str)
	local result = str
	local start = string.find(str, "_[^_]*$") or 0
	if start > 0 then
		result = string.sub(str, start+1)
	end
	return result
end

---@param guid string
---@param timerName string
Ext.Osiris.RegisterListener("ProcObjectTimerFinished", 2, "before", function (guid, timerName)
	if timerName == "LLFULOOT_MakeItemsLootable" then
		guid = GetGUID(guid)
		local character = Ext.Entity.GetCharacter(guid) --[[@as EsvCharacter]]
		if character then
			for _,v in pairs(character:GetInventoryItems()) do
				local item = Ext.Entity.GetItem(v)
				if item and item.UnsoldGenerated then
					item.UnsoldGenerated = false
					ObjectSetFlag(item.MyGuid, "LLFULOOT_TradeItemMadeLootable", 0)
				end
			end
			CharacterSetCorpseLootable(character.MyGuid, 1)
		end
	elseif timerName == "LLFULOOT_AdjustGold" then
		guid = GetGUID(guid)
		local character = Ext.Entity.GetCharacter(guid)
		if character then
			local gold = PersistentVars.GoldAmount[character.MyGuid] or 0
			PersistentVars.GoldAmount[character.MyGuid] = nil
			local fourth = GlobalGetFlag("LLFULOOT_GoldReduction_Fourth") == 1
			local half = GlobalGetFlag("LLFULOOT_GoldReduction_Half") == 1
			if gold > 0 and (half or fourth) then
				local goldReduced = gold
				if fourth then
					goldReduced = math.ceil(gold/4)
				else
					goldReduced = math.ceil(gold/2)
				end
				for _,v in pairs(character:GetInventoryItems()) do
					local item = Ext.Entity.GetItem(v)
					if item and item.StatsId == "Gold" or GetTemplate(v) == "LOOT_Gold_A_1c3c9c74-34a1-4685-989e-410dc080be6f" then
						ItemRemove(v)
					end
				end
				if goldReduced > 0 then
					if Ext.Debug.IsDeveloperMode() then
						Ext.Utils.Print(string.format("[FullLoot] Reducing trader's (%s) lootable gold from (%s) to (%s)", character.DisplayName, gold, goldReduced))
					end
					CharacterAddGold(guid, goldReduced)
				end
			end
		else
			PersistentVars.GoldAmount[guid] = nil
		end
	end
end)

local _ARMORSLOT = {
	Helmet = 0,
	Breast = 1,
	Leggings = 2,
	--Weapon = 3,
	--Shield = 4,
	Ring = 5,
	Belt = 6,
	Boots = 7,
	Gloves = 8,
	Amulet = 9,
	Ring2 = 10,
}

local NULL_UUID = {
	["NULL_00000000-0000-0000-0000-000000000000"] = true,
	["00000000-0000-0000-0000-000000000000"] = true
}

---@param item EsvItem
local function _ItemIsNPCItem(item)
	local statsId = item.StatsId
	if item.Stats then
		statsId = item.Stats.Name
	elseif item.StatsFromName then
		statsId = item.StatsFromName.Name
	end
	if string.sub(statsId, 1, 1) == "_" then
		return true
	end
	return false
end

---@param character EsvCharacter
local function _CannotDie(character)
	if character.Dead then
		return false
	end
	if character.CannotDie then
		return true
	end
	--TODO SetInvulnerable_UseProcSetInvulnerable flag, once it's been mapped
	--[[ for _,v in pairs(character.Flags) do
		if v == "CannotDie" then
			return true
		end
	end ]]
end

---@param character EsvCharacter
local function _IsTrader(character)
	if not character:HasTag("LLFULOOT_LootDisabled")
	and not character.IsPlayer
	and not character.Summon
	and not character.PartyFollower
	then
		local tradeTreasures = character.RootTemplate.TradeTreasures or {}
		local totalTradeTreasures = #tradeTreasures
		return (character:HasTag("TRADER") or character.Trader) and totalTradeTreasures > 0
	end
	return false
end

---@param guid string
Ext.Osiris.RegisterListener("CharacterKilledBy", 1, "before", function (guid, owner, attacker)
	if GlobalGetFlag("LLFULOOT_PVPLootEnabled") == 1 then
		local character = Ext.Entity.GetCharacter(guid) --[[@as EsvCharacter]]
		if character and not character:HasTag("LLFULOOT_LootDisabled")
		and character.IsPlayer
		and not character.Summon
		and not character.PartyFollower
		and (CharacterIsPlayer(owner) == 1 or CharacterIsPlayer(attacker) == 1)
		and CharacterIsInPartyWith(character.MyGuid, owner) == 0
		then
			CharacterSetCorpseLootable(guid, 1)
		end
	end
end)

---@param guid string
Ext.Osiris.RegisterListener("CharacterResurrected", 1, "after", function (guid)
	--If a trader gets resurrected somehow, reset treasure
	local character = Ext.Entity.GetCharacter(guid) --[[@as EsvCharacter]]
	if character and _IsTrader(character) then
		for _,v in pairs(character:GetInventoryItems()) do
			local item = Ext.Entity.GetItem(v)
			if item and item.Slot > 14 and not _ItemIsNPCItem(item) then
				if ObjectGetFlag(item.MyGuid, "LLFULOOT_TradeItemMadeLootable") == 1 then
					item.UnsoldGenerated = true
					ObjectClearFlag(item.MyGuid, "LLFULOOT_TradeItemMadeLootable", 0)
				elseif ObjectGetFlag(item.MyGuid, "LLFULOOT_EquipmentItemMadeLootable") == 1 then
					CharacterEquipItem(character.MyGuid, item.MyGuid)
					ObjectClearFlag(item.MyGuid, "LLFULOOT_EquipmentItemMadeLootable", 0)
				end
			end
		end
	end
end)

---@param guid string
Ext.Osiris.RegisterListener("TradeGenerationEnded", 1, "after", function (guid)
	if CharacterIsDead(guid) == 1 or HasActiveStatus(guid, "DYING") == 1 then
		Osi.ProcObjectTimerCancel(guid, "LLFULOOT_MakeItemsLootable")
		Osi.ProcObjectTimer(guid, "LLFULOOT_MakeItemsLootable", 500)
	end
end)

---@param guid GUID
Ext.Osiris.RegisterListener("CharacterPrecogDying", 1, "before", function (guid)
	if GlobalGetFlag("LLFULOOT_LootDisabled") == 0 and ObjectExists(guid) == 1 then
		local character = Ext.Entity.GetCharacter(guid) --[[@as EsvCharacter]]
		if character then
			if not _CannotDie(character) and _IsTrader(character) then
				local host = CharacterGetHostCharacter()
				if not character.TreasureGeneratedForTrader then
					GenerateItems(host, guid)
					Osi.ProcObjectTimerCancel(guid, "LLFULOOT_MakeItemsLootable")
					Osi.ProcObjectTimer(guid, "LLFULOOT_MakeItemsLootable", 500)
				else
					for _,v in pairs(character:GetInventoryItems()) do
						local item = Ext.Entity.GetItem(v) --[[@as EsvItem]]
						if item and item.UnsoldGenerated and not _ItemIsNPCItem(item) then
							item.UnsoldGenerated = false
							ObjectSetFlag(item.MyGuid, "LLFULOOT_TradeItemMadeLootable", 0)
						end
					end
				end
				if GlobalGetFlag("LLFULOOT_AdjustGoldAmounts") == 1 then
					local gold = CharacterGetGold(guid)
					if gold and gold > 0 then
						PersistentVars.GoldAmount[character.MyGuid] = gold
						Osi.ProcObjectTimerCancel(guid, "LLFULOOT_AdjustGold")
						Osi.ProcObjectTimer(guid, "LLFULOOT_AdjustGold", 500)
					end
				end

				if GlobalGetFlag("LLFULOOT_EquippedArmorLootable") == 1 then
					for slot,_ in pairs(_ARMORSLOT) do
						local itemGUID = CharacterGetEquippedItem(guid, slot)
						if not NULL_UUID[itemGUID] then
							local item = Ext.Entity.GetItem(itemGUID) --[[@as EsvItem]]
							if item and string.sub(item.StatsId, 1, 1) ~= "_" then
								ObjectSetFlag(guid, "LLFULOOT_EquipmentItemMadeLootable", 0)
								ItemToInventory(itemGUID, guid, 1, 0, 1)
							end
						end
					end
				end

				if GlobalGetFlag("LLFULOOT_EquippedWeaponsLootable") == 1 then
					local mainhand = CharacterGetEquippedItem(guid, "Weapon")
					local offhand = CharacterGetEquippedItem(guid, "Shield")
					if not NULL_UUID[mainhand] then
						local item = Ext.Entity.GetItem(mainhand) --[[@as EsvItem]]
						if item and string.sub(item.StatsId, 1, 1) ~= "_" then
							ObjectSetFlag(guid, "LLFULOOT_EquipmentItemMadeLootable", 0)
							ItemToInventory(mainhand, guid, 1, 0, 1)
						end
					end
					if not NULL_UUID[offhand] then
						local item = Ext.Entity.GetItem(offhand) --[[@as EsvItem]]
						if item and string.sub(item.StatsId, 1, 1) ~= "_" then
							ObjectSetFlag(guid, "LLFULOOT_EquipmentItemMadeLootable", 0)
							ItemToInventory(offhand, guid, 1, 0, 1)
						end
					end
				end
			end
		end
	end
end)

LootHelpers = {
	ItemIsNPCItem = _ItemIsNPCItem,
	GetItemOwner = GetItemOwner,
	IsTrader = _IsTrader,
	CannotDie = _CannotDie,
}