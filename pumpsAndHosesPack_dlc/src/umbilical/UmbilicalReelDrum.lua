UmbilicalReelDrum = {}
local UmbilicalReelDrum_mt = Class(UmbilicalReelDrum)
UmbilicalReelDrum.HOSE_END_LENGTH = 1
UmbilicalReelDrum.DEFAULT_CAPACITY = 1000
UmbilicalReelDrum.DEFAULT_DIAMETER = 0.5
UmbilicalReelDrum.HOSE_KG_METER = 0.00196

function UmbilicalReelDrum.new(id, isClient, isServer)
	local self = setmetatable({}, UmbilicalReelDrum_mt)
	self.id = id
	self.isClient = isClient
	self.isServer = isServer
	self.hoses = Stack.new()
	self.isActive = false
	self.capacity = UmbilicalReelDrum.DEFAULT_CAPACITY
	self.hasInitialHose = false
	self.requiresGuideHose = true
	self.folds = false

	return self
end

function UmbilicalReelDrum:delete()
	self:deleteHoses()
	self.hoseEnd:delete()
	delete(self.hoseEndConnector)
	delete(self.guideTargetNode)
	delete(self.guideNode)
	delete(self.hoseNode)
end

function UmbilicalReelDrum:deleteHoses()
	while self.hoses:size() > 0 do
		local hose = self.hoses:pop()

		hose:delete()
	end
end

function UmbilicalReelDrum:loadFromXML(xmlFile, key, components, i3dMappings)
	self.length = 0
	self.connectorIndex = xmlFile:getValue(key .. "#connectorIndex", 1)
	self.capacity = xmlFile:getValue(key .. "#capacity", self.capacity)
	self.requiresGuideHose = xmlFile:getValue(key .. "#hasGuide", self.requiresGuideHose)
	self.hasInitialHose = xmlFile:getValue(key .. "#hasHose", self.hasInitialHose)
	self.folds = xmlFile:getValue(key .. "#folds", self.folds)
	self.linkNode = xmlFile:getValue(key .. "#linkNode", "0>", components, i3dMappings)
	self.drumNode = xmlFile:getValue(key .. "#drumNode", nil, components, i3dMappings)
	self.drumDiameter = xmlFile:getValue(key .. "#drumDiameter", UmbilicalReelDrum.DEFAULT_DIAMETER)
	self.hoseShift = xmlFile:getValue(key .. ".hose#shift", UmbilicalReelHose.DEFAULT_SHIFT)
	self.hoseCoils = xmlFile:getValue(key .. ".hose#coils", UmbilicalReelHose.DEFAULT_COILS)
	self.hoseOffset = xmlFile:getValue(key .. ".hose#offset", "0 0 0", true)
	local ox, oy, oz = localToLocal(self.drumNode, self.linkNode, 0, 0, 0)
	self.origin = {
		x = ox,
		y = oy,
		z = oz
	}
	self.hoseNode = createTransformGroup("hoseNode")

	link(self.drumNode, self.hoseNode)
	setTranslation(self.hoseNode, unpack(self.hoseOffset))

	self.guideNode = createTransformGroup("guideNode")

	link(self.linkNode, self.guideNode)
	setTranslation(self.guideNode, unpack(self.hoseOffset))
	setRotation(self.guideNode, 0, math.pi, 0)

	self.guideTargetNode = createTransformGroup("guideTargetNode")

	link(self.guideNode, self.guideTargetNode)
	setTranslation(self.guideTargetNode, 0, 0, 0)
	setRotation(self.guideTargetNode, 0, math.pi, 0)

	self.hoseEndOffset = xmlFile:getValue(key .. ".hose#endOffset", 0)
	self.hoseEndConnector = self:createReelEndConnector(self.guideNode)
	self.hoseEnd = self:createReelEndHose(self.guideNode, self.hoseEndConnector)

	self:updateReelEndHose(true)
	setTranslation(self.guideNode, self.hoseOffset[1], self.origin.y + self.drumDiameter * 0.5 - HoseBase.Y_OFFSET * 0.5, self.origin.z)

	return true
end

function UmbilicalReelDrum:loadFromSavegameXMLFile(xmlFile, key)
	local i = 0

	while not self.hasInitialHose do
		local hoseKey = ("%s.hose(%d)"):format(key, i)

		if not xmlFile:hasProperty(hoseKey) then
			break
		end

		local length = xmlFile:getValue(hoseKey .. "#length", 0)
		local capacity = xmlFile:getValue(hoseKey .. "#capacity", length)
		local color = xmlFile:getValue(hoseKey .. "#color", "0.05 0.05 0.05 0", true)
		local damage = xmlFile:getValue(hoseKey .. "#damage", 0)

		if length > 0 and i == self:getAmountOfHoses() then
			local hose = self:allocateHose(capacity, length)

			if self.isClient then
				self:setColor(color)
			end

			hose:setDamageAmount(damage)

			if self.isServer then
				hose.lengthSent = length
			end
		end

		i = i + 1
	end

	self:updateReelEndHose(true)
end

function UmbilicalReelDrum:saveToXMLFile(xmlFile, key, usedModNames)
	xmlFile:setValue(key .. "#id", self.id)

	for i, hose in ipairs(self.hoses.stack) do
		local hoseKey = ("%s.hose(%d)"):format(key, i - 1)

		xmlFile:setValue(hoseKey .. "#length", hose.length)
		xmlFile:setValue(hoseKey .. "#capacity", hose.capacity)
		xmlFile:setValue(hoseKey .. "#color", unpack(hose:getColor()))
		xmlFile:setValue(hoseKey .. "#damage", hose.damage)
	end
end

function UmbilicalReelDrum:setIsActive(isActive, deleteHose)
	self.isActive = isActive

	if not isActive and deleteHose then
		local currentHose = self:arrogateHose()

		if currentHose ~= nil and currentHose:isEmpty() then
			self:discardHose()
		end
	end

	self:updateReelEndHose(not isActive)
end

function UmbilicalReelDrum:createReelHose(linkNode)
	local cache = g_currentMission.manure.shapeCacheContainer:getByKeyOrDefault("reel")

	return UmbilicalReelHose.new(cache, linkNode)
end

function UmbilicalReelDrum:createReelEndHose(linkNode, targetNode)
	local cache = g_currentMission.manure.shapeCacheContainer:getByKeyOrDefault("hoseEnd")
	local hoseEndCacheEntry = cache:clone()

	return HoseBase(linkNode, targetNode, hoseEndCacheEntry.node, UmbilicalReelDrum.HOSE_END_LENGTH)
end

function UmbilicalReelDrum:createReelEndConnector(linkNode)
	local cache = g_currentMission.manure.shapeCacheContainer:getByKeyOrDefault("connector")
	local cacheEntry = cache:clone()
	local node = cacheEntry.node

	link(linkNode, node)
	setRotation(node, -0.5 * math.pi, 0, 0)

	return node
end

function UmbilicalReelDrum:allocateHose(capacity, length)
	length = length or 0
	local previousHose = self:arrogateHose()
	local hose = self:createReelHose(self.hoseNode)
	local occupiedDiameter = self.drumDiameter
	local layerNumber = 0

	if previousHose ~= nil then
		occupiedDiameter = previousHose:getDiameter()
		local layer = previousHose:getCurrentLayer()
		layerNumber = layer.index
	end

	local diameter = math.max(self.drumDiameter, occupiedDiameter)

	hose:setInnerDiameter(diameter)
	hose:setCapacity(capacity ~= 0 and capacity or self.capacity)
	hose:setCoilsAmount(self.hoseCoils)
	hose:setShift(self.hoseShift)

	if self.isClient then
		hose:loadLayers(length, layerNumber % 2 ~= 0)
	end

	self.hoses:push(hose)

	if length ~= 0 then
		self:setHoseLength(hose, length, UmbilicalReel.WIND_DIRECTION)
	end

	self:updateReelHose(hose, UmbilicalReel.WIND_DIRECTION)

	return hose
end

function UmbilicalReelDrum:arrogateHose()
	return self.hoses:first()
end

function UmbilicalReelDrum:discardHose()
	local hose = self.hoses:pop()

	if hose ~= nil then
		hose:delete()
	end

	local nextHose = self.hoses:first()

	if nextHose ~= nil then
		self:setColor(nextHose:getColor())
		self:updateReelHose(nextHose, UmbilicalReel.WIND_DIRECTION)
	end

	self:updateReelEndHose(nextHose ~= nil)

	return hose
end

function UmbilicalReelDrum:updateReelHose(hose, reelDirection)
	local alpha = hose:getActiveLayer(hose.length)
	local state = hose:getState(alpha)
	local targetRot = hose:getRotationByState(state)

	setRotation(self.drumNode, -targetRot, 0, 0)
	self:updateGuide(hose, state)
	hose:updateLayers(alpha, reelDirection)
end

function UmbilicalReelDrum:updateGuide(hose, state)
	local layers = hose:getAmountOfLayers()
	local layer = hose:getLayerByIndex(layers)

	if layer ~= nil then
		local xOffset = self.hoseOffset[1]
		local fromX = hose:getPlacementOffset(layers - 1, xOffset)
		local toX = hose:getPlacementOffset(layers, xOffset)
		local limit = math.abs(xOffset)
		local x = math.clamp(MathUtil.lerp(fromX, toX, state), -limit, limit)
		local radius = hose:getRadius()
		local diameter = hose:getDiameter()
		local meshCorrection = 0.001

		setTranslation(self.guideNode, x, self.origin.y + radius - hose.layerThickness * 0.5 + meshCorrection, self.origin.z)

		local length = diameter + 0.1

		setTranslation(self.hoseEndConnector, 0, -length, -(radius + hose.layerThickness + self.hoseEndOffset))
		self.hoseEnd:setLength(length)
		self.hoseEnd:update()
	end
end

function UmbilicalReelDrum:updateReelEndHose(isActive)
	local state = isActive and not self:isEmpty()

	self.hoseEnd:setActiveState(state)

	if state then
		self.hoseEnd:update()
	end

	setVisibility(self.hoseEndConnector, state)
end

function UmbilicalReelDrum:setColor(color)
	if self.isClient then
		local hose = self:arrogateHose()

		if hose ~= nil then
			hose:setColor(color)
		end

		self.hoseEnd:setColor(color)
	end
end

function UmbilicalReelDrum:addLength(hose, length, reelDirection)
	hose:addLength(length, reelDirection)

	if self.isClient then
		self:updateReelHose(hose, reelDirection)
		self:updateReelEndHose(false)
	end
end

function UmbilicalReelDrum:setHoseLength(hose, length, reelDirection)
	hose:setLength(length, reelDirection)

	if self.isClient then
		self:updateReelHose(hose, reelDirection)
		self:updateReelEndHose(true)
	end
end

function UmbilicalReelDrum:getLength()
	local occupiedLength = 0

	for _, hose in ipairs(self.hoses.stack) do
		occupiedLength = occupiedLength + hose.length
	end

	return occupiedLength
end

function UmbilicalReelDrum:isEmpty()
	return self:getLength() == 0
end

function UmbilicalReelDrum:isFull()
	return self:getFreeCapacity() == 0
end

function UmbilicalReelDrum:getCapacity()
	return self.capacity
end

function UmbilicalReelDrum:getFreeCapacity()
	return self.capacity - self:getLength()
end

function UmbilicalReelDrum:getAmountOfHoses()
	return self.hoses:size()
end

function UmbilicalReelDrum:getHoses()
	return self.hoses.stack
end

function UmbilicalReelDrum:getWeight()
	return self:getLength() * UmbilicalReelDrum.HOSE_KG_METER
end
