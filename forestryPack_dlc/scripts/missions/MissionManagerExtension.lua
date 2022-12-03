local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

MissionManager.CATEGORY_FORESTRY = 4

local function postInitDataStructures(self)
	self.forestryMissions = {}
	self.activeTreeMissions = {}
	self.activeRockMissions = {}
	self.possibleForestryMissionsWeighted = {}
	self.deadwoodMission = {
		spots = {}
	}
	self.treeTransportMission = {
		spots = {}
	}
	self.destructibleRockMission = {
		spots = {},
		spotsDisabled = {}
	}
end

MissionManager.initDataStructures = Utils.appendedFunction(MissionManager.initDataStructures, postInitDataStructures)

local function postLoadMapData(self, xmlFile)
	postInitDataStructures(self)

	local missionXmlFilename = getXMLString(xmlFile, "map.forestryMissions#filename")

	if missionXmlFilename ~= nil then
		local _, baseDirectory = Utils.getModNameAndBaseDirectory(getXMLFilename(xmlFile))
		local filename = Utils.getFilename("map/forestryMissions.xml", baseDirectory)
		local forestryMissionXml = loadXMLFile("ForestryMission", filename)

		if forestryMissionXml ~= 0 then
			self:loadDeadwoodMissionData(forestryMissionXml, "forestryMissions.deadwoodMission", baseDirectory)
			self:loadTransportMissionData(forestryMissionXml, "forestryMissions.transportMission", baseDirectory)
			self:loadDestructibleRockMissionData(forestryMissionXml, "forestryMissions.destructibleRockMission", baseDirectory)
			delete(forestryMissionXml)

			if g_currentMission:getIsServer() then
				for _, missionType in ipairs(self.missionTypes) do
					if missionType.category == MissionManager.CATEGORY_FORESTRY then
						for _ = 1, missionType.priority do
							table.insert(self.possibleForestryMissionsWeighted, missionType)
						end
					end
				end
			end
		end
	end
end

MissionManager.loadMapData = Utils.appendedFunction(MissionManager.loadMapData, postLoadMapData)

local function preUnloadMapData(self)
	if self.treeTransportMission ~= nil then
		if self.treeTransportMission.spotRoot ~= nil then
			delete(self.treeTransportMission.spotRoot)
		end

		if self.treeTransportMission.cachedTreeRequestId ~= nil then
			g_i3DManager:releaseSharedI3DFile(self.treeTransportMission.cachedTreeRequestId)
		end
	end

	if self.destructibleRockMission ~= nil and self.destructibleRockMission.markerNode ~= nil then
		delete(self.destructibleRockMission.markerNode)

		self.destructibleRockMission.markerNode = nil
	end

	for _, missionType in ipairs(self.missionTypes) do
		if missionType.classObject.unloadMapData ~= nil then
			missionType.classObject.unloadMapData()
		end
	end

	self.possibleForestryMissionsWeighted = {}
end

MissionManager.unloadMapData = Utils.prependedFunction(MissionManager.unloadMapData, preUnloadMapData)

local function overwrittenLoadFromXMLFile(self, superFunc, xmlFilename)
	local ret = superFunc(self, xmlFilename)

	if not ret then
		return ret
	end

	return ret
end

MissionManager.loadFromXMLFile = Utils.overwrittenFunction(MissionManager.loadFromXMLFile, overwrittenLoadFromXMLFile)

local function postGenerateMissions(self, dt)
	local createdAnyMission = false

	Utils.shuffle(self.possibleForestryMissionsWeighted)

	for _, missionType in ipairs(self.possibleForestryMissionsWeighted) do
		local canRun = missionType.classObject.canRun()

		if canRun then
			local mission, spots = nil

			if missionType.name == "deadwood" then
				spots = self.deadwoodMission.spots
			elseif missionType.name == "treeTransport" then
				spots = self.treeTransportMission.spots
			elseif missionType.name == "destructibleRocks" then
				spots = table.ifilter(self.destructibleRockMission.spots, function (spot)
					return self.destructibleRockMission.spotsDisabled[spot] == nil
				end)
			end

			if spots ~= nil then
				Utils.shuffle(spots)

				local blockedFarmlands = {}

				for _, activeMission in ipairs(self.activeTreeMissions) do
					if activeMission.type == missionType then
						blockedFarmlands[activeMission.spot.farmlandId] = true
					end
				end

				local foundSpot = nil

				for _, spot in ipairs(spots) do
					if not spot.isInUse and blockedFarmlands[spot.farmlandId] == nil and g_farmlandManager:getFarmlandOwner(spot.farmlandId) == FarmlandManager.NO_OWNER_FARM_ID then
						foundSpot = spot

						break
					end
				end

				if foundSpot then
					mission = missionType.classObject.new(true, g_client ~= nil)
					mission.type = missionType

					if not mission:init(foundSpot) then
						mission:delete()

						mission = nil
					end
				end
			end

			if mission ~= nil then
				self:assignGenerationTime(mission)
				mission:register()
				table.insert(self.missions, mission)

				createdAnyMission = true

				break
			end
		end
	end

	if createdAnyMission then
		g_messageCenter:publish(MessageType.MISSION_GENERATED)
	end
end

MissionManager.generateMissions = Utils.appendedFunction(MissionManager.generateMissions, postGenerateMissions)

local function postUpdateMissions(self, dt)
	for _, mission in ipairs(self.activeTreeMissions) do
		if not mission:validate() then
			mission:delete()
		end
	end

	for _, mission in ipairs(self.activeRockMissions) do
		if not mission:validate() then
			mission:delete()
		end
	end
end

MissionManager.updateMissions = Utils.appendedFunction(MissionManager.updateMissions, postUpdateMissions)

function MissionManager:getMissionBySplitShape(shape)
	if shape == nil or shape == 0 then
		return nil
	end

	for _, mission in ipairs(self.activeTreeMissions) do
		if mission.status == AbstractMission.STATUS_RUNNING and mission:getIsMissionSplitShape(shape) then
			return mission
		end
	end

	return nil
end

function MissionManager:getIsShapeCutAllowed(shape, x, z, farmId)
	for _, mission in ipairs(self.activeTreeMissions) do
		local isAllowed = mission:getIsShapeCutAllowed(shape, x, z, farmId)

		if isAllowed ~= nil then
			return isAllowed
		end
	end

	return nil
end

function MissionManager:getIsForestryMissionDestructible(farmId, nodeId)
	for _, mission in ipairs(self.activeRockMissions) do
		if mission.status == AbstractMission.STATUS_RUNNING and mission.farmId == farmId and mission:getDestructibleIsInMissionArea(nodeId, farmId) then
			return true
		end
	end

	return false
end

function MissionManager:toggleDeadwoodSpots()
	self.debugRenderDeadwoodSpotsActive = not self.debugRenderDeadwoodSpotsActive

	if self.debugRenderDeadwoodSpotsActive then
		g_currentMission:addDrawable(self.deadwoodMissionDebug)
	else
		g_currentMission:removeDrawable(self.deadwoodMissionDebug)
	end
end

function MissionManager:toggleTreeTransportSpots()
	self.debugRenderTreeTransportSpotsActive = not self.debugRenderTreeTransportSpotsActive

	if self.debugRenderTreeTransportSpotsActive then
		g_currentMission:addDrawable(self.treeTransportMissionDebug)
	else
		g_currentMission:removeDrawable(self.treeTransportMissionDebug)
	end
end

function MissionManager:toggleRockSpots()
	self.debugRenderRockSpotsActive = not self.debugRenderRockSpotsActive

	if self.debugRenderRockSpotsActive then
		g_currentMission:addDrawable(self.rockMissionDebug)
	else
		g_currentMission:removeDrawable(self.rockMissionDebug)
	end
end

function MissionManager:addActiveTreeMission(mission)
	table.addElement(self.activeTreeMissions, mission)
end

function MissionManager:removeActiveTreeMission(mission)
	table.removeElement(self.activeTreeMissions, mission)
end

function MissionManager:addActiveRockMission(mission)
	table.addElement(self.activeRockMissions, mission)
end

function MissionManager:removeActiveRockMission(mission)
	table.removeElement(self.activeRockMissions, mission)
end

function MissionManager:disableDestructibleRockMissionSpot(spot)
	self.destructibleRockMission.spotsDisabled[spot] = true
end

function MissionManager:loadDeadwoodMissionData(xmlFile, key, baseDirectory)
	local treeTypeName = getXMLString(xmlFile, key .. "#treeType")
	local treeDesc = g_treePlantManager:getTreeTypeDescFromName(treeTypeName)

	if treeDesc ~= nil then
		self.deadwoodMission.treeIndex = treeDesc.index
		self.deadwoodMission.rewardPerTree = getXMLFloat(xmlFile, key .. "#rewardPerTree") or 350
		self.deadwoodMission.penaltyPerTree = getXMLFloat(xmlFile, key .. "#penaltyPerTree") or 3500
		local spotFilename = getXMLString(xmlFile, key .. ".spots#filename")

		if spotFilename ~= nil then
			spotFilename = Utils.getFilename(spotFilename, baseDirectory)
			local i3dNode = g_i3DManager:loadI3DFile(spotFilename, false, false)

			if i3dNode ~= 0 then
				local root = getChildAt(i3dNode, 0)

				for i = 0, getNumOfChildren(root) - 1 do
					local spotNode = getChildAt(root, i)
					local x, y, z = getTranslation(spotNode)
					local radius = tonumber(getUserAttribute(spotNode, "radius"))

					if radius ~= nil then
						local farmlandId = g_farmlandManager:getFarmlandIdAtWorldPosition(x, z)
						y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, y, z)
						local spot = {
							isInUse = false,
							index = #self.deadwoodMission.spots + 1,
							x = x,
							y = y,
							z = z,
							radius = radius,
							farmlandId = farmlandId
						}

						table.insert(self.deadwoodMission.spots, spot)
					end
				end

				delete(i3dNode)

				if #self.deadwoodMission.spots > 0 and g_isDevelopmentVersion then
					addConsoleCommand("gsMissionDeadwoodSpotsShow", "Shows the deadwood spots", "toggleDeadwoodSpots", self)

					self.deadwoodMissionDebug = {}
					local spots = self.deadwoodMission.spots

					function self.deadwoodMissionDebug.draw()
						for k, spot in ipairs(spots) do
							local steps = 20
							local x = spot.x
							local y = spot.y
							local z = spot.z
							local radius = spot.radius
							local color = DebugUtil.getDebugColor(k)

							DebugUtil.drawDebugCircle(x, y, z, radius, steps, color, true, true)
						end
					end
				end
			end
		else
			Logging.warning("Missing spot definition file")
		end
	else
		Logging.warning("Missing or undefined treeType for deadwood mission!")
	end
end

function MissionManager:loadDestructibleRockMissionData(xmlFile, key, baseDirectory)
	self.destructibleRockMission.rewardPerRock = getXMLFloat(xmlFile, key .. "#rewardPerRock") or 350
	self.destructibleRockMission.penaltyPerRock = getXMLFloat(xmlFile, key .. "#penaltyPerRock") or 3500
	local spotFilename = getXMLString(xmlFile, key .. ".spots#filename")

	if spotFilename ~= nil then
		spotFilename = Utils.getFilename(spotFilename, baseDirectory)
		local i3dNode = g_i3DManager:loadI3DFile(spotFilename, false, false)

		if i3dNode ~= 0 then
			local root = getChildAt(i3dNode, 0)

			for i = 0, getNumOfChildren(root) - 1 do
				local spotNode = getChildAt(root, i)
				local x, y, z = getTranslation(spotNode)
				local radius = tonumber(getUserAttribute(spotNode, "radius"))

				if radius ~= nil then
					local farmlandId = g_farmlandManager:getFarmlandIdAtWorldPosition(x, z)
					y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, y, z)
					local spot = {
						isInUse = false,
						index = #self.destructibleRockMission.spots + 1,
						x = x,
						y = y,
						z = z,
						radius = radius,
						farmlandId = farmlandId
					}

					table.insert(self.destructibleRockMission.spots, spot)
				end
			end

			delete(i3dNode)

			if #self.destructibleRockMission.spots > 0 and g_isDevelopmentVersion then
				addConsoleCommand("gsMissionRockSpotsShow", "Shows the rock spots", "toggleRockSpots", self)

				self.rockMissionDebug = {}
				local spots = self.destructibleRockMission.spots

				function self.rockMissionDebug.draw()
					for k, spot in ipairs(spots) do
						local steps = 20
						local x = spot.x
						local y = spot.y
						local z = spot.z
						local radius = spot.radius
						local color = DebugUtil.getDebugColor(k)

						DebugUtil.drawDebugCircle(x, y, z, radius, steps, color, true, true)
					end
				end
			end
		end
	end

	local markerFilename = getXMLString(xmlFile, key .. ".marker#filename")

	if markerFilename ~= nil then
		markerFilename = Utils.getFilename(markerFilename, baseDirectory)
		local i3dNode = g_i3DManager:loadI3DFile(markerFilename, false, false)

		if i3dNode ~= 0 then
			local markerNode = getChildAt(i3dNode, 0)

			link(getRootNode(), markerNode)

			self.destructibleRockMission.markerNode = markerNode

			delete(i3dNode)
		end
	end
end

function MissionManager:loadTransportMissionData(xmlFile, key, baseDirectory)
	local treeTypeName = getXMLString(xmlFile, key .. "#treeType")
	local treeDesc = g_treePlantManager:getTreeTypeDescFromName(treeTypeName)

	if treeDesc ~= nil then
		self.treeTransportMission.treeIndex = treeDesc.index
		self.treeTransportMission.rewardPerTree = getXMLFloat(xmlFile, key .. "#rewardPerTree") or 350
		self.treeTransportMission.penaltyPerTree = getXMLFloat(xmlFile, key .. "#penaltyPerTree") or 3500
		local spotFilename = getXMLString(xmlFile, key .. ".spots#filename")

		if spotFilename ~= nil then
			spotFilename = Utils.getFilename(spotFilename, baseDirectory)
			local i3dNode = g_i3DManager:loadI3DFile(spotFilename, false, false)

			if i3dNode ~= 0 then
				local root = getChildAt(i3dNode, 0)

				link(getRootNode(), root)

				for i = 0, getNumOfChildren(root) - 1 do
					local spotNode = getChildAt(root, i)
					local x, y, z = getTranslation(spotNode)
					local farmlandId = g_farmlandManager:getFarmlandIdAtWorldPosition(x, z)
					y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, y, z)
					local sizeX = tonumber(getUserAttribute(spotNode, "sizeX")) or 1
					local sizeY = tonumber(getUserAttribute(spotNode, "sizeY")) or 1
					local sizeZ = tonumber(getUserAttribute(spotNode, "sizeZ")) or 1
					local spot = {
						isInUse = false,
						node = spotNode,
						index = #self.treeTransportMission.spots + 1,
						x = x,
						y = y,
						z = z,
						farmlandId = farmlandId,
						sizeX = sizeX,
						sizeY = sizeY,
						sizeZ = sizeZ
					}

					table.insert(self.treeTransportMission.spots, spot)
				end

				self.treeTransportMission.spotRoot = root

				delete(i3dNode)

				if #self.treeTransportMission.spots > 0 and g_isDevelopmentVersion then
					addConsoleCommand("gsMissionTreeTransportSpotsShow", "Shows the tree transport spots", "toggleTreeTransportSpots", self)

					self.treeTransportMissionDebug = {}
					local spots = self.treeTransportMission.spots

					function self.treeTransportMissionDebug.draw()
						for k, spot in ipairs(spots) do
							local steps = 20
							local x = spot.x
							local y = spot.y
							local z = spot.z
							local radius = 5
							local color = DebugUtil.getDebugColor(k)

							DebugUtil.drawDebugCircle(x, y, z, radius, steps, color, true, true)
						end
					end
				end
			end
		else
			Logging.warning("Missing spot definition file")
		end
	else
		Logging.warning("Missing or undefined treeType for tree transport mission!")
	end
end
