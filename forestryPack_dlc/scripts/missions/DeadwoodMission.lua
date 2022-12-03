local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

DeadwoodMission = {
	CUSTOM_ENVIRONMENT = g_currentModName,
	NUM_INSTANCES = 0,
	MAX_NUM_INSTANCES = 2
}
local DeadwoodMission_mt = Class(DeadwoodMission, AbstractMission)

InitObjectClass(DeadwoodMission, "DeadwoodMission")

function DeadwoodMission.new(isServer, isClient, customMt)
	local self = AbstractMission.new(isServer, isClient, customMt or DeadwoodMission_mt)
	self.spot = nil
	self.trees = {}
	self.preplacedDeadwood = {}
	self.deadTrees = {}
	self.deadTreeShapeToTree = {}
	self.deadTreeCutSplitShapes = {}
	self.pendingOriginalTrees = {}
	self.originalTrees = {}
	self.numDeadTrees = 0
	self.numCutDownTrees = 0
	self.wronglyCutDownTreesReward = 0
	self.resolveOriginalTreeServerIds = false
	self.resolveDeadTreeServerIds = false
	self.mapHotspot = nil
	self.deadwoodSplitTypeIndex = g_splitTypeManager:getSplitTypeIndexByName("DEADWOOD")
	self.mission = g_currentMission

	g_messageCenter:subscribe(MessageType.SPLIT_SHAPE, self.onTreeShapeCut, self)

	DeadwoodMission.NUM_INSTANCES = DeadwoodMission.NUM_INSTANCES + 1

	g_missionManager:addActiveTreeMission(self)

	return self
end

function DeadwoodMission:init(spot)
	local res = DeadwoodMission:superClass().init(self)

	if spot == nil then
		return false
	end

	self:setSpot(spot)
	overlapSphere(spot.x, spot.y, spot.z, self.spot.radius, "onTreeCallback", self, CollisionFlag.TREE, false, true, false, false)

	local numTrees = #self.trees
	local numPreplaced = #self.preplacedDeadwood
	local totalNumTrees = numTrees + numPreplaced

	if totalNumTrees == 0 then
		return false
	end

	local numDeadTrees = numPreplaced

	if numDeadTrees < 10 then
		local minTrees = math.min(5, numTrees)
		local maxTrees = math.min(10, numTrees)
		numDeadTrees = numDeadTrees + math.random(minTrees, maxTrees)
	end

	self.numDeadTrees = numDeadTrees
	self.reward = self.numDeadTrees * g_missionManager.deadwoodMission.rewardPerTree

	Utils.shuffle(self.trees)

	for _, treeNode in ipairs(self.preplacedDeadwood) do
		table.insert(self.originalTrees, treeNode)
	end

	for _, treeNode in ipairs(self.trees) do
		if #self.originalTrees == self.numDeadTrees then
			break
		end

		table.insert(self.originalTrees, treeNode)
	end

	return res
end

function DeadwoodMission:setSpot(spot)
	self.spot = spot
	spot.isInUse = true
	self.farmlandId = spot.farmlandId
end

function DeadwoodMission:delete()
	DeadwoodMission:superClass().delete(self)
	self:destroyMapHotspot()
	self:destroyTrees()
	g_messageCenter:unsubscribeAll(self)
	g_missionManager:removeActiveTreeMission(self)

	if self.spot ~= nil then
		self.spot.isInUse = false
		self.spot = nil
	end

	DeadwoodMission.NUM_INSTANCES = math.max(DeadwoodMission.NUM_INSTANCES - 1, 0)
end

function DeadwoodMission:saveToXMLFile(xmlFile, key)
	DeadwoodMission:superClass().saveToXMLFile(self, xmlFile, key)
	setXMLInt(xmlFile, key .. "#spotIndex", self.spot.index)
	setXMLInt(xmlFile, key .. "#numCutDownTrees", self.numCutDownTrees)

	local i = 0

	for _, treeNode in ipairs(self.originalTrees) do
		local treeKey = string.format("%s.originalTree(%d)", key, i)

		if entityExists(treeNode) then
			local splitShapePart1, splitShapePart2, splitShapePart3 = getSaveableSplitShapeId(treeNode)

			if splitShapePart1 ~= 0 and splitShapePart1 ~= nil then
				setXMLInt(xmlFile, treeKey .. "#splitShapePart1", splitShapePart1)
				setXMLInt(xmlFile, treeKey .. "#splitShapePart2", splitShapePart2)
				setXMLInt(xmlFile, treeKey .. "#splitShapePart3", splitShapePart3)
			end
		end

		i = i + 1
	end

	i = 0

	for _, deadTree in pairs(self.deadTrees) do
		local deadTreeKey = string.format("%s.deadTree(%d)", key, i)

		setXMLBool(xmlFile, deadTreeKey .. "#cutDown", deadTree.cutDown)

		if deadTree.splitShapeId ~= nil then
			local splitShapePart1, splitShapePart2, splitShapePart3 = getSaveableSplitShapeId(deadTree.splitShapeId)

			if splitShapePart1 ~= 0 and splitShapePart1 ~= nil then
				setXMLInt(xmlFile, deadTreeKey .. "#splitShapePart1", splitShapePart1)
				setXMLInt(xmlFile, deadTreeKey .. "#splitShapePart2", splitShapePart2)
				setXMLInt(xmlFile, deadTreeKey .. "#splitShapePart3", splitShapePart3)
			end
		end

		i = i + 1
	end

	i = 0

	for splitShape, _ in pairs(self.deadTreeCutSplitShapes) do
		local cutSplitShapeKey = string.format("%s.cutSplitShape(%d)", key, i)

		if entityExists(splitShape) then
			local splitShapePart1, splitShapePart2, splitShapePart3 = getSaveableSplitShapeId(splitShape)

			if splitShapePart1 ~= 0 and splitShapePart1 ~= nil then
				setXMLInt(xmlFile, cutSplitShapeKey .. "#splitShapePart1", splitShapePart1)
				setXMLInt(xmlFile, cutSplitShapeKey .. "#splitShapePart2", splitShapePart2)
				setXMLInt(xmlFile, cutSplitShapeKey .. "#splitShapePart3", splitShapePart3)

				i = i + 1
			end
		end
	end
end

function DeadwoodMission:loadFromXMLFile(xmlFile, key)
	DeadwoodMission:superClass().loadFromXMLFile(self, xmlFile, key)

	local spotIndex = getXMLInt(xmlFile, key .. "#spotIndex") or 0
	local spot = g_missionManager.deadwoodMission.spots[spotIndex]

	if spot == nil then
		return false
	end

	self:setSpot(spot)

	local i = 0

	while true do
		local treeKey = string.format("%s.originalTree(%d)", key, i)

		if not hasXMLProperty(xmlFile, treeKey) then
			break
		end

		local splitShapePart1 = getXMLInt(xmlFile, treeKey .. "#splitShapePart1")

		if splitShapePart1 ~= nil then
			local splitShapePart2 = getXMLInt(xmlFile, treeKey .. "#splitShapePart2")
			local splitShapePart3 = getXMLInt(xmlFile, treeKey .. "#splitShapePart3")
			local splitShapeId = getShapeFromSaveableSplitShapeId(splitShapePart1, splitShapePart2, splitShapePart3)

			if splitShapeId ~= 0 and splitShapeId ~= nil then
				table.insert(self.originalTrees, splitShapeId)
			end
		end

		i = i + 1
	end

	self.numDeadTrees = #self.originalTrees
	self.numCutDownTrees = 0
	i = 0

	while true do
		local deadTreeKey = string.format("%s.deadTree(%d)", key, i)

		if not hasXMLProperty(xmlFile, deadTreeKey) then
			break
		end

		local cutDown = getXMLBool(xmlFile, deadTreeKey .. "#cutDown")
		local splitShapeId, rootNode, x, _, z, rotY = nil
		local splitShapePart1 = getXMLInt(xmlFile, deadTreeKey .. "#splitShapePart1")

		if splitShapePart1 ~= nil then
			local splitShapePart2 = getXMLInt(xmlFile, deadTreeKey .. "#splitShapePart2")
			local splitShapePart3 = getXMLInt(xmlFile, deadTreeKey .. "#splitShapePart3")
			splitShapeId = getShapeFromSaveableSplitShapeId(splitShapePart1, splitShapePart2, splitShapePart3)

			if splitShapeId ~= 0 and splitShapeId ~= nil then
				x, _, z = getWorldTranslation(splitShapeId)
				_, rotY, _ = getWorldRotation(splitShapeId)
				rootNode = getParent(splitShapeId)
			else
				splitShapeId = nil
			end
		end

		if cutDown then
			self.numCutDownTrees = self.numCutDownTrees + 1
		end

		local deadTree = {
			x = x,
			z = z,
			rotY = rotY,
			cutDown = cutDown,
			splitShapeId = splitShapeId,
			rootNode = rootNode
		}

		if splitShapeId ~= nil then
			self.deadTreeShapeToTree[splitShapeId] = deadTree
		end

		table.insert(self.deadTrees, deadTree)

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
			local cutSplitShapeId = getShapeFromSaveableSplitShapeId(splitShapePart1, splitShapePart2, splitShapePart3)

			if cutSplitShapeId ~= 0 and cutSplitShapeId ~= nil then
				self.deadTreeCutSplitShapes[cutSplitShapeId] = true
			end
		end

		i = i + 1
	end

	if self.status ~= AbstractMission.STATUS_STOPPED then
		for _, treeNode in ipairs(self.originalTrees) do
			self:setTreeVisibility(treeNode, false)
		end
	end

	if self.status == AbstractMission.STATUS_RUNNING then
		self:addTreeMarker()
	end

	return true
end

function DeadwoodMission:writeStream(streamId, connection)
	DeadwoodMission:superClass().writeStream(self, streamId, connection)
	streamWriteUInt8(streamId, self.spot.index)
	streamWriteUInt8(streamId, self.numCutDownTrees)
	streamWriteUInt8(streamId, self.numDeadTrees)
	streamWriteUInt8(streamId, #self.originalTrees)

	for _, treeNode in ipairs(self.originalTrees) do
		writeSplitShapeIdToStream(streamId, treeNode)
	end

	self:writeDeadTreesStream(streamId)
end

function DeadwoodMission:readStream(streamId, connection)
	DeadwoodMission:superClass().readStream(self, streamId, connection)

	local spotIndex = streamReadUInt8(streamId)
	local spot = g_missionManager.deadwoodMission.spots[spotIndex]

	self:setSpot(spot)

	self.numCutDownTrees = streamReadUInt8(streamId)
	self.numDeadTrees = streamReadUInt8(streamId)
	local numOriginalTrees = streamReadUInt8(streamId)

	for i = 1, numOriginalTrees do
		local entityId, splitShapeId1, splitShapeId2 = readSplitShapeIdFromStream(streamId)

		if entityId ~= 0 then
			table.insert(self.originalTrees, entityId)
		elseif splitShapeId1 ~= 0 then
			table.insert(self.pendingOriginalTrees, {
				splitShapeId1,
				splitShapeId2
			})
		end
	end

	self.resolveOriginalTreeServerIds = true

	self:readDeadTreesStream(streamId)
end

function DeadwoodMission:readUpdateStream(streamId, timestamp, connection)
	DeadwoodMission:superClass().readUpdateStream(self, streamId, timestamp, connection)

	self.numCutDownTrees = streamReadUInt8(streamId)
end

function DeadwoodMission:writeUpdateStream(streamId, connection, dirtyMask)
	DeadwoodMission:superClass().writeUpdateStream(self, streamId, connection, dirtyMask)
	streamWriteUInt8(streamId, self.numCutDownTrees)
end

function DeadwoodMission:readDeadTreesStream(streamId)
	local numDeadTrees = streamReadUInt8(streamId)

	for i = 1, numDeadTrees do
		local tree = {
			cutDown = false
		}

		if not streamReadBool(streamId) then
			local entityId, splitShapeId1, splitShapeId2 = readSplitShapeIdFromStream(streamId)

			if entityId ~= 0 then
				tree.splitShapeId = entityId
			elseif splitShapeId1 ~= 0 then
				tree.serverSplitShapePart2 = splitShapeId2
				tree.serverSplitShapePart1 = splitShapeId1
			end
		end

		table.insert(self.deadTrees, tree)
	end

	self.resolveDeadTreeServerIds = true
end

function DeadwoodMission:writeDeadTreesStream(streamId)
	streamWriteUInt8(streamId, #self.deadTrees)

	for _, tree in ipairs(self.deadTrees) do
		if not streamWriteBool(streamId, tree.cutDown) then
			writeSplitShapeIdToStream(streamId, tree.splitShapeId)
		end
	end
end

function DeadwoodMission:update(dt)
	DeadwoodMission:superClass().update(self, dt)

	if not self.isServer then
		if self.resolveDeadTreeServerIds then
			local resolvedAll = true

			for _, tree in ipairs(self.deadTrees) do
				if tree.serverSplitShapePart1 ~= nil and tree.serverSplitShapePart2 ~= nil then
					local entityId = resolveStreamSplitShapeId(tree.serverSplitShapePart1, tree.serverSplitShapePart2)

					if entityId ~= 0 then
						tree.splitShapeId = entityId
						tree.serverSplitShapePart1 = nil
						tree.serverSplitShapePart2 = nil
					else
						resolvedAll = false
					end
				end
			end

			if resolvedAll then
				self.resolveDeadTreeServerIds = false

				if self.status == AbstractMission.STATUS_RUNNING then
					self:addTreeMarker()
				end
			end
		end

		if self.resolveOriginalTreeServerIds then
			for i = #self.pendingOriginalTrees, 1, -1 do
				local originalTree = self.pendingOriginalTrees[i]
				local entityId = resolveStreamSplitShapeId(originalTree[1], originalTree[2])

				if entityId ~= 0 then
					table.remove(self.pendingOriginalTrees, i)
					table.insert(self.originalTrees, entityId)
				end
			end

			if #self.pendingOriginalTrees == 0 then
				self.resolveOriginalTreeServerIds = false

				if self.status == AbstractMission.STATUS_RUNNING then
					for _, treeNode in ipairs(self.originalTrees) do
						self:setTreeVisibility(treeNode, false)
					end
				end
			end
		end
	end

	if g_currentMission.player ~= nil and g_currentMission.player.farmId == self.farmId and self.mapHotspot == nil then
		self:createHotspots()
	end
end

function DeadwoodMission:setTreeVisibility(treeNode, isVisible)
	local treeRoot = getParent(treeNode)

	setVisibility(treeRoot, isVisible)

	if isVisible then
		addToPhysics(treeRoot)
	else
		removeFromPhysics(treeRoot)
	end
end

function DeadwoodMission:addMissionTree(treeNode)
	local treeRoot = getParent(treeNode)
	local x, y, z = getWorldTranslation(treeRoot)
	local rx, ry, rz = getWorldRotation(treeRoot)
	local treeIndex = g_missionManager.deadwoodMission.treeIndex
	local missionTreeNode = g_treePlantManager:plantTree(treeIndex, x, y, z, rx, ry, rz, 1, nil, false)
	local splitShapeId = SplitShapeUtil.getSplitShapeId(missionTreeNode)

	if splitShapeId ~= nil then
		local deadTree = {
			cutDown = false,
			rootNode = missionTreeNode,
			splitShapeId = splitShapeId,
			x = x,
			z = z,
			rotY = ry
		}

		table.insert(self.deadTrees, deadTree)

		self.deadTreeShapeToTree[splitShapeId] = deadTree
	end
end

function DeadwoodMission:start(spawnVehicles)
	local res = DeadwoodMission:superClass().start(self, spawnVehicles)

	if not res then
		return false
	end

	for _, treeNode in ipairs(self.originalTrees) do
		self:setTreeVisibility(treeNode, false)
		self:addMissionTree(treeNode)
	end

	self:addTreeMarker()
	g_server:broadcastEvent(DeadwoodMissionTreeEvent.new(self))

	return res
end

function DeadwoodMission:started()
	DeadwoodMission:superClass().started(self)

	for _, treeNode in ipairs(self.originalTrees) do
		self:setTreeVisibility(treeNode, false)
	end
end

function DeadwoodMission:destroyTrees()
	for _, tree in ipairs(self.deadTrees) do
		if tree.rootNode ~= nil and entityExists(tree.rootNode) then
			for i = getNumOfChildren(tree.rootNode), 1, -1 do
				delete(getChildAt(tree.rootNode, i - 1))
			end
		end
	end

	self.deadTrees = {}
	self.deadTreeShapeToTree = {}

	for splitShapeId, _ in pairs(self.deadTreeCutSplitShapes) do
		if entityExists(splitShapeId) then
			delete(splitShapeId)

			self.deadTreeCutSplitShapes[splitShapeId] = nil
		end
	end

	for _, treeNode in ipairs(self.originalTrees) do
		self:setTreeVisibility(treeNode, true)
	end
end

function DeadwoodMission:addTreeMarker()
	local treeMarkerType = g_currentMission.treeMarkerSystem:getTreeMarkerTypeByName("EXCLAMATION")

	if treeMarkerType == nil then
		return
	end

	for _, tree in pairs(self.deadTrees) do
		if tree.splitShapeId ~= nil then
			g_currentMission.treeMarkerSystem:addTreeMarkerByWorldDirection(tree.splitShapeId, treeMarkerType.index, 0.7084, 0.0212, 0.0006, 1, 0, 1, 2, 0.7, true)
		end
	end
end

function DeadwoodMission:finish(success)
	self:destroyMapHotspot()

	if g_currentMission:getIsServer() and success then
		local stats = g_currentMission:farmStats(self.farmId)

		stats:updateStats("forestryMissionCount", 1)
	end

	if g_currentMission:getFarmId() == self.farmId and success then
		g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK, string.format(g_i18n:getText("deadwoodMission_completed"), self.farmlandId))
	end

	DeadwoodMission:superClass().finish(self, success)
end

function DeadwoodMission:getIsMissionSplitShape(shape)
	if shape == nil or shape == 0 then
		return false
	end

	if self.deadTreeCutSplitShapes[shape] ~= nil then
		return true
	end

	if self.deadTreeShapeToTree[shape] ~= nil then
		return true
	end

	return false
end

function DeadwoodMission:createHotspots()
	self:destroyMapHotspot()

	if self.spot == nil then
		return
	end

	local x = self.spot.x
	local z = self.spot.z
	local radius = self.spot.radius
	self.mapHotspot = DeadwoodMissionHotspot.new()

	self.mapHotspot:setWorldPosition(x, z)
	self.mapHotspot:setWorldRadius(radius)
	g_currentMission:addMapHotspot(self.mapHotspot)
end

function DeadwoodMission:destroyMapHotspot()
	if self.mapHotspot ~= nil then
		g_currentMission:removeMapHotspot(self.mapHotspot)
		self.mapHotspot:delete()

		self.mapHotspot = nil
	end
end

function DeadwoodMission:showCompletionNotification()
	local text = string.format(g_i18n:getText("deadwoodMission_completionNotification"), self.farmlandId, self.completion * 100)

	g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_INFO, text)
end

function DeadwoodMission:validate()
	local res = DeadwoodMission:superClass().validate(self)

	if not res then
		return false
	end

	local farmland = g_farmlandManager:getFarmlandById(self.farmlandId)

	if farmland.isOwned then
		return false
	end

	return res
end

function DeadwoodMission:dismiss()
	if self.isServer then
		local change = 0

		if self.success then
			change = self:getReward()
		end

		change = change - self.wronglyCutDownTreesReward

		if change ~= 0 then
			self.mission:addMoney(change, self.farmId, MoneyType.MISSIONS, true, true)
		end
	end
end

function DeadwoodMission:getData()
	return {
		location = string.format("%s %d", g_i18n:getText("ui_farmlandScreen"), self.farmlandId),
		jobType = g_i18n:getText("deadwoodMission_title", DeadwoodMission.CUSTOM_ENVIRONMENT),
		action = string.format(g_i18n:getText("deadwoodMission_action", DeadwoodMission.CUSTOM_ENVIRONMENT), self.numDeadTrees),
		description = g_i18n:getText("deadwoodMission_description", DeadwoodMission.CUSTOM_ENVIRONMENT)
	}
end

function DeadwoodMission:getNPC()
	local farmland = g_farmlandManager:getFarmlandById(self.farmlandId)
	local npc = g_npcManager:getNPCByIndex(farmland.npcIndex)

	return npc
end

function DeadwoodMission:getExtraProgressText()
	local remaining = self.numDeadTrees - self.numCutDownTrees

	if remaining == 1 then
		return g_i18n:getText("deadwoodMission_oneRemainingTree", DeadwoodMission.CUSTOM_ENVIRONMENT)
	end

	return string.format(g_i18n:getText("deadwoodMission_remainingTrees", DeadwoodMission.CUSTOM_ENVIRONMENT), remaining)
end

function DeadwoodMission:getCompletion()
	return self.numCutDownTrees / self.numDeadTrees
end

function DeadwoodMission:getReward()
	return self.reward
end

function DeadwoodMission:calculateStealingCost()
	return self.wronglyCutDownTreesReward
end

function DeadwoodMission:onTreeShapeCut(shapeData, splitShapeData)
	if self.status ~= AbstractMission.STATUS_RUNNING then
		return
	end

	if self.isServer then
		local missionTree = self.deadTreeShapeToTree[shapeData.shape]

		if missionTree ~= nil then
			missionTree.cutDown = true
			self.numCutDownTrees = self.numCutDownTrees + 1

			for _, data in ipairs(splitShapeData) do
				self.deadTreeCutSplitShapes[data.shape] = true
			end

			return
		end

		if self.deadTreeCutSplitShapes[shapeData.shape] ~= nil then
			for _, data in ipairs(splitShapeData) do
				self.deadTreeCutSplitShapes[data.shape] = true
			end

			return
		end

		if shapeData.alreadySplit then
			return
		end

		local mission = g_missionManager:getMissionBySplitShape(shapeData.shape)

		if mission ~= nil then
			return
		end

		local farmlandId = g_farmlandManager:getFarmlandIdAtWorldPosition(shapeData.x, shapeData.z)

		if self.farmlandId == farmlandId then
			local volume = shapeData.volume
			local splitType = g_splitTypeManager:getSplitTypeByIndex(shapeData.splitType)
			local costs = math.max(g_missionManager.deadwoodMission.penaltyPerTree, volume * 1000 * splitType.pricePerLiter)
			self.wronglyCutDownTreesReward = self.wronglyCutDownTreesReward + costs

			g_currentMission:broadcastEventToFarm(WrongTreeCutDownEvent.new(), self.farmId, true)
		end
	end
end

function DeadwoodMission:onTreeCallback(transformId)
	if transformId ~= 0 and getHasClassId(transformId, ClassIds.SHAPE) then
		local splitType = getSplitType(transformId)

		if splitType ~= 0 and not getIsSplitShapeSplit(transformId) then
			local x, _, z = getWorldTranslation(transformId)
			local farmlandId = g_farmlandManager:getFarmlandIdAtWorldPosition(x, z)

			if farmlandId == self.farmlandId then
				if splitType == self.deadwoodSplitTypeIndex then
					table.insert(self.preplacedDeadwood, transformId)
				else
					table.insert(self.trees, transformId)
				end
			end
		end
	end

	return true
end

function DeadwoodMission:getIsShapeCutAllowed(shape, x, z, farmId)
	if self.farmId == farmId then
		local farmlandId = g_farmlandManager:getFarmlandIdAtWorldPosition(x, z)

		if self.farmlandId == farmlandId then
			if self.status == AbstractMission.STATUS_FINISHED then
				return getIsSplitShapeSplit(shape)
			elseif self.status == AbstractMission.STATUS_RUNNING then
				return true
			end
		end
	end

	return nil
end

function DeadwoodMission.canRun()
	local numSpots = #g_missionManager.deadwoodMission.spots

	if numSpots == 0 then
		return false
	end

	if g_missionManager.deadwoodMission.treeIndex == nil then
		return false
	end

	if DeadwoodMission.MAX_NUM_INSTANCES <= DeadwoodMission.NUM_INSTANCES then
		return false
	end

	return true
end

g_missionManager:registerMissionType(DeadwoodMission, "deadwood", MissionManager.CATEGORY_FORESTRY, 1)
