ExtendedSlopeCompensation = {
	SLOPE_COLLISION_MASK = 223,
	COMPENSATION_NODE_XML_KEY = "vehicle.extendedSlopeCompensation.compensationNode(?)",
	MOD_DIRECTORY = g_currentModDirectory,
	MOD_NAME = g_currentModName,
	SPEC_NAME = g_currentModName .. ".extendedSlopeCompensation",
	SPEC_TABLE_NAME = "spec_" .. g_currentModName .. ".extendedSlopeCompensation",
	prerequisitesPresent = function (specializations)
		return true
	end
}

function ExtendedSlopeCompensation.initSpecialization()
	local schema = Vehicle.xmlSchema

	schema:setXMLSpecializationType("ExtendedSlopeCompensation")
	schema:register(XMLValueType.ANGLE, "vehicle.extendedSlopeCompensation#threshold", "Update threshold for animation", 0.1)
	schema:register(XMLValueType.BOOL, "vehicle.extendedSlopeCompensation#highUpdateFrequency", "Defines if the angle is updated every frame or every seconds frame", false)
	schema:register(XMLValueType.INT, ExtendedSlopeCompensation.COMPENSATION_NODE_XML_KEY .. "#wheel1", "Wheel index 1")
	schema:register(XMLValueType.INT, ExtendedSlopeCompensation.COMPENSATION_NODE_XML_KEY .. "#wheel2", "Wheel index 2")
	schema:register(XMLValueType.ANGLE, ExtendedSlopeCompensation.COMPENSATION_NODE_XML_KEY .. "#maxAngle", "Max. angle", 5)
	schema:register(XMLValueType.ANGLE, ExtendedSlopeCompensation.COMPENSATION_NODE_XML_KEY .. "#minAngle", "Min. angle", "Negative #maxAngle")
	schema:register(XMLValueType.ANGLE, ExtendedSlopeCompensation.COMPENSATION_NODE_XML_KEY .. "#speed", "Move speed (degree/sec)", 5)
	schema:register(XMLValueType.BOOL, ExtendedSlopeCompensation.COMPENSATION_NODE_XML_KEY .. "#inverted", "Inverted rotation", false)
	schema:register(XMLValueType.STRING, ExtendedSlopeCompensation.COMPENSATION_NODE_XML_KEY .. "#animationName", "Animation name")
	schema:register(XMLValueType.NODE_INDEX, ExtendedSlopeCompensation.COMPENSATION_NODE_XML_KEY .. "#referenceNode", "Node that is used to detect the current angle")
	schema:register(XMLValueType.INT, ExtendedSlopeCompensation.COMPENSATION_NODE_XML_KEY .. "#referenceAxis", "Reference angle detection axis", 1)
	schema:register(XMLValueType.NODE_INDEX, ExtendedSlopeCompensation.COMPENSATION_NODE_XML_KEY .. "#rotationNode", "Node that is rotated based on the slope angle")
	schema:register(XMLValueType.INT, ExtendedSlopeCompensation.COMPENSATION_NODE_XML_KEY .. "#rotationAxis", "Rotation axis on wich the rotationNode is rotated", 1)
	schema:register(XMLValueType.FLOAT, ExtendedSlopeCompensation.COMPENSATION_NODE_XML_KEY .. "#foldAngleScale", "Angle scale while folded", 1)
	schema:register(XMLValueType.BOOL, ExtendedSlopeCompensation.COMPENSATION_NODE_XML_KEY .. "#invertFoldAngleScale", "Invert angle folding scale", false)
	schema:setXMLSpecializationType()

	local schemaSavegame = Vehicle.xmlSchemaSavegame

	schemaSavegame:register(XMLValueType.ANGLE, string.format("vehicles.vehicle(?).%s.compensationNode(?)#lastAngle", ExtendedSlopeCompensation.SPEC_NAME), "Last angle of compensation node")
end

function ExtendedSlopeCompensation.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "loadExtendedCompensationNodeFromXML", ExtendedSlopeCompensation.loadExtendedCompensationNodeFromXML)
	SpecializationUtil.registerFunction(vehicleType, "getExtendedCompensationAngle", ExtendedSlopeCompensation.getExtendedCompensationAngle)
	SpecializationUtil.registerFunction(vehicleType, "getExtendedCompensationAngleScale", ExtendedSlopeCompensation.getExtendedCompensationAngleScale)
	SpecializationUtil.registerFunction(vehicleType, "getExtendedCompensationGroundPosition", ExtendedSlopeCompensation.getExtendedCompensationGroundPosition)
	SpecializationUtil.registerFunction(vehicleType, "extendedSlopeDetectionCallback", ExtendedSlopeCompensation.extendedSlopeDetectionCallback)
	SpecializationUtil.registerFunction(vehicleType, "setExtendedCompensationNodeAngle", ExtendedSlopeCompensation.setExtendedCompensationNodeAngle)
end

function ExtendedSlopeCompensation.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", ExtendedSlopeCompensation)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", ExtendedSlopeCompensation)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", ExtendedSlopeCompensation)
end

function ExtendedSlopeCompensation:onPostLoad(savegame)
	local spec = self[ExtendedSlopeCompensation.SPEC_TABLE_NAME]
	spec.lastRaycastDistance = 0
	spec.compensationNodes = {}
	local i = 0

	while true do
		local key = string.format("vehicle.extendedSlopeCompensation.compensationNode(%d)", i)

		if not self.xmlFile:hasProperty(key) then
			break
		end

		local compensationNode = {}

		if self:loadExtendedCompensationNodeFromXML(compensationNode, self.xmlFile, key) then
			table.insert(spec.compensationNodes, compensationNode)
		end

		i = i + 1
	end

	spec.threshold = self.xmlFile:getValue("vehicle.extendedSlopeCompensation#threshold", 0.002)

	if #spec.compensationNodes == 0 then
		SpecializationUtil.removeEventListener(self, "onUpdate", ExtendedSlopeCompensation)
		SpecializationUtil.removeEventListener(self, "onUpdateTick", ExtendedSlopeCompensation)
	else
		if self.xmlFile:getValue("vehicle.extendedSlopeCompensation#highUpdateFrequency", false) then
			SpecializationUtil.removeEventListener(self, "onUpdateTick", ExtendedSlopeCompensation)
		else
			SpecializationUtil.removeEventListener(self, "onUpdate", ExtendedSlopeCompensation)
		end

		if savegame ~= nil then
			for j, compensationNode in ipairs(spec.compensationNodes) do
				local lastAngle = savegame.xmlFile:getValue(string.format("%s.%s.compensationNode(%d)#lastAngle", savegame.key, ExtendedSlopeCompensation.SPEC_NAME, j - 1), 0)

				self:setExtendedCompensationNodeAngle(compensationNode, lastAngle)
			end
		end
	end
end

function ExtendedSlopeCompensation:saveToXMLFile(xmlFile, key, usedModNames)
	local spec = self[ExtendedSlopeCompensation.SPEC_TABLE_NAME]

	for i, compensationNode in ipairs(spec.compensationNodes) do
		xmlFile:setValue(string.format("%s.compensationNode(%d)#lastAngle", key, i - 1), compensationNode.lastAngle)
	end
end

function ExtendedSlopeCompensation:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	local spec = self[ExtendedSlopeCompensation.SPEC_TABLE_NAME]

	for _, compensationNode in ipairs(spec.compensationNodes) do
		local angle = MathUtil.clamp(self:getExtendedCompensationAngle(compensationNode), compensationNode.minAngle, compensationNode.maxAngle) * self:getExtendedCompensationAngleScale(compensationNode)

		if compensationNode.inverted then
			angle = -angle
		end

		local difference = math.abs(compensationNode.targetAngle - angle)

		if spec.threshold < difference then
			compensationNode.targetAngle = angle
		end

		local dir = MathUtil.sign(compensationNode.targetAngle - compensationNode.lastAngle)
		local limit = dir > 0 and math.min or math.max
		local speedScale = math.min(math.max(math.abs(compensationNode.lastAngle - angle) / (compensationNode.speed * 1000), 0.2), 1)
		local newAngle = limit(compensationNode.lastAngle + compensationNode.speed * dt * dir * speedScale, compensationNode.targetAngle)

		if newAngle ~= compensationNode.lastAngle then
			self:setExtendedCompensationNodeAngle(compensationNode, newAngle)
		end
	end
end

function ExtendedSlopeCompensation:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	ExtendedSlopeCompensation.onUpdate(self, dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
end

function ExtendedSlopeCompensation:loadExtendedCompensationNodeFromXML(compensationNode, xmlFile, key)
	compensationNode.useWheelReference = false
	compensationNode.raycastDistance = 0
	compensationNode.lastDistance1 = 0
	compensationNode.lastDistance2 = 0

	for i = 1, 2 do
		local name = string.format("wheel%d", i)
		local wheelId = self.xmlFile:getValue(key .. "#" .. name)

		if wheelId ~= nil then
			local wheel = self:getWheels()[wheelId]

			if wheel ~= nil then
				compensationNode[name .. "Node"] = wheel.driveNode
				compensationNode.raycastDistance = math.max(compensationNode.raycastDistance, wheel.radius + 1)
				compensationNode.useWheelReference = true
			else
				Logging.xmlWarning(self.xmlFile, "Unable to find wheel index '%d' for compensation node '%s'", wheelId, key)

				return false
			end
		end
	end

	compensationNode.referenceNode = self.xmlFile:getValue(key .. "#referenceNode", nil, self.components, self.i3dMappings)
	compensationNode.referenceAxis = self.xmlFile:getValue(key .. "#referenceAxis", 1)
	compensationNode.rotationNode = self.xmlFile:getValue(key .. "#rotationNode", nil, self.components, self.i3dMappings)
	compensationNode.rotationAxis = self.xmlFile:getValue(key .. "#rotationAxis", 1)

	if compensationNode.rotationNode ~= nil then
		compensationNode.rotationNodeRotation = {
			getRotation(compensationNode.rotationNode)
		}
	end

	compensationNode.maxAngle = self.xmlFile:getValue(key .. "#maxAngle", 5)
	compensationNode.minAngle = self.xmlFile:getValue(key .. "#minAngle", -math.deg(compensationNode.maxAngle))
	compensationNode.speed = self.xmlFile:getValue(key .. "#speed", 1) / 1000
	compensationNode.inverted = self.xmlFile:getValue(key .. "#inverted", false)
	compensationNode.targetAngle = 0
	compensationNode.lastAngle = 0
	compensationNode.animationName = self.xmlFile:getValue(key .. "#animationName")

	if compensationNode.animationName ~= nil then
		local updateAnimation = self:getExtendedCompensationAngleScale(compensationNode) > 0

		self:setAnimationTime(compensationNode.animationName, 0, updateAnimation)
		self:setAnimationTime(compensationNode.animationName, 1, updateAnimation)
		self:setAnimationTime(compensationNode.animationName, 0.5, updateAnimation)
	end

	compensationNode.foldAngleScale = xmlFile:getValue(key .. "#foldAngleScale")
	compensationNode.invertFoldAngleScale = xmlFile:getValue(key .. "#invertFoldAngleScale", false)

	return true
end

function ExtendedSlopeCompensation:getExtendedCompensationAngle(compensationNode)
	if compensationNode.useWheelReference then
		local x1, y1, z1, valid1 = self:getExtendedCompensationGroundPosition(compensationNode, 1)
		local x2, y2, z2, valid2 = self:getExtendedCompensationGroundPosition(compensationNode, 2)

		if valid1 and valid2 then
			local h = y1 - y2
			local l = MathUtil.vector2Length(x1 - x2, z1 - z2)

			return math.tan(h / l)
		end
	elseif compensationNode.referenceNode ~= nil then
		local x, y, z = worldDirectionToLocal(compensationNode.referenceNode, 0, 1, 0)

		if compensationNode.referenceAxis == 1 then
			return math.atan2(x, y)
		elseif compensationNode.referenceAxis == 2 then
			return math.atan2(x, z)
		elseif compensationNode.referenceAxis == 3 then
			return math.atan2(y, z)
		end
	end

	return 0
end

function ExtendedSlopeCompensation:getExtendedCompensationAngleScale(compensationNode)
	if self.getCompensationAngleScale ~= nil then
		return self:getCompensationAngleScale(compensationNode)
	end

	return 1
end

function ExtendedSlopeCompensation:getExtendedCompensationGroundPosition(compensationNode, wheelId)
	local spec = self[ExtendedSlopeCompensation.SPEC_TABLE_NAME]
	local x, y, z = getWorldTranslation(compensationNode["wheel" .. wheelId .. "Node"])
	spec.lastRaycastDistance = 0

	raycastAll(x, y, z, 0, -1, 0, "extendedSlopeDetectionCallback", compensationNode.raycastDistance, self, ExtendedSlopeCompensation.SLOPE_COLLISION_MASK)

	local distance = spec.lastRaycastDistance

	if distance == 0 then
		distance = compensationNode["lastDistance" .. wheelId]
	else
		compensationNode["lastDistance" .. wheelId] = spec.lastRaycastDistance
	end

	return x, y - distance, z, distance ~= 0
end

function ExtendedSlopeCompensation:extendedSlopeDetectionCallback(hitObjectId, x, y, z, distance)
	if getRigidBodyType(hitObjectId) ~= RigidBodyType.STATIC then
		return true
	end

	self[ExtendedSlopeCompensation.SPEC_TABLE_NAME].lastRaycastDistance = distance

	return false
end

function ExtendedSlopeCompensation:setExtendedCompensationNodeAngle(compensationNode, angle)
	if compensationNode.animationName ~= nil and self.setAnimationTime ~= nil then
		local alpha = (angle - compensationNode.minAngle) / (compensationNode.maxAngle - compensationNode.minAngle)

		self:setAnimationTime(compensationNode.animationName, alpha, true)
	end

	if compensationNode.rotationNode ~= nil then
		compensationNode.rotationNodeRotation[1], compensationNode.rotationNodeRotation[2], compensationNode.rotationNodeRotation[3] = getRotation(compensationNode.rotationNode)
		compensationNode.rotationNodeRotation[compensationNode.rotationAxis] = angle

		setRotation(compensationNode.rotationNode, compensationNode.rotationNodeRotation[1], compensationNode.rotationNodeRotation[2], compensationNode.rotationNodeRotation[3])

		if self.setMovingToolDirty ~= nil then
			self:setMovingToolDirty(compensationNode.rotationNode)
		end
	end

	compensationNode.lastAngle = angle
end

function ExtendedSlopeCompensation:updateDebugValues(values)
	local spec = self[ExtendedSlopeCompensation.SPEC_TABLE_NAME]

	for i, compensationNode in ipairs(spec.compensationNodes) do
		local angle = MathUtil.clamp(self:getExtendedCompensationAngle(compensationNode), compensationNode.minAngle, compensationNode.maxAngle)

		if compensationNode.inverted then
			angle = -angle
		end

		table.insert(values, {
			name = string.format("compNode %d", i),
			value = string.format("%.2f°", math.deg(angle))
		})
	end
end
