Cone = {}
local Cone_mt = Class(Cone)

InitObjectClass(Cone, "Cone")

function Cone.onCreate(nodeId)
	log("Not implemented!")
end

function Cone:new(isServer, isClient)
	local self = setmetatable({}, Cone_mt)
	self.isServer = isServer
	self.isClient = isClient
	self.isDeleted = false

	registerObjectClassName(self, "Cone")

	return self
end

function Cone:delete()
	unregisterObjectClassName(self)

	self.isDeleted = true

	if self.sharedLoadRequestId ~= nil then
		g_i3DManager:releaseSharedI3DFile(self.sharedLoadRequestId)

		self.sharedLoadRequestId = nil
	end
end

function Cone:readStream(streamId, connection)
	if connection:getIsServer() then
		local i3dFilename = NetworkUtil.convertFromNetworkFilename(streamReadString(streamId))
		local isNew = self.i3dFilename == nil

		if isNew then
			self:load(i3dFilename, 0, 0, 0, 0, 0, 0)
		end
	end
end

function Cone:writeStream(streamId, connection)
	if not connection:getIsServer() then
		streamWriteString(streamId, NetworkUtil.convertToNetworkFilename(self.i3dFilename))
	end
end

function Cone:load(i3dFilename)
	self:create(i3dFilename)

	self.ballYOffset = calcDistanceFrom(self.nodeId, self.coneId)
	self.lostBall = false
end

function Cone:create(i3dFilename)
	self.i3dFilename = i3dFilename
	self.customEnvironment, self.baseDirectory = Utils.getModNameAndBaseDirectory(i3dFilename)
	local root, sharedLoadRequestId = g_i3DManager:loadSharedI3DFile(i3dFilename, false, false)
	self.sharedLoadRequestId = sharedLoadRequestId
	local coneId = getChildAt(root, 0)
	local ballId = getChildAt(root, 1)

	link(getRootNode(), coneId)
	link(getRootNode(), ballId)
	delete(root)

	self.coneId = coneId
	self.nodeId = ballId

	self:deactivate()
end

function Cone:link(parentNode)
	link(parentNode, self.coneId)
	link(parentNode, self.nodeId)
end

function Cone:setPosition(x, y, z)
	setWorldTranslation(self.coneId, x, y, z)
	setWorldTranslation(self.nodeId, x, y + self.ballYOffset, z)

	self.lastPosition = {
		x,
		y,
		z
	}
end

function Cone:deactivate()
	if self.isServer then
		removeFromPhysics(self.coneId)
		removeFromPhysics(self.nodeId)
	end

	self.isActive = false
end

function Cone:activate()
	if self.isServer then
		addToPhysics(self.coneId)
		addToPhysics(self.nodeId)
	end

	self.isActive = true
end

function Cone:update(dt)
	if self.isServer and self.isActive then
		self.lostBall = self:hasLostBall()

		if self.lostBall then
			local x, y, z = getWorldTranslation(self.nodeId)
			local terrainY = self:getTerrainHeightWithProps(x, z)

			if terrainY > y + 1 then
				setTranslation(self.nodeId, x, terrainY + 1.1, y)
			end
		end
	end
end

function Cone:getTerrainHeightWithProps(x, z)
	local terrainY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
	local offset = 1
	local distance = 5
	local collisionMask = 63
	self.groundY = -1

	raycastClosest(x, terrainY + offset, z, 0, -1, 0, "groundRaycastCallback", distance, self, collisionMask)

	return math.max(terrainY, self.groundY)
end

function Cone:groundRaycastCallback(hitObjectId, x, y, z, distance)
	if hitObjectId ~= nil then
		local objectType = getRigidBodyType(hitObjectId)

		if objectType ~= RigidBodyType.DYNAMIC and objectType ~= RigidBodyType.KINEMATIC then
			self.groundY = y

			return false
		end
	end

	return true
end

function Cone:hasLostBall()
	if self.lostBall then
		return true
	end

	local _, y, _ = getWorldTranslation(self.nodeId)
	local _, iy, _ = unpack(self.lastPosition)

	return math.abs(y - (iy + self.ballYOffset)) > 0.5
end

function Cone:reset()
	self.lostBall = false

	self:deactivate()
	setRotation(self.nodeId, 0, 0, 0)
	setRotation(self.coneId, 0, 0, 0)
	self:setPosition(unpack(self.lastPosition))
	self:activate()
end
