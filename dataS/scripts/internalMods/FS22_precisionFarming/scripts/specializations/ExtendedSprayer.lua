ExtendedSprayer = {
	MOD_NAME = g_currentModName
}

source(g_currentModDirectory .. "scripts/hud/ExtendedSprayerHUDExtension.lua")
VehicleHUDExtension.registerHUDExtension(ExtendedSprayer, ExtendedSprayerHUDExtension)

function ExtendedSprayer.prerequisitesPresent(specializations)
	return SpecializationUtil.hasSpecialization(Sprayer, specializations) and SpecializationUtil.hasSpecialization(PrecisionFarmingStatistic, specializations)
end

function ExtendedSprayer.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "setSprayAmountAutoMode", ExtendedSprayer.setSprayAmountAutoMode)
	SpecializationUtil.registerFunction(vehicleType, "setSprayAmountManualValue", ExtendedSprayer.setSprayAmountManualValue)
	SpecializationUtil.registerFunction(vehicleType, "setSprayAmountAutoFruitTypeIndex", ExtendedSprayer.setSprayAmountAutoFruitTypeIndex)
	SpecializationUtil.registerFunction(vehicleType, "setSprayAmountDefaultFruitRequirementIndex", ExtendedSprayer.setSprayAmountDefaultFruitRequirementIndex)
	SpecializationUtil.registerFunction(vehicleType, "getCurrentSprayerMode", ExtendedSprayer.getCurrentSprayerMode)
	SpecializationUtil.registerFunction(vehicleType, "getCurrentNitrogenLevelOffset", ExtendedSprayer.getCurrentNitrogenLevelOffset)
	SpecializationUtil.registerFunction(vehicleType, "getCurrentNitrogenUsageLevelOffset", ExtendedSprayer.getCurrentNitrogenUsageLevelOffset)
	SpecializationUtil.registerFunction(vehicleType, "getIsUsingExactNitrogenAmount", ExtendedSprayer.getIsUsingExactNitrogenAmount)
	SpecializationUtil.registerFunction(vehicleType, "getIsPrecisionSprayingRequired", ExtendedSprayer.getIsPrecisionSprayingRequired)
	SpecializationUtil.registerFunction(vehicleType, "preProcessExtUnderRootFertilizerArea", ExtendedSprayer.preProcessExtUnderRootFertilizerArea)
	SpecializationUtil.registerFunction(vehicleType, "postProcessExtUnderRootFertilizerArea", ExtendedSprayer.postProcessExtUnderRootFertilizerArea)
end

function ExtendedSprayer.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getSprayerUsage", ExtendedSprayer.getSprayerUsage)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "processSprayerArea", ExtendedSprayer.processSprayerArea)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "changeSeedIndex", ExtendedSprayer.changeSeedIndex)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getSprayerDoubledAmountActive", ExtendedSprayer.getSprayerDoubledAmountActive)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "updateSprayerEffects", ExtendedSprayer.updateSprayerEffects)
end

function ExtendedSprayer.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", ExtendedSprayer)
	SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", ExtendedSprayer)
	SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", ExtendedSprayer)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", ExtendedSprayer)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", ExtendedSprayer)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", ExtendedSprayer)
	SpecializationUtil.registerEventListener(vehicleType, "onChangedFillType", ExtendedSprayer)
	SpecializationUtil.registerEventListener(vehicleType, "onTurnedOn", ExtendedSprayer)
	SpecializationUtil.registerEventListener(vehicleType, "onTurnedOff", ExtendedSprayer)
	SpecializationUtil.registerEventListener(vehicleType, "onStateChange", ExtendedSprayer)
	SpecializationUtil.registerEventListener(vehicleType, "onVariableWorkWidthSectionChanged", ExtendedSprayer)
	SpecializationUtil.registerEventListener(vehicleType, "onEndWorkAreaProcessing", ExtendedSprayer)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", ExtendedSprayer)
end

function ExtendedSprayer:onLoad(savegame)
	local specName = ExtendedSprayer.MOD_NAME .. ".extendedSprayer"
	self.spec_extendedSprayer = self["spec_" .. specName]
	local spec = self.spec_extendedSprayer

	if g_precisionFarming ~= nil then
		spec.soilMap = g_precisionFarming.soilMap
		spec.pHMap = g_precisionFarming.pHMap
		spec.nitrogenMap = g_precisionFarming.nitrogenMap
	end

	spec.texts = {
		toggleSprayAmountAutoModePos = g_i18n:getText("action_toggleSprayAmountAutoModePos", self.customEnvironment),
		toggleSprayAmountAutoModeNeg = g_i18n:getText("action_toggleSprayAmountAutoModeNeg", self.customEnvironment),
		toggleSprayAmountAutoManual = g_i18n:getText("action_toggleSprayAmountManual", self.customEnvironment),
		toggleSprayDefaultFruitRequirement = g_i18n:getText("action_toggleSprayDefaultFruitRequirement", self.customEnvironment)
	}
	spec.lastLitersPerHectar = 0
	spec.lastNitrogenProportion = 0
	spec.lastRegularUsage = 0
	spec.lastTouchedSoilType = 0
	spec.lastTouchedSoilTypeReal = 0
	spec.lastTouchedSoilTypeSent = 0
	spec.lastTouchedSoilTypeTimer = 0
	spec.lastTouchedSoilTypeInterval = 2000
	spec.lastGroundUpdateDistance = math.huge
	spec.groundUpdateDistance = 4
	spec.phChangeBuffer = UsageBuffer.new(2000, PHMap.NUM_BITS)
	spec.phActualBuffer = UsageBuffer.new(1000, PHMap.NUM_BITS)
	spec.phTargetBuffer = UsageBuffer.new(1000, PHMap.NUM_BITS)
	spec.nChangeBuffer = UsageBuffer.new(2000, NitrogenMap.NUM_BITS)
	spec.nActualBuffer = UsageBuffer.new(1000, NitrogenMap.NUM_BITS)
	spec.nTargetBuffer = UsageBuffer.new(1000, NitrogenMap.NUM_BITS)
	spec.sprayAmountAutoMode = true
	spec.sprayAmountAutoModeChangeAllowed = true
	spec.sprayAmountManual = 1
	spec.sprayAmountManualMin = 1
	spec.sprayAmountManualMax = 1
	spec.inputActionToggleAuto = InputAction.PRECISIONFARMING_SPRAY_AMOUNT_MODE
	spec.inputActionToggleSprayAmount = InputAction.PRECISIONFARMING_SPRAY_AMOUNT
	spec.isDoingMissionWork = false
	local _, _, nMaxValue = spec.nitrogenMap:getMinMaxValue()
	spec.sprayAmountManualMax = nMaxValue
	spec.isLimingActive = false
	spec.attachStateChanged = false
	spec.nApplyAutoModeFruitType = FruitType.UNKNOWN
	spec.nApplyAutoModeFruitTypeSent = FruitType.UNKNOWN
	spec.nApplyAutoModeFruitRequirementDefaultIndex = 1
	spec.nApplyAutoModeFruitTypeRequiresDefaultMode = false
	spec.lastAreaChangeTime = -math.huge
	spec.lastSprayerEffectState = true
	local sprayerFillUnitIndex = self:getSprayerFillUnitIndex()
	spec.isSlurryTanker = self:getFillUnitAllowsFillType(sprayerFillUnitIndex, FillType.LIQUIDMANURE) or self:getFillUnitAllowsFillType(sprayerFillUnitIndex, FillType.DIGESTATE)
	spec.isManureSpreader = self:getFillUnitAllowsFillType(sprayerFillUnitIndex, FillType.MANURE)
	spec.isSolidFertilizerSprayer = self:getFillUnitAllowsFillType(sprayerFillUnitIndex, FillType.FERTILIZER) or self:getFillUnitAllowsFillType(sprayerFillUnitIndex, FillType.LIME)
	spec.isLiquidFertilizerSprayer = self:getFillUnitAllowsFillType(sprayerFillUnitIndex, FillType.LIQUIDFERTILIZER)
	spec.usageValuesDirtyFlag = self:getNextDirtyFlag()
end

function ExtendedSprayer:onPostLoad(savegame)
	if savegame ~= nil and not savegame.resetVehicles then
		local spec = self.spec_extendedSprayer
		local specName = ExtendedSprayer.MOD_NAME .. ".extendedSprayer"

		self:setSprayAmountAutoMode(Utils.getNoNil(savegame.xmlFile:getBool(savegame.key .. "." .. specName .. "#sprayAmountAutoMode"), spec.sprayAmountAutoMode), true)
		self:setSprayAmountManualValue(savegame.xmlFile:getInt(savegame.key .. "." .. specName .. "#sprayAmountManual") or spec.sprayAmountManual, true)
	end
end

function ExtendedSprayer:saveToXMLFile(xmlFile, key, usedModNames)
	local spec = self.spec_extendedSprayer

	xmlFile:setBool(key .. "#sprayAmountAutoMode", spec.sprayAmountAutoMode)
	xmlFile:setInt(key .. "#sprayAmountManual", spec.sprayAmountManual)
end

function ExtendedSprayer:onReadUpdateStream(streamId, timestamp, connection)
	if connection:getIsServer() then
		local spec = self.spec_extendedSprayer

		if streamReadBool(streamId) then
			spec.phChangeBuffer:readStream(streamId, connection)
			spec.phActualBuffer:readStream(streamId, connection)
			spec.phTargetBuffer:readStream(streamId, connection)
			spec.nChangeBuffer:readStream(streamId, connection)
			spec.nActualBuffer:readStream(streamId, connection)
			spec.nTargetBuffer:readStream(streamId, connection)

			spec.lastTouchedSoilType = streamReadUIntN(streamId, 3)

			if streamReadBool(streamId) then
				self:setSprayAmountAutoFruitTypeIndex(streamReadUIntN(streamId, FruitTypeManager.SEND_NUM_BITS))
			else
				self:setSprayAmountAutoFruitTypeIndex(nil)
			end
		end
	end
end

function ExtendedSprayer:onWriteUpdateStream(streamId, connection, dirtyMask)
	if not connection:getIsServer() then
		local spec = self.spec_extendedSprayer

		if streamWriteBool(streamId, bitAND(dirtyMask, spec.usageValuesDirtyFlag) ~= 0) then
			spec.phChangeBuffer:writeStream(streamId, connection)
			spec.phActualBuffer:writeStream(streamId, connection)
			spec.phTargetBuffer:writeStream(streamId, connection)
			spec.nChangeBuffer:writeStream(streamId, connection)
			spec.nActualBuffer:writeStream(streamId, connection)
			spec.nTargetBuffer:writeStream(streamId, connection)
			streamWriteUIntN(streamId, spec.lastTouchedSoilType, 3)

			if streamWriteBool(streamId, spec.nApplyAutoModeFruitType ~= nil) then
				streamWriteUIntN(streamId, spec.nApplyAutoModeFruitType, FruitTypeManager.SEND_NUM_BITS)
			end
		end
	end
end

function ExtendedSprayer:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	local spec = self.spec_extendedSprayer

	if self.isServer then
		if g_time - spec.lastAreaChangeTime > 500 then
			spec.lastGroundUpdateDistance = spec.lastGroundUpdateDistance + self.lastMovedDistance

			if spec.groundUpdateDistance < spec.lastGroundUpdateDistance then
				spec.lastGroundUpdateDistance = 0
				local workArea = self:getWorkAreaByIndex(1)

				if workArea ~= nil then
					local x, y, z = nil
					local lx, _, _ = localToLocal(workArea.start, self.rootNode, 0, 0, 0)

					if math.abs(lx) < 0.5 then
						x, y, z = getWorldTranslation(workArea.start)
					else
						local x1, y1, z1 = getWorldTranslation(workArea.start)
						local x2, y2, z2 = getWorldTranslation(workArea.width)
						z = (z1 + z2) * 0.5
						y = (y1 + y2) * 0.5
						x = (x1 + x2) * 0.5
					end

					local isOnField, _ = FSDensityMapUtil.getFieldDataAtWorldPosition(x, 0, z)

					if isOnField then
						local sprayer, fillUnitIndex = ExtendedSprayer.getFillTypeSourceVehicle(self)
						local fillType = sprayer:getFillUnitLastValidFillType(fillUnitIndex)

						if fillType == FillType.UNKNOWN then
							fillType = sprayer:getFillUnitFirstSupportedFillType(fillUnitIndex)
						end

						if fillType == FillType.LIME then
							local pHLevel = spec.pHMap:getLevelAtWorldPos(x, z)
							local pHOptimal = 0
							local soilTypeIndex = spec.soilMap:getTypeIndexAtWorldPos(x, z)

							if soilTypeIndex > 0 then
								pHOptimal = spec.pHMap:getOptimalPHValueForSoilTypeIndex(soilTypeIndex)
							end

							spec.phChangeBuffer:add(0)
							spec.phActualBuffer:add(pHLevel, true)
							spec.phTargetBuffer:add(pHOptimal, true)

							spec.lastTouchedSoilTypeReal = soilTypeIndex

							if spec.lastTouchedSoilType == 0 then
								spec.lastTouchedSoilType = soilTypeIndex
							end
						else
							local forcedFruitType = nil

							if self.spec_sowingMachine ~= nil then
								forcedFruitType = self.spec_sowingMachine.workAreaParameters.seedsFruitType
							end

							local nLevel = spec.nitrogenMap:getLevelAtWorldPos(x, z)
							local nTarget, soilTypeIndex, fruitTypeIndex = spec.nitrogenMap:getTargetLevelAtWorldPos(x, z, nil, forcedFruitType, fillType, nLevel, spec.nApplyAutoModeFruitRequirementDefaultIndex)

							spec.nChangeBuffer:add(0)
							spec.nActualBuffer:add(nLevel, true, true)
							spec.nTargetBuffer:add(nTarget, true, true)
							self:setSprayAmountAutoFruitTypeIndex(fruitTypeIndex)

							spec.lastTouchedSoilTypeReal = soilTypeIndex

							if spec.lastTouchedSoilType == 0 then
								spec.lastTouchedSoilType = soilTypeIndex
							end
						end
					else
						spec.phChangeBuffer:reset()
						spec.phActualBuffer:reset()
						spec.phTargetBuffer:reset()
						spec.nChangeBuffer:reset()
						spec.nActualBuffer:reset()
						spec.nTargetBuffer:reset()

						spec.lastTouchedSoilType = 0
						spec.lastTouchedSoilTypeReal = 0
						spec.lastLitersPerHectar = 0
						spec.lastNitrogenProportion = 0

						self:raiseDirtyFlags(spec.usageValuesDirtyFlag)
					end
				end
			else
				spec.phActualBuffer:add(nil, true)
				spec.phTargetBuffer:add(nil, true)
				spec.nActualBuffer:add(nil, true)
				spec.nTargetBuffer:add(nil, true)
			end
		elseif self:getIsTurnedOn() then
			spec.phActualBuffer:add()
			spec.phTargetBuffer:add()
			spec.nActualBuffer:add()
			spec.nTargetBuffer:add()

			spec.lastGroundUpdateDistance = spec.groundUpdateDistance * 0.5
		else
			spec.lastGroundUpdateDistance = spec.groundUpdateDistance * 0.5
		end
	end
end

function ExtendedSprayer:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	local spec = self.spec_extendedSprayer

	if self.isServer then
		spec.phChangeBuffer:update(dt)
		spec.phActualBuffer:update(dt)
		spec.phTargetBuffer:update(dt)
		spec.nChangeBuffer:update(dt)
		spec.nActualBuffer:update(dt)
		spec.nTargetBuffer:update(dt)

		if spec.phChangeBuffer:getIsDirty() or spec.phActualBuffer:getIsDirty() or spec.phTargetBuffer:getIsDirty() or spec.nChangeBuffer:getIsDirty() or spec.nActualBuffer:getIsDirty() or spec.nTargetBuffer:getIsDirty() then
			spec.phChangeBuffer:resetDirtyState()
			spec.phActualBuffer:resetDirtyState()
			spec.phTargetBuffer:resetDirtyState()
			spec.nChangeBuffer:resetDirtyState()
			spec.nActualBuffer:resetDirtyState()
			spec.nTargetBuffer:resetDirtyState()
			self:raiseDirtyFlags(spec.usageValuesDirtyFlag)
		end

		spec.lastTouchedSoilTypeTimer = spec.lastTouchedSoilTypeTimer + dt

		if spec.lastTouchedSoilTypeInterval < spec.lastTouchedSoilTypeTimer then
			spec.lastTouchedSoilType = spec.lastTouchedSoilTypeReal
			spec.lastTouchedSoilTypeTimer = 0

			if spec.lastTouchedSoilTypeSent ~= spec.lastTouchedSoilType then
				self:raiseDirtyFlags(spec.usageValuesDirtyFlag)

				spec.lastTouchedSoilTypeSent = spec.lastTouchedSoilType
			end
		end

		if spec.nApplyAutoModeFruitType ~= spec.nApplyAutoModeFruitTypeSent then
			self:raiseDirtyFlags(spec.usageValuesDirtyFlag)

			spec.nApplyAutoModeFruitTypeSent = spec.nApplyAutoModeFruitType
		end
	end

	if self.isClient then
		if self:getIsTurnedOn() then
			ExtendedSprayer.updateSprayerEffectState(self)
		else
			spec.lastSprayerEffectState = true
		end
	end

	spec.isLiming, spec.isFertilizing = self:getCurrentSprayerMode()

	if self:getIsActiveForInput(true, true) then
		ExtendedSprayer.updateMinimapActiveState(self)

		local _, _, _, _, mission = self:getPFStatisticInfo()
		local isDoingMissionWork = mission ~= nil or spec.sprayAmountAutoMode and spec.nApplyAutoModeFruitTypeRequiresDefaultMode

		if spec.isDoingMissionWork ~= isDoingMissionWork then
			spec.isDoingMissionWork = isDoingMissionWork

			ExtendedSprayer.updateMinimapActiveState(self)
		end
	end
end

function ExtendedSprayer:onChangedFillType(fillUnitIndex, fillTypeIndex, oldFillTypeIndex)
	local spec = self.spec_extendedSprayer

	if spec.isSolidFertilizerSprayer and fillTypeIndex == FillType.LIME then
		local _, _, pHMaxValue = spec.pHMap:getMinMaxValue()
		spec.sprayAmountManualMax = pHMaxValue - 1
		spec.isLimingActive = true
	else
		local _, _, nMaxValue = spec.nitrogenMap:getMinMaxValue()
		spec.sprayAmountManualMax = nMaxValue - 1
		spec.isLimingActive = false
	end
end

function ExtendedSprayer:onTurnedOn()
	if self.isClient then
		ExtendedSprayer.updateSprayerEffectState(self, true)
	end
end

function ExtendedSprayer:onTurnedOff()
	if self.isClient then
		ExtendedSprayer.updateSprayerEffectState(self, true)
	end
end

function ExtendedSprayer:onStateChange(state, data)
	local spec = self.spec_extendedSprayer

	if state == Vehicle.STATE_CHANGE_ATTACH or state == Vehicle.STATE_CHANGE_DETACH then
		spec.attachStateChanged = true
	end
end

function ExtendedSprayer:onVariableWorkWidthSectionChanged()
	local vehicles = self.rootVehicle.childVehicles

	for i = 1, #vehicles do
		local vehicle = vehicles[i]

		if SpecializationUtil.hasSpecialization(CropSensor, vehicle.specializations) then
			vehicle:updateCropSensorWorkingWidth()
		end
	end

	if self.isClient then
		ExtendedSprayer.updateSprayerEffectState(self, true)
	end
end

function ExtendedSprayer:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	if self.isClient then
		local spec = self.spec_extendedSprayer

		self:clearActionEventsTable(spec.actionEvents)
		spec.pHMap:setRequireMinimapDisplay(false, self)
		spec.nitrogenMap:setRequireMinimapDisplay(false, self)

		if isActiveForInputIgnoreSelection and self == ExtendedSprayer.getValidSprayerToUse(self) then
			if spec.sprayAmountAutoModeChangeAllowed then
				local _, actionEventId = self:addActionEvent(spec.actionEvents, spec.inputActionToggleAuto, self, ExtendedSprayer.actionEventToggleAuto, false, true, false, true, nil)

				g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_HIGH)
			end

			local _, actionEventId = self:addActionEvent(spec.actionEvents, spec.inputActionToggleSprayAmount, self, ExtendedSprayer.actionEventChangeSprayAmount, false, true, false, true, nil)

			g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_HIGH)
			g_inputBinding:setActionEventText(actionEventId, spec.texts.toggleSprayAmountAutoManual)

			if self.spec_sowingMachine == nil then
				_, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.TOGGLE_SEEDS, self, ExtendedSprayer.actionEventChangeDefaultFruitRequirement, false, true, false, true, nil)

				g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_HIGH)
				g_inputBinding:setActionEventText(actionEventId, spec.texts.toggleSprayDefaultFruitRequirement)
			end

			ExtendedSprayer.updateActionEventState(self)
			ExtendedSprayer.updateActionEventAutoModeDefault(self)
			ExtendedSprayer.updateMinimapActiveState(self)
		end

		spec.attachStateChanged = true
	end
end

function ExtendedSprayer:getValidSprayerToUse()
	local vehicleList = self.rootVehicle.childVehicles

	for i = 1, #vehicleList do
		local subVehicle = vehicleList[i]

		if ExtendedSprayer.getIsVehicleValid(subVehicle) then
			return subVehicle
		end
	end

	return nil
end

function ExtendedSprayer.getIsVehicleValid(vehicle)
	if not SpecializationUtil.hasSpecialization(ExtendedSprayer, vehicle.specializations) then
		return false
	end

	if not SpecializationUtil.hasSpecialization(WorkArea, vehicle.specializations) then
		return false
	end

	if #vehicle.spec_workArea.workAreas == 0 then
		return false
	end

	if SpecializationUtil.hasSpecialization(ManureBarrel, vehicle.specializations) and vehicle.spec_manureBarrel.attachedTool ~= nil then
		return false
	end

	return true
end

function ExtendedSprayer:actionEventToggleAuto(actionName, inputValue, callbackState, isAnalog)
	self:setSprayAmountAutoMode()
end

function ExtendedSprayer:actionEventChangeSprayAmount(actionName, inputValue, callbackState, isAnalog)
	local spec = self.spec_extendedSprayer

	self:setSprayAmountManualValue(spec.sprayAmountManual + MathUtil.sign(inputValue))
end

function ExtendedSprayer:actionEventChangeDefaultFruitRequirement(actionName, inputValue, callbackState, isAnalog)
	local spec = self.spec_extendedSprayer

	self:setSprayAmountDefaultFruitRequirementIndex(spec.nitrogenMap:getNextFruitRequirementIndex(spec.nApplyAutoModeFruitRequirementDefaultIndex))
end

function ExtendedSprayer:updateActionEventState()
	local spec = self.spec_extendedSprayer
	local actionEventToggleAuto = spec.actionEvents[spec.inputActionToggleAuto]

	if actionEventToggleAuto ~= nil then
		g_inputBinding:setActionEventText(actionEventToggleAuto.actionEventId, spec.sprayAmountAutoMode and spec.texts.toggleSprayAmountAutoModeNeg or spec.texts.toggleSprayAmountAutoModePos)
	end

	local actionEventToggleSprayAmount = spec.actionEvents[spec.inputActionToggleSprayAmount]

	if actionEventToggleSprayAmount ~= nil then
		g_inputBinding:setActionEventActive(actionEventToggleSprayAmount.actionEventId, not spec.sprayAmountAutoMode)
	end
end

function ExtendedSprayer:updateActionEventAutoModeDefault()
	local spec = self.spec_extendedSprayer
	local actionEvent = spec.actionEvents[InputAction.TOGGLE_SEEDS]

	if actionEvent ~= nil then
		g_inputBinding:setActionEventActive(actionEvent.actionEventId, spec.sprayAmountAutoMode and (spec.nApplyAutoModeFruitType == nil or spec.nApplyAutoModeFruitType == FruitType.UNKNOWN))
	end
end

function ExtendedSprayer.getFillTypeSourceVehicle(sprayer)
	local fillUnitIndex = sprayer:getSprayerFillUnitIndex()

	if sprayer:getFillUnitFillLevel(fillUnitIndex) <= 0 then
		local spec = sprayer.spec_sprayer

		for _, supportedSprayType in ipairs(spec.supportedSprayTypes) do
			for _, src in ipairs(spec.fillTypeSources[supportedSprayType]) do
				local vehicle = src.vehicle

				if vehicle:getFillUnitFillType(src.fillUnitIndex) == supportedSprayType and vehicle:getFillUnitFillLevel(src.fillUnitIndex) > 0 then
					return vehicle, src.fillUnitIndex
				end
			end
		end
	end

	return sprayer, fillUnitIndex
end

function ExtendedSprayer:getCurrentSprayerMode()
	local sprayer, fillUnitIndex = ExtendedSprayer.getFillTypeSourceVehicle(self)
	local fillType = sprayer:getFillUnitLastValidFillType(fillUnitIndex)

	if fillType == FillType.LIME then
		return true, false
	end

	if fillType == FillType.FERTILIZER or fillType == FillType.LIQUIDFERTILIZER or fillType == FillType.MANURE or fillType == FillType.LIQUIDFERTILIZER or fillType == FillType.LIQUIDMANURE or fillType == FillType.DIGESTATE then
		return false, true
	end

	if fillType == FillType.HERBICIDE then
		return false, false
	end

	if self:getIsAIActive() then
		return false, true
	end

	return false, false
end

function ExtendedSprayer:getCurrentNitrogenLevelOffset(lastChangeLevels)
	return 0
end

function ExtendedSprayer:getCurrentNitrogenUsageLevelOffset(lastChangeLevels)
	return 0
end

function ExtendedSprayer:getIsUsingExactNitrogenAmount()
	return true
end

function ExtendedSprayer:updateMinimapActiveState()
	local spec = self.spec_extendedSprayer
	local _, _, _, isOnField = self:getPFStatisticInfo()
	local isActive = isOnField

	if isActive then
		local sprayer, fillUnitIndex = ExtendedSprayer.getFillTypeSourceVehicle(self)
		isActive = isActive and (sprayer:getFillUnitFillLevel(fillUnitIndex) > 0 or self:getIsAIActive())
	end

	isActive = isActive and (spec.isLiming or spec.isFertilizing)

	if spec.isLiming then
		spec.pHMap:setRequireMinimapDisplay(isActive, self, self:getIsSelected())
	elseif spec.isFertilizing then
		spec.nitrogenMap:setRequireMinimapDisplay(isActive, self, self:getIsSelected())
		spec.nitrogenMap:setMinimapMissionState(spec.isDoingMissionWork)
	end
end

function ExtendedSprayer:getIsPrecisionSprayingRequired()
	local spec = self.spec_extendedSprayer

	if spec.isDoingMissionWork then
		return true
	end

	if spec.sprayAmountAutoMode then
		if spec.isLiming then
			local pHActual = math.floor(spec.phActualBuffer:getLastAdded())
			local pHTarget = math.floor(spec.phTargetBuffer:getLastAdded())

			if pHTarget <= pHActual then
				return false
			end
		elseif spec.isFertilizing then
			local nActual = math.floor(spec.nActualBuffer:getLastAdded())
			local nTarget = math.floor(spec.nTargetBuffer:getLastAdded())

			if nTarget <= nActual then
				return false
			end
		end
	end

	return true
end

function ExtendedSprayer:updateSprayerEffectState(force)
	local spec = self.spec_extendedSprayer
	local effectState = self:getIsPrecisionSprayingRequired() and self:getAreEffectsVisible() and self:getIsTurnedOn()

	if spec.lastSprayerEffectState ~= effectState or force then
		local specSprayer = self.spec_sprayer
		local sprayType = self:getActiveSprayType()

		if effectState then
			local fillType = self:getFillUnitLastValidFillType(self:getSprayerFillUnitIndex())

			if fillType == FillType.UNKNOWN then
				fillType = self:getFillUnitFirstSupportedFillType(self:getSprayerFillUnitIndex())
			end

			g_effectManager:setFillType(specSprayer.effects, fillType)
			g_effectManager:startEffects(specSprayer.effects)
			g_soundManager:playSample(specSprayer.samples.spray)

			if sprayType ~= nil then
				g_effectManager:setFillType(sprayType.effects, fillType)
				g_effectManager:startEffects(sprayType.effects)
				g_animationManager:startAnimations(sprayType.animationNodes)
				g_soundManager:playSample(sprayType.samples.spray)
			end

			g_animationManager:startAnimations(specSprayer.animationNodes)
		else
			g_effectManager:stopEffects(specSprayer.effects)
			g_soundManager:stopSample(specSprayer.samples.spray)

			for _, _sprayType in ipairs(specSprayer.sprayTypes) do
				g_effectManager:stopEffects(_sprayType.effects)
				g_animationManager:stopAnimations(_sprayType.animationNodes)
				g_soundManager:stopSample(_sprayType.samples.spray)
			end

			g_animationManager:stopAnimations(specSprayer.animationNodes)
		end

		spec.lastSprayerEffectState = effectState
	end
end

function ExtendedSprayer:getSprayerUsage(superFunc, fillType, dt)
	local usage = superFunc(self, fillType, dt)

	if self:getIsTurnedOn() then
		local specSpray = self.spec_sprayer
		local usageScale = specSpray.usageScale
		local activeSprayType = self:getActiveSprayType()

		if activeSprayType ~= nil then
			usageScale = activeSprayType.usageScale
		end

		local workWidth = nil

		if usageScale.workAreaIndex ~= nil then
			workWidth = self:getWorkAreaWidth(usageScale.workAreaIndex)
		else
			workWidth = usageScale.workingWidth
		end

		local lastSpeed = math.max(self:getLastSpeed(), 1)
		local spec = self.spec_extendedSprayer
		local minRate = spec.sprayAmountAutoMode and 0 or 1

		if spec.isLiming then
			if spec.pHMap ~= nil then
				local changeValue = math.ceil(spec.phChangeBuffer:get())
				local litersPerUpdate, literPerHectar, regularUsage = spec.pHMap:getLimeUsage(workWidth, lastSpeed, math.max(changeValue, minRate), dt)
				spec.lastRegularUsage = regularUsage
				usage = litersPerUpdate
				spec.lastLitersPerHectar = literPerHectar
				spec.lastNitrogenProportion = 0
			end
		elseif spec.isFertilizing and spec.nitrogenMap ~= nil then
			if not spec.isDoingMissionWork then
				local sprayVehicle = specSpray.workAreaParameters.sprayVehicle

				if sprayVehicle == nil then
					sprayVehicle = ExtendedSprayer.getFillTypeSourceVehicle(self)
				end

				local changeValue = math.ceil(spec.nChangeBuffer:get())
				local actualNitrogen = spec.nActualBuffer:get()
				local nitrogenUsageLevelOffset = sprayVehicle ~= nil and sprayVehicle.getCurrentNitrogenUsageLevelOffset ~= nil and sprayVehicle:getCurrentNitrogenUsageLevelOffset(spec.nChangeBuffer:get()) or 0
				local litersPerUpdate, literPerHectar, regularUsage, nitrogenProportion = spec.nitrogenMap:getFertilizerUsage(workWidth, lastSpeed, math.max(changeValue, minRate), fillType, dt, spec.sprayAmountAutoMode, spec.nApplyAutoModeFruitType, actualNitrogen, nitrogenUsageLevelOffset)
				spec.lastRegularUsage = regularUsage
				usage = litersPerUpdate
				spec.lastLitersPerHectar = literPerHectar
				spec.lastNitrogenProportion = nitrogenProportion
			else
				spec.lastRegularUsage = usage
				spec.lastLitersPerHectar = usage / dt * 10000 / workWidth / (self.speedLimit / 3600)
				spec.lastNitrogenProportion = 0
			end
		end

		if self:getIsAIActive() and usage == 0 then
			usage = 0.0001
		end
	end

	return usage
end

function ExtendedSprayer:processSprayerArea(superFunc, workArea, dt)
	local specSpray = self.spec_sprayer
	local spec = self.spec_extendedSprayer

	if specSpray.workAreaParameters.sprayFillLevel <= 0 then
		return superFunc(self, workArea, dt)
	end

	if not spec.isLiming and not spec.isFertilizing then
		return superFunc(self, workArea, dt)
	end

	local sx, _, sz = getWorldTranslation(workArea.start)
	local wx, _, wz = getWorldTranslation(workArea.width)
	local hx, _, hz = getWorldTranslation(workArea.height)

	if self.isServer then
		if spec.pHMap ~= nil then
			local numPixelsChanged, phLevelDifference, phLevelActual, phLevelTarget, soilTypeIndex, _ = spec.pHMap:updateSprayArea(sx, sz, wx, wz, hx, hz, specSpray.workAreaParameters.sprayType, spec.sprayAmountAutoMode, spec.sprayAmountManual)

			if numPixelsChanged > 0 and phLevelDifference > 0 then
				if not spec.sprayAmountAutoMode then
					local cx = (sx + wx + hx) / 3
					local cz = (sz + wz + hz) / 3
					soilTypeIndex = spec.soilMap:getTypeIndexAtWorldPos(cx, cz)

					if soilTypeIndex > 0 then
						phLevelTarget = spec.pHMap:getOptimalPHValueForSoilTypeIndex(soilTypeIndex)
					end
				end

				spec.phChangeBuffer:add(phLevelDifference)
				spec.phActualBuffer:add(phLevelActual)
				spec.phTargetBuffer:add(phLevelTarget)

				spec.lastTouchedSoilTypeReal = soilTypeIndex

				if spec.lastTouchedSoilType == 0 then
					spec.lastTouchedSoilType = soilTypeIndex
				end

				spec.lastAreaChangeTime = g_time
			end
		end

		if spec.nitrogenMap ~= nil then
			local sprayVehicle = specSpray.workAreaParameters.sprayVehicle

			if sprayVehicle == nil then
				sprayVehicle = ExtendedSprayer.getFillTypeSourceVehicle(self)
			end

			local nitrogenLevelOffset = 0

			if sprayVehicle.getCurrentNitrogenLevelOffset ~= nil then
				nitrogenLevelOffset = sprayVehicle:getCurrentNitrogenLevelOffset(spec.nChangeBuffer:get())
			end

			local defaultNitrogenRequirementIndex = spec.nApplyAutoModeFruitRequirementDefaultIndex
			local numPixelsChanged, autoFruitTypeIndex, autoSoilTypeIndex, foundLevel, targetLevel, changeLevel, _ = spec.nitrogenMap:updateSprayArea(sx, sz, wx, wz, hx, hz, specSpray.workAreaParameters.sprayType, specSpray.workAreaParameters.sprayType, spec.sprayAmountAutoMode, spec.sprayAmountManual, nil, nitrogenLevelOffset, defaultNitrogenRequirementIndex)

			if numPixelsChanged > 0 then
				if not spec.sprayAmountAutoMode then
					local cx = (sx + wx + hx) / 3
					local cz = (sz + wz + hz) / 3

					if autoFruitTypeIndex == FruitType.UNKNOWN or autoSoilTypeIndex == 0 then
						local nTarget, soilTypeIndex, fruitTypeIndex = spec.nitrogenMap:getTargetLevelAtWorldPos(cx, cz, nil, , , , spec.nApplyAutoModeFruitRequirementDefaultIndex)
						targetLevel = nTarget
						autoSoilTypeIndex = soilTypeIndex
						autoFruitTypeIndex = fruitTypeIndex
					end
				end

				spec.nChangeBuffer:add(changeLevel)
				spec.nActualBuffer:add(foundLevel)
				spec.nTargetBuffer:add(targetLevel)
				self:setSprayAmountAutoFruitTypeIndex(autoFruitTypeIndex)

				if autoSoilTypeIndex ~= 0 then
					spec.lastTouchedSoilTypeReal = autoSoilTypeIndex

					if spec.lastTouchedSoilType == 0 then
						spec.lastTouchedSoilType = autoSoilTypeIndex
					end
				end

				spec.lastAreaChangeTime = g_time
			end
		end

		local changedArea = 0
		local totalArea = 0

		if self:getIsPrecisionSprayingRequired() then
			changedArea, totalArea = superFunc(self, workArea, dt)
			local desc = g_sprayTypeManager:getSprayTypeByIndex(specSpray.workAreaParameters.sprayType)

			if desc ~= nil then
				FSDensityMapUtil.setGroundTypeLayerArea(sx, sz, wx, wz, hx, hz, desc.sprayGroundType)
			end

			if spec.isDoingMissionWork and changedArea > 0 then
				spec.nitrogenMap:setMinimapRequiresUpdate(true)
			end
		end

		if spec.pHMap ~= nil then
			spec.pHMap:postUpdateSprayArea(sx, sz, wx, wz, hx, hz, specSpray.workAreaParameters.sprayType, specSpray.workAreaParameters.sprayType, spec.sprayAmountAutoMode, spec.sprayAmountManual)
		end

		if spec.nitrogenMap ~= nil then
			spec.nitrogenMap:postUpdateSprayArea(sx, sz, wx, wz, hx, hz, specSpray.workAreaParameters.sprayType, specSpray.workAreaParameters.sprayType, spec.sprayAmountAutoMode, spec.sprayAmountManual)
		end

		return changedArea, totalArea
	else
		local changedArea = 0
		local totalArea = 0

		if self:getIsPrecisionSprayingRequired() then
			changedArea, totalArea = superFunc(self, workArea, dt)
			local desc = g_sprayTypeManager:getSprayTypeByIndex(specSpray.workAreaParameters.sprayType)

			if desc ~= nil then
				FSDensityMapUtil.setGroundTypeLayerArea(sx, sz, wx, wz, hx, hz, desc.sprayGroundType)
			end
		end

		return changedArea, totalArea
	end
end

function ExtendedSprayer:changeSeedIndex(superFunc, ...)
	superFunc(self, ...)

	local spec = self.spec_extendedSprayer
	spec.lastGroundUpdateDistance = math.huge
end

function ExtendedSprayer:getSprayerDoubledAmountActive(superFunc, sprayTypeIndex)
	return false, false
end

function ExtendedSprayer:updateSprayerEffects(superFunc, force)
end

function ExtendedSprayer:preProcessExtUnderRootFertilizerArea(workArea, dt)
	local specSpray = self.spec_sprayer
	local spec = self.spec_extendedSprayer

	if self.isServer then
		local sx, _, sz = getWorldTranslation(workArea.start)
		local wx, _, wz = getWorldTranslation(workArea.width)
		local hx, _, hz = getWorldTranslation(workArea.height)

		if spec.nitrogenMap ~= nil then
			local sprayVehicle = specSpray.workAreaParameters.sprayVehicle

			if sprayVehicle == nil then
				sprayVehicle = ExtendedSprayer.getFillTypeSourceVehicle(self)
			end

			local forcedFruitType = nil

			if self.spec_sowingMachine ~= nil then
				forcedFruitType = self.spec_sowingMachine.workAreaParameters.seedsFruitType
			end

			local nitrogenLevelOffset = 0

			if sprayVehicle.getCurrentNitrogenLevelOffset ~= nil then
				nitrogenLevelOffset = sprayVehicle:getCurrentNitrogenLevelOffset(spec.nChangeBuffer:get())
			end

			local numPixelsChanged, _, autoSoilTypeIndex, foundLevel, targetLevel, changeLevel = spec.nitrogenMap:updateSprayArea(sx, sz, wx, wz, hx, hz, specSpray.workAreaParameters.sprayType, SprayType.FERTILIZER, spec.sprayAmountAutoMode, spec.sprayAmountManual, forcedFruitType, nitrogenLevelOffset)

			if numPixelsChanged > 0 then
				if not spec.sprayAmountAutoMode then
					local cx = (sx + wx + hx) / 3
					local cz = (sz + wz + hz) / 3
					local sprayer, fillUnitIndex = ExtendedSprayer.getFillTypeSourceVehicle(self)
					local fillType = sprayer:getFillUnitLastValidFillType(fillUnitIndex)

					if fillType == FillType.UNKNOWN then
						fillType = sprayer:getFillUnitFirstSupportedFillType(fillUnitIndex)
					end

					local nTarget, soilTypeIndex, _ = spec.nitrogenMap:getTargetLevelAtWorldPos(cx, cz, nil, forcedFruitType, fillType, foundLevel, spec.nApplyAutoModeFruitRequirementDefaultIndex)
					targetLevel = nTarget
					autoSoilTypeIndex = soilTypeIndex
				end

				spec.nChangeBuffer:add(changeLevel)
				spec.nActualBuffer:add(foundLevel)
				spec.nTargetBuffer:add(targetLevel)
				self:setSprayAmountAutoFruitTypeIndex(forcedFruitType)

				if autoSoilTypeIndex ~= 0 then
					spec.lastTouchedSoilTypeReal = autoSoilTypeIndex

					if spec.lastTouchedSoilType == 0 then
						spec.lastTouchedSoilType = autoSoilTypeIndex
					end
				end

				spec.lastAreaChangeTime = g_time
			end
		end
	end
end

function ExtendedSprayer:postProcessExtUnderRootFertilizerArea(workArea, dt)
	local specSpray = self.spec_sprayer
	local spec = self.spec_extendedSprayer

	if self.isServer then
		local sx, _, sz = getWorldTranslation(workArea.start)
		local wx, _, wz = getWorldTranslation(workArea.width)
		local hx, _, hz = getWorldTranslation(workArea.height)
		local desc = g_sprayTypeManager:getSprayTypeByIndex(SprayType.FERTILIZER)

		if desc ~= nil then
			FSDensityMapUtil.setGroundTypeLayerArea(sx, sz, wx, wz, hx, hz, desc.sprayGroundType)
		end

		if spec.nitrogenMap ~= nil then
			spec.nitrogenMap:postUpdateSprayArea(sx, sz, wx, wz, hx, hz, specSpray.workAreaParameters.sprayType, SprayType.FERTILIZER, spec.sprayAmountAutoMode, spec.sprayAmountManual)
		end
	end
end

function ExtendedSprayer:onEndWorkAreaProcessing(dt, hasProcessed)
	local spec = self.spec_extendedSprayer
	local specSprayer = self.spec_sprayer

	if self.isServer and specSprayer.workAreaParameters.isActive then
		local sprayVehicle = specSprayer.workAreaParameters.sprayVehicle
		local usage = specSprayer.workAreaParameters.usage
		local fillType = specSprayer.workAreaParameters.sprayFillType

		if (sprayVehicle ~= nil or self:getIsAIActive()) and self:getIsTurnedOn() then
			local usageRegular = spec.lastRegularUsage
			local farmlandStatistics, _, farmlandId = self:getPFStatisticInfo()

			if farmlandStatistics ~= nil and farmlandId ~= nil then
				if fillType == FillType.LIME then
					farmlandStatistics:updateStatistic(farmlandId, "usedLime", usage)
					farmlandStatistics:updateStatistic(farmlandId, "usedLimeRegular", usageRegular)
				elseif fillType == FillType.FERTILIZER then
					farmlandStatistics:updateStatistic(farmlandId, "usedMineralFertilizer", usage)
					farmlandStatistics:updateStatistic(farmlandId, "usedMineralFertilizerRegular", usageRegular)
				elseif fillType == FillType.LIQUIDFERTILIZER then
					farmlandStatistics:updateStatistic(farmlandId, "usedLiquidFertilizer", usage)
					farmlandStatistics:updateStatistic(farmlandId, "usedLiquidFertilizerRegular", usageRegular)
				elseif fillType == FillType.MANURE then
					farmlandStatistics:updateStatistic(farmlandId, "usedManure", usage)
					farmlandStatistics:updateStatistic(farmlandId, "usedManureRegular", usageRegular)
				elseif fillType == FillType.LIQUIDMANURE or fillType == FillType.DIGESTATE then
					farmlandStatistics:updateStatistic(farmlandId, "usedLiquidManure", usage)
					farmlandStatistics:updateStatistic(farmlandId, "usedLiquidManureRegular", usageRegular)
				end
			end
		end
	end
end

function ExtendedSprayer:setSprayAmountAutoMode(state, noEventSend)
	local spec = self.spec_extendedSprayer

	if state == nil then
		state = not spec.sprayAmountAutoMode
	end

	if not spec.sprayAmountAutoModeChangeAllowed then
		state = false
	end

	spec.sprayAmountAutoMode = state

	ExtendedSprayer.updateActionEventState(self)
	ExtendedSprayer.updateActionEventAutoModeDefault(self)
	ExtendedSprayerAmountEvent.sendEvent(self, spec.sprayAmountAutoMode, spec.sprayAmountManual, noEventSend)
end

function ExtendedSprayer:setSprayAmountManualValue(value, noEventSend)
	local spec = self.spec_extendedSprayer
	spec.sprayAmountManual = MathUtil.clamp(value, spec.sprayAmountManualMin, spec.sprayAmountManualMax)

	ExtendedSprayer.updateActionEventState(self)
	ExtendedSprayerAmountEvent.sendEvent(self, spec.sprayAmountAutoMode, spec.sprayAmountManual, noEventSend)
end

function ExtendedSprayer:setSprayAmountAutoFruitTypeIndex(index)
	local spec = self.spec_extendedSprayer

	if index ~= spec.nApplyAutoModeFruitType then
		spec.nApplyAutoModeFruitType = index
		spec.nApplyAutoModeFruitTypeRequiresDefaultMode = spec.nitrogenMap:getFruitTypeRequirementRequiresDefaultMode(index)

		ExtendedSprayer.updateActionEventAutoModeDefault(self)
	end
end

function ExtendedSprayer:setSprayAmountDefaultFruitRequirementIndex(index, noEventSend)
	local spec = self.spec_extendedSprayer
	spec.nApplyAutoModeFruitRequirementDefaultIndex = index
	spec.lastGroundUpdateDistance = math.huge

	ExtendedSprayerDefaultFruitTypeEvent.sendEvent(self, index, noEventSend)
end
