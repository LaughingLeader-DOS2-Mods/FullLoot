---@type ModSettings
local settings = nil
Ext.RegisterListener("SessionLoaded", function()
	if Mods.LeaderLib ~= nil then
		---@type ModSettings
		settings = Mods.LeaderLib.CreateModSettings("d4ae0c69-d7c6-4068-af28-2613e50d7e5e")
		settings.Global:AddLocalizedFlags({
			"LLFULOOT_InitialSetupComplete",
			"LLFULOOT_EquippedArmorLootable",
			"LLFULOOT_EquippedWeaponsLootable",
			"LLFULOOT_AdjustGoldAmounts",
			"LLFULOOT_GoldReduction_Fourth",
			"LLFULOOT_GoldReduction_Half",
			"LLFULOOT_TraderDifficulty_StrongerTraders",
			"LLFULOOT_TraderDifficulty_SpawnGuards",
		})
		settings.Global.Flags.LLFULOOT_InitialSetupComplete.DebugOnly = true
		settings.Global.Flags.LLFULOOT_EquippedArmorLootable.DebugOnly = true
		settings.Global.Flags.LLFULOOT_EquippedWeaponsLootable.DebugOnly = true

		settings.GetMenuOrder = function()
			return {{
				Entries = {
					"LLFULOOT_AdjustGoldAmounts",
					"LLFULOOT_GoldReduction_Fourth",
					"LLFULOOT_GoldReduction_Half",
					"LLFULOOT_TraderDifficulty_StrongerTraders",
					"LLFULOOT_TraderDifficulty_SpawnGuards",
					"LLFULOOT_EquippedArmorLootable",
					"LLFULOOT_EquippedWeaponsLootable",
					"LLFULOOT_InitialSetupComplete",
				}
			}}
		end
	end
end)