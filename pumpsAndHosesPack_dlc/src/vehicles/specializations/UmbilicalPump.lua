UmbilicalPump = {
	MOD_DIRECTORY = g_currentModDirectory,
	MOD_NAME = g_currentModName,
	DAMAGE_LOAD_REDUCTION = 0.3,
	DAMAGE_EFFICIENCY_TIME_INCREASE = 0.45,
	CONDITION_DURATION = 12000000,
	CONGESTION_DURATION = 240000,
	PUMP_MOTOR_TURN_OFF_TIME = 15000,
	GAMEPLAY_PUMP_MULTIPLIER = 2,
	AI_USAGE_OFF = 1,
	AI_USAGE_PURCHASING = 2,
	AI_USAGE_STORAGES = 3,
	WARNING_ATTACH_UMBILICAL_HOSE = 1,
	WARNING_NO_SOURCE_FOUND = 2,
	WARNING_NO_TARGET_FOUND = 3,
	WARNING_SOURCE_VEHICLE_EMPTY = 4,
	WARNING_SOURCE_SILO_EMPTY = 5,
	OVERLAP_SKIP_TICK_NUM = 15,
	OVERLAP_SIZE = 5,
	OVERLAP_HEIGHT = 1,
	OBJECT_REMOVE_DISTANCE = 10
}
UmbilicalPump.WARNINGS = {
	[UmbilicalPump.WARNING_ATTACH_UMBILICAL_HOSE] = "warning_attachUmbilical",
	[UmbilicalPump.WARNING_NO_SOURCE_FOUND] = "warning_noPumpSourceFoundNear",
	[UmbilicalPump.WARNING_NO_TARGET_FOUND] = "warning_noPumpTargetFoundOnHose",
	[UmbilicalPump.WARNING_SOURCE_VEHICLE_EMPTY] = "warning_manureFillUnitEmpty",
	[UmbilicalPump.WARNING_SOURCE_SILO_EMPTY] = "warning_manureSiloEmpty"
}

VehicleHUDExtension.registerHUDExtension(UmbilicalPump, UmbilicalPumpHUD)

function UmbilicalPump.prerequisitesPresent(specializations)
	return SpecializationUtil.hasSpecialization(UmbilicalHoseConnector, specializations) and SpecializationUtil.hasSpecialization(Wearable, specializations)
end

function UmbilicalPump.initSpecialization()
	local schema = Vehicle.xmlSchema

	schema:setXMLSpecializationType("UmbilicalPump")
	UmbilicalPump.registerReelXMLPaths(schema, "vehicle.umbilicalPump")
	schema:setXMLSpecializationType()
end

function UmbilicalPump.registerReelXMLPaths(schema, baseName)
	SoundManager.registerSampleXMLPaths(schema, baseName .. ".sounds", "pump")
	Dashboard.registerDashboardXMLPaths(schema, baseName .. ".dashboards", "load state")
	schema:register(XMLValueType.FLOAT, baseName .. "#litersPerSecond", "Liters per second", 100)
	schema:register(XMLValueType.FLOAT, baseName .. "#maxDistance", "Max pump distance", 250)
	schema:register(XMLValueType.FLOAT, baseName .. "#reachMaxEfficiencyTime", "Time to reach max efficiency", 1500)
	schema:register(XMLValueType.STRING, baseName .. "#fillTypeCategories", "Fill type categories")
	schema:register(XMLValueType.STRING, baseName .. "#fillTypes", "List of supported fill types")
	schema:register(XMLValueType.NODE_INDEX, baseName .. "#triggerNode", "Vehicle trigger node, required if isStandalone")
	schema:register(XMLValueType.BOOL, baseName .. "#isStandalone", "Is the pump standalone, i.e. not connected to a vehicle")
	schema:register(XMLValueType.BOOL, baseName .. "#isWaterPump", "Is the pump a water pump")
	schema:register(XMLValueType.BOOL, baseName .. "#supportsCirculation", "Does the pump support circulation, to circulate the fluid from the pump to the source")
	schema:register(XMLValueType.INT, baseName .. "#connectorIndex", "The connector index to use for the pump")
end

function UmbilicalPump.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "setIsPumpActive", UmbilicalPump.setIsPumpActive)
	SpecializationUtil.registerFunction(vehicleType, "isPumpActive", UmbilicalPump.isPumpActive)
	SpecializationUtil.registerFunction(vehicleType, "isPumpAllowed", UmbilicalPump.isPumpAllowed)
	SpecializationUtil.registerFunction(vehicleType, "setIsPumpCirculating", UmbilicalPump.setIsPumpCirculating)
	SpecializationUtil.registerFunction(vehicleType, "isPumpCirculating", UmbilicalPump.isPumpCirculating)
	SpecializationUtil.registerFunction(vehicleType, "runPump", UmbilicalPump.runPump)
	SpecializationUtil.registerFunction(vehicleType, "doPump", UmbilicalPump.doPump)
	SpecializationUtil.registerFunction(vehicleType, "calculateCharacteristics", UmbilicalPump.calculateCharacteristics)
	SpecializationUtil.registerFunction(vehicleType, "calculatePumpCondition", UmbilicalPump.calculatePumpCondition)
	SpecializationUtil.registerFunction(vehicleType, "tryAutomaticPumpTurnOn", UmbilicalPump.tryAutomaticPumpTurnOn)
	SpecializationUtil.registerFunction(vehicleType, "tryAutomaticPumpTurnOff", UmbilicalPump.tryAutomaticPumpTurnOff)
	SpecializationUtil.registerFunction(vehicleType, "getValidSupportedFillUnitIndex", UmbilicalPump.getValidSupportedFillUnitIndex)
	SpecializationUtil.registerFunction(vehicleType, "getPumpLoad", UmbilicalPump.getPumpLoad)
	SpecializationUtil.registerFunction(vehicleType, "setPumpToObject", UmbilicalPump.setPumpToObject)
	SpecializationUtil.registerFunction(vehicleType, "setPumpFromObject", UmbilicalPump.setPumpFromObject)
	SpecializationUtil.registerFunction(vehicleType, "getPumpToOrBufferObject", UmbilicalPump.getPumpToOrBufferObject)
	SpecializationUtil.registerFunction(vehicleType, "getPumpFromOrSelfObject", UmbilicalPump.getPumpFromOrSelfObject)
	SpecializationUtil.registerFunction(vehicleType, "getPumpWarning", UmbilicalPump.getPumpWarning)
	SpecializationUtil.registerFunction(vehicleType, "onCollisionCallback", UmbilicalPump.onCollisionCallback)
end

function UmbilicalPump.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", UmbilicalPump)
	SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", UmbilicalPump)
	SpecializationUtil.registerEventListener(vehicleType, "onDelete", UmbilicalPump)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", UmbilicalPump)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", UmbilicalPump)
	SpecializationUtil.registerEventListener(vehicleType, "onReadStream", UmbilicalPump)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", UmbilicalPump)
	SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", UmbilicalPump)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", UmbilicalPump)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", UmbilicalPump)
	SpecializationUtil.registerEventListener(vehicleType, "onAttachUmbilicalHose", UmbilicalPump)
	SpecializationUtil.registerEventListener(vehicleType, "onDetachUmbilicalHose", UmbilicalPump)
end

function UmbilicalPump.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getDoConsumePtoPower", UmbilicalPump.getDoConsumePtoPower)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getConsumingLoad", UmbilicalPump.getConsumingLoad)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsOperating", UmbilicalPump.getIsOperating)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getUseTurnedOnSchema", UmbilicalPump.getUseTurnedOnSchema)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsPowerTakeOffActive", UmbilicalPump.getIsPowerTakeOffActive)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getPtoRpm", UmbilicalPump.getPtoRpm)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "canUpdateUmbilicalHose", UmbilicalPump.canUpdateUmbilicalHose)
end

function UmbilicalPump.registerEvents(vehicleType)
end

function UmbilicalPump:onLoad(savegame)
	self.spec_umbilicalPump = self[("spec_%s.umbilicalPump"):format(UmbilicalPump.MOD_NAME)]
	local spec = self.spec_umbilicalPump
	local baseKey = "vehicle.umbilicalPump"
	local fillTypes = g_fillTypeManager:getFillTypesFromXML(self.xmlFile, baseKey .. "#fillTypeCategories", baseKey .. "#fillTypes", false)
	spec.overlapTick = 0
	spec.supportedFillTypes = table.swap(fillTypes)
	spec.isWaterPump = self.xmlFile:getValue(baseKey .. "#isWaterPump", false)
	spec.isStandalone = self.xmlFile:getValue(baseKey .. "#isStandalone", false)
	spec.supportsCirculation = self.xmlFile:getValue(baseKey .. "#supportsCirculation", true)
	spec.connectorIndex = self.xmlFile:getValue(baseKey .. "#connectorIndex", 1)
	spec.pumpIsActive = false
	spec.pumpIsCirculating = false
	local reachMaxEfficiencyTime = self.xmlFile:getValue(baseKey .. "#reachMaxEfficiencyTime", 1500)
	spec.characteristics = {
		currentTime = 0,
		currentLoadSent = 0,
		currentLoad = 0,
		condition = 1,
		hasThroughput = false,
		conditionSent = 0,
		orgMaxTime = reachMaxEfficiencyTime,
		maxTime = reachMaxEfficiencyTime,
		litersPerSecond = self.xmlFile:getValue(baseKey .. "#litersPerSecond", 100) * UmbilicalPump.GAMEPLAY_PUMP_MULTIPLIER,
		maxDistance = self.xmlFile:getValue(baseKey .. "#maxDistance", 250)
	}
	spec.trigger = {
		numObjects = 0,
		node = self.xmlFile:getValue(baseKey .. "#triggerNode", nil, self.components, self.i3dMappings),
		objects = {}
	}

	if self.isClient then
		spec.samples = {
			pump = g_soundManager:loadSampleFromXML(self.xmlFile, baseKey .. ".sounds", "pump", self.baseDirectory, self.components, 0, AudioGroup.VEHICLE, self.i3dMappings, self)
		}
	end

	if self.loadDashboardsFromXML ~= nil then
		self:loadDashboardsFromXML(self.xmlFile, baseKey .. ".dashboards", {
			valueFunc = "getPumpLoad",
			valueTypeToLoad = "pumpLoad",
			valueObject = self,
			stateFunc = UmbilicalPump.dashboardLoadState
		})
	end

	spec.hasTargetObject = false
	spec.pumpHasLoad = false
	spec.pumpAllowed = false
	spec.targetObject = nil
	spec.targetFillUnitIndex = nil
	spec.dirtyFlag = self:getNextDirtyFlag()
end

function UmbilicalPump:onPostLoad()
	local spec = self.spec_umbilicalPump

	if self.isServer then
		spec.hasFillUnits = SpecializationUtil.hasSpecialization(FillUnit, self.specializations) and #self:getFillUnits() > 0
		spec.waterFillUnitIndex = self:getFirstValidFillUnitToFill(FillType.WATER)
		local manureFillUnitIndex = self:getFirstValidFillUnitToFill(FillType.LIQUIDMANURE)

		if manureFillUnitIndex == nil then
			manureFillUnitIndex = self:getFirstValidFillUnitToFill(FillType.DIGESTATE)
		end

		spec.manureFillUnitIndex = manureFillUnitIndex
	end
end

function UmbilicalPump:onDelete()
	local spec = self.spec_umbilicalPump

	g_soundManager:deleteSamples(spec.samples)
end

function UmbilicalPump:onReadStream(streamId, connection)
	local pumpIsActive = streamReadBool(streamId)

	self:setIsPumpActive(pumpIsActive, true)

	local pumpIsCirculating = streamReadBool(streamId)

	self:setIsPumpCirculating(pumpIsCirculating, true)
end

function UmbilicalPump:onWriteStream(streamId, connection)
	local spec = self.spec_umbilicalPump

	streamWriteBool(streamId, spec.pumpIsActive)
	streamWriteBool(streamId, spec.pumpIsCirculating)
end

function UmbilicalPump:onReadUpdateStream(streamId, timestamp, connection)
	if connection:getIsServer() then
		local isDirty = streamReadBool(streamId)

		if isDirty then
			local spec = self.spec_umbilicalPump
			spec.characteristics.currentLoad = streamReadFloat32(streamId)
			spec.characteristics.condition = streamReadFloat32(streamId)
			spec.pumpHasLoad = streamReadBool(streamId)
			spec.hasTargetObject = streamReadBool(streamId)
			spec.pumpAllowed = streamReadBool(streamId)
		end
	end
end

function UmbilicalPump:onWriteUpdateStream(streamId, connection, dirtyMask)
	if not connection:getIsServer() then
		local spec = self.spec_umbilicalPump

		if streamWriteBool(streamId, bitAND(dirtyMask, spec.dirtyFlag) ~= 0) then
			streamWriteFloat32(streamId, spec.characteristics.currentLoad)
			streamWriteFloat32(streamId, spec.characteristics.condition)
			streamWriteBool(streamId, spec.pumpHasLoad)
			streamWriteBool(streamId, spec.hasTargetObject)
			streamWriteBool(streamId, spec.pumpAllowed)
		end
	end
end

function UmbilicalPump:onUpdate(dt, isActiveForInput)
	if isActiveForInput and self.isClient then
		local spec = self.spec_umbilicalPump
		local showAction = spec.pumpAllowed

		if not spec.pumpIsActive then
			showAction = showAction and spec.hasTargetObject
		else
			showAction = showAction and spec.pumpIsActive
		end

		if spec.actionEvents ~= nil then
			local pumpActionEvent = spec.actionEvents[InputAction.PM_TOGGLE_PUMP_STATE]

			if pumpActionEvent ~= nil then
				local key = spec.pumpIsActive and "action_deactivateManurePump" or "action_activateManurePump"

				g_inputBinding:setActionEventText(pumpActionEvent.actionEventId, g_i18n:getText(key))
				g_inputBinding:setActionEventTextVisibility(pumpActionEvent.actionEventId, showAction)
			end
		end
	end
end

function UmbilicalPump:onUpdateTick(dt)
	local spec = self.spec_umbilicalPump

	if UmbilicalPump.OVERLAP_SKIP_TICK_NUM < spec.overlapTick then
		if spec.trigger.node ~= nil then
			local x, y, z = getWorldTranslation(spec.trigger.node)
			local rx, ry, rz = getWorldRotation(spec.trigger.node)

			overlapBox(x, y, z, rx, ry, rz, UmbilicalPump.OVERLAP_SIZE, UmbilicalPump.OVERLAP_HEIGHT, UmbilicalPump.OVERLAP_SIZE, "onCollisionCallback", self, CollisionFlag.FILLABLE + CollisionFlag.VEHICLE, true, true, true)
		end

		spec.overlapTick = 0
	end

	spec.overlapTick = spec.overlapTick + 1

	UmbilicalPump.validateTriggerObjects(self)

	if not self.isServer then
		return
	end

	self:tryAutomaticPumpTurnOff(dt)

	local isPumpAllowed = self:isPumpAllowed()

	if not isPumpAllowed then
		self:setIsPumpActive(false)
	end

	self:calculateCharacteristics(dt, isPumpAllowed)

	if not self:isPumpActive() then
		return
	end

	self:runPump(dt)
	self:raiseActive()
end

function UmbilicalPump:calculateCharacteristics(dt, isPumpAllowed)
	local spec = self.spec_umbilicalPump
	local hasTargetObject = spec.targetObject ~= nil
	local hasLoad = hasTargetObject and spec.characteristics.hasThroughput
	local resetMotorRun = hasTargetObject and spec.targetObject:getIsAIActive()

	if spec.pumpIsActive and hasLoad then
		if spec.characteristics.currentTime < spec.characteristics.maxTime then
			spec.characteristics.currentTime = math.min(spec.characteristics.currentTime + dt, spec.characteristics.maxTime)
		end

		resetMotorRun = true
	elseif spec.characteristics.currentTime > 0 then
		spec.characteristics.currentTime = math.max(spec.characteristics.currentTime - dt, 0)
	end

	if resetMotorRun then
		local rootVehicle = self:getRootVehicle()

		if rootVehicle.spec_motorized ~= nil then
			rootVehicle.spec_motorized.motorStopTimer = rootVehicle.spec_motorized.motorStopTimerDuration
		end
	end

	if spec.pumpIsActive and not hasTargetObject then
		spec.characteristics.currentLoad = math.random()
	elseif spec.pumpIsActive then
		self:calculatePumpCondition(dt)

		local currentLoad = math.clamp(spec.characteristics.currentTime / spec.characteristics.maxTime, 0, 1)
		local maxTime = spec.characteristics.orgMaxTime
		local damage = self:getVehicleDamage()

		if not spec.isWaterPump then
			local umbilicalHose = self:getUmbilicalHose(spec.connectorIndex)

			if umbilicalHose ~= nil then
				local hoseDamage = umbilicalHose:getDamageAmount()
				local cubicMetersPerSecond = spec.characteristics.litersPerSecond * 0.001
				local maxDistance = spec.characteristics.maxDistance
				local totalLength = umbilicalHose:getTotalLength()
				local f = math.max(1, totalLength / maxDistance)
				local f2 = f * f + hoseDamage / 10
				local conditionPart = 0.9 / (f2 - 0.1)
				spec.characteristics.condition = conditionPart * conditionPart
				maxTime = maxTime + totalLength / cubicMetersPerSecond

				if hasLoad then
					local hoseCongestion = cubicMetersPerSecond / UmbilicalPump.CONGESTION_DURATION

					umbilicalHose:setDamageAmount(umbilicalHose.damage + hoseCongestion * dt)
				end
			end
		end

		spec.characteristics.maxTime = maxTime * (1 + damage * UmbilicalPump.DAMAGE_EFFICIENCY_TIME_INCREASE)
		spec.characteristics.currentLoad = currentLoad * (1 - damage * UmbilicalPump.DAMAGE_LOAD_REDUCTION)
	end

	if hasLoad ~= spec.pumpHasLoad or hasTargetObject ~= spec.hasTargetObject or isPumpAllowed ~= spec.pumpAllowed then
		spec.pumpHasLoad = hasLoad
		spec.hasTargetObject = hasTargetObject
		spec.pumpAllowed = isPumpAllowed
	end

	if spec.characteristics.currentLoad ~= spec.characteristics.currentLoadSent or spec.characteristics.condition ~= spec.characteristics.conditionSent or spec.pumpHasLoad ~= spec.pumpHasLoadSent or spec.pumpAllowed ~= spec.isPumpAllowedSent or spec.hasTargetObject ~= spec.hasTargetObjectSent then
		spec.characteristics.currentLoadSent = spec.characteristics.currentLoad
		spec.characteristics.conditionSent = spec.characteristics.condition
		spec.pumpHasLoadSent = spec.pumpHasLoad
		spec.hasTargetObjectSent = spec.hasTargetObject
		spec.isPumpAllowedSent = spec.pumpAllowed

		self:raiseDirtyFlags(spec.dirtyFlag)
	end

	spec.characteristics.hasThroughput = false
end

function UmbilicalPump:calculatePumpCondition(dt)
	local spec = self.spec_umbilicalPump

	if spec.waterFillUnitIndex ~= nil then
		local delta = spec.characteristics.litersPerSecond * 0.01 * dt * 0.001
		local movedDelta = self:addFillUnitFillLevel(self:getOwnerFarmId(), spec.waterFillUnitIndex, -delta, FillType.WATER, ToolType.UNDEFINED, nil)

		if movedDelta ~= 0 then
			return
		end
	end

	local conditionImpactDuration = 1 / UmbilicalPump.CONDITION_DURATION * math.max(1 - spec.characteristics.currentLoad, 0.001)
	local conditionDamage = conditionImpactDuration * dt

	self:setDamageAmount(self.spec_wearable.damage + conditionDamage)
end

function UmbilicalPump:runPump(dt)
	local spec = self.spec_umbilicalPump
	local to, toFillUnitIndex = self:getPumpToOrBufferObject()

	if to == nil then
		return
	end

	local from, fillUnitIndex = self:getPumpFromOrSelfObject()

	if from == nil then
		return
	end

	local targetHasNoFreeCapacity = to:getFillUnitFreeCapacity(toFillUnitIndex) <= 0
	local toEqualsFrom = to == from

	if spec.supportsCirculation and (spec.pumpIsCirculating ~= targetHasNoFreeCapacity or toEqualsFrom) then
		self:setIsPumpCirculating(targetHasNoFreeCapacity or toEqualsFrom)
	end

	if not spec.supportsCirculation and targetHasNoFreeCapacity then
		self:setIsPumpActive(false)

		return
	end

	if spec.supportsCirculation and spec.pumpIsCirculating then
		return
	end

	local fillType, fromFillUnitIndex = UmbilicalPump.getSourceFillTypeAndFillUnitIndex(self, from, fillUnitIndex)

	if fillType == FillType.UNKNOWN then
		self:setIsPumpActive(false)

		return
	end

	if not to:getFillUnitAllowsFillType(toFillUnitIndex, fillType) then
		self:setIsPumpActive(false)

		return
	end

	local canRunWithoutVolume = spec.isStandalone and fillType == FillType.WATER and not spec.hasFillUnits

	if not canRunWithoutVolume and fromFillUnitIndex == nil then
		self:setIsPumpActive(false)
	end

	if not canRunWithoutVolume then
		local fromFillLevel = 0

		if spec.sourceIsTrigger then
			fromFillLevel = from.source:getFillLevel(fillType, self:getOwnerFarmId())
		else
			fromFillLevel = from:getFillUnitFillLevel(fromFillUnitIndex)
		end

		if fromFillLevel == 0 then
			self:setIsPumpActive(false)

			return
		end
	end

	local lps = spec.characteristics.litersPerSecond * math.max(spec.characteristics.currentLoad * spec.characteristics.condition, 0.01)
	local delta = lps * 0.001 * dt
	local movedDelta = self:doPump(from, to, fromFillUnitIndex, toFillUnitIndex, delta, fillType, canRunWithoutVolume, spec.sourceIsTrigger)
	spec.characteristics.hasThroughput = not spec.pumpIsCirculating and movedDelta ~= 0
end

function UmbilicalPump:doPump(from, to, fromFillUnitIndex, toFillUnitIndex, delta, fillType, canRunWithoutVolume, isTrigger)
	if delta == 0 then
		return 0
	end

	local farmId = from:getOwnerFarmId()
	local movedDelta = to:addFillUnitFillLevel(farmId, toFillUnitIndex, delta, fillType, ToolType.UNDEFINED, nil)

	if movedDelta ~= 0 then
		local priceMultiplier = 1

		if not canRunWithoutVolume then
			local helperSlurrySource = g_currentMission.missionInfo.helperSlurrySource
			local isPumpingHelperSlurry = fillType == FillType.LIQUIDMANURE or fillType == FillType.DIGESTATE

			if helperSlurrySource ~= UmbilicalPump.AI_USAGE_OFF and to:getIsAIActive() and isPumpingHelperSlurry then
				if isTrigger or farmId == AccessHandler.EVERYONE or farmId == AccessHandler.NOBODY then
					farmId = g_currentMission:getFarmId()
				end

				if helperSlurrySource == UmbilicalPump.AI_USAGE_PURCHASING then
					canRunWithoutVolume = true
					priceMultiplier = 1.5
				elseif UmbilicalPump.AI_USAGE_STORAGES <= helperSlurrySource then
					local loadingStation = g_currentMission.liquidManureLoadingStations[helperSlurrySource - 2]

					if loadingStation ~= nil then
						local remainingDelta = loadingStation:removeFillLevel(fillType, movedDelta, farmId or self:getOwnerFarmId())

						if movedDelta - remainingDelta > 1e-06 then
							return movedDelta
						end
					end
				end
			end
		end

		if not canRunWithoutVolume then
			if isTrigger then
				from.source:removeFillLevel(fillType, movedDelta, g_currentMission:getFarmId())
			else
				from:addFillUnitFillLevel(farmId, fromFillUnitIndex, -movedDelta, fillType, ToolType.UNDEFINED, nil)
			end
		else
			local moneyType = fillType == FillType.WATER and MoneyType.PURCHASE_WATER or MoneyType.PURCHASE_FERTILIZER
			local price = movedDelta * g_currentMission.economyManager:getPricePerLiter(fillType) * priceMultiplier

			g_farmManager:updateFarmStats(farmId, "expenses", price)
			g_currentMission:addMoney(-price, farmId, moneyType, true)
		end
	end

	return movedDelta
end

function UmbilicalPump:getSourceFillTypeAndFillUnitIndex(from, fillUnitIndex)
	local spec = self.spec_umbilicalPump

	if fillUnitIndex ~= nil then
		if not spec.sourceIsTrigger then
			local fillType = from:getFillUnitFillType(fillUnitIndex)

			return fillType, fillUnitIndex
		else
			return fillUnitIndex, fillUnitIndex
		end
	end

	if spec.isStandalone and spec.isWaterPump then
		return FillType.WATER, nil
	end

	return FillType.UNKNOWN, nil
end

function UmbilicalPump.getFillUnitBufferVehicle(vehicle)
	if vehicle.getFillUnitBuffer ~= nil then
		local bufferFillUnit = vehicle:getFillUnitBuffer()

		if bufferFillUnit ~= nil and vehicle:getFillUnitFreeCapacity(bufferFillUnit) > 0 then
			return vehicle, bufferFillUnit
		end
	end

	return nil
end

function UmbilicalPump:validateTriggerObjects()
	local spec = self.spec_umbilicalPump

	local function toFarAway(node1, node2)
		local distance = calcDistanceFrom(node1, node2)

		return UmbilicalPump.OBJECT_REMOVE_DISTANCE <= distance
	end

	if spec.trigger.numObjects > 0 then
		local from = spec.sourceObject
		local fromFillUnitIndex = spec.sourceFillUnitIndex

		if from ~= nil and not spec.isWaterPump then
			if from.isDeleted then
				self:setPumpFromObject(nil, )
			end

			if fromFillUnitIndex ~= nil and from.getFillUnitFillLevel ~= nil and from:getFillUnitFillLevel(fromFillUnitIndex) <= 0 then
				self:setPumpFromObject(nil, )
			else
				local index = self:getValidSupportedFillUnitIndex(from)

				if index == nil then
					self:setPumpFromObject(nil, )
				end
			end
		end

		for object, info in pairs(spec.trigger.objects) do
			if object.isDeleted or toFarAway(self.rootNode, info.nodeId) then
				spec.trigger.objects[object] = nil
				spec.trigger.numObjects = spec.trigger.numObjects - 1

				if object == spec.sourceObject then
					self:setPumpFromObject(nil, )
				end
			elseif info.count > 0 and not object.isDeleted then
				if spec.isStandalone and spec.isWaterPump then
					if spec.targetObject == nil then
						self:setPumpToObject(object, info.fillUnitIndex)
						self:setPumpFromObject(self, nil, info.isTrigger)
					end
				elseif spec.sourceObject == nil then
					if not info.isTrigger and object:getFillUnitFillLevel(info.fillUnitIndex) > 0 then
						self:setPumpFromObject(object, info.fillUnitIndex, info.isTrigger)
					end

					if info.isTrigger then
						local fillLevel = object.source:getFillLevel(info.fillUnitIndex, self:getOwnerFarmId())

						if fillLevel > 0 then
							self:setPumpFromObject(object, info.fillUnitIndex, info.isTrigger)
						end
					end
				end
			end
		end
	end
end

function UmbilicalPump:getPumpFromOrSelfObject()
	local spec = self.spec_umbilicalPump
	local object = spec.sourceObject
	local fillUnitIndex = spec.sourceFillUnitIndex

	if object == nil and not spec.isStandalone and spec.hasFillUnits then
		local targetObject, _ = self:getPumpToOrBufferObject()

		if targetObject ~= self then
			local bufferVehicle, bufferFillUnit = UmbilicalPump.getFillUnitBufferVehicle(self)

			if bufferVehicle ~= nil then
				return bufferVehicle, bufferFillUnit
			end

			fillUnitIndex = self:getValidSupportedFillUnitIndex(self)

			if fillUnitIndex ~= nil and self:getFillUnitFillLevel(fillUnitIndex) > 0 then
				return self, fillUnitIndex
			end
		end

		return self, spec.manureFillUnitIndex
	end

	return object, fillUnitIndex
end

function UmbilicalPump:setIsPumpActive(pumpIsActive, noEventSend)
	local spec = self.spec_umbilicalPump

	if pumpIsActive ~= spec.pumpIsActive then
		UmbilicalPumpActiveEvent.sendEvent(self, pumpIsActive, noEventSend)

		spec.pumpIsActive = pumpIsActive
		spec.characteristics.currentLoad = 0
		spec.characteristics.currentTime = 0
		spec.characteristics.condition = 1
		local key = pumpIsActive and "action_deactivateManurePump" or "action_activateManurePump"

		if spec.actionEvents ~= nil then
			local togglePumpEvent = spec.actionEvents[InputAction.PM_TOGGLE_PUMP_STATE]

			if togglePumpEvent ~= nil then
				g_inputBinding:setActionEventText(togglePumpEvent.actionEventId, g_i18n:getText(key))
			end
		end

		if self.isClient then
			if pumpIsActive then
				g_soundManager:playSample(spec.samples.pump)
			else
				g_soundManager:stopSample(spec.samples.pump)
			end
		end
	end
end

function UmbilicalPump:isPumpActive()
	return self.spec_umbilicalPump.pumpIsActive
end

function UmbilicalPump:isPumpAllowed()
	local spec = self.spec_umbilicalPump

	if not self:getIsPowered() and not spec.isWaterPump then
		return false
	end

	local to = self:getPumpToOrBufferObject()

	if to == nil then
		return false
	end

	if spec.isStandalone and spec.isWaterPump then
		return true
	end

	local from, fromFillUnitIndex = self:getPumpFromOrSelfObject()

	if from == self and self:getFillUnitFillLevel(fromFillUnitIndex) == 0 then
		return false
	end

	return from ~= nil and self:hasUmbilicalHose(spec.connectorIndex)
end

function UmbilicalPump:setIsPumpCirculating(pumpIsCirculating, noEventSend)
	local spec = self.spec_umbilicalPump

	if not self:isPumpActive() then
		pumpIsCirculating = false
	end

	if pumpIsCirculating ~= spec.pumpIsCirculating then
		UmbilicalPumpCirculatingEvent.sendEvent(self, pumpIsCirculating, noEventSend)

		spec.pumpIsCirculating = pumpIsCirculating
	end
end

function UmbilicalPump:isPumpCirculating()
	return self.spec_umbilicalPump.pumpIsCirculating
end

function UmbilicalPump:getValidSupportedFillUnitIndex(object)
	local spec = self.spec_umbilicalPump
	local isTrigger = object:isa(LoadTrigger)

	if isTrigger then
		local fillLevels = object.source:getAllFillLevels(self:getOwnerFarmId())

		for fillTypeIndex in pairs(spec.supportedFillTypes) do
			for sourceFillTypeIndex, fillLevel in pairs(fillLevels) do
				if sourceFillTypeIndex == fillTypeIndex and fillLevel > 0 then
					return fillTypeIndex
				end
			end
		end

		return nil
	end

	if object.getFirstValidFillUnitToFill == nil then
		return nil
	end

	for fillTypeIndex in pairs(spec.supportedFillTypes) do
		local fillUnitIndex = object:getFirstValidFillUnitToFill(fillTypeIndex, true)

		if fillUnitIndex ~= nil then
			return fillUnitIndex
		end
	end

	return nil
end

function UmbilicalPump:setPumpToObject(object, fillUnitIndex)
	local spec = self.spec_umbilicalPump

	if object ~= nil and fillUnitIndex == nil then
		fillUnitIndex = self:getValidSupportedFillUnitIndex(object)

		if fillUnitIndex == nil then
			object = nil
		end
	end

	spec.targetObject = object
	spec.targetFillUnitIndex = fillUnitIndex
end

function UmbilicalPump:setPumpFromObject(object, fillUnitIndex, isTrigger)
	local spec = self.spec_umbilicalPump
	spec.sourceObject = object
	spec.sourceFillUnitIndex = fillUnitIndex
	spec.sourceIsTrigger = isTrigger or false
end

function UmbilicalPump:tryAutomaticPumpTurnOn(forced)
	if not self.isServer or not g_currentMission.missionInfo.automaticMotorStartEnabled then
		return
	end

	local spec = self.spec_umbilicalPump
	local rootVehicle = self:getRootVehicle()

	if rootVehicle ~= nil and rootVehicle.getIsControlled ~= nil and not rootVehicle:getIsControlled() and rootVehicle.getIsMotorStarted ~= nil and not rootVehicle:getIsMotorStarted() then
		spec.turnOffTimer = UmbilicalPump.PUMP_MOTOR_TURN_OFF_TIME

		rootVehicle:startMotor()
	end

	if not self:isPumpActive() and self:isPumpAllowed() or forced ~= nil and forced then
		self:setIsPumpActive(true)
	end
end

function UmbilicalPump:tryAutomaticPumpTurnOff(dt)
	if not self.isServer or not g_currentMission.missionInfo.automaticMotorStartEnabled then
		return
	end

	local spec = self.spec_umbilicalPump

	if spec.turnOffTimer == nil or spec.pumpHasLoad then
		spec.turnOffTimer = UmbilicalPump.PUMP_MOTOR_TURN_OFF_TIME
	end

	if not spec.pumpHasLoad and spec.turnOffTimer > 0 then
		spec.turnOffTimer = spec.turnOffTimer - dt
	elseif spec.turnOffTimer <= 0 then
		local rootVehicle = self:getRootVehicle()

		if rootVehicle.getIsControlled ~= nil and not rootVehicle:getIsControlled() and rootVehicle.getIsMotorStarted ~= nil and rootVehicle:getIsMotorStarted() then
			for _, vehicle in pairs(rootVehicle:getChildVehicles()) do
				if vehicle ~= self and vehicle.isPumpActive ~= nil and vehicle:isPumpActive() then
					return
				end
			end

			self:setIsPumpActive(false)
			rootVehicle:stopMotor()
		end
	end
end

function UmbilicalPump:getPumpToOrBufferObject()
	local spec = self.spec_umbilicalPump
	local to = spec.targetObject
	local toFillUnitIndex = spec.targetFillUnitIndex

	if not spec.isWaterPump and to ~= nil and to.getFillUnitFreeCapacity ~= nil and to:getFillUnitFreeCapacity(toFillUnitIndex) <= 0 then
		local toRootVehicle = to:getRootVehicle()
		local vehicles = toRootVehicle:getChildVehicles()

		for _, vehicle in pairs(vehicles) do
			local bufferVehicle, bufferFillUnit = UmbilicalPump.getFillUnitBufferVehicle(vehicle)

			if bufferVehicle ~= nil then
				return bufferVehicle, bufferFillUnit
			end
		end

		local bufferVehicle, bufferFillUnit = UmbilicalPump.getFillUnitBufferVehicle(self)

		if bufferVehicle ~= nil then
			return bufferVehicle, bufferFillUnit
		end
	end

	return to, toFillUnitIndex
end

function UmbilicalPump:getPumpWarning(onlyForTurnOff)
	local spec = self.spec_umbilicalPump
	onlyForTurnOff = onlyForTurnOff or false

	if not spec.isWaterPump then
		local hasUmbilicalHose = self:hasUmbilicalHose(spec.connectorIndex)

		if not onlyForTurnOff and not hasUmbilicalHose then
			return UmbilicalPump.WARNING_ATTACH_UMBILICAL_HOSE
		end
	end

	local to = self:getPumpToOrBufferObject()

	if not onlyForTurnOff and to == nil then
		return UmbilicalPump.WARNING_NO_TARGET_FOUND
	end

	local from, fromFillUnitIndex = self:getPumpFromOrSelfObject()

	if from == nil then
		return UmbilicalPump.WARNING_NO_SOURCE_FOUND
	end

	if from:isa(LoadTrigger) then
		local fillTypeIndex = self:getValidSupportedFillUnitIndex(from)

		if fillTypeIndex == nil then
			return UmbilicalPump.WARNING_NO_SOURCE_FOUND
		end

		local fillLevel = from.source:getFillLevel(fillTypeIndex, self:getOwnerFarmId())

		if fillLevel <= 0 then
			return UmbilicalPump.WARNING_SOURCE_SILO_EMPTY
		end
	end

	if from:isa(Vehicle) and from == self and self:getFillUnitFillLevel(fromFillUnitIndex) <= 0 then
		return UmbilicalPump.WARNING_SOURCE_VEHICLE_EMPTY
	end

	return nil
end

function UmbilicalPump:onAttachUmbilicalHose(umbilicalHose)
	local spec = self.spec_umbilicalPump

	if umbilicalHose ~= nil and spec.targetObject == nil then
		local object = umbilicalHose:searchObject(self, function (object)
			return not object:isa(UmbilicalHoseWrench) and SpecializationUtil.hasSpecialization(UmbilicalHoseConnector, object.specializations)
		end)

		if object ~= nil then
			self:setPumpToObject(object)
		end
	end
end

function UmbilicalPump:onDetachUmbilicalHose(umbilicalHose)
	local object = nil

	if umbilicalHose ~= nil then
		object = umbilicalHose:searchObject(self, function (object)
			return not object:isa(UmbilicalHoseWrench) and SpecializationUtil.hasSpecialization(UmbilicalHoseConnector, object.specializations)
		end)
	end

	local spec = self.spec_umbilicalPump

	if object == nil or self:hasUmbilicalHose(spec.connectorIndex) then
		self:setPumpToObject(nil, )
	else
		self:setPumpToObject(object)
	end
end

function UmbilicalPump:getPumpLoad()
	if self:isPumpActive() then
		return self.spec_umbilicalPump.characteristics.currentLoad
	end

	return 0
end

function UmbilicalPump:dashboardLoadState(dashboard, newValue, minValue, maxValue, isActive)
	Dashboard.defaultDashboardStateFunc(self, dashboard, newValue, minValue, maxValue, isActive)
end

function UmbilicalPump:getUseTurnedOnSchema(superFunc)
	local spec = self.spec_umbilicalPump

	return spec.pumpIsActive or superFunc(self)
end

function UmbilicalPump:getIsOperating(superFunc)
	local spec = self.spec_umbilicalPump

	return spec.pumpIsActive or superFunc(self)
end

function UmbilicalPump:getIsPowerTakeOffActive(superFunc)
	local spec = self.spec_umbilicalPump

	return spec.pumpIsActive or superFunc(self)
end

function UmbilicalPump:getConsumingLoad(superFunc)
	local value, count = superFunc(self)
	local spec = self.spec_umbilicalPump
	local load = spec.characteristics.currentLoad

	return value + load, count + 1
end

function UmbilicalPump:getDoConsumePtoPower(superFunc)
	local spec = self.spec_umbilicalPump

	return spec.pumpIsActive or superFunc(self)
end

function UmbilicalPump:getPtoRpm(superFunc)
	local spec = self.spec_umbilicalPump
	local rpm = superFunc(self)

	if spec.pumpIsActive then
		local load = spec.characteristics.currentLoad
		local maxRpm = self.spec_powerConsumer.ptoRpm

		if maxRpm > 540 then
			local virtualCapRpm = rpm * 0.4
			maxRpm = maxRpm - virtualCapRpm
		end

		return maxRpm * math.max(load, 0.75)
	end

	return rpm
end

function UmbilicalPump:canUpdateUmbilicalHose(superFunc)
	if self:isPumpActive() then
		return false
	end

	local spec = self.spec_umbilicalPump

	if spec.isWaterPump then
		return false
	end

	return superFunc(self)
end

function UmbilicalPump:onCollisionCallback(hitObjectId, x, y, z, distance)
	if hitObjectId == 0 or hitObjectId == g_currentMission.terrainRootNode then
		return
	end

	local spec = self.spec_umbilicalPump
	local object = g_currentMission:getNodeObject(hitObjectId)

	if object ~= nil and object ~= self and object ~= nil and object ~= self then
		local isVehicle = object:isa(Vehicle)
		local isTrigger = object:isa(LoadTrigger)

		if isVehicle or isTrigger then
			if spec.trigger.objects[object] == nil then
				local fillUnitIndex = self:getValidSupportedFillUnitIndex(object)

				if fillUnitIndex ~= nil then
					spec.trigger.objects[object] = {
						count = 0,
						fillUnitIndex = fillUnitIndex,
						nodeId = hitObjectId,
						isTrigger = isTrigger
					}
					spec.trigger.numObjects = spec.trigger.numObjects + 1
				end
			end

			if spec.trigger.objects[object] ~= nil then
				spec.trigger.objects[object].count = spec.trigger.objects[object].count + 1

				self:raiseActive()
			end
		end
	end
end

function UmbilicalPump:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	if self.isClient then
		local spec = self.spec_umbilicalPump

		self:clearActionEventsTable(spec.actionEvents)

		if isActiveForInput then
			local key = spec.pumpIsActive and "action_deactivateManurePump" or "action_activateManurePump"
			local _, actionEventTogglePump = self:addActionEvent(spec.actionEvents, InputAction.PM_TOGGLE_PUMP_STATE, self, UmbilicalPump.actionEventTogglePump, false, true, false, true, nil, , true)

			g_inputBinding:setActionEventText(actionEventTogglePump, g_i18n:getText(key))
			g_inputBinding:setActionEventTextVisibility(actionEventTogglePump, true)
			g_inputBinding:setActionEventTextPriority(actionEventTogglePump, GS_PRIO_HIGH)
		end
	end
end

function UmbilicalPump:actionEventTogglePump(...)
	local spec = self.spec_umbilicalPump

	if spec.pumpAllowed then
		self:setIsPumpActive(not self:isPumpActive())
	elseif self.isClient then
		local warningId = self:getPumpWarning()

		if warningId ~= nil then
			g_currentMission:showBlinkingWarning(g_i18n:getText(UmbilicalPump.WARNINGS[warningId]))
		end
	end
end
