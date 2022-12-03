ToolCarrier = {
	MOD_DIRECTORY = g_currentModDirectory,
	MOD_NAME = g_currentModName,
	MODE_START = 1,
	MODE_STOP = 2,
	MODE_TRANSPORT = 3,
	initSpecialization = function ()
		local schema = Vehicle.xmlSchema

		schema:setXMLSpecializationType("ToolCarrier")
		schema:register(XMLValueType.NODE_INDEX, "vehicle.toolCarrier.arm.parts.part(?)#node", "The node of the arm")
		schema:register(XMLValueType.NODE_INDEX, "vehicle.toolCarrier.arm.parts.part(?)#refNode", "The ref node of the arm")
		schema:register(XMLValueType.NODE_INDEX, "vehicle.toolCarrier.arm.parts.part(?)#targetNode", "The target node of the arm")
		schema:register(XMLValueType.ANGLE, "vehicle.toolCarrier.arm.parts.part(?)#rotLimit", "The limit")
		schema:register(XMLValueType.FLOAT, "vehicle.toolCarrier.arm.parts.part(?)#transLimit", "The limit")
		schema:register(XMLValueType.FLOAT, "vehicle.toolCarrier.arm.parts.part(?)#offset", "The offset")
		schema:register(XMLValueType.FLOAT, "vehicle.toolCarrier.arm.parts.part(?)#movementSpeed", "The movementSpeed")
		schema:register(XMLValueType.FLOAT, "vehicle.toolCarrier.arm.parts.part(?)#resetDuration", "The resetDuration")
		schema:register(XMLValueType.INT, "vehicle.toolCarrier.arm.parts.part(?)#axis", "The axis")
		schema:register(XMLValueType.INT, "vehicle.toolCarrier.arm.parts.part(?)#dependentIndex", "The depending arm index")
		schema:register(XMLValueType.BOOL, "vehicle.toolCarrier.arm.parts.part(?)#isLockable", "If lockable")
		schema:register(XMLValueType.BOOL, "vehicle.toolCarrier.arm.parts.part(?)#isInverted", "If node behaviour is inverted")
		schema:register(XMLValueType.STRING, "vehicle.toolCarrier.arm.parts.part(?)#functionName", "Function name")
		schema:register(XMLValueType.STRING, "vehicle.toolCarrier#animationName", "Lift animation name")
		schema:register(XMLValueType.STRING, "vehicle.toolCarrier#lockAnimationName", "Lock animation name")
		schema:register(XMLValueType.FLOAT, "vehicle.toolCarrier#unlockThreshold", "The unlock threshold")
		schema:register(XMLValueType.FLOAT, "vehicle.toolCarrier#lockSpeed", "The speed to lock")
		schema:register(XMLValueType.FLOAT, "vehicle.toolCarrier#unlockSpeed", "The speed to unlock")
		schema:register(XMLValueType.FLOAT, "vehicle.toolCarrier#higherThreshold", "The higher threshold")
		schema:register(XMLValueType.FLOAT, "vehicle.toolCarrier#lowerThreshold", "The lowering threshold")
		schema:register(XMLValueType.FLOAT, "vehicle.toolCarrier#transportAnimationTime", "The animation time for transport")
		schema:register(XMLValueType.BOOL, "vehicle.toolCarrier#isCarrier", "Is a carrier")
		schema:setXMLSpecializationType()

		local schemaSavegame = Vehicle.xmlSchemaSavegame
		local modName = g_manureModName

		schemaSavegame:register(XMLValueType.FLOAT, ("vehicles.vehicle(?).%s.toolCarrier#headlandMode"):format(modName), "The headland mode of the tool carrier")
	end,
	prerequisitesPresent = function (specializations)
		return SpecializationUtil.hasSpecialization(UmbilicalHoseConnector, specializations)
	end
}

function ToolCarrier.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "loadArmPartFromXML", ToolCarrier.loadArmPartFromXML)
	SpecializationUtil.registerFunction(vehicleType, "canUseArm", ToolCarrier.canUseArm)
	SpecializationUtil.registerFunction(vehicleType, "canOperate", ToolCarrier.canOperate)
	SpecializationUtil.registerFunction(vehicleType, "canSwitchHeadlandState", ToolCarrier.canSwitchHeadlandState)
	SpecializationUtil.registerFunction(vehicleType, "setHeadlandState", ToolCarrier.setHeadlandState)
	SpecializationUtil.registerFunction(vehicleType, "partRotateToTarget", ToolCarrier.partRotateToTarget)
	SpecializationUtil.registerFunction(vehicleType, "partTranslateToTarget", ToolCarrier.partTranslateToTarget)
end

function ToolCarrier.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", ToolCarrier)
	SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", ToolCarrier)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", ToolCarrier)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", ToolCarrier)
	SpecializationUtil.registerEventListener(vehicleType, "onAttachUmbilicalHose", ToolCarrier)
	SpecializationUtil.registerEventListener(vehicleType, "onDetachUmbilicalHose", ToolCarrier)
	SpecializationUtil.registerEventListener(vehicleType, "onFoldTimeChanged", ToolCarrier)
end

function ToolCarrier:onLoad()
	self.spec_toolCarrier = self[("spec_%s.toolCarrier"):format(ToolCarrier.MOD_NAME)]
	local spec = self.spec_toolCarrier
	spec.parts = {}

	self.xmlFile:iterate("vehicle.toolCarrier.arm.parts.part", function (_, key)
		local part = {}

		if self:loadArmPartFromXML(self.xmlFile, key, part) then
			table.insert(spec.parts, part)
		end
	end)

	spec.connectorIndex = 1
	spec.animationName = self.xmlFile:getValue("vehicle.toolCarrier#animationName")
	spec.lockAnimationName = self.xmlFile:getValue("vehicle.toolCarrier#lockAnimationName")
	spec.animationLowerSpeed = 0.1
	spec.animationHigherSpeed = 1
	spec.unlockThreshold = self.xmlFile:getValue("vehicle.toolCarrier#unlockThreshold", 0.5)
	spec.higherThreshold = self.xmlFile:getValue("vehicle.toolCarrier#higherThreshold", 0.05)
	spec.lowerThreshold = self.xmlFile:getValue("vehicle.toolCarrier#lowerThreshold", 0.25)
	spec.unlockState = 0
	spec.unlockSpeed = self.xmlFile:getValue("vehicle.toolCarrier#unlockSpeed", 0.4)
	spec.lockSpeed = self.xmlFile:getValue("vehicle.toolCarrier#lockSpeed", 0.8)
	spec.isCarrier = self.xmlFile:getValue("vehicle.toolCarrier#isCarrier", true)
	spec.transportAnimationTime = self.xmlFile:getValue("vehicle.toolCarrier#transportAnimationTime", 0.5)
	spec.isUnlocked = false
	spec.headlandMode = ToolCarrier.MODE_TRANSPORT
	spec.floatingRotThreshold = math.rad(45)
	spec.resetState = 0
	spec.performReset = false
end

function ToolCarrier:onPostLoad(savegame)
	local spec = self.spec_toolCarrier

	if savegame ~= nil and not savegame.resetVehicles then
		local key = ("%s.%s.toolCarrier"):format(savegame.key, self:manure_getModName())
		local headlandMode = savegame.xmlFile:getValue(key .. "#headlandMode", spec.headlandMode)

		self:setHeadlandState(headlandMode, true, true)
	end
end

function ToolCarrier:saveToXMLFile(xmlFile, key, usedModNames)
	local spec = self.spec_toolCarrier

	xmlFile:setValue(key .. "#headlandMode", spec.headlandMode)
end

function ToolCarrier:loadArmPartFromXML(xmlFile, baseKey, part)
	part.node = xmlFile:getValue(baseKey .. "#node", nil, self.components, self.i3dMappings)

	if part.node == nil then
		log("Error: failed to load arm node!")

		return false
	end

	part.refNode = xmlFile:getValue(baseKey .. "#refNode", nil, self.components, self.i3dMappings)

	if part.refNode == nil then
		part.refNode = part.node
	end

	part.targetNode = xmlFile:getValue(baseKey .. "#targetNode", nil, self.components, self.i3dMappings)
	part.axis = xmlFile:getValue(baseKey .. "#axis", 1)

	if part.axis > 3 then
		log("Error: axis can only be of value 1, 2 or 3!")

		return false
	end

	part.rotLimit = xmlFile:getValue(baseKey .. "#rotLimit")
	part.transLimit = xmlFile:getValue(baseKey .. "#transLimit")
	part.isInverted = xmlFile:getValue(baseKey .. "#isInverted", false)
	part.dependentIndex = xmlFile:getValue(baseKey .. "#dependentIndex")
	part.translation = {
		getTranslation(part.node)
	}
	part.rotation = {
		getRotation(part.node)
	}
	part.alpha = 0
	part.resetDuration = xmlFile:getValue(baseKey .. "#resetDuration", 20000)
	part.isLockable = xmlFile:getValue(baseKey .. "#isLockable", false)
	local orgTranslation = {
		getTranslation(part.node)
	}
	local orgRotation = {
		getRotation(part.node)
	}
	part.orgTranslation = orgTranslation
	part.orgRotation = orgRotation
	part.offset = xmlFile:getValue(baseKey .. "#offset", 0)
	part.movementSpeed = xmlFile:getValue(baseKey .. "#movementSpeed", 1) * 0.001
	part.functionName = xmlFile:getValue(baseKey .. "#functionName", "partRotateToTarget")

	if self[part.functionName] == nil then
		log("Error: function not found for arm!")

		return false
	end

	part.updateFunction = self[part.functionName]

	return true
end

function ToolCarrier:canUseArm()
	local spec = self.spec_toolCarrier

	return self:hasUmbilicalHose() and self:getIsUnfolded() and spec.headlandMode ~= ToolCarrier.MODE_TRANSPORT
end

function ToolCarrier:canOperate(excludeSelf)
	excludeSelf = excludeSelf or false

	if not excludeSelf and not self:getIsUnfolded() then
		return false
	end

	if self.getAttachedImplements ~= nil then
		for _, implement in pairs(self:getAttachedImplements()) do
			if not implement.object:getIsUnfolded() then
				return false
			end
		end
	end

	return true
end

function ToolCarrier:canSwitchHeadlandState()
	local spec = self.spec_toolCarrier

	return spec.animationName ~= nil and spec.lockAnimationName ~= nil
end

function ToolCarrier:setHeadlandState(state, force, noEventSend)
	force = force or false
	local spec = self.spec_toolCarrier

	if spec.headlandMode ~= state or force then
		ToolCarrierStateEvent.sendEvent(self, state, force, noEventSend)

		spec.headlandMode = state
		local isTransport = spec.headlandMode == ToolCarrier.MODE_TRANSPORT
		local animationTime = self:getAnimationTime(spec.animationName)
		local isStartMode = spec.headlandMode == ToolCarrier.MODE_START
		local direction = math.booltodirection(not isStartMode)
		local speed = isStartMode and spec.animationHigherSpeed or spec.animationLowerSpeed
		local stopTime = 1

		if isStartMode then
			stopTime = 0
		elseif isTransport then
			stopTime = spec.transportAnimationTime
			direction = math.booltodirection(spec.transportAnimationTime > animationTime)
		end

		self:setAnimationStopTime(spec.animationName, stopTime)
		self:setAnimationStopTime(spec.lockAnimationName, stopTime)
		self:setAnimationSpeed(spec.animationName, speed)
		self:setAnimationSpeed(spec.lockAnimationName, speed)
		self:playAnimation(spec.animationName, direction, animationTime, true)
		self:playAnimation(spec.lockAnimationName, direction, self:getAnimationTime(spec.lockAnimationName), true)

		local actionEvent = spec.actionEvents[InputAction.PM_TOGGLE_TOOLCARRIER_STATE]

		if actionEvent ~= nil and not isTransport then
			g_inputBinding:setActionEventText(actionEvent.actionEventId, g_i18n:getText(("action_toolCarrier_headlandState_%s"):format(spec.headlandMode)))
		end
	end
end

function ToolCarrier:handleLowering(doLowering)
	local spec = self.spec_toolCarrier
	local attachedImplements = self:getAttachedImplements()

	local function setLoweredState(attacherObject, attachedObject, jointDescIndex)
		if attachedObject.getToggledFoldMiddleDirection ~= nil then
			attacherObject:setJointMoveDown(jointDescIndex, doLowering)

			local direction = math.booltodirection(not doLowering)

			attachedObject:setFoldState(direction, not doLowering)
		else
			attacherObject:handleLowerImplementByAttacherJointIndex(jointDescIndex, doLowering)
		end
	end

	if #attachedImplements > 0 then
		for _, implement in ipairs(attachedImplements) do
			local object = implement.object
			local jointDescIndex = self:getAttacherJointIndexFromObject(object)

			setLoweredState(self, object, jointDescIndex)
		end
	elseif not spec.isCarrier then
		local attacherVehicle = self:getAttacherVehicle()

		if attacherVehicle ~= nil then
			local jointDescIndex = attacherVehicle:getAttacherJointIndexFromObject(self)

			setLoweredState(attacherVehicle, self, jointDescIndex)
		end
	end
end

function ToolCarrier:onUpdate(dt)
	local spec = self.spec_toolCarrier
	local onHeadland = spec.headlandMode == ToolCarrier.MODE_STOP

	if self.isServer and spec.lastHeadlandMode ~= spec.headlandMode and self:canOperate(true) then
		local performLowering = not onHeadland
		local stateLower = self:getAnimationTime(spec.animationName)
		local doLowering = not onHeadland and stateLower <= spec.lowerThreshold
		local doHigher = onHeadland and spec.higherThreshold <= stateLower

		if spec.headlandMode == ToolCarrier.MODE_TRANSPORT then
			doHigher = true
			performLowering = false
		end

		if doLowering or doHigher then
			ToolCarrier.handleLowering(self, performLowering)

			spec.lastHeadlandMode = spec.headlandMode
		end
	end

	local stateLock = self:getAnimationTime(spec.lockAnimationName)
	spec.isUnlocked = spec.unlockThreshold <= stateLock or not onHeadland

	if spec.isUnlocked then
		local speed = onHeadland and spec.unlockSpeed or spec.lockSpeed
		local dir = math.booltodirection(onHeadland)
		local dtToUse = dt * 0.001 * speed * dir
		spec.unlockState = math.clamp(spec.unlockState + dtToUse, 0, 1)
	end

	if self:canUseArm() then
		local hose = self:getUmbilicalHose(spec.connectorIndex)

		for _, part in ipairs(spec.parts) do
			part.updateFunction(self, part, hose, spec.unlockState, dt)
		end
	elseif spec.performReset then
		local donePerformingReset = true
		spec.resetState = math.clamp(spec.resetState - dt * 0.001, 0, 1)

		for _, part in ipairs(spec.parts) do
			local targetRotation = Vector3(part.orgRotation):lerp(Vector3(part.rotation), spec.resetState)
			local targetTranslation = Vector3(part.orgTranslation)

			targetRotation:applyRotationToNode(part.node)
			targetTranslation:applyTranslationToNode(part.node)

			local isNotBackToOriginal = targetRotation:magnitudeSquared() ~= 0

			if isNotBackToOriginal then
				donePerformingReset = false
			end
		end

		if donePerformingReset then
			spec.performReset = false
		end
	end
end

function ToolCarrier:partRotateToTarget(part, hose, state, dt)
	local spec = self.spec_toolCarrier

	if part.rotLimit == nil then
		return
	end

	local limit = part.rotLimit

	if part.isLockable then
		limit = limit * state
	end

	local targetNode = part.node

	if hose ~= nil then
		local point = self:getUmbilicalHoseConnectPoint(spec.connectorIndex, true)
		targetNode = point.node
	end

	if part.targetNode ~= nil then
		targetNode = part.targetNode
	end

	local differenceVector = Vector3.translationFromTwoWorldNodes(targetNode, part.refNode)
	local differencePos = differenceVector:getPositionTable()
	differencePos[part.axis] = differencePos[part.axis] + part.offset
	local targetVector = Vector3(worldDirectionToLocal(getParent(part.node), differencePos[1], differencePos[2], differencePos[3]))
	local targetRotation = 0

	if part.axis == 1 then
		targetRotation = targetVector:angleX()
	else
		targetRotation = targetVector:angleY()
	end

	local normalizedVector = math.clamp(MathUtil.normalizeRotationForShortestPath(targetRotation + math.pi, part.rotation[part.axis]), -limit, limit)

	if part.isInverted then
		normalizedVector = -normalizedVector
	end

	part.rotation[part.axis] = normalizedVector

	setRotation(part.node, part.rotation[1], part.rotation[2], part.rotation[3])
end

function ToolCarrier:partTranslateToTarget(part, hose, state, dt)
	local spec = self.spec_toolCarrier

	if part.transLimit == nil then
		return
	end

	local limit = part.transLimit

	if part.isLockable then
		limit = limit * state
	end

	local canUpdate = not part.isLockable or part.isLockable and spec.isUnlocked

	if canUpdate then
		local dependingPart = part

		if part.dependentIndex ~= nil then
			dependingPart = spec.parts[part.dependentIndex]
		end

		canUpdate = spec.floatingRotThreshold <= math.abs(dependingPart.rotation[dependingPart.axis])
	end

	local lockInPlace = part.isLockable and spec.headlandMode == ToolCarrier.MODE_START

	if lockInPlace then
		canUpdate = true
	end

	if canUpdate then
		local targetNode = part.node

		if hose ~= nil then
			local point = self:getUmbilicalHoseConnectPoint(spec.connectorIndex, true)
			targetNode = point.node
		end

		if part.targetNode ~= nil then
			targetNode = part.targetNode
		end

		local differenceVector3 = Vector3.translationFromTwoWorldNodes(targetNode, part.refNode)
		local length = math.abs(differenceVector3:magnitude())
		local targetVector = math.clamp(length, 0, limit)
		local targetAlpha = 1

		if limit ~= 0 then
			targetAlpha = part.translation[part.axis] / part.transLimit
		else
			targetAlpha = 0
		end

		local resetDuration = lockInPlace and part.resetDuration * 2 or part.resetDuration

		if part.alpha < targetAlpha then
			part.alpha = math.min(part.alpha + dt / resetDuration, 1)
		else
			part.alpha = math.max(part.alpha - dt / resetDuration, 0)
		end

		targetVector = MathUtil.lerp(part.translation[part.axis], part.transLimit - targetVector, part.alpha)
		part.translation[part.axis] = targetVector

		setTranslation(part.node, part.translation[1], part.translation[2], part.translation[3])
	end
end

function ToolCarrier:onAttachUmbilicalHose(umbilicalHose)
	for _, implement in pairs(self:getAttachedImplements()) do
		if implement.object.attachUmbilicalHoseSource ~= nil then
			implement.object:attachUmbilicalHoseSource(self, umbilicalHose)
		end
	end
end

function ToolCarrier:onDetachUmbilicalHose(umbilicalHose, connectorId)
	local spec = self.spec_toolCarrier

	self:setHeadlandState(ToolCarrier.MODE_STOP)

	spec.performReset = true
	spec.resetState = 1

	for _, implement in pairs(self:getAttachedImplements()) do
		if implement.object.detachUmbilicalHoseSource ~= nil then
			implement.object:detachUmbilicalHoseSource(self, umbilicalHose)
		end
	end
end

function ToolCarrier:onFoldTimeChanged(foldAnimTime)
	if foldAnimTime == 1 then
		self:setHeadlandState(ToolCarrier.MODE_TRANSPORT)
	elseif foldAnimTime == 0 or foldAnimTime == self.spec_foldable.foldMiddleAnimTime then
		self:setHeadlandState(ToolCarrier.MODE_STOP)
	end
end

function ToolCarrier:actionEventHeadlandState(...)
	local spec = self.spec_toolCarrier

	if self:canSwitchHeadlandState() then
		if not self:canOperate() then
			g_currentMission:showBlinkingWarning(g_i18n:getText("info_putInWorkingPosition"), 1000)

			return
		end

		local nextState = ToolCarrier.MODE_START

		if spec.headlandMode == nextState then
			nextState = ToolCarrier.MODE_STOP
		end

		self:setHeadlandState(nextState)
	end
end

function ToolCarrier:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	if self.isClient then
		local spec = self.spec_toolCarrier

		self:clearActionEventsTable(spec.actionEvents)

		if isActiveForInput and self:canSwitchHeadlandState() then
			local _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.PM_TOGGLE_TOOLCARRIER_STATE, self, ToolCarrier.actionEventHeadlandState, false, true, false, true, nil, , true)
			local state = spec.headlandMode

			if state == ToolCarrier.MODE_TRANSPORT then
				state = ToolCarrier.MODE_STOP
			end

			g_inputBinding:setActionEventText(actionEventId, g_i18n:getText(("action_toolCarrier_headlandState_%s"):format(state)))
			g_inputBinding:setActionEventTextVisibility(actionEventId, true)
			g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)
		end
	end
end
