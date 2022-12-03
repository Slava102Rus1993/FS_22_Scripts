PrecisionFarmingStatistic = {
	MOD_NAME = g_currentModName,
	prerequisitesPresent = function (specializations)
		return true
	end
}

function PrecisionFarmingStatistic.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "getPFStatisticInfo", PrecisionFarmingStatistic.getPFStatisticInfo)
	SpecializationUtil.registerFunction(vehicleType, "getPFYieldMap", PrecisionFarmingStatistic.getPFYieldMap)
end

function PrecisionFarmingStatistic.registerOverwrittenFunctions(vehicleType)
end

function PrecisionFarmingStatistic.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", PrecisionFarmingStatistic)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", PrecisionFarmingStatistic)
end

function PrecisionFarmingStatistic:onLoad(savegame)
	local specName = PrecisionFarmingStatistic.MOD_NAME .. ".precisionFarmingStatistic"
	self.spec_precisionFarmingStatistic = self["spec_" .. specName]
	local spec = self.spec_precisionFarmingStatistic

	if g_precisionFarming ~= nil then
		spec.soilMap = g_precisionFarming.soilMap
		spec.phMap = g_precisionFarming.phMap
		spec.yieldMap = g_precisionFarming.yieldMap
		spec.farmlandStatistics = g_precisionFarming.farmlandStatistics
	end

	spec.isOnField = false
	spec.isOnFieldSmoothed = false
	spec.isOnFieldLastPos = {
		0,
		0
	}
	spec.farmlandId = 0
	spec.mission = nil
	spec.lastUpdateDistance = 0
	spec.updateDistance = 0.5
end

function PrecisionFarmingStatistic:onUpdateTick(dt, isActive, isActiveForInput, isSelected)
	local spec = self.spec_precisionFarmingStatistic
	spec.lastUpdateDistance = spec.lastUpdateDistance + self.lastMovedDistance

	if spec.updateDistance < spec.lastUpdateDistance or spec.farmlandId == 0 then
		spec.lastUpdateDistance = 0
		local x, _, z = getWorldTranslation(self.rootNode)
		spec.farmlandId = g_farmlandManager:getFarmlandIdAtWorldPosition(x, z)
		spec.mission = g_missionManager:getMissionAtWorldPosition(x, z)
		local isOnField = self:getIsOnField()

		if isOnField ~= spec.isOnField then
			if isOnField then
				spec.isOnFieldSmoothed = true
			else
				spec.isOnFieldLastPos[1] = x
				spec.isOnFieldLastPos[2] = z
			end
		end

		if spec.isOnFieldSmoothed ~= isOnField then
			local distance = MathUtil.vector2Length(x - spec.isOnFieldLastPos[1], z - spec.isOnFieldLastPos[2])

			if distance > 20 then
				spec.isOnFieldSmoothed = isOnField
			end
		end

		spec.isOnField = isOnField
	end
end

function PrecisionFarmingStatistic:getPFStatisticInfo()
	local spec = self.spec_precisionFarmingStatistic

	return spec.farmlandStatistics, spec.isOnField, spec.farmlandId, spec.isOnFieldSmoothed, spec.mission
end

function PrecisionFarmingStatistic:getPFYieldMap()
	local spec = self.spec_precisionFarmingStatistic

	return spec.yieldMap
end
