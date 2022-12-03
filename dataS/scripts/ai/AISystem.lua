AISystem = {
	xmlSchema = nil,
	COSTMAP_MAX_VALUE = 16,
	NEXT_JOB_ID = 0
}
local AISystem_mt = Class(AISystem)

function AISystem.onCreateAIRoadSpline(_, node)
	if node ~= nil and node ~= 0 then
		local maxWidth = tonumber(getUserAttribute(node, "maxWidth"))
		local maxTurningRadius = tonumber(getUserAttribute(node, "maxTurningRadius"))

		g_currentMission.aiSystem:addRoadSpline(node, maxWidth, maxTurningRadius)
	end
end

function AISystem.new(isServer, mission, customMt)
	local self = setmetatable({}, customMt or AISystem_mt)
	self.isServer = isServer
	self.mission = mission
	self.filename = "vehicleNavigationCostmap.dat"
	self.navigationMap = nil
	self.activeJobs = {}
	self.activeJobVehicles = {}
	self.delayedRoadSplines = {}
	AISystem.xmlSchema = XMLSchema.new("aiSystem")

	self:registerXMLPaths(AISystem.xmlSchema)

	return self
end

function AISystem:registerXMLPaths(schema)
	schema:register(XMLValueType.ANGLE, "aiSystem.maxSlopeAngle", "Maximum terrain angle in degrees which is classified as drivable", 15)
	schema:register(XMLValueType.STRING, "aiSystem.blockedAreaInfoLayer#name", "Map info layer name defining areas which are blocked for AI driving", "navigationCollision")
	schema:register(XMLValueType.INT, "aiSystem.blockedAreaInfoLayer#channel", "Map info layer channel defining areas which are blocked for AI driving", 0)
	schema:register(XMLValueType.FLOAT, "aiSystem.vehicleMaxHeight", "Maximum expected vehicle height used for generating the costmap, e.g. relevant for overhanging collisions", 4)
	schema:register(XMLValueType.BOOL, "aiSystem.isLeftHandTraffic", "Map has left-hand traffic. This setting will only affect collision avoidance, traffic and ai splines need to be set up as left hand in map itself", false)
end

function AISystem:delete()
	if self.isServer then
		for i = #self.activeJobs, 1, -1 do
			local job = self.activeJobs[i]

			self:stopJob(job, AIMessageErrorUnknown.new())
		end
	end

	if self.navigationMap ~= nil then
		delete(self.navigationMap)

		self.navigationMap = nil
	end

	if self.debug ~= nil and self.debug.marker ~= nil then
		delete(self.debug.marker)
	end

	self.mission:unregisterObjectToCallOnMissionStart(self)
	removeConsoleCommand("gsAISetTarget")
	removeConsoleCommand("gsAISetLastTarget")
	removeConsoleCommand("gsAIStart")
	removeConsoleCommand("gsAIEnableDebug")
	removeConsoleCommand("gsAISplinesShow")
	removeConsoleCommand("gsAISplinesCheckInterference")
	removeConsoleCommand("gsAIStationsShow")
	removeConsoleCommand("gsAIObstaclesShow")
	removeConsoleCommand("gsAICostsShow")
	removeConsoleCommand("gsAICostsUpdate")
	removeConsoleCommand("gsAICostsExport")
end

function AISystem:loadMapData(xmlFile, missionInfo, baseDirectory)
	if g_addCheatCommands then
		if self.isServer then
			addConsoleCommand("gsAISetTarget", "Sets AI Target", "consoleCommandAISetTarget", self)
			addConsoleCommand("gsAISetLastTarget", "Sets AI Target to last position", "consoleCommandAISetLastTarget", self)
			addConsoleCommand("gsAIStart", "Starts driving to target", "consoleCommandAIStart", self)
		end

		addConsoleCommand("gsAIEnableDebug", "Enables AI debugging", "consoleCommandAIEnableDebug", self)
		addConsoleCommand("gsAISplinesShow", "Toggle AI system spline visibility", "consoleCommandAIToggleSplineVisibility", self)
		addConsoleCommand("gsAISplinesCheckInterference", "Check if AI splines interfere with any objects", "consoleCommandAICheckSplineInterference", self)
		addConsoleCommand("gsAIStationsShow", "Toggle AI system stations ai nodes visibility", "consoleCommandAIToggleAINodeDebug", self)
		addConsoleCommand("gsAIObstaclesShow", "Shows the obstacles around the camera", "consoleCommandAIShowObstacles", self)
		addConsoleCommand("gsAICostsShow", "Shows the costs per cell", "consoleCommandAIShowCosts", self)
		addConsoleCommand("gsAICostsUpdate", "Update costmap given width around the camera", "consoleCommandAISetAreaDirty", self)
		addConsoleCommand("gsAICostsExport", "Export costmap to image file", "consoleCommandAICostmapExport", self)
	end

	self.cellSizeMeters = 1
	self.maxSlopeAngle = math.rad(15)
	self.infoLayerName = "navigationCollision"
	self.infoLayerChannel = 0
	self.aiDrivableCollisionMask = CollisionFlag.AI_DRIVABLE
	self.obstacleCollisionMask = CollisionFlag.STATIC_OBJECTS + CollisionFlag.AI_BLOCKING + CollisionFlag.STATIC_OBJECT
	self.vehicleMaxHeight = 4
	self.defaultVehicleMaxWidth = 6
	self.defaultVehicleMaxTurningRadius = 20
	self.isLeftHandTraffic = false
	local relFilename = getXMLString(xmlFile, "map.aiSystem#filename")

	if relFilename ~= nil then
		local filepath = Utils.getFilename(relFilename, baseDirectory)

		if filepath ~= nil then
			local xmlFileAISystem = XMLFile.load("mapAISystem", filepath, AISystem.xmlSchema)

			if xmlFileAISystem ~= nil then
				self.maxSlopeAngle = xmlFileAISystem:getValue("aiSystem.maxSlopeAngle") or self.maxSlopeAngle
				self.infoLayerName = xmlFileAISystem:getValue("aiSystem.blockedAreaInfoLayer#name") or self.infoLayerName
				self.infoLayerChannel = xmlFileAISystem:getValue("aiSystem.blockedAreaInfoLayer#channel") or self.infoLayerChannel
				self.vehicleMaxHeight = xmlFileAISystem:getValue("aiSystem.vehicleMaxHeight") or self.vehicleMaxHeight
				self.isLeftHandTraffic = Utils.getNoNil(xmlFileAISystem:getValue("aiSystem.isLeftHandTraffic"), self.isLeftHandTraffic)

				xmlFileAISystem:delete()
			end
		end
	end

	self.debugEnabled = g_isDevelopmentVersion
	self.debug = {
		target = nil,
		isCostRenderingActive = false,
		colors = {}
	}
	self.debug.colors.default = {
		0,
		1,
		0,
		1
	}
	self.debug.colors.blocking = {
		1,
		0,
		0,
		1
	}
	self.debug.colors.spline = {
		0,
		0,
		1,
		1
	}
	self.activeJobs = {}
	self.jobsToRemove = {}
	self.roadSplines = {}

	g_i3DManager:loadI3DFileAsync("data/shared/aiMarker.i3d", false, false, self.onAIMarkerLoaded, self, nil)
end

function AISystem:onAIMarkerLoaded(node, failedReason, args)
	if node ~= 0 then
		local marker = getChildAt(node, 0)
		self.debug.marker = marker

		link(getRootNode(), marker)
		delete(node)
	end
end

function AISystem:addRoadSpline(spline, maxWidth, maxTurningRadius)
	if self.isServer and spline ~= nil then
		if self.navigationMap ~= nil then
			local defaultMaxWidth = maxWidth or self.defaultVehicleMaxWidth
			local defaultMaxTurningRadius = maxTurningRadius or self.defaultVehicleMaxTurningRadius

			addRoadsToVehicleNavigationMap(self.navigationMap, spline, defaultMaxWidth, defaultMaxTurningRadius)
			table.addElement(self.roadSplines, spline)

			if self.splinesVisible then
				setVisibility(spline, self.splinesVisible)
				I3DUtil.interateRecursively(spline, function (node)
					setVisibility(node, self.splinesVisible)
				end)
			end
		else
			table.addElement(self.delayedRoadSplines, spline)
		end
	end
end

function AISystem:removeRoadSpline(spline)
	if self.isServer and spline ~= nil then
		if self.navigationMap ~= nil then
			removeRoadsFromVehicleNavigationMap(self.navigationMap, spline)
			setVisibility(spline, false)
			table.removeElement(self.roadSplines, spline)
		else
			table.removeElement(self.delayedRoadSplines, spline)
		end
	end
end

function AISystem:onTerrainLoad(terrainNode)
	if self.isServer then
		self.navigationMap = createVehicleNavigationMap(self.cellSizeMeters, terrainNode, self.maxSlopeAngle, self.infoLayerName, self.infoLayerChannel, self.aiDrivableCollisionMask, self.obstacleCollisionMask, self.vehicleMaxHeight, self.isLeftHandTraffic)

		if self.mission.trafficSystem ~= nil then
			local roadSplineRootNodeId = self.mission.trafficSystem.rootNodeId

			self:addRoadSpline(roadSplineRootNodeId)
		end

		for i = #self.delayedRoadSplines, 1, -1 do
			local spline = table.remove(self.delayedRoadSplines, 1)

			self:addRoadSpline(spline)
		end

		local missionInfo = self.mission.missionInfo
		local loadFromSave = false

		if missionInfo.isValid and missionInfo:getIsNavigationCollisionValid(self.mission) then
			local path = missionInfo.savegameDirectory .. "/" .. self.filename
			local success = loadVehicleNavigationCostMapFromFile(self.navigationMap, path)

			if success then
				Logging.info("Loaded navigation cost map from savegame")

				loadFromSave = true
			end
		end

		if not loadFromSave then
			self.mission:registerObjectToCallOnMissionStart(self)
		end
	end

	return true
end

function AISystem:onMissionStarted()
	local worldSizeHalf = 0.5 * self.mission.terrainSize

	Logging.info("No vehicle navigation cost map found. Start scanning map...")
	updateVehicleNavigationMap(self.navigationMap, -worldSizeHalf, worldSizeHalf, -worldSizeHalf, worldSizeHalf)
end

function AISystem:loadFromXMLFile(xmlFilename)
	local xmlFile = XMLFile.load("aiSystemXML", xmlFilename)
	local x = xmlFile:getFloat("aiSystem.debug.target#posX")
	local y = xmlFile:getFloat("aiSystem.debug.target#posY")
	local z = xmlFile:getFloat("aiSystem.debug.target#posZ")
	local dirX = xmlFile:getFloat("aiSystem.debug.target#dirX")
	local dirY = xmlFile:getFloat("aiSystem.debug.target#dirY")
	local dirZ = xmlFile:getFloat("aiSystem.debug.target#dirZ")

	if x ~= nil and y ~= nil and z ~= nil and dirX ~= nil and dirY ~= nil and dirZ ~= nil then
		self.debug.target = {
			x = x,
			y = y,
			z = z,
			dirX = dirX,
			dirY = dirY,
			dirZ = dirZ
		}
	end

	xmlFile:delete()
end

function AISystem:save(xmlFilename, usedModNames)
	local xmlFile = XMLFile.create("aiSystemXML", xmlFilename, "aiSystem")

	if xmlFile ~= nil then
		local hasData = false

		if self.debug.target ~= nil then
			local target = self.debug.target

			xmlFile:setFloat("aiSystem.debug.target#posX", target.x)
			xmlFile:setFloat("aiSystem.debug.target#posY", target.y)
			xmlFile:setFloat("aiSystem.debug.target#posZ", target.z)
			xmlFile:setFloat("aiSystem.debug.target#dirX", target.dirX)
			xmlFile:setFloat("aiSystem.debug.target#dirY", target.dirY)
			xmlFile:setFloat("aiSystem.debug.target#dirZ", target.dirZ)

			hasData = true
		end

		if hasData then
			xmlFile:save()
		end

		xmlFile:delete()
	end
end

function AISystem:getNavigationMapFilename()
	return self.filename
end

function AISystem:getNavigationMap()
	return self.navigationMap
end

function AISystem:update(dt)
	for i = #self.jobsToRemove, 1, -1 do
		local job = self.jobsToRemove[i]
		local jobId = job.jobId

		table.removeElement(self.activeJobs, job)
		table.remove(self.jobsToRemove, i)
		g_messageCenter:publish(MessageType.AI_JOB_REMOVED, jobId)
	end

	for _, job in ipairs(self.activeJobs) do
		job:update(dt)

		if self.isServer and g_currentMission.isRunning then
			local price = job:getPricePerMs()

			if price > 0 then
				local difficultyMultiplier = g_currentMission.missionInfo.buyPriceMultiplier

				if GS_IS_MOBILE_VERSION then
					difficultyMultiplier = difficultyMultiplier * 0.8
				end

				price = price * dt * difficultyMultiplier

				g_currentMission:addMoney(-price, job.startedFarmId, MoneyType.AI, true)

				local farm = g_farmManager:getFarmById(job.startedFarmId)

				if farm ~= nil and farm:getBalance() + price < 0 then
					self:stopJob(job, AIMessageErrorOutOfMoney.new())
				end
			end
		end
	end
end

function AISystem:onClientJoined(connection)
	for _, job in ipairs(self.activeJobs) do
		connection:sendEvent(AIJobStartEvent.new(job, job.startedFarmId))
	end
end

function AISystem:setAreaDirty(minX, maxX, minZ, maxZ)
	if self.navigationMap ~= nil then
		updateVehicleNavigationMap(self.navigationMap, minX, maxX, minZ, maxZ)
	end
end

function AISystem:removeJob(job)
	table.insert(self.jobsToRemove, job)
end

function AISystem:addJob(job)
	table.insert(self.activeJobs, job)
end

function AISystem:getNumActiveJobs()
	return #self.activeJobs
end

function AISystem:getActiveJobs()
	return self.activeJobs
end

function AISystem:startJob(job, startFarmId)
	assert(self.isServer)

	if self.isServer then
		job:setId(AISystem.NEXT_JOB_ID)

		AISystem.NEXT_JOB_ID = AISystem.NEXT_JOB_ID + 1

		g_server:broadcastEvent(AIJobStartEvent.new(job, startFarmId))
		self:startJobInternal(job, startFarmId)
	end
end

function AISystem:startJobInternal(job, startFarmId)
	job:start(startFarmId)
	self:addJob(job)
	g_messageCenter:publish(MessageType.AI_JOB_STARTED, job, startFarmId)
end

function AISystem:stopJob(job, aiMessage)
	if self.isServer then
		self:stopJobInternal(job, aiMessage)
		g_server:broadcastEvent(AIJobStopEvent.new(job, aiMessage))
	else
		g_client:getServerConnection():sendEvent(AIJobStopEvent.new(job, aiMessage))
	end
end

function AISystem:stopJobInternal(job, aiMessage)
	job:stop(aiMessage)
	self:removeJob(job)
	g_messageCenter:publish(MessageType.AI_JOB_STOPPED, job, aiMessage)
end

function AISystem:skipCurrentTask(job)
	g_client:getServerConnection():sendEvent(AIJobSkipTaskEvent.new(job))
end

function AISystem:skipCurrentTaskInternal(job)
	job:skipCurrentTask()
end

function AISystem:getJobByIndex(index)
	return self.activeJobs[index]
end

function AISystem:stopJobById(jobId, aiMessage, noEventSend)
	local job = self:getJobById(jobId)

	if job ~= nil then
		self:stopJob(job, aiMessage, noEventSend)

		return true
	end

	return false
end

function AISystem:getJobById(jobId)
	for _, job in ipairs(self.activeJobs) do
		if job.jobId == jobId then
			return job
		end
	end

	return nil
end

function AISystem:addJobVehicle(vehicle)
	table.addElement(self.activeJobVehicles, vehicle)
end

function AISystem:removeJobVehicle(vehicle)
	table.removeElement(self.activeJobVehicles, vehicle)
end

function AISystem:getAILimitedReached()
	return g_currentMission.maxNumHirables <= #self.activeJobVehicles
end

function AISystem:getIsPositionReachable(x, y, z)
	if self.navigationMap == nil or not self.isServer then
		return true
	end

	local costs, isBlocking = getVehicleNavigationMapCostAtWorldPos(self.navigationMap, x, y, z)

	if costs == 255 or isBlocking then
		return false
	end

	return true
end

function AISystem:draw()
	if self.debug.isCostRenderingActive then
		local x, _, z = getWorldTranslation(getCamera(0))

		if self.mission.controlledVehicle ~= nil then
			local object = self.mission.controlledVehicle

			if self.mission.controlledVehicle.selectedImplement ~= nil then
				object = self.mission.controlledVehicle.selectedImplement.object
			end

			x, _, z = getWorldTranslation(object.components[1].node)
		end

		local cellSizeHalf = self.cellSizeMeters * 0.5
		x = math.floor(x / self.cellSizeMeters) * self.cellSizeMeters + cellSizeHalf
		z = math.floor(z / self.cellSizeMeters) * self.cellSizeMeters + cellSizeHalf
		local range = 15 * self.cellSizeMeters
		local terrainSizeHalf = self.mission.terrainSize * 0.5
		local minX = math.max(x - range, -terrainSizeHalf + cellSizeHalf)
		local minZ = math.max(z - range, -terrainSizeHalf + cellSizeHalf)
		local maxX = math.min(x + range, terrainSizeHalf - cellSizeHalf)
		local maxZ = math.min(z + range, terrainSizeHalf - cellSizeHalf)

		for stepZ = minZ, maxZ, self.cellSizeMeters do
			for stepX = minX, maxX, self.cellSizeMeters do
				local worldPosX = stepX
				local worldPosY = getTerrainHeightAtWorldPos(self.mission.terrainRootNode, stepX, 0, stepZ)
				local worldPosZ = stepZ
				local cost, isBlocking = getVehicleNavigationMapCostAtWorldPos(self.navigationMap, worldPosX, worldPosY, worldPosZ)
				local color = self.debug.colors.default

				if isBlocking then
					color = self.debug.colors.blocking
				else
					local r, g, b = Utils.getGreenRedBlendedColor(cost / AISystem.COSTMAP_MAX_VALUE)
					color[1] = r
					color[2] = g
					color[3] = b
				end

				Utils.renderTextAtWorldPosition(worldPosX, worldPosY, worldPosZ, string.format("%.1f", cost), getCorrectTextSize(0.015), 0, color)
			end
		end
	end
end

function AISystem:addObstacle(node, centerOffsetX, centerOffsetY, centerOffsetZ, sizeX, sizeY, sizeZ, brakeAcceleration)
	if self.isServer and self.navigationMap ~= nil and node ~= nil then
		centerOffsetX = centerOffsetX or 0
		centerOffsetY = centerOffsetY or 0
		centerOffsetZ = centerOffsetZ or 0
		sizeX = sizeX or 0
		sizeY = sizeY or 0
		sizeZ = sizeZ or 0
		brakeAcceleration = brakeAcceleration or 0

		addVehicleNavigationPhysicsObstacle(self.navigationMap, node, centerOffsetX, centerOffsetY, centerOffsetZ, sizeX, sizeY, sizeZ, brakeAcceleration)
	end
end

function AISystem:removeObstacle(node)
	if self.isServer and self.navigationMap ~= nil and node ~= nil then
		removeVehicleNavigationPhysicsObstacle(self.navigationMap, node)
	end
end

function AISystem:setObstacleIsPassable(node, isPassable)
	if self.isServer and self.navigationMap ~= nil and node ~= nil and setVehicleNavigationPhysicsObstacleIsPassable ~= nil then
		setVehicleNavigationPhysicsObstacleIsPassable(self.navigationMap, node, isPassable)
	end
end

function AISystem:consoleCommandAIShowCosts()
	if not self.isServer then
		return "gsAICostsShow is a server-only command"
	end

	self.debug.isCostRenderingActive = not self.debug.isCostRenderingActive

	if self.debug.isCostRenderingActive then
		self.mission:addDrawable(self)

		return "showCosts=true"
	else
		self.mission:removeDrawable(self)

		return "showCosts=false"
	end
end

function AISystem:consoleCommandAISetTarget(offsetX, offsetZ)
	if not self.isServer then
		return "gsAISetTarget is a server-only command"
	end

	local x = 0
	local y = 0
	local z = 0
	local dirX = 1
	local dirY = 0
	local dirZ = 0
	local _ = nil

	if self.mission.controlPlayer then
		if self.mission.player ~= nil and self.mission.player.isControlled and self.mission.player.rootNode ~= nil and self.mission.player.rootNode ~= 0 then
			x, y, z = getWorldTranslation(self.mission.player.rootNode)
			dirZ = -math.cos(self.mission.player.rotY)
			dirX = -math.sin(self.mission.player.rotY)
		end
	elseif self.mission.controlledVehicle ~= nil then
		x, y, z = getWorldTranslation(self.mission.controlledVehicle.rootNode)
		dirX, _, dirZ = localDirectionToWorld(self.mission.controlledVehicle.rootNode, 0, 0, 1)
	else
		x, y, z = getWorldTranslation(getCamera())
		dirX, _, dirZ = localDirectionToWorld(getCamera(), 0, 0, -1)
	end

	local normX, _, normZ = MathUtil.crossProduct(0, 1, 0, dirX, dirY, dirZ)
	offsetX = tonumber(offsetX) or 0
	offsetZ = tonumber(offsetZ) or 0
	x = x + dirX * offsetZ + normX * offsetX
	z = z + dirZ * offsetZ + normZ * offsetX
	self.debug.target = {
		x = x,
		y = y,
		z = z,
		dirX = dirX,
		dirY = dirY,
		dirZ = dirZ
	}
	local marker = self.debug.marker

	if marker ~= nil then
		setWorldTranslation(marker, x, y, z)
		setDirection(marker, dirX, dirY, dirZ, 0, 1, 0)
	end

	return "Set AI Target"
end

function AISystem:consoleCommandAISetLastTarget()
	if not self.isServer then
		return "gsAISetLastTarget is a server-only command"
	end

	if self.debug.target ~= nil then
		local x = self.debug.target.x
		local y = self.debug.target.y
		local z = self.debug.target.z
		local dirX = self.debug.target.dirX
		local dirY = self.debug.target.dirY
		local dirZ = self.debug.target.dirZ
		local marker = self.debug.marker

		if marker ~= nil then
			setWorldTranslation(marker, x, y, z)
			setDirection(marker, dirX, dirY, dirZ, 0, 1, 0)
		end

		return "Set target to last target"
	else
		return "No last target found"
	end
end

function AISystem:consoleCommandAIStart()
	if not self.isServer then
		return "Only available on server"
	end

	if self.mission.controlledVehicle == nil then
		return "Please enter a vehicle first"
	end

	local target = self.debug.target

	if target == nil then
		return "Please set a target first"
	end

	local job = g_currentMission.aiJobTypeManager:createJob(AIJobType.GOTO)
	local angle = MathUtil.getYRotationFromDirection(target.dirX, target.dirZ)

	job.vehicleParameter:setVehicle(self.mission.controlledVehicle)
	job.positionAngleParameter:setPosition(target.x, target.z)
	job.positionAngleParameter:setAngle(angle)
	job:setValues()

	local success, errorMessage = job:validate(g_currentMission.player.farmId)

	if success then
		self:startJob(job, g_currentMission.player.farmId)

		return "Started ai..."
	else
		return "Error: " .. tostring(errorMessage)
	end
end

function AISystem:consoleCommandAIEnableDebug()
	self.debugEnabled = not self.debugEnabled

	return "debugEnabled=" .. tostring(self.debugEnabled)
end

function AISystem:consoleCommandAIToggleSplineVisibility()
	self.splinesVisible = not self.splinesVisible

	if self.splinesVisible then
		self.splineDebugElements = {}
		local debugMat = g_debugManager:getDebugMat()

		for _, roadSplineOrTG in ipairs(self.roadSplines) do
			if I3DUtil.getIsSpline(roadSplineOrTG) then
				self.splineDebugElements[roadSplineOrTG] = true
			end

			I3DUtil.interateRecursively(roadSplineOrTG, function (node)
				if I3DUtil.getIsSpline(node) then
					self.splineDebugElements[node] = true
				end
			end)
		end

		for spline in pairs(self.splineDebugElements) do
			DebugUtil.setNodeEffectivelyVisible(spline)

			local r, g, b = unpack(DebugUtil.getDebugColor(spline))

			setMaterial(spline, debugMat, 0)
			setShaderParameter(spline, "color", r, g, b, 0, false)
			setShaderParameter(spline, "alpha", 1, 0, 0, 0, false)

			local debugElements = DebugUtil.getSplineDebugElements(spline)
			self.splineDebugElements[spline] = debugElements

			for elemName, debugElement in pairs(debugElements) do
				if elemName == "splineAttributes" then
					debugElement:setColor(r, g, b)
				end

				g_debugManager:addPermanentElement(debugElement)
			end
		end
	else
		for spline, debugElements in pairs(self.splineDebugElements) do
			for _, debugElement in pairs(debugElements) do
				g_debugManager:removePermanentElement(debugElement)
			end

			if entityExists(spline) then
				setVisibility(spline, false)
			end
		end

		self.splineDebugElements = nil
	end

	if g_currentMission.trafficSystem ~= nil and g_currentMission.trafficSystem.rootNodeId ~= nil then
		setVisibility(g_currentMission.trafficSystem.rootNodeId, self.splinesVisible)
	end

	return "AISystem.splinesVisible=" .. tostring(self.splinesVisible)
end

function AISystem:consoleCommandAIToggleAINodeDebug()
	self.stationsAINodesVisible = not self.stationsAINodesVisible

	if self.stationsAINodesVisible then
		self.stationsAINodesDebugElements = {}

		for _, unloadingStation in pairs(g_currentMission.storageSystem:getUnloadingStations()) do
			if unloadingStation:isa(UnloadingStation) then
				local x, _, _, _, unloadTrigger = unloadingStation:getAITargetPositionAndDirection(FillType.UNKNOWN)

				if x ~= nil then
					local text = "UnloadingStation: " .. unloadingStation:getName()
					local gizmo = DebugGizmo.new():createWithNode(unloadTrigger.aiNode, text, nil, , , false, true)

					g_debugManager:addPermanentElement(gizmo)
					table.insert(self.stationsAINodesDebugElements, gizmo)
				end
			end
		end

		for _, loadingStation in pairs(g_currentMission.storageSystem:getLoadingStations()) do
			local x, _, _, _, loadTrigger = loadingStation:getAITargetPositionAndDirection(FillType.UNKNOWN)

			if x ~= nil then
				local text = "LoadingStation: " .. loadingStation:getName()
				local gizmo = DebugGizmo.new():createWithNode(loadTrigger.aiNode, text, nil, , , false, true)

				g_debugManager:addPermanentElement(gizmo)
				table.insert(self.stationsAINodesDebugElements, gizmo)
			end
		end
	else
		for _, gizmo in pairs(self.stationsAINodesDebugElements) do
			g_debugManager:removePermanentElement(gizmo)
			gizmo:delete()
		end

		self.stationsAINodesDebugElements = nil
	end

	if self.stationsAINodesVisible then
		Logging.warning("Nodes in reloaded placeables are not updated automatically. Toggle this command again to update the station nodes if placeables were reloaded.")
	end

	return "AISystem.stationsAINodesVisible=" .. tostring(self.stationsAINodesVisible)
end

function AISystem:consoleCommandAIShowObstacles()
	if not self.isServer then
		return "gsAIObstaclesShow is a server-only command"
	end

	self.mapDebugRenderingEnabled = not self.mapDebugRenderingEnabled

	enableVehicleNavigationMapDebugRendering(self.navigationMap, self.mapDebugRenderingEnabled)

	return "AIShowObstacles=" .. tostring(self.mapDebugRenderingEnabled)
end

function AISystem:consoleCommandAISetAreaDirty(width)
	if not self.isServer then
		return "gsAICostsUpdate is a server-only command"
	end

	local x, _, z = getWorldTranslation(getCamera(0))
	width = MathUtil.clamp(tonumber(width) or 30, 2, 1000)
	local halfWidth = width / 2

	self:setAreaDirty(x - halfWidth, z - halfWidth, x + halfWidth, z + halfWidth)

	return string.format("Updated costmap in a %dx%d area", width, width)
end

function AISystem:consoleCommandAICostmapExport(imageFormatStr)
	if not self.isServer then
		return "gsAICostsExport is a server-only command"
	end

	if g_currentMission.missionInfo.savegameDirectory == nil then
		return "Error: Savegame directory does not exist yet, please save the game first"
	end

	local imageFormat = BitmapUtil.FORMAT.PIXELMAP

	if imageFormatStr ~= nil then
		imageFormat = BitmapUtil.FORMAT[imageFormatStr:upper()]

		if imageFormat == nil then
			Logging.error("Unknown image format '%s'. Available formats: %s", imageFormatStr, table.concatKeys(BitmapUtil.FORMAT, ", "))

			return "Error: Costmap export failed"
		end
	end

	local terrainSizeHalf = self.mission.terrainSize * 0.5
	local cellSizeHalf = self.cellSizeMeters / 2
	local imageSize = self.mission.terrainSize
	local isGreymap = imageFormat == BitmapUtil.FORMAT.GREYMAP
	local colorBlocking = self.debug.colors.blocking
	local colorSpline = self.debug.colors.spline
	local splines = {}

	for _, roadSplineOrTG in ipairs(self.roadSplines) do
		if I3DUtil.getIsSpline(roadSplineOrTG) then
			splines[roadSplineOrTG] = true
		end

		I3DUtil.interateRecursively(roadSplineOrTG, function (node)
			if I3DUtil.getIsSpline(node) then
				splines[node] = true
			end
		end)
	end

	local posToHasSpline = {}

	for spline in pairs(splines) do
		local splineLength = getSplineLength(spline)

		for splineTime = 0, 1, 1 / splineLength do
			local wx, _, wz = getSplinePosition(spline, splineTime)
			local xInt = MathUtil.round(wx)
			local zInt = MathUtil.round(wz)
			posToHasSpline[xInt] = posToHasSpline[xInt] or {}
			posToHasSpline[xInt][zInt] = true
		end
	end

	local function getPixelsIterator()
		local stepZ = -terrainSizeHalf + cellSizeHalf
		local stepX = -terrainSizeHalf + cellSizeHalf
		local pixel = {
			0,
			0,
			0
		}

		return function ()
			if stepZ > terrainSizeHalf - cellSizeHalf then
				return nil
			end

			local worldPosY = getTerrainHeightAtWorldPos(self.mission.terrainRootNode, stepX, 0, stepZ)
			local cost, isBlocking = getVehicleNavigationMapCostAtWorldPos(self.navigationMap, stepX, worldPosY, stepZ)
			local xInt = MathUtil.round(stepX)
			local zInt = MathUtil.round(stepZ)
			local posHasSpline = posToHasSpline[xInt] and posToHasSpline[xInt][zInt]

			if isGreymap then
				if posHasSpline then
					pixel[1] = 1
				else
					pixel[1] = cost
				end

				pixel[1] = pixel[1] / AISystem.COSTMAP_MAX_VALUE * 255
			else
				if posHasSpline then
					pixel[3] = colorSpline[3]
					pixel[2] = colorSpline[2]
					pixel[1] = colorSpline[1]
				elseif isBlocking then
					pixel[3] = colorBlocking[3]
					pixel[2] = colorBlocking[2]
					pixel[1] = colorBlocking[1]
				else
					pixel[1], pixel[2], pixel[3] = Utils.getGreenRedBlendedColor(cost / AISystem.COSTMAP_MAX_VALUE)
				end

				pixel[3] = pixel[3] * 255
				pixel[2] = pixel[2] * 255
				pixel[1] = pixel[1] * 255
			end

			if stepX < terrainSizeHalf - self.cellSizeMeters then
				stepX = stepX + self.cellSizeMeters
			else
				stepX = -terrainSizeHalf + cellSizeHalf
				stepZ = stepZ + self.cellSizeMeters
			end

			return pixel
		end
	end

	if not BitmapUtil.writeBitmapToFileFromIterator(getPixelsIterator, imageSize, imageSize, g_currentMission.missionInfo.savegameDirectory .. "/navigationMap", imageFormat) then
		return "Error: Costmap export failed"
	end

	return "Finished costmap export"
end

function AISystem:consoleCommandAICheckSplineInterference(stepLength, heightOffset, defaultSplineWidth)
	local usage = "gsAISplineCheckInterference [stepLength] [heightOffset] [defaultSplineWidth]\nUse 'gsDebugManagerClearElements' to remove boxes."
	self.debugLastPos = {}

	self:debugDeleteInterferences()

	self.debugInterferencePositions = {}
	self.debugInterferences = {}
	stepLength = tonumber(stepLength) or 5
	heightOffset = tonumber(heightOffset) or 0.2
	defaultSplineWidth = tonumber(defaultSplineWidth) or self.defaultVehicleMaxWidth
	local collisionMask = CollisionMask.ALL - CollisionFlag.TERRAIN
	local overlapFactor = 0.9

	Logging.info("Checking interference: stepLength=%.2f heightOffset=%.2f defaultSplineWidth=%.2f", stepLength, heightOffset, defaultSplineWidth)

	local numSplines = 0
	local testPosition = createTransformGroup("testPosition")
	local splineMaxWidth = nil

	local function checkInterference(spline)
		numSplines = numSplines + 1
		local splineWidth = getUserAttribute(spline, "maxWidth") or splineMaxWidth or defaultSplineWidth
		local splineLength = getSplineLength(spline)
		local stepSize = stepLength * overlapFactor / splineLength

		for offset = 0, 1 + stepSize, stepSize do
			local clampedSplineTime = MathUtil.clamp(offset, 0, 1)
			local wx, wy, wz = getSplinePosition(spline, clampedSplineTime)
			local dx, dy, dz = getSplineDirection(spline, clampedSplineTime)

			setWorldTranslation(testPosition, wx, wy, wz)
			setDirection(testPosition, dx, dy, dz, 0, 1, 0)

			local rx, ry, rz = getWorldRotation(testPosition)
			local sx = splineWidth / 2
			local sy = self.vehicleMaxHeight / 2 - heightOffset / 2
			local sz = stepLength / 2
			wy = wy + sy + heightOffset
			self.debugLastPos = {
				rx = rx,
				ry = ry,
				rz = rz,
				sx = sx,
				sy = sy,
				sz = sz,
				wx = wx,
				wy = wy,
				wz = wz,
				spline = spline
			}

			overlapBox(wx, wy, wz, rx, ry, rz, sx, sy, sz, "splineInterferenceOverlapCallback", self, collisionMask, true, true, true, false)
		end
	end

	local function filterSplines(node, depth)
		if I3DUtil.getIsSpline(node) then
			checkInterference(node)
		else
			splineMaxWidth = getUserAttribute(node, "maxWidth")
		end
	end

	for _, aiSpline in ipairs(self.roadSplines) do
		I3DUtil.interateRecursively(aiSpline, filterSplines)
	end

	delete(testPosition)

	local numInterferences = table.size(self.debugInterferences)
	self.debugInterferences = nil
	self.debugLastPos = nil

	return string.format("Checked %d splines, found %d interferences\n%s", numSplines, numInterferences, usage)
end

function AISystem:splineInterferenceOverlapCallback(nodeId)
	if nodeId ~= 0 and nodeId ~= g_currentMission.terrainRootNode and not CollisionFlag.getHasFlagSet(nodeId, CollisionFlag.VEHICLE) and CollisionFlag.getHasFlagSet(nodeId, CollisionFlag.AI_BLOCKING) then
		local last = self.debugLastPos
		local customWidth = getUserAttribute(nodeId, "maxWidth")
		local customWidthText = customWidth and string.format(" (maxWidth UserAttribute: %.2f)", customWidth) or ""

		Logging.info("found interference for spline '%s'%s with object '%s|%s' at %d %d %d", getName(last.spline), customWidthText, getName(getParent(nodeId)), getName(nodeId), last.wx, last.wy, last.wz)

		local debugFunctionPair = {
			DebugUtil.drawOverlapBox,
			{
				last.wx,
				last.wy,
				last.wz,
				last.rx,
				last.ry,
				last.rz,
				last.sx,
				last.sy,
				last.sz
			}
		}

		table.insert(self.debugInterferencePositions, debugFunctionPair)
		g_debugManager:addPermanentFunction(debugFunctionPair)

		self.debugInterferences[nodeId] = true
	end
end

function AISystem:debugDeleteInterferences()
	if self.debugInterferencePositions ~= nil then
		for _, debugFunctionPair in ipairs(self.debugInterferencePositions) do
			g_debugManager:removePermanentFunction(debugFunctionPair)
		end
	end
end

function AISystem.getAgentStateName(index)
	for k, v in pairs(AgentState) do
		if v == index then
			return k
		end
	end

	return "UNKNOWN"
end
