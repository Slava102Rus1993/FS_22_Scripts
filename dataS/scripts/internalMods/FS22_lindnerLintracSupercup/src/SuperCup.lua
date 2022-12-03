SuperCup = {
	STATES = {
		SETUP = 2,
		START = 3,
		IDLE = 1,
		FINISHED = 5,
		RUN = 4
	},
	RUN_FARM_ID = AccessHandler.NOBODY - 1
}
local SuperCup_mt = Class(SuperCup)

function SuperCup:new(mission, modDirectory, modName, farmId, baseNode, parent)
	local self = setmetatable({}, SuperCup_mt)
	self.version = 1
	self.debug = false
	self.isServer = mission:getIsServer()
	self.isClient = mission:getIsClient()
	self.modDirectory = modDirectory
	self.modName = modName
	self.farmId = farmId
	self.baseNode = baseNode
	self.parent = parent
	self.started = false
	self.currentPlayerUserId = nil
	self.scores = {}
	self.checkpoints = {}
	self.vehicleList = {}
	self.vehiclesToLoad = {}
	self.superCupEnterReferenceNode = baseNode
	self.superCupExitReferenceNode = baseNode
	self.mission = mission
	self.coneHandler = ConeHandler:new(baseNode, modDirectory, self.isServer, self.isClient)
	self.trafficLight = TrafficLight:new(baseNode, self.isServer, self.isClient)
	self.hud = SuperCupHUD.new(modDirectory, mission.hud.gameInfoDisplay)
	self.activatable = SuperCupActivatable:new(self)
	self.backup_maxAttachDistanceSQ = AttacherJoints.MAX_ATTACH_DISTANCE_SQ
	self.backup_maxAttachAngle = AttacherJoints.MAX_ATTACH_ANGLE

	return self
end

function SuperCup:delete()
	removeTrigger(self.triggerNode)
	self.hud:delete()
	self.stateMachine:delete()
	self.coneHandler:delete()
	self.trafficLight:delete()

	for _, checkpoint in ipairs(self.checkpoints) do
		checkpoint:delete()
	end

	self.checkpoints = {}

	for _, vehicle in ipairs(self.vehicleList) do
		if vehicle ~= nil and not vehicle.isDeleted then
			self.mission:removeVehicle(vehicle, false)
			vehicle:delete()
		end
	end

	self.vehicleList = {}
	self.vehiclesToLoad = {}
end

function SuperCup:readStream(streamId, connection)
	self.started = streamReadBool(streamId)
	local hasPlayer = streamReadBool(streamId)

	if hasPlayer then
		self.currentPlayerUserId = streamReadInt8(streamId)
	end

	local coneHandlerId = NetworkUtil.readNodeObjectId(streamId)

	self.coneHandler:readStream(streamId, connection)
	g_client:finishRegisterObject(self.coneHandler, coneHandlerId)

	for _, checkpoint in ipairs(self.checkpoints) do
		local checkpointId = NetworkUtil.readNodeObjectId(streamId)

		checkpoint:readStream(streamId, connection)
		g_client:finishRegisterObject(checkpoint, checkpointId)
	end
end

function SuperCup:writeStream(streamId, connection)
	streamWriteBool(streamId, self.started)
	streamWriteBool(streamId, self.currentPlayerUserId ~= nil)

	if self.currentPlayerUserId ~= nil then
		streamWriteInt8(streamId, self.currentPlayerUserId)
	end

	NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.coneHandler))
	self.coneHandler:writeStream(streamId, connection)
	g_server:registerObjectInStream(connection, self.coneHandler)

	for _, checkpoint in ipairs(self.checkpoints) do
		NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(checkpoint))
		checkpoint:writeStream(streamId, connection)
		g_server:registerObjectInStream(connection, checkpoint)
	end
end

function SuperCup:readUpdateStream(streamId, timestamp, connection)
	for _, checkpoint in ipairs(self.checkpoints) do
		checkpoint:readUpdateStream(streamId, timestamp, connection)
	end
end

function SuperCup:writeUpdateStream(streamId, connection, dirtyMask)
	for _, checkpoint in ipairs(self.checkpoints) do
		checkpoint:writeUpdateStream(streamId, connection, dirtyMask)
	end
end

function SuperCup.registerXMLPaths(schema, basePath)
	schema:register(XMLValueType.NODE_INDEX, basePath .. "#triggerNode", "Node to reference the trigger")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".enterReferenceNode", "Node to enter the super cup")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".exitReferenceNode", "Node to exit the super cup")
	schema:register(XMLValueType.STRING, basePath .. ".vehicles.vehicle(?)#filename", "The vehicle filename")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".vehicles.vehicle(?)#spawnNode", "Node to exit the super cup")
	schema:register(XMLValueType.BOOL, basePath .. ".vehicles.vehicle(?)#canBeEntered", "If the vehicle can be entered")
	schema:register(XMLValueType.ANGLE, basePath .. ".vehicles.vehicle(?)#rotation", "The spawn heading rotation")
	ConeHandler.registerXMLPaths(schema, basePath .. ".cones")
	TrafficLight.registerXMLPaths(schema, basePath .. ".trafficLight")
	Checkpoint.registerXMLPaths(schema, basePath .. ".checkpoints")
	ActionRequiredCheckpoint.registerXMLPaths(schema, basePath .. ".checkpoints")
end

function SuperCup:loadFromXML(xmlFile, rootXMLTag, components, i3dMappings)
	self.superCupEnterReferenceNode = xmlFile:getValue(rootXMLTag .. ".enterReferenceNode", nil, components, i3dMappings)
	self.superCupExitReferenceNode = xmlFile:getValue(rootXMLTag .. ".exitReferenceNode", nil, components, i3dMappings)
	self.triggerNode = xmlFile:getValue(rootXMLTag .. "#triggerNode", nil, components, i3dMappings)

	assert(self.triggerNode ~= nil, "Supercup needs a start trigger!")
	addTrigger(self.triggerNode, "playerEnterTriggerCallback", self)
	self.hud:loadFromXML(xmlFile, rootXMLTag)
	self.hud:setIsActive(false)
	self.hud:setFarmContext(self.farmId)
	self.coneHandler:loadFromXML(xmlFile, rootXMLTag, components, i3dMappings)
	self.coneHandler:setOwnerFarmId(self.farmId)
	self.coneHandler:register(true)
	self.trafficLight:loadFromXML(xmlFile, rootXMLTag, components, i3dMappings)
	self:loadSuperCupCheckpointsFromXML(xmlFile, rootXMLTag, components, i3dMappings)
	self:loadSuperCupVehiclesFromXML(xmlFile, rootXMLTag, components, i3dMappings)

	local function updateVehicleList(state)
		state.vehicleList = self.vehicleList
	end

	local function setStarted(state)
		if state.playerUserId == self.mission.playerUserId then
			self.mission.activatableObjectsSystem:addActivatable(self.activatable)
		end

		self.started = true
		self.currentPlayerUserId = state.playerUserId
	end

	local function setStopped(state)
		self.started = false

		self.mission.activatableObjectsSystem:removeActivatable(self.activatable)

		self.currentPlayerUserId = nil
	end

	local function setAttachRangeLimit()
	end

	local function resetAttachRangeLimit()
		AttacherJoints.MAX_ATTACH_DISTANCE_SQ = self.backup_maxAttachDistanceSQ
		AttacherJoints.MAX_ATTACH_ANGLE = self.backup_maxAttachAngle
	end

	self.stateMachine = StateEngine:new(self.parent):add(SuperCup.STATES.IDLE, AbstractState):add(SuperCup.STATES.SETUP, SetupState, {
		self.mission,
		self.checkpoints,
		self.vehiclesToLoad,
		self.vehicleList
	}):add(SuperCup.STATES.START, StartState, {
		self.mission,
		self.isServer,
		self.coneHandler,
		self.trafficLight,
		self.hud
	}):add(SuperCup.STATES.RUN, RunState, {
		self.mission,
		self.isServer,
		self.coneHandler,
		self.trafficLight,
		self.checkpoints,
		self.hud,
		self.vehicleList,
		self.parent
	}):add(SuperCup.STATES.FINISHED, FinishState, {
		self.mission,
		self.isServer,
		self.isClient,
		self,
		self.vehicleList,
		self.trafficLight,
		self.hud
	}):addEntryAction(SuperCup.STATES.START, setAttachRangeLimit):addEntryAction(SuperCup.STATES.RUN, updateVehicleList):addEntryAction(SuperCup.STATES.FINISHED, resetAttachRangeLimit):addEntryAction(SuperCup.STATES.FINISHED, updateVehicleList):addEntryAction(SuperCup.STATES.SETUP, setStarted):addEntryAction(SuperCup.STATES.FINISHED, setStopped):build()
end

function SuperCup:saveResult(score)
	table.insert(self.scores, score)

	local path = self:getFilePath()

	createFolder(path)

	local dateNow = getDate("%Y_%m_%d_%H_%M_%S")
	local folderName = ("result-%s"):format(dateNow)
	local folderPath = self:getFilePath(folderName)

	createFolder(folderPath)
	saveScreenshot(folderPath .. "/score.jpg")

	local xmlFile = self:getXMLFile(folderPath .. "/score.xml")

	if xmlFile ~= nil then
		setXMLString(xmlFile, "superCup.score.time", score.time)
		setXMLInt(xmlFile, "superCup.score.penalties", score.penalties)
		setXMLString(xmlFile, "superCup.score.player", score.playerNickname)
		setXMLString(xmlFile, "superCup.score.uuid", score.uuid)
		setXMLInt(xmlFile, "superCup.score.playerId", score.playerId)
		saveXMLFile(xmlFile)
		delete(xmlFile)
	end
end

function SuperCup:saveToXMLFile()
	local xmlFile = self:getXMLFile(self:getFilePath("superCup.xml"))

	if xmlFile ~= nil then
		local dateNow = getDate("%Y-%m-%d")
		local d = 0

		while true do
			local key = ("superCup.scores(%d)"):format(d)

			if not hasXMLProperty(xmlFile, key) then
				break
			end

			if getXMLString(xmlFile, key .. "#date") == dateNow then
				break
			end

			d = d + 1
		end

		local baseKey = ("superCup.scores(%d)"):format(d)

		setXMLString(xmlFile, baseKey .. "#date", dateNow)

		for i, score in ipairs(self.scores) do
			local key = ("%s.score(%d)"):format(baseKey, i - 1)

			setXMLString(xmlFile, key .. "#time", score.time)
			setXMLInt(xmlFile, key .. "#penalties", score.penalties)
			setXMLString(xmlFile, key .. "#player", score.playerNickname)
			setXMLString(xmlFile, key .. "#uuid", score.uuid)
			setXMLInt(xmlFile, key .. "#playerId", score.playerId)
		end

		saveXMLFile(xmlFile)
		delete(xmlFile)
	end
end

function SuperCup:getXMLFile(path)
	local xmlFile = nil

	if fileExists(path) then
		xmlFile = loadXMLFile("superCupXML", path)
	else
		xmlFile = createXMLFile("superCupXML", path, "superCup")
	end

	return xmlFile
end

function SuperCup:getFilePath(fileName)
	local basePath = getUserProfileAppPath() .. "lindnerSuperCup/"

	if fileName == nil then
		return basePath
	end

	return Utils.getFilename(fileName, basePath)
end

function SuperCup:update(dt)
	self.stateMachine:update(dt)
end

function SuperCup:draw()
	if self.mission.player ~= nil and self.hud:canInteractWithFarm(self.mission.player.farmId) then
		self.hud:draw()
	end
end

function SuperCup:getCurrentPlayerUserId()
	local playerUserId = self.mission.playerUserId

	if self.currentPlayerUserId ~= nil then
		playerUserId = self.currentPlayerUserId
	end

	return playerUserId
end

function SuperCup:onYesNoSuperCupDialog(isYes)
	if isYes then
		self:startSuperCup(self.mission.playerUserId)
	end
end

function SuperCup:setIsSuperCupStarted(isStarted)
	if isStarted then
		self:startSuperCup(self.mission.playerUserId)
	else
		self:stopSuperCup(self:getCurrentPlayerUserId())
	end
end

function SuperCup:startSuperCup(playerUserId)
	if self.isServer then
		self:onStartSuperCup(playerUserId)
	else
		g_client:getServerConnection():sendEvent(SuperCupStartEvent.new(self.parent, playerUserId))
	end
end

function SuperCup:onStartSuperCup(playerUserId)
	if self.isServer and not self.stateMachine:isInState(SuperCup.STATES.SETUP) then
		self.stateMachine:transition(SuperCup.STATES.SETUP, {
			playerUserId
		})
	end
end

function SuperCup:stopSuperCup(playerUserId)
	playerUserId = playerUserId or self:getCurrentPlayerUserId()

	if self.isServer then
		self:onStopSuperCup(playerUserId)
	else
		g_client:getServerConnection():sendEvent(SuperCupStopEvent.new(self.parent, playerUserId))
	end
end

function SuperCup:onStopSuperCup(playerUserId)
	if self.isServer and not self.stateMachine:isInState(SuperCup.STATES.FINISHED) then
		self.stateMachine:transition(SuperCup.STATES.FINISHED, {
			playerUserId
		})
	end
end

function SuperCup:loadSuperCupCheckpointsFromXML(xmlFile, rootXMLTag, components, i3dMappings)
	local i = 0

	while true do
		local key = ("%s.checkpoints.checkpoint(%d)"):format(rootXMLTag, i)

		if not xmlFile:hasProperty(key) then
			break
		end

		local className = xmlFile:getValue(key .. "#className", "Checkpoint")
		local checkpointClass = SuperCupUtil.getClassObject(className)

		if checkpointClass ~= nil then
			local checkpoint = checkpointClass:new(self.baseNode, self.isServer, self.isClient)

			checkpoint:setOwnerFarmId(self.farmId)

			if checkpoint:loadFromXML(xmlFile, key, components, i3dMappings) then
				checkpoint:register(true)
				table.insert(self.checkpoints, checkpoint)
			else
				checkpoint:delete()
			end
		end

		i = i + 1
	end
end

function SuperCup:loadSuperCupVehiclesFromXML(xmlFile, rootXMLTag, components, i3dMappings)
	if not self.isServer then
		return
	end

	local i = 0

	while true do
		local key = ("%s.vehicles.vehicle(%d)"):format(rootXMLTag, i)

		if not xmlFile:hasProperty(key) then
			break
		end

		local filename = xmlFile:getValue(key .. "#filename")
		local spawnNode = xmlFile:getValue(key .. "#spawnNode", nil, components, i3dMappings)

		if filename == nil or spawnNode == nil then
			Logging.xmlWarning("Could not find vehicle file or spawn node!")

			break
		end

		local rotation = xmlFile:getValue(key .. "#rotation", 0)

		table.insert(self.vehiclesToLoad, {
			node = spawnNode,
			filename = Utils.getFilename(filename, self.modDirectory),
			rotation = rotation,
			farmId = self.farmId,
			baseNode = self.baseNode
		})

		i = i + 1
	end
end

function SuperCup:playerEnterTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	local player = self.mission.player

	if onEnter and player ~= nil and otherId == player.rootNode and not self.started then
		if player.farmId ~= self.farmId then
			local farm = g_farmManager:getFarmById(self.farmId)

			g_gui:showInfoDialog({
				dialogType = DialogElement.TYPE_INFO,
				text = g_i18n:getText("info_joinFarm"):format(farm.name)
			})
		else
			g_gui:showYesNoDialog({
				dialogType = DialogElement.TYPE_QUESTION,
				text = g_i18n:getText("info_participate"),
				callback = self.onYesNoSuperCupDialog,
				target = self
			})
		end
	end
end
