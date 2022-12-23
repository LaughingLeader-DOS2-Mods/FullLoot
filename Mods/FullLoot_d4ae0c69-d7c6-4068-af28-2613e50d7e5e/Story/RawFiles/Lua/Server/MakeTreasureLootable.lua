
local function _PrintDebug(msg, ...)
	Ext.Utils.Print(string.format(msg, ...))
end

if not Ext.Debug.IsDeveloperMode() then
	_PrintDebug = function () end
end

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

---@param character EsvCharacter
local function MoveItemsToTempBackpack(character)
	local backpack = CreateItemTemplateAtPosition("394d4e05-b258-4b3f-a78b-eff97a25b231", 0, 0, 0)
	MoveAllItemsTo(character.MyGuid, backpack, 0, 0, 1)
	PersistentVars.TempBackpack[GetGUID(backpack)] = character.MyGuid
	SetVarObject(backpack, "LLFULLOOT_Target", character.MyGuid)
end

---@param character EsvCharacter
local function MakeItemsLootable(character)
	if not character.CorpseLootable then
		_PrintDebug("[FullLoot:LLFULOOT_AdjustGold] Trader (%s) - Making items lootable.", character.DisplayName)
		CharacterSetCorpseLootable(character.MyGuid, 1)
	end
	for _,v in pairs(character:GetInventoryItems()) do
		local item = Ext.Entity.GetItem(v)
		if item and item.UnsoldGenerated then
			item.UnsoldGenerated = false
			ObjectSetFlag(item.MyGuid, "LLFULOOT_TradeItemMadeLootable", 0)
		end
	end
end

---@param guid string
---@param timerName string
Ext.Osiris.RegisterListener("ProcObjectTimerFinished", 2, "before", function (guid, timerName)
	if timerName == "LLFULOOT_MakeItemsLootable" then
		local character = Ext.Entity.GetCharacter(guid) --[[@as EsvCharacter]]
		if character then
			MakeItemsLootable(character)
		end
	elseif timerName == "LLFULOOT_MoveItemsToCorpse" then
		local owner = GetVarObject(guid, "LLFULLOOT_Target")
		MoveAllItemsTo(guid, owner, 0, 0, 1)
		Osi.ProcObjectTimerCancel(guid, "LLFULOOT_DeleteBackpack")
		Osi.ProcObjectTimer(guid, "LLFULOOT_DeleteBackpack", 250)
	elseif timerName == "LLFULOOT_DeleteBackpack" then
		ItemRemove(guid)
		PersistentVars.TempBackpack[guid] = nil
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
					_PrintDebug("[FullLoot:LLFULOOT_AdjustGold] Trader (%s) - Reducing lootable gold from (%s) to (%s)", character.DisplayName, gold, goldReduced)
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
		local tradeTreasures = character.CurrentTemplate.TradeTreasures or {}
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
			_PrintDebug("[FullLoot:LLFULOOT_AdjustGold] (%s) - Making corpse lootable.", character.DisplayName)
		end
	end
end)

---@param guid string
Ext.Osiris.RegisterListener("CharacterResurrected", 1, "after", function (guid)
	--If a trader gets resurrected somehow, reset treasure
	local character = Ext.Entity.GetCharacter(guid) --[[@as EsvCharacter]]
	if character and _IsTrader(character) then
		_PrintDebug("[FullLoot:CharacterResurrected] Trader (%s) - Reverting lootable items.", character.DisplayName)
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

---@param stat StatEntryWeapon
---@return StatEntryWeapon|nil
local function FindRootParent(stat)
	if not stat then
		return nil
	end
	if stat.Using and stat.Using ~= "" then
		return FindRootParent(Ext.Stats.Get(stat.Using, nil, false))
	else
		return stat
	end
end

---@param item EsvItem
---@return string
local function GetTemplatGUID(item)
	if item.RootTemplate.RootTemplate ~= "" then
		return item.RootTemplate.RootTemplate
	else
		return item.RootTemplate.Id
	end
end

---@param stat StatEntryWeapon
---@return string|nil
local function GetItemRootTemplate(stat)
	if stat.ItemGroup ~= "" then
		local itemGroup = Ext.Stats.ItemGroup.GetLegacy(stat.ItemGroup)
		if itemGroup then
			for _,lg in pairs(itemGroup.LevelGroups) do
				for _,rg in pairs(lg.RootGroups) do
					if rg.RootGroup ~= "" then
						return rg.RootGroup
					end
				end
			end
		end
	end
	return nil
end

---@param item EsvItem
---@param character EsvCharacter
---@return EsvItem|nil
local function MakeUsableWeapon(item, character)
	if string.sub(item.StatsId, 1, 1) == "_" then -- NPC item
		local stat = FindRootParent(item.Stats.StatsEntry)
		if stat then
			if string.sub(stat.Name, 1, 1) == "_" then
				local baseDerived = Ext.Stats.Get("WPN_" .. stat.Name, nil, false)
				if baseDerived then
					stat = baseDerived
				else
					stat = nil
				end
			end
			if stat then
				local template = nil
				if item.Stats.StatsEntry.ItemGroup ~= "EMPTY" then
					template = GetTemplatGUID(item)
				else
					template = GetItemRootTemplate(stat)
				end
				if template then
					local constructor = Ext.CreateItemConstructor(template)
					---@type EocItemDefinition
					local props = constructor[1]
					props:ResetProgression()
					props.IsIdentified = true
					props.StatsLevel = character.Stats.Level
					props.GenerationLevel = character.Stats.Level

					local newItem = constructor:Construct()
					if newItem then
						NRD_ItemSetIdentified(newItem.MyGuid, 1)
						return newItem
					end
				end
			end
		end
	else
		return item
	end
end

---@param guid GUID
Ext.Osiris.RegisterListener("CharacterPrecogDying", 1, "before", function (guid)
	if GlobalGetFlag("LLFULOOT_LootDisabled") == 0 and ObjectExists(guid) == 1 then
		local character = Ext.Entity.GetCharacter(guid) --[[@as EsvCharacter]]
		if character then
			guid = GetGUID(guid)
			if not _CannotDie(character) and _IsTrader(character) then
				local host = CharacterGetHostCharacter()
				if not character.TreasureGeneratedForTrader then
					_PrintDebug("[FullLoot:CharacterPrecogDying] Trader (%s) - Generating treasure.", character.DisplayName)
					GenerateItems(host, guid)
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
						if item then
							local lootableItem = MakeUsableWeapon(item, character)
							if lootableItem then
								ObjectSetFlag(lootableItem.MyGuid, "LLFULOOT_EquipmentItemMadeLootable", 0)
								ItemToInventory(lootableItem.MyGuid, guid, 1, 0, 1)
							end
						end
					end
					if not NULL_UUID[offhand] then
						local item = Ext.Entity.GetItem(offhand) --[[@as EsvItem]]
						if item then
							local lootableItem = MakeUsableWeapon(item, character)
							if lootableItem then
								ObjectSetFlag(lootableItem.MyGuid, "LLFULOOT_EquipmentItemMadeLootable", 0)
								ItemToInventory(lootableItem.MyGuid, guid, 1, 0, 1)
							end
						end
					end
				end

				MakeItemsLootable(character)
				MoveItemsToTempBackpack(character)
			end
		end
	end
end)

---@param guid string
Ext.Osiris.RegisterListener("CharacterDied", 1, "before", function (guid)
	guid = GetGUID(guid)
	for backpack,charGUID in pairs(PersistentVars.TempBackpack) do
		if charGUID == guid then
			Osi.ProcObjectTimerCancel(backpack, "LLFULOOT_MoveItemsToCorpse")
			Osi.ProcObjectTimer(backpack, "LLFULOOT_MoveItemsToCorpse", 250)
		end
	end
end)

local function _RestartLootableTimer(guid)
	if CharacterIsDead(guid) == 1 or HasActiveStatus(guid, "DYING") == 1 then
		guid = GetGUID(guid)
		Osi.ProcObjectTimerCancel(guid, "LLFULOOT_MakeItemsLootable")
		Osi.ProcObjectTimer(guid, "LLFULOOT_MakeItemsLootable", 500)
	end
end

---@param guid string
Ext.Osiris.RegisterListener("TradeGenerationEnded", 1, "after", _RestartLootableTimer)

Ext.Osiris.RegisterListener("ItemAddedToCharacter", 2, "after", function (itemGUID, charGUID)
	_RestartLootableTimer(charGUID)
end)

LootHelpers = {
	ItemIsNPCItem = _ItemIsNPCItem,
	GetItemOwner = GetItemOwner,
	IsTrader = _IsTrader,
	CannotDie = _CannotDie,
}