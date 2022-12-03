UmbilicalCleaner = {
	MOD_DIRECTORY = g_currentModDirectory,
	MOD_NAME = g_currentModName,
	prerequisitesPresent = function (specializations)
		return SpecializationUtil.hasSpecialization(TurnOnVehicle, specializations)
	end,
	initSpecialization = function ()
		local schema = Vehicle.xmlSchema

		schema:setXMLSpecializationType("UmbilicalCleaner")
		SoundManager.registerSampleXMLPaths(schema, "vehicle.umbilicalCleaner.sounds", "clean")
		Dashboard.registerDashboardXMLPaths(schema, "vehicle.umbilicalCleaner.dashboards", "pressure state")
		schema:register(XMLValueType.VECTOR_N, "vehicle.umbilicalCleaner#configurationIndices", "The configuration indices to use")
		schema:setXMLSpecializationType()

		local schemaSavegame = Vehicle.xmlSchemaSavegame
		local modName = g_manureModName

		schemaSavegame:register(XMLValueType.FLOAT, ("vehicles.vehicle(?).%s.umbilicalCleaner#pressure"):format(modName), "The pressure state of the umbilical cleaner")
	end
}

function UmbilicalCleaner.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "setIsPressurised", UmbilicalCleaner.setIsPressurised)
	SpecializationUtil.registerFunction(vehicleType, "getPressure", UmbilicalCleaner.getPressure)
end

function UmbilicalCleaner.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", UmbilicalCleaner)
	SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", UmbilicalCleaner)
	SpecializationUtil.registerEventListener(vehicleType, "onDelete", UmbilicalCleaner)
	SpecializationUtil.registerEventListener(vehicleType, "onReadStream", UmbilicalCleaner)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", UmbilicalCleaner)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", UmbilicalCleaner)
	SpecializationUtil.registerEventListener(vehicleType, "onDraw", UmbilicalCleaner)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", UmbilicalCleaner)
end

function UmbilicalCleaner.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanBeTurnedOn", UmbilicalCleaner.getCanBeTurnedOn)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanToggleTurnedOn", UmbilicalCleaner.getCanToggleTurnedOn)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getPtoRpm", UmbilicalCleaner.getPtoRpm)
end

function UmbilicalCleaner:onLoad()
	self.spec_umbilicalCleaner = self[("spec_%s.umbilicalCleaner"):format(UmbilicalCleaner.MOD_NAME)]
	local spec = self.spec_umbilicalCleaner
	local baseKey = "vehicle.umbilicalCleaner"

	if self.isClient then
		spec.samples = {
			clean = g_soundManager:loadSampleFromXML(self.xmlFile, baseKey .. ".sounds", "clean", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
		}
	end

	spec.isActive = true
	spec.pressure = 0
	spec.pressurePerSecond = 0.05
	spec.isPressurised = false
	local configurationIndices = table.swap(self.xmlFile:getValue(baseKey .. "#configurationIndices", {}, true))
	local configurationId = self.configurations.umbilicalReel

	if configurationId ~= nil then
		spec.isActive = configurationIndices[configurationId] ~= nil
	end

	if self.loadDashboardsFromXML ~= nil then
		self:loadDashboardsFromXML(self.xmlFile, baseKey .. ".dashboards", {
			valueFunc = "getPressure",
			valueTypeToLoad = "compressorPressure",
			valueObject = self,
			stateFunc = UmbilicalCleaner.dashboardLoadState
		})
	end

	if not spec.isActive then
		SpecializationUtil.removeEventListener(self, "onPostLoad", UmbilicalCleaner)
		SpecializationUtil.removeEventListener(self, "onReadStream", UmbilicalCleaner)
		SpecializationUtil.removeEventListener(self, "onWriteStream", UmbilicalCleaner)
		SpecializationUtil.removeEventListener(self, "onUpdateTick", UmbilicalCleaner)
		SpecializationUtil.removeEventListener(self, "onDraw", UmbilicalCleaner)
		SpecializationUtil.removeEventListener(self, "onRegisterActionEvents", UmbilicalCleaner)
	end
end

function UmbilicalCleaner:onPostLoad(savegame)
	local spec = self.spec_umbilicalCleaner

	if savegame ~= nil and not savegame.resetVehicles then
		local key = ("%s.%s.umbilicalCleaner"):format(savegame.key, self:manure_getModName())
		spec.pressure = savegame.xmlFile:getValue(key .. "#pressure", spec.pressure)
		spec.isPressurised = spec.pressure == 1
	end
end

function UmbilicalCleaner:onDelete()
	local spec = self.spec_umbilicalCleaner

	g_soundManager:deleteSamples(spec.samples)
end

function UmbilicalCleaner:onReadStream(streamId, connection)
	local spec = self.spec_umbilicalCleaner
	spec.isPressurised = streamReadBool(streamId)
	spec.pressure = streamReadFloat32(streamId)
end

function UmbilicalCleaner:onWriteStream(streamId, connection)
	local spec = self.spec_umbilicalCleaner

	streamWriteFloat32(streamId, spec.pressure)
	streamWriteBool(streamId, spec.isPressurised)
end

function UmbilicalCleaner:saveToXMLFile(xmlFile, key, usedModNames)
	local spec = self.spec_umbilicalCleaner

	xmlFile:setValue(key .. "#pressure", spec.pressure)
end

function UmbilicalCleaner:onUpdateTick(dt)
	local spec = self.spec_umbilicalCleaner

	if self:getIsTurnedOn() then
		if spec.pressure ~= 1 then
			spec.pressure = math.min(spec.pressure + spec.pressurePerSecond * dt * 0.001, 1)
		else
			spec.pressure = 1

			if self.isServer and not spec.isPressurised then
				self:setIsPressurised(true)
			end
		end

		self:raiseActive()
	end
end

function UmbilicalCleaner:onDraw(isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	if isActiveForInput and self.isClient then
		local umbilicalHose = UmbilicalCleaner.searchUmbilicalHoseAtVehicle(self:getRootVehicle())

		if umbilicalHose ~= nil then
			g_currentMission:addExtraPrintText(g_i18n:getText("info_hoseDamageState"):format(umbilicalHose:getDamageAmount() * 100))
		end
	end
end

function UmbilicalCleaner:setIsPressurised(isPressurised, umbilicalHose, noEventSend)
	local spec = self.spec_umbilicalCleaner

	if spec.isPressurised ~= isPressurised then
		UmbilicalCleanerEvent.sendEvent(self, isPressurised, umbilicalHose, noEventSend)

		spec.isPressurised = isPressurised

		if isPressurised then
			spec.pressure = 1

			self:setIsTurnedOn(false, true)
		else
			spec.pressure = 0
			local umbilicalHoses = umbilicalHose:collectAttachedUmbilicalHoses(umbilicalHose)

			for _, hose in ipairs(umbilicalHoses) do
				hose:setDamageAmount(0, true)
			end
		end

		if spec.actionEvents ~= nil then
			local toggleEvent = spec.actionEvents[InputAction.PM_TOGGLE_CLEAN]

			if toggleEvent ~= nil then
				g_inputBinding:setActionEventTextVisibility(toggleEvent.actionEventId, isPressurised)
			end
		end

		if self.isClient then
			g_soundManager:playSample(spec.samples.clean)
		end
	end
end

function UmbilicalCleaner.searchUmbilicalHoseAtVehicle(root)
	for _, vehicle in pairs(root:getChildVehicles()) do
		if vehicle ~= nil and vehicle.spec_umbilicalHoseConnector ~= nil then
			for connectorId, _ in ipairs(vehicle.spec_umbilicalHoseConnector.connectors) do
				local umbilicalHose = vehicle:getUmbilicalHose(connectorId)

				if umbilicalHose ~= nil then
					return umbilicalHose
				end
			end
		end
	end

	return nil
end

function UmbilicalCleaner:getPressure()
	return self.spec_umbilicalCleaner.pressure
end

function UmbilicalCleaner:dashboardLoadState(dashboard, newValue, minValue, maxValue, isActive)
	Dashboard.defaultDashboardStateFunc(self, dashboard, newValue, minValue, maxValue, isActive)
end

function UmbilicalCleaner:getCanBeTurnedOn(superFunc)
	local spec = self.spec_umbilicalCleaner

	if not spec.isActive or spec.isPressurised then
		return false
	end

	return superFunc(self)
end

function UmbilicalCleaner:getCanToggleTurnedOn(superFunc)
	local spec = self.spec_umbilicalCleaner

	if not spec.isActive or spec.isPressurised then
		return false
	end

	return superFunc(self)
end

function UmbilicalCleaner:getPtoRpm(superFunc)
	local rpm = superFunc(self)

	if self:getIsTurnedOn() then
		return self.spec_powerConsumer.ptoRpm * 0.4
	end

	return rpm
end

function UmbilicalCleaner:actionEventClean(...)
	if self.isClient then
		local spec = self.spec_umbilicalCleaner
		local root = self:getRootVehicle()
		local umbilicalHose = UmbilicalCleaner.searchUmbilicalHoseAtVehicle(root)

		if umbilicalHose == nil then
			g_currentMission:showBlinkingWarning(g_i18n:getText("warning_noPumpConnectedToHose"))

			return
		end

		if spec.isPressurised then
			self:setIsPressurised(false, umbilicalHose)
		else
			g_currentMission:showBlinkingWarning(g_i18n:getText("warning_notEnoughPressure"))
		end
	end
end

function UmbilicalCleaner:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	if self.isClient then
		local spec = self.spec_umbilicalCleaner

		self:clearActionEventsTable(spec.actionEvents)

		if isActiveForInput then
			local _, actionEventUnloadId = self:addActionEvent(spec.actionEvents, InputAction.PM_TOGGLE_CLEAN, self, UmbilicalCleaner.actionEventClean, false, true, false, true, nil)

			g_inputBinding:setActionEventTextPriority(actionEventUnloadId, GS_PRIO_NORMAL)
			g_inputBinding:setActionEventTextVisibility(actionEventUnloadId, spec.isPressurised)
		end
	end
end
