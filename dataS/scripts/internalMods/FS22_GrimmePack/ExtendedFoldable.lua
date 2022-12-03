ExtendedFoldable = {
	prerequisitesPresent = function (specializations)
		return SpecializationUtil.hasSpecialization(Foldable, specializations)
	end,
	registerEventListeners = function (vehicleType)
		SpecializationUtil.registerEventListener(vehicleType, "onFillUnitFillLevelChanged", ExtendedFoldable)
		SpecializationUtil.registerEventListener(vehicleType, "onFoldStateChanged", ExtendedFoldable)
	end,
	prerequisitesPresent = function (specializations)
		return true
	end,
	onFillUnitFillLevelChanged = function (self, fillUnitIndex, fillLevelDelta, fillTypeIndex, toolType, fillPositionData, appliedDelta)
		local currentDischargeNode = self:getCurrentDischargeNode()

		if currentDischargeNode ~= nil and currentDischargeNode.fillUnitIndex == fillUnitIndex then
			local fillLevelPct = self:getFillUnitFillLevelPercentage(fillUnitIndex)

			if fillLevelPct >= 0.2 and self:getFoldAnimTime() > 0 then
				self:setFoldState(-1, true)
			end
		end
	end,
	onFoldStateChanged = function (self, direction, moveToMiddle)
		local spec = self.spec_foldable

		if direction == spec.turnOnFoldDirection and self.spec_cover ~= nil then
			self:setCoverState(1)
		end
	end
}
