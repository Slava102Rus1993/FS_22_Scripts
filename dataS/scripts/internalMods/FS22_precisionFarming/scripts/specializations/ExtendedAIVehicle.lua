ExtendedAIVehicle = {
	MOD_NAME = g_currentModName,
	prerequisitesPresent = function (specializations)
		return SpecializationUtil.hasSpecialization(AIFieldWorker, specializations) and SpecializationUtil.hasSpecialization(PrecisionFarmingStatistic, specializations)
	end,
	registerFunctions = function (vehicleType)
	end
}

function ExtendedAIVehicle.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "updateAIFieldWorkerLowFrequency", ExtendedAIVehicle.updateAIFieldWorkerLowFrequency)
end

function ExtendedAIVehicle.registerEventListeners(vehicleType)
end

function ExtendedAIVehicle:updateAIFieldWorkerLowFrequency(superFunc, dt)
	if self:getIsAIActive() then
		local difficultyMultiplier = g_currentMission.missionInfo.buyPriceMultiplier
		local price = -dt * difficultyMultiplier * AIJobFieldWork.getPricePerMs(nil)
		local farmlandStatistics, _, farmlandId = self:getPFStatisticInfo()

		if farmlandStatistics ~= nil and farmlandId ~= nil then
			farmlandStatistics:updateStatistic(farmlandId, "helperCosts", -price)
		end
	end

	superFunc(self, dt)
end
