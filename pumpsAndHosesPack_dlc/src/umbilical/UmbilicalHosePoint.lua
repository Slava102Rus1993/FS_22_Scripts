UmbilicalHosePoint = {}
local UmbilicalHosePoint_mt = Class(UmbilicalHosePoint)

function UmbilicalHosePoint.new(id, node, parentPoint, isClient, shapeCacheContainer)
	local self = setmetatable({}, UmbilicalHosePoint_mt)
	self.id = id
	self.node = node
	self.shapeCacheContainer = shapeCacheContainer
	self.isClient = isClient
	self.isDeleted = false
	self.isGuide = false
	self.length = 0
	self.lengthSq = self.length * self.length
	self.invertNode = createTransformGroup("invertNode")

	link(node, self.invertNode)
	setRotation(self.invertNode, 0, math.pi, 0)

	local x, y, z = getWorldTranslation(node)
	local dx, dy, dz = localDirectionToWorld(node, 0, 0, 1)
	self.position = Vector3(x, y, z)
	self.lastPosition = Vector3(x, y, z)
	self.direction = Vector3(dx, dy, dz)
	self.lastDirection = Vector3(dx, dy, dz)

	if parentPoint ~= nil then
		self.lastDirection = parentPoint.lastPosition - self.lastPosition

		if isClient and parentPoint.hose ~= nil then
			parentPoint.hose:setLength(parentPoint.length)
			parentPoint.hose:setActiveState(true)
		end
	end

	if self.lastDirection:magnitudeSquared() > 0.0001 then
		setDirection(node, self.lastDirection.x, self.lastDirection.y, self.lastDirection.z, 0, 1, 0)
	end

	self:createConnector()

	return self
end

function UmbilicalHosePoint:delete()
	self:deleteHose()
	self:deleteConnector()

	if self.invertNode ~= nil then
		delete(self.invertNode)
	end

	if self.node ~= nil then
		delete(self.node)
	end

	self.isDeleted = true
end

function UmbilicalHosePoint:createHose(type, linkNode)
	if not self.isClient then
		return
	end

	type = type or "hoseUmbilical"
	linkNode = linkNode or self.node
	local hoseCacheEntry = self.shapeCacheContainer:getByKeyOrDefault(type)
	local hoseCache = hoseCacheEntry:clone()
	local hose = HoseBase(linkNode, self.node, hoseCache.node, self.length, false, false)
	self.hose = hose

	self.hose:setDirection(true)
	self.hose:setLength(self.length)
	self.hose:setActiveState(true)
end

function UmbilicalHosePoint:deleteHose()
	if self.hose ~= nil then
		self.hose:delete()

		self.hose = nil
	end
end

function UmbilicalHosePoint:createConnector()
	if not self.isClient then
		return
	end

	local connectorCacheEntry = self.shapeCacheContainer:getByKeyOrDefault("CONNECTOR")
	local connectorCache = connectorCacheEntry:clone()
	self.connectorNode = connectorCache.node

	link(self.node, self.connectorNode)
end

function UmbilicalHosePoint:deleteConnector()
	if self.connectorNode ~= nil then
		delete(self.connectorNode)

		self.connectorNode = nil
	end
end

function UmbilicalHosePoint:setLength(length)
	self.length = length
	self.lengthSq = self.length * self.length

	if not self.isDeleted and self.hose ~= nil then
		self.hose:setLength(length)
	end
end

function UmbilicalHosePoint:setColor(color)
	if not self.isDeleted and self.hose ~= nil then
		self.hose:setColor(color)
	end
end

function UmbilicalHosePoint:setHoseState(isActive)
	if not self.isDeleted and self.hose ~= nil then
		self.hose:setActiveState(isActive)
	end
end

function UmbilicalHosePoint:setConnectorState(isActive)
	if not self.isDeleted and self.connectorNode ~= nil then
		setVisibility(self.connectorNode, isActive)
	end

	self.connectorIsActive = isActive
end

function UmbilicalHosePoint:previous()
	return self._prev
end

function UmbilicalHosePoint:next()
	return self._next
end
