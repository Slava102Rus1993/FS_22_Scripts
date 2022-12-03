local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

TreeTransportMission = {
	CUSTOM_ENVIRONMENT = g_currentModName,
	NUM_INSTANCES = 0,
	MAX_NUM_INSTANCES = 2
}
local TreeTransportMission_mt = Class(TreeTransportMission, AbstractMission)

InitObjectClass(TreeTransportMission, "TreeTransportMission")

function TreeTransportMission.new(isServer, isClient, customMt)
	local self = AbstractMission.new(isServer, isClient, customMt or TreeTransportMission_mt)
	self.spot = nil
	self.trees = {}
	self.pendingTrees = {}
	self.treeShapeToTree = {}
	self.cutSplitShapes = {}
	self.resolveServerIds = false
	self.hasCollision = false
	self.numDeliveredTrees = 0
	self.numDeletedTrees = 0
	self.numTrees = 0
	self.mapHotspot = nil
	self.mission = g_currentMission

	g_messageCenter:subscribe(MessageType.SPLIT_SHAPE, self.onTreeShapeCut, self)

	TreeTransportMission.NUM_INSTANCES = TreeTransportMission.NUM_INSTANCES + 1

	g_missionManager:addActiveTreeMission(self)

	return self
end

function TreeTransportMission:init(spot)
	local res = TreeTransportMission:superClass().init(self)

	if spot == nil then
		return false
	end

	self:setSpot(spot)

	if not self:canSpawnTrees() then
		return false
	end

	self.numTrees = getNumOfChildren(spot.node)
	self.reward = self.numTrees * g_missionManager.treeTransportMission.rewardPerTree

	return res
end

function TreeTransportMission:setSpot(spot)
	self.spot = spot
	spot.isInUse = true
	self.farmlandId = spot.farmlandId
end

function TreeTransportMission:delete()
	TreeTransportMission:superClass().delete(self)
	self:destroyMapHotspot()
	self:deleteTrees()
	g_messageCenter:unsubscribeAll(self)
	g_missionManager:removeActiveTreeMission(self)

	if self.spot ~= nil then
		self.spot.isInUse = false
		self.spot = nil
	end

	TreeTransportMission.NUM_INSTANCES = math.max(TreeTransportMission.NUM_INSTANCES - 1, 0)
end

function TreeTransportMission:saveToXMLFile(xmlFile, key)
	TreeTransportMission:superClass().saveToXMLFile(self, xmlFile, key)
	setXMLInt(xmlFile, key .. "#spotIndex", self.spot.index)
	setXMLInt(xmlFile, key .. "#numTrees", self.numTrees)
	setXMLInt(xmlFile, key .. "#numDeliveredTrees", self.numDeliveredTrees)
	setXMLInt(xmlFile, key .. "#numDeletedTrees", self.numDeletedTrees)

	if self.status == AbstractMission.STATUS_RUNNING then
		local i = 0

		for _, treeNode in ipairs(self.trees) do
			local treeKey = string.format("%s.tree(%d)", key, i)

			if entityExists(treeNode) then
				local splitShapePart1, splitShapePart2, splitShapePart3 = getSaveableSplitShapeId(treeNode)

				if splitShapePart1 ~= 0 then
					setXMLInt(xmlFile, treeKey .. "#splitShapePart1", splitShapePart1)
					setXMLInt(xmlFile, treeKey .. "#splitShapePart2", splitShapePart2)
					setXMLInt(xmlFile, treeKey .. "#splitShapePart3", splitShapePart3)

					local x, y, z = getWorldTranslation(treeNode)
					local rx, ry, rz = getWorldRotation(treeNode)

					setXMLString(xmlFile, treeKey .. "#position", string.format("%.4f %.4f %.4f", x, y, z))
					setXMLString(xmlFile, treeKey .. "#rotation", string.format("%.4f %.4f %.4f", math.deg(rx), math.deg(ry), math.deg(rz)))

					i = i + 1
				end
			end
		end

		i = 0

		for splitShape, _ in pairs(self.cutSplitShapes) do
			local cutSplitShapeKey = string.format("%s.cutSplitShape(%d)", key, i)

			if entityExists(splitShape) then
				local splitShapePart1, splitShapePart2, splitShapePart3 = getSaveableSplitShapeId(splitShape)

				if splitShapePart1 ~= 0 then
					setXMLInt(xmlFile, cutSplitShapeKey .. "#splitShapePart1", splitShapePart1)
					setXMLInt(xmlFile, cutSplitShapeKey .. "#splitShapePart2", splitShapePart2)
					setXMLInt(xmlFile, cutSplitShapeKey .. "#splitShapePart3", splitShapePart3)

					i = i + 1
				end
			end
		end
	end
end

function TreeTransportMission:loadFromXMLFile(xmlFile, key)
	TreeTransportMission:superClass().loadFromXMLFile(self, xmlFile, key)

	local spotIndex = getXMLInt(xmlFile, key .. "#spotIndex") or 0
	local spot = g_missionManager.treeTransportMission.spots[spotIndex]

	if spot == nil then
		return false
	end

	self:setSpot(spot)

	self.numDeliveredTrees = getXMLInt(xmlFile, key .. "#numDeliveredTrees") or 0
	self.numDeletedTrees = getXMLInt(xmlFile, key .. "#numDeletedTrees") or 0
	self.numTrees = getXMLInt(xmlFile, key .. "#numTrees") or self.numTrees

	if self.status == AbstractMission.STATUS_RUNNING then
		local i = 0

		while true do
			local treeKey = string.format("%s.tree(%d)", key, i)

			if not hasXMLProperty(xmlFile, treeKey) then
				break
			end

			local splitShapePart1 = getXMLInt(xmlFile, treeKey .. "#splitShapePart1")

			if splitShapePart1 ~= nil then
				local splitShapePart2 = getXMLInt(xmlFile, treeKey .. "#splitShapePart2")
				local splitShapePart3 = getXMLInt(xmlFile, treeKey .. "#splitShapePart3")
				local treeNode = getShapeFromSaveableSplitShapeId(splitShapePart1, splitShapePart2, splitShapePart3)

				if treeNode ~= 0 then
					local x, y, z = string.getVector(getXMLString(xmlFile, treeKey .. "#position"))
					local rx, ry, rz = string.getVector(getXMLString(xmlFile, treeKey .. "#rotation"))
					rx = math.rad(rx)
					ry = math.rad(ry)
					rz = math.rad(rz)

					if x ~= nil and y ~= nil and z ~= nil and rx ~= nil and ry ~= nil and rz ~= nil then
						setWorldTranslation(treeNode, x, y, z)
						setWorldRotation(treeNode, rx, ry, rz)
					end

					local treeObj = TransportTree.new(self.isServer, self.isClient)

					treeObj:setNodeId(treeNode)
					treeObj:register()

					self.treeShapeToTree[treeNode] = treeObj

					table.insert(self.trees, treeNode)
				else
					self.numDeletedTrees = self.numDeletedTrees + 1
				end
			end

			i = i + 1
		end

		i = 0

		while true do
			local cutSplitShapeKey = string.format("%s.cutSplitShape(%d)", key, i)

			if not hasXMLProperty(xmlFile, cutSplitShapeKey) then
				break
			end

			local splitShapePart1 = getXMLInt(xmlFile, cutSplitShapeKey .. "#splitShapePart1")

			if splitShapePart1 ~= nil then
				local splitShapePart2 = getXMLInt(xmlFile, cutSplitShapeKey .. "#splitShapePart2")
				local splitShapePart3 = getXMLInt(xmlFile, cutSplitShapeKey .. "#splitShapePart3")
				local splitShape = getShapeFromSaveableSplitShapeId(splitShapePart1, splitShapePart2, splitShapePart3)

				if splitShape ~= 0 then
					self.cutSplitShapes[splitShape] = true
				end
			end

			i = i + 1
		end
	end

	return true
end

function TreeTransportMission:writeStream(streamId, connection)
	TreeTransportMission:superClass().writeStream(self, streamId, connection)
	streamWriteUInt8(streamId, self.spot.index)
	streamWriteUInt8(streamId, self.numTrees)
	streamWriteUInt8(streamId, self.numDeletedTrees)
	streamWriteUInt8(streamId, self.numDeliveredTrees)
	streamWriteUInt8(streamId, #self.trees)

	for _, treeNode in ipairs(self.trees) do
		if entityExists(treeNode) then
			writeSplitShapeIdToStream(streamId, treeNode)
		end
	end
end

function TreeTransportMission:readStream(streamId, connection)
	TreeTransportMission:superClass().readStream(self, streamId, connection)

	local spotIndex = streamReadUInt8(streamId)
	local spot = g_missionManager.treeTransportMission.spots[spotIndex]

	self:setSpot(spot)

	self.numTrees = streamReadUInt8(streamId)
	self.numDeletedTrees = streamReadUInt8(streamId)
	self.numDeliveredTrees = streamReadUInt8(streamId)
	local numTrees = streamReadUInt8(streamId)

	for i = 1, numTrees do
		local entityId, splitShapeId1, splitShapeId2 = readSplitShapeIdFromStream(streamId)

		if entityId ~= 0 then
			table.insert(self.trees, entityId)
		elseif splitShapeId1 ~= 0 then
			table.insert(self.pendingTrees, {
				splitShapeId1,
				splitShapeId2
			})
		end
	end

	self.resolveServerIds = true
end

function TreeTransportMission:writeUpdateStream(streamId, connection, dirtyMask)
	TreeTransportMission:superClass().writeUpdateStream(self, streamId, connection, dirtyMask)
	streamWriteUInt8(streamId, self.numDeletedTrees)
	streamWriteUInt8(streamId, self.numDeliveredTrees)
end

function TreeTransportMission:readUpdateStream(streamId, timestamp, connection)
	TreeTransportMission:superClass().readUpdateStream(self, streamId, timestamp, connection)

	self.numDeletedTrees = streamReadUInt8(streamId)
	self.numDeliveredTrees = streamReadUInt8(streamId)
end

function TreeTransportMission:update(dt)
	TreeTransportMission:superClass().update(self, dt)

	if not self.isServer then
		if self.pendingTrees ~= nil then
			for i = #self.pendingTrees, 1, -1 do
				local tree = self.pendingTrees[i]
				local entityId = resolveStreamSplitShapeId(tree[1], tree[2])

				if entityId ~= 0 then
					table.remove(self.pendingTrees, i)
					table.insert(self.trees, entityId)
				end
			end

			if #self.pendingTrees == 0 then
				self.pendingTrees = nil
			end
		end
	else
		for splitShapeId, tree in pairs(self.treeShapeToTree) do
			if not entityExists(splitShapeId) then
				self:onMissionTreeDeleted(splitShapeId)
			end
		end
	end

	if g_currentMission.player ~= nil and g_currentMission.player.farmId == self.farmId and self.mapHotspot == nil then
		self:createHotspots()
	end
end

function TreeTransportMission:createTree(x, y, z, rx, ry, rz)
	local treeNode = g_treePlantManager:plantTree(g_missionManager.treeTransportMission.treeIndex, x, y, z, rx, ry, rz, 1, 1, false, nil)

	if treeNode ~= nil then
		local splitShapeId = SplitShapeUtil.getSplitShapeId(treeNode)
		local treeObj = TransportTree.new(self.isServer, self.isClient)

		treeObj:setNodeId(splitShapeId)
		treeObj:register()

		self.treeShapeToTree[splitShapeId] = treeObj

		table.insert(self.trees, splitShapeId)

		return treeNode
	end

	return nil
end

function TreeTransportMission:deleteTrees()
	for _, tree in ipairs(self.trees) do
		if entityExists(tree) then
			local parent = getParent(tree)

			if entityExists(parent) then
				delete(parent)
			end
		end
	end

	for splitShapeId, _ in pairs(self.cutSplitShapes) do
		if entityExists(splitShapeId) then
			delete(splitShapeId)

			self.cutSplitShapes[splitShapeId] = nil
		end
	end
end

function TreeTransportMission:start(spawnVehicles)
	local res = TreeTransportMission:superClass().start(self, spawnVehicles)

	if not res then
		return false
	end

	if not self:canSpawnTrees() then
		return false
	end

	if self.isServer then
		for i = 0, self.numTrees - 1 do
			local spawnNode = getChildAt(self.spot.node, i)
			local x, y, z = getWorldTranslation(spawnNode)
			local rx, ry, rz = getWorldRotation(spawnNode)

			self:createTree(x, y, z, rx, ry, rz)
		end
	end

	return res
end

function TreeTransportMission:finish(success)
	self:destroyMapHotspot()

	if g_currentMission:getIsServer() and success then
		local stats = g_currentMission:farmStats(self.farmId)

		stats:updateStats("forestryMissionCount", 1)
	end

	if g_currentMission:getFarmId() == self.farmId and success then
		g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK, string.format(g_i18n:getText("treeTransportMission_completed"), self.farmlandId))
	end

	TreeTransportMission:superClass().finish(self, success)
end

function TreeTransportMission:createHotspots()
	self:destroyMapHotspot()

	if self.spot == nil then
		return
	end

	local x = self.spot.x
	local z = self.spot.z
	self.mapHotspot = TreeTransportMissionHotspot.new()

	self.mapHotspot:setWorldPosition(x, z)
	g_currentMission:addMapHotspot(self.mapHotspot)
end

function TreeTransportMission:destroyMapHotspot()
	if self.mapHotspot ~= nil then
		g_currentMission:removeMapHotspot(self.mapHotspot)
		self.mapHotspot:delete()

		self.mapHotspot = nil
	end
end

function TreeTransportMission:onMissionTreeDeleted(splitShapeId)
	local tree = self.treeShapeToTree[splitShapeId]

	if tree ~= nil then
		tree:delete()

		self.treeShapeToTree[splitShapeId] = nil
		self.numDeletedTrees = self.numDeletedTrees + 1

		g_currentMission:broadcastEventToFarm(TransportTreeCutEvent.new(), self.farmId, true)
	end
end

function TreeTransportMission:onTreeShapeCut(shapeData, splitShapeData)
	if self.status ~= AbstractMission.STATUS_RUNNING then
		return
	end

	if self.isServer then
		local treeObj = self.treeShapeToTree[shapeData.shape]

		if treeObj then
			self:onMissionTreeDeleted(shapeData.shape)

			for _, data in ipairs(splitShapeData) do
				self.cutSplitShapes[data.shape] = true
			end

			return
		end

		if self.cutSplitShapes[shapeData.shape] ~= nil then
			for _, data in ipairs(splitShapeData) do
				self.cutSplitShapes[data.shape] = true
			end

			return
		end
	end
end

function TreeTransportMission:showCompletionNotification()
	local text = string.format(g_i18n:getText("treeTransportMission_completionNotification"), self.farmlandId, self.completion * 100)

	g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_INFO, text)
end

function TreeTransportMission:validate()
	local res = TreeTransportMission:superClass().validate(self)

	if not res then
		return false
	end

	local farmland = g_farmlandManager:getFarmlandById(self.farmlandId)

	if farmland.isOwned then
		return false
	end

	return res
end

function TreeTransportMission:getData()
	return {
		location = string.format("%s %d", g_i18n:getText("ui_farmlandScreen"), self.farmlandId),
		jobType = g_i18n:getText("treeTransportMission_title", TreeTransportMission.CUSTOM_ENVIRONMENT),
		action = string.format(g_i18n:getText("treeTransportMission_action", TreeTransportMission.CUSTOM_ENVIRONMENT), self.numTrees),
		description = g_i18n:getText("treeTransportMission_description", TreeTransportMission.CUSTOM_ENVIRONMENT)
	}
end

function TreeTransportMission:getNPC()
	local farmland = g_farmlandManager:getFarmlandById(self.farmlandId)
	local npc = g_npcManager:getNPCByIndex(farmland.npcIndex)

	return npc
end

function TreeTransportMission:getExtraProgressText()
	local remaining = math.max(0, self.numTrees - (self.numDeliveredTrees + self.numDeletedTrees))

	return string.format(g_i18n:getText("treeTransportMission_remainingTrees", TreeTransportMission.CUSTOM_ENVIRONMENT), remaining)
end

function TreeTransportMission:getCompletion()
	if self.numTrees > 0 then
		return (self.numDeliveredTrees + self.numDeletedTrees) / self.numTrees
	end

	return 1
end

function TreeTransportMission:getReward()
	return self.reward
end

function TreeTransportMission:calculateStealingCost()
	return self.numDeletedTrees * g_missionManager.treeTransportMission.penaltyPerTree
end

function TreeTransportMission:dismiss()
	if self.isServer then
		local change = 0

		if self.success then
			change = self:getReward()
		end

		change = change - self:calculateStealingCost()

		if change ~= 0 then
			self.mission:addMoney(change, self.farmId, MoneyType.MISSIONS, true, true)
		end
	end
end

function TreeTransportMission:getIsShapeCutAllowed(shape, x, z, farmId)
	if self.status ~= AbstractMission.STATUS_STOPPED and self.treeShapeToTree[shape] ~= nil then
		return false
	end

	return nil
end

function TreeTransportMission:onTriggerProcessedWood(trigger, splitShapeId, volume, fillType)
	if not self.isServer then
		return
	end

	if self.treeShapeToTree[splitShapeId] == nil then
		return
	end

	self.numDeliveredTrees = self.numDeliveredTrees + 1

	self.treeShapeToTree[splitShapeId]:delete()

	self.treeShapeToTree[splitShapeId] = nil
end

function TreeTransportMission:getIsMissionSplitShape(shape)
	if shape == nil or shape == 0 then
		return false
	end

	if self.treeShapeToTree[shape] ~= nil then
		return true
	end

	return false
end

function TreeTransportMission:canSpawnTrees()
	local spot = self.spot
	local sizeX = spot.sizeX * 0.5
	local sizeY = spot.sizeY * 0.5
	local sizeZ = spot.sizeZ * 0.5
	local threshold = 0.15
	local x, y, z = localToWorld(spot.node, sizeX - threshold, sizeY - threshold, sizeZ - threshold)
	local rx, ry, rz = getWorldRotation(spot.node)
	self.hasCollision = false

	overlapBox(x, y, z, rx, ry, rz, sizeX + threshold, sizeY + threshold, sizeZ + threshold, "onSpotCollision", self, CollisionMask.VEHICLE + CollisionMask.PLAYER_KINEMATIC, true, true, true)

	if self.hasCollision then
		return false
	end

	return true
end

function TreeTransportMission:onSpotCollision(node)
	if node ~= g_currentMission.terrainRootNode and not getHasTrigger(node) then
		local name = getName(node)

		if not string.contains(name, "dirtRoad") then
			self.hasCollision = true
		end
	end
end

function TreeTransportMission.canRun()
	local numSpots = #g_missionManager.treeTransportMission.spots

	if numSpots == 0 then
		return false
	end

	if g_missionManager.treeTransportMission.treeIndex == nil then
		return false
	end

	if TreeTransportMission.MAX_NUM_INSTANCES <= TreeTransportMission.NUM_INSTANCES then
		return false
	end

	return true
end

g_missionManager:registerMissionType(TreeTransportMission, "treeTransport", MissionManager.CATEGORY_FORESTRY, 1)
