CropSensor = {
	MOD_NAME = g_currentModName,
	SPEC_NAME = g_currentModName .. ".cropSensor",
	MAX_UPDATES_PER_FRAME = 1,
	MIN_SENSOR_RADIUS = 5,
	PATTERN_OCTAGON = {
		{
			0.33,
			0,
			-1,
			-0.33,
			0,
			-1,
			-0.33,
			0,
			-0.33
		},
		{
			1,
			0,
			0.33,
			1,
			0,
			-0.33,
			0.33,
			0,
			-0.33
		},
		{
			-0.33,
			0,
			1,
			0.33,
			0,
			1,
			0.33,
			0,
			0.33
		},
		{
			-1,
			0,
			-0.33,
			-1,
			0,
			0.33,
			-0.33,
			0,
			0.33
		},
		{
			-0.33,
			0,
			1,
			-0.33,
			0,
			-0.33,
			0.33,
			0,
			0.33
		},
		{
			1,
			0,
			0.33,
			-0.33,
			0,
			0.33,
			0.33,
			0,
			-0.33
		}
	},
	PATTERN_CORNER_LEFT = {
		{
			0,
			0,
			0,
			-0.15,
			0,
			0.33,
			1,
			0,
			0
		},
		{
			0.33,
			0,
			0.33,
			0,
			0,
			0.66,
			0.85,
			0,
			0.33
		},
		{
			-0.15,
			0,
			0.33,
			-0.15,
			0,
			0.66,
			0.33,
			0,
			0.33
		}
	},
	PATTERN_CORNER_RIGHT = {
		{
			0,
			0,
			0,
			0.15,
			0,
			0.33,
			-1,
			0,
			0
		},
		{
			-0.33,
			0,
			0.33,
			0,
			0,
			0.66,
			-0.85,
			0,
			0.33
		},
		{
			0.15,
			0,
			0.33,
			0.15,
			0,
			0.66,
			-0.33,
			0,
			0.33
		}
	},
	prerequisitesPresent = function (specializations)
		return SpecializationUtil.hasSpecialization(PrecisionFarmingStatistic, specializations)
	end
}

function CropSensor.initSpecialization()
	g_configurationManager:addConfigurationType("cropSensor", g_i18n:getText("configuration_cropSensor"), "cropSensor", nil, , , ConfigurationUtil.SELECTOR_MULTIOPTION)

	local schema = Vehicle.xmlSchema

	schema:setXMLSpecializationType("CropSensor")
	schema:register(XMLValueType.NODE_INDEX, "vehicle.cropSensor.sensorNode(?)#node", "Sensor Node")
	schema:register(XMLValueType.NODE_INDEX, "vehicle.cropSensor.sensorNode(?)#lightNode", "Real light source node")
	schema:register(XMLValueType.NODE_INDEX, "vehicle.cropSensor.sensorNode(?)#staticLight", "Static light shape")
	schema:register(XMLValueType.FLOAT, "vehicle.cropSensor.sensorNode(?)#radius", "Sensor radius", 18)
	schema:register(XMLValueType.BOOL, "vehicle.cropSensor.sensorNode(?)#requiresDaylight", "Sensor requires daylight to work", false)
	schema:register(XMLValueType.STRING, "vehicle.cropSensor.sensorNode(?)#pattern", "Sensor pattern (OCTAGON | ?)", "OCTAGON")
	CropSensor.registerSensorLinkNodePaths(schema, "vehicle.cropSensor.cropSensorConfigurations.cropSensorConfiguration(?).sensorLinkNode(?)")
	schema:setXMLSpecializationType()
end

function CropSensor.registerSensorLinkNodePaths(schema, basePath)
	schema:register(XMLValueType.NODE_INDEX, basePath .. "#node", "Sensor Node")
	schema:register(XMLValueType.STRING, basePath .. "#type", "Type of node to link (SENSOR_LEFT | SENSOR_RIGHT | SENSOR_TOP)", "SENSOR_LEFT")
	schema:register(XMLValueType.VECTOR_TRANS, basePath .. "#translation", "Translation offset", "0 0 0")
	schema:register(XMLValueType.VECTOR_ROT, basePath .. "#rotation", "Rotation offset", "0 0 0")
	schema:register(XMLValueType.BOOL, basePath .. ".rotationNode(?)#autoRotate", "Rotation will be automatically adjusted to the vehicle orientation")
	schema:register(XMLValueType.VECTOR_ROT, basePath .. ".rotationNode(?)#rotation", "Rotation of rotation node", "0 0 0")
end

function CropSensor.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "setCropSensorActive", CropSensor.setCropSensorActive)
	SpecializationUtil.registerFunction(vehicleType, "updateCropSensorWorkingWidth", CropSensor.updateCropSensorWorkingWidth)
	SpecializationUtil.registerFunction(vehicleType, "updateSensorRadius", CropSensor.updateSensorRadius)
	SpecializationUtil.registerFunction(vehicleType, "updateSensorNode", CropSensor.updateSensorNode)
	SpecializationUtil.registerFunction(vehicleType, "linkCropSensor", CropSensor.linkCropSensor)
end

function CropSensor.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "doCheckSpeedLimit", CropSensor.doCheckSpeedLimit)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getUseTurnedOnSchema", CropSensor.getUseTurnedOnSchema)
end

function CropSensor.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", CropSensor)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", CropSensor)
	SpecializationUtil.registerEventListener(vehicleType, "onDraw", CropSensor)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", CropSensor)
	SpecializationUtil.registerEventListener(vehicleType, "onRootVehicleChanged", CropSensor)
end

function CropSensor:onLoad(savegame)
	self.spec_cropSensor = self["spec_" .. CropSensor.SPEC_NAME]
	local spec = self.spec_cropSensor
	local baseName = "vehicle.cropSensor"
	spec.sensorNodes = {}

	self.xmlFile:iterate(baseName .. ".sensorNode", function (index, key)
		local sensorNode = {
			node = self.xmlFile:getValue(key .. "#node", nil, self.components, self.i3dMappings)
		}

		if sensorNode.node ~= nil then
			sensorNode.radius = self.xmlFile:getValue(key .. "#radius", 20)
			sensorNode.origRadius = sensorNode.radius
			sensorNode.requiresDaylight = self.xmlFile:getValue(key .. "#requiresDaylight", false)
			local patternStr = self.xmlFile:getValue(key .. "#pattern", "OCTAGON")
			local pattern = CropSensor["PATTERN_" .. patternStr:upper()]

			if pattern == nil then
				Logging.xmlWarning(self.xmlFile, "Wrong pattern '%s' ground in '%s'", patternStr, key)
			end

			sensorNode.lightNode = self.xmlFile:getValue(key .. "#lightNode", nil, self.components, self.i3dMappings)

			if sensorNode.lightNode ~= nil then
				setVisibility(sensorNode.lightNode, false)
			end

			sensorNode.staticLight = self.xmlFile:getValue(key .. "#staticLight", nil, self.components, self.i3dMappings)

			if sensorNode.staticLight ~= nil then
				setShaderParameter(sensorNode.staticLight, "lightControl", 0, 0, 0, 0, false)
			end

			sensorNode.pattern = pattern or CropSensor.PATTERN_OCTAGON
			sensorNode.index = 1

			table.insert(spec.sensorNodes, sensorNode)
		end
	end)

	spec.isStandaloneSensor = #spec.sensorNodes > 0
	spec.inputActionToggle = InputAction.PRECISIONFARMING_TOGGLE_CROP_SENSOR
	local configIndex = self.configurations.cropSensor

	if configIndex ~= nil then
		local configKey = string.format("vehicle.cropSensor.cropSensorConfigurations.cropSensorConfiguration(%d)", configIndex - 1)
		spec.sensorLinkNodeData = {
			linkNodes = {}
		}

		self.xmlFile:iterate(configKey .. ".sensorLinkNode", function (index, key)
			local linkNode = {
				node = self.xmlFile:getValue(key .. "#node", nil, self.components, self.i3dMappings)
			}

			if linkNode.node ~= nil then
				linkNode.typeName = self.xmlFile:getValue(key .. "#type", "SENSOR_LEFT"):upper()
				linkNode.translation = self.xmlFile:getValue(key .. "#translation", "0 0 0", true)
				linkNode.rotation = self.xmlFile:getValue(key .. "#rotation", "0 0 0", true)
				linkNode.rotationNodes = {}

				self.xmlFile:iterate(key .. ".rotationNode", function (_, rotationNodeKey)
					local rotatioNode = {
						autoRotate = self.xmlFile:getValue(rotationNodeKey .. "#autoRotate"),
						rotation = self.xmlFile:getValue(rotationNodeKey .. "#rotation", nil, true)
					}

					table.insert(linkNode.rotationNodes, rotatioNode)
				end)
				table.insert(spec.sensorLinkNodeData.linkNodes, linkNode)
			end
		end)

		if #spec.sensorLinkNodeData.linkNodes > 0 then
			self:linkCropSensor(spec.sensorLinkNodeData)
		end

		if configIndex > 1 and g_precisionFarming ~= nil then
			local linkData = g_precisionFarming:getCropSensorLinkageData(self.configFileName)

			if linkData ~= nil then
				self:linkCropSensor(linkData)
			end
		end
	end

	spec.isAvailable = #spec.sensorNodes > 0
	spec.isActive = false
	spec.workingWidth = 0

	if spec.isAvailable then
		spec.texts = {
			toggleCropSensorPos = g_i18n:getText("action_toggleCropSensorPos", self.customEnvironment),
			toggleCropSensorNeg = g_i18n:getText("action_toggleCropSensorNeg", self.customEnvironment),
			warningSensorDaylight = g_i18n:getText("warning_sensorRequiresDaylight", self.customEnvironment)
		}

		if g_precisionFarming ~= nil then
			spec.soilMap = g_precisionFarming.soilMap
			spec.coverMap = g_precisionFarming.coverMap
			spec.nitrogenMap = g_precisionFarming.nitrogenMap
			spec.farmlandStatistics = g_precisionFarming.farmlandStatistics
		end
	end
end

function CropSensor:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	if self.isServer then
		local spec = self.spec_cropSensor

		if spec.isAvailable and spec.isActive then
			for i = 1, #spec.sensorNodes do
				local sensorNode = spec.sensorNodes[i]

				if not sensorNode.requiresDaylight or g_currentMission.environment.isSunOn then
					sensorNode.index = self:updateSensorNode(sensorNode.node, sensorNode.radius, sensorNode.pattern, sensorNode.index)
				end
			end
		end
	end
end

function CropSensor:onDraw()
	if self.isClient and not self:getIsAIActive() then
		local spec = self.spec_cropSensor

		if spec.isAvailable and spec.isActive then
			for i = 1, #spec.sensorNodes do
				local sensorNode = spec.sensorNodes[i]

				if sensorNode.requiresDaylight and not g_currentMission.environment.isSunOn then
					g_currentMission:showBlinkingWarning(spec.texts.warningSensorDaylight, 1000)
				end
			end
		end
	end
end

function CropSensor:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	if self.isClient then
		local spec = self.spec_cropSensor

		if spec.isAvailable then
			self:clearActionEventsTable(spec.actionEvents)

			if isActiveForInputIgnoreSelection then
				local _, actionEventId = self:addActionEvent(spec.actionEvents, spec.inputActionToggle, self, CropSensor.actionEventToggle, false, true, false, true, nil)

				g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)
				CropSensor.updateActionEventTexts(self)
			end
		end
	end
end

function CropSensor:onRootVehicleChanged(rootVehicle)
	if self.isServer then
		local spec = self.spec_cropSensor

		if spec.isAvailable then
			local actionController = rootVehicle.actionController

			if actionController ~= nil then
				if spec.controlledAction ~= nil then
					spec.controlledAction:updateParent(actionController)

					return
				end

				spec.controlledAction = actionController:registerAction("cropSensorTurnOn", nil, 1)

				spec.controlledAction:setCallback(self, CropSensor.actionControllerToggleEvent)
				spec.controlledAction:setFinishedFunctions(self, function ()
					return spec.isActive
				end, true, false)
				spec.controlledAction:setIsSaved(true)
				spec.controlledAction:addAIEventListener(self, "onAIFieldWorkerStart", 1)
				spec.controlledAction:addAIEventListener(self, "onAIFieldWorkerEnd", -1)
				spec.controlledAction:addAIEventListener(self, "onAIImplementStart", 1)
				spec.controlledAction:addAIEventListener(self, "onAIImplementEnd", -1)
			elseif spec.controlledAction ~= nil then
				spec.controlledAction:remove()
			end
		end
	end
end

function CropSensor:actionEventToggle(actionName, inputValue, callbackState, isAnalog)
	self:setCropSensorActive()
end

function CropSensor:updateActionEventTexts()
	local spec = self.spec_cropSensor
	local actionEvent = spec.actionEvents[spec.inputActionToggle]

	if actionEvent ~= nil then
		g_inputBinding:setActionEventText(actionEvent.actionEventId, spec.isActive and spec.texts.toggleCropSensorNeg or spec.texts.toggleCropSensorPos)
	end
end

function CropSensor:actionControllerToggleEvent(direction)
	self:setCropSensorActive(direction >= 0)

	return true
end

function CropSensor:doCheckSpeedLimit(superFunc)
	return superFunc(self) or self.spec_cropSensor ~= nil and self.spec_cropSensor.isStandaloneSensor and self.spec_cropSensor.isActive
end

function CropSensor:getUseTurnedOnSchema(superFunc)
	return superFunc(self) or self.spec_cropSensor ~= nil and self.spec_cropSensor.isStandaloneSensor and self.spec_cropSensor.isActive
end

function CropSensor:setCropSensorActive(state, noEventSend)
	local spec = self.spec_cropSensor

	if state == nil then
		state = not spec.isActive
	end

	if state ~= spec.isActive then
		if self.isClient then
			for i = 1, #spec.sensorNodes do
				local sensorNode = spec.sensorNodes[i]

				if sensorNode.lightNode ~= nil then
					setVisibility(sensorNode.lightNode, state)
				end

				if sensorNode.staticLight ~= nil then
					setShaderParameter(sensorNode.staticLight, "lightControl", state and 0.2 or 0, 0, 0, 0, false)
				end
			end
		end

		if state then
			self:updateCropSensorWorkingWidth()
		end

		spec.isActive = state

		CropSensor.updateActionEventTexts(self)
		CropSensorStateEvent.sendEvent(self, state, noEventSend)
	end
end

function CropSensor:updateCropSensorWorkingWidth()
	local spec = self.spec_cropSensor
	spec.workingWidth = CropSensor.getMaxWorkingWidth(self)

	for i = 1, #spec.sensorNodes do
		local sensorNode = spec.sensorNodes[i]

		self:updateSensorRadius(sensorNode, spec.workingWidth)
	end
end

function CropSensor:updateSensorRadius(sensorNode, workingWidth)
	if workingWidth > 0 then
		local xOffset, _, _ = localToLocal(sensorNode.node, self.rootNode, 0, 0, 0)
		workingWidth = workingWidth * 1.1
		sensorNode.radius = math.max(workingWidth / 2 - math.abs(xOffset), CropSensor.MIN_SENSOR_RADIUS)
	else
		sensorNode.radius = sensorNode.origRadius
	end
end

function CropSensor:updateSensorNode(sensorNode, radius, pattern, index)
	local spec = self.spec_cropSensor

	if index > #pattern then
		index = 1
	end

	for i = index, math.min(index + CropSensor.MAX_UPDATES_PER_FRAME - 1, #pattern) do
		local position = pattern[i]
		local xs, _, zs = localToWorld(sensorNode, position[1] * radius, position[2] * radius, position[3] * radius)
		local xw, _, zw = localToWorld(sensorNode, position[4] * radius, position[5] * radius, position[6] * radius)
		local xh, _, zh = localToWorld(sensorNode, position[7] * radius, position[8] * radius, position[9] * radius)

		spec.nitrogenMap:updateCropSensorArea(xs, zs, xw, zw, xh, zh)

		index = i
	end

	return index + 1
end

function CropSensor:linkCropSensor(linkData)
	for i = 1, #linkData.linkNodes do
		local linkNodeData = linkData.linkNodes[i]
		local linkNode = linkNodeData.node

		if linkNode == nil and linkNodeData.nodeName ~= nil and self.i3dMappings[linkNodeData.nodeName] ~= nil then
			linkNode = self.i3dMappings[linkNodeData.nodeName].nodeId
		end

		if linkNode ~= nil then
			local sensorData = g_precisionFarming:getClonedCropSensorNode(linkNodeData.typeName)

			if sensorData ~= nil then
				link(linkNode, sensorData.node)
				setTranslation(sensorData.node, linkNodeData.translation[1], linkNodeData.translation[2], linkNodeData.translation[3])
				setRotation(sensorData.node, linkNodeData.rotation[1], linkNodeData.rotation[2], linkNodeData.rotation[3])

				for j = 1, #sensorData.rotationNodes do
					local rotationNode = sensorData.rotationNodes[j]
					local autoRotate = false

					if linkNodeData.rotationNodes[j] ~= nil then
						local vRotationNode = linkNodeData.rotationNodes[j]

						if rotationNode.autoRotate and vRotationNode.autoRotate ~= false and vRotationNode.rotation == nil then
							autoRotate = true
						elseif vRotationNode.rotation ~= nil then
							setRotation(rotationNode.node, vRotationNode.rotation[1], vRotationNode.rotation[2], vRotationNode.rotation[3])
						end
					else
						autoRotate = rotationNode.autoRotate
					end

					if autoRotate then
						local rx, ry, rz = localRotationToLocal(self:getParentComponent(sensorData.node), getParent(rotationNode.node), 0, 0, 0)

						setRotation(rotationNode.node, rx, ry, rz)
					end
				end

				if sensorData.measurementNode ~= nil then
					local sensorNode = {
						node = sensorData.measurementNode,
						radius = 10
					}
					sensorNode.origRadius = sensorNode.radius
					sensorNode.pattern = linkNodeData.typeName == "SENSOR_LEFT" and CropSensor.PATTERN_CORNER_LEFT or CropSensor.PATTERN_CORNER_RIGHT
					sensorNode.requiresDaylight = sensorData.requiresDaylight
					sensorNode.index = 1

					table.insert(self.spec_cropSensor.sensorNodes, sensorNode)
				end
			end
		end
	end
end

function CropSensor.getMaxWorkingWidth(sensorVehicle)
	local childVehicles = sensorVehicle.rootVehicle.childVehicles
	local maxWidth = 0

	for i = 1, #childVehicles do
		local childVehicle = childVehicles[i]

		if SpecializationUtil.hasSpecialization(ExtendedSprayer, childVehicle.specializations) then
			if childVehicle.getWorkAreaByIndex ~= nil then
				local workAreas = childVehicle.spec_workArea.workAreas

				for j = 1, #workAreas do
					local workArea = workAreas[j]

					if workArea.start ~= nil and workArea.width ~= nil then
						local width = calcDistanceFrom(workArea.start, workArea.width)
						maxWidth = math.max(maxWidth, width)
						local x1, _, _ = localToLocal(workArea.start, sensorVehicle.rootNode, 0, 0, 0)
						local x2, _, _ = localToLocal(workArea.width, sensorVehicle.rootNode, 0, 0, 0)
						maxWidth = math.max(maxWidth, math.abs(x1) * 2, math.abs(x2) * 2)
					end
				end
			end

			if childVehicle.getAIMarkers ~= nil then
				local leftMarker, rightMarker, _, _ = childVehicle:getAIMarkers()

				if leftMarker ~= nil and rightMarker ~= nil then
					local width = calcDistanceFrom(leftMarker, rightMarker)
					maxWidth = math.max(maxWidth, width)
					local x1, _, _ = localToLocal(leftMarker, sensorVehicle.rootNode, 0, 0, 0)
					local x2, _, _ = localToLocal(rightMarker, sensorVehicle.rootNode, 0, 0, 0)
					maxWidth = math.max(maxWidth, math.abs(x1) * 2, math.abs(x2) * 2)
				end
			end
		end
	end

	return maxWidth
end
