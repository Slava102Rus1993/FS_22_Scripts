local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

TransportTree = {}
local TransportTree_mt = Class(TransportTree, PhysicsObject)

InitObjectClass(TransportTree, "TransportTree")

function TransportTree.new(isServer, isClient, customMt)
	local self = PhysicsObject.new(isServer, isClient, customMt or TransportTree_mt)

	return self
end

function TransportTree:delete()
	if self.isServer then
		removeWakeUpReport(self.nodeId)
	end

	self.nodeId = 0

	PhysicsObject:superClass().delete(self)
end

function TransportTree:readStream(streamId, connection)
	local entityId, splitShapeId1, splitShapeId2 = readSplitShapeIdFromStream(streamId)

	if entityId ~= 0 then
		self:setNodeId(entityId)
	elseif splitShapeId1 ~= 0 then
		self.splitShapePart1 = splitShapeId1
		self.splitShapePart2 = splitShapeId2
	end
end

function TransportTree:writeStream(streamId, connection)
	writeSplitShapeIdToStream(streamId, self.nodeId)
end

function TransportTree:setNodeId(nodeId)
	self.nodeId = nodeId

	setRigidBodyType(self.nodeId, self:getDefaultRigidBodyType())
	addToPhysics(self.nodeId)

	self.forcedClipDistance = getClipDistance(self.nodeId)
	local x, y, z = getWorldTranslation(self.nodeId)
	local xRot, yRot, zRot = getWorldRotation(self.nodeId)
	self.sendPosZ = z
	self.sendPosY = y
	self.sendPosX = x
	self.sendRotZ = zRot
	self.sendRotY = yRot
	self.sendRotX = xRot

	if not self.isServer then
		local quatX, quatY, quatZ, quatW = mathEulerToQuaternion(xRot, yRot, zRot)
		self.positionInterpolator = InterpolatorPosition.new(x, y, z)
		self.quaternionInterpolator = InterpolatorQuaternion.new(quatX, quatY, quatZ, quatW)
	end

	if self.isServer then
		addWakeUpReport(nodeId, "onPhysicObjectWakeUpCallback", self)
	end
end

function TransportTree:update(dt)
	if not self.isServer and self.splitShapePart1 ~= nil then
		local entityId = resolveStreamSplitShapeId(self.splitShapePart1, self.splitShapePart2)

		if entityId ~= 0 then
			self:setNodeId(entityId)

			self.splitShapePart1 = nil
			self.splitShapePart2 = nil
		end
	end

	if entityExists(self.nodeId) then
		TransportTree:superClass().update(self, dt)
	end
end

function TransportTree:updateMove()
	if not entityExists(self.nodeId) then
		return false
	end

	return TransportTree:superClass().updateMove(self)
end

function TransportTree:getUpdatePriority(skipCount, x, y, z, coeff, connection, isGuiVisible)
	if not entityExists(self.nodeId) then
		return 0
	end

	return TransportTree:superClass().getUpdatePriority(self, skipCount, x, y, z, coeff, connection, isGuiVisible)
end

function TransportTree:testScope(x, y, z, coeff, isGuiVisible)
	if not entityExists(self.nodeId) then
		return false
	end

	return TransportTree:superClass().testScope(self, x, y, z, coeff, isGuiVisible)
end

function TransportTree:onGhostRemove()
	if not entityExists(self.nodeId) then
		return
	end

	TransportTree:superClass().onGhostRemove(self)
end

function TransportTree:onGhostAdd()
	if not entityExists(self.nodeId) then
		return
	end

	TransportTree:superClass().onGhostAdd(self)
end

function TransportTree:wakeUp()
	if not entityExists(self.nodeId) then
		return
	end

	TransportTree:superClass().wakeUp(self)
end

function TransportTree:setWorldPositionQuaternion(x, y, z, quatX, quatY, quatZ, quatW, changeInterp)
	if not entityExists(self.nodeId) then
		return
	end

	TransportTree:superClass().setWorldPositionQuaternion(self, x, y, z, quatX, quatY, quatZ, quatW, changeInterp)
end

function TransportTree:setLocalPositionQuaternion(x, y, z, quatX, quatY, quatZ, quatW, changeInterp)
	if not entityExists(self.nodeId) then
		return
	end

	TransportTree:superClass().setLocalPositionQuaternion(self, x, y, z, quatX, quatY, quatZ, quatW, changeInterp)
end
