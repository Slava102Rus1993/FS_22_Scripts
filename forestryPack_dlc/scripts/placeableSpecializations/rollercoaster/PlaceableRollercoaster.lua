local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

PlaceableRollercoaster = {
	MOD_NAME = g_currentModName,
	SPEC_NAME = g_currentModName .. ".rollercoaster"
}
PlaceableRollercoaster.SPEC = "spec_" .. PlaceableRollercoaster.SPEC_NAME
PlaceableRollercoaster.SEAT_INDEX_NUM_BITS = 4
PlaceableRollercoaster.SEAT_MAX_NUM = 2^PlaceableRollercoaster.SEAT_INDEX_NUM_BITS - 1
PlaceableRollercoaster.INSTANCE = nil

function PlaceableRollercoaster.prerequisitesPresent(specializations)
	return true
end

function PlaceableRollercoaster.registerFunctions(placeableType)
	SpecializationUtil.registerFunction(placeableType, "onSharedAnimationFileLoaded", PlaceableRollercoaster.onSharedAnimationFileLoaded)
	SpecializationUtil.registerFunction(placeableType, "getCanEnter", PlaceableRollercoaster.getCanEnter)
	SpecializationUtil.registerFunction(placeableType, "getFreeSeatIndex", PlaceableRollercoaster.getFreeSeatIndex)
	SpecializationUtil.registerFunction(placeableType, "getCanStart", PlaceableRollercoaster.getCanStart)
	SpecializationUtil.registerFunction(placeableType, "setState", PlaceableRollercoaster.setState)
	SpecializationUtil.registerFunction(placeableType, "getFillLevel", PlaceableRollercoaster.getFillLevel)
	SpecializationUtil.registerFunction(placeableType, "removeFillLevel", PlaceableRollercoaster.removeFillLevel)
	SpecializationUtil.registerFunction(placeableType, "finalizeBuild", PlaceableRollercoaster.finalizeBuild)
	SpecializationUtil.registerFunction(placeableType, "startRide", PlaceableRollercoaster.startRide)
	SpecializationUtil.registerFunction(placeableType, "endRide", PlaceableRollercoaster.endRide)
	SpecializationUtil.registerFunction(placeableType, "getAnimation", PlaceableRollercoaster.getAnimation)
	SpecializationUtil.registerFunction(placeableType, "setAnimationTime", PlaceableRollercoaster.setAnimationTime)
	SpecializationUtil.registerFunction(placeableType, "updateFxModifierValues", PlaceableRollercoaster.updateFxModifierValues)
	SpecializationUtil.registerFunction(placeableType, "tryEnterRide", PlaceableRollercoaster.tryEnterRide)
	SpecializationUtil.registerFunction(placeableType, "enterRide", PlaceableRollercoaster.enterRide)
	SpecializationUtil.registerFunction(placeableType, "exitRide", PlaceableRollercoaster.exitRide)
	SpecializationUtil.registerFunction(placeableType, "onUserRemoved", PlaceableRollercoaster.onUserRemoved)
	SpecializationUtil.registerFunction(placeableType, "registerRidersChangedListener", PlaceableRollercoaster.registerRidersChangedListener)
	SpecializationUtil.registerFunction(placeableType, "unregisterRidersChangedListener", PlaceableRollercoaster.unregisterRidersChangedListener)
	SpecializationUtil.registerFunction(placeableType, "getParentComponent", PlaceableRollercoaster.getParentComponent)
	SpecializationUtil.registerFunction(placeableType, "passengerCharacterLoaded", PlaceableRollercoaster.passengerCharacterLoaded)
	SpecializationUtil.registerFunction(placeableType, "playerTriggerCallback", PlaceableRollercoaster.playerTriggerCallback)
	SpecializationUtil.registerFunction(placeableType, "setPlayerTriggerState", PlaceableRollercoaster.setPlayerTriggerState)
	SpecializationUtil.registerFunction(placeableType, "getNumRides", PlaceableRollercoaster.getNumRides)
end

function PlaceableRollercoaster.registerOverwrittenFunctions(placeableType)
	SpecializationUtil.registerOverwrittenFunction(placeableType, "collectPickObjects", PlaceableRollercoaster.collectPickObjects)
	SpecializationUtil.registerOverwrittenFunction(placeableType, "updateInfo", PlaceableRollercoaster.updateInfo)
	SpecializationUtil.registerOverwrittenFunction(placeableType, "getHotspot", PlaceableRollercoaster.getHotspot)
end

function PlaceableRollercoaster.registerEventListeners(placeableType)
	SpecializationUtil.registerEventListener(placeableType, "onLoad", PlaceableRollercoaster)
	SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", PlaceableRollercoaster)
	SpecializationUtil.registerEventListener(placeableType, "onDelete", PlaceableRollercoaster)
	SpecializationUtil.registerEventListener(placeableType, "onUpdate", PlaceableRollercoaster)
	SpecializationUtil.registerEventListener(placeableType, "onReadStream", PlaceableRollercoaster)
	SpecializationUtil.registerEventListener(placeableType, "onWriteStream", PlaceableRollercoaster)
	SpecializationUtil.registerEventListener(placeableType, "onReadUpdateStream", PlaceableRollercoaster)
	SpecializationUtil.registerEventListener(placeableType, "onWriteUpdateStream", PlaceableRollercoaster)
end

function PlaceableRollercoaster.registerXMLPaths(schema, basePath)
	schema:setXMLSpecializationType("Rollercoaster")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".rollercoaster.animation.clip#rootNode", "Animation root node")
	schema:register(XMLValueType.STRING, basePath .. ".rollercoaster.animation.clip#name", "Animation clip name")
	schema:register(XMLValueType.STRING, basePath .. ".rollercoaster.animation.clip#filename", "Animation filename")
	schema:register(XMLValueType.FLOAT, basePath .. ".rollercoaster.animation#speedScale", "Animation speed scale")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".rollercoaster.movingSounds.sound(?)#node", "")
	schema:register(XMLValueType.STRING, basePath .. ".rollercoaster.movingSounds.sound(?)#filename", "")
	schema:register(XMLValueType.FLOAT, basePath .. ".rollercoaster.movingSounds.sound(?)#innerRadius", "Audio source inner radius")
	schema:register(XMLValueType.FLOAT, basePath .. ".rollercoaster.movingSounds.sound(?)#radius", "Audio source radius")
	schema:register(XMLValueType.FLOAT, basePath .. ".rollercoaster.movingSounds.sound(?)#volume", "Audio source volume")
	SoundManager.registerSampleXMLPaths(schema, basePath .. ".rollercoaster.sounds", "driving1")
	SoundManager.registerSampleXMLPaths(schema, basePath .. ".rollercoaster.sounds", "driving2")
	SoundManager.registerSampleXMLPaths(schema, basePath .. ".rollercoaster.sounds", "driving3")
	SoundManager.registerSampleXMLPaths(schema, basePath .. ".rollercoaster.sounds", "driving4")
	SoundManager.registerSampleXMLPaths(schema, basePath .. ".rollercoaster.sounds", "driving5")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".rollercoaster.playerTrigger#node", "Player trigger for entering the ride")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".rollercoaster.exitPoints.exitPoint(?)#node", "Node where players exit the rollercoaster")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".rollercoaster.hotspot#linkNode", "Node where hotspot is linked to")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".rollercoaster.hotspot#teleportNode", "Node where player is teleported to. Teleporting is only available if this is set")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".rollercoaster.carts.cart(?)#node", "Cart node")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".rollercoaster.carts.cart(?).seat(?)#node", "Seat reference node to calculate entering distance to")
	VehicleCamera.registerCameraXMLPaths(schema, basePath .. ".rollercoaster.carts.cart(?).seat(?).camera")
	VehicleCharacter.registerCharacterXMLPaths(schema, basePath .. ".rollercoaster.carts.cart(?).seat(?).characterNode")
	schema:register(XMLValueType.STRING, basePath .. ".rollercoaster.stateMachine.states.state(?)#name", "State name")
	schema:register(XMLValueType.STRING, basePath .. ".rollercoaster.stateMachine.states.state(?)#class", "State class")
	RollercoasterState.registerXMLPaths(schema, basePath .. ".rollercoaster.stateMachine.states.state(?)")
	RollercoasterStateBuilding.registerXMLPaths(schema, basePath .. ".rollercoaster.stateMachine.states.state(?)")
	RollercoasterStateRideWaiting.registerXMLPaths(schema, basePath .. ".rollercoaster.stateMachine.states.state(?)")
	schema:register(XMLValueType.STRING, basePath .. ".rollercoaster.stateMachine.transitions.transition(?)#from", "State name from")
	schema:register(XMLValueType.STRING, basePath .. ".rollercoaster.stateMachine.transitions.transition(?)#to", "State name to")
	SellingStation.registerXMLPaths(schema, basePath .. ".rollercoaster.sellingStation")
	Storage.registerXMLPaths(schema, basePath .. ".rollercoaster.storage")
	schema:setXMLSpecializationType()
end

function PlaceableRollercoaster.registerSavegameXMLPaths(schema, basePath)
	schema:register(XMLValueType.INT, basePath .. ".state#index", "")
	schema:register(XMLValueType.FLOAT, basePath .. "#splineTime", "")
	schema:register(XMLValueType.STRING, basePath .. ".player(?)#uniqueUserId", "")
	schema:register(XMLValueType.INT, basePath .. ".player(?)#rideCount", 0)
	RollercoasterStateBuilding.registerSavegameXMLPaths(schema, basePath)
	Storage.registerSavegameXMLPaths(schema, basePath .. ".storage")
end

function PlaceableRollercoaster:onLoad(savegame)
	local spec = self[PlaceableRollercoaster.SPEC]
	local key = "placeable.rollercoaster"
	local clipRootNode = self.xmlFile:getValue(key .. ".animation.clip#rootNode", nil, self.components, self.i3dMappings)
	local clipName = self.xmlFile:getValue(key .. ".animation.clip#name")
	local _, baseDirectory = Utils.getModNameAndBaseDirectory(self.xmlFile:getFilename())

	if clipRootNode ~= nil and clipName ~= nil then
		local clipFilename = self.xmlFile:getValue(key .. ".animation.clip#filename")
		spec.animation = {
			clipRootNode = clipRootNode,
			clipName = clipName,
			clipTrack = 0,
			speedScale = self.xmlFile:getValue(key .. ".animation#speedScale", 1)
		}

		if clipFilename ~= nil then
			clipFilename = Utils.getFilename(clipFilename, baseDirectory)
			local loadingTask = self:createLoadingTask()
			local arguments = {
				loadingTask = loadingTask
			}
			spec.animation.sharedLoadRequestId = g_i3DManager:loadSharedI3DFileAsync(clipFilename, false, false, self.onSharedAnimationFileLoaded, self, arguments)
			spec.animation.clipFilename = clipFilename
		end

		setVisibility(clipRootNode, false)

		spec.animationTimeInterpolator = InterpolationTime.new(1.3)
		spec.animationInterpolator = InterpolatorValue.new(0)
	end

	spec.playerTrigger = self.xmlFile:getValue(key .. ".playerTrigger#node", nil, self.components, self.i3dMappings)

	addTrigger(spec.playerTrigger, "playerTriggerCallback", self)
	self:setPlayerTriggerState(false)

	spec.activatable = RollercoasterActivatable.new(self)
	spec.carts = {}
	spec.seats = {}

	self.xmlFile:iterate(key .. ".carts.cart", function (cartIndex, cartKey)
		local cart = {
			node = self.xmlFile:getValue(cartKey .. "#node", nil, self.components, self.i3dMappings),
			slope = 0,
			angleChange = 0
		}
		cart.dirX, cart.dirY, cart.dirZ = localDirectionToWorld(cart.node, 0, 0, 1)

		self.xmlFile:iterate(cartKey .. ".seat", function (_, seatKey)
			local seatEntry = {
				cart = cart,
				node = self.xmlFile:getValue(seatKey .. "#node", nil, self.components, self.i3dMappings)
			}

			if seatEntry.node ~= nil then
				local camera = VehicleCamera.new(self)

				if camera:loadFromXML(self.xmlFile, seatKey .. ".camera", nil, 1) then
					seatEntry.camera = camera
				end

				seatEntry.vehicleCharacter = VehicleCharacter.new(self)

				if seatEntry.vehicleCharacter ~= nil and not seatEntry.vehicleCharacter:load(self.xmlFile, seatKey .. ".characterNode") then
					seatEntry.vehicleCharacter = nil
				end
			end

			seatEntry.characterSpineLastRotationZ = 0
			seatEntry.characterSpineLastRotationX = 0
			seatEntry.randomFactor = math.random()
			seatEntry.smoothingFactor = 1 - math.random(10, 40) / 100
			seatEntry.smoothingFactorInv = 1 - seatEntry.smoothingFactor

			table.insert(spec.seats, seatEntry)
		end)
		table.insert(spec.carts, cart)
	end)

	spec.centerCart = spec.carts[MathUtil.round(#spec.carts / 2)]
	spec.localSeatIndex = nil
	spec.numRiders = 0
	spec.ridersChangedListeners = {}
	spec.exitPoints = {}

	self.xmlFile:iterate(key .. ".exitPoints.exitPoint", function (_, pointKey)
		local exitPoint = self.xmlFile:getValue(pointKey .. "#node", nil, self.components, self.i3dMappings)

		if exitPoint ~= nil then
			table.insert(spec.exitPoints, exitPoint)
		end
	end)

	if #spec.exitPoints < #spec.seats then
		Logging.xmlWarning(self.xmlFile, "Only %d exitPoints defined for %d seats", #spec.exitPoints, #spec.seats)
	end

	spec.rollercoasterHotspot = RollercoasterHotspot.new()
	spec.hotSpotLinkNode = self.xmlFile:getValue(key .. ".hotspot#linkNode", nil, self.components, self.i3dMappings)
	spec.hotSpotTeleportNode = self.xmlFile:getValue(key .. ".hotspot#teleportNode", nil, self.components, self.i3dMappings)

	if self.isClient then
		spec.soundsMoving = {}

		self.xmlFile:iterate(key .. ".movingSounds.sound", function (index, soundKey)
			local movingSoundNode = self.xmlFile:getValue(soundKey .. "#node", nil, self.components, self.i3dMappings)
			local soundFilename = Utils.getFilename(self.xmlFile:getValue(soundKey .. "#filename"), baseDirectory)
			local innerRadius = self.xmlFile:getValue(soundKey .. "#innerRadius")
			local radius = self.xmlFile:getValue(soundKey .. "#radius")
			local volume = self.xmlFile:getValue(soundKey .. "#volume", 1)
			local audioSource = createAudioSource("rollercoaster_" .. tostring(index), soundFilename, radius, innerRadius, volume, 0)
			local sample = getAudioSourceSample(audioSource)

			setSampleGroup(sample, AudioGroup.ENVIRONMENT)
			link(getChildAt(movingSoundNode, 1), audioSource)
			table.insert(spec.soundsMoving, {
				node = movingSoundNode
			})
		end)

		spec.sounds = {
			driving1 = g_soundManager:loadSampleFromXML(self.xmlFile, key .. ".sounds", "driving1", baseDirectory, self.components, 0, AudioGroup.ENVIRONMENT, self.i3dMappings, self),
			driving2 = g_soundManager:loadSampleFromXML(self.xmlFile, key .. ".sounds", "driving2", baseDirectory, self.components, 0, AudioGroup.ENVIRONMENT, self.i3dMappings, self),
			driving3 = g_soundManager:loadSampleFromXML(self.xmlFile, key .. ".sounds", "driving3", baseDirectory, self.components, 0, AudioGroup.ENVIRONMENT, self.i3dMappings, self),
			driving4 = g_soundManager:loadSampleFromXML(self.xmlFile, key .. ".sounds", "driving4", baseDirectory, self.components, 0, AudioGroup.ENVIRONMENT, self.i3dMappings, self),
			driving5 = g_soundManager:loadSampleFromXML(self.xmlFile, key .. ".sounds", "driving5", baseDirectory, self.components, 0, AudioGroup.ENVIRONMENT, self.i3dMappings, self)
		}
		spec.speed = 0
		spec.posX, spec.posY, spec.posZ = getWorldTranslation(spec.centerCart.node)
		self.currentUpdateDistance = math.huge
	end

	spec.unloadingStation = SellingStation.new(self.isServer, self.isClient)

	spec.unloadingStation:load(self.components, self.xmlFile, key .. ".sellingStation", self.customEnvironment, self.i3dMappings, self.components[1].node)

	spec.unloadingStation.owningPlaceable = self
	spec.unloadingStation.storeSoldGoods = true
	spec.unloadingStation.skipSell = self:getOwnerFarmId() ~= AccessHandler.EVERYONE

	function spec.unloadingStation.getIsFillAllowedFromFarm(_, farmId)
		return g_currentMission.accessHandler:canFarmAccess(farmId, self)
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
	g_currentMission.storageSystem:addUnloadingStation(spec.unloadingStation, self)
	g_currentMission.economyManager:addSellingStation(spec.unloadingStation)
	g_messageCenter:subscribe(MessageType.USER_REMOVED, self.onUserRemoved, self)
end

function PlaceableRollercoaster:onSharedAnimationFileLoaded(node, failedReason, args)
	local spec = self[PlaceableRollercoaster.SPEC]

	if node ~= 0 and node ~= nil then
		if not self.isDeleted then
			local animNode = getChildAt(getChildAt(node, 0), 0)

			if cloneAnimCharacterSet(animNode, spec.animation.clipRootNode) then
				local characterSet = getAnimCharacterSet(spec.animation.clipRootNode)
				local clipIndex = getAnimClipIndex(characterSet, spec.animation.clipName)

				if clipIndex ~= -1 then
					assignAnimTrackClip(characterSet, spec.animation.clipTrack, clipIndex)
					setAnimTrackLoopState(characterSet, spec.animation.clipTrack, false)

					spec.animation.clipDuration = getAnimClipDuration(characterSet, clipIndex)
					spec.animation.clipIndex = clipIndex
					spec.animation.clipCharacterSet = characterSet

					setAnimTrackSpeedScale(characterSet, clipIndex, spec.animation.speedScale)
				else
					Logging.error("Animation clip with name '%s' does not exist in '%s'", spec.animation.clipName, spec.animation.clipFilename or self.xmlFilename)
				end
			end
		end

		delete(node)
	end

	spec.stateMachine = {}
	spec.stateNameToIndex = {}
	spec.stateTransitions = {}
	spec.stateIndex = -1
	spec.statesDirtyMask = 0
	local maxNumStates = 255
	local stateMachineNextIndex = 1
	local stateMachineXmlKey = "placeable.rollercoaster.stateMachine"

	self.xmlFile:iterate(stateMachineXmlKey .. ".states.state", function (_, stateKey)
		if maxNumStates < stateMachineNextIndex then
			Logging.xmlWarning(self.xmlFile, "Maximum number of states reached (%d)", maxNumStates)

			return
		end

		local stateName = self.xmlFile:getValue(stateKey .. "#name", ""):upper()

		if spec.stateNameToIndex[stateName] ~= nil then
			Logging.xmlError(self.xmlFile, "State '%s' already defined", stateName, stateKey)

			return
		end

		local stateClassName = self.xmlFile:getValue(stateKey .. "#class", "")
		local class = ClassUtil.getClassObject(PlaceableRollercoaster.MOD_NAME .. "." .. stateClassName)

		if class == nil then
			Logging.xmlError(self.xmlFile, "State class '%s' at '%s' not defined", stateClassName, stateKey)

			return
		end

		local stateIndex = stateMachineNextIndex
		spec.stateNameToIndex[stateName] = stateIndex
		local state = class.new(self)

		state:load(self.xmlFile, stateKey)

		spec.stateMachine[stateIndex] = state
		spec.statesDirtyMask = spec.statesDirtyMask + state.dirtyFlag
		stateMachineNextIndex = stateMachineNextIndex + 1
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

	spec.playerRideCounter = {}

	self:finishLoadingTask(args.loadingTask)
end

function PlaceableRollercoaster:onFinalizePlacement(savegame)
	local spec = self[PlaceableRollercoaster.SPEC]

	if self.isServer then
		for i = 1, spec.stateIndexPending do
			self:setState(i)
		end

		spec.postFinalize()

		spec.postFinalize = nil
		spec.stateIndexPending = nil

		self:raiseActive()
	end

	spec.rollercoasterHotspot:setPlaceable(self)
	spec.rollercoasterHotspot:setOwnerFarmId(nil)

	local x, y, z, _ = nil
	x, _, z = getWorldTranslation(spec.hotSpotLinkNode)

	spec.rollercoasterHotspot:setWorldPosition(x, z)

	x, y, z = getWorldTranslation(spec.hotSpotTeleportNode)

	spec.rollercoasterHotspot:setTeleportWorldPosition(x, y, z)
	g_currentMission:addMapHotspot(spec.rollercoasterHotspot)

	if PlaceableRollercoaster.INSTANCE == nil then
		PlaceableRollercoaster.INSTANCE = self
	end
end

function PlaceableRollercoaster:onDelete()
	local spec = self[PlaceableRollercoaster.SPEC]

	g_messageCenter:unsubscribeAll(self)
	g_currentMission:removeMapHotspot(spec.rollercoasterHotspot)
	spec.rollercoasterHotspot:delete()

	if spec.animation ~= nil and spec.animation.sharedLoadRequestId ~= nil then
		g_i3DManager:releaseSharedI3DFile(spec.animation.sharedLoadRequestId)

		spec.animation.sharedLoadRequestId = nil
	end

	for _, seat in ipairs(spec.seats) do
		seat.vehicleCharacter:delete()
	end

	if spec.soundsMoving ~= nil then
		for _, sound in ipairs(spec.soundsMoving) do
			if sound.movingSound ~= nil then
				g_currentMission.ambientSoundSystem:removeMovingSound(sound.movingSound)

				sound.movingSound = nil
			end
		end
	end

	if spec.sounds ~= nil then
		g_soundManager:deleteSamples(spec.sounds)
	end

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

	if PlaceableRollercoaster.INSTANCE == self then
		PlaceableRollercoaster.INSTANCE = nil
	end
end

function PlaceableRollercoaster:collectPickObjects(superFunc, node)
	local spec = self[PlaceableRollercoaster.SPEC]

	for i = 1, #spec.unloadingStation.unloadTriggers do
		local unloadTrigger = spec.unloadingStation.unloadTriggers[i]

		if node == unloadTrigger.exactFillRootNode then
			return
		end
	end

	superFunc(self, node)
end

function PlaceableRollercoaster:saveToXMLFile(xmlFile, key, usedModNames)
	local spec = self[PlaceableRollercoaster.SPEC]

	if spec.stateIndex ~= nil and spec.stateIndex > 0 then
		xmlFile:setValue(key .. ".state#index", spec.stateIndex)

		local state = spec.stateMachine[spec.stateIndex]

		state:saveToXMLFile(xmlFile, key, usedModNames)
	end

	spec.storage:saveToXMLFile(xmlFile, key .. ".storage")

	local i = 0

	for uniqueUserId, rideCount in pairs(spec.playerRideCounter) do
		local counterKey = string.format("%s.player(%d)", key, i)

		xmlFile:setValue(counterKey .. "#uniqueUserId", uniqueUserId)
		xmlFile:setValue(counterKey .. "#rideCount", rideCount)

		i = i + 1
	end
end

function PlaceableRollercoaster:loadFromXMLFile(xmlFile, key)
	local spec = self[PlaceableRollercoaster.SPEC]
	spec.stateIndexPending = xmlFile:getValue(key .. ".state#index") or 1

	function spec.postFinalize()
		local state = spec.stateMachine[spec.stateIndexPending]

		state:loadFromXMLFile(xmlFile, key)
	end

	spec.storage:loadFromXMLFile(xmlFile, key .. ".storage")
	xmlFile:iterate(key .. ".player", function (_, counterKey)
		local uniqueUserId = xmlFile:getValue(counterKey .. "#uniqueUserId")
		local rideCount = xmlFile:getValue(counterKey .. "#rideCount")

		if uniqueUserId ~= nil and rideCount ~= nil then
			spec.playerRideCounter[uniqueUserId] = rideCount
		end
	end)
end

function PlaceableRollercoaster:onReadStream(streamId, connection)
	local spec = self[PlaceableRollercoaster.SPEC]
	local unloadingStationId = NetworkUtil.readNodeObjectId(streamId)

	spec.unloadingStation:readStream(streamId, connection)
	g_client:finishRegisterObject(spec.unloadingStation, unloadingStationId)

	local storageId = NetworkUtil.readNodeObjectId(streamId)

	spec.storage:readStream(streamId, connection)
	g_client:finishRegisterObject(spec.storage, storageId)

	local stateIndex = streamReadUInt8(streamId)

	for i = 1, stateIndex do
		self:setState(i)
	end

	local state = spec.stateMachine[stateIndex]

	state:onReadStream(streamId, connection)

	for seatIndex, seat in ipairs(spec.seats) do
		if streamReadBool(streamId) then
			local player = NetworkUtil.readNodeObject(streamId)

			self:enterRide(seatIndex, player)
		end
	end
end

function PlaceableRollercoaster:onWriteStream(streamId, connection)
	local spec = self[PlaceableRollercoaster.SPEC]

	NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(spec.unloadingStation))
	spec.unloadingStation:writeStream(streamId, connection)
	g_server:registerObjectInStream(connection, spec.unloadingStation)
	NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(spec.storage))
	spec.storage:writeStream(streamId, connection)
	g_server:registerObjectInStream(connection, spec.storage)
	streamWriteUInt8(streamId, spec.stateIndex)

	local state = spec.stateMachine[spec.stateIndex]

	state:onWriteStream(streamId, connection)

	for seatIndex, seat in ipairs(spec.seats) do
		if streamWriteBool(streamId, seat.player ~= nil) then
			NetworkUtil.writeNodeObject(streamId, seat.player)
		end
	end
end

function PlaceableRollercoaster:onReadUpdateStream(streamId, timestamp, connection)
	if connection:getIsServer() then
		local spec = self[PlaceableRollercoaster.SPEC]

		if streamReadBool(streamId) then
			for _, state in ipairs(spec.stateMachine) do
				if streamReadBool(streamId) then
					state:onReadUpdateStream(streamId, timestamp, connection)
				end
			end
		end
	end
end

function PlaceableRollercoaster:onWriteUpdateStream(streamId, connection, dirtyMask)
	if not connection:getIsServer() then
		local spec = self[PlaceableRollercoaster.SPEC]

		if streamWriteBool(streamId, bitAND(dirtyMask, spec.statesDirtyMask) ~= 0) then
			for _, state in ipairs(spec.stateMachine) do
				if streamWriteBool(streamId, bitAND(dirtyMask, state.dirtyFlag) ~= 0) then
					state:onWriteUpdateStream(streamId, connection, dirtyMask)
				end
			end
		end
	end
end

function PlaceableRollercoaster:onUpdate(dt)
	local spec = self[PlaceableRollercoaster.SPEC]

	if self.isServer then
		local state = spec.stateMachine[spec.stateIndex]

		if state ~= nil then
			if state:isDone() then
				local nextStateIndex = spec.stateTransitions[spec.stateIndex]

				self:setState(nextStateIndex)

				state = spec.stateMachine[spec.stateIndex]

				self:raiseActive()
			elseif state:raiseActive() then
				self:raiseActive()
			end

			if state ~= nil then
				state:update(dt)
			end
		end
	end

	if self.isClient then
		if spec.localSeatIndex ~= nil then
			spec.seats[spec.localSeatIndex].camera:update(dt)
			self:raiseActive()
		end

		for _, seat in ipairs(spec.seats) do
			if seat.player ~= nil and seat.player ~= g_currentMission.player then
				local randomDeviation = 1 - seat.randomFactor + math.sin(g_time / 500 + seat.randomFactor) * seat.randomFactor / 5
				seat.characterSpineLastRotationX = seat.smoothingFactor * seat.characterSpineLastRotationX + seat.smoothingFactorInv * (seat.cart.slope + randomDeviation / 2) / 5
				seat.characterSpineLastRotationZ = seat.smoothingFactor * seat.characterSpineLastRotationZ + seat.smoothingFactorInv * (seat.cart.angleChange - randomDeviation) / 20

				setRotation(seat.vehicleCharacter.characterNode, seat.characterSpineLastRotationX, 0, seat.characterSpineLastRotationZ)
				seat.vehicleCharacter:update(dt)
			end
		end

		if spec.numRiders > 0 then
			self:raiseActive()

			self.currentUpdateDistance = calcDistanceFrom(spec.centerCart.node, getCamera())
		end
	end
end

function PlaceableRollercoaster:setState(newStateIndex)
	local spec = self[PlaceableRollercoaster.SPEC]

	if self.isServer then
		g_server:broadcastEvent(RollercoasterStateEvent.new(self, newStateIndex), false)
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

function PlaceableRollercoaster:getFillLevel(fillType)
	local spec = self[PlaceableRollercoaster.SPEC]

	return spec.storage:getFillLevel(fillType)
end

function PlaceableRollercoaster:removeFillLevel(fillType, amount)
	local spec = self[PlaceableRollercoaster.SPEC]
	local previousFillLevel = spec.storage:getFillLevel(fillType)

	spec.storage:setFillLevel(previousFillLevel - amount, fillType)

	return previousFillLevel - spec.storage:getFillLevel(fillType)
end

function PlaceableRollercoaster:finalizeBuild()
	local spec = self[PlaceableRollercoaster.SPEC]

	spec.storage:empty()
	g_currentMission.storageSystem:removeUnloadingStation(spec.unloadingStation, self)
	g_currentMission.economyManager:removeSellingStation(spec.unloadingStation)

	if spec.soundsMoving ~= nil then
		for _, sound in ipairs(spec.soundsMoving) do
			if sound.node and sound.movingSound == nil then
				sound.movingSound = g_currentMission.ambientSoundSystem:addMovingSound(sound.node)
			end
		end
	end

	spec.rollercoasterHotspot:changeToRollercoaster()
end

function PlaceableRollercoaster:getCanEnter()
	local spec = self[PlaceableRollercoaster.SPEC]

	return spec.stateIndex == spec.stateNameToIndex.RIDE_WAITING and spec.animation.clipCharacterSet ~= nil and spec.localSeatIndex == nil and spec.numRiders < #spec.seats
end

function PlaceableRollercoaster:getFreeSeatIndex()
	local spec = self[PlaceableRollercoaster.SPEC]

	for seatIndex, seat in ipairs(spec.seats) do
		if seat.player == nil then
			return seatIndex
		end
	end

	return nil
end

function PlaceableRollercoaster:getCanStart()
	local spec = self[PlaceableRollercoaster.SPEC]

	return spec.numRiders > 0
end

function PlaceableRollercoaster:startRide()
	local spec = self[PlaceableRollercoaster.SPEC]

	if spec.animation.clipCharacterSet ~= nil then
		if spec.localSeatIndex ~= nil then
			g_currentMission.hud:setIsVisible(false)
		end

		if self.isClient then
			spec.animationInterpolator:setValue(0)
			spec.animationTimeInterpolator:reset()
		end

		setAnimTrackTime(spec.animation.clipCharacterSet, spec.animation.clipTrack, 0, true)
		enableAnimTrack(spec.animation.clipCharacterSet, spec.animation.clipTrack)

		if self.isClient then
			g_soundManager:playSamples(spec.sounds)
		end
	end
end

function PlaceableRollercoaster:endRide()
	local spec = self[PlaceableRollercoaster.SPEC]

	if self.isClient then
		g_soundManager:stopSamples(spec.sounds)
	end

	for seatIndex, seat in ipairs(spec.seats) do
		if seat.player ~= nil then
			self:exitRide(seatIndex)
		end
	end
end

function PlaceableRollercoaster:tryEnterRide(connection, player)
	local seatIndex = self:getFreeSeatIndex()

	if seatIndex ~= nil then
		g_server:broadcastEvent(RollercoasterPassengerEnterResponseEvent.new(self, player, seatIndex), true, nil, self, false, nil, true)
	end
end

function PlaceableRollercoaster:enterRide(seatIndex, player)
	local spec = self[PlaceableRollercoaster.SPEC]

	if player == g_currentMission.player then
		spec.localSeatIndex = seatIndex
		g_currentMission.isPlayerFrozen = true

		g_inputBinding:setContext("ROLLERCOASTER", true)
		spec.seats[seatIndex].camera:onActivate()

		if g_currentMission.controlPlayer then
			g_currentMission.player:onLeave()
		end
	else
		local playerStyle = player:getStyle()

		spec.seats[seatIndex].vehicleCharacter:loadCharacter(playerStyle, self, PlaceableRollercoaster.passengerCharacterLoaded, {
			seat = spec.seats[seatIndex]
		})
	end

	spec.numRiders = spec.numRiders + 1

	for target, func in pairs(spec.ridersChangedListeners) do
		func(spec.numRiders, 1, player)
	end

	if spec.numRiders >= #spec.seats then
		self:setPlayerTriggerState(false)
	end

	spec.seats[seatIndex].player = player

	self:raiseActive()
end

function PlaceableRollercoaster:exitRide(seatIndex)
	local spec = self[PlaceableRollercoaster.SPEC]
	local isOwner = spec.localSeatIndex == seatIndex

	spec.seats[seatIndex].vehicleCharacter:unloadCharacter()

	if isOwner then
		spec.seats[seatIndex].camera:onDeactivate()
	end

	local player = spec.seats[seatIndex].player

	if isOwner then
		if g_inputBinding:getContextName() == "ROLLERCOASTER" then
			g_inputBinding:revertContext(true)
		end

		g_currentMission.isPlayerFrozen = false

		g_currentMission.hud:setIsVisible(true)

		spec.localSeatIndex = nil
	end

	local exitNodeIndex = (seatIndex - 1) % #spec.exitPoints + 1
	local exitNode = spec.exitPoints[exitNodeIndex]
	local x, y, z = getWorldTranslation(exitNode)

	player:moveTo(x, y, z, true, false)
	player:onEnter(isOwner)

	spec.numRiders = spec.numRiders - 1

	for target, func in pairs(spec.ridersChangedListeners) do
		func(spec.numRiders, -1, spec.seats[seatIndex].player)
	end

	if self.isServer and player ~= nil then
		local userId = player.userId
		local user = g_currentMission.userManager:getUserByUserId(userId)

		if user ~= nil then
			local uniqueUserId = user:getUniqueUserId()

			if spec.playerRideCounter[uniqueUserId] == nil then
				spec.playerRideCounter[uniqueUserId] = 0
			end

			spec.playerRideCounter[uniqueUserId] = spec.playerRideCounter[uniqueUserId] + 1

			PlayerSuperStrength.updatePlayer(player)
		end

		if player == g_currentMission.player then
			local stats = g_currentMission:farmStats(g_currentMission.player.farmId)

			stats:updateStats("numRollercoasterRides", 1)
		end
	end

	spec.seats[seatIndex].player = nil
end

function PlaceableRollercoaster:onUserRemoved(user)
	local spec = self[PlaceableRollercoaster.SPEC]
	local userId = user:getId()

	for seatIndex, seat in ipairs(spec.seats) do
		if seat.player ~= nil and seat.player.userId == userId then
			self:exitRide(seatIndex)

			break
		end
	end
end

function PlaceableRollercoaster:registerRidersChangedListener(target, func)
	local spec = self[PlaceableRollercoaster.SPEC]
	spec.ridersChangedListeners[target] = func
end

function PlaceableRollercoaster:unregisterRidersChangedListener(target)
	local spec = self[PlaceableRollercoaster.SPEC]
	spec.ridersChangedListeners[target] = nil
end

function PlaceableRollercoaster:getAnimation()
	local spec = self[PlaceableRollercoaster.SPEC]

	return spec.animation
end

function PlaceableRollercoaster:setAnimationTime(animationTime)
	local spec = self[PlaceableRollercoaster.SPEC]

	setAnimTrackTime(spec.animation.clipCharacterSet, spec.animation.clipTrack, animationTime, true)
end

function PlaceableRollercoaster:updateFxModifierValues(dt)
	local spec = self[PlaceableRollercoaster.SPEC]
	local x, y, z = getWorldTranslation(spec.centerCart.node)
	local distance = MathUtil.vector3Length(x - spec.posX, y - spec.posY, z - spec.posZ)
	spec.posZ = z
	spec.posY = y
	spec.posX = x
	spec.speed = 0.2 * spec.speed + 0.8 * distance / (dt / 1000)

	for _, cart in ipairs(spec.carts) do
		local dx, dy, dz = localDirectionToWorld(cart.node, 0, 0, 1)
		local angleChange = MathUtil.getVectorAngleDifference(dx, 0, dz, cart.dirX, 0, cart.dirZ)

		if MathUtil.isNan(angleChange) then
			angleChange = 0
		end

		cart.angleChange = 0.6 * cart.angleChange + 0.4 * angleChange * 100
		cart.dirZ = dz
		cart.dirY = dy
		cart.dirX = dx
		dx, dy, dz = localDirectionToWorld(cart.node, 1, 0, 0)
		local slope = math.acos(dy / MathUtil.vector3Length(dx, dy, dz)) - 0.5 * math.pi
		cart.slope = 0.7 * cart.slope + 0.3 * slope
	end
end

function PlaceableRollercoaster:getParentComponent(node)
	return getParent(node)
end

function PlaceableRollercoaster:passengerCharacterLoaded(success, arguments)
	if success then
		local seat = arguments.seat

		if seat ~= nil then
			seat.vehicleCharacter:updateVisibility()
			seat.vehicleCharacter:updateIKChains()
		end
	end
end

function PlaceableRollercoaster:playerTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	if (onEnter or onLeave) and g_currentMission.player ~= nil and g_currentMission.player.rootNode == otherId then
		local spec = self[PlaceableRollercoaster.SPEC]

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

function PlaceableRollercoaster:setPlayerTriggerState(state)
	local spec = self[PlaceableRollercoaster.SPEC]

	setVisibility(spec.playerTrigger, state)
end

function PlaceableRollercoaster:getNumRides(uniqueUserId)
	local spec = self[PlaceableRollercoaster.SPEC]

	return spec.playerRideCounter[uniqueUserId] or 0
end

function PlaceableRollercoaster:getHotspot(index)
	local spec = self[PlaceableRollercoaster.SPEC]

	return spec.rollercoasterHotspot
end

function PlaceableRollercoaster:updateInfo(superFunc, infoTable)
	superFunc(self, infoTable)

	local spec = self[PlaceableRollercoaster.SPEC]
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

function PlaceableRollercoaster:getSpeedSoundModifier()
	local spec = self[PlaceableRollercoaster.SPEC]

	return spec.speed
end

g_soundManager:registerModifierType("ROLLERCOASTER_SPEED", PlaceableRollercoaster.getSpeedSoundModifier)

function PlaceableRollercoaster:getCurveSoundModifier()
	local spec = self[PlaceableRollercoaster.SPEC]

	if spec.localSeatIndex ~= nil then
		return math.abs(spec.seats[spec.localSeatIndex].cart.angleChange)
	end

	return math.abs(spec.centerCart.angleChange)
end

g_soundManager:registerModifierType("ROLLERCOASTER_CURVE", PlaceableRollercoaster.getCurveSoundModifier)

RollercoasterActivatable = {}
local RollercoasterActivatable_mt = Class(RollercoasterActivatable)

function RollercoasterActivatable.new(rollercoaster)
	local self = setmetatable({}, RollercoasterActivatable_mt)
	self.rollercoaster = rollercoaster
	self.activateText = g_i18n:getText("action_rideRollercoaster")

	return self
end

function RollercoasterActivatable:getIsActivatable()
	return self.rollercoaster:getCanEnter()
end

function RollercoasterActivatable:run()
	if self.rollercoaster:getCanEnter() then
		local seatIndex = self.rollercoaster:getFreeSeatIndex()

		if seatIndex ~= nil then
			g_client:getServerConnection():sendEvent(RollercoasterPassengerEnterRequestEvent.new(self.rollercoaster, g_currentMission.player))
		end
	end
end
