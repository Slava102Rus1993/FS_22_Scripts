UmbilicalSprayer = {
	MOD_DIRECTORY = g_currentModDirectory,
	MOD_NAME = g_currentModName,
	WARNING_NO_HOSE_CONNECTED = "warning_noHoseConnectedToSprayer",
	WARNING_NO_PUMP_CONNECTED = "warning_noPumpConnectedToHose",
	WARNING_NO_PUMP_RUNNING = "warning_pumpIsNotRunningNAME",
	WARNING_USING_BUFFER_TANK = "warning_usingBufferingTank"
}

VehicleHUDExtension.registerHUDExtension(UmbilicalSprayer, UmbilicalPumpHUD)

function UmbilicalSprayer.prerequisitesPresent(specializations)
	return SpecializationUtil.hasSpecialization(Sprayer, specializations)
end

function UmbilicalSprayer.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "getUmbilicalHoseAttachedObject", UmbilicalSprayer.getUmbilicalHoseAttachedObject)
	SpecializationUtil.registerFunction(vehicleType, "detachUmbilicalHoseSource", UmbilicalSprayer.detachUmbilicalHoseSource)
	SpecializationUtil.registerFunction(vehicleType, "attachUmbilicalHoseSource", UmbilicalSprayer.attachUmbilicalHoseSource)
end

function UmbilicalSprayer.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", UmbilicalSprayer)
	SpecializationUtil.registerEventListener(vehicleType, "onTurnedOn", UmbilicalSprayer)
	SpecializationUtil.registerEventListener(vehicleType, "onDeactivate", UmbilicalSprayer)
	SpecializationUtil.registerEventListener(vehicleType, "onRootVehicleChanged", UmbilicalSprayer)
	SpecializationUtil.registerEventListener(vehicleType, "onStartWorkAreaProcessing", UmbilicalSprayer)
end

function UmbilicalSprayer.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "processSprayerArea", UmbilicalSprayer.processSprayerArea)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsSprayerExternallyFilled", UmbilicalSprayer.getIsSprayerExternallyFilled)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanAIImplementContinueWork", UmbilicalSprayer.getCanAIImplementContinueWork)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanToggleTurnedOn", UmbilicalSprayer.getCanToggleTurnedOn)
end

function UmbilicalSprayer:onLoad(savegame)
	self.spec_umbilicalSprayer = self[("spec_%s.umbilicalSprayer"):format(UmbilicalSprayer.MOD_NAME)]
	local spec = self.spec_umbilicalSprayer
	spec.connectorObject = nil
	spec.pumpObject = nil

	if self.spec_sprayer ~= nil then
		self.spec_sprayer.needsToBeFilledToTurnOn = false
	end
end

function UmbilicalSprayer:onTurnedOn()
	local spec = self.spec_umbilicalSprayer
	local useBuffer = false

	if self.isBufferObjectSprayVehicle ~= nil then
		useBuffer = self:isBufferObjectSprayVehicle()
	end

	local warningKey, warningParam = nil

	if spec.connectorObject == nil then
		local connectorObject = self:getUmbilicalHoseAttachedObject()

		if connectorObject ~= nil then
			if connectorObject:hasUmbilicalHose() then
				local umbilicalHose = connectorObject:getUmbilicalHose()

				self:attachUmbilicalHoseSource(connectorObject, umbilicalHose)
			else
				warningKey = UmbilicalSprayer.WARNING_NO_HOSE_CONNECTED
			end
		end
	end

	if spec.connectorObject ~= nil then
		if spec.pumpObject ~= nil then
			spec.pumpObject:tryAutomaticPumpTurnOn()

			if not spec.pumpObject:isPumpActive() then
				warningKey = UmbilicalSprayer.WARNING_NO_PUMP_RUNNING
				warningParam = spec.pumpObject:getFullName()
			end
		else
			warningKey = UmbilicalSprayer.WARNING_NO_PUMP_CONNECTED
		end

		if self.isClient and warningKey ~= nil then
			local warning = g_i18n:getText(warningKey)

			if warningParam ~= nil then
				warning = warning:format(warningParam)
			end

			if useBuffer then
				warning = ("%s\n%s"):format(warning, g_i18n:getText(UmbilicalSprayer.WARNING_USING_BUFFER_TANK))
			end

			local isActiveForInput = spec.connectorObject:getIsActiveForInput(false, true) or self:getIsActiveForInput(false, true)

			if isActiveForInput then
				g_currentMission:showBlinkingWarning(warning, 2000)
			end
		end
	end
end

function UmbilicalSprayer:onDeactivate()
	self:detachUmbilicalHoseSource()
end

function UmbilicalSprayer:attachUmbilicalHoseSource(connectorObject, umbilicalHose)
	local pumpObject = umbilicalHose:searchObject(connectorObject, function (object)
		return not object:isa(UmbilicalHoseWrench) and SpecializationUtil.hasSpecialization(UmbilicalPump, object.specializations)
	end)
	local spec = self.spec_umbilicalSprayer
	spec.connectorObject = connectorObject
	spec.pumpObject = pumpObject
end

function UmbilicalSprayer:detachUmbilicalHoseSource(connectorObject, umbilicalHose)
	local spec = self.spec_umbilicalSprayer
	spec.connectorObject = nil
	spec.pumpObject = nil
end

function UmbilicalSprayer:onRootVehicleChanged(rootVehicle)
	local spec = self.spec_umbilicalSprayer
	local actionController = rootVehicle.actionController

	if actionController ~= nil then
		if spec.controlledAction ~= nil then
			spec.controlledAction:updateParent(actionController)

			return
		end

		spec.controlledAction = actionController:registerAction("lowerToolCarrier", InputAction.PM_TOGGLE_TOOLCARRIER_STATE, 3)

		spec.controlledAction:setCallback(self, UmbilicalSprayer.actionControllerHeadlandEvent)
		spec.controlledAction:setFinishedFunctions(self, UmbilicalSprayer.actionControllerHeadlandEvent, ToolCarrier.MODE_STOP)
		spec.controlledAction:setResetOnDeactivation(false)
		spec.controlledAction:addAIEventListener(self, "onAIImplementStartLine", ToolCarrier.MODE_START)
		spec.controlledAction:addAIEventListener(self, "onAIImplementEndLine", ToolCarrier.MODE_STOP)
		spec.controlledAction:addAIEventListener(self, "onAIImplementPrepare", -1)
	elseif spec.controlledAction ~= nil then
		spec.controlledAction:remove()
	end
end

function UmbilicalSprayer:onStartWorkAreaProcessing(dt)
	if self.spec_extendedSprayer == nil then
		return
	end

	local workAreaParameters = self.spec_sprayer.workAreaParameters

	if workAreaParameters.isUnderPerforming then
		workAreaParameters.lastSprayFillLevel = workAreaParameters.sprayFillLevel
		workAreaParameters.sprayFillLevel = -1
		workAreaParameters.isUnderPerforming = nil
	end
end

function UmbilicalSprayer:actionControllerHeadlandEvent(state)
	local connectorObject = self:getUmbilicalHoseAttachedObject()

	if connectorObject ~= nil and connectorObject.canSwitchHeadlandState ~= nil and connectorObject:canSwitchHeadlandState() then
		connectorObject:setHeadlandState(state)

		return true
	end

	return false
end

function UmbilicalSprayer:getUmbilicalHoseAttachedObject()
	local attacherVehicle = self:getAttacherVehicle()

	if attacherVehicle ~= nil and SpecializationUtil.hasSpecialization(ManureBarrel, attacherVehicle.specializations) then
		return nil
	end

	local function isValidUmbilicalHoseConnector(object)
		return SpecializationUtil.hasSpecialization(UmbilicalHoseConnector, object.specializations) and not SpecializationUtil.hasSpecialization(UmbilicalReel, object.specializations) and not SpecializationUtil.hasSpecialization(ManureBarrel, object.specializations)
	end

	local rootVehicle = self:getRootVehicle()

	if isValidUmbilicalHoseConnector(rootVehicle) then
		return rootVehicle
	end

	local vehicles = rootVehicle:getChildVehicles()

	for _, vehicle in pairs(vehicles) do
		if isValidUmbilicalHoseConnector(vehicle) then
			return vehicle
		end
	end

	return nil
end

function UmbilicalSprayer:getIsSprayerExternallyFilled()
	return false
end

function UmbilicalSprayer:getCanAIImplementContinueWork(superFunc)
	local canContinue, stopAI, stopReason = superFunc(self)

	if not canContinue then
		return false, stopAI, stopReason
	end

	local connectorObject = self:getUmbilicalHoseAttachedObject()

	if connectorObject ~= nil and not connectorObject:hasUmbilicalHose() then
		return false, true, AIMessageErrorOutOfFill.new()
	end

	return canContinue, stopAI, stopReason
end

function UmbilicalSprayer:processSprayerArea(superFunc, workArea, dt)
	local workAreaParameters = self.spec_sprayer.workAreaParameters
	local usageScale = self.spec_sprayer.usageScale
	local spec = self.spec_umbilicalSprayer
	local usage = workAreaParameters.usage

	if spec.connectorObject == nil then
		return superFunc(self, workArea, dt)
	end

	if self.spec_extendedSprayer ~= nil and workAreaParameters.isUnderPerforming == nil and workAreaParameters.sprayFillLevel == -1 and workAreaParameters.lastSprayFillLevel ~= nil then
		workAreaParameters.sprayFillLevel = workAreaParameters.lastSprayFillLevel
		workAreaParameters.lastSprayFillLevel = nil
	end

	local fillLevel = workAreaParameters.sprayFillLevel

	if self.getBufferObject ~= nil then
		local bufferObject, bufferFillUnitIndex = self:getBufferObject()

		if bufferObject ~= nil and bufferFillUnitIndex ~= nil then
			fillLevel = fillLevel + bufferObject:getFillUnitFillLevel(bufferFillUnitIndex)
		end
	end

	if usage >= fillLevel or usage <= 0 and fillLevel < 1 then
		workAreaParameters.isUnderPerforming = true
	end

	if workAreaParameters.isUnderPerforming then
		local usageRequirement = usage * usageScale.workingWidth

		if fillLevel > usageRequirement then
			workAreaParameters.isUnderPerforming = false
		end
	end

	if workAreaParameters.isUnderPerforming then
		if self:getIsAIActive() and self.isServer then
			local rootVehicle = self.rootVehicle

			rootVehicle:stopCurrentAIJob(AIMessageErrorOutOfFill.new())

			return 0, 0
		end

		return 0, 0
	end

	return superFunc(self, workArea, dt)
end

function UmbilicalSprayer:getCanToggleTurnedOn(superFunc)
	return false
end
