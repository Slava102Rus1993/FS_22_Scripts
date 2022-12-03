UmbilicalHoseConnector = {
	MOD_DIRECTORY = g_currentModDirectory,
	MOD_NAME = g_currentModName,
	GUIDE_LENGTH = 5,
	GUIDE = "hoseUmbilical",
	GUIDE_OVERLOAD = "hoseOverload",
	GUIDE_FLAT = "hoseFlatToRound",
	CONNECTOR_ID = UmbilicalHoseOrchestrator.TYPE_HEAD,
	MAX_UMBILICAL_HOSE_LENGTH = 1000
}

function UmbilicalHoseConnector.initSpecialization()
	local schema = Vehicle.xmlSchema

	schema:setXMLSpecializationType("UmbilicalHoseConnector")
	UmbilicalHoseConnector.registerConnectorXMLPaths(schema, "vehicle.umbilicalHoseConnector")
	UmbilicalHoseConnector.registerConnectorXMLPaths(schema, "vehicle.umbilicalHoseConnector.connector(?)")
	schema:setXMLSpecializationType()

	local schemaSavegame = Vehicle.xmlSchemaSavegame
	local modName = g_manureModName

	schemaSavegame:register(XMLValueType.INT, ("vehicles.vehicle(?).%s.umbilicalHoseConnector.connector(?)#connectorType"):format(modName), "The connector type")
	UmbilicalHoseOrchestrator.registerSavegameXMLPaths(schemaSavegame, ("vehicles.vehicle(?).%s.umbilicalHoseConnector.connector(?).umbilicalHose"):format(modName))
end

function UmbilicalHoseConnector.registerConnectorXMLPaths(schema, baseName)
	schema:register(XMLValueType.NODE_INDEX, baseName .. "#attachNode", "attachNode")
	schema:register(XMLValueType.NODE_INDEX, baseName .. "#targetNode", "targetNode")
	schema:register(XMLValueType.BOOL, baseName .. "#createGuide", "Create guide hose")
	schema:register(XMLValueType.BOOL, baseName .. "#requiresDelayedNode", "Requires delayed node")
	schema:register(XMLValueType.STRING, baseName .. "#guideHoseType", "type")
	schema:register(XMLValueType.FLOAT, baseName .. "#attachRange", "the max attach range")
end

function UmbilicalHoseConnector.prerequisitesPresent(specializations)
	return true
end

function UmbilicalHoseConnector.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "canFindUmbilicalHose", UmbilicalHoseConnector.canFindUmbilicalHose)
	SpecializationUtil.registerFunction(vehicleType, "canUpdateUmbilicalHose", UmbilicalHoseConnector.canUpdateUmbilicalHose)
	SpecializationUtil.registerFunction(vehicleType, "needsUmbilicalHoseForceUpdate", UmbilicalHoseConnector.needsUmbilicalHoseForceUpdate)
	SpecializationUtil.registerFunction(vehicleType, "getAttachNode", UmbilicalHoseConnector.getAttachNode)
	SpecializationUtil.registerFunction(vehicleType, "getTargetNode", UmbilicalHoseConnector.getTargetNode)
	SpecializationUtil.registerFunction(vehicleType, "getTargetOffsetFactor", UmbilicalHoseConnector.getTargetOffsetFactor)
	SpecializationUtil.registerFunction(vehicleType, "hasUmbilicalHose", UmbilicalHoseConnector.hasUmbilicalHose)
	SpecializationUtil.registerFunction(vehicleType, "getUmbilicalHose", UmbilicalHoseConnector.getUmbilicalHose)
	SpecializationUtil.registerFunction(vehicleType, "getUmbilicalHoseConnectPoint", UmbilicalHoseConnector.getUmbilicalHoseConnectPoint)
	SpecializationUtil.registerFunction(vehicleType, "hasUmbilicalHoseGuide", UmbilicalHoseConnector.hasUmbilicalHoseGuide)
	SpecializationUtil.registerFunction(vehicleType, "getUmbilicalHoseGuide", UmbilicalHoseConnector.getUmbilicalHoseGuide)
	SpecializationUtil.registerFunction(vehicleType, "attachUmbilicalHoseFromQuery", UmbilicalHoseConnector.attachUmbilicalHoseFromQuery)
	SpecializationUtil.registerFunction(vehicleType, "attachUmbilicalHose", UmbilicalHoseConnector.attachUmbilicalHose)
	SpecializationUtil.registerFunction(vehicleType, "detachUmbilicalHose", UmbilicalHoseConnector.detachUmbilicalHose)
	SpecializationUtil.registerFunction(vehicleType, "isAttachUmbilicalHoseAllowed", UmbilicalHoseConnector.isAttachUmbilicalHoseAllowed)
	SpecializationUtil.registerFunction(vehicleType, "isDetachUmbilicalHoseAllowed", UmbilicalHoseConnector.isDetachUmbilicalHoseAllowed)
	SpecializationUtil.registerFunction(vehicleType, "createGuide", UmbilicalHoseConnector.createGuide)
	SpecializationUtil.registerFunction(vehicleType, "removeGuide", UmbilicalHoseConnector.removeGuide)
	SpecializationUtil.registerFunction(vehicleType, "registerConnectorNode", UmbilicalHoseConnector.registerConnectorNode)
end

function UmbilicalHoseConnector.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", UmbilicalHoseConnector)
	SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", UmbilicalHoseConnector)
	SpecializationUtil.registerEventListener(vehicleType, "onPreDelete", UmbilicalHoseConnector)
	SpecializationUtil.registerEventListener(vehicleType, "onReadStream", UmbilicalHoseConnector)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", UmbilicalHoseConnector)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", UmbilicalHoseConnector)
	SpecializationUtil.registerEventListener(vehicleType, "onPostUpdate", UmbilicalHoseConnector)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", UmbilicalHoseConnector)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", UmbilicalHoseConnector)
end

function UmbilicalHoseConnector.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getPowerMultiplier", UmbilicalHoseConnector.getPowerMultiplier)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsFoldAllowed", UmbilicalHoseConnector.getIsFoldAllowed)
end

function UmbilicalHoseConnector.registerEvents(vehicleType)
	SpecializationUtil.registerEvent(vehicleType, "onAttachUmbilicalHose")
	SpecializationUtil.registerEvent(vehicleType, "onDetachUmbilicalHose")
end

function UmbilicalHoseConnector:onLoad()
	self.spec_umbilicalHoseConnector = self[("spec_%s.umbilicalHoseConnector"):format(UmbilicalHoseConnector.MOD_NAME)]
	local spec = self.spec_umbilicalHoseConnector
	local baseKey = "vehicle.umbilicalHoseConnector"
	spec.connectors = {}
	spec.connectorsByNode = {}

	local function loadConnector(id, key, connector)
		connector.id = id
		connector.attachNode = self.xmlFile:getValue(key .. "#attachNode", nil, self.components, self.i3dMappings)
		connector.targetNode = self.xmlFile:getValue(key .. "#targetNode", connector.attachNode, self.components, self.i3dMappings)
		connector.createGuide = self.xmlFile:getValue(key .. "#createGuide", true)
		connector.requiresDelayedNode = self.xmlFile:getValue(key .. "#requiresDelayedNode", false)
		connector.guideHoseType = self.xmlFile:getValue(key .. "#guideHoseType", "hoseFlatToRound")
		connector.attachRange = self.xmlFile:getValue(key .. "#attachRange", 3)
		connector.guideHose = nil
		connector.umbilicalHose = nil
		connector.connectorType = nil
	end

	local isReel = SpecializationUtil.hasSpecialization(UmbilicalReel, self.specializations)

	self.xmlFile:iterate(baseKey .. ".connector", function (id, key)
		local connector = {}

		loadConnector(id, key, connector)

		if connector.attachNode ~= nil or isReel then
			table.insert(spec.connectors, connector)
			self:registerConnectorNode(connector.attachNode, connector.id)
		end
	end)

	if #spec.connectors == 0 then
		local connector = {}

		loadConnector(1, "vehicle.umbilicalHoseConnector", connector)

		if connector.attachNode ~= nil or isReel then
			table.insert(spec.connectors, connector)
			self:registerConnectorNode(connector.attachNode, connector.id)
		end
	end

	spec.umbilicalHoseQueryInfo = {}
	spec.umbilicalHoseBufferQuery = {}

	if #spec.connectors == 0 and not isReel then
		SpecializationUtil.removeEventListener(self, "onRegisterActionEvents", UmbilicalHoseConnector)
		SpecializationUtil.removeEventListener(self, "onReadStream", UmbilicalHoseConnector)
		SpecializationUtil.removeEventListener(self, "onWriteStream", UmbilicalHoseConnector)
		SpecializationUtil.removeEventListener(self, "onUpdate", UmbilicalHoseConnector)
		SpecializationUtil.removeEventListener(self, "onPostUpdate", UmbilicalHoseConnector)
		SpecializationUtil.removeEventListener(self, "onUpdateTick", UmbilicalHoseConnector)
	end
end

function UmbilicalHoseConnector:onPostLoad(savegame)
	local spec = self.spec_umbilicalHoseConnector

	if savegame ~= nil and not savegame.resetVehicles then
		local key = ("%s.%s.umbilicalHoseConnector"):format(savegame.key, self:manure_getModName())
		local i = 0

		while true do
			local connectorKey = ("%s.connector(%d)"):format(key, i)

			if not savegame.xmlFile:hasProperty(connectorKey) then
				break
			end

			local connector = spec.connectors[i + 1]
			local connectorType = savegame.xmlFile:getValue(connectorKey .. "#connectorType")

			if connectorType ~= nil and savegame.xmlFile:hasProperty(connectorKey .. ".umbilicalHose") then
				local umbilicalHose = g_currentMission.manure:createUmbilicalHose()

				if umbilicalHose:loadFromXMLFile(savegame.xmlFile, connectorKey .. ".umbilicalHose") then
					umbilicalHose:setOwnerFarmId(self:getOwnerFarmId(), true)
					umbilicalHose:register()
					self:attachUmbilicalHose(umbilicalHose, connector.id, connectorType, connector.createGuide, true)
				else
					umbilicalHose:delete()
				end
			end

			i = i + 1
		end
	end
end

function UmbilicalHoseConnector:saveToXMLFile(xmlFile, key, usedModNames)
	local spec = self.spec_umbilicalHoseConnector

	for connectorId, connector in ipairs(spec.connectors) do
		local connectorKey = ("%s.connector(%d)"):format(key, connectorId - 1)
		local umbilicalHose = connector.umbilicalHose
		local connectorType = connector.connectorType

		if umbilicalHose ~= nil and connectorType ~= nil and umbilicalHose:isSavedAt(connectorType) and umbilicalHose:saveToXMLFile(xmlFile, connectorKey .. ".umbilicalHose", usedModNames, connectorType) then
			xmlFile:setValue(connectorKey .. "#connectorType", connectorType)
		end
	end
end

function UmbilicalHoseConnector:onPreDelete()
	local spec = self.spec_umbilicalHoseConnector
	local isDetachAllowed = self:isDetachUmbilicalHoseAllowed()

	for connectorId, connector in ipairs(spec.connectors) do
		if connector.umbilicalHose ~= nil then
			self:detachUmbilicalHose(connectorId, not isDetachAllowed, true)
		end
	end
end

function UmbilicalHoseConnector:onReadStream(streamId, connection)
	if connection:getIsServer() then
		local spec = self.spec_umbilicalHoseConnector

		for _, connector in ipairs(spec.connectors) do
			local hasUmbilicalHoseConnected = streamReadBool(streamId)

			if hasUmbilicalHoseConnected then
				local connectorType = streamReadUIntN(streamId, 2) + 1
				local umbilicalHose = NetworkUtil.readNodeObject(streamId)

				self:attachUmbilicalHose(umbilicalHose, connector.id, connectorType, connector.createGuide, true)
			end
		end
	end
end

function UmbilicalHoseConnector:onWriteStream(streamId, connection)
	if not connection:getIsServer() then
		local spec = self.spec_umbilicalHoseConnector

		for _, connector in ipairs(spec.connectors) do
			local hasUmbilicalHoseConnected = connector.connectorType ~= nil

			streamWriteBool(streamId, hasUmbilicalHoseConnected)

			if hasUmbilicalHoseConnected then
				streamWriteUIntN(streamId, connector.connectorType - 1, 2)
				NetworkUtil.writeNodeObject(streamId, connector.umbilicalHose)
			end
		end
	end
end

function UmbilicalHoseConnector:onUpdate(dt)
	local spec = self.spec_umbilicalHoseConnector

	if not self.isServer then
		return
	end

	for connectorId, connector in ipairs(spec.connectors) do
		if connector.umbilicalHose ~= nil and connector.connectorType ~= nil and connector.umbilicalHose:hasControlPoints() then
			local canUpdate = self:canUpdateUmbilicalHose()
			local needsForceUpdate = self:needsUmbilicalHoseForceUpdate()
			local node = self:getTargetNode(connectorId)
			local offsetFactor = self:getTargetOffsetFactor()
			local limitToGround = connector.createGuide
			local hasMoved, movementIsValid = connector.umbilicalHose:updatePositionByNode(node, offsetFactor, canUpdate, connector.connectorType, needsForceUpdate, limitToGround)

			if not movementIsValid then
				self:detachUmbilicalHose(connectorId)
			end

			if hasMoved then
				self:raiseActive()
			end
		end
	end
end

function UmbilicalHoseConnector:onPostUpdate(dt)
	local spec = self.spec_umbilicalHoseConnector

	if not self.isClient then
		return
	end

	for _, connector in ipairs(spec.connectors) do
		if connector.guideHose ~= nil then
			local umbilicalHose = connector.umbilicalHose
			local hose = connector.guideHose

			if umbilicalHose ~= nil then
				if hose:canPerformCompute() then
					local c2, c3 = umbilicalHose:getCurvePoints(connector.connectorType)
					local g0, g1 = hose.curve:controlsFromCubicBezierToCatmull(hose:getControlPoints())
					local p0 = {
						g0[1],
						g0[2],
						g0[3]
					}
					local p1 = {
						g1[1],
						g1[2],
						g1[3]
					}
					local p2 = {
						c2.position.x,
						c2.position.y,
						c2.position.z
					}
					local p3 = {
						c3.position.x,
						c3.position.y,
						c3.position.z
					}

					hose:curveTo(p0, p1, p2, p3)
				end
			else
				hose:update()
			end
		end
	end
end

function UmbilicalHoseConnector:onUpdateTick(dt)
	local spec = self.spec_umbilicalHoseConnector
	local query = spec.umbilicalHoseQueryInfo
	local buffer = spec.umbilicalHoseBufferQuery
	local attachActionEvent = spec.actionEvents[InputAction.PM_ATTACH]
	local hasUmbilicalHose = false

	if self:canFindUmbilicalHose() then
		for connectorId, connector in ipairs(spec.connectors) do
			local connectorHasUmbilicalHose = self:hasUmbilicalHose(connectorId)
			hasUmbilicalHose = hasUmbilicalHose or connectorHasUmbilicalHose

			if not connectorHasUmbilicalHose then
				g_currentMission.manure:getClosestUmbilicalHose(self:getAttachNode(connectorId), connector.attachRange, buffer)
			end
		end

		query.hose = buffer.hose
		query.node = buffer.node
		query.type = buffer.type
		buffer.hose = nil
		buffer.node = nil
		buffer.type = nil
	else
		query.hose = nil
		query.node = nil
		query.type = nil
	end

	if attachActionEvent ~= nil then
		local hasUmbilicalHoseInQuery = query.hose ~= nil

		if hasUmbilicalHoseInQuery then
			g_currentMission.manure:showHoseContext(g_i18n:getText("info_attachUmbilicalHoseContext"))
		end

		local prio = hasUmbilicalHoseInQuery and GS_PRIO_VERY_HIGH or GS_PRIO_VERY_LOW
		local key = hasUmbilicalHoseInQuery and "action_attachUmbilicalHose" or "action_detachUmbilicalHose"

		g_inputBinding:setActionEventTextVisibility(attachActionEvent.actionEventId, hasUmbilicalHoseInQuery or hasUmbilicalHose)
		g_inputBinding:setActionEventTextPriority(attachActionEvent.actionEventId, prio)
		g_inputBinding:setActionEventText(attachActionEvent.actionEventId, g_i18n:getText(key))
	end
end

function UmbilicalHoseConnector:registerConnectorNode(node, connectorId)
	if node == nil then
		return
	end

	connectorId = connectorId or 1
	local spec = self.spec_umbilicalHoseConnector
	spec.connectorsByNode[node] = spec.connectors[connectorId]
end

function UmbilicalHoseConnector:createGuide(connectorId, color, targetNode, guideHoseType)
	local spec = self.spec_umbilicalHoseConnector
	local connector = spec.connectors[connectorId]
	color = color or connector.umbilicalHose:getColor()
	targetNode = targetNode or connector.umbilicalHose:getGuideConnectPointNodeAt(connector.connectorType, not connector.requiresDelayedNode)
	guideHoseType = guideHoseType or connector.guideHoseType

	if self.isClient then
		self:removeGuide(connectorId)

		local node = self:getAttachNode(connectorId)
		local cacheHose = g_currentMission.manure.shapeCacheContainer:getByKeyOrDefault(guideHoseType)
		local hoseCacheEntry = cacheHose:clone()
		local bends = guideHoseType == UmbilicalHoseConnector.GUIDE_OVERLOAD or guideHoseType == UmbilicalHoseConnector.GUIDE_FLAT
		local adaptToGround = not bends
		connector.guideHose = HoseBase(node, targetNode, hoseCacheEntry.node, UmbilicalHoseConnector.GUIDE_LENGTH, bends, adaptToGround)

		connector.guideHose:setColor(color)
	end
end

function UmbilicalHoseConnector:removeGuide(connectorId)
	local spec = self.spec_umbilicalHoseConnector
	local connector = spec.connectors[connectorId]

	if self.isClient and connector.guideHose ~= nil then
		self:removeAllSubWashableNodes(connector.guideHose.mesh)
		connector.guideHose:delete()

		connector.guideHose = nil
	end
end

function UmbilicalHoseConnector:attachUmbilicalHoseFromQuery(query)
	local spec = self.spec_umbilicalHoseConnector
	local connector = spec.connectorsByNode[query.node]

	self:attachUmbilicalHose(query.hose, connector.id, query.type, connector.createGuide)
end

function UmbilicalHoseConnector:attachUmbilicalHose(umbilicalHose, connectorId, connectorType, createGuide, noEventSend)
	local spec = self.spec_umbilicalHoseConnector

	UmbilicalHoseConnectorAttachEvent.sendEvent(self, umbilicalHose, connectorId, connectorType, createGuide, noEventSend)

	local connector = spec.connectors[connectorId]

	umbilicalHose:onAttach(self, connectorType, connector.requiresDelayedNode or self:needsUmbilicalHoseForceUpdate(), false, connector.requiresDelayedNode or not connector.requiresDelayedNode and not createGuide)

	connector.umbilicalHose = umbilicalHose
	connector.connectorType = connectorType

	if createGuide then
		self:createGuide(connectorId)
	end

	umbilicalHose:raiseActive()
	SpecializationUtil.raiseEvent(self, "onAttachUmbilicalHose", umbilicalHose, connectorType, connectorId)
end

function UmbilicalHoseConnector:detachUmbilicalHose(connectorId, deleteUmbilicalHose, noEventSend)
	deleteUmbilicalHose = deleteUmbilicalHose or false
	local spec = self.spec_umbilicalHoseConnector
	local connector = spec.connectors[connectorId]
	connector.connectorType = nil
	local umbilicalHose = connector.umbilicalHose

	UmbilicalHoseConnectorDetachEvent.sendEvent(self, connectorId, deleteUmbilicalHose, noEventSend)
	SpecializationUtil.raiseEvent(self, "onDetachUmbilicalHose", umbilicalHose, connectorId)

	if umbilicalHose ~= nil then
		umbilicalHose:onDetach(self)

		if deleteUmbilicalHose then
			g_currentMission.manure:deleteUmbilicalHose(umbilicalHose, true)
		end
	end

	connector.umbilicalHose = nil

	self:removeGuide(connectorId)
end

function UmbilicalHoseConnector:canFindUmbilicalHose()
	return true
end

function UmbilicalHoseConnector:canUpdateUmbilicalHose()
	return true
end

function UmbilicalHoseConnector:needsUmbilicalHoseForceUpdate()
	return false
end

function UmbilicalHoseConnector:getAttachNode(connectorId)
	connectorId = connectorId or 1
	local spec = self.spec_umbilicalHoseConnector

	return spec.connectors[connectorId].attachNode
end

function UmbilicalHoseConnector:getTargetNode(connectorId)
	connectorId = connectorId or 1
	local spec = self.spec_umbilicalHoseConnector

	return spec.connectors[connectorId].targetNode
end

function UmbilicalHoseConnector:getTargetOffsetFactor()
	return 0
end

function UmbilicalHoseConnector:getUmbilicalHose(connectorId)
	connectorId = connectorId or 1
	local spec = self.spec_umbilicalHoseConnector

	return spec.connectors[connectorId].umbilicalHose
end

function UmbilicalHoseConnector:hasUmbilicalHose(connectorId)
	connectorId = connectorId or 1
	local spec = self.spec_umbilicalHoseConnector

	return spec.connectors[connectorId].umbilicalHose ~= nil
end

function UmbilicalHoseConnector:getUmbilicalHoseConnectPoint(connectorId, getNextOrPreviousInstead, invertConnectorType)
	connectorId = connectorId or 1
	local spec = self.spec_umbilicalHoseConnector
	local connector = spec.connectors[connectorId]
	local connectorType = connector.connectorType

	if invertConnectorType then
		connectorType = connectorType == UmbilicalHoseOrchestrator.TYPE_HEAD and UmbilicalHoseOrchestrator.TYPE_TAIL or UmbilicalHoseOrchestrator.TYPE_HEAD
	end

	return connector.umbilicalHose:getConnectPointAt(connectorType, getNextOrPreviousInstead)
end

function UmbilicalHoseConnector:getUmbilicalHoseGuide(connectorId)
	connectorId = connectorId or 1
	local spec = self.spec_umbilicalHoseConnector

	return spec.connectors[connectorId].guideHose
end

function UmbilicalHoseConnector:hasUmbilicalHoseGuide(connectorId)
	connectorId = connectorId or 1
	local spec = self.spec_umbilicalHoseConnector

	return spec.connectors[connectorId].guideHose ~= nil
end

function UmbilicalHoseConnector:isAttachUmbilicalHoseAllowed(umbilicalHose)
	return g_currentMission.accessHandler:canFarmAccessOtherId(self:getOwnerFarmId(), umbilicalHose:getOwnerFarmId())
end

function UmbilicalHoseConnector:isDetachUmbilicalHoseAllowed()
	return true
end

function UmbilicalHoseConnector:getPowerMultiplier(superFunc)
	local multiplier = superFunc(self)
	local spec = self.spec_umbilicalHoseConnector

	for connectorId, connector in pairs(spec.connectors) do
		if self:hasUmbilicalHose(connectorId) then
			local length = connector.umbilicalHose:getTotalLength()
			multiplier = multiplier + length / UmbilicalHoseConnector.MAX_UMBILICAL_HOSE_LENGTH
		end
	end

	return multiplier
end

function UmbilicalHoseConnector:getIsFoldAllowed(superFunc, direction, onAiTurnOn)
	local spec = self.spec_umbilicalHoseConnector

	for connectorId, _ in pairs(spec.connectors) do
		if self:hasUmbilicalHose(connectorId) then
			return false, g_i18n:getText("warning_detachUmbilicalHose")
		end
	end

	return superFunc(self, direction, onAiTurnOn)
end

function UmbilicalHoseConnector:actionEventAttachUmbilicalHose(...)
	local spec = self.spec_umbilicalHoseConnector
	local query = spec.umbilicalHoseQueryInfo

	if query.hose ~= nil then
		if self:isAttachUmbilicalHoseAllowed(query.hose) then
			self:attachUmbilicalHoseFromQuery(query)
		else
			g_currentMission:showBlinkingWarning(g_i18n:getText("info_attachUmbilicalHoseNotAllowed"))
		end
	elseif self:isDetachUmbilicalHoseAllowed() then
		for connectorId, _ in ipairs(spec.connectors) do
			if self:hasUmbilicalHose(connectorId) then
				self:detachUmbilicalHose(connectorId)

				break
			end
		end
	end
end

function UmbilicalHoseConnector:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	if self.isClient then
		local spec = self.spec_umbilicalHoseConnector

		self:clearActionEventsTable(spec.actionEvents)

		if isActiveForInput then
			local _, actionEventToggle = self:addActionEvent(spec.actionEvents, InputAction.PM_ATTACH, self, UmbilicalHoseConnector.actionEventAttachUmbilicalHose, false, true, false, true, nil, , true)

			g_inputBinding:setActionEventText(actionEventToggle, g_i18n:getText("action_attachUmbilicalHose"))
			g_inputBinding:setActionEventActive(actionEventToggle, true)
			g_inputBinding:setActionEventTextVisibility(actionEventToggle, true)
			g_inputBinding:setActionEventTextPriority(actionEventToggle, GS_PRIO_VERY_HIGH)
		end
	end
end
