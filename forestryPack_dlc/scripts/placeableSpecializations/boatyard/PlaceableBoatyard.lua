local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

PlaceableBoatyard = {
	MOD_NAME = g_currentModName,
	SPEC_NAME = g_currentModName .. ".boatyard"
}
PlaceableBoatyard.SPEC = "spec_" .. PlaceableBoatyard.SPEC_NAME

function PlaceableBoatyard.prerequisitesPresent(specializations)
	return true
end

function PlaceableBoatyard.registerFunctions(placeableType)
	SpecializationUtil.registerFunction(placeableType, "onBoatI3DFileLoaded", PlaceableBoatyard.onBoatI3DFileLoaded)
	SpecializationUtil.registerFunction(placeableType, "setMeshProgress", PlaceableBoatyard.setMeshProgress)
	SpecializationUtil.registerFunction(placeableType, "setState", PlaceableBoatyard.setState)
	SpecializationUtil.registerFunction(placeableType, "setSplineTime", PlaceableBoatyard.setSplineTime)
	SpecializationUtil.registerFunction(placeableType, "addSplineDistanceDelta", PlaceableBoatyard.addSplineDistanceDelta)
	SpecializationUtil.registerFunction(placeableType, "getSplineTime", PlaceableBoatyard.getSplineTime)
	SpecializationUtil.registerFunction(placeableType, "releaseBoat", PlaceableBoatyard.releaseBoat)
	SpecializationUtil.registerFunction(placeableType, "createBoat", PlaceableBoatyard.createBoat)
	SpecializationUtil.registerFunction(placeableType, "setWindValues", PlaceableBoatyard.setWindValues)
	SpecializationUtil.registerFunction(placeableType, "getFillLevel", PlaceableBoatyard.getFillLevel)
	SpecializationUtil.registerFunction(placeableType, "removeFillLevel", PlaceableBoatyard.removeFillLevel)
	SpecializationUtil.registerFunction(placeableType, "playerTriggerCallback", PlaceableBoatyard.playerTriggerCallback)
	SpecializationUtil.registerFunction(placeableType, "buyRequest", PlaceableBoatyard.buyRequest)
end

function PlaceableBoatyard.registerOverwrittenFunctions(placeableType)
	SpecializationUtil.registerOverwrittenFunction(placeableType, "collectPickObjects", PlaceableBoatyard.collectPickObjects)
	SpecializationUtil.registerOverwrittenFunction(placeableType, "updateInfo", PlaceableBoatyard.updateInfo)
	SpecializationUtil.registerOverwrittenFunction(placeableType, "setOwnerFarmId", PlaceableBoatyard.setOwnerFarmId)
end

function PlaceableBoatyard.registerEventListeners(placeableType)
	SpecializationUtil.registerEventListener(placeableType, "onLoad", PlaceableBoatyard)
	SpecializationUtil.registerEventListener(placeableType, "onDelete", PlaceableBoatyard)
	SpecializationUtil.registerEventListener(placeableType, "onUpdate", PlaceableBoatyard)
	SpecializationUtil.registerEventListener(placeableType, "onReadStream", PlaceableBoatyard)
	SpecializationUtil.registerEventListener(placeableType, "onWriteStream", PlaceableBoatyard)
	SpecializationUtil.registerEventListener(placeableType, "onReadUpdateStream", PlaceableBoatyard)
	SpecializationUtil.registerEventListener(placeableType, "onWriteUpdateStream", PlaceableBoatyard)
end

function PlaceableBoatyard.registerXMLPaths(schema, basePath)
	schema:setXMLSpecializationType("Boatyard")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".boatyard#spline", "")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".boatyard#linkNode", "")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".boatyard#playerTrigger", "")
	schema:register(XMLValueType.STRING, basePath .. ".boatyard.boat#filename", "")
	schema:register(XMLValueType.INT, basePath .. ".boatyard.boat#reward", "")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".boatyard.boat.progressiveVisibilityMesh.mesh(?)#node", "")
	schema:register(XMLValueType.STRING, basePath .. ".boatyard.boat.progressiveVisibilityMesh.mesh(?)#id", "")
	schema:register(XMLValueType.INT, basePath .. ".boatyard.boat.progressiveVisibilityMesh.mesh(?)#indexMin", "")
	schema:register(XMLValueType.INT, basePath .. ".boatyard.boat.progressiveVisibilityMesh.mesh(?)#indexMax", "")
	schema:register(XMLValueType.STRING, basePath .. ".boatyard.stateMachine.states.state(?)#name", "State name")
	schema:register(XMLValueType.STRING, basePath .. ".boatyard.stateMachine.states.state(?)#class", "State class")
	BoatyardState.registerXMLPaths(schema, basePath .. ".boatyard.stateMachine.states.state(?)")
	BoatyardStateMoving.registerXMLPaths(schema, basePath .. ".boatyard.stateMachine.states.state(?)")
	BoatyardStateBuilding.registerXMLPaths(schema, basePath .. ".boatyard.stateMachine.states.state(?)")
	BoatyardStateLaunching.registerXMLPaths(schema, basePath .. ".boatyard.stateMachine.states.state(?)")
	schema:register(XMLValueType.STRING, basePath .. ".boatyard.stateMachine.transitions.transition(?)#from", "State name from")
	schema:register(XMLValueType.STRING, basePath .. ".boatyard.stateMachine.transitions.transition(?)#to", "State name to")
	schema:register(XMLValueType.FLOAT, basePath .. ".boatyard.sailingSplines#bobbingFreq", "")
	schema:register(XMLValueType.FLOAT, basePath .. ".boatyard.sailingSplines#bobbingAmount", "")
	schema:register(XMLValueType.FLOAT, basePath .. ".boatyard.sailingSplines#swayingFreq", "")
	schema:register(XMLValueType.FLOAT, basePath .. ".boatyard.sailingSplines#swayingAmount", "")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".boatyard.sailingSplines.spline(?)#node", "")
	SellingStation.registerXMLPaths(schema, basePath .. ".boatyard.sellingStation")
	Storage.registerXMLPaths(schema, basePath .. ".boatyard.storage")
	schema:setXMLSpecializationType()
end

function PlaceableBoatyard.registerSavegameXMLPaths(schema, basePath)
	schema:register(XMLValueType.INT, basePath .. ".state#index", "")
	schema:register(XMLValueType.FLOAT, basePath .. "#splineTime", "")
	BoatyardStateBuilding.registerSavegameXMLPaths(schema, basePath)
	Storage.registerSavegameXMLPaths(schema, basePath .. ".storage")
end

function PlaceableBoatyard:onLoad(savegame)
	local spec = self[PlaceableBoatyard.SPEC]
	local key = "placeable.boatyard"
	spec.spline = self.xmlFile:getValue(key .. "#spline", nil, self.components, self.i3dMappings)
	spec.splineLength = getSplineLength(spec.spline)
	spec.splineTime = 0
	spec.splineTimeInterpolator = InterpolationTime.new(1.2)
	spec.splineInterpolator = InterpolatorValue.new(0)
	spec.splineTimeDirtyFlag = self:getNextDirtyFlag()
	spec.splineTimeChanged = false
	spec.boatLinkNode = self.xmlFile:getValue(key .. "#linkNode", nil, self.components, self.i3dMappings)

	link(getRootNode(), spec.boatLinkNode)

	local boatI3DFilename = self.xmlFile:getValue(key .. ".boat#filename")
	boatI3DFilename = Utils.getFilename(boatI3DFilename, self.baseDirectory)
	spec.boatLaunchReward = self.xmlFile:getValue(key .. ".boat#reward", 100000)
	spec.idToMesh = {}
	spec.meshes = {}
	local arguments = {
		loadingTask = self:createLoadingTask(spec)
	}
	spec.sharedLoadRequestId = g_i3DManager:loadSharedI3DFileAsync(boatI3DFilename, true, false, self.onBoatI3DFileLoaded, self, arguments)
	spec.unloadingStation = SellingStation.new(self.isServer, self.isClient)

	spec.unloadingStation:load(self.components, self.xmlFile, key .. ".sellingStation", self.customEnvironment, self.i3dMappings, self.components[1].node)

	spec.unloadingStation.storeSoldGoods = true
	spec.unloadingStation.owningPlaceable = self
	spec.unloadingStation.skipSell = self:getOwnerFarmId() ~= AccessHandler.EVERYONE

	function spec.unloadingStation.getIsFillAllowedFromFarm(_, farmId)
		return true
	end

	spec.unloadingStation:register(true)

	spec.storage = Storage.new(self.isServer, self.isClient)

	spec.storage:load(self.components, self.xmlFile, key .. ".storage", self.i3dMappings)
	spec.storage:register(true)
	spec.storage:addFillLevelChangedListeners(function ()
		self:raiseActive()
	end)

	spec.fillTypesAndLevelsAuxiliary = {}
	spec.fillTypeToFillTypeStorageTable = {}
	spec.infoTriggerFillTypesAndLevels = {}
	spec.infoTableEntryStorage = {
		accentuate = true,
		title = g_i18n:getText("statistic_storage")
	}

	spec.unloadingStation:addTargetStorage(spec.storage)

	spec.playerTrigger = self.xmlFile:getValue(key .. "#playerTrigger", nil, self.components, self.i3dMappings)

	if spec.playerTrigger ~= nil then
		addTrigger(spec.playerTrigger, "playerTriggerCallback", self)
	end

	spec.activatable = BoatyardActivatable.new(self)
	spec.stateMachine = {}
	spec.stateNameToIndex = {}
	spec.stateTransitions = {}
	spec.stateIndex = -1
	spec.stateMachineNextIndex = 0
	spec.statesDirtyMask = 0
	local maxNumStates = 255
	local stateMachineXmlKey = "placeable.boatyard.stateMachine"

	self.xmlFile:iterate(stateMachineXmlKey .. ".states.state", function (_, stateKey)
		if maxNumStates < spec.stateMachineNextIndex then
			Logging.xmlWarning(self.xmlFile, "Maximum number of states reached (%d)", maxNumStates)

			return
		end

		local stateName = self.xmlFile:getValue(stateKey .. "#name", ""):upper()

		if spec.stateNameToIndex[stateName] ~= nil then
			Logging.xmlError(self.xmlFile, "State '%s' already defined", stateName, stateKey)

			return
		end

		local stateClassName = self.xmlFile:getValue(stateKey .. "#class", "")
		local class = ClassUtil.getClassObject(PlaceableBoatyard.MOD_NAME .. "." .. stateClassName)

		if class == nil then
			Logging.xmlError(self.xmlFile, "State class '%s' at '%s' not defined", stateClassName, stateKey)

			return
		end

		local stateIndex = spec.stateMachineNextIndex
		spec.stateNameToIndex[stateName] = stateIndex
		local state = class.new(self)

		state:load(self.xmlFile, stateKey)

		spec.stateMachine[stateIndex] = state
		spec.statesDirtyMask = spec.statesDirtyMask + state.dirtyFlag
		spec.stateMachineNextIndex = spec.stateMachineNextIndex + 1
	end)
	self.xmlFile:iterate(stateMachineXmlKey .. ".transitions.transition", function (_, transitionKey)
		local stateFromName = self.xmlFile:getValue(transitionKey .. "#from", ""):upper()
		local stateFromIndex = spec.stateNameToIndex[stateFromName]

		if stateFromIndex == nil then
			Logging.xmlError(self.xmlFile, "Invalid state. Transition from name '%s' not defined for '%s'", stateFromName, transitionKey)

			return
		end

		local stateToName = self.xmlFile:getValue(transitionKey .. "#to", ""):upper()
		local stateToIndex = spec.stateNameToIndex[stateToName]

		if stateToIndex == nil then
			Logging.xmlError(self.xmlFile, "Invalid state. Transition to name '%s' not defined for '%s'", stateToName, transitionKey)

			return
		end

		spec.stateTransitions[stateFromIndex] = stateToIndex
	end)

	spec.sailingSplines = {}
	spec.boatBobbingFreq = self.xmlFile:getValue(key .. ".sailingSplines#bobbingFreq", 1) / 1000 / math.pi
	spec.boatBobbingAmount = self.xmlFile:getValue(key .. ".sailingSplines#bobbingAmount", 0.05)
	spec.boatSwayingFreq = self.xmlFile:getValue(key .. ".sailingSplines#swayingFreq", 0.8) / 1000 / math.pi
	spec.boatSwayingAmount = self.xmlFile:getValue(key .. ".sailingSplines#swayingAmount", 0.025)

	self.xmlFile:iterate(key .. ".sailingSplines.spline", function (_, sailingSplineKey)
		local sailingSpline = self.xmlFile:getValue(sailingSplineKey .. "#node", nil, self.components, self.i3dMappings)
		local splineLength = getSplineLength(sailingSpline)

		table.insert(spec.sailingSplines, {
			node = sailingSpline,
			length = splineLength
		})
	end)

	spec.nextSailingSplineIndex = math.random(1, #spec.sailingSplines)
	spec.boatsSailingLinkNode = createTransformGroup("sailingBoatsLinkNode")

	link(getRootNode(), spec.boatsSailingLinkNode)

	spec.boatsSailing = {}
	spec.sailingAcc = 0.2
	spec.windSpeed = 1

	g_currentMission.environment.weather.windUpdater:addWindChangedListener(self)
end

function PlaceableBoatyard:onBoatI3DFileLoaded(i3dFileRoot, failedReason, args)
	local spec = self[PlaceableBoatyard.SPEC]

	if i3dFileRoot ~= 0 then
		spec.boatRoot = i3dFileRoot
		local components = {}

		I3DUtil.loadI3DComponents(i3dFileRoot, components)

		local boatKey = "placeable.boatyard.boat"

		self.xmlFile:iterate(boatKey .. ".progressiveVisibilityMesh.mesh", function (index, nodeKey)
			local node = self.xmlFile:getValue(nodeKey .. "#node", nil, components)

			if not getHasClassId(node, ClassIds.SHAPE) then
				Logging.xmlError(self.xmlFile, "node '%s' at '%s' is not a shape", getName(node), nodeKey)

				return
			end

			if not getHasShaderParameter(node, "hideByIndex") then
				Logging.xmlError(self.xmlFile, "mesh '%s' at '%s' does not have required shader parameter 'hideByIndex'", getName(node), nodeKey)

				return
			end

			local id = self.xmlFile:getValue(nodeKey .. "#id")
			local indexMin = self.xmlFile:getValue(nodeKey .. "#indexMin", 0)
			local indexMax = self.xmlFile:getValue(nodeKey .. "#indexMax")

			if spec.idToMesh[id] ~= nil then
				Logging.xmlError(self.xmlFile, "id '%s' at '%s' already in use", id, nodeKey)

				return
			end

			local mesh = {
				lastValue = -1,
				node = node,
				childIndex = getChildIndex(node),
				id = id,
				index = #spec.meshes + 1,
				indexMin = indexMin,
				indexMax = indexMax,
				dirtyFlag = self:getNextDirtyFlag(),
				numBits = MathUtil.getNumRequiredBits(indexMax)
			}
			spec.idToMesh[id] = mesh

			table.insert(spec.meshes, mesh)
		end)
	end

	self:finishLoadingTask(args.loadingTask)
	self:raiseActive()
end

function PlaceableBoatyard:onDelete()
	local spec = self[PlaceableBoatyard.SPEC]

	g_currentMission.activatableObjectsSystem:removeActivatable(spec.activatable)

	if spec.unloadingStation ~= nil then
		g_currentMission.storageSystem:removeUnloadingStation(spec.unloadingStation, self)
		g_currentMission.economyManager:removeSellingStation(spec.unloadingStation)
		spec.unloadingStation:delete()
	end

	if spec.playerTrigger ~= nil then
		removeTrigger(spec.playerTrigger)

		spec.playerTrigger = nil
	end

	for _, state in ipairs(spec.stateMachine) do
		state:delete()
	end

	if spec.boatRoot ~= nil then
		delete(spec.boatRoot)

		spec.boatRoot = nil
	end

	if spec.boatLinkNode ~= nil then
		delete(spec.boatLinkNode)

		spec.boatLinkNode = nil
	end

	if spec.boatsSailingLinkNode ~= nil then
		delete(spec.boatsSailingLinkNode)

		spec.boatsSailingLinkNode = nil
	end

	if spec.sharedLoadRequestId ~= nil then
		g_i3DManager:releaseSharedI3DFile(spec.sharedLoadRequestId)

		spec.sharedLoadRequestId = nil
	end
end

function PlaceableBoatyard:collectPickObjects(superFunc, node)
	local spec = self[PlaceableBoatyard.SPEC]

	for i = 1, #spec.unloadingStation.unloadTriggers do
		local unloadTrigger = spec.unloadingStation.unloadTriggers[i]

		if node == unloadTrigger.exactFillRootNode then
			return
		end
	end

	superFunc(self, node)
end

function PlaceableBoatyard:saveToXMLFile(xmlFile, key, usedModNames)
	local spec = self[PlaceableBoatyard.SPEC]

	if spec.stateIndex > 0 then
		xmlFile:setValue(key .. ".state#index", spec.stateIndex)
		xmlFile:setValue(key .. "#splineTime", spec.splineTime)

		local state = spec.stateMachine[spec.stateIndex]

		state:saveToXMLFile(xmlFile, key, usedModNames)
	end

	spec.storage:saveToXMLFile(xmlFile, key .. ".storage")
end

function PlaceableBoatyard:loadFromXMLFile(xmlFile, key)
	local spec = self[PlaceableBoatyard.SPEC]
	local stateIndex = xmlFile:getValue(key .. ".state#index") or 0
	local splineTimeLoaded = xmlFile:getValue(key .. "#splineTime")

	for i = 0, stateIndex do
		self:setState(i)
	end

	if splineTimeLoaded ~= nil then
		self:setSplineTime(splineTimeLoaded)
	end

	local state = spec.stateMachine[spec.stateIndex]

	state:loadFromXMLFile(xmlFile, key)
	spec.storage:loadFromXMLFile(xmlFile, key .. ".storage")
end

function PlaceableBoatyard:onReadStream(streamId, connection)
	local spec = self[PlaceableBoatyard.SPEC]
	local unloadingStationId = NetworkUtil.readNodeObjectId(streamId)

	spec.unloadingStation:readStream(streamId, connection)
	g_client:finishRegisterObject(spec.unloadingStation, unloadingStationId)

	local storageId = NetworkUtil.readNodeObjectId(streamId)

	spec.storage:readStream(streamId, connection)
	g_client:finishRegisterObject(spec.storage, storageId)

	local stateIndex = streamReadUInt8(streamId)

	for i = 0, stateIndex do
		self:setState(i)
	end

	local state = spec.stateMachine[stateIndex]

	state:onReadStream(streamId, connection)

	local splineTime = streamReadFloat32(streamId)
	spec.splineTimeChanged = true

	spec.splineInterpolator:setValue(splineTime)
	spec.splineTimeInterpolator:reset()

	for meshIndex, mesh in ipairs(spec.meshes) do
		local hideByIndexValue = streamReadUIntN(streamId, mesh.numBits)
		local progress = MathUtil.inverseLerp(mesh.indexMax, mesh.indexMin, hideByIndexValue)

		self:setMeshProgress(mesh.id, progress)
	end

	spec.nextSailingSplineIndex = streamReadUInt8(streamId, spec.nextSailingSplineIndex)
end

function PlaceableBoatyard:onWriteStream(streamId, connection)
	local spec = self[PlaceableBoatyard.SPEC]

	NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(spec.unloadingStation))
	spec.unloadingStation:writeStream(streamId, connection)
	g_server:registerObjectInStream(connection, spec.unloadingStation)
	NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(spec.storage))
	spec.storage:writeStream(streamId, connection)
	g_server:registerObjectInStream(connection, spec.storage)
	streamWriteUInt8(streamId, spec.stateIndex)

	local state = spec.stateMachine[spec.stateIndex]

	state:onWriteStream(streamId, connection)
	streamWriteFloat32(streamId, spec.splineTime)

	for meshIndex, mesh in ipairs(spec.meshes) do
		streamWriteUIntN(streamId, mesh.lastValue, mesh.numBits)
	end

	streamWriteUInt8(streamId, spec.nextSailingSplineIndex)
end

function PlaceableBoatyard:onReadUpdateStream(streamId, timestamp, connection)
	if connection:getIsServer() then
		local spec = self[PlaceableBoatyard.SPEC]

		for meshIndex, mesh in ipairs(spec.meshes) do
			if streamReadBool(streamId) then
				local hideByIndexValue = streamReadUIntN(streamId, mesh.numBits)
				local progress = MathUtil.inverseLerp(mesh.indexMax, mesh.indexMin, hideByIndexValue)

				self:setMeshProgress(mesh.id, progress)
			end
		end

		spec.splineTimeChanged = streamReadBool(streamId)

		if spec.splineTimeChanged then
			local splineTime = streamReadFloat32(streamId)

			spec.splineTimeInterpolator:startNewPhaseNetwork()
			spec.splineInterpolator:setTargetValue(splineTime)
		end

		if streamReadBool(streamId) then
			for _, state in ipairs(spec.stateMachine) do
				if streamReadBool(streamId) then
					state:onReadUpdateStream(streamId, timestamp, connection)
				end
			end
		end
	end
end

function PlaceableBoatyard:onWriteUpdateStream(streamId, connection, dirtyMask)
	if not connection:getIsServer() then
		local spec = self[PlaceableBoatyard.SPEC]

		for meshIndex, mesh in ipairs(spec.meshes) do
			if streamWriteBool(streamId, bitAND(dirtyMask, mesh.dirtyFlag) ~= 0) then
				streamWriteUIntN(streamId, mesh.lastValue, mesh.numBits)
			end
		end

		if streamWriteBool(streamId, bitAND(dirtyMask, spec.splineTimeDirtyFlag) ~= 0) then
			streamWriteFloat32(streamId, spec.splineTime)
		end

		if streamWriteBool(streamId, bitAND(dirtyMask, spec.statesDirtyMask) ~= 0) then
			for _, state in ipairs(spec.stateMachine) do
				if streamWriteBool(streamId, bitAND(dirtyMask, state.dirtyFlag) ~= 0) then
					state:onWriteUpdateStream(streamId, connection, dirtyMask)
				end
			end
		end
	end
end

function PlaceableBoatyard:onUpdate(dt)
	local spec = self[PlaceableBoatyard.SPEC]

	if self.isServer then
		local state = spec.stateMachine[spec.stateIndex]

		if state:isDone() then
			local nextStateIndex = spec.stateTransitions[spec.stateIndex]

			self:setState(nextStateIndex)

			state = spec.stateMachine[spec.stateIndex]

			self:raiseActive()
		elseif state:raiseActive() then
			self:raiseActive()
		end

		state:update(dt)
	elseif self.isClient and spec.splineTimeChanged then
		spec.splineTimeInterpolator:update(dt)

		local interpolationAlpha = spec.splineTimeInterpolator:getAlpha()
		local splineTime = spec.splineInterpolator:getInterpolatedValue(interpolationAlpha)

		self:setSplineTime(splineTime)

		if spec.splineTimeInterpolator:isInterpolating() then
			self:raiseActive()
		end
	end

	for boatSailingNode, boatAttrs in pairs(spec.boatsSailing) do
		local spline = boatAttrs.spline
		local bobbing = spec.boatBobbingAmount * math.sin(g_time * spec.boatBobbingFreq)
		local swaying = spec.boatSwayingAmount * math.sin(g_time * spec.boatSwayingFreq)

		if boatAttrs.transitionTime < boatAttrs.transitionDuration then
			local alpha = boatAttrs.transitionTime / boatAttrs.transitionDuration
			local x, y, z = MathUtil.vector3Lerp(boatAttrs.startX, boatAttrs.startY, boatAttrs.startZ, spline.startX, spline.startY + bobbing, spline.startZ, alpha)

			setWorldTranslation(boatSailingNode, x, y, z)

			local dx, dy, dz = MathUtil.vector3Lerp(boatAttrs.startDx, boatAttrs.startDy, boatAttrs.startDz, spline.startDx, spline.startDy, spline.startDz, alpha)
			local ux, uy, uz = MathUtil.vector3Lerp(boatAttrs.startUx, boatAttrs.startUy, boatAttrs.startUz, swaying, 1, 0, alpha)

			setDirection(boatSailingNode, dx, dy, dz, ux, uy, uz)

			boatAttrs.transitionTime = boatAttrs.transitionTime + dt
		else
			local windFactor = MathUtil.clamp(spec.windSpeed / 15, 0.5, 2)
			boatAttrs.speed = MathUtil.clamp(boatAttrs.speed + spec.sailingAcc * dt / 1000, 0, windFactor * 3)
			boatAttrs.splineTime = boatAttrs.splineTime + boatAttrs.speed / 1000 * dt / spline.length
			local x, y, z = getSplinePosition(spline.node, boatAttrs.splineTime)
			local dx, dy, dz = getSplineDirection(spline.node, boatAttrs.splineTime)

			setWorldTranslation(boatSailingNode, x, y + bobbing, z)
			setDirection(boatSailingNode, dx, dy, dz, swaying, 1, 0)

			if boatAttrs.splineTime >= 1 then
				spec.boatsSailing[boatSailingNode] = nil

				delete(boatSailingNode)
			end
		end
	end

	if next(spec.boatsSailing) then
		self:raiseActive()
	end
end

function PlaceableBoatyard:setOwnerFarmId(superFunc, farmId)
	superFunc(self, farmId)

	local spec = self[PlaceableBoatyard.SPEC]
	spec.unloadingStation.skipSell = farmId ~= AccessHandler.EVERYONE

	setVisibility(spec.playerTrigger, farmId == AccessHandler.EVERYONE)

	if farmId == AccessHandler.EVERYONE then
		g_currentMission.storageSystem:addUnloadingStation(spec.unloadingStation, self)
		g_currentMission.economyManager:addSellingStation(spec.unloadingStation)
	else
		g_currentMission.economyManager:removeSellingStation(spec.unloadingStation)
		g_currentMission.storageSystem:removeUnloadingStation(spec.unloadingStation, self)
	end
end

function PlaceableBoatyard:setWindValues(windDirX, windDirZ, windVelocity, cirrusCloudSpeedFactor)
	local spec = self[PlaceableBoatyard.SPEC]
	spec.windSpeed = windVelocity
end

function PlaceableBoatyard:setMeshProgress(meshId, percentage)
	local spec = self[PlaceableBoatyard.SPEC]

	if spec.boat ~= nil then
		local mesh = spec.idToMesh[meshId]

		if mesh ~= nil then
			local hideByIndexValue = MathUtil.round(MathUtil.lerp(mesh.indexMax, mesh.indexMin, percentage))

			if hideByIndexValue ~= mesh.lastValue then
				local node = getChildAt(spec.boat, mesh.childIndex)

				setVisibility(node, percentage ~= 0)

				mesh.lastValue = hideByIndexValue

				setShaderParameter(node, "hideByIndex", hideByIndexValue, 0, 0, 0, false)

				if self.isServer then
					self:raiseDirtyFlags(mesh.dirtyFlag)
				end
			end
		end
	end
end

function PlaceableBoatyard:setState(newStateIndex)
	local spec = self[PlaceableBoatyard.SPEC]

	if self.isServer then
		g_server:broadcastEvent(BoatyardStateEvent.new(self, newStateIndex), false)
	end

	if newStateIndex ~= spec.stateIndex then
		local oldStateIndex = spec.stateIndex
		spec.stateIndex = newStateIndex
		local oldState = spec.stateMachine[oldStateIndex]
		local state = spec.stateMachine[newStateIndex]

		if oldState ~= nil then
			oldState:deactivate()
		end

		state:activate()
	end
end

function PlaceableBoatyard:createBoat()
	local spec = self[PlaceableBoatyard.SPEC]

	if spec.boat == nil then
		spec.boat = clone(spec.boatRoot, false, false, true)

		link(spec.boatLinkNode, spec.boat)
	end
end

function PlaceableBoatyard:releaseBoat()
	local spec = self[PlaceableBoatyard.SPEC]

	if spec.boat == nil then
		return
	end

	local sailingSplineAttrs = spec.sailingSplines[spec.nextSailingSplineIndex]
	local boatSailing = spec.boat
	local x, y, z = getWorldTranslation(spec.boat)
	local rx, ry, rz = getWorldRotation(spec.boat)

	link(spec.boatsSailingLinkNode, spec.boat)
	setWorldTranslation(spec.boat, x, y, z)
	setWorldRotation(spec.boat, rx, ry, rz)

	local dx, dy, dz = localDirectionToWorld(spec.boat, 0, 0, 1)
	local ux, uy, uz = localDirectionToWorld(spec.boat, 0, 1, 0)
	local splineX, splineY, splineZ, splineTime = getClosestSplinePosition(sailingSplineAttrs.node, x, y, z, 0.2)
	local splineDx, splineDy, splineDz = getSplineDirection(sailingSplineAttrs.node, splineTime)
	sailingSplineAttrs.startZ = splineZ
	sailingSplineAttrs.startY = splineY
	sailingSplineAttrs.startX = splineX
	sailingSplineAttrs.startDz = splineDz
	sailingSplineAttrs.startDy = splineDy
	sailingSplineAttrs.startDx = splineDx
	local distanceDifference = MathUtil.vector3Length(x - splineX, y - splineY, z - splineZ)
	local angleDifference = math.deg(MathUtil.getVectorAngleDifference(dx, dy, dz, splineDx, splineDy, splineDz))
	spec.boatsSailing[boatSailing] = {
		speed = 0,
		transitionTime = 0,
		spline = sailingSplineAttrs,
		splineIndex = spec.nextSailingSplineIndex,
		splineTime = splineTime,
		transitionDuration = math.max(distanceDifference * 4, angleDifference) * 1000,
		startX = x,
		startY = y,
		startZ = z,
		startDx = dx,
		startDy = dy,
		startDz = dz,
		startUx = ux,
		startUy = uy,
		startUz = uz
	}

	if self.isServer and self:getOwnerFarmId() ~= AccessHandler.EVERYONE then
		g_currentMission:addMoney(spec.boatLaunchReward * EconomyManager.getPriceMultiplier(), self:getOwnerFarmId(), MoneyType.SOLD_PRODUCTS, true, true)
	end

	spec.boat = nil
	spec.nextSailingSplineIndex = 1 + spec.nextSailingSplineIndex % #spec.sailingSplines

	self:raiseActive()
end

function PlaceableBoatyard:setSplineTime(splineTime, resetInterpolation)
	local spec = self[PlaceableBoatyard.SPEC]
	spec.splineTime = MathUtil.clamp(splineTime, 0, 1)

	if self.isServer then
		self:raiseDirtyFlags(spec.splineTimeDirtyFlag)
	elseif resetInterpolation and self.isClient then
		spec.splineInterpolator:setValue(splineTime)
	end

	local x, y, z = getSplinePosition(spec.spline, spec.splineTime)

	setWorldTranslation(spec.boatLinkNode, x, y, z)

	local dx, dy, dz = getSplineDirection(spec.spline, spec.splineTime)
	local jitter = 0.002 * math.sin(spec.splineTime * spec.splineLength * 2)

	setDirection(spec.boatLinkNode, -dx, -dy, -dz, jitter, 1, 0)
end

function PlaceableBoatyard:addSplineDistanceDelta(distance)
	local spec = self[PlaceableBoatyard.SPEC]
	local increment = distance / spec.splineLength

	self:setSplineTime(spec.splineTime + increment)

	return spec.splineTime, increment
end

function PlaceableBoatyard:getSplineTime()
	local spec = self[PlaceableBoatyard.SPEC]

	return spec.splineTime
end

function PlaceableBoatyard:getFillLevel(fillType)
	local spec = self[PlaceableBoatyard.SPEC]

	return spec.storage:getFillLevel(fillType)
end

function PlaceableBoatyard:removeFillLevel(fillType, amount)
	local spec = self[PlaceableBoatyard.SPEC]
	local previousFillLevel = spec.storage:getFillLevel(fillType)

	spec.storage:setFillLevel(previousFillLevel - amount, fillType)

	return previousFillLevel - spec.storage:getFillLevel(fillType)
end

function PlaceableBoatyard:updateInfo(superFunc, infoTable)
	superFunc(self, infoTable)

	local spec = self[PlaceableBoatyard.SPEC]
	spec.fillTypesAndLevelsAuxiliary = {}

	for fillType, fillLevel in pairs(spec.storage:getFillLevels()) do
		spec.fillTypesAndLevelsAuxiliary[fillType] = (spec.fillTypesAndLevelsAuxiliary[fillType] or 0) + fillLevel
	end

	table.clear(spec.infoTriggerFillTypesAndLevels)

	for fillType, fillLevel in pairs(spec.fillTypesAndLevelsAuxiliary) do
		if fillLevel > 0.1 then
			spec.fillTypeToFillTypeStorageTable[fillType] = spec.fillTypeToFillTypeStorageTable[fillType] or {
				fillType = fillType,
				fillLevel = fillLevel
			}
			spec.fillTypeToFillTypeStorageTable[fillType].fillLevel = fillLevel

			table.insert(spec.infoTriggerFillTypesAndLevels, spec.fillTypeToFillTypeStorageTable[fillType])
		end
	end

	table.clear(spec.fillTypesAndLevelsAuxiliary)
	table.sort(spec.infoTriggerFillTypesAndLevels, function (a, b)
		return b.fillLevel < a.fillLevel
	end)

	local numEntries = math.min(#spec.infoTriggerFillTypesAndLevels, 7)

	if numEntries > 0 then
		table.insert(infoTable, spec.infoTableEntryStorage)

		for i = 1, numEntries do
			local fillTypeAndLevel = spec.infoTriggerFillTypesAndLevels[i]

			table.insert(infoTable, {
				title = g_fillTypeManager:getFillTypeTitleByIndex(fillTypeAndLevel.fillType),
				text = g_i18n:formatVolume(fillTypeAndLevel.fillLevel, 0)
			})
		end
	end

	local state = spec.stateMachine[spec.stateIndex]

	if state.updateInfo ~= nil then
		state:updateInfo(infoTable)
	end
end

function PlaceableBoatyard:playerTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	if (onEnter or onLeave) and g_currentMission.player ~= nil and g_currentMission.player.rootNode == otherId then
		local spec = self[PlaceableBoatyard.SPEC]

		if onEnter then
			if Platform.isMobile and spec.activatable:getIsActivatable() then
				spec.activatable:run()

				return
			end

			g_currentMission.activatableObjectsSystem:addActivatable(spec.activatable)
		end

		if onLeave then
			g_currentMission.activatableObjectsSystem:removeActivatable(spec.activatable)
		end
	end
end

function PlaceableBoatyard:buyRequest()
	local price = self:getPrice()

	local function buyingEventCallback(statusCode)
		if statusCode ~= nil then
			local dialogArgs = BuyExistingPlaceableEvent.DIALOG_MESSAGES[statusCode]

			if dialogArgs ~= nil then
				g_gui:showInfoDialog({
					text = g_i18n:getText(dialogArgs.text),
					dialogType = dialogArgs.dialogType
				})
			end
		end

		g_messageCenter:unsubscribe(BuyExistingPlaceableEvent, self)
	end

	local function dialogCallback(yes, _)
		if yes then
			g_messageCenter:subscribe(BuyExistingPlaceableEvent, buyingEventCallback)
			g_client:getServerConnection():sendEvent(BuyExistingPlaceableEvent.new(self, g_currentMission:getFarmId()))
		end
	end

	local callback = dialogCallback
	local text = string.format(g_i18n:getText("dialog_buyBuildingFor"), self:getName(), g_i18n:formatMoney(price, 0, true))

	g_gui:showYesNoDialog({
		text = text,
		callback = callback
	})
end

BoatyardActivatable = {}
local BoatyardActivatable_mt = Class(BoatyardActivatable)

function BoatyardActivatable.new(boatyard)
	local self = setmetatable({}, BoatyardActivatable_mt)
	self.boatyard = boatyard
	self.activateText = string.format(g_i18n:getText("action_buyOBJECT"), self.boatyard:getName())

	return self
end

function BoatyardActivatable:getIsActivatable()
	local ownerFarmId = self.boatyard:getOwnerFarmId()

	return ownerFarmId == AccessHandler.EVERYONE
end

function BoatyardActivatable:run()
	local ownerFarmId = self.boatyard:getOwnerFarmId()

	if ownerFarmId == AccessHandler.EVERYONE then
		self.boatyard:buyRequest()
	end
end
