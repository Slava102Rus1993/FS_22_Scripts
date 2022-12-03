ExtendedCombine = {
	MOD_NAME = g_currentModName,
	prerequisitesPresent = function (specializations)
		return SpecializationUtil.hasSpecialization(Combine, specializations) and SpecializationUtil.hasSpecialization(PrecisionFarmingStatistic, specializations)
	end,
	registerFunctions = function (vehicleType)
	end,
	registerOverwrittenFunctions = function (vehicleType)
	end,
	registerEventListeners = function (vehicleType)
		SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", ExtendedCombine)
		SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", ExtendedCombine)
	end
}

function ExtendedCombine:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	if self.isClient and self:getIsActiveForInput(true, true) then
		ExtendedCombine.updateMinimapActiveState(self)
	end
end

function ExtendedCombine:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	if self.isClient then
		if isActiveForInputIgnoreSelection then
			ExtendedCombine.updateMinimapActiveState(self)
		else
			ExtendedCombine.updateMinimapActiveState(self, false)
		end
	end
end

function ExtendedCombine:updateMinimapActiveState(forcedState)
	local yieldMap = self:getPFYieldMap()

	if yieldMap ~= nil then
		local isActive = forcedState

		if isActive == nil then
			local _, _, _, isOnField, mission = self:getPFStatisticInfo()
			isActive = isOnField and self.spec_combine.numAttachedCutters > 0 and mission == nil
		end

		yieldMap:setRequireMinimapDisplay(isActive, self, self:getIsSelected())
	end
end
