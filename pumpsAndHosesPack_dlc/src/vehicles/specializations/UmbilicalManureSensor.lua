UmbilicalManureSensor = {
	MOD_NAME = g_currentModName,
	prerequisitesPresent = function (specializations)
		return true
	end,
	registerEventListeners = function (vehicleType)
		SpecializationUtil.registerEventListener(vehicleType, "onLoad", UmbilicalManureSensor)
	end
}

function UmbilicalManureSensor.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "getIsUsingExactNitrogenAmount", UmbilicalManureSensor.getIsUsingExactNitrogenAmount)
	SpecializationUtil.registerFunction(vehicleType, "linkManureSensor", UmbilicalManureSensor.linkManureSensor)
	SpecializationUtil.registerFunction(vehicleType, "getManureSensorNitrogenOffset", UmbilicalManureSensor.getManureSensorNitrogenOffset)
	SpecializationUtil.registerFunction(vehicleType, "getCurrentNitrogenUsageLevelOffset", UmbilicalManureSensor.getCurrentNitrogenUsageLevelOffset)
	SpecializationUtil.registerFunction(vehicleType, "getCurrentNitrogenLevelOffset", UmbilicalManureSensor.getCurrentNitrogenLevelOffset)
end

function UmbilicalManureSensor:onLoad(savegame)
	if g_modIsLoaded.FS22_precisionFarming then
		self.spec_manureSensor = self[("spec_%s.umbilicalManureSensor"):format(UmbilicalManureSensor.MOD_NAME)]
		local spec = self.spec_manureSensor
		spec.currentCurveOffset = math.random()
		spec.sensorRequired = false
		local fillUnits = self:getFillUnits()

		for i = 1, #fillUnits do
			spec.sensorRequired = spec.sensorRequired or self:getFillUnitAllowsFillType(i, FillType.LIQUIDMANURE) or self:getFillUnitAllowsFillType(i, FillType.DIGESTATE)
		end

		spec.sensorAvailable = false
		local configIndex = self.configurations.manureSensor

		if configIndex ~= nil then
			local configKey = string.format("vehicle.manureSensor.manureSensorConfigurations.manureSensorConfiguration(%d)", configIndex - 1)
			local linkNode = self.xmlFile:getValue(configKey .. ".linkNode#node", nil, self.components, self.i3dMappings)

			if linkNode ~= nil then
				local typeName = self.xmlFile:getValue(configKey .. ".linkNode#type", "DEFAULT")
				local linkData = {
					linkNodes = {}
				}
				linkData.linkNodes[1] = {
					linkNode = linkNode,
					typeName = typeName
				}

				self:linkManureSensor(linkData)
			end

			if configIndex > 1 and g_precisionFarming ~= nil then
				local linkData = g_precisionFarming:getManureSensorLinkageData(self.configFileName)

				if linkData ~= nil then
					self:linkManureSensor(linkData)
				end
			end
		end
	end
end

function UmbilicalManureSensor:getIsUsingExactNitrogenAmount()
	if self.spec_manureSensor == nil then
		return false
	end

	return self.spec_manureSensor.sensorAvailable
end

function UmbilicalManureSensor:linkManureSensor(linkData)
	if g_modIsLoaded.FS22_precisionFarming then
		FS22_precisionFarming.ManureSensor.linkManureSensor(self, linkData)
	end
end

function UmbilicalManureSensor:getManureSensorNitrogenOffset(lastChangeLevels)
	if g_modIsLoaded.FS22_precisionFarming then
		return FS22_precisionFarming.ManureSensor.getManureSensorNitrogenOffset(self, lastChangeLevels)
	end

	return 0
end

function UmbilicalManureSensor:getCurrentNitrogenUsageLevelOffset(lastChangeLevels)
	if self.spec_manureSensor ~= nil and self.spec_manureSensor.sensorAvailable then
		return self:getManureSensorNitrogenOffset(lastChangeLevels)
	end

	return 0
end

function UmbilicalManureSensor:getCurrentNitrogenLevelOffset(lastChangeLevels)
	if self.spec_manureSensor ~= nil and not self.spec_manureSensor.sensorAvailable then
		return self:getManureSensorNitrogenOffset(lastChangeLevels)
	end

	return 0
end
