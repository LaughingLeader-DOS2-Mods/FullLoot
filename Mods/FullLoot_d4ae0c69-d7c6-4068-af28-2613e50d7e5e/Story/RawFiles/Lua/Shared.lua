---@return ModSettings|nil
function GetSettings()
	if Mods.LeaderLib ~= nil then
		local settings = Mods.LeaderLib.SettingsManager.GetMod(ModuleUUID, false, true)
		if settings then
			return settings
		end
	end
	return nil
end