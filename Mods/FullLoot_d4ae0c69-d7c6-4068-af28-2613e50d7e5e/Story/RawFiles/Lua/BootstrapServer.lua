Ext.Require("Shared.lua")

local PRESETS = {
Battlemage = { SkillSet = "Class_Battlemage", Skills = {}, Skills_Act2 = {}, Equipment = {}, Equipment_Act2 = {}},
Cleric = { SkillSet = "Class_Cleric", Skills = {}, Skills_Act2 = {}, Equipment = {}, Equipment_Act2 = {}},
Conjurer = { SkillSet = "Class_Conjurer", Skills = {}, Skills_Act2 = {}, Equipment = {}, Equipment_Act2 = {}},
Enchanter = { SkillSet = "Class_Enchanter", Skills = {}, Skills_Act2 = {}, Equipment = {}, Equipment_Act2 = {}},
Fighter = { SkillSet = "Class_Fighter", Skills = {}, Skills_Act2 = {}, Equipment = {}, Equipment_Act2 = {}},
Inquisitor = { SkillSet = "Class_Inquisitor", Skills = {}, Skills_Act2 = {}, Equipment = {}, Equipment_Act2 = {}},
Knight = { SkillSet = "Class_Knight", Skills = {}, Skills_Act2 = {}, Equipment = {}, Equipment_Act2 = {}},
Metamorph = { SkillSet = "Class_Metamorph", Skills = {}, Skills_Act2 = {}, Equipment = {}, Equipment_Act2 = {}},
Ranger = { SkillSet = "Class_Ranger", Skills = {}, Skills_Act2 = {}, Equipment = {}, Equipment_Act2 = {}},
Rogue = { SkillSet = "Class_Rogue", Skills = {}, Skills_Act2 = {}, Equipment = {}, Equipment_Act2 = {}},
Shadowblade = { SkillSet = "Class_Shadowblade", Skills = {}, Skills_Act2 = {}, Equipment = {}, Equipment_Act2 = {}},
Wayfarer = { SkillSet = "Class_Wayfarer", Skills = {}, Skills_Act2 = {}, Equipment = {}, Equipment_Act2 = {}},
Witch = { SkillSet = "Class_Witch", Skills = {}, Skills_Act2 = {}, Equipment = {}, Equipment_Act2 = {}},
Wizard = { SkillSet = "Class_Wizard", Skills = {}, Skills_Act2 = {}, Equipment = {}, Equipment_Act2 = {}},
}

function LLFULOOT_Ext_SetupGuard(char, preset)
	local preset_data = PRESETS[preset]
	if preset_data ~= nil then
		local act2 = true
		local db_current_level = Osi.DB_CurrentLevel:Get(nil)
		if db_current_level ~= nil and db_current_level[1] ~= nil then
			local current_level = db_current_level[1]
			if current_level == "TUT_Tutorial_A" or current_level == "FJ_FortJoy_Main" then
				act2 = false
			end
		end

		local skills = preset_data.Skills
		local equipment_name = preset_data.SkillSet .. "_Start"
		if act2 then
			skills = preset_data.Skills_Act2
			equipment_name = preset_data.SkillSet .. "_Act2"
		end
		for k,skill in pairs(skills) do
			CharacterAddSkill(char, skill, 0)
			Ext.Print("[FullLoot:Bootstrap.lua] Adding preset (".. preset ..") skill (".. skill ..") to guard (".. char ..").")
		end
		Ext.Print("[FullLoot:Bootstrap.lua] Applying equipment (".. equipment_name ..") to guard (".. char ..").")
		CharacterTransformAppearanceToWithEquipmentSet(char, char, equipment_name, 0)
	end
end

local function SessionLoading()
	--Ext.Print("[FullLoot:Bootstrap.lua] Gathering preset skills / equipment.")
	--Ext.Print("===================================================================")
	for preset,data in pairs(PRESETS) do
		local skillset_name = data.SkillSet
		local skillset_data = Ext.GetSkillSet(skillset_name)
		if skillset_data ~= nil then
			for _,skill in pairs(skillset_data.Skills) do
				data.Skills[#data.Skills+1] = skill
				--Ext.Print("[FullLoot:Bootstrap.lua] Added skill (".. skill ..") to preset (".. preset ..").")
			end
		end
		local skillset_data_act2 = Ext.GetSkillSet(skillset_name .. "_Act2")
		if skillset_data_act2 ~= nil then
			for _,skill in pairs(skillset_data_act2.Skills) do
				data.Skills_Act2[#data.Skills_Act2+1] = skill
				--Ext.Print("[FullLoot:Bootstrap.lua] Added skill (".. skill ..") to preset (".. preset ..") (Act2).")
			end
		end

		local equipment_data = Ext.GetEquipmentSet(skillset_name .. "_Start")
		if equipment_data ~= nil then
			for _,v in pairs(equipment_data.Groups) do
				data.Equipment[#data.Equipment+1] = v.Equipment[1]
				--Ext.Print("[FullLoot:Bootstrap.lua] Added equipment stat (".. v.Equipment[1] ..") to preset (".. preset ..").")
			end
		end

		equipment_data = Ext.GetEquipmentSet(skillset_name .. "_Act2")
		if equipment_data ~= nil then
			for _,v in pairs(equipment_data.Groups) do
				data.Equipment_Act2[#data.Equipment_Act2+1] = v.Equipment[1]
				--Ext.Print("[FullLoot:Bootstrap.lua] Added equipment stat (".. v.Equipment[1] ..") to preset (".. preset ..") (Act2).")
			end
		end
	end
end

Ext.RegisterListener("SessionLoading", SessionLoading)