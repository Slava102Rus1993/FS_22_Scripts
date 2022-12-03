local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

if g_gui ~= nil then
	g_gui:loadProfiles(g_currentModDirectory .. "gui/guiProfiles.xml")

	for _, profile in pairs(g_gui.profiles) do
		for name, value in pairs(profile.values) do
			if (name == "imageFilename" or name == "iconFilename") and value == g_currentModName .. "UIElements" then
				profile.values[name] = g_currentModDirectory .. "menu/hud/ui_elements.png"
				profile.values.imageSize = "1024 1024"
			end
		end
	end
end
