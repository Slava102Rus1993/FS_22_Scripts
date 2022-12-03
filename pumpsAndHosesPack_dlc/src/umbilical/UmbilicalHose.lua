UmbilicalHose = {
	DEFAULT_POINT_DISTANCE = 5
}
local UmbilicalHose_mt = Class(UmbilicalHose)

function UmbilicalHose.new(mission, shapeCacheContainer, isServer, isClient)
	local self = setmetatable({}, UmbilicalHose_mt)
	self.mission = mission
	self.shapeCacheContainer = shapeCacheContainer
	self.isServer = isServer
	self.isClient = isClient
	self.isRunByEditor = g_isEditor or false
	local linkNode = self.isRunByEditor and g_hoseLinkNode or getRootNode()
	self.rootNode = createTransformGroup("umbilicalHoseRoot")

	link(linkNode, self.rootNode)

	self.controlPointDistance = UmbilicalHose.DEFAULT_POINT_DISTANCE
	self.points = {}
	self.size = 0
	self.lastRayCastId = 0
	self.lastDelayedActivePointId = 0
	self.connectInfo = {
		[true] = {
			leadingNodeIsDelayed = false,
			firstHoseUsed = false
		},
		[false] = {
			leadingNodeIsDelayed = false,
			firstHoseUsed = false
		}
	}

	return self
end

function UmbilicalHose:delete()
	for _, point in pairs(self.points) do
		point:delete()
	end

	delete(self.rootNode)
end

function UmbilicalHose:loadFromXMLFile(xmlFile, key, resetVehicles)
	local nodeToLoad = {}

	xmlFile:iterate(key .. ".nodes.node", function (id, nodeKey)
		local length = xmlFile:getValue(nodeKey .. "#length")

		if length == nil then
			return
		end

		local x, y, z = xmlFile:getValue(nodeKey .. "#position")

		if x == nil or y == nil or z == nil then
			return
		end

		table.insert(nodeToLoad, {
			id = id,
			info = {
				x,
				y,
				z,
				length
			}
		})
	end)

	for _, node in ipairs(nodeToLoad) do
		local x, y, z, length = unpack(node.info)
		local point = self:addPointByPosition(x, y, z, true)

		if point.hose ~= nil then
			point.hose:setLength(length)
		end
	end

	local success = self:getNumberOfControlPoints() > 0

	if success then
		self:finalize()
	else
		self:delete()
	end

	return success
end

function UmbilicalHose:saveToXMLFile(xmlFile, key)
	local i = 0

	for _, point in pairs(self.points) do
		local hoseKey = ("%s.nodes.node(%d)"):format(key, i)

		if point ~= nil then
			local length = point.length
			local x, y, z = point.lastPosition:getPosition()

			xmlFile:setValue(hoseKey .. "#length", length)
			xmlFile:setValue(hoseKey .. "#position", x, y, z)
		end

		i = i + 1
	end

	return true
end

function UmbilicalHose:readStream(streamId, connection)
	if connection:getIsServer() then
		local paramsXZ = g_currentMission.vehicleXZPosCompressionParams
		local paramsY = g_currentMission.vehicleYPosCompressionParams
		local size = streamReadInt32(streamId)

		for _ = 1, size do
			local x = NetworkUtil.readCompressedWorldPosition(streamId, paramsXZ)
			local y = NetworkUtil.readCompressedWorldPosition(streamId, paramsY)
			local z = NetworkUtil.readCompressedWorldPosition(streamId, paramsXZ)
			local point = self:addPointByPosition(x, y, z, true)

			if point.hose ~= nil then
				point.hose:setLength(point.length)
			end
		end

		self:finalize()
	end
end

function UmbilicalHose:writeStream(streamId, connection)
	if not connection:getIsServer() then
		local paramsXZ = g_currentMission.vehicleXZPosCompressionParams
		local paramsY = g_currentMission.vehicleYPosCompressionParams

		streamWriteInt32(streamId, self.size)

		for i = 1, self.size do
			local point = self.points[i]
			local x, y, z = point.lastPosition:getPosition()

			NetworkUtil.writeCompressedWorldPosition(streamId, x, paramsXZ)
			NetworkUtil.writeCompressedWorldPosition(streamId, y, paramsY)
			NetworkUtil.writeCompressedWorldPosition(streamId, z, paramsXZ)
		end
	end
end

function UmbilicalHose:setColor(color)
	self.color = color

	self:applyColor()
end

function UmbilicalHose:applyColor()
	for _, point in pairs(self.points) do
		if point.hose ~= nil then
			point.hose:setColor(self.color)
		end
	end
end

function UmbilicalHose:finalize()
	if self.isClient then
		self.tail:setConnectorState(true)
		self.head:setConnectorState(true)

		for _, point in pairs(self.points) do
			point:setHoseState(true)
		end

		self:updateCurve()
	end
end

function UmbilicalHose:getFirstHoseRecursively(point, atTail)
	if point == nil then
		return nil
	end

	if point.hose ~= nil then
		return point.hose
	end

	if atTail then
		return self:getFirstHoseRecursively(point:previous(), atTail)
	end

	return self:getFirstHoseRecursively(point:next(), atTail)
end

function UmbilicalHose:onAttach(atTail, leadingNodeIsDelayed, isHose, useFirstHose)
	local info = self.connectInfo[atTail]
	info.firstHoseUsed = isHose or useFirstHose
	info.leadingNodeIsDelayed = not isHose and leadingNodeIsDelayed

	if not self.isClient then
		return
	end

	local point = self:getControlListNode(atTail)

	if point == nil then
		return
	end

	point:setConnectorState(isHose or self:getNumberOfControlPoints() < 2)

	if info.firstHoseUsed then
		return
	end

	local hose = self:getFirstHoseRecursively(point, atTail)

	if hose ~= nil then
		hose:setActiveState(false)
	end
end

function UmbilicalHose:onDetach(atTail)
	local info = self.connectInfo[atTail]
	info.firstHoseUsed = false
	info.leadingNodeIsDelayed = false

	if not self.isClient then
		return
	end

	local point = self:getControlListNode(atTail)

	if point == nil then
		return
	end

	local mockPoint = {
		position = point.lastPosition
	}

	self:moveToTarget(point, mockPoint, atTail, false, false)
	point:setConnectorState(true)

	local hose = self:getFirstHoseRecursively(point, atTail)

	if hose ~= nil then
		hose:setActiveState(true)
	end

	self:updateCurve()
end

function UmbilicalHose:addPointByNode(node, atTail, type)
	atTail = atTail or false
	local parent = atTail and self.tail or self.head
	local lastId = #self.points
	local lastPoint = self.points[lastId]
	local id = lastId + 1
	local point = UmbilicalHosePoint.new(id, node, parent, self.isClient, self.shapeCacheContainer)

	point:setLength(self.controlPointDistance)
	point:createHose(type)
	point:setColor(self.color)

	if self.isClient then
		point:setConnectorState(lastPoint == nil)
	end

	if lastPoint ~= nil and self.isClient then
		local activateConnector = atTail and lastPoint == self.head or not atTail and lastPoint == self.tail

		lastPoint:setConnectorState(activateConnector)
	end

	if atTail then
		table.insert(self.points, point)
	else
		table.insert(self.points, 1, point)
	end

	self.size = self.size + 1
	self.points = self:realignPoints()

	return point
end

function UmbilicalHose:addPointByPosition(x, y, z, atTail)
	local node = createTransformGroup("pointNode")

	link(self.rootNode, node)
	setWorldTranslation(node, x, y, z)

	return self:addPointByNode(node, atTail)
end

function UmbilicalHose:removePointAtEnds(atTail)
	local atPosition = atTail and self.tail.id or self.head.id
	local removedPoint = self.points[atPosition]
	self.points[atPosition] = nil
	local next = atTail and self.head.id or atPosition + 1
	local last = atTail and atPosition - 1 or self.tail.id
	self.head = self.points[next]
	self.tail = self.points[last]
	self.size = self.size - 1
	self.points = self:realignPoints()

	return removedPoint
end

function UmbilicalHose:deletePoint(atTail)
	local point = self:removePointAtEnds(atTail)

	point:delete()

	return true
end

function UmbilicalHose:realignPoints()
	local points = {}

	for _, alignPoint in pairs(self.points) do
		local alignLastId = #points
		local alignLastPoint = points[alignLastId]
		local alignId = alignLastId + 1
		alignPoint.id = alignId
		points[alignId] = alignPoint

		if alignLastPoint ~= nil then
			alignLastPoint._next = alignPoint
			alignPoint._prev = alignLastPoint
		end
	end

	self.head = points[1]
	self.tail = points[#points]

	return points
end

function UmbilicalHose:getAttachNode(atTail)
	if not atTail then
		return self.tail
	end

	return self.head
end

function UmbilicalHose:getControlListNode(atTail)
	if atTail then
		return self.tail
	end

	return self.head
end

function UmbilicalHose:getConnectNode(atTail, getNextOrPreviousInstead)
	local point = self:getControlListNode(atTail)

	if getNextOrPreviousInstead then
		local nextOrPreviousPoint = nil

		if atTail then
			nextOrPreviousPoint = point:previous()
		else
			nextOrPreviousPoint = point:next()
		end

		if nextOrPreviousPoint ~= nil then
			return nextOrPreviousPoint
		end
	end

	return point
end

function UmbilicalHose:getTail()
	return self.tail
end

function UmbilicalHose:getHead()
	return self.head
end

function UmbilicalHose:getNumberOfControlPoints()
	return self.size
end

function UmbilicalHose:getLength()
	return self:getNumberOfControlPoints() * self.controlPointDistance
end

function UmbilicalHose:hasLengthLeft()
	return self.size > 0
end

function UmbilicalHose:move(x, y, z, atTail, updateLinkedNodes)
	local mockPoint = {
		position = Vector3(x, y, z)
	}

	if updateLinkedNodes then
		if atTail then
			if self.lastRayCastId <= self.lastDelayedActivePointId then
				self.lastRayCastId = self.size
			end
		elseif self.lastDelayedActivePointId <= self.lastRayCastId then
			self.lastRayCastId = 0
		end

		if atTail then
			self.lastRayCastId = math.max(self.lastRayCastId - 1, 0)
		else
			self.lastRayCastId = math.min(self.lastRayCastId + 1, self.size)
		end
	end

	if atTail then
		self:moveTail(mockPoint, updateLinkedNodes)
	else
		self:moveHead(mockPoint, updateLinkedNodes)
	end

	self:updateCurve()
end

function UmbilicalHose:moveTail(mockPoint, updateLinkedNodes)
	local lead = self.tail

	if lead == nil then
		return
	end

	local info = self.connectInfo[true]

	self:moveToTarget(lead, mockPoint, true, info.leadingNodeIsDelayed, true)

	if not updateLinkedNodes then
		return
	end

	while lead._prev ~= nil do
		local controlPoint = lead
		local targetControlPoint = lead:previous()

		self:moveToTarget(targetControlPoint, controlPoint, true, true, false)

		lead = lead:previous()
	end
end

function UmbilicalHose:moveHead(mockPoint, updateLinkedNodes)
	local lead = self.head

	if lead == nil then
		return
	end

	local info = self.connectInfo[false]

	self:moveToTarget(lead, mockPoint, false, info.leadingNodeIsDelayed, true)

	if not updateLinkedNodes then
		return
	end

	while lead._next ~= nil do
		local controlPoint = lead
		local targetControlPoint = lead:next()

		self:moveToTarget(targetControlPoint, controlPoint, false, true, false)

		lead = lead:next()
	end
end

function UmbilicalHose:moveToTarget(point, targetPoint, atTail, delayUpdate, isLeadingNode)
	if point.isDeleted then
		return
	end

	local currentDistance = point.position - targetPoint.position
	local distanceSq = currentDistance:magnitudeSquared()
	local direction = Vector3.zero

	if point.lengthSq < distanceSq then
		direction = currentDistance:normalized()
	end

	local info = self.connectInfo[atTail]
	local pointLength = delayUpdate and point.length or info.firstHoseUsed and 0 or point.length
	local pointSq = pointLength * pointLength
	local update = pointSq < math.abs(math.round(distanceSq, 1)) or not delayUpdate

	if update then
		if delayUpdate then
			local distance = math.sqrt(distanceSq)
			local difference = math.abs(distance - point.length)
			local movement = direction * difference * 0.5
			point.position = point.position - movement
		else
			point.position = targetPoint.position
		end

		if not isLeadingNode and not self.isRunByEditor and (point.id == self.lastRayCastId or point.id == 2 or point.id == self.size - 1) then
			point.position.y = self:getTerrainLimitedYPosition(point.position.x, point.position.y, point.position.z)
		end

		setWorldTranslation(point.node, point.position.x, point.position.y, point.position.z)

		point.lastDirection = direction
		point.lastPosition = point.position
		self.lastDelayedActivePointId = point.id
	end

	if self.isClient then
		if point.hose ~= nil then
			point.hose:setDirection(atTail)
		end

		I3DUtil.setWorldDirection(point.node, direction.x, direction.y, direction.z, 0, 0, 1)
	end
end

function UmbilicalHose:getTerrainLimitedYPosition(x, y, z)
	local terrainY = getTerrainHeightAtWorldPos(self.mission.terrainRootNode, x, y, z)
	self.correctedY = -1

	raycastClosest(x, y + HoseBase.Y_OFFSET, z, 0, -1, 0, "groundRaycastCallback", 5, self, CollisionFlag.TERRAIN + CollisionFlag.STATIC_OBJECT)

	return math.max(terrainY, self.correctedY) + HoseBase.Y_OFFSET
end

function UmbilicalHose:groundRaycastCallback(hitObjectId, x, y, z, distance)
	if getHasTrigger(hitObjectId) then
		return true
	end

	self.correctedY = y

	return true
end

function UmbilicalHose:updateCurve()
	if self.isClient then
		local function alignConnector(point, p0, p1)
			if point.connectorIsActive then
				local direction = p0.position - p1.position

				setWorldTranslation(point.connectorNode, p1.position.x, p1.position.y, p1.position.z)
				I3DUtil.setWorldDirection(point.connectorNode, direction.x, direction.y, direction.z, 0, 1, 0)
			end
		end

		local function computeCurve(point, p0, p1, p2, p3)
			if point.id == 1 then
				alignConnector(point, p2, p0)
			elseif point.id == self.size - 1 then
				local lastPoint = self.points[self.size]

				alignConnector(lastPoint, p1, p3)
			end

			if point ~= nil and point.hose ~= nil then
				point.hose:curveToByVectors(p0.position, p1.position, p2.position, p3.position)
			end
		end

		self:iterateCurve(computeCurve)
	end
end

function UmbilicalHose:iterateCurve(func)
	local points = self.points
	local numOfPoints = #points
	local iterateAmount = numOfPoints - 1

	if numOfPoints < 2 then
		return
	end

	if numOfPoints == 2 then
		local point = points[1]
		local next = points[2]

		func(point, point, point, next, next)

		return
	end

	for i = 1, iterateAmount do
		local point = points[i]
		local next = points[math.min(i + 1, numOfPoints)]
		local isFirst = i == 1
		local isLast = i == iterateAmount
		local p0, p1, p2, p3 = nil

		if isFirst then
			p3 = points[i + 2]
			p2 = next
			p1 = point
			p0 = point
		elseif isLast then
			p3 = next
			p2 = next
			p1 = points[numOfPoints - 1]
			p0 = points[numOfPoints - 2]
		else
			p3 = points[i + 2]
			p2 = next
			p1 = point
			p0 = points[i - 1]
		end

		if point ~= nil and p0 ~= nil and p1 ~= nil and p2 ~= nil and p3 ~= nil and not point.isDeleted then
			func(point, p0, p1, p2, p3)
		end
	end
end

function UmbilicalHose:draw()
	local tailPoint = self.tail
	local headPoint = self.head

	local function drawPoint(point, text)
		text = text or tostring(point.id)

		if not self.isRunByEditor then
			DebugUtil.drawDebugNode(point.node, text, false, 0)
		else
			local x, y, z = point.lastPosition:getPosition()

			Utils.renderTextAtWorldPosition(x, y, z, text, getCorrectTextSize(0.012), 0)
		end
	end

	drawPoint(tailPoint, "TAIL")
	drawPoint(headPoint, "HEAD")

	local smoothingSteps = 5

	local function drawCurve(point, p0, p1, p2, p3)
		drawPoint(point)

		for t = 0, 1, 1 / smoothingSteps do
			local x = Curve.catmullRomTensionPoint(t, p0.position.x, p1.position.x, p2.position.x, p3.position.x, 0.5)
			local y = Curve.catmullRomTensionPoint(t, p0.position.y, p1.position.y, p2.position.y, p3.position.y, 0.5)
			local z = Curve.catmullRomTensionPoint(t, p0.position.z, p1.position.z, p2.position.z, p3.position.z, 0.5)

			drawDebugPoint(x, y, z, 0, 0, 1, 1)
		end
	end

	self:iterateCurve(drawCurve)
end
