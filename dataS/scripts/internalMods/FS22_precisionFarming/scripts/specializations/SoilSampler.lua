SoilSampler = {
	MOD_NAME = g_currentModName,
	SPEC_NAME = g_currentModName .. ".soilSampler",
	SEND_NUM_BITS = 9,
	SAMPLING_OCTAGON = {
		{
			0.33,
			0,
			-1,
			-0.33,
			0,
			-1,
			-0.33,
			0,
			-0.33
		},
		{
			1,
			0,
			0.33,
			1,
			0,
			-0.33,
			0.33,
			0,
			-0.33
		},
		{
			-0.33,
			0,
			1,
			0.33,
			0,
			1,
			0.33,
			0,
			0.33
		},
		{
			-1,
			0,
			-0.33,
			-1,
			0,
			0.33,
			-0.33,
			0,
			0.33
		},
		{
			-0.33,
			0,
			1,
			-0.33,
			0,
			-0.33,
			0.33,
			0,
			0.33
		},
		{
			1,
			0,
			0.33,
			-0.33,
			0,
			0.33,
			0.33,
			0,
			-0.33
		}
	},
	prerequisitesPresent = function (specializations)
		return SpecializationUtil.hasSpecialization(PrecisionFarmingStatistic, specializations)
	end
}

function SoilSampler.initSpecialization()
	local schema = Vehicle.xmlSchema

	schema:setXMLSpecializationType("SoilSampler")
	schema:register(XMLValueType.NODE_INDEX, "vehicle.soilSampler#node", "Sampling Node")
	schema:register(XMLValueType.FLOAT, "vehicle.soilSampler#radius", "Sampling radius", 10)
	schema:register(XMLValueType.STRING, "vehicle.soilSampler#actionNameTake", "Take sample input action name", "IMPLEMENT_EXTRA")
	schema:register(XMLValueType.STRING, "vehicle.soilSampler#actionNameSend", "Send sample input action name", "IMPLEMENT_EXTRA3")
	schema:register(XMLValueType.STRING, "vehicle.soilSampler#animationName", "Sampling animation name")
	schema:register(XMLValueType.FLOAT, "vehicle.soilSampler#animationSpeed", "Sampling animation speed", 1)
	schema:register(XMLValueType.FLOAT, "vehicle.soilSampler#foldMinLimit", "Fold min. limit", 0)
	schema:register(XMLValueType.FLOAT, "vehicle.soilSampler#foldMaxLimit", "Fold max. limit", 1)
	schema:register(XMLValueType.STRING, "vehicle.soilSampler.samplesAnimation#name", "Samples animation name")
	schema:register(XMLValueType.FLOAT, "vehicle.soilSampler.samplesAnimation#speed", "Samples animation speed", 1)
	schema:register(XMLValueType.INT, "vehicle.soilSampler.samplesAnimation#minSamples", "Min. samples", 0)
	schema:register(XMLValueType.INT, "vehicle.soilSampler.samplesAnimation#maxSamples", "Max. samples", 0)
	schema:register(XMLValueType.FLOAT, "vehicle.soilSampler.visualSamples#updateTime", "Update time", 0.5)
	schema:register(XMLValueType.NODE_INDEX, "vehicle.soilSampler.visualSamples.visualSample(?)#node", "Visual sample node")
	schema:setXMLSpecializationType()

	local schemaSavegame = Vehicle.xmlSchemaSavegame

	schemaSavegame:register(XMLValueType.INT, "vehicles.vehicle(?)." .. SoilSampler.SPEC_NAME .. "#numCollectedSamples", "Num collected samples")
end

function SoilSampler.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "startSoilSampling", SoilSampler.startSoilSampling)
	SpecializationUtil.registerFunction(vehicleType, "setNumCollectedSoilSamples", SoilSampler.setNumCollectedSoilSamples)
	SpecializationUtil.registerFunction(vehicleType, "getNormalizedSampleIndex", SoilSampler.getNormalizedSampleIndex)
	SpecializationUtil.registerFunction(vehicleType, "getCanStartSoilSampling", SoilSampler.getCanStartSoilSampling)
	SpecializationUtil.registerFunction(vehicleType, "processSoilSampling", SoilSampler.processSoilSampling)
	SpecializationUtil.registerFunction(vehicleType, "sendTakenSoilSamples", SoilSampler.sendTakenSoilSamples)
end

function SoilSampler.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "doCheckSpeedLimit", SoilSampler.doCheckSpeedLimit)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsFoldAllowed", SoilSampler.getIsFoldAllowed)
end

function SoilSampler.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", SoilSampler)
	SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", SoilSampler)
	SpecializationUtil.registerEventListener(vehicleType, "onReadStream", SoilSampler)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", SoilSampler)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", SoilSampler)
	SpecializationUtil.registerEventListener(vehicleType, "onFoldStateChanged", SoilSampler)
	SpecializationUtil.registerEventListener(vehicleType, "onLeaveRootVehicle", SoilSampler)
	SpecializationUtil.registerEventListener(vehicleType, "onPreDetach", SoilSampler)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", SoilSampler)
end

function SoilSampler:onLoad(savegame)
	self.spec_soilSampler = self["spec_" .. SoilSampler.SPEC_NAME]
	local spec = self.spec_soilSampler
	local baseName = "vehicle.soilSampler"
	spec.samplingNode = self.xmlFile:getValue(baseName .. "#node", nil, self.components, self.i3dMappings)
	spec.samplingRadius = self.xmlFile:getValue(baseName .. "#radius", 10)
	local actionNameTake = self.xmlFile:getValue(baseName .. "#actionNameTake", "IMPLEMENT_EXTRA")
	spec.inputActionTake = InputAction[actionNameTake] or InputAction.IMPLEMENT_EXTRA
	local actionNameSend = self.xmlFile:getValue(baseName .. "#actionNameSend", "IMPLEMENT_EXTRA3")
	spec.inputActionSend = InputAction[actionNameSend] or InputAction.IMPLEMENT_EXTRA
	spec.isSampling = false
	spec.animationName = self.xmlFile:getValue(baseName .. "#animationName")
	spec.animationSpeed = self.xmlFile:getValue(baseName .. "#animationSpeed", 1)
	spec.numCollectedSamples = 0
	spec.foldMinLimit = self.xmlFile:getValue(baseName .. "#foldMinLimit", 0)
	spec.foldMaxLimit = self.xmlFile:getValue(baseName .. "#foldMaxLimit", 1)
	spec.samplesAnimation = {
		name = self.xmlFile:getValue(baseName .. ".samplesAnimation#name"),
		speed = self.xmlFile:getValue(baseName .. ".samplesAnimation#speed", 1),
		minSamples = self.xmlFile:getValue(baseName .. ".samplesAnimation#minSamples", 0),
		maxSamples = self.xmlFile:getValue(baseName .. ".samplesAnimation#maxSamples", 0)
	}
	spec.visualSampleUpdateTime = self.xmlFile:getValue(baseName .. ".visualSamples#updateTime", 0.5)
	spec.visualSampleUpdated = true
	spec.visualSamples = {}
	local i = 0

	while true do
		local visualSampleKey = string.format("%s.visualSamples.visualSample(%d)", baseName, i)

		if not self.xmlFile:hasProperty(visualSampleKey) then
			break
		end

		local node = self.xmlFile:getValue(visualSampleKey .. "#node", nil, self.components, self.i3dMappings)

		if node ~= nil then
			setVisibility(node, false)
			table.insert(spec.visualSamples, node)
		end

		i = i + 1
	end

	spec.texts = {
		takeSample = g_i18n:getText("action_takeSoilSample", self.customEnvironment),
		sendSoilSamples = g_i18n:getText("action_sendSoilSamples", self.customEnvironment),
		numSamplesTaken = g_i18n:getText("info_numSamplesTaken", self.customEnvironment),
		infoSamplesSend = g_i18n:getText("info_samplesSend", self.customEnvironment)
	}

	if g_precisionFarming ~= nil then
		spec.soilMap = g_precisionFarming.soilMap
		spec.coverMap = g_precisionFarming.coverMap
		spec.farmlandStatistics = g_precisionFarming.farmlandStatistics
	end
end

function SoilSampler:onPostLoad(savegame)
	local spec = self.spec_soilSampler

	if savegame ~= nil and not savegame.resetVehicles then
		local numSamples = savegame.xmlFile:getValue(savegame.key .. "." .. SoilSampler.SPEC_NAME .. "#numCollectedSamples", spec.numCollectedSamples)

		self:setNumCollectedSoilSamples(numSamples, true)
	end
end

function SoilSampler:saveToXMLFile(xmlFile, key, usedModNames)
	local spec = self.spec_soilSampler

	xmlFile:setValue(key .. "#numCollectedSamples", spec.numCollectedSamples)
end

function SoilSampler:onReadStream(streamId, connection)
	local spec = self.spec_soilSampler
	local numSamples = streamReadUIntN(streamId, SoilSampler.SEND_NUM_BITS) or spec.numCollectedSamples

	self:setNumCollectedSoilSamples(numSamples, true)
end

function SoilSampler:onWriteStream(streamId, connection)
	local spec = self.spec_soilSampler

	streamWriteUIntN(streamId, spec.numCollectedSamples, SoilSampler.SEND_NUM_BITS)
end

function SoilSampler:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	local spec = self.spec_soilSampler

	if spec.isSampling then
		if self.isClient and not spec.visualSampleUpdated and spec.visualSampleUpdateTime <= self:getAnimationTime(spec.animationName) then
			local sampleIndex = self:getNormalizedSampleIndex()

			for i = 1, #spec.visualSamples do
				setVisibility(spec.visualSamples[i], i <= sampleIndex)
			end

			spec.visualSampleUpdated = false
		end

		if not self:getIsAnimationPlaying(spec.animationName) then
			spec.isSampling = false

			self:setAnimationTime(spec.animationName, 0, false)

			if spec.soilMap:getMinimapAdditionalElementLinkNode() == spec.samplingNode then
				spec.soilMap:setMinimapSamplingState(false)
			end

			self:processSoilSampling()

			self.speedLimit = math.huge
		end
	end

	if isActiveForInputIgnoreSelection and spec.numCollectedSamples > 0 then
		g_currentMission:addExtraPrintText(string.format(spec.texts.numSamplesTaken, spec.numCollectedSamples))
	end
end

function SoilSampler:onFoldStateChanged(direction, moveToMiddle)
	local spec = self.spec_soilSampler

	if self:getIsActiveForInput(true) then
		spec.soilMap:setRequireMinimapDisplay(direction == 1, self, self:getIsSelected())
	end
end

function SoilSampler:onLeaveRootVehicle()
	local spec = self.spec_soilSampler

	if spec.soilMap:getMinimapAdditionalElementLinkNode() == spec.samplingNode then
		spec.soilMap:setRequireMinimapDisplay(false, self)
		spec.soilMap:setMinimapAdditionalElementLinkNode(nil)
		spec.soilMap:setMinimapSamplingState(false)
	end
end

function SoilSampler:onPreDetach()
	local spec = self.spec_soilSampler

	if spec.soilMap:getMinimapAdditionalElementLinkNode() == spec.samplingNode then
		spec.soilMap:setRequireMinimapDisplay(false, self)
		spec.soilMap:setMinimapAdditionalElementLinkNode(nil)
		spec.soilMap:setMinimapSamplingState(false)
	end
end

function SoilSampler:startSoilSampling(noEventSend)
	local spec = self.spec_soilSampler
	spec.isSampling = true

	if self.isServer then
		if not self:getIsLowered(false) then
			local attacherVehicle = self:getAttacherVehicle()

			if attacherVehicle ~= nil then
				local jointDesc = attacherVehicle:getAttacherJointDescFromObject(self)

				if jointDesc.allowsLowering then
					local jointDescIndex = attacherVehicle:getAttacherJointIndexFromObject(self)

					attacherVehicle:setJointMoveDown(jointDescIndex, true, false)
				end
			end
		end

		local farmlandStatistics, isOnField, farmlandId = self:getPFStatisticInfo()

		if farmlandStatistics ~= nil and isOnField and farmlandId ~= nil then
			spec.farmlandStatistics:updateStatistic(farmlandId, "numSoilSamples", 1)
			spec.farmlandStatistics:updateStatistic(farmlandId, "soilSampleCosts", spec.soilMap:getPricePerSoilSample())
		end

		self.speedLimit = 0
	end

	self:playAnimation(spec.animationName, spec.animationSpeed, self:getAnimationTime(spec.animationName), true)
	self:setNumCollectedSoilSamples(spec.numCollectedSamples + 1, false)

	if self:getIsActiveForInput(true) then
		spec.soilMap:setMinimapSamplingState(true)
	end

	if self.isClient then
		if (spec.numCollectedSamples - 1) % #spec.visualSamples == 0 then
			for i = 1, #spec.visualSamples do
				setVisibility(spec.visualSamples[i], false)
			end

			self:playAnimation(spec.samplesAnimation.name, -spec.samplesAnimation.speed, self:getAnimationTime(spec.samplesAnimation.name), true)
		else
			local sampleIndex = self:getNormalizedSampleIndex()
			local stopTime = (sampleIndex - spec.samplesAnimation.minSamples) / (spec.samplesAnimation.maxSamples - spec.samplesAnimation.minSamples)

			if self:getAnimationTime(spec.samplesAnimation.name) < stopTime then
				self:setAnimationStopTime(spec.samplesAnimation.name, stopTime)
				self:playAnimation(spec.samplesAnimation.name, spec.samplesAnimation.speed, self:getAnimationTime(spec.samplesAnimation.name), true)
			end
		end

		spec.visualSampleUpdated = false
	end

	SoilSampler.updateActionEventState(self)
	SoilSamplerStartEvent.sendEvent(self, noEventSend)
end

function SoilSampler:setNumCollectedSoilSamples(num, updateVisuals)
	local spec = self.spec_soilSampler
	spec.numCollectedSamples = num or spec.numCollectedSamples + 1

	if updateVisuals then
		local sampleIndex = self:getNormalizedSampleIndex()

		for j = 1, #spec.visualSamples do
			setVisibility(spec.visualSamples[j], j <= sampleIndex)
		end

		local stopTime = (sampleIndex - spec.samplesAnimation.minSamples) / (spec.samplesAnimation.maxSamples - spec.samplesAnimation.minSamples)

		self:setAnimationTime(spec.samplesAnimation.name, stopTime, true)
	end
end

function SoilSampler:getNormalizedSampleIndex()
	local spec = self.spec_soilSampler
	local sampleIndex = spec.numCollectedSamples % #spec.visualSamples

	if spec.numCollectedSamples == 0 then
		return 0
	elseif sampleIndex == 0 then
		return #spec.visualSamples
	end

	return sampleIndex
end

function SoilSampler:getCanStartSoilSampling()
	local spec = self.spec_soilSampler
	local x, _, z = getWorldTranslation(spec.samplingNode)
	local farmlandId = g_farmlandManager:getFarmlandIdAtWorldPosition(x, z)

	if farmlandId == nil then
		return false, g_i18n:getText("warning_youDontHaveAccessToThisLand")
	end

	local landOwner = g_farmlandManager:getFarmlandOwner(farmlandId)
	local accessible = landOwner ~= 0 and g_currentMission.accessHandler:canFarmAccessOtherId(self:getActiveFarm(), landOwner)

	if not accessible then
		return false, g_i18n:getText("warning_youDontHaveAccessToThisLand")
	end

	if self.getIsMotorStarted ~= nil then
		if not self:getIsMotorStarted() then
			return false, g_i18n:getText("warning_motorNotStarted")
		end
	else
		local rootAttacherVehicle = self:getRootVehicle()

		if rootAttacherVehicle ~= self and rootAttacherVehicle.getIsMotorStarted ~= nil and not rootAttacherVehicle:getIsMotorStarted() then
			return false, g_i18n:getText("warning_motorNotStarted")
		end
	end

	if self.getFoldAnimTime ~= nil then
		local time = self:getFoldAnimTime()

		if spec.foldMaxLimit < time or time < spec.foldMinLimit then
			return false, self.spec_foldable.unfoldWarning
		end
	end

	return not self.spec_soilSampler.isSampling
end

function SoilSampler:processSoilSampling()
	if self.isServer then
		local spec = self.spec_soilSampler

		if spec.soilMap ~= nil then
			local length = spec.samplingRadius
			local octagon = SoilSampler.SAMPLING_OCTAGON

			for i = 1, #octagon do
				local position = octagon[i]
				local xs, _, zs = localToWorld(spec.samplingNode, position[1] * length, position[2] * length, position[3] * length)
				local xw, _, zw = localToWorld(spec.samplingNode, position[4] * length, position[5] * length, position[6] * length)
				local xh, _, zh = localToWorld(spec.samplingNode, position[7] * length, position[8] * length, position[9] * length)

				spec.coverMap:analyseArea(xs, zs, xw, zw, xh, zh, nil, self:getOwnerFarmId())
			end
		end
	end
end

function SoilSampler:sendTakenSoilSamples(noEventSend)
	local spec = self.spec_soilSampler

	if self.isServer and spec.soilMap ~= nil then
		spec.soilMap:analyseSoilSamples(self:getOwnerFarmId(), spec.numCollectedSamples)
	end

	if self.isClient then
		for i = 1, #spec.visualSamples do
			setVisibility(spec.visualSamples[i], false)
		end

		self:playAnimation(spec.samplesAnimation.name, -spec.samplesAnimation.speed, self:getAnimationTime(spec.samplesAnimation.name), true)
	end

	spec.numCollectedSamples = 0

	SoilSampler.updateActionEventState(self)
	SoilSamplerSendEvent.sendEvent(self, noEventSend)
end

function SoilSampler:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	if self.isClient then
		local spec = self.spec_soilSampler

		self:clearActionEventsTable(spec.actionEvents)

		if isActiveForInputIgnoreSelection then
			local _, actionEventId = self:addActionEvent(spec.actionEvents, spec.inputActionTake, self, SoilSampler.actionEventStartSample, false, true, false, true, nil)

			g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)
			g_inputBinding:setActionEventText(actionEventId, spec.texts.takeSample)

			_, actionEventId = self:addActionEvent(spec.actionEvents, spec.inputActionSend, self, SoilSampler.actionEventSendSamples, false, true, false, true, nil)

			g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)
			g_inputBinding:setActionEventText(actionEventId, spec.texts.sendSoilSamples)
			SoilSampler.updateActionEventState(self)
			spec.soilMap:setRequireMinimapDisplay(self:getFoldAnimTime() > 0, self, self:getIsSelected())
			spec.soilMap:setMinimapAdditionalElementLinkNode(spec.samplingNode)
			spec.soilMap:setMinimapAdditionalElementRealSize(spec.samplingRadius * 2, spec.samplingRadius * 2)
		end
	end
end

function SoilSampler:updateActionEventState()
	local spec = self.spec_soilSampler
	local actionEventSend = spec.actionEvents[spec.inputActionSend]

	if actionEventSend ~= nil then
		g_inputBinding:setActionEventActive(actionEventSend.actionEventId, spec.numCollectedSamples > 0)
	end
end

function SoilSampler:actionEventStartSample(actionName, inputValue, callbackState, isAnalog)
	local canStart, warning = self:getCanStartSoilSampling()

	if canStart then
		self:startSoilSampling()
	elseif warning ~= nil then
		g_currentMission:showBlinkingWarning(warning, 2000)
	end
end

function SoilSampler:actionEventSendSamples(actionName, inputValue, callbackState, isAnalog)
	local spec = self.spec_soilSampler

	if spec.numCollectedSamples > 0 and not self.spec_soilSampler.isSampling then
		g_gui:showInfoDialog({
			text = spec.texts.infoSamplesSend,
			callback = SoilSampler.onSendSoilSamplesDialog,
			target = self
		})
	end
end

function SoilSampler:onSendSoilSamplesDialog()
	local spec = self.spec_soilSampler

	if spec.soilMap ~= nil then
		spec.soilMap:sendSoilSamplesByFarm(self:getOwnerFarmId())
	end
end

function SoilSampler:doCheckSpeedLimit(superFunc)
	return superFunc(self) or self.spec_soilSampler.isSampling
end

function SoilSampler:getIsFoldAllowed(superFunc, direction, onAiTurnOn)
	return not self.spec_soilSampler.isSampling and superFunc(self, direction, onAiTurnOn)
end
