local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

local function postSaveToXMLFile(self)
	if self.isValid and g_currentMission ~= nil then
		g_currentMission.destructibleMapObjectSystem:saveToXMLFile(self.savegameDirectory .. "/destructibleMapObjectSystem.xml")
		g_currentMission.treeMarkerSystem:saveToXMLFile(self.savegameDirectory .. "/treeMarkerSystem.xml")
	end
end

FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile, postSaveToXMLFile)
