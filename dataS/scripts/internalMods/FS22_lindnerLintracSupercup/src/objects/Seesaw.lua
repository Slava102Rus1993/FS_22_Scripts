Seesaw = {
	ANGLE_THRESHOLD = 1
}
local Seesaw_mt = Class(Seesaw, Object)

InitObjectClass(Seesaw, "Seesaw")

function Seesaw.registerXMLPaths(schema, basePath)
	schema:register(XMLValueType.NODE_INDEX, basePath .. "#rootNode", "the seesaw root node")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".ramps.ramp(?)#node", "the ramp node")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".ramps.ramp(?)#jointTransform", "the ramp joint transform")
	schema:register(XMLValueType.ANGLE, basePath .. ".ramps.ramp(?)#maxAngle", "the ramp max rotation angle")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".beaconLight#node", "the beacon light node")
	schema:register(XMLValueType.STRING, basePath .. ".beaconLight#filename", "the beacon light filename")
end

function Seesaw:new(nodeId, isServer, isClient)
	local self = Object.new(isServer, isClient, Seesaw_mt)
	self.nodeId = nodeId
	self.ramps = {}
	self.isServer = isServer
	self.isClient = isClient
	self.beaconLightsActive = false
	self.networkTimeInterpolator = InterpolationTime.new(1.2)
	self.physicsObjectDirtyFlag = self:getNextDirtyFlag()

	registerObjectClassName(self, "Seesaw")

	return self
end

function Seesaw:delete()
	if self.beaconLight ~= nil and self.sharedLoadRequestId ~= nil then
		g_i3DManager:releaseSharedI3DFile(self.sharedLoadRequestId)

		self.sharedLoadRequestId = nil
	end

	for _, ramp in ipairs(self.ramps) do
		self:removeChildrenFromNodeObject(ramp.nodeId)
		delete(ramp.nodeId)

		ramp.nodeId = 0
	end

	self.ramps = {}

	unregisterObjectClassName(self)
	Seesaw:superClass().delete(self)
end

function Seesaw:writeStream(streamId, connection)
	streamWriteBool(streamId, self.beaconLightsActive)

	local paramsXZ = g_currentMission.vehicleXZPosCompressionParams
	local paramsY = g_currentMission.vehicleYPosCompressionParams

	for _, ramp in ipairs(self.ramps) do
		local x, y, z = getWorldTranslation(ramp.nodeId)
		local _, _, zRot = getRotation(ramp.nodeId)

		NetworkUtil.writeCompressedWorldPosition(streamId, x, paramsXZ)
		NetworkUtil.writeCompressedWorldPosition(streamId, y, paramsY)
		NetworkUtil.writeCompressedWorldPosition(streamId, z, paramsXZ)
		NetworkUtil.writeCompressedAngle(streamId, zRot)
	end
end

function Seesaw:readStream(streamId, connection)
	self.beaconLightsActive = streamReadBool(streamId)

	self.networkTimeInterpolator:reset()

	local paramsXZ = g_currentMission.vehicleXZPosCompressionParams
	local paramsY = g_currentMission.vehicleYPosCompressionParams

	for _, ramp in ipairs(self.ramps) do
		local x = NetworkUtil.readCompressedWorldPosition(streamId, paramsXZ)
		local y = NetworkUtil.readCompressedWorldPosition(streamId, paramsY)
		local z = NetworkUtil.readCompressedWorldPosition(streamId, paramsXZ)
		local zRot = NetworkUtil.readCompressedAngle(streamId)

		self:setPosition(ramp, x, y, z, zRot, true)
	end

	self:raiseActive()
end

function Seesaw:writeUpdateStream(streamId, connection, dirtyMask)
	if not connection:getIsServer() and streamWriteBool(streamId, bitAND(dirtyMask, self.physicsObjectDirtyFlag) ~= 0) then
		local paramsXZ = g_currentMission.vehicleXZPosCompressionParams
		local paramsY = g_currentMission.vehicleYPosCompressionParams

		for i, ramp in ipairs(self.ramps) do
			NetworkUtil.writeCompressedWorldPosition(streamId, ramp.sendPosX, paramsXZ)
			NetworkUtil.writeCompressedWorldPosition(streamId, ramp.sendPosY, paramsY)
			NetworkUtil.writeCompressedWorldPosition(streamId, ramp.sendPosZ, paramsXZ)
			NetworkUtil.writeCompressedAngle(streamId, ramp.sendRotZ)
		end
	end
end

function Seesaw:readUpdateStream(streamId, timestamp, connection)
	if connection:getIsServer() and streamReadBool(streamId) then
		self.networkTimeInterpolator:startNewPhaseNetwork()

		local paramsXZ = g_currentMission.vehicleXZPosCompressionParams
		local paramsY = g_currentMission.vehicleYPosCompressionParams

		for i, ramp in ipairs(self.ramps) do
			local x = NetworkUtil.readCompressedWorldPosition(streamId, paramsXZ)
			local y = NetworkUtil.readCompressedWorldPosition(streamId, paramsY)
			local z = NetworkUtil.readCompressedWorldPosition(streamId, paramsXZ)
			local zRot = NetworkUtil.readCompressedAngle(streamId)

			ramp.positionInterpolator:setTargetPosition(x, y, z)
			ramp.angleInterpolator:setTargetAngle(zRot)
		end

		self:raiseActive()
	end
end

function Seesaw:loadFromXML(xmlFile, baseKey, components, i3dMappings)
	self.rootNode = xmlFile:getValue(baseKey .. ".seesaw#rootNode", nil, components, i3dMappings)

	assert(self.rootNode ~= nil, "Seesaw requires a rootNode!")
	assert(getRigidBodyType(self.rootNode) ~= RigidBodyType.NONE, "Seesaw rootNode needs to be a rigid body!")

	local i = 0

	while true do
		local key = ("%s.seesaw.ramps.ramp(%d)"):format(baseKey, i)

		if not xmlFile:hasProperty(key) then
			break
		end

		local ramp = {}

		if self:loadRampFromXML(xmlFile, key, ramp, components, i3dMappings) then
			table.insert(self.ramps, ramp)
		end

		i = i + 1
	end

	self:loadBeaconLightFromXML(xmlFile, baseKey, components, i3dMappings)
	self:removeFromPhysics()

	return true
end

function Seesaw:loadRampFromXML(xmlFile, baseKey, ramp, components, i3dMappings)
	local node = xmlFile:getValue(baseKey .. "#node", nil, components, i3dMappings)
	local jointTransform = xmlFile:getValue(baseKey .. "#jointTransform", nil, components, i3dMappings)

	if node == nil or jointTransform == nil then
		return false
	end

	ramp.nodeId = node

	setRigidBodyType(ramp.nodeId, self:getDefaultRigidBodyType())

	ramp.maxAngle = xmlFile:getValue(baseKey .. "#maxAngle", 10)
	ramp.jointTransform = jointTransform
	ramp.jointIndex = 0
	local x, y, z = getTranslation(ramp.nodeId)
	local xRot, yRot, zRot = getRotation(ramp.nodeId)
	ramp.orgTranslation = {
		x,
		y,
		z
	}
	ramp.orgRotation = {
		xRot,
		yRot,
		zRot
	}
	x, y, z = getWorldTranslation(ramp.nodeId)
	ramp.sendPosZ = z
	ramp.sendPosY = y
	ramp.sendPosX = x
	ramp.sendRotZ = zRot

	if not self.isServer then
		ramp.positionInterpolator = InterpolatorPosition.new(x, y, z)
		ramp.angleInterpolator = InterpolatorAngle.new(zRot)
	end

	self:addChildrenToNodeObject(ramp.nodeId)

	return true
end

function Seesaw:addChildrenToNodeObject(nodeId)
	for i = 0, getNumOfChildren(nodeId) - 1 do
		self:addChildrenToNodeObject(getChildAt(nodeId, i))
	end

	local rigidBodyType = getRigidBodyType(nodeId)

	if rigidBodyType ~= RigidBodyType.NONE and self.isServer then
		addWakeUpReport(nodeId, "onPhysicObjectWakeUpCallback", self)
	end
end

function Seesaw:removeChildrenFromNodeObject(nodeId)
	for i = 0, getNumOfChildren(nodeId) - 1 do
		self:removeChildrenFromNodeObject(getChildAt(nodeId, i))
	end

	local rigidBodyType = getRigidBodyType(nodeId)

	if rigidBodyType ~= RigidBodyType.NONE then
		g_currentMission:removeNodeObject(nodeId, self)

		if self.isServer then
			removeWakeUpReport(nodeId)
		end
	end
end

function Seesaw:onPhysicObjectWakeUpCallback(id)
	self:raiseActive()
end

function Seesaw:setPosition(ramp, x, y, z, zRot, changeInterp)
	setWorldTranslation(ramp.nodeId, x, y, z)
	setRotation(ramp.nodeId, 0, 0, zRot)

	if changeInterp then
		if not self.isServer then
			ramp.positionInterpolator:setPosition(x, y, z)
			ramp.angleInterpolator:setAngle(zRot)
		else
			self:raiseDirtyFlags(self.physicsObjectDirtyFlag)

			ramp.sendPosZ = z
			ramp.sendPosY = y
			ramp.sendPosX = x
			ramp.sendRotZ = zRot
		end
	end
end

function Seesaw:setLocalPosition(ramp, x, y, z, zRot, changeInterp)
	setTranslation(ramp.nodeId, x, y, z)
	setRotation(ramp.nodeId, 0, 0, zRot)

	if changeInterp then
		if not self.isServer then
			ramp.positionInterpolator:setPosition(getWorldTranslation(ramp.nodeId))
			ramp.angleInterpolator:setAngle(zRot)
		else
			self:raiseDirtyFlags(self.physicsObjectDirtyFlag)

			ramp.sendPosX, ramp.sendPosY, ramp.sendPosZ = getWorldTranslation(ramp.nodeId)
			ramp.sendRotZ = zRot
		end
	end
end

function Seesaw:loadBeaconLightFromXML(xmlFile, baseKey, components, i3dMappings)
	local node = xmlFile:getValue(baseKey .. ".seesaw.beaconLight#node", nil, components, i3dMappings)

	if node ~= nil then
		local lightXmlFilename = xmlFile:getValue(baseKey .. ".seesaw.beaconLight#filename")

		if lightXmlFilename ~= nil then
			lightXmlFilename = Utils.getFilename(lightXmlFilename)
			local lightXmlFile = loadXMLFile("beaconLightXML", lightXmlFilename)

			if lightXmlFile ~= nil and lightXmlFile ~= 0 then
				local i3dFilename = getXMLString(lightXmlFile, "beaconLight.filename")

				if i3dFilename ~= nil then
					local i3dNode, sharedLoadRequestId = g_i3DManager:loadSharedI3DFile(Utils.getFilename(i3dFilename), false, false)
					self.sharedLoadRequestId = sharedLoadRequestId

					if i3dNode ~= nil and i3dNode ~= 0 then
						local rootNode = I3DUtil.indexToObject(i3dNode, getXMLString(lightXmlFile, "beaconLight.rootNode#node"))
						local rotatorNode = I3DUtil.indexToObject(i3dNode, getXMLString(lightXmlFile, "beaconLight.rotator#node"))
						local speed = getXMLFloat(lightXmlFile, "beaconLight.rotator#speed") or 0.015
						local lightNode = I3DUtil.indexToObject(i3dNode, getXMLString(lightXmlFile, "beaconLight.light#node"))
						local lightShaderNode = I3DUtil.indexToObject(i3dNode, getXMLString(lightXmlFile, "beaconLight.light#shaderNode"))
						local intensity = getXMLFloat(lightXmlFile, "beaconLight.light#intensity") or 1000
						local realLightNode = I3DUtil.indexToObject(i3dNode, getXMLString(lightXmlFile, "beaconLight.realLight#node"))

						if rootNode ~= nil and (lightNode ~= nil or lightShaderNode ~= nil) then
							link(node, rootNode)
							setTranslation(rootNode, 0, 0, 0)

							local light = {
								filename = i3dFilename,
								rootNode = rootNode,
								rotatorNode = rotatorNode,
								lightNode = lightNode,
								lightShaderNode = lightShaderNode,
								realLightNode = realLightNode,
								speed = speed,
								intensity = intensity
							}

							if realLightNode ~= nil then
								light.defaultColor = {
									getLightColor(realLightNode)
								}

								setVisibility(realLightNode, false)
							end

							if lightNode ~= nil then
								setVisibility(lightNode, false)
							end

							if lightShaderNode ~= nil then
								local _, y, z, w = getShaderParameter(lightShaderNode, "lightControl")

								setShaderParameter(lightShaderNode, "lightControl", 0, y, z, w, false)
							end

							if light.speed > 0 then
								local rot = math.random(0, math.pi * 2)

								if light.rotatorNode ~= nil then
									setRotation(light.rotatorNode, 0, rot, 0)
								end
							end

							self.beaconLight = light
						end

						delete(i3dNode)
					end
				end

				delete(lightXmlFile)
			end
		end
	end

	self.beaconLightsActive = false
end

function Seesaw:createRampJoint(ramp)
	local constructor = JointConstructor.new()

	constructor:setActors(self.rootNode, ramp.nodeId)
	constructor:setJointTransforms(ramp.jointTransform, ramp.jointTransform)

	local springForce = 10500
	local springDamping = 5500

	constructor:setEnableCollision(false)
	constructor:setRotationLimitSpring(springForce, springDamping, springForce, springDamping, springForce, springDamping)
	constructor:setTranslationLimitSpring(springForce, springDamping, springForce, springDamping, springForce, springDamping)
	constructor:setTranslationLimit(0, true, 0, 0)
	constructor:setTranslationLimit(1, true, 0, 0)
	constructor:setTranslationLimit(2, true, 0, 0)
	constructor:setRotationLimit(0, 0, 0)
	constructor:setRotationLimit(1, 0, 0)
	constructor:setRotationLimit(2, -ramp.maxAngle, ramp.maxAngle)

	return constructor:finalize()
end

function Seesaw:reset()
	self:removeFromPhysics()

	for _, ramp in ipairs(self.ramps) do
		local x, y, z = unpack(ramp.orgTranslation)
		local _, _, rotZ = unpack(ramp.orgRotation)

		self:setLocalPosition(ramp, x, y, z, rotZ, true)
	end

	self:addToPhysics()

	for _, ramp in ipairs(self.ramps) do
		local x, y, z = unpack(ramp.orgTranslation)

		self:setLocalPosition(ramp, x, y, z, ramp.maxAngle, true)
		setJointFrame(ramp.jointIndex, 0, ramp.jointTransform)
	end
end

function Seesaw:addToPhysics()
	if not self.isAddedToPhysics then
		addToPhysics(self.rootNode)

		for _, ramp in ipairs(self.ramps) do
			setRigidBodyType(ramp.nodeId, self:getDefaultRigidBodyType())
			addToPhysics(ramp.nodeId)

			if self.isServer then
				ramp.jointIndex = self:createRampJoint(ramp)
			end
		end

		self.isAddedToPhysics = true
	end
end

function Seesaw:removeFromPhysics()
	removeFromPhysics(self.rootNode)

	for _, ramp in ipairs(self.ramps) do
		removeFromPhysics(ramp.nodeId)

		if self.isServer then
			ramp.jointIndex = 0
		end
	end

	self.isAddedToPhysics = false
end

function Seesaw:getDefaultRigidBodyType()
	if self.isServer then
		return RigidBodyType.DYNAMIC
	end

	return RigidBodyType.KINEMATIC
end

function Seesaw:isHorizontal()
	local ramp1, ramp2 = unpack(self.ramps)
	local _, _, rz1 = getRotation(ramp1.nodeId)
	local _, _, rz2 = getRotation(ramp2.nodeId)

	if math.abs(math.deg(rz1)) <= Seesaw.ANGLE_THRESHOLD and math.abs(math.deg(rz2)) <= Seesaw.ANGLE_THRESHOLD then
		return true
	end

	return false
end

function Seesaw:update(dt)
	if self.beaconLightsActive then
		local beaconLight = self.beaconLight

		if beaconLight.rotatorNode ~= nil then
			rotate(beaconLight.rotatorNode, 0, beaconLight.speed * dt, 0)
		end

		self:raiseActive()
	end

	if not self.isServer then
		self.networkTimeInterpolator:update(dt)

		local interpolationAlpha = self.networkTimeInterpolator:getAlpha()

		for _, ramp in ipairs(self.ramps) do
			local x, y, z = ramp.positionInterpolator:getInterpolatedValues(interpolationAlpha)
			local rotZ = ramp.angleInterpolator:getInterpolatedValue(interpolationAlpha)

			self:setPosition(ramp, x, y, z, rotZ, false)
		end

		if self.networkTimeInterpolator:isInterpolating() then
			self:raiseActive()
		end
	end
end

function Seesaw:updateMove()
	local hasMoved = true

	for _, ramp in ipairs(self.ramps) do
		local x, y, z = getWorldTranslation(ramp.nodeId)
		local _, _, zRot = getRotation(ramp.nodeId)
		local threshold = 0.01
		hasMoved = hasMoved or threshold < math.abs(ramp.sendRotZ - zRot)

		if hasMoved then
			ramp.sendPosX = x
			ramp.sendPosY = y
			ramp.sendPosZ = z
			ramp.sendRotZ = zRot
		end
	end

	if hasMoved then
		self:raiseDirtyFlags(self.physicsObjectDirtyFlag)
	end

	return hasMoved
end

function Seesaw:updateTick(dt)
	if self.isServer then
		self:updateMove()
		self:raiseActive()
	end
end

function Seesaw:setBeaconLightVisibility(visibility, force, noEventSend)
	if visibility ~= self.beaconLightsActive or force then
		if self.isServer and not noEventSend then
			g_server:broadcastEvent(SuperCupSeeSawEvent.new(self, visibility, force))
		end

		self.beaconLightsActive = visibility
		local beaconLight = self.beaconLight

		if beaconLight ~= nil then
			local realBeaconLights = g_gameSettings:getValue("realBeaconLights")

			if realBeaconLights and beaconLight.realLightNode ~= nil then
				setVisibility(beaconLight.realLightNode, visibility)
			end

			if beaconLight.lightNode ~= nil then
				setVisibility(beaconLight.lightNode, visibility)
			end

			if beaconLight.lightShaderNode ~= nil then
				local value = visibility and 1 * beaconLight.intensity or 0
				local _, y, z, w = getShaderParameter(beaconLight.lightShaderNode, "lightControl")

				setShaderParameter(beaconLight.lightShaderNode, "lightControl", value, y, z, w, false)
			end
		end

		self:raiseActive()
	end

	return true
end
