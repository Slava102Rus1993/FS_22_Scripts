local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

ForestryPhysicsRope = {
	COLLISION_MASK = CollisionFlag.DYNAMIC_OBJECT,
	MOD_DIRECTORY = g_currentModDirectory,
	NUM_NODE_BITS = 8,
	NUM_POSITION_BITS = 16,
	NUM_LENGTH_BITS = 16,
	MAX_LENGTH = 128,
	NUM_UPDATE_POSITION_BITS = 7,
	MAX_UPDATE_LENGTH = 0.75
}
local ForestryPhysicsRope_mt = Class(ForestryPhysicsRope)

function ForestryPhysicsRope.new(vehicle, linkActor, linkNode, isServer, customMt)
	local self = setmetatable({}, customMt or ForestryPhysicsRope_mt)
	self.vehicle = vehicle
	self.linkActor = linkActor
	self.linkNode = linkNode
	self.isServer = isServer
	self.physicsRopeIndex = nil
	self.visibility = false
	self.useDynamicLength = false
	self.visualRopes = {}
	self.nodes = {}
	self.numActiveNodes = 0
	self.boundingRadius = 1

	return self
end

function ForestryPhysicsRope.registerXMLPaths(schema, baseKey)
	schema:register(XMLValueType.STRING, baseKey .. "#filename", "Path to rope i3d file", "shared/ropes/physicsRopes.i3d")
	schema:register(XMLValueType.STRING, baseKey .. "#ropeNode", "Path to rope i3d file", "0")
	schema:register(XMLValueType.FLOAT, baseKey .. "#diameter", "Diameter of the rope", 0.02)
	schema:register(XMLValueType.FLOAT, baseKey .. "#uvScale", "UV scale of the rope", 4)
	schema:register(XMLValueType.VECTOR_4, baseKey .. "#emissiveColor", "Emissive color", "0 0 0")
	schema:register(XMLValueType.FLOAT, baseKey .. "#minLength", "Minimum length of the rope", 1)
	schema:register(XMLValueType.FLOAT, baseKey .. "#maxLength", "Minimum length of the rope", 20)
	schema:register(XMLValueType.FLOAT, baseKey .. "#linkLength", "Length of each rope segment", 0.5)
	schema:register(XMLValueType.FLOAT, baseKey .. "#nodeDistance", "Distance between two nodes for rendering", 1)
	schema:register(XMLValueType.FLOAT, baseKey .. "#massPerLength", "Mass of each segment in kg", 20)
	schema:register(XMLValueType.INT, baseKey .. "#collisionMask", "CollisionMask of the rope", ForestryPhysicsRope.COLLISION_MASK)
end

function ForestryPhysicsRope.registerSavegameXMLPaths(schema, baseKey)
	schema:register(XMLValueType.VECTOR_TRANS, baseKey .. ".ropeNode(?)#translation", "Translation of rope node")
end

function ForestryPhysicsRope:loadFromXML(xmlFile, key, minLength, maxLength)
	self.i3dFilename = xmlFile:getValue(key .. "#filename", "shared/ropes/physicsRopes.i3d")
	self.i3dRopePath = xmlFile:getValue(key .. "#ropeNode", "0")
	self.diameter = xmlFile:getValue(key .. "#diameter", 0.02)
	self.uvScale = xmlFile:getValue(key .. "#uvScale", 4)
	self.emissiveColor = xmlFile:getValue(key .. "#emissiveColor", "0 1 0 0", true)
	self.minLength = xmlFile:getValue(key .. "#minLength", minLength)
	self.maxLength = xmlFile:getValue(key .. "#maxLength", maxLength)
	self.linkLength = xmlFile:getValue(key .. "#linkLength", 0.5)
	self.nodeDistance = xmlFile:getValue(key .. "#nodeDistance", 1)
	self.massPerLength = xmlFile:getValue(key .. "#massPerLength", 20) * 0.001
	self.collisionMask = xmlFile:getValue(key .. "#collisionMask", ForestryPhysicsRope.COLLISION_MASK)
	local numSegments = self.maxLength / self.linkLength

	if numSegments > 2^ForestryPhysicsRope.NUM_NODE_BITS - 1 then
		Logging.xmlWarning(xmlFile, "Physics rope has too many segments! Max. %d segments are allowed, %d defined. (length / linkLength)", 2^ForestryPhysicsRope.NUM_NODE_BITS - 1, numSegments)
	end

	if ForestryPhysicsRope.MAX_LENGTH < self.maxLength then
		Logging.xmlWarning(xmlFile, "Physics rope too long! Max. %dm are allowed", ForestryPhysicsRope.MAX_LENGTH)
	end

	if self.i3dFilename ~= nil then
		self.i3dFilename = Utils.getFilename(self.i3dFilename, ForestryPhysicsRope.MOD_DIRECTORY)

		if self.vehicle ~= nil then
			self.sharedLoadRequestId = self.vehicle:loadSubSharedI3DFile(self.i3dFilename, false, false, self.onI3DLoaded, self, self)
		else
			self.sharedLoadRequestId = g_i3DManager:loadSharedI3DFileAsync(self.i3dFilename, false, false, self.onI3DLoaded, self, self)
		end
	end
end

function ForestryPhysicsRope:clone(linkActor, linkNode, maxLength)
	local ropeClone = ForestryPhysicsRope.new(self.vehicle, linkActor or self.linkActor, linkNode or self.linkNode)
	ropeClone.i3dFilename = self.i3dFilename
	ropeClone.i3dRopePath = self.i3dRopePath
	ropeClone.diameter = self.diameter
	ropeClone.uvScale = self.uvScale
	ropeClone.emissiveColor = self.emissiveColor
	ropeClone.minLength = self.minLength
	ropeClone.maxLength = maxLength or self.maxLength
	ropeClone.linkLength = self.linkLength
	ropeClone.nodeDistance = self.nodeDistance
	ropeClone.massPerLength = self.massPerLength
	ropeClone.collisionMask = self.collisionMask

	if ropeClone.i3dFilename ~= nil then
		local i3dNode, sharedLoadRequestId, failedReason = g_i3DManager:loadSharedI3DFile(ropeClone.i3dFilename, false, false)
		ropeClone.sharedLoadRequestId = sharedLoadRequestId

		ropeClone:onI3DLoaded(i3dNode, failedReason)

		return ropeClone
	end
end

function ForestryPhysicsRope:saveToXMLFile(xmlFile, key)
	if self.physicsRopeIndex ~= nil then
		_, self.numActiveNodes = getPhysicsRopeLength(self.physicsRopeIndex)

		for i = 1, self.numActiveNodes do
			local x, y, z = getWorldTranslation(self.nodes[i])

			xmlFile:setValue(string.format("%s.ropeNode(%d)#translation", key, i - 1), x, y, z)
		end
	end
end

function ForestryPhysicsRope.loadPositionDataFromSavegame(xmlFile, key)
	local positions = {}

	xmlFile:iterate(key .. ".ropeNode", function (index, nodeKey)
		local translation = xmlFile:getValue(nodeKey .. "#translation", nil, true)

		table.insert(positions, translation)
	end)

	return positions
end

function ForestryPhysicsRope:delete()
	g_currentMission:removeUpdateable(self)

	for _, node in pairs(self.nodes) do
		delete(node)
	end

	if self.referenceFrame ~= nil then
		if entityExists(self.referenceFrame) then
			delete(self.referenceFrame)
		end

		g_i3DManager:releaseSharedI3DFile(self.sharedLoadRequestId)
	end
end

function ForestryPhysicsRope:writeStream(streamId)
	if self.physicsRopeIndex ~= nil then
		local _, numSegments = getPhysicsRopeLength(self.physicsRopeIndex)

		streamWriteUIntN(streamId, numSegments, ForestryPhysicsRope.NUM_NODE_BITS)

		local maxValue = 2^(ForestryPhysicsRope.NUM_POSITION_BITS - 1) - 1

		for i = 1, numSegments do
			local node = self.nodes[i]
			local x, y, z = getTranslation(node)

			streamWriteIntN(streamId, MathUtil.clamp(x / ForestryPhysicsRope.MAX_LENGTH, -1, 1) * maxValue, ForestryPhysicsRope.NUM_POSITION_BITS)
			streamWriteIntN(streamId, MathUtil.clamp(y / ForestryPhysicsRope.MAX_LENGTH, -1, 1) * maxValue, ForestryPhysicsRope.NUM_POSITION_BITS)
			streamWriteIntN(streamId, MathUtil.clamp(z / ForestryPhysicsRope.MAX_LENGTH, -1, 1) * maxValue, ForestryPhysicsRope.NUM_POSITION_BITS)
		end
	else
		streamWriteUIntN(streamId, 0, ForestryPhysicsRope.NUM_NODE_BITS)
	end
end

function ForestryPhysicsRope.readStream(streamId, invert)
	local positions = {}
	local maxValue = 2^(ForestryPhysicsRope.NUM_POSITION_BITS - 1) - 1
	local numPositions = streamReadUIntN(streamId, ForestryPhysicsRope.NUM_NODE_BITS)

	for i = 1, numPositions do
		local x = streamReadIntN(streamId, ForestryPhysicsRope.NUM_POSITION_BITS) / maxValue * ForestryPhysicsRope.MAX_LENGTH
		local y = streamReadIntN(streamId, ForestryPhysicsRope.NUM_POSITION_BITS) / maxValue * ForestryPhysicsRope.MAX_LENGTH
		local z = streamReadIntN(streamId, ForestryPhysicsRope.NUM_POSITION_BITS) / maxValue * ForestryPhysicsRope.MAX_LENGTH

		if invert then
			table.insert(positions, 1, {
				x,
				y,
				z
			})
		else
			table.insert(positions, {
				x,
				y,
				z
			})
		end
	end

	return positions
end

function ForestryPhysicsRope:writeUpdateStream(streamId)
	if streamWriteBool(streamId, self.physicsRopeIndex ~= nil) then
		local length = MathUtil.clamp(getPhysicsRopeLength(self.physicsRopeIndex), 0, ForestryPhysicsRope.MAX_LENGTH)
		local maxValue = 2^ForestryPhysicsRope.NUM_LENGTH_BITS - 1

		streamWriteUIntN(streamId, length / ForestryPhysicsRope.MAX_LENGTH * maxValue, ForestryPhysicsRope.NUM_LENGTH_BITS)
	end
end

function ForestryPhysicsRope:readUpdateStream(streamId)
	if streamReadBool(streamId) then
		local maxValue = 2^ForestryPhysicsRope.NUM_LENGTH_BITS - 1
		local length = streamReadUIntN(streamId, ForestryPhysicsRope.NUM_LENGTH_BITS) / maxValue * ForestryPhysicsRope.MAX_LENGTH
		self.ropeLength = length

		if self.physicsRopeIndex ~= nil then
			setPhysicsRopeMaxLength(self.physicsRopeIndex, self.ropeLength)
		end
	end
end

function ForestryPhysicsRope:update(dt)
	if self.physicsRopeIndex ~= nil and self.useDynamicLength then
		local _, numSegments = getPhysicsRopeLength(self.physicsRopeIndex)
		local lx, ly, lz = getWorldTranslation(self.curTargetNode)
		local lwx = self.dynamicLengthLastPosition[1]
		local lwy = self.dynamicLengthLastPosition[2]
		local lwz = self.dynamicLengthLastPosition[3]
		local distance = MathUtil.vector3Length(lx - lwx, ly - lwy, lz - lwz)
		local move = distance - (self.dynamicLengthLastDistance or distance)
		local numPositions = 0
		local wx = 0
		local wy = 0
		local wz = 0

		for i = numSegments, math.max(1, numSegments - 10), -1 do
			if self.nodes[i] ~= nil then
				local x, y, z = getWorldTranslation(self.nodes[i])
				wz = wz + z
				wy = wy + y
				wx = wx + x
				numPositions = numPositions + 1
			end
		end

		if numPositions > 0 then
			wz = wz / numPositions
			wy = wy / numPositions
			wx = wx / numPositions
		else
			wx, wy, wz = getWorldTranslation(self.curLinkNode)
		end

		if move < 0 and self:getRopeDirectLengthPercentage() > 1 then
			move = 0
		end

		self:adjustLength(move, true)

		self.dynamicLengthLastPosition[3] = wz
		self.dynamicLengthLastPosition[2] = wy
		self.dynamicLengthLastPosition[1] = wx
		self.dynamicLengthLastDistance = MathUtil.vector3Length(lx - wx, ly - wy, lz - wz)
	end

	if self.physicsRopeIndex ~= nil then
		local ropeLength, numActiveNodes = getPhysicsRopeLength(self.physicsRopeIndex)

		if ropeLength ~= self.ropeLength or numActiveNodes ~= self.numActiveNodes then
			self.numActiveNodes = numActiveNodes
			self.ropeLength = ropeLength
			local foundRope = false

			for i = 1, #self.visualRopes do
				local visualRope = self.visualRopes[i]

				if numActiveNodes <= visualRope.numBones and not foundRope then
					setVisibility(visualRope.node, numActiveNodes <= visualRope.numBones)
					setShaderParameter(visualRope.node, "numNodesAndLength", numActiveNodes, ropeLength, 0, 0, false)

					if numActiveNodes > 1 then
						local xSum = 0
						local ySum = 0
						local zSum = 0

						for nodeIndex = 1, numActiveNodes do
							local x, y, z = getWorldTranslation(self.nodes[nodeIndex])
							zSum = zSum + z
							ySum = ySum + y
							xSum = xSum + x
						end

						local cx = xSum / numActiveNodes
						local cy = ySum / numActiveNodes
						local cz = zSum / numActiveNodes
						visualRope.boundingRadius = math.max(math.ceil(ropeLength * 0.5), 2)
						local bvx, bvy, bvz = worldToLocal(self.nodes[1], cx, cy, cz)

						setShapeBoundingSphere(visualRope.node, bvx, bvy, bvz, visualRope.boundingRadius)
					end

					foundRope = true
				else
					setVisibility(visualRope.node, false)

					visualRope.boundingRadius = nil
				end
			end
		end
	end
end

function ForestryPhysicsRope:updateAnchorNodes()
	if self.physicsRopeIndex ~= nil then
		local sx, sy, sz = worldToLocal(self.curLinkActor, getWorldTranslation(self.curLinkNode))

		setPhysicsRopeAnchor(self.physicsRopeIndex, 0, self.curLinkActor, sx, sy, sz, false)

		local ex, ey, ez = worldToLocal(self.curTargetActor, getWorldTranslation(self.curTargetNode))

		setPhysicsRopeAnchor(self.physicsRopeIndex, 999999, self.curTargetActor, ex, ey, ez, false)
	end
end

function ForestryPhysicsRope:setUseDynamicLength(useDynamicLength)
	self.useDynamicLength = useDynamicLength
	self.dynamicLengthLastPosition = {
		getWorldTranslation(self.curTargetNode)
	}
	self.dynamicLengthLastDistance = nil
end

function ForestryPhysicsRope:applySavegamePositions(savegamePositions)
	for i = 1, #savegamePositions do
		local position = savegamePositions[i]

		if self.nodes[i] ~= nil then
			setTranslation(self.nodes[i], position[1], position[2], position[3])
		end
	end
end

function ForestryPhysicsRope:copyNodePositions(otherRope, invert)
	for i = 1, #otherRope.nodes do
		local otherNode = otherRope.nodes[i]
		local otherIndex = i

		if invert then
			otherIndex = #self.nodes - (i - 1)
		end

		if self.nodes[otherIndex] ~= nil then
			setWorldTranslation(self.nodes[otherIndex], getWorldTranslation(otherNode))
		end
	end
end

function ForestryPhysicsRope:create(targetActor, targetNode, linkActor, linkNode, inverted, useNodePositions)
	useNodePositions = Utils.getNoNil(useNodePositions, false)
	linkNode = linkNode or self.linkNode
	linkActor = linkActor or self.linkActor

	if inverted then
		targetNode = linkNode
		targetActor = linkActor
		linkNode = targetNode
		linkActor = targetActor
	end

	local sx, sy, sz = worldToLocal(linkActor, getWorldTranslation(linkNode))
	local ex, ey, ez = worldToLocal(targetActor, getWorldTranslation(targetNode))
	self.physicsRopeIndex = addPhysicsRope(self.nodes, self.nodeDistance, self.linkLength, self.massPerLength, self.collisionMask, linkActor, sx, sy, sz, targetActor, ex, ey, ez, useNodePositions)
	self.ropeLength = getPhysicsRopeLength(self.physicsRopeIndex)
	self.ropeLengthSumUp = self.ropeLength
	self.curLinkActor = linkActor
	self.curLinkNode = linkNode
	self.curTargetActor = targetActor
	self.curTargetNode = targetNode

	g_currentMission:addUpdateable(self)
	self:setVisibility(true)

	return self.physicsRopeIndex ~= nil
end

function ForestryPhysicsRope:destroy()
	if self.physicsRopeIndex ~= nil then
		removePhysicsRope(self.physicsRopeIndex)

		self.physicsRopeIndex = nil
	end

	self.ropeLength = 0
	self.ropeLengthSumUp = 0
	self.numActiveNodes = 0
	self.curLinkActor = nil
	self.curLinkNode = nil
	self.curTargetActor = nil
	self.curTargetNode = nil

	g_currentMission:removeUpdateable(self)
	self:setVisibility(false)
end

function ForestryPhysicsRope:setMaxLength(maxLength)
	self.maxLength = maxLength
	local numSegments = self.maxLength / self.linkLength

	if numSegments > 2^ForestryPhysicsRope.NUM_NODE_BITS - 1 then
		Logging.warning("Physics rope has too many segments! Max. %d segments are allowed, %d defined. (length / linkLength)", 2^ForestryPhysicsRope.NUM_NODE_BITS - 1, numSegments)
	end

	if ForestryPhysicsRope.MAX_LENGTH < self.maxLength then
		Logging.warning("Physics rope too long! Max. %dm are allowed", ForestryPhysicsRope.MAX_LENGTH)
	end
end

function ForestryPhysicsRope:generateNodes()
	for i = #self.nodes, 1, -1 do
		delete(self.nodes[i])

		self.nodes[i] = nil
	end

	for i = 1, math.ceil(self.maxLength / self.linkLength) + 1 do
		local node = createTransformGroup("ropeNode" .. i)

		link(self.linkNode, node)
		table.insert(self.nodes, node)
	end
end

function ForestryPhysicsRope:getRopeDirectLengthPercentage(referenceMaxLength)
	if self.physicsRopeIndex ~= nil then
		local length = calcDistanceFrom(self.curLinkNode, self.curTargetNode)

		return (length - self.minLength) / ((referenceMaxLength or self.maxLength) - self.minLength)
	end

	return 0
end

function ForestryPhysicsRope:getLength()
	if self.physicsRopeIndex ~= nil then
		return getPhysicsRopeLength(self.physicsRopeIndex)
	end

	return 0
end

function ForestryPhysicsRope:adjustLength(lengthDelta, sumUp)
	if self.physicsRopeIndex ~= nil then
		local ropeLength, ropeSegments = getPhysicsRopeLength(self.physicsRopeIndex)

		if ropeSegments > 0 then
			if sumUp and self.ropeLengthSumUp ~= 0 then
				ropeLength = self.ropeLengthSumUp
			end

			local newRopeLength = MathUtil.clamp(ropeLength + lengthDelta, self.minLength, self.maxLength)

			setPhysicsRopeMaxLength(self.physicsRopeIndex, newRopeLength)

			self.ropeLengthSumUp = newRopeLength

			return MathUtil.sign(newRopeLength - ropeLength)
		end
	end

	return 0
end

function ForestryPhysicsRope:setVisibility(visibility)
	self.visibility = visibility

	if self.referenceFrame ~= nil and entityExists(self.referenceFrame) then
		setVisibility(self.referenceFrame, self.visibility)
	end
end

function ForestryPhysicsRope:setEmissiveColor(r, g, b, a)
	if r ~= self.emissiveColor[1] or g ~= self.emissiveColor[2] or b ~= self.emissiveColor[3] or a ~= self.emissiveColor[4] then
		self.emissiveColor[1] = r
		self.emissiveColor[2] = g
		self.emissiveColor[3] = b
		self.emissiveColor[4] = a

		for i = 1, #self.visualRopes do
			setShaderParameter(self.visualRopes[i].node, "ropeEmissiveColor", self.emissiveColor[1], self.emissiveColor[2], self.emissiveColor[3], self.emissiveColor[4], false)
		end
	end
end

function ForestryPhysicsRope:onI3DLoaded(i3dNode, failedReason)
	if i3dNode ~= 0 then
		self.referenceFrame = createTransformGroup("ropeReferenceFrame")

		link(self.linkNode, self.referenceFrame)
		setVisibility(self.referenceFrame, self.visibility)

		local ropeRoot = getChildAt(i3dNode, 0)

		for i = 1, getNumOfChildren(ropeRoot) do
			local node = getChildAt(ropeRoot, 0)

			link(self.referenceFrame, node)

			local visualRope = {
				node = node,
				numBones = getNumOfShapeBones(node)
			}

			table.insert(self.visualRopes, visualRope)
			setShaderParameter(node, "numBonesAndBoneDistanceAndDiameterAndVScale", visualRope.numBones, self.nodeDistance, self.diameter, self.uvScale, false)
		end

		local jointRoot = getChildAt(i3dNode, 1)

		for i = 1, getNumOfChildren(jointRoot) do
			local node = getChildAt(jointRoot, 0)

			unlink(node)
			table.insert(self.nodes, node)
		end

		delete(i3dNode)
	end
end
