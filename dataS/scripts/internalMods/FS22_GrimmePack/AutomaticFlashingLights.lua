AutomaticFlashingLights = {
	prerequisitesPresent = function (specializations)
		return SpecializationUtil.hasSpecialization(Dischargeable, specializations) and SpecializationUtil.hasSpecialization(Lights, specializations)
	end,
	registerEventListeners = function (vehicleType)
		SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", AutomaticFlashingLights)
		SpecializationUtil.registerEventListener(vehicleType, "onFillUnitFillLevelChanged", AutomaticFlashingLights)
	end,
	onUpdateTick = function (self, dt)
		if self:getTurnLightState() == Lights.TURNLIGHT_HAZARD then
			local spec = self.spec_dischargeable
			spec.lastTimeDischarged = spec.lastTimeDischarged or 0

			if g_time - spec.lastTimeDischarged > 1000 then
				self:setTurnLightState(Lights.TURNLIGHT_OFF, true, true)
			end
		end
	end,
	onFillUnitFillLevelChanged = function (self, fillUnitIndex, fillLevelDelta, fillTypeIndex, toolType, fillPositionData, appliedDelta)
		if fillLevelDelta < 0 then
			if self:getTurnLightState() ~= Lights.TURNLIGHT_HAZARD then
				self:setTurnLightState(Lights.TURNLIGHT_HAZARD, true, true)
			end

			self.spec_dischargeable.lastTimeDischarged = g_time
		end
	end
}
