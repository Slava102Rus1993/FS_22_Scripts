local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

TreeAutomaticArmControl = {
	MOD_NAME = g_currentModName,
	SPEC_NAME = g_currentModName .. ".treeAutomaticArmControl"
}
TreeAutomaticArmControl.SPEC_TABLE_NAME = "spec_" .. TreeAutomaticArmControl.SPEC_NAME
TreeAutomaticArmControl.STATE_NONE = 0
TreeAutomaticArmControl.STATE_MOVE_BACK = 1
TreeAutomaticArmControl.STATE_ALIGN_X = 2
TreeAutomaticArmControl.STATE_ALIGN_Z = 3
TreeAutomaticArmControl.STATE_FINISHED = 4

function TreeAutomaticArmControl.prerequisitesPresent(specializations)
	return SpecializationUtil.hasSpecialization(Cylindered, specializations)
end

function TreeAutomaticArmControl.initSpecialization()
	g_configurationManager:addConfigurationType("treeAutomaticArmControl", g_i18n:getText("shop_configuration"), "treeAutomaticArmControl", nil, , , ConfigurationUtil.SELECTOR_MULTIOPTION)

	local schema = Vehicle.xmlSchema

	schema:setXMLSpecializationType("TreeAutomaticArmControl")
	TreeAutomaticArmControl.registerXMLPaths(schema, "vehicle.treeAutomaticArmControl")
	TreeAutomaticArmControl.registerXMLPaths(schema, "vehicle.treeAutomaticArmControl.treeAutomaticArmControlConfigurations.treeAutomaticArmControlConfiguration(?)")
	ObjectChangeUtil.registerObjectChangeXMLPaths(schema, "vehicle.treeAutomaticArmControl.treeAutomaticArmControlConfigurations.treeAutomaticArmControlConfiguration(?)")
	schema:setXMLSpecializationType()
end

function TreeAutomaticArmControl.registerXMLPaths(schema, basePath)
	schema:register(XMLValueType.BOOL, basePath .. "#requiresEasyArmControl", "If 'true' then it is only available if easy arm control is enabled", true)
	schema:register(XMLValueType.FLOAT, basePath .. "#foldMinLimit", "Min. folding time to activate the automatic control", 0)
	schema:register(XMLValueType.FLOAT, basePath .. "#foldMaxLimit", "Max. folding time to activate the automatic control", 1)
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".treeDetectionNode#node", "Tree detection node")
	schema:register(XMLValueType.FLOAT, basePath .. ".treeDetectionNode#minRadius", "Min. distance to tree", 5)
	schema:register(XMLValueType.FLOAT, basePath .. ".treeDetectionNode#maxRadius", "Max. distance to tree", 10)
	schema:register(XMLValueType.ANGLE, basePath .. ".treeDetectionNode#maxAngle", "Max. angle to the target tree", 45)
	schema:register(XMLValueType.FLOAT, basePath .. ".treeDetectionNode#cutHeight", "Tree cur height measured from terrain height", 0.4)
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".xAlignment#movingToolNode", "Moving tool to do alignment on X axis (most likely Y-Rot tool)")
	schema:register(XMLValueType.FLOAT, basePath .. ".xAlignment#speedScale", "Speed scale used to control the moving tool", 1)
	schema:register(XMLValueType.FLOAT, basePath .. ".xAlignment#offset", "X alignment offset from tree detection node", "Automatically calculated with the difference on X between xAlignment and zAlignment node")
	schema:register(XMLValueType.ANGLE, basePath .. ".xAlignment#threshold", "X alignment angle threshold (if angle to target is below this value the Y and Z alignment will start)", 1)
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".zAlignment#movingToolNode", "Moving tool to do alignment on Z axis (EasyArmControl Z Target)")
	schema:register(XMLValueType.FLOAT, basePath .. ".zAlignment#speedScale", "Speed scale used to control the moving tool", 1)
	schema:register(XMLValueType.FLOAT, basePath .. ".zAlignment#moveBackDistance", "Distance the arm is moved back behind the tree first to start the x alignment", 2)
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".zAlignment#referenceNode", "Reference node which is tried to be moved right in front of the tree")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".yAlignment#movingToolNode", "Moving tool to do alignment on Y axis (EasyArmControl Y Target)")
	schema:register(XMLValueType.FLOAT, basePath .. ".yAlignment#speedScale", "Speed scale used to control the moving tool", 1)
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".yAlignment#referenceNode", "Reference node which is tried to be moved right in front of the tree")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".alignmentNode(?)#movingToolNode", "MovingTool node which is aligned according to attributes")
	schema:register(XMLValueType.ANGLE, basePath .. ".alignmentNode(?)#rotation", "Target rotation")
	schema:register(XMLValueType.FLOAT, basePath .. ".alignmentNode(?)#translation", "Target translation")
	schema:register(XMLValueType.FLOAT, basePath .. ".alignmentNode(?)#speedScale", "Speed scale used to reach the target rotation/translation", 1)
	schema:register(XMLValueType.BOOL, basePath .. ".alignmentNode(?)#isPrerequisite", "Defines if this moving tool is first brought into the target position before the real alignment starts", false)
	TargetTreeMarker.registerXMLPaths(schema, basePath .. ".treeMarker")
	schema:register(XMLValueType.COLOR, basePath .. ".treeMarker#targetColor", "Color of tree is available to alignment, but not ready for cut yet", "2 2 0")
	schema:register(XMLValueType.COLOR, basePath .. ".treeMarker#tooThickColor", "Color of tree is too thick to be cutted", "2 0 0")
end

function TreeAutomaticArmControl.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "getIsAutoTreeAlignmentAllowed", TreeAutomaticArmControl.getIsAutoTreeAlignmentAllowed)
	SpecializationUtil.registerFunction(vehicleType, "getAutoAlignTreeMarkerState", TreeAutomaticArmControl.getAutoAlignTreeMarkerState)
	SpecializationUtil.registerFunction(vehicleType, "setTreeArmAlignmentInput", TreeAutomaticArmControl.setTreeArmAlignmentInput)
	SpecializationUtil.registerFunction(vehicleType, "doTreeArmAlignment", TreeAutomaticArmControl.doTreeArmAlignment)
	SpecializationUtil.registerFunction(vehicleType, "getBestTreeToAutoAlign", TreeAutomaticArmControl.getBestTreeToAutoAlign)
	SpecializationUtil.registerFunction(vehicleType, "onTreeAutoOverlapCallback", TreeAutomaticArmControl.onTreeAutoOverlapCallback)
	SpecializationUtil.registerFunction(vehicleType, "getTreeAutomaticOverwrites", TreeAutomaticArmControl.getTreeAutomaticOverwrites)
end

function TreeAutomaticArmControl.registerOverwrittenFunctions(vehicleType)
end

function TreeAutomaticArmControl.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", TreeAutomaticArmControl)
	SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", TreeAutomaticArmControl)
	SpecializationUtil.registerEventListener(vehicleType, "onDelete", TreeAutomaticArmControl)
	SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", TreeAutomaticArmControl)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", TreeAutomaticArmControl)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", TreeAutomaticArmControl)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", TreeAutomaticArmControl)
end

function TreeAutomaticArmControl:onLoad(savegame)
	local spec = self[TreeAutomaticArmControl.SPEC_TABLE_NAME]
	local configurationId = Utils.getNoNil(self.configurations.treeAutomaticArmControl, 1)
	local configKey = string.format("vehicle.treeAutomaticArmControl.treeAutomaticArmControlConfigurations.treeAutomaticArmControlConfiguration(%d)", configurationId - 1)

	ObjectChangeUtil.updateObjectChanges(self.xmlFile, "vehicle.treeAutomaticArmControl.treeAutomaticArmControlConfigurations.treeAutomaticArmControlConfiguration", configurationId, self.components, self)

	if not self.xmlFile:hasProperty(configKey) then
		configKey = "vehicle.treeAutomaticArmControl"
	end

	spec.alignmentNodes = {}

	self.xmlFile:iterate(configKey .. ".alignmentNode", function (index, nodeKey)
		local alignmentNode = {
			movingToolNode = self.xmlFile:getValue(nodeKey .. "#movingToolNode", nil, self.components, self.i3dMappings),
			rotation = self.xmlFile:getValue(nodeKey .. "#rotation"),
			translation = self.xmlFile:getValue(nodeKey .. "#translation")
		}

		if alignmentNode.movingToolNode ~= nil and (alignmentNode.rotation ~= nil or alignmentNode.translation ~= nil) then
			alignmentNode.speedScale = self.xmlFile:getValue(nodeKey .. "#speedScale", 1)
			alignmentNode.isPrerequisite = self.xmlFile:getValue(nodeKey .. "#isPrerequisite", false)

			table.insert(spec.alignmentNodes, alignmentNode)
		end
	end)

	spec.xAlignment = {}
	spec.zAlignment = {}
	spec.yAlignment = {}
	spec.treeDetectionNode = self.xmlFile:getValue(configKey .. ".treeDetectionNode#node", nil, self.components, self.i3dMappings)

	if spec.treeDetectionNode ~= nil then
		spec.treeDetectionNodeMinRadius = self.xmlFile:getValue(configKey .. ".treeDetectionNode#minRadius", 5)
		spec.treeDetectionNodeMaxRadius = self.xmlFile:getValue(configKey .. ".treeDetectionNode#maxRadius", 10)
		spec.treeDetectionNodeMaxAngle = self.xmlFile:getValue(configKey .. ".treeDetectionNode#maxAngle", 45)
		spec.treeDetectionNodeCutHeight = self.xmlFile:getValue(configKey .. ".treeDetectionNode#cutHeight", 0.4)
		spec.treeDetectionNodeCutHeightSafetyOffset = 0.075
		spec.foundTrees = {}
		spec.foundValidTargetServer = false
		spec.lastFoundValidTarget = false
		spec.lastCenterX = 0
		spec.lastTargetY = 0
		spec.lastMinZ = 0
		spec.lastTargetTrans = {
			0,
			0,
			0
		}
		spec.state = TreeAutomaticArmControl.STATE_NONE
		spec.xAlignment = {
			movingToolNode = self.xmlFile:getValue(configKey .. ".xAlignment#movingToolNode", nil, self.components, self.i3dMappings),
			speedScale = self.xmlFile:getValue(configKey .. ".xAlignment#speedScale", 1),
			offset = self.xmlFile:getValue(configKey .. ".xAlignment#offset"),
			threshold = self.xmlFile:getValue(configKey .. ".xAlignment#threshold", 1)
		}
		spec.zAlignment = {
			movingToolNode = self.xmlFile:getValue(configKey .. ".zAlignment#movingToolNode", nil, self.components, self.i3dMappings),
			speedScale = self.xmlFile:getValue(configKey .. ".zAlignment#speedScale", 1),
			moveBackDistance = self.xmlFile:getValue(configKey .. ".zAlignment#moveBackDistance", 2),
			referenceNode = self.xmlFile:getValue(configKey .. ".zAlignment#referenceNode", nil, self.components, self.i3dMappings)
		}
		spec.yAlignment = {
			movingToolNode = self.xmlFile:getValue(configKey .. ".yAlignment#movingToolNode", nil, self.components, self.i3dMappings),
			speedScale = self.xmlFile:getValue(configKey .. ".yAlignment#speedScale", 1),
			referenceNode = self.xmlFile:getValue(configKey .. ".yAlignment#referenceNode", nil, self.components, self.i3dMappings)
		}
		spec.treeMarker = TargetTreeMarker.new(self, self.rootNode)

		spec.treeMarker:loadFromXML(self.xmlFile, configKey .. ".treeMarker")

		spec.treeMarker.cutColor = {
			spec.treeMarker.color[1],
			spec.treeMarker.color[2],
			spec.treeMarker.color[3]
		}
		spec.treeMarker.targetColor = self.xmlFile:getValue(configKey .. ".treeMarker#targetColor", "2 2 0", true)
		spec.treeMarker.tooThickColor = self.xmlFile:getValue(configKey .. ".treeMarker#tooThickColor", "2 0 0", true)
		spec.requiresEasyArmControl = self.xmlFile:getValue(configKey .. "#requiresEasyArmControl", true)
		spec.foldMinLimit = self.xmlFile:getValue(configKey .. "#foldMinLimit", 0)
		spec.foldMaxLimit = self.xmlFile:getValue(configKey .. "#foldMaxLimit", 1)

		if spec.xAlignment.offset == nil and spec.yAlignment.referenceNode ~= nil and spec.xAlignment.movingToolNode ~= nil then
			local offset, _, _ = localToLocal(spec.yAlignment.referenceNode, spec.xAlignment.movingToolNode, 0, 0, 0)
			spec.xAlignment.offset = -offset
		end

		spec.controlInputLastValue = 0
		spec.controlInputTimer = 0
		spec.dirtyFlag = self:getNextDirtyFlag()
	else
		spec.xAlignment.offset = self.xmlFile:getValue(configKey .. ".xAlignment#offset")
		spec.zAlignment.referenceNode = self.xmlFile:getValue(configKey .. ".zAlignment#referenceNode", nil, self.components, self.i3dMappings)
		spec.yAlignment.referenceNode = self.xmlFile:getValue(configKey .. ".yAlignment#referenceNode", nil, self.components, self.i3dMappings)

		SpecializationUtil.removeEventListener(self, "onDelete", TreeAutomaticArmControl)
		SpecializationUtil.removeEventListener(self, "onUpdate", TreeAutomaticArmControl)
		SpecializationUtil.removeEventListener(self, "onRegisterActionEvents", TreeAutomaticArmControl)
	end
end

function TreeAutomaticArmControl:onPostLoad(savegame)
	local spec = self[TreeAutomaticArmControl.SPEC_TABLE_NAME]

	if spec.xAlignment.movingToolNode ~= nil then
		spec.xAlignment.movingTool = self:getMovingToolByNode(spec.xAlignment.movingToolNode)
	end

	if spec.zAlignment.movingToolNode ~= nil then
		spec.zAlignment.movingTool = self:getMovingToolByNode(spec.zAlignment.movingToolNode)
	end

	if spec.yAlignment.movingToolNode ~= nil then
		spec.yAlignment.movingTool = self:getMovingToolByNode(spec.yAlignment.movingToolNode)
	end

	for i = #spec.alignmentNodes, 1, -1 do
		local alignmentNode = spec.alignmentNodes[i]
		alignmentNode.movingTool = self:getMovingToolByNode(alignmentNode.movingToolNode)

		if alignmentNode.movingTool == nil then
			table.remove(spec.alignmentNodes, i)
		end
	end
end

function TreeAutomaticArmControl:onDelete()
	local spec = self[TreeAutomaticArmControl.SPEC_TABLE_NAME]

	if spec.treeMarker ~= nil then
		spec.treeMarker:delete()
	end
end

function TreeAutomaticArmControl:onReadUpdateStream(streamId, timestamp, connection)
	local spec = self[TreeAutomaticArmControl.SPEC_TABLE_NAME]

	if spec.treeDetectionNode ~= nil then
		if not connection:getIsServer() then
			if streamReadBool(streamId) then
				spec.controlInputLastValue = streamReadBool(streamId) and 1 or 0
				spec.controlInputTimer = 250
			end
		elseif streamReadBool(streamId) then
			spec.foundValidTargetServer = streamReadBool(streamId)
		end
	end
end

function TreeAutomaticArmControl:onWriteUpdateStream(streamId, connection, dirtyMask)
	local spec = self[TreeAutomaticArmControl.SPEC_TABLE_NAME]

	if spec.treeDetectionNode ~= nil then
		if connection:getIsServer() then
			if streamWriteBool(streamId, bitAND(dirtyMask, spec.dirtyFlag) ~= 0) then
				streamWriteBool(streamId, spec.controlInputLastValue ~= 0)
			end
		elseif streamWriteBool(streamId, bitAND(dirtyMask, spec.dirtyFlag) ~= 0) then
			streamWriteBool(streamId, spec.foundValidTargetServer)
		end
	end
end

function TreeAutomaticArmControl:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	local spec = self[TreeAutomaticArmControl.SPEC_TABLE_NAME]
	local foundValidTarget = false

	if self:getIsAutoTreeAlignmentAllowed() then
		local bestTreeId = self:getBestTreeToAutoAlign(spec.treeDetectionNode, spec.foundTrees)

		if bestTreeId ~= nil then
			local wx, wy, wz = getWorldTranslation(bestTreeId)
			wy = math.max(wy, getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, wx, wy, wz) + spec.treeDetectionNodeCutHeight + spec.treeDetectionNodeCutHeightSafetyOffset)
			local x, y, z, dx, dy, dz, radius = SplitShapeUtil.getTreeOffsetPosition(bestTreeId, wx, wy, wz, 3)

			if x ~= nil then
				local lx, _, lz = worldToLocal(spec.treeDetectionNode, x, y, z)

				spec.treeMarker:setPosition(x, y, z, dx, dy, dz, radius, 0)

				local hasSplitShape, hasValidRadius = self:getAutoAlignTreeMarkerState(radius)

				if hasSplitShape then
					spec.treeMarker:setColor(spec.treeMarker.cutColor[1], spec.treeMarker.cutColor[2], spec.treeMarker.cutColor[3], false)
				else
					local color = hasValidRadius and spec.treeMarker.targetColor or spec.treeMarker.tooThickColor

					if spec.state == TreeAutomaticArmControl.STATE_NONE then
						spec.treeMarker:setColor(color[1], color[2], color[3], false)
					else
						spec.treeMarker:setColor(color[1], color[2], color[3], true)
					end
				end

				spec.lastCenterX = lx
				spec.lastTargetY = y - spec.treeDetectionNodeCutHeightSafetyOffset
				spec.lastMinZ = lz - radius
				spec.lastTargetTrans[3] = z
				spec.lastTargetTrans[2] = y
				spec.lastTargetTrans[1] = x
				foundValidTarget = true
			end
		end

		for i = #spec.foundTrees, 1, -1 do
			spec.foundTrees[i] = nil
		end

		if spec.state ~= TreeAutomaticArmControl.STATE_NONE then
			table.insert(spec.foundTrees, bestTreeId)
		end

		local x, y, z = getWorldTranslation(spec.treeDetectionNode)

		overlapSphere(x, y, z, spec.treeDetectionNodeMaxRadius, "onTreeAutoOverlapCallback", self, CollisionFlag.TREE, false, true, false, true)
	end

	if self.isClient then
		local targetFound = spec.foundValidTargetServer and foundValidTarget and isActiveForInputIgnoreSelection

		spec.treeMarker:setIsActive(targetFound and g_woodCuttingMarkerEnabled)
		TreeAutomaticArmControl.updateActionEvents(self, targetFound)
	end

	if self.isServer then
		if foundValidTarget ~= spec.lastFoundValidTarget then
			spec.foundValidTargetServer = foundValidTarget
			spec.lastFoundValidTarget = foundValidTarget

			self:raiseDirtyFlags(spec.dirtyFlag)
		end

		if spec.controlInputTimer > 0 then
			spec.controlInputTimer = spec.controlInputTimer - dt

			if spec.controlInputTimer <= 0 then
				spec.controlInputLastValue = 0
				spec.controlInputTimer = 0
			end

			self:setTreeArmAlignmentInput(spec.controlInputLastValue)
		end
	end
end

function TreeAutomaticArmControl:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	if self.isClient then
		local spec = self[TreeAutomaticArmControl.SPEC_TABLE_NAME]

		self:clearActionEventsTable(spec.actionEvents)

		if isActiveForInputIgnoreSelection then
			local _, actionEventId = self:addPoweredActionEvent(spec.actionEvents, InputAction.TREE_AUTOMATIC_ALIGN, self, TreeAutomaticArmControl.actionEvent, true, false, true, true, nil)

			g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_HIGH)
			TreeAutomaticArmControl.updateActionEvents(self, false)
		end
	end
end

function TreeAutomaticArmControl:actionEvent(actionName, inputValue, callbackState, isAnalog)
	self:setTreeArmAlignmentInput(inputValue)
end

function TreeAutomaticArmControl:updateActionEvents(state)
	local spec = self[TreeAutomaticArmControl.SPEC_TABLE_NAME]
	local actionEvent = spec.actionEvents[InputAction.TREE_AUTOMATIC_ALIGN]

	if actionEvent ~= nil then
		g_inputBinding:setActionEventActive(actionEvent.actionEventId, state)
	end
end

function TreeAutomaticArmControl:getIsAutoTreeAlignmentAllowed()
	local spec = self[TreeAutomaticArmControl.SPEC_TABLE_NAME]

	if self.getIsControlled ~= nil and not self:getIsControlled() then
		return false
	end

	if spec.requiresEasyArmControl and (self.spec_cylindered.easyArmControl == nil or not self.spec_cylindered.easyArmControl.state) then
		return false
	end

	if self.spec_woodHarvester ~= nil and self.spec_woodHarvester.hasAttachedSplitShape then
		return false
	end

	if self.spec_woodHarvester == nil and self.spec_fellerBuncher == nil then
		local hasWoodHarvester = false

		for i = 1, #self.childVehicles do
			local childVehicle = self.childVehicles[i]

			if childVehicle ~= self and (childVehicle.spec_woodHarvester ~= nil or childVehicle.spec_fellerBuncher ~= nil) then
				hasWoodHarvester = true

				break
			end
		end

		if not hasWoodHarvester then
			return false
		end
	end

	if self.getFoldAnimTime ~= nil then
		local time = self:getFoldAnimTime()

		if time < spec.foldMinLimit or spec.foldMaxLimit < time then
			return false
		end
	end

	return true
end

function TreeAutomaticArmControl:getAutoAlignTreeMarkerState(foundRadius, checkChildren)
	if self.spec_woodHarvester ~= nil then
		return self.spec_woodHarvester.curSplitShape ~= nil, foundRadius <= self.spec_woodHarvester.cutMaxRadius
	end

	if self.spec_fellerBuncher ~= nil then
		return self.spec_fellerBuncher.foundSplitShape ~= nil, foundRadius <= self.spec_fellerBuncher.maxRadius
	end

	if checkChildren ~= false then
		for i = 1, #self.childVehicles do
			local childVehicle = self.childVehicles[i]

			if childVehicle ~= self and childVehicle.getAutoAlignTreeMarkerState ~= nil then
				local splitShapeFound, hasValidRadius = childVehicle:getAutoAlignTreeMarkerState(foundRadius, false)

				if splitShapeFound ~= nil then
					return splitShapeFound, hasValidRadius
				end
			end
		end
	end

	return nil, 
end

function TreeAutomaticArmControl:setTreeArmAlignmentInput(inputValue)
	local spec = self[TreeAutomaticArmControl.SPEC_TABLE_NAME]

	if self.isServer then
		if inputValue > 0 and spec.state ~= TreeAutomaticArmControl.STATE_FINISHED and spec.foundValidTargetServer then
			self:doTreeArmAlignment()
		elseif inputValue == 0 then
			spec.state = TreeAutomaticArmControl.STATE_NONE
		end
	else
		spec.controlInputLastValue = inputValue

		if inputValue > 0 then
			self:raiseDirtyFlags(spec.dirtyFlag)
		end
	end
end

function TreeAutomaticArmControl:doTreeArmAlignment()
	local spec = self[TreeAutomaticArmControl.SPEC_TABLE_NAME]

	if not TreeAutomaticArmControl.prepareAlignment(self) then
		return
	end

	if spec.state == TreeAutomaticArmControl.STATE_NONE then
		spec.state = TreeAutomaticArmControl.STATE_MOVE_BACK
	end

	local zAlignmentReferenceNode = spec.zAlignment.referenceNode
	local yAlignmentReferenceNode = spec.yAlignment.referenceNode
	local xAlignmentOffset = spec.xAlignment.offset or 0

	for i = 1, #self.childVehicles do
		local childVehicle = self.childVehicles[i]

		if childVehicle ~= self and childVehicle.getTreeAutomaticOverwrites ~= nil then
			if not TreeAutomaticArmControl.prepareAlignment(childVehicle) then
				return
			end

			local _zAlignmentReferenceNode, _yAlignmentReferenceNode, _xAlignmentOffset = childVehicle:getTreeAutomaticOverwrites()
			yAlignmentReferenceNode = yAlignmentReferenceNode or _yAlignmentReferenceNode
			zAlignmentReferenceNode = zAlignmentReferenceNode or _zAlignmentReferenceNode

			if _xAlignmentOffset ~= nil then
				xAlignmentOffset = xAlignmentOffset + _xAlignmentOffset
			end
		end
	end

	if spec.xAlignment.movingTool ~= nil and spec.state ~= TreeAutomaticArmControl.STATE_FINISHED and spec.state ~= TreeAutomaticArmControl.STATE_MOVE_BACK then
		local x, _, z = worldToLocal(spec.xAlignment.movingTool.node, spec.lastTargetTrans[1], spec.lastTargetTrans[2], spec.lastTargetTrans[3])
		local distance = MathUtil.vector2Length(x, z)
		local angle = math.atan((x + (xAlignmentOffset or 0)) / distance) * spec.xAlignment.speedScale
		local curRot = spec.xAlignment.movingTool.curRot[spec.xAlignment.movingTool.rotationAxis]
		local move = TreeAutomaticArmControl.calculateMovingToolTargetMove(self, spec.xAlignment.movingTool, curRot + angle)

		if move ~= 0 then
			spec.xAlignment.movingTool.externalMove = move
		elseif math.abs(angle) < spec.xAlignment.threshold and spec.state == TreeAutomaticArmControl.STATE_ALIGN_X then
			spec.state = TreeAutomaticArmControl.STATE_ALIGN_Z
		end
	end

	if spec.zAlignment.movingTool ~= nil and zAlignmentReferenceNode ~= nil then
		local _, _, targetZ = localToLocal(zAlignmentReferenceNode, spec.treeDetectionNode, 0, 0, 0)
		local offset = 0

		if spec.state == TreeAutomaticArmControl.STATE_MOVE_BACK then
			offset = targetZ - (spec.lastMinZ - spec.zAlignment.moveBackDistance)

			if offset < spec.zAlignment.moveBackDistance * 0.5 then
				spec.state = TreeAutomaticArmControl.STATE_ALIGN_X
			end
		elseif spec.state == TreeAutomaticArmControl.STATE_ALIGN_Z then
			offset = targetZ - spec.lastMinZ

			if math.abs(offset) < 0.03 then
				spec.state = TreeAutomaticArmControl.STATE_FINISHED
			end
		end

		if math.abs(offset) > 0.03 then
			spec.zAlignment.movingTool.externalMove = -(offset + 0.5 * MathUtil.sign(offset)) * spec.zAlignment.speedScale
		else
			spec.zAlignment.movingTool.externalMove = 0
		end
	end

	if spec.yAlignment.movingTool ~= nil and yAlignmentReferenceNode ~= nil and spec.state == TreeAutomaticArmControl.STATE_ALIGN_Z then
		local _, curY, _ = getWorldTranslation(yAlignmentReferenceNode)
		local offset = spec.lastTargetY - curY

		if math.abs(offset) > 0.03 then
			spec.yAlignment.movingTool.externalMove = (offset + 0.5 * MathUtil.sign(offset)) * spec.yAlignment.speedScale
		else
			spec.yAlignment.movingTool.externalMove = 0
		end
	end
end

function TreeAutomaticArmControl:calculateMovingToolTargetMove(movingTool, targetRot)
	local durationToStop = movingTool.lastRotSpeed / movingTool.rotAcceleration
	local rotSpeed = movingTool.lastRotSpeed
	local stopRot = movingTool.curRot[movingTool.rotationAxis]
	local deceleration = -movingTool.rotAcceleration * MathUtil.sign(durationToStop)

	for _ = 1, math.abs(durationToStop) do
		rotSpeed = rotSpeed + deceleration
		stopRot = stopRot + rotSpeed
	end

	local threshold = 0.001
	local state, stopState, targetState = nil

	if movingTool.rotMin ~= nil and movingTool.rotMax ~= nil then
		state = Cylindered.getMovingToolState(self, movingTool)
		stopState = MathUtil.inverseLerp(movingTool.rotMin, movingTool.rotMax, stopRot)
		targetState = MathUtil.inverseLerp(movingTool.rotMin, movingTool.rotMax, targetRot)
	else
		local curRot = movingTool.curRot[movingTool.rotationAxis]
		curRot = MathUtil.normalizeRotationForShortestPath(curRot, targetRot)
		stopRot = MathUtil.normalizeRotationForShortestPath(stopRot, targetRot)
		state = curRot
		stopState = stopRot
		targetState = targetRot
		threshold = 0.0001
	end

	local move = nil

	if targetState < state then
		move = -MathUtil.sign(movingTool.rotSpeed)

		if stopState < targetState then
			return 0
		end
	else
		move = MathUtil.sign(movingTool.rotSpeed)

		if targetState < stopState then
			return 0
		end
	end

	local offset = targetState - state

	if math.abs(offset) < threshold then
		return 0
	end

	return move
end

function TreeAutomaticArmControl:prepareAlignment()
	local spec = self[TreeAutomaticArmControl.SPEC_TABLE_NAME]

	if self.getIsTurnedOn ~= nil and not self:getIsTurnedOn() and self:getCanBeTurnedOn() then
		self:setIsTurnedOn(true)
	end

	local spec_woodHarvester = self.spec_woodHarvester

	if spec_woodHarvester ~= nil and spec_woodHarvester.headerJointTilt ~= nil and spec_woodHarvester.headerJointTilt.state then
		self:setWoodHarvesterTiltState(false)
	end

	for i = 1, #spec.alignmentNodes do
		local alignmentNode = spec.alignmentNodes[i]
		local move = 0

		if alignmentNode.rotation ~= nil then
			move = TreeAutomaticArmControl.calculateMovingToolTargetMove(self, alignmentNode.movingTool, alignmentNode.rotation)
		end

		if move ~= 0 then
			alignmentNode.movingTool.externalMove = move

			if alignmentNode.isPrerequisite then
				return false
			end
		end
	end

	return true
end

function TreeAutomaticArmControl:getBestTreeToAutoAlign(referenceNode, trees)
	local minFactor = math.huge
	local minFactorTree = nil

	for i = 1, #trees do
		local treeId = trees[i]

		if entityExists(treeId) and getRigidBodyType(treeId) == RigidBodyType.STATIC and not getIsSplitShapeSplit(treeId) then
			local wx, _, wz = getWorldTranslation(treeId)

			if WoodHarvester.getCanSplitShapeBeAccessed(self, wx, wz, treeId) then
				local distance = calcDistanceFrom(referenceNode, treeId)
				local x, _, z = localToLocal(treeId, referenceNode, 0, 0, 0)
				x, z = MathUtil.vector2Normalize(x, z)
				local angle = MathUtil.getYRotationFromDirection(x, z)

				if math.abs(angle) < self[TreeAutomaticArmControl.SPEC_TABLE_NAME].treeDetectionNodeMaxAngle then
					local factor = math.abs(math.deg(angle)) + distance * 2

					if minFactor > factor then
						minFactor = factor
						minFactorTree = treeId
					end
				end
			end
		end
	end

	return minFactorTree
end

function TreeAutomaticArmControl:onTreeAutoOverlapCallback(objectId, ...)
	if not self.isDeleted and objectId ~= 0 and getHasClassId(objectId, ClassIds.SHAPE) then
		local splitType = g_splitTypeManager:getSplitTypeByIndex(getSplitType(objectId))

		if splitType ~= nil and splitType.allowsWoodHarvester then
			local spec = self[TreeAutomaticArmControl.SPEC_TABLE_NAME]
			local x1, _, z1 = getWorldTranslation(spec.treeDetectionNode)
			local x2, _, z2 = getWorldTranslation(objectId)
			local distance = MathUtil.vector2Length(x1 - x2, z1 - z2)

			if spec.treeDetectionNodeMinRadius < distance and distance < spec.treeDetectionNodeMaxRadius then
				table.insert(spec.foundTrees, objectId)
			end
		end
	end
end

function TreeAutomaticArmControl:getTreeAutomaticOverwrites()
	local spec = self[TreeAutomaticArmControl.SPEC_TABLE_NAME]

	return spec.zAlignment.referenceNode, spec.yAlignment.referenceNode, spec.xAlignment.offset
end

function TreeAutomaticArmControl.drawDebugCircleRange(node, radius, steps, minRot, maxRot)
	local ox = 0
	local oy = 0
	local oz = 0
	local range = maxRot - minRot

	for i = 1, steps do
		local a1 = math.pi * 0.5 + minRot + (i - 1) / steps * range
		local a2 = math.pi * 0.5 + minRot + i / steps * range
		local c = math.cos(a1) * radius
		local s = math.sin(a1) * radius
		local x1, y1, z1 = localToWorld(node, ox + c, oy + 0, oz + s)
		c = math.cos(a2) * radius
		s = math.sin(a2) * radius
		local x2, y2, z2 = localToWorld(node, ox + c, oy + 0, oz + s)

		drawDebugLine(x1, y1, z1, 1, 0, 0, x2, y2, z2, 1, 0, 0)
	end
end
