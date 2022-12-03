local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

ExtendedCylindered = {
	MOD_NAME = g_currentModName,
	SPEC_NAME = g_currentModName .. ".extendedCylindered",
	prerequisitesPresent = function (specializations)
		return true
	end
}

function ExtendedCylindered.initSpecialization()
	local schema = Vehicle.xmlSchema

	schema:setXMLSpecializationType("ExtendedCylindered")
	ExtendedCylindered.registerExtraXMLPaths(schema, Cylindered.MOVING_TOOL_XML_KEY)
	ExtendedCylindered.registerExtraXMLPaths(schema, Cylindered.MOVING_PART_XML_KEY)
	schema:setXMLSpecializationType()
end

function ExtendedCylindered.registerExtraXMLPaths(schema, baseKey)
	schema:register(XMLValueType.NODE_INDEX, baseKey .. ".dependentToolLimits#movingToolNode", "Node of movingTool")
	schema:register(XMLValueType.INT, baseKey .. ".dependentToolLimits#axis", "Reference rotation axis to use", 1)
	schema:register(XMLValueType.ANGLE, baseKey .. ".dependentToolLimits.limit(?)#rotation", "Reference rotation")
	schema:register(XMLValueType.ANGLE, baseKey .. ".dependentToolLimits.limit(?)#rotMin", "Min. rotation")
	schema:register(XMLValueType.ANGLE, baseKey .. ".dependentToolLimits.limit(?)#rotMax", "Max. rotation")
	schema:register(XMLValueType.FLOAT, baseKey .. ".dependentToolLimits.limit(?)#transMin", "Min. translation")
	schema:register(XMLValueType.FLOAT, baseKey .. ".dependentToolLimits.limit(?)#transMax", "Max. translation")
	schema:register(XMLValueType.NODE_INDEX, baseKey .. ".jointRotationOffsetAdjuster#jointNode", "Joint Node")
	schema:register(XMLValueType.NODE_INDEX, baseKey .. ".jointRotationOffsetAdjuster#nodeActor1", "Actor 1 Node")
	schema:register(XMLValueType.INT, baseKey .. ".jointRotationOffsetAdjuster#axis", "Reference axis", 1)
	schema:register(XMLValueType.INT, baseKey .. ".jointRotationOffsetAdjuster#direction", "Direction to adjust the moving tool node", -1)
	schema:register(XMLValueType.ANGLE, baseKey .. ".jointRotationOffsetAdjuster#threshold", "If this threshold is reached the rotation of the moving tool is adjusted", 25)
end

function ExtendedCylindered.registerFunctions(vehicleType)
end

function ExtendedCylindered.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "loadExtraDependentParts", ExtendedCylindered.loadExtraDependentParts)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "updateExtraDependentParts", ExtendedCylindered.updateExtraDependentParts)
end

function ExtendedCylindered.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", ExtendedCylindered)
end

function ExtendedCylindered:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	local spec = self.spec_cylindered

	for i = 1, #spec.movingTools do
		local movingTool = spec.movingTools[i]

		if movingTool.jointRotationOffsetAdjuster ~= nil and movingTool.rotSpeed ~= nil then
			local adjuster = movingTool.jointRotationOffsetAdjuster
			adjuster.rotationOffset[1], adjuster.rotationOffset[2], adjuster.rotationOffset[3] = localRotationToLocal(adjuster.jointNode, adjuster.nodeActor1, 0, 0, 0)
			local offset = adjuster.rotationOffset[adjuster.axis]

			if adjuster.threshold < math.abs(offset) and Cylindered.setToolRotation(self, movingTool, nil, 0, offset * 0.75 * adjuster.direction) then
				Cylindered.setDirty(self, movingTool)

				if movingTool.delayedNode ~= nil then
					self:updateDelayedTool(movingTool)
				end

				self:raiseDirtyFlags(movingTool.dirtyFlag)
				self:raiseDirtyFlags(self.spec_cylindered.cylinderedDirtyFlag)
			end
		end
	end
end

function ExtendedCylindered:loadExtraDependentParts(superFunc, xmlFile, baseName, entry)
	if not superFunc(self, xmlFile, baseName, entry) then
		return false
	end

	entry.dependentToolLimits = {
		node = xmlFile:getValue(baseName .. ".dependentToolLimits#movingToolNode", nil, self.components, self.i3dMappings)
	}

	if entry.dependentToolLimits.node ~= nil then
		entry.dependentToolLimits.axis = xmlFile:getValue(baseName .. ".dependentToolLimits#axis", 1)
		local curve = AnimCurve.new(Cylindered.limitInterpolator)
		local isValid = false

		self.xmlFile:iterate(baseName .. ".dependentToolLimits.limit", function (index, key)
			local rotation = xmlFile:getValue(key .. "#rotation")
			local rotMin = xmlFile:getValue(key .. "#rotMin")
			local rotMax = xmlFile:getValue(key .. "#rotMax")
			local transMin = xmlFile:getValue(key .. "#transMin")
			local transMax = xmlFile:getValue(key .. "#transMax")

			if rotation ~= nil and (rotMin ~= nil and rotMax ~= nil or transMin ~= nil and transMax ~= nil) then
				curve:addKeyframe({
					rotMin = rotMin,
					rotMax = rotMax,
					transMin = transMin,
					transMax = transMax,
					time = rotation
				})

				isValid = true
			end
		end)

		if isValid then
			entry.dependentToolLimits.rotation = {
				0,
				0,
				0
			}
			entry.dependentToolLimits.curve = curve
		else
			entry.dependentToolLimits = nil
		end
	else
		entry.dependentToolLimits = nil
	end

	entry.jointRotationOffsetAdjuster = {
		jointNode = xmlFile:getValue(baseName .. ".jointRotationOffsetAdjuster#jointNode", nil, self.components, self.i3dMappings),
		nodeActor1 = xmlFile:getValue(baseName .. ".jointRotationOffsetAdjuster#nodeActor1", nil, self.components, self.i3dMappings)
	}

	if entry.jointRotationOffsetAdjuster.jointNode ~= nil and entry.jointRotationOffsetAdjuster.nodeActor1 ~= nil then
		entry.jointRotationOffsetAdjuster.axis = xmlFile:getValue(baseName .. ".jointRotationOffsetAdjuster#axis", 1)
		entry.jointRotationOffsetAdjuster.direction = xmlFile:getValue(baseName .. ".jointRotationOffsetAdjuster#direction", -1)
		entry.jointRotationOffsetAdjuster.threshold = xmlFile:getValue(baseName .. ".jointRotationOffsetAdjuster#threshold", 25)
		entry.jointRotationOffsetAdjuster.rotationOffset = {
			0,
			0,
			0
		}
	else
		entry.jointRotationOffsetAdjuster = nil
	end

	return true
end

function ExtendedCylindered:updateExtraDependentParts(superFunc, part, dt)
	superFunc(self, part, dt)

	if part.dependentToolLimits ~= nil then
		local movingTool = self:getMovingToolByNode(part.dependentToolLimits.node)

		if movingTool ~= nil then
			local rotation = part.dependentToolLimits.rotation
			rotation[1], rotation[2], rotation[3] = getRotation(part.node)
			local minRot, maxRot, minTrans, maxTrans = part.dependentToolLimits.curve:get(rotation[part.dependentToolLimits.axis] or 0)

			if minRot ~= nil then
				movingTool.rotMin = minRot
			end

			if maxRot ~= nil then
				movingTool.rotMax = maxRot
			end

			if minTrans ~= nil then
				movingTool.transMin = minTrans
			end

			if maxTrans ~= nil then
				movingTool.transMax = maxTrans
			end

			local isDirty = false

			if minRot ~= nil or maxRot ~= nil then
				isDirty = isDirty or Cylindered.setToolRotation(self, movingTool, 0, 0)
			end

			if minTrans ~= nil or maxTrans ~= nil then
				isDirty = isDirty or Cylindered.setToolTranslation(self, movingTool, 0, 0)
			end

			if isDirty then
				Cylindered.setDirty(self, movingTool)
				self:raiseDirtyFlags(movingTool.dirtyFlag)
				self:raiseDirtyFlags(self.spec_cylindered.cylinderedDirtyFlag)
			end
		end
	end
end
