ExtendedWearable = {
	MOD_NAME = g_currentModName,
	prerequisitesPresent = function (specializations)
		return SpecializationUtil.hasSpecialization(Wearable, specializations) and SpecializationUtil.hasSpecialization(PrecisionFarmingStatistic, specializations)
	end,
	registerFunctions = function (vehicleType)
	end,
	registerOverwrittenFunctions = function (vehicleType)
	end,
	registerEventListeners = function (vehicleType)
		SpecializationUtil.registerEventListener(vehicleType, "onLoad", ExtendedWearable)
		SpecializationUtil.registerEventListener(vehicleType, "onPostUpdateTick", ExtendedWearable)
	end
}

function ExtendedWearable:onLoad(savegame)
	local specName = ExtendedWearable.MOD_NAME .. ".extendedWearable"
	self.spec_extendedWearable = self["spec_" .. specName]
	local spec = self.spec_extendedWearable
	spec.lastDamage = -1
end

function ExtendedWearable:onPostUpdateTick(dt, isActive, isActiveForInput, isSelected)
	local spec = self.spec_extendedWearable
	local damage = self.spec_wearable.damage

	if spec.lastDamage > 0 then
		local price = self:getPrice()
		local lastRepairPrice = Wearable.calculateRepairPrice(price, spec.lastDamage)
		local repairPrice = Wearable.calculateRepairPrice(price, damage)
		local repairCosts = repairPrice - lastRepairPrice

		if repairCosts > 0 then
			local farmlandStatistics, isOnField, farmlandId = self:getPFStatisticInfo()

			if isOnField and farmlandStatistics ~= nil and farmlandId ~= nil then
				farmlandStatistics:updateStatistic(farmlandId, "vehicleCosts", repairCosts)
			end
		end
	end

	spec.lastDamage = damage
end
