local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

table.insert(FarmStats.STAT_NAMES, "numRollercoasterRides")
table.insert(FarmStats.STAT_NAMES, "forestryMissionCount")

FarmStats.saveToXMLFile = Utils.appendedFunction(FarmStats.saveToXMLFile, function (self, xmlFile, key)
	xmlFile:setInt(key .. ".statistics.numRollercoasterRides", self.statistics.numRollercoasterRides.total)
	xmlFile:setInt(key .. ".statistics.forestryMissionCount", self.statistics.forestryMissionCount.total)
end)
FarmStats.loadFromXMLFile = Utils.appendedFunction(FarmStats.loadFromXMLFile, function (self, xmlFile, rootKey)
	local key = rootKey .. ".statistics"
	self.statistics.numRollercoasterRides.total = xmlFile:getInt(key .. ".numRollercoasterRides", 0)
	self.statistics.forestryMissionCount.total = xmlFile:getInt(key .. ".forestryMissionCount", 0)
end)
FarmStats.getStatisticData = Utils.overwrittenFunction(FarmStats.getStatisticData, function (self, superFunc)
	local res = superFunc(self)

	if not g_currentMission.missionDynamicInfo.isMultiplayer or not g_currentMission.missionDynamicInfo.isClient then
		if PlaceableRollercoaster.INSTANCE ~= nil then
			self:addStatistic("numRollercoasterRides", nil, self:getSessionValue("numRollercoasterRides"), self:getTotalValue("numRollercoasterRides"), "%d")
		end

		if g_missionManager.possibleForestryMissionsWeighted ~= nil and #g_missionManager.possibleForestryMissionsWeighted > 0 then
			self:addStatistic("forestryMissionCount", nil, self:getSessionValue("forestryMissionCount"), self:getTotalValue("forestryMissionCount"), "%d")
		end
	end

	return res
end)
