local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

DestructibleRockMission = {
	CUSTOM_ENVIRONMENT = g_currentModName,
	NUM_INSTANCES = 0,
	MAX_NUM_INSTANCES = 2,
	MIN_NUM_ROCKS = 4,
	MAX_NUM_ROCKS = 10,
	COLLISION_MASK = CollisionFlag.STATIC_OBJECT
}
local DestructibleRockMission_mt = Class(DestructibleRockMission, AbstractMission)

InitObjectClass(DestructibleRockMission, "DestructibleRockMission")

function DestructibleRockMission.new(isServer, isClient, customMt)
	local self = AbstractMission.new(isServer, isClient, customMt or DestructibleRockMission_mt)
	self.spot = nil
	self.rocks = {}
	self.rocksKeys = {}
	self.rocksAll = {}
	self.rocksAllKeys = {}
	self.rockToMarker = {}
	self.markerRootNode = nil
	self.numRocksDestroyed = 0
	self.wronglyDestroyedRocksPenalty = 0
	self.mapHotspot = nil
	self.mission = g_currentMission

	g_currentMission.destructibleMapObjectSystem:registerDestructibleDestroyedListener(self, self.onRockDestroyed)

	DestructibleRockMission.NUM_INSTANCES = DestructibleRockMission.NUM_INSTANCES + 1

	g_missionManager:addActiveRockMission(self)

	return self
end

function DestructibleRockMission:init(spot)
	local res = DestructibleRockMission:superClass().init(self)

	if spot == nil then
		return false
	end

	self:setSpot(spot)
	overlapSphere(spot.x, spot.y, spot.z, self.spot.radius, "overlapCallback", self, DestructibleRockMission.COLLISION_MASK, false, true, false, false)

	if #self.rocks < DestructibleRockMission.MIN_NUM_ROCKS then
		g_missionManager:disableDestructibleRockMissionSpot(spot)

		return false
	end

	self.reward = #self.rocks * g_missionManager.destructibleRockMission.rewardPerRock

	return res
end

function DestructibleRockMission:overlapCallback(transformId)
	if transformId ~= 0 and getHasClassId(transformId, ClassIds.SHAPE) then
		local destructible = g_currentMission.destructibleMapObjectSystem:getDestructibleFromNode(transformId)

		if destructible ~= nil then
			local x, _, z = getWorldTranslation(transformId)
			local farmlandId = g_farmlandManager:getFarmlandIdAtWorldPosition(x, z)

			if farmlandId == self.farmlandId then
				local rocksMaxReached = DestructibleRockMission.MAX_NUM_ROCKS <= #self.rocks
				local rocksMinReached = DestructibleRockMission.MIN_NUM_ROCKS <= #self.rocks
				local isPartOfMission = not rocksMinReached or not rocksMaxReached and Utils.getCoinToss()

				self:addDestructible(destructible, isPartOfMission)
			end
		end
	end

	return true
end

function DestructibleRockMission:addDestructible(destructible, isPartOfMission)
	if isPartOfMission then
		table.insert(self.rocks, destructible)

		self.rocksKeys[destructible] = true
	end

	table.insert(self.rocksAll, destructible)

	self.rocksAllKeys[destructible] = true
end

function DestructibleRockMission:setSpot(spot)
	self.spot = spot
	spot.isInUse = true
	self.farmlandId = spot.farmlandId
end

function DestructibleRockMission:delete()
	DestructibleRockMission:superClass().delete(self)
	self:destroyMapHotspot()
	self:cleanupTipAny()

	for _, marker in pairs(self.rockToMarker) do
		delete(marker)
	end

	self.rockToMarker = nil

	if self.markerRootNode ~= nil then
		delete(self.markerRootNode)

		self.markerRootNode = nil
	end

	g_currentMission.destructibleMapObjectSystem:unregisterDestructibleDestroyedListener(self)
	g_missionManager:removeActiveRockMission(self)

	if self.spot ~= nil then
		self.spot.isInUse = false
		self.spot = nil
	end

	DestructibleRockMission.NUM_INSTANCES = math.max(DestructibleRockMission.NUM_INSTANCES - 1, 0)
end

function DestructibleRockMission:saveToXMLFile(xmlFile, key)
	DestructibleRockMission:superClass().saveToXMLFile(self, xmlFile, key)
	setXMLInt(xmlFile, key .. "#spotIndex", self.spot.index)
	setXMLInt(xmlFile, key .. "#numRocksDestroyed", self.numRocksDestroyed)

	for i, rock in ipairs(self.rocksAll) do
		local rockKey = string.format("%s.destructible(%d)", key, i - 1)
		local group, index = g_currentMission.destructibleMapObjectSystem:getGroupAndIndexForDestructible(rock)

		setXMLInt(xmlFile, rockKey .. "#groupId", group.groupId)
		setXMLInt(xmlFile, rockKey .. "#index", index)

		if self.rocksKeys[rock] == nil then
			setXMLBool(xmlFile, rockKey .. "#notPartOfMission", true)
		end
	end
end

function DestructibleRockMission:loadFromXMLFile(xmlFile, key)
	DestructibleRockMission:superClass().loadFromXMLFile(self, xmlFile, key)

	local spotIndex = getXMLInt(xmlFile, key .. "#spotIndex") or 0
	local spot = g_missionManager.destructibleRockMission.spots[spotIndex]

	if spot == nil then
		return false
	end

	self:setSpot(spot)

	self.numRocksDestroyed = getXMLInt(xmlFile, key .. "#numRocksDestroyed")
	local i = 0

	while true do
		local destructibleKey = string.format("%s.destructible(%d)", key, i)

		if not hasXMLProperty(xmlFile, destructibleKey) then
			break
		end

		local groupId = getXMLInt(xmlFile, destructibleKey .. "#groupId")
		local index = getXMLInt(xmlFile, destructibleKey .. "#index")
		local isPartOfMission = Utils.getNoNil(getXMLBool(xmlFile, destructibleKey .. "#notPartOfMission"), true)
		local groupRoot = g_currentMission.destructibleMapObjectSystem:getGroupRootById(groupId)
		local destructible = getChildAt(groupRoot, index)

		self:addDestructible(destructible, isPartOfMission)

		i = i + 1
	end

	if self.status == AbstractMission.STATUS_RUNNING then
		self:addRockMarkers()
	end

	return true
end

function DestructibleRockMission:writeStream(streamId, connection)
	DestructibleRockMission:superClass().writeStream(self, streamId, connection)
	streamWriteUInt8(streamId, self.spot.index)
	streamWriteUInt8(streamId, self.numRocksDestroyed)
	streamWriteUInt8(streamId, #self.rocksAll)

	for i, rock in ipairs(self.rocksAll) do
		local group, index = g_currentMission.destructibleMapObjectSystem:getGroupAndIndexForDestructible(rock)

		streamWriteUIntN(streamId, group.groupId, DestructibleMapObjectSystem.GROUP_ID_NUM_BITS)
		streamWriteUIntN(streamId, index, DestructibleMapObjectSystem.CHILD_INDEX_NUM_BITS)
		streamWriteBool(streamId, self.rocksKeys[rock] ~= nil)
	end
end

function DestructibleRockMission:readStream(streamId, connection)
	DestructibleRockMission:superClass().readStream(self, streamId, connection)

	local spotIndex = streamReadUInt8(streamId)
	local spot = g_missionManager.destructibleRockMission.spots[spotIndex]

	self:setSpot(spot)

	self.numRocksDestroyed = streamReadUInt8(streamId)
	local numRocksAll = streamReadUInt8(streamId)

	for i = 1, numRocksAll do
		local groupId = streamReadUIntN(streamId, DestructibleMapObjectSystem.GROUP_ID_NUM_BITS)
		local index = streamReadUIntN(streamId, DestructibleMapObjectSystem.CHILD_INDEX_NUM_BITS)
		local isPartOfMission = streamReadBool(streamId)
		local groupRoot = g_currentMission.destructibleMapObjectSystem:getGroupRootById(groupId)
		local destructible = getChildAt(groupRoot, index)

		self:addDestructible(destructible, isPartOfMission)
	end

	if not self.isServer and self.status == AbstractMission.STATUS_RUNNING then
		self:addRockMarkers()
	end
end

function DestructibleRockMission:readUpdateStream(streamId, timestamp, connection)
	DestructibleRockMission:superClass().readUpdateStream(self, streamId, timestamp, connection)

	self.numRocksDestroyed = streamReadUInt8(streamId)
end

function DestructibleRockMission:writeUpdateStream(streamId, connection, dirtyMask)
	DestructibleRockMission:superClass().writeUpdateStream(self, streamId, connection, dirtyMask)
	streamWriteUInt8(streamId, self.numRocksDestroyed)
end

function DestructibleRockMission:update(dt)
	DestructibleRockMission:superClass().update(self, dt)

	if g_currentMission.player ~= nil and g_currentMission.player.farmId == self.farmId and self.mapHotspot == nil then
		self:createHotspots()
	end

	if not self.markersAdded and self.status == AbstractMission.STATUS_RUNNING then
		self:addRockMarkers()
	end
end

function DestructibleRockMission:start(spawnVehicles)
	local res = DestructibleRockMission:superClass().start(self, spawnVehicles)

	if not res then
		return false
	end

	self:addRockMarkers()

	return res
end

function DestructibleRockMission:cleanupTipAny()
	for _, rock in ipairs(self.rocksAll) do
		local rigidBodies = g_currentMission.destructibleMapObjectSystem:getDestructibleRigidBodies(rock)

		if rigidBodies ~= nil then
			for _, rigidBody in ipairs(rigidBodies) do
				local _, _, _, bvRadius = getShapeBoundingSphere(rigidBody)
				local wx, _, wz = getWorldTranslation(rock)
				local halfWidth = bvRadius / 2
				local startX = wx - halfWidth
				local startZ = wz - halfWidth
				local endX = wx - halfWidth
				local endZ = wz + halfWidth
				local heightX = wx + halfWidth
				local heightZ = wz - halfWidth

				DensityMapHeightUtil.removeFromGroundByArea(startX, startZ, endX, endZ, heightX, heightZ, FillType.STONE)
			end
		end
	end
end

function DestructibleRockMission:addRockMarkers()
	if self.markersAdded then
		return
	end

	if self.markerRootNode == nil then
		self.markerRootNode = createTransformGroup("destructibleRockMissionMarkers")

		link(getRootNode(), self.markerRootNode)
	end

	for index, rock in pairs(self.rocks) do
		if getEffectiveVisibility(rock) then
			local marker = clone(g_missionManager.destructibleRockMission.markerNode, false, false, false)

			link(self.markerRootNode, marker)

			self.rockToMarker[rock] = marker
			local x, y, z = getWorldTranslation(rock)

			raycastAll(x, y + 10, z, 0, -1, 0, "rockMarkerRaycastCallback", 10, self, DestructibleRockMission.COLLISION_MASK, false, true)
		end
	end

	self.markersAdded = true
end

function DestructibleRockMission:rockMarkerRaycastCallback(nodeId, x, y, z)
	if nodeId ~= 0 and nodeId ~= g_currentMission.terrainRootNode then
		if self.rockToMarker == nil or self.status ~= AbstractMission.STATUS_RUNNING then
			return false
		end

		local destructible = g_currentMission.destructibleMapObjectSystem:getDestructibleFromNode(nodeId)

		if destructible then
			local marker = self.rockToMarker[destructible]

			if marker then
				setWorldTranslation(marker, x, y - 0.15, z)
				setWorldRotation(marker, 0, 0, 0)
			end

			return false
		end
	end

	return true
end

function DestructibleRockMission:finish(success)
	self:destroyMapHotspot()

	if g_currentMission:getIsServer() and success then
		local stats = g_currentMission:farmStats(self.farmId)

		stats:updateStats("forestryMissionCount", 1)
	end

	if #self.rocksAll - self.numRocksDestroyed < DestructibleRockMission.MIN_NUM_ROCKS then
		g_missionManager:disableDestructibleRockMissionSpot(self.spot)
	end

	if g_currentMission:getFarmId() == self.farmId and success then
		g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK, string.format(g_i18n:getText("destructibleRockMission_completed"), self.farmlandId))
	end

	DestructibleRockMission:superClass().finish(self, success)
end

function DestructibleRockMission:createHotspots()
	self:destroyMapHotspot()

	if self.spot == nil then
		return
	end

	local x = self.spot.x
	local z = self.spot.z
	local radius = self.spot.radius
	self.mapHotspot = DestructibleRockMissionHotspot.new()

	self.mapHotspot:setWorldPosition(x, z)
	self.mapHotspot:setWorldRadius(radius + 3)
	g_currentMission:addMapHotspot(self.mapHotspot)
end

function DestructibleRockMission:destroyMapHotspot()
	if self.mapHotspot ~= nil then
		g_currentMission:removeMapHotspot(self.mapHotspot)
		self.mapHotspot:delete()

		self.mapHotspot = nil
	end
end

function DestructibleRockMission:showCompletionNotification()
	local text = string.format(g_i18n:getText("destructibleRockMission_completionNotification"), self.farmlandId, self.completion * 100)

	g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_INFO, text)
end

function DestructibleRockMission:validate()
	local res = DestructibleRockMission:superClass().validate(self)

	if not res then
		return false
	end

	local farmland = g_farmlandManager:getFarmlandById(self.farmlandId)

	if farmland.isOwned then
		return false
	end

	return res
end

function DestructibleRockMission:dismiss()
	if self.isServer then
		local change = 0

		if self.success then
			change = self:getReward()
		end

		change = change - self.wronglyDestroyedRocksPenalty

		if change ~= 0 then
			self.mission:addMoney(change, self.farmId, MoneyType.MISSIONS, true, true)
		end
	end
end

function DestructibleRockMission:getData()
	return {
		location = string.format("%s %d", g_i18n:getText("ui_farmlandScreen"), self.farmlandId),
		jobType = g_i18n:getText("destructibleRockMission_title", DestructibleRockMission.CUSTOM_ENVIRONMENT),
		action = string.format(g_i18n:getText("destructibleRockMission_action", DestructibleRockMission.CUSTOM_ENVIRONMENT), #self.rocks),
		description = g_i18n:getText("destructibleRockMission_description", DestructibleRockMission.CUSTOM_ENVIRONMENT)
	}
end

function DestructibleRockMission:getNPC()
	local farmland = g_farmlandManager:getFarmlandById(self.farmlandId)
	local npc = g_npcManager:getNPCByIndex(farmland.npcIndex)

	return npc
end

function DestructibleRockMission:getExtraProgressText()
	local remaining = #self.rocks - self.numRocksDestroyed

	if remaining == 1 then
		return g_i18n:getText("destructibleRockMission_oneRemainingRock", DestructibleRockMission.CUSTOM_ENVIRONMENT)
	end

	return string.format(g_i18n:getText("destructibleRockMission_remainingRocks", DestructibleRockMission.CUSTOM_ENVIRONMENT), remaining)
end

function DestructibleRockMission:getCompletion()
	return self.numRocksDestroyed / #self.rocks
end

function DestructibleRockMission:getReward()
	return self.reward
end

function DestructibleRockMission:calculateStealingCost()
	return self.wronglyDestroyedRocksPenalty
end

function DestructibleRockMission:onRockDestroyed(destructible)
	if self.status ~= AbstractMission.STATUS_RUNNING then
		return
	end

	if not self.rocksAllKeys[destructible] then
		return
	end

	if self.rocksKeys[destructible] then
		local marker = self.rockToMarker[destructible]

		if marker then
			setVisibility(marker, false)
		end

		if self.isServer then
			self.numRocksDestroyed = self.numRocksDestroyed + 1
		end
	elseif self.isServer then
		self.wronglyDestroyedRocksPenalty = self.wronglyDestroyedRocksPenalty + g_missionManager.destructibleRockMission.penaltyPerRock

		g_currentMission:broadcastEventToFarm(WrongRockDestroyedEvent.new(), self.farmId, true)
	end
end

function DestructibleRockMission:getDestructibleIsInMissionArea(destructible, farmId)
	if self.farmId == farmId then
		return self.rocksAllKeys[destructible] ~= nil
	end

	return false
end

function DestructibleRockMission.canRun()
	local numSpots = #g_missionManager.destructibleRockMission.spots

	if numSpots == 0 then
		return false
	end

	if DestructibleRockMission.MAX_NUM_INSTANCES <= DestructibleRockMission.NUM_INSTANCES then
		return false
	end

	return true
end

g_missionManager:registerMissionType(DestructibleRockMission, "destructibleRocks", MissionManager.CATEGORY_FORESTRY, 1)
