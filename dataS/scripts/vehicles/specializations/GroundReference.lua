GroundReference = {
	GROUND_REFERENCE_XML_KEY = "vehicle.groundReferenceNodes.groundReferenceNode(?)",
	prerequisitesPresent = function (specializations)
		return true
	end
}

function GroundReference.initSpecialization()
	local schema = Vehicle.xmlSchema

	schema:setXMLSpecializationType("GroundReference")

	local basePath = GroundReference.GROUND_REFERENCE_XML_KEY

	schema:register(XMLValueType.NODE_INDEX, basePath .. "#node", "Ground reference node")
	schema:register(XMLValueType.FLOAT, basePath .. "#threshold", "Threshold", 0)
	schema:register(XMLValueType.BOOL, basePath .. "#onlyActiveWhenLowered", "Node is only active when tool is lowered", true)
	schema:register(XMLValueType.FLOAT, basePath .. "#chargeValue", "Charge value to calculate power consumption", 1)
	schema:register(XMLValueType.FLOAT, basePath .. "#forceFactor", "Ground force factor")
	schema:register(XMLValueType.FLOAT, basePath .. "#maxActivationDepth", "Max. activation depth", 10)
	schema:register(XMLValueType.INT, SpeedRotatingParts.SPEED_ROTATING_PART_XML_KEY .. "#groundReferenceNodeIndex", "Ground reference node index")
	schema:setXMLSpecializationType()
end

function GroundReference.registerEvents(vehicleType)
end

function GroundReference.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "loadGroundReferenceNode", GroundReference.loadGroundReferenceNode)
	SpecializationUtil.registerFunction(vehicleType, "updateGroundReferenceNode", GroundReference.updateGroundReferenceNode)
	SpecializationUtil.registerFunction(vehicleType, "getGroundReferenceNodeFromIndex", GroundReference.getGroundReferenceNodeFromIndex)
	SpecializationUtil.registerFunction(vehicleType, "getIsGroundReferenceNodeActive", GroundReference.getIsGroundReferenceNodeActive)
	SpecializationUtil.registerFunction(vehicleType, "getIsGroundReferenceNodeThreshold", GroundReference.getIsGroundReferenceNodeThreshold)
end

function GroundReference.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getPowerMultiplier", GroundReference.getPowerMultiplier)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "loadSpeedRotatingPartFromXML", GroundReference.loadSpeedRotatingPartFromXML)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsSpeedRotatingPartActive", GroundReference.getIsSpeedRotatingPartActive)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "checkMovingPartDirtyUpdateNode", GroundReference.checkMovingPartDirtyUpdateNode)
end

function GroundReference.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", GroundReference)
	SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", GroundReference)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", GroundReference)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", GroundReference)
end

function GroundReference:onLoad(savegame)
	local spec = self.spec_groundReference
	spec.hasForceFactors = false
	spec.groundReferenceNodes = {}
	local i = 0

	while true do
		local baseName = string.format("vehicle.groundReferenceNodes.groundReferenceNode(%d)", i)

		if not self.xmlFile:hasProperty(baseName) then
			break
		end

		local entry = {}

		if self:loadGroundReferenceNode(self.xmlFile, baseName, entry) then
			table.insert(spec.groundReferenceNodes, entry)
		end

		i = i + 1
	end

	local totalCharge = 0

	for _, refNode in pairs(spec.groundReferenceNodes) do
		totalCharge = totalCharge + refNode.chargeValue
	end

	if totalCharge > 0 then
		for _, refNode in pairs(spec.groundReferenceNodes) do
			refNode.chargeValue = refNode.chargeValue / totalCharge
		end
	end

	local forceFactorSum = 0

	for _, refNode in pairs(spec.groundReferenceNodes) do
		forceFactorSum = forceFactorSum + refNode.forceFactor
	end

	if forceFactorSum > 0 then
		for _, refNode in pairs(spec.groundReferenceNodes) do
			refNode.forceFactor = refNode.forceFactor / forceFactorSum
		end
	end

	if #spec.groundReferenceNodes == 0 then
		SpecializationUtil.removeEventListener(self, "onUpdateTick", GroundReference)
	end
end

function GroundReference:onReadUpdateStream(streamId, timestamp, connection)
	local spec = self.spec_groundReference

	if connection:getIsServer() then
		for _, groundReferenceNode in ipairs(spec.groundReferenceNodes) do
			groundReferenceNode.isActive = streamReadBool(streamId)
		end
	end
end

function GroundReference:onWriteUpdateStream(streamId, connection, dirtyMask)
	local spec = self.spec_groundReference

	if not connection:getIsServer() then
		for _, groundReferenceNode in ipairs(spec.groundReferenceNodes) do
			streamWriteBool(streamId, groundReferenceNode.isActive)
		end
	end
end

function GroundReference:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	local spec = self.spec_groundReference

	for _, groundReferenceNode in ipairs(spec.groundReferenceNodes) do
		self:updateGroundReferenceNode(groundReferenceNode)
	end
end

function GroundReference:loadGroundReferenceNode(xmlFile, baseName, entry)
	XMLUtil.checkDeprecatedXMLElements(xmlFile, baseName .. "#index", baseName .. "#node")

	local spec = self.spec_groundReference
	local node = xmlFile:getValue(baseName .. "#node", nil, self.components, self.i3dMappings)

	if node ~= nil then
		entry.node = node
		entry.threshold = xmlFile:getValue(baseName .. "#threshold", 0)
		entry.onlyActiveWhenLowered = xmlFile:getValue(baseName .. "#onlyActiveWhenLowered", true)
		entry.chargeValue = xmlFile:getValue(baseName .. "#chargeValue", 1)
		entry.forceFactor = xmlFile:getValue(baseName .. "#forceFactor")

		if entry.forceFactor ~= nil then
			spec.hasForceFactors = true
		end

		entry.forceFactor = entry.forceFactor or 1
		entry.maxActivationDepth = xmlFile:getValue(baseName .. "#maxActivationDepth", 10)
		entry.isActive = false

		return true
	end

	return false
end

function GroundReference:updateGroundReferenceNode(groundReferenceNode)
	if self.isServer then
		local activeLowered = true

		if groundReferenceNode.onlyActiveWhenLowered and self.getIsLowered ~= nil and not self:getIsLowered(false) then
			activeLowered = false
		end

		local threshold = self:getIsGroundReferenceNodeThreshold(groundReferenceNode)
		local x, y, z = getWorldTranslation(groundReferenceNode.node)
		local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, y, z)
		local terrainDiff = terrainHeight + threshold - y
		local terrainActiv = terrainDiff > 0 and terrainDiff < groundReferenceNode.maxActivationDepth
		local densityHeight, _ = DensityMapHeightUtil.getHeightAtWorldPos(x, y, z)
		local densityDiff = densityHeight + threshold - y
		local densityActiv = densityDiff > 0 and densityDiff < groundReferenceNode.maxActivationDepth
		groundReferenceNode.isActive = activeLowered and (terrainActiv or densityActiv)
	end
end

function GroundReference:getGroundReferenceNodeFromIndex(refNodeIndex)
	local spec = self.spec_groundReference

	return spec.groundReferenceNodes[refNodeIndex]
end

function GroundReference:getIsGroundReferenceNodeActive(groundReferenceNode)
	return groundReferenceNode.isActive
end

function GroundReference:getIsGroundReferenceNodeThreshold(groundReferenceNode)
	return groundReferenceNode.threshold
end

function GroundReference:getPowerMultiplier(superFunc)
	local powerMultiplier = superFunc(self)
	local spec = self.spec_groundReference

	if #spec.groundReferenceNodes > 0 then
		local factor = 0

		if spec.hasForceFactors then
			for _, refNode in ipairs(spec.groundReferenceNodes) do
				if refNode.isActive then
					factor = factor + refNode.forceFactor
				end
			end
		else
			for _, refNode in ipairs(spec.groundReferenceNodes) do
				if refNode.isActive then
					factor = refNode.chargeValue
				end
			end
		end

		powerMultiplier = powerMultiplier * factor
	end

	return powerMultiplier
end

function GroundReference:loadSpeedRotatingPartFromXML(superFunc, speedRotatingPart, xmlFile, key)
	if not superFunc(self, speedRotatingPart, xmlFile, key) then
		return false
	end

	XMLUtil.checkDeprecatedXMLElements(self.xmlFile, key .. "#refNodeIndex", key .. "#groundReferenceNodeIndex")

	speedRotatingPart.groundReferenceNodeIndex = xmlFile:getValue(key .. "#groundReferenceNodeIndex")

	if speedRotatingPart.groundReferenceNodeIndex ~= nil and speedRotatingPart.groundReferenceNodeIndex == 0 then
		Logging.xmlWarning(self.xmlFile, "Unknown ground reference node index '%d' in '%s'! Indices start with 1!", speedRotatingPart.groundReferenceNodeIndex, key)
	end

	return true
end

function GroundReference:getIsSpeedRotatingPartActive(superFunc, speedRotatingPart)
	if speedRotatingPart.groundReferenceNodeIndex ~= nil then
		local spec = self.spec_groundReference

		if spec.groundReferenceNodes[speedRotatingPart.groundReferenceNodeIndex] ~= nil then
			if not spec.groundReferenceNodes[speedRotatingPart.groundReferenceNodeIndex].isActive then
				return false
			end
		else
			Logging.xmlWarning(self.xmlFile, "Unknown ground reference node index '%d' for speed rotating part '%s'! Indices start with 1!", speedRotatingPart.groundReferenceNodeIndex, getName(speedRotatingPart.repr or speedRotatingPart.shaderNode))

			speedRotatingPart.groundReferenceNodeIndex = nil
		end
	end

	return superFunc(self, speedRotatingPart)
end

function GroundReference:checkMovingPartDirtyUpdateNode(superFunc, node, movingPart)
	superFunc(self, node, movingPart)

	local spec = self.spec_groundReference

	for i = 1, #spec.groundReferenceNodes do
		local groundReferenceNode = spec.groundReferenceNodes[i]

		if node == groundReferenceNode.node then
			Logging.xmlError(self.xmlFile, "Found ground reference node '%s' in active dirty moving part '%s' with limited update distance. Remove limit or adjust hierarchy for correct function. (maxUpdateDistance='-')", getName(node), getName(movingPart.node))
		end
	end
end
