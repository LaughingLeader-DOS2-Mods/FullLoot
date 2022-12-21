Ext.Require("Shared.lua")
Ext.Require("Server/MakeTreasureLootable.lua")
Ext.Require("Server/TraderDifficulty.lua")
local Tests = Ext.Require("Server/Tests.lua")

---@class FullLootPersistentVars
local _defaultPersistentVars = {
	---@type table<GUID, integer>
	GoldAmount = {}
}

local function CopyTable(source)
	local tbl = {}
	for k,v in pairs(source) do
		tbl[k] = v
	end
	return tbl
end

---@type FullLootPersistentVars
PersistentVars = CopyTable(_defaultPersistentVars)

---Add key/value entries to target from addFrom, optionally skipping if that key exists already.
---@param target table
---@param addFrom table
---@param skipExisting boolean|nil If true, existing values aren't updated.
---@param deep boolean|nil If true, iterate into table values to AddOrUpdate them as well.
---@return table target Returns the target table.
local function _AddOrUpdate(target, addFrom, deep)
	if type(target) ~= "table" or type(addFrom) ~= "table" then
		return target
	end
	for k,v in pairs(addFrom) do
		local existing = target[k]
		if existing == nil then
			target[k] = v
		else
			if deep and (type(v) == "table" and type(existing) == "table") then
				_AddOrUpdate(existing, v, deep)
			else
				target[k] = v
			end
		end
	end
	return target
end

---Only assigns values from addFrom if they already exist in target.
---@param target table
---@param addFrom table
---@return table
local function _CopyExistingKeys(target, addFrom)
	if target == nil or addFrom == nil then
		return target
	end
	for k,v in pairs(target) do
		local newValue = addFrom[k]
		if newValue ~= nil then
			if type(v) == "table" then
				_AddOrUpdate(v, newValue, true)
			else
				target[k] = newValue
			end
		end
	end
	return target
end

local function _InitPersistentVars()
	PersistentVars = _CopyExistingKeys(_defaultPersistentVars, PersistentVars)
end

Ext.Osiris.RegisterListener("GameStarted", 2, "after", function (...)
	_InitPersistentVars()
end)

Ext.Events.SessionLoaded:Subscribe(function (e)
	if Mods.LeaderLib then
		Mods.LeaderLib.Events.PersistentVarsLoaded:Subscribe(function (_)
			_InitPersistentVars()
		end)

		if Ext.Debug.IsDeveloperMode() then
			Tests.Init()
		end
	end
	_InitPersistentVars()
end, {Priority=0})