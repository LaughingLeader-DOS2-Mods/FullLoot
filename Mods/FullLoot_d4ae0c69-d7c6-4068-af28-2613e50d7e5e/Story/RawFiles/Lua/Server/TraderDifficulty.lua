_TraderDifficultyData = {
	OriginsRegions = {
		TUT_Tutorial_A = 0,
		FJ_FortJoy_Main = 1,
		LV_HoE_Main = 2,
		RC_Main = 3,
		CoS_Main = 4,
		ARX_Main = 5,
		ARX_Endgame = 6
	},
	---@type table<string, {SkillSet:string, EquipmentStat:string, EquipmentStatAct2:string|nil, Skills:string[], Skills_Act2:string[]}>
	PRESETS = {}
}

---@param charGUID GUID
---@param preset string
function SetupGuard(charGUID, preset)
	local presetData = _TraderDifficultyData.PRESETS[preset]
	if presetData ~= nil then
		local act2 = false
		local currentLevel = Ext.Entity.GetCurrentLevelData()
		if currentLevel then
			local levelValue = _TraderDifficultyData.OriginsRegions[currentLevel.LevelName] or 0
			act2 = levelValue >= 3
		end

		local equipmentStat = presetData.EquipmentStat
		local skills = presetData.Skills
		if act2 then
			skills = presetData.Skills_Act2
			equipmentStat = presetData.EquipmentStatAct2 or presetData.EquipmentStat
		end
		for k,skill in pairs(skills) do
			CharacterAddSkill(charGUID, skill, 0)
			Ext.Utils.Print("[FullLoot:Bootstrap.lua] Adding preset (".. preset ..") skill (".. skill ..") to guard (".. charGUID ..").")
		end
		Ext.Utils.Print("[FullLoot:Bootstrap.lua] Applying equipment (".. equipmentStat ..") to guard (".. charGUID ..").")
		CharacterTransformAppearanceToWithEquipmentSet(charGUID, charGUID, equipmentStat, 0)
	end
end

Ext.Events.SessionLoaded:Subscribe(function (e)
	for _,v in pairs(Ext.Stats.GetCharacterCreation().ClassPresets) do
		local data = {
			SkillSet = v.SkillSet,
			EquipmentStat = "",
			EquipmentStatAct2 = "",
			Skills = {},
			Skills_Act2 = {},
		}
		if v.EquipmentProperties[1] then
			for _,e in pairs(v.EquipmentProperties) do
				if e.StartingEquipmentSet and e.StartingEquipmentSet ~= "" then
					data.EquipmentStat = e.StartingEquipmentSet
					break
				end
			end
		end
		local skillsetData = Ext.Stats.SkillSet.GetLegacy(v.SkillSet)
		if skillsetData then
			for _,skill in pairs(skillsetData.Skills) do
				data.Skills[#data.Skills+1] = skill
			end
		end

		local skillsetDatAct2 = Ext.Stats.SkillSet.GetLegacy(v.SkillSet .. "_Act2")
		if skillsetDatAct2 then
			for _,skill in pairs(skillsetDatAct2.Skills) do
				data.Skills_Act2[#data.Skills_Act2+1] = skill
			end
		end

		local equipmentDataAct2 = Ext.Stats.EquipmentSet.GetLegacy(data.EquipmentStat .. "_Act2")
		if equipmentDataAct2 then
			data.EquipmentStatAct2 = equipmentDataAct2.Name
		end
		_TraderDifficultyData.PRESETS[v.ClassType] = data
	end
end, {Priority=0})