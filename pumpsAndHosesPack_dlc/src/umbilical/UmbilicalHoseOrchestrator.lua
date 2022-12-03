UmbilicalHoseOrchestrator = {
	CLASS_NAME = "UmbilicalHoseOrchestrator",
	TYPE_HEAD = 1,
	TYPE_TAIL = 2
}
local UmbilicalHoseOrchestrator_mt = Class(UmbilicalHoseOrchestrator, Object)

InitObjectClass(UmbilicalHoseOrchestrator, UmbilicalHoseOrchestrator.CLASS_NAME)
g_xmlManager:addInitSchemaFunction(function ()
	local savegameSchema = ItemSystem.xmlSchemaSavegame

	UmbilicalHoseOrchestrator.registerSavegameXMLPaths(savegameSchema, "items.item(?)")
end)

function UmbilicalHoseOrchestrator.registerSavegameXMLPaths(schema, baseName)
	schema:register(XMLValueType.INT, baseName .. "#type", "Type of hose")
	schema:register(XMLValueType.COLOR, baseName .. "#color", "Color of the hose", "0.05 0.05 0.05 0")
	schema:register(XMLValueType.FLOAT, baseName .. "#damage", "The hose damage")
	schema:register(XMLValueType.FLOAT, baseName .. "#length", "The hose length")
	schema:register(XMLValueType.FLOAT, baseName .. "#capacity", "The hose capacity")
	schema:register(XMLValueType.INT, baseName .. "#farmId", "Id of owner farm")
	schema:register(XMLValueType.INT, baseName .. "#activeConnectorType", "Active connector type")
	schema:register(XMLValueType.BOOL, baseName .. "#isFinalized", "Hose is finalized")
	UmbilicalHoseOrchestrator.registerSavegameXMLPathsForNodes(schema, baseName .. ".nodes.node(?)")
end

function UmbilicalHoseOrchestrator.registerSavegameXMLPathsForNodes(schema, baseName)
	schema:register(XMLValueType.VECTOR_TRANS, baseName .. "#position", " position")
	schema:register(XMLValueType.VECTOR_ROT, baseName .. "#direction", " direction")
	schema:register(XMLValueType.FLOAT, baseName .. "#length", "length")
end

function UmbilicalHoseOrchestrator.new(isServer, isClient, mt)
	return UmbilicalHoseOrchestrator.construct(g_currentMission, g_currentMission.manure.shapeCacheContainer, isServer, isClient, mt)
end

function UmbilicalHoseOrchestrator.construct(mission, shapeCacheContainer, isServer, isClient, mt)
	local self = Object.new(isServer, isClient, mt or UmbilicalHoseOrchestrator_mt)

	registerObjectClassName(self, UmbilicalHoseOrchestrator.CLASS_NAME)

	self.mission = mission
	self.hose = UmbilicalHose.new(mission, shapeCacheContainer, isServer, isClient)

	self:setColor()

	self.connectorsInfo = {
		[UmbilicalHoseOrchestrator.TYPE_HEAD] = nil,
		[UmbilicalHoseOrchestrator.TYPE_TAIL] = nil
	}
	self.networkTimeInterpolator = InterpolationTime.new(1.2)
	self.connectorsPositionInfo = {
		[UmbilicalHoseOrchestrator.TYPE_HEAD] = {
			sendX = 0,
			updateLinkedNodes = false,
			sendZ = 0,
			sendY = 0,
			positionInterpolator = InterpolatorPosition.new(0, 0, 0)
		},
		[UmbilicalHoseOrchestrator.TYPE_TAIL] = {
			sendX = 0,
			updateLinkedNodes = false,
			sendZ = 0,
			sendY = 0,
			positionInterpolator = InterpolatorPosition.new(0, 0, 0)
		}
	}
	self.activeConnectorType = UmbilicalHoseOrchestrator.TYPE_TAIL
	self.dirtyFlag = self:getNextDirtyFlag()

	self.mission.itemSystem:addItemToSave(self)
	self.mission.manure:addUmbilicalHose(self)

	self.damage = 0
	self.damageByCurve = 0
	self.damageSent = 0
	self.capacity = 0
	self.capacitySent = 0
	self.length = 0
	self.lengthSent = 0
	self.isFinalized = false
	self.infoDirtyFlag = self:getNextDirtyFlag()

	return self
end

function UmbilicalHoseOrchestrator:delete()
	self.hose:delete()
	self.mission.itemSystem:removeItemToSave(self)
	unregisterObjectClassName(self)
	UmbilicalHoseOrchestrator:superClass().delete(self)
end

function UmbilicalHoseOrchestrator:loadFromXMLFile(xmlFile, key, resetVehicles)
	local color = xmlFile:getValue(key .. "#color", "0.05 0.05 0.05 0", true)

	self:setColor(color)

	local damage = xmlFile:getValue(key .. "#damage", self.damage)

	self:setDamageAmount(damage, true)

	local farmId = xmlFile:getValue(key .. "#farmId", AccessHandler.EVERYONE)

	self:setOwnerFarmId(farmId or AccessHandler.EVERYONE)

	if not self.hose:loadFromXMLFile(xmlFile, key, resetVehicles) then
		return false
	end

	local capacity = xmlFile:getValue(key .. "#capacity", self.capacity)
	local length = xmlFile:getValue(key .. "#length", self.length)

	if capacity == 0 and length == 0 and self.hose:getNumberOfControlPoints() > 0 then
		capacity = self:getCorrectedNumberOfControlPointsAtHose() * self.hose.controlPointDistance
		length = capacity

		Logging.warning("Loading hose without capacity and length, but with control points. Capacity and length will be set to %s and %s", capacity, length)
	end

	self:setCapacity(capacity)
	self:addLength(length)

	self.activeConnectorType = xmlFile:getValue(key .. "#activeConnectorType", self.activeConnectorType)
	local head = self:getConnectPointAt(UmbilicalHoseOrchestrator.TYPE_HEAD)
	local tail = self:getConnectPointAt(UmbilicalHoseOrchestrator.TYPE_TAIL)
	local hx, hy, hz = head.lastPosition:getPosition()
	local tx, ty, tz = tail.lastPosition:getPosition()

	self:changePositionInterpolation(UmbilicalHoseOrchestrator.TYPE_HEAD, hx, hy, hz, false)
	self:changePositionInterpolation(UmbilicalHoseOrchestrator.TYPE_TAIL, tx, ty, tz, false)
	self:raiseActive()

	local isFinalized = xmlFile:getValue(key .. "#isFinalized", true)

	self:setIsFinalized(isFinalized)

	return true
end

function UmbilicalHoseOrchestrator:saveToXMLFile(xmlFile, key, usedModNames, connectorType)
	xmlFile:setValue(key .. "#color", unpack(self:getColor()))
	xmlFile:setValue(key .. "#damage", self.damage)
	xmlFile:setValue(key .. "#farmId", self:getOwnerFarmId())
	xmlFile:setValue(key .. "#capacity", self:getCapacity())
	xmlFile:setValue(key .. "#length", self:getLength())
	xmlFile:setValue(key .. "#activeConnectorType", self.activeConnectorType)
	xmlFile:setValue(key .. "#isFinalized", self.isFinalized)

	return self.hose:saveToXMLFile(xmlFile, key)
end

function UmbilicalHoseOrchestrator:readStream(streamId, connection)
	UmbilicalHoseOrchestrator:superClass().readStream(self, streamId, connection)

	if connection:getIsServer() then
		local paramsXZ = g_currentMission.vehicleXZPosCompressionParams
		local paramsY = g_currentMission.vehicleYPosCompressionParams

		self.hose:readStream(streamId, connection)

		self.activeConnectorType = streamReadUIntN(streamId, 2) + 1
		local color = NetworkHelper.readCompressedLinearColor(streamId)

		self:setColor(color)

		local damage = streamReadFloat32(streamId)

		self:setDamageAmount(damage, true)

		self.length = streamReadFloat32(streamId)
		self.capacity = streamReadFloat32(streamId)
		self.isFinalized = streamReadBool(streamId)
		local atTail = self.activeConnectorType == UmbilicalHoseOrchestrator.TYPE_TAIL

		for connectorType, positionInfo in pairs(self.connectorsPositionInfo) do
			local x = NetworkUtil.readCompressedWorldPosition(streamId, paramsXZ)
			local y = NetworkUtil.readCompressedWorldPosition(streamId, paramsY)
			local z = NetworkUtil.readCompressedWorldPosition(streamId, paramsXZ)
			positionInfo.updateLinkedNodes = streamReadBool(streamId)

			if connectorType == self.activeConnectorType then
				self.hose:move(x, y, z, atTail, positionInfo.updateLinkedNodes)
			end

			positionInfo.positionInterpolator:setPosition(x, y, z)
		end

		self.networkTimeInterpolator:reset()
		NetworkHelper.readUmbilicalHoseConnectorInfo(streamId, self.connectorsInfo[UmbilicalHoseOrchestrator.TYPE_HEAD])
		NetworkHelper.readUmbilicalHoseConnectorInfo(streamId, self.connectorsInfo[UmbilicalHoseOrchestrator.TYPE_TAIL])
	end
end

function UmbilicalHoseOrchestrator:writeStream(streamId, connection)
	UmbilicalHoseOrchestrator:superClass().writeStream(self, streamId, connection)

	if not connection:getIsServer() then
		local paramsXZ = g_currentMission.vehicleXZPosCompressionParams
		local paramsY = g_currentMission.vehicleYPosCompressionParams

		self.hose:writeStream(streamId, connection)
		streamWriteUIntN(streamId, self.activeConnectorType - 1, 2)
		NetworkHelper.writeCompressedLinearColor(streamId, self.color)
		streamWriteFloat32(streamId, self.damage)
		streamWriteFloat32(streamId, self.length)
		streamWriteFloat32(streamId, self.capacity)
		streamWriteBool(streamId, self.isFinalized)

		for _, positionInfo in pairs(self.connectorsPositionInfo) do
			local x = positionInfo.sendX
			local y = positionInfo.sendY
			local z = positionInfo.sendZ

			NetworkUtil.writeCompressedWorldPosition(streamId, x, paramsXZ)
			NetworkUtil.writeCompressedWorldPosition(streamId, y, paramsY)
			NetworkUtil.writeCompressedWorldPosition(streamId, z, paramsXZ)
			streamWriteBool(streamId, positionInfo.updateLinkedNodes)
		end

		NetworkHelper.writeUmbilicalHoseConnectorInfo(streamId, self.connectorsInfo[UmbilicalHoseOrchestrator.TYPE_HEAD])
		NetworkHelper.writeUmbilicalHoseConnectorInfo(streamId, self.connectorsInfo[UmbilicalHoseOrchestrator.TYPE_TAIL])
	end
end

function UmbilicalHoseOrchestrator:readUpdateStream(streamId, timestamp, connection)
	UmbilicalHoseOrchestrator:superClass().readUpdateStream(self, streamId, timestamp, connection)

	if connection:getIsServer() and streamReadBool(streamId) then
		self.networkTimeInterpolator:startNewPhaseNetwork()

		self.activeConnectorType = streamReadUIntN(streamId, 2) + 1
		local paramsXZ = g_currentMission.vehicleXZPosCompressionParams
		local paramsY = g_currentMission.vehicleYPosCompressionParams

		for _, positionInfo in pairs(self.connectorsPositionInfo) do
			local x = NetworkUtil.readCompressedWorldPosition(streamId, paramsXZ)
			local y = NetworkUtil.readCompressedWorldPosition(streamId, paramsY)
			local z = NetworkUtil.readCompressedWorldPosition(streamId, paramsXZ)
			positionInfo.updateLinkedNodes = streamReadBool(streamId)

			positionInfo.positionInterpolator:setTargetPosition(x, y, z)
		end
	end

	if connection:getIsServer() and streamReadBool(streamId) then
		local damage = streamReadFloat32(streamId)

		self:setDamageAmount(damage, true)

		self.length = streamReadFloat32(streamId)
		self.capacity = streamReadFloat32(streamId)
		self.isFinalized = streamReadBool(streamId)
	end
end

function UmbilicalHoseOrchestrator:writeUpdateStream(streamId, connection, dirtyMask)
	UmbilicalHoseOrchestrator:superClass().writeUpdateStream(self, streamId, connection, dirtyMask)

	if not connection:getIsServer() and streamWriteBool(streamId, bitAND(dirtyMask, self.dirtyFlag) ~= 0) then
		streamWriteUIntN(streamId, self.activeConnectorType - 1, 2)

		local paramsXZ = g_currentMission.vehicleXZPosCompressionParams
		local paramsY = g_currentMission.vehicleYPosCompressionParams

		for _, positionInfo in pairs(self.connectorsPositionInfo) do
			NetworkUtil.writeCompressedWorldPosition(streamId, positionInfo.sendX, paramsXZ)
			NetworkUtil.writeCompressedWorldPosition(streamId, positionInfo.sendY, paramsY)
			NetworkUtil.writeCompressedWorldPosition(streamId, positionInfo.sendZ, paramsXZ)
			streamWriteBool(streamId, positionInfo.updateLinkedNodes)
		end
	end

	if not connection:getIsServer() and streamWriteBool(streamId, bitAND(dirtyMask, self.infoDirtyFlag) ~= 0) then
		streamWriteFloat32(streamId, self.damage)
		streamWriteFloat32(streamId, self.length)
		streamWriteFloat32(streamId, self.capacity)
		streamWriteBool(streamId, self.isFinalized)
	end
end

function UmbilicalHoseOrchestrator:update(dt)
	UmbilicalHoseOrchestrator:superClass().update(self, dt)

	if not self.isServer then
		self.networkTimeInterpolator:update(dt)

		local interpolationAlpha = self.networkTimeInterpolator:getAlpha()

		for type, positionInfo in pairs(self.connectorsPositionInfo) do
			local x, y, z = positionInfo.positionInterpolator:getInterpolatedValues(interpolationAlpha)
			local point = self:getConnectPointAt(type)
			local movementThreshold = 0.0001
			local hasMoved = movementThreshold < math.abs(point.position.x - x) or movementThreshold < math.abs(point.position.y - y) or movementThreshold < math.abs(point.position.z - z)

			if hasMoved then
				self:setHosePosition(x, y, z, type, false, false)

				if type == self.activeConnectorType then
					self:setHosePosition(x, y, z, type, positionInfo.updateLinkedNodes, false)
				end
			end
		end

		if self.networkTimeInterpolator:isInterpolating() then
			self:raiseActive()
		end
	end

	if self.isServer then
		self:determineHosesToUpdate()
	end
end

function UmbilicalHoseOrchestrator:determineHosesToUpdate()
	local atTail = self:isInTailMode()
	local headInfo = self.connectorsInfo[UmbilicalHoseOrchestrator.TYPE_HEAD]
	local tailInfo = self.connectorsInfo[UmbilicalHoseOrchestrator.TYPE_TAIL]

	local function moveByInfo(info, connectorType)
		if not info.isHose then
			return
		end

		local attachedConnectorType = info.object:getConnectorTypeOfObject(self)

		if attachedConnectorType ~= nil and (info.object.dependingObject == nil or self.dependingObject ~= info.object.dependingObject) then
			local node = self:getConnectPointNodeAt(connectorType)

			info.object:updatePositionByHoseNode(node, attachedConnectorType, self)
			info.object:raiseActive()
		end
	end

	if atTail and headInfo ~= nil then
		moveByInfo(headInfo, UmbilicalHoseOrchestrator.TYPE_HEAD)
	elseif not atTail and tailInfo ~= nil then
		moveByInfo(tailInfo, UmbilicalHoseOrchestrator.TYPE_TAIL)
	end
end

function UmbilicalHoseOrchestrator:draw(dt)
	UmbilicalHoseOrchestrator:superClass().draw(self, dt)

	if self.hose ~= nil then
		self.hose:draw()
	end
end

function UmbilicalHoseOrchestrator:isInTailMode()
	return self.activeConnectorType == UmbilicalHoseOrchestrator.TYPE_TAIL
end

function UmbilicalHoseOrchestrator:setColor(color)
	local r, g, b, m = unpack(color or {})
	r = r or 0.05
	g = g or 0.05
	b = b or 0.05
	m = m or 0
	self.color = {
		r,
		g,
		b,
		m
	}

	self.hose:setColor(self.color)
end

function UmbilicalHoseOrchestrator:getColor()
	return self.color
end

function UmbilicalHoseOrchestrator:setDamageAmount(amount, force)
	self.damage = math.min(math.max(amount, 0), 1)
	self.damageByCurve = math.max(self.damage - 0.2, 0) / 0.8

	if self.isServer then
		local diff = self.damageSent - self.damage

		if math.abs(diff) > 0.01 or force then
			self:raiseDirtyFlags(self.infoDirtyFlag)

			self.damageSent = self.damage
		end
	end
end

function UmbilicalHoseOrchestrator:getDamageAmount()
	return self.damageByCurve
end

function UmbilicalHoseOrchestrator:getConnectPointAt(connectorType, getNextOrPreviousInstead)
	getNextOrPreviousInstead = getNextOrPreviousInstead or false
	local atTail = connectorType == UmbilicalHoseOrchestrator.TYPE_TAIL

	return self.hose:getConnectNode(atTail, getNextOrPreviousInstead)
end

function UmbilicalHoseOrchestrator:getConnectPointNodeAt(connectorType, getNextOrPreviousInstead)
	local point = self:getConnectPointAt(connectorType, getNextOrPreviousInstead)

	return point.node
end

function UmbilicalHoseOrchestrator:getGuideConnectPointNodeAt(connectorType, getNextOrPreviousInstead)
	local point = self:getConnectPointAt(connectorType, getNextOrPreviousInstead)

	return point.invertNode
end

function UmbilicalHoseOrchestrator:hasControlPoints()
	return self.hose:getNumberOfControlPoints() > 0
end

function UmbilicalHoseOrchestrator:hasOnePoint()
	return self.hose:getNumberOfControlPoints() == 1
end

function UmbilicalHoseOrchestrator:hasLengthLeft()
	return self.hose:hasLengthLeft()
end

function UmbilicalHoseOrchestrator:getLength()
	return self.length
end

function UmbilicalHoseOrchestrator:getTotalLength()
	local length = self:getLength()

	for _, info in pairs(self.connectorsInfo) do
		if info.object ~= self and info.isHose then
			length = length + info.object:getLength()
		end
	end

	return length
end

function UmbilicalHoseOrchestrator:addLength(length)
	self.length = math.clamp(self.length + length, 0, self.capacity)

	if self.isServer then
		self:raiseDirtyFlags(self.infoDirtyFlag)

		self.lengthSent = self.length
	end
end

function UmbilicalHoseOrchestrator:resolveControlPoints(guideNode, isUnwinding)
	local targetPointsAtHose = self:getNumberOfControlPointsForLength(self.length)
	local pointsAtHose = self:getCorrectedNumberOfControlPointsAtHose()
	local diff = targetPointsAtHose - pointsAtHose

	if diff ~= 0 then
		local removeControlPoint = diff == -1

		if removeControlPoint then
			if not isUnwinding then
				self:removeControlPoint(self:isInTailMode())
			end
		elseif isUnwinding then
			local maxPointsAtHose = self:getNumberOfControlPointsForLength(self.capacity)
			local isLastNode = targetPointsAtHose == maxPointsAtHose

			if targetPointsAtHose <= maxPointsAtHose then
				self:addControlPoint(guideNode, isLastNode)
			end
		end
	end
end

function UmbilicalHoseOrchestrator:setCapacity(capacity)
	self.capacity = capacity

	if self.isServer then
		self:raiseDirtyFlags(self.infoDirtyFlag)

		self.capacitySent = self.capacity
	end
end

function UmbilicalHoseOrchestrator:getCapacity()
	return self.capacity
end

function UmbilicalHoseOrchestrator:getNumberOfControlPointsForLength(length)
	local delta = length / self.hose.controlPointDistance

	return math.floor(delta) + 1
end

function UmbilicalHoseOrchestrator:getCorrectedNumberOfControlPointsAtHose()
	return math.max(self.hose:getNumberOfControlPoints(), 0)
end

function UmbilicalHoseOrchestrator:getLastPointLength()
	local pointsAtHose = self:getCorrectedNumberOfControlPointsAtHose()

	return self.length - pointsAtHose * self.hose.controlPointDistance
end

function UmbilicalHoseOrchestrator:getConnectorInfoByType(connectorType)
	connectorType = connectorType or UmbilicalHoseOrchestrator.TYPE_TAIL

	return self.connectorsInfo[connectorType]
end

function UmbilicalHoseOrchestrator:getConnectorsInfo()
	return self.connectorsInfo
end

function UmbilicalHoseOrchestrator:hasConnectionOnBothEnds()
	return self.connectorsInfo[UmbilicalHoseOrchestrator.TYPE_HEAD] ~= nil and self.connectorsInfo[UmbilicalHoseOrchestrator.TYPE_TAIL] ~= nil
end

function UmbilicalHoseOrchestrator:hasHosesConnected(onBothEnds)
	onBothEnds = onBothEnds or false
	local headInfo = self.connectorsInfo[UmbilicalHoseOrchestrator.TYPE_HEAD]
	local tailInfo = self.connectorsInfo[UmbilicalHoseOrchestrator.TYPE_TAIL]
	local hoseAtHead = headInfo ~= nil and headInfo.isHose
	local hoseAtTail = tailInfo ~= nil and tailInfo.isHose

	if onBothEnds then
		return hoseAtHead and hoseAtTail
	end

	return hoseAtHead or hoseAtTail
end

function UmbilicalHoseOrchestrator:hasVehicleConnected(onBothEnds)
	onBothEnds = onBothEnds or false
	local headInfo = self.connectorsInfo[UmbilicalHoseOrchestrator.TYPE_HEAD]
	local tailInfo = self.connectorsInfo[UmbilicalHoseOrchestrator.TYPE_TAIL]
	local vehicleAtHead = headInfo ~= nil and not headInfo.isHose
	local vehicleAtTail = tailInfo ~= nil and not tailInfo.isHose

	if onBothEnds then
		return vehicleAtHead and vehicleAtTail
	end

	return vehicleAtHead or vehicleAtTail
end

function UmbilicalHoseOrchestrator:isAlreadySaved(connectorType)
	local atTail = connectorType == UmbilicalHoseOrchestrator.TYPE_TAIL
	local headInfo = self.connectorsInfo[UmbilicalHoseOrchestrator.TYPE_HEAD]
	local tailInfo = self.connectorsInfo[UmbilicalHoseOrchestrator.TYPE_TAIL]

	if atTail then
		return headInfo ~= nil and headInfo.isSaved
	end

	return tailInfo ~= nil and tailInfo.isSaved
end

function UmbilicalHoseOrchestrator:isSavedAt(connectorType)
	local info = self.connectorsInfo[connectorType]

	return info ~= nil and info.isSaved
end

function UmbilicalHoseOrchestrator:searchObject(root, predicate, atConnectorType)
	if root == nil then
		return nil
	end

	for connectorType, info in pairs(self.connectorsInfo) do
		if connectorType ~= atConnectorType and info.object ~= root then
			if info.isHose then
				local hose = info.object
				local object = hose:searchObject(root, predicate, hose:getConnectorTypeOfObject(self))

				if object ~= nil then
					return object, connectorType
				end
			elseif predicate == nil or predicate(info.object, connectorType) then
				return info.object, connectorType
			end
		end
	end

	return nil
end

function UmbilicalHoseOrchestrator:collectAttachedUmbilicalHoses(root, list, atConnectorType)
	if root == nil then
		return nil
	end

	if list == nil then
		list = {}
	end

	for connectorType, info in pairs(self.connectorsInfo) do
		if connectorType ~= atConnectorType and info.object ~= root and info.isHose then
			table.addElement(list, info.object)
			info.object:collectAttachedUmbilicalHoses(root, list, info.object:getConnectorTypeOfObject(self))
		end
	end

	table.addElement(list, root)

	return list
end

function UmbilicalHoseOrchestrator:attachUmbilicalHose(toUmbilicalHose, fromConnectorType, toConnectorType, createGuide, noEventSend)
	UmbilicalHoseConnectorAttachEvent.sendEvent(self, toUmbilicalHose, fromConnectorType, toConnectorType, createGuide, noEventSend)
	self:onAttach(toUmbilicalHose, fromConnectorType, false, false)
	toUmbilicalHose:onAttach(self, toConnectorType, false, true)

	local point = self:getConnectPointAt(fromConnectorType)

	if self.isClient then
		point:setConnectorState(false)
	end

	if self.isServer then
		local targetPoint = toUmbilicalHose:getConnectPointAt(toConnectorType)

		self:updatePositionByHoseNode(targetPoint.node, fromConnectorType, toUmbilicalHose, true)
		toUmbilicalHose:updatePositionByHoseNode(point.node, toConnectorType, self, true)
	end

	self:raiseActive()
	toUmbilicalHose:raiseActive()
end

function UmbilicalHoseOrchestrator:detachUmbilicalHose(connectorType, deleteUmbilicalHose, noEventSend)
	assert(connectorType ~= nil)
	UmbilicalHoseConnectorDetachEvent.sendEvent(self, connectorType, deleteUmbilicalHose, noEventSend)

	local info = self.connectorsInfo[connectorType]
	local object = info.object

	if self.isServer then
		local targetPoint = self:getConnectPointAt(connectorType)

		self:updatePositionByNode(targetPoint.node, -1, true, connectorType, true)

		local toConnectorType = object:getConnectorTypeOfObject(self)

		object:updatePositionByNode(targetPoint.node, 1, true, toConnectorType, true)
	end

	self:onDetach(object, connectorType)
	object:onDetach(self)

	if self.isClient then
		local point = self:getConnectPointAt(connectorType)

		point:setConnectorState(true)
	end
end

function UmbilicalHoseOrchestrator:onAttach(object, connectorType, leadingNodeIsDelayed, canPerformUpdate, usesGuide)
	usesGuide = usesGuide or false

	assert(connectorType == UmbilicalHoseOrchestrator.TYPE_HEAD or connectorType == UmbilicalHoseOrchestrator.TYPE_TAIL)

	local isHose = object:isa(UmbilicalHoseOrchestrator)
	local isWrench = object:isa(UmbilicalHoseWrench)

	self.hose:onAttach(connectorType == UmbilicalHoseOrchestrator.TYPE_TAIL, leadingNodeIsDelayed, isHose or isWrench, usesGuide)

	self.connectorsInfo[connectorType] = {
		isSaved = false,
		object = object,
		isHose = isHose,
		canPerformUpdate = canPerformUpdate or false
	}

	if not isHose and not isWrench and self:hasVehicleConnected() then
		self.mission.itemSystem:removeItemToSave(self)

		if not self:isAlreadySaved(connectorType) then
			self.connectorsInfo[connectorType].isSaved = true
		end
	end

	self.activeConnectorType = connectorType

	self:raiseUmbilicalHoseEvent("onAttachUmbilicalHose", connectorType)
end

function UmbilicalHoseOrchestrator:onDetach(object, connectorType)
	if connectorType == nil and object ~= nil then
		connectorType = self:getConnectorTypeOfObject(object)
	end

	if connectorType ~= nil then
		self:raiseUmbilicalHoseEvent("onDetachUmbilicalHose", connectorType)

		local info = self.connectorsInfo[connectorType]

		if info ~= nil and info.object == self.dependingObject then
			self.dependingObject = nil
		end

		self.hose:onDetach(connectorType == UmbilicalHoseOrchestrator.TYPE_TAIL)

		self.connectorsInfo[connectorType] = nil
	end

	local isWrench = object:isa(UmbilicalHoseWrench)
	local hasHose = self:hasHosesConnected()
	local hasVehicle = self:hasVehicleConnected()

	if not hasVehicle and isWrench or hasHose or not hasHose and not hasVehicle then
		self.mission.itemSystem:addItemToSave(self)
	end
end

function UmbilicalHoseOrchestrator:getConnectorTypeOfObject(object)
	if object == nil then
		return nil
	end

	for connectorType, info in pairs(self.connectorsInfo) do
		if info.object == object then
			return connectorType
		end
	end

	return nil
end

function UmbilicalHoseOrchestrator:raiseUmbilicalHoseEvent(eventName, connectorType)
	local info = self.connectorsInfo[connectorType]
	local object, type = self:searchObject(info.object, function (object)
		return not object:isa(UmbilicalHoseWrench) and SpecializationUtil.hasSpecialization(UmbilicalHoseConnector, object.specializations)
	end)

	if object ~= nil and object.eventListeners[eventName] ~= nil then
		SpecializationUtil.raiseEvent(object, eventName, self, type)
	end
end

function UmbilicalHoseOrchestrator:getClosestDistanceToEnds(node, closestDistance, minDistance)
	if not entityExists(node) then
		return nil
	end

	local function isPointInRange(point, connectorType)
		if not entityExists(point.node) then
			return nil
		end

		local distance = calcDistanceFrom(node, point.node)

		if distance < minDistance and distance < closestDistance then
			return point.node, distance, connectorType
		end

		return nil
	end

	local nodeInRange, distance, connectorType = isPointInRange(self.hose:getHead(), UmbilicalHoseOrchestrator.TYPE_HEAD)

	if nodeInRange ~= nil then
		return nodeInRange, distance, connectorType
	end

	return isPointInRange(self.hose:getTail(), UmbilicalHoseOrchestrator.TYPE_TAIL)
end

function UmbilicalHoseOrchestrator:updatePositionByHoseNode(node, connectorType, dependingObject, force)
	self.dependingObject = dependingObject

	return self:updatePositionByNode(node, 0, true, connectorType, force)
end

function UmbilicalHoseOrchestrator:updatePositionByNode(node, offset, updateLinkedNodes, connectorType, force, limitToGround)
	updateLinkedNodes = updateLinkedNodes or false
	force = force or false

	if limitToGround == nil then
		limitToGround = true
	end

	local x, y, z = localToWorld(node, 0, 0, offset)

	if limitToGround then
		y = self.hose:getTerrainLimitedYPosition(x, y, z)
	end

	local movementIsValid = true

	if self:hasControlPoints() and not force then
		movementIsValid = self:guardMovement(node, connectorType)
	end

	local positionInfo = self.connectorsPositionInfo[connectorType]
	local movementThreshold = 0.005
	local hasMoved = movementThreshold < math.abs(positionInfo.sendX - x) or movementThreshold < math.abs(positionInfo.sendY - y) or movementThreshold < math.abs(positionInfo.sendZ - z)

	self:raiseActive()

	if hasMoved and movementIsValid or force then
		self:setHosePosition(x, y, z, connectorType, updateLinkedNodes, true)
	end

	return hasMoved, movementIsValid
end

function UmbilicalHoseOrchestrator:setHosePosition(x, y, z, activeConnectorType, updateLinkedNodes, changeInterpolation)
	local atTail = activeConnectorType == UmbilicalHoseOrchestrator.TYPE_TAIL

	self.hose:move(x, y, z, atTail, updateLinkedNodes)

	if self.mission.manure.isDebug then
		self.hose:draw()
	end

	if changeInterpolation and self.isServer then
		if updateLinkedNodes then
			self.activeConnectorType = activeConnectorType
		end

		local oppositeConnectorType = atTail and UmbilicalHoseOrchestrator.TYPE_HEAD or UmbilicalHoseOrchestrator.TYPE_TAIL
		local point = self:getConnectPointAt(oppositeConnectorType)

		if point ~= nil then
			local px, py, pz = point.lastPosition:getPosition()

			self:changePositionInterpolation(oppositeConnectorType, px, py, pz, false)
		end

		self:changePositionInterpolation(activeConnectorType, x, y, z, updateLinkedNodes)
	end
end

function UmbilicalHoseOrchestrator:changePositionInterpolation(connectorType, x, y, z, updateLinkedNodes)
	local positionInfo = self.connectorsPositionInfo[connectorType]

	if not self.isServer then
		positionInfo.positionInterpolator:setPosition(x, y, z)
	else
		self:raiseDirtyFlags(self.dirtyFlag)

		positionInfo.sendZ = z
		positionInfo.sendY = y
		positionInfo.sendX = x
		positionInfo.updateLinkedNodes = updateLinkedNodes
	end
end

function UmbilicalHoseOrchestrator:guardMovement(node, connectorType)
	local point = self:getConnectPointAt(connectorType)

	return calcDistanceFrom(node, point.node) <= point.length * 2
end

function UmbilicalHoseOrchestrator:addControlPoint(guideNode, isLastNode)
	local x, y, z = getWorldTranslation(guideNode)

	if not isLastNode and self:hasControlPoints() then
		local point = self:getConnectPointAt(self.activeConnectorType)
		x, y, z = point.lastPosition:getPosition()
	end

	local limitedY = self.hose:getTerrainLimitedYPosition(x, y, z)

	return self:addAtWorldPosition(x, limitedY, z)
end

function UmbilicalHoseOrchestrator:addAtWorldPosition(x, y, z)
	if self.isServer then
		g_server:broadcastEvent(UmbilicalHoseSpawnEvent.new(self, x, y, z))
	end

	local hasControlPoints = self:hasControlPoints()

	if not hasControlPoints then
		self:changePositionInterpolation(UmbilicalHoseOrchestrator.TYPE_HEAD, x, y, z, false)
		self:changePositionInterpolation(UmbilicalHoseOrchestrator.TYPE_TAIL, x, y, z, false)
	else
		self:changePositionInterpolation(self.activeConnectorType, x, y, z, false)
	end

	return self.hose:addPointByPosition(x, y, z, self:isInTailMode())
end

function UmbilicalHoseOrchestrator:removeControlPoint(atTail)
	if self.isServer then
		g_server:broadcastEvent(UmbilicalHoseRemoveEvent.new(self, atTail))
	end

	return self.hose:deletePoint(atTail)
end

function UmbilicalHoseOrchestrator:finalize()
	self.hose:finalize()
	self:setIsFinalized(true)
end

function UmbilicalHoseOrchestrator:setIsFinalized(isFinalized)
	self.isFinalized = isFinalized

	if self.isServer then
		self:raiseDirtyFlags(self.infoDirtyFlag)
	end
end

function UmbilicalHoseOrchestrator:getCurvePoints(connectorType)
	local points = self.hose.points

	if self.hose.size < 2 then
		return points[1], points[1]
	end

	if connectorType == UmbilicalHoseOrchestrator.TYPE_TAIL then
		local num = #points

		return points[num], points[num - 1]
	end

	return points[1], points[2]
end
