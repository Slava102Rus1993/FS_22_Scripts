ExtendedMotorized = {
	MOD_NAME = g_currentModName,
	prerequisitesPresent = function (specializations)
		return SpecializationUtil.hasSpecialization(Motorized, specializations) and SpecializationUtil.hasSpecialization(PrecisionFarmingStatistic, specializations)
	end,
	registerFunctions = function (vehicleType)
	end
}

function ExtendedMotorized.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "updateConsumers", ExtendedMotorized.updateConsumers)
end

function ExtendedMotorized.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", ExtendedMotorized)
end

function ExtendedMotorized:onLoad(savegame)
	local specName = ExtendedMotorized.MOD_NAME .. ".extendedMotorized"
	self.spec_extendedMotorized = self["spec_" .. specName]
	local spec = self.spec_extendedMotorized

	if g_precisionFarming ~= nil then
		spec.farmlandStatistics = g_precisionFarming.farmlandStatistics
	end
end

function ExtendedMotorized:updateConsumers(superFunc, dt, accInput)
	superFunc(self, dt, accInput)

	local farmlandStatistics, isOnField, farmlandId = self:getPFStatisticInfo()

	if farmlandStatistics ~= nil and farmlandId ~= nil and isOnField then
		local spec = self.spec_motorized

		for _, consumer in pairs(spec.consumers) do
			if consumer.permanentConsumption and consumer.usage > 0 then
				local fillUnit = self:getFillUnitByIndex(consumer.fillUnitIndex)

				if fillUnit ~= nil and fillUnit.lastValidFillType == FillType.DIESEL then
					farmlandStatistics:updateStatistic(farmlandId, "usedFuel", spec.lastFuelUsage / 60 / 60 / 1000 * dt)
				end
			end
		end
	end
end
