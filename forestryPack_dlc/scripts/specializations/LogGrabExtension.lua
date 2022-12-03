local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

LogGrabExtension = {
	GRAB_INDEX_NUM_BITS = 3,
	MOD_NAME = g_currentModName,
	SPEC_NAME = g_currentModName .. ".logGrabExtension"
}

source(g_currentModDirectory .. "scripts/specializations/events/LogGrabExtensionClawStateEvent.lua")

function LogGrabExtension.prerequisitesPresent(specializations)
	return true
end

function LogGrabExtension.initSpecialization()
	local schema = Vehicle.xmlSchema

	schema:setXMLSpecializationType("LogGrabExtension")
	schema:register(XMLValueType.NODE_INDEX, "vehicle.logGrab.grab(?)#jointNode", "Joint node")
	schema:register(XMLValueType.NODE_INDEX, "vehicle.logGrab.grab(?)#jointRoot", "Joint root node")
	schema:register(XMLValueType.BOOL, "vehicle.logGrab.grab(?)#lockAllAxis", "Lock all axis", false)
	schema:register(XMLValueType.BOOL, "vehicle.logGrab.grab(?)#limitYAxis", "Limit joint y axis movement (only allows movement up, but not down)", false)
	schema:register(XMLValueType.ANGLE, "vehicle.logGrab.grab(?)#rotLimit", "Defines the rotation limit on all axis", 10)
	schema:register(XMLValueType.BOOL, "vehicle.logGrab.grab(?)#unmountOnTreeCut", "Unmount trees while the wood harvester cuts the tree (only if the vehicle is a wood harvester as well)", false)
	schema:register(XMLValueType.NODE_INDEX, "vehicle.logGrab.grab(?).trigger#node", "Trigger node")
	schema:register(XMLValueType.INT, "vehicle.logGrab.grab(?).claw(?)#componentJoint", "Component joint index")
	schema:register(XMLValueType.FLOAT, "vehicle.logGrab.grab(?).claw(?)#dampingFactor", "Damping factor", 20)
	schema:register(XMLValueType.INT, "vehicle.logGrab.grab(?).claw(?)#axis", "Grab axis", 1)
	schema:register(XMLValueType.ANGLE, "vehicle.logGrab.grab(?).claw(?)#rotationOffsetThreshold", "Rotation offset threshold", 10)
	schema:register(XMLValueType.BOOL, "vehicle.logGrab.grab(?).claw(?)#rotationOffsetInverted", "Invert threshold", false)
	schema:register(XMLValueType.FLOAT, "vehicle.logGrab.grab(?).claw(?)#rotationOffsetTime", "Rotation offset time until mount", 1000)
	schema:register(XMLValueType.NODE_INDEX, "vehicle.logGrab.grab(?).claw(?).movingTool(?)#node", "Node of moving tool to block while limit is exceeded")
	schema:register(XMLValueType.FLOAT, "vehicle.logGrab.grab(?).claw(?).movingTool(?)#direction", "Direction to block the moving tool", 1)
	schema:register(XMLValueType.INT, "vehicle.logGrab.grab(?).claw(?).movingTool(?)#closeDirection", "Direction in which the grab is closed (if defined the trees are locked while fully closed)")
	schema:register(XMLValueType.STRING, "vehicle.logGrab.grab(?).clawAnimation#name", "Claw animation name")
	schema:register(XMLValueType.FLOAT, "vehicle.logGrab.grab(?).clawAnimation#speedScale", "Animation speed scale", 1)
	schema:register(XMLValueType.BOOL, "vehicle.logGrab.grab(?).clawAnimation#initialState", "Initial state of the grab (true: closed, false: open)", true)
	schema:register(XMLValueType.FLOAT, "vehicle.logGrab.grab(?).clawAnimation#lockTime", "Animation time when trees are locked", 1)
	schema:register(XMLValueType.STRING, "vehicle.logGrab.grab(?).clawAnimation#inputAction", "Input action to toggle animation", "IMPLEMENT_EXTRA2")
	schema:register(XMLValueType.INT, "vehicle.logGrab.grab(?).clawAnimation#controlGroupIndex", "Control group that needs to be active")
	schema:register(XMLValueType.L10N_STRING, "vehicle.logGrab.grab(?).clawAnimation#textPos", "Input text to open the claw", "action_foldBenchPos")
	schema:register(XMLValueType.L10N_STRING, "vehicle.logGrab.grab(?).clawAnimation#textNeg", "Input text to close the claw", "action_foldBenchNeg")
	schema:register(XMLValueType.FLOAT, "vehicle.logGrab.grab(?).clawAnimation#foldMinLimit", "Min. folding time to control claw", 0)
	schema:register(XMLValueType.FLOAT, "vehicle.logGrab.grab(?).clawAnimation#foldMaxLimit", "Max. folding time to control claw", 1)
	schema:register(XMLValueType.BOOL, "vehicle.logGrab.grab(?).clawAnimation#openDuringFolding", "Claw will be opened during folding", false)
	schema:register(XMLValueType.BOOL, "vehicle.logGrab.grab(?).clawAnimation#closeDuringFolding", "Claw will be closed during folding", false)
	schema:register(XMLValueType.STRING, "vehicle.logGrab.grab(?).lockAnimation#name", "Lock animation played while tree joints are created and revered while joints are removed")
	schema:register(XMLValueType.FLOAT, "vehicle.logGrab.grab(?).lockAnimation#speedScale", "Animation speed scale", 1)
	schema:register(XMLValueType.FLOAT, "vehicle.logGrab.grab(?).lockAnimation#unlockSpeedScale", "Animation speed scale while trees are unlocked", "negative #speedScale")
	schema:register(XMLValueType.NODE_INDEX, "vehicle.logGrab.grab(?).treeDetection#node", "Tree detection node")
	schema:register(XMLValueType.FLOAT, "vehicle.logGrab.grab(?).treeDetection#sizeY", "Tree detection node size y", 2)
	schema:register(XMLValueType.FLOAT, "vehicle.logGrab.grab(?).treeDetection#sizeZ", "Tree detection node size z", 2)
	schema:register(XMLValueType.INT, "vehicle.logGrab.grab(?).componentJointLimit(?)#jointIndex", "Index of component joint to change", 1)
	schema:register(XMLValueType.VECTOR_ROT, "vehicle.logGrab.grab(?).componentJointLimit(?)#limitActive", "Limit when tree is mounted")
	schema:register(XMLValueType.VECTOR_ROT, "vehicle.logGrab.grab(?).componentJointLimit(?)#limitInactive", "Limit when no tree is mounted")
	schema:register(XMLValueType.INT, "vehicle.logGrab.grab(?).componentJointMassSetting(?)#jointIndex", "Index of component joint to change", 1)
	schema:register(XMLValueType.FLOAT, "vehicle.logGrab.grab(?).componentJointMassSetting(?)#minMass", "Mass of mounted trees to use min defined value (t)", 0)
	schema:register(XMLValueType.FLOAT, "vehicle.logGrab.grab(?).componentJointMassSetting(?)#maxMass", "Mass of mounted trees to use max defined value (t)", 1)
	schema:register(XMLValueType.VECTOR_3, "vehicle.logGrab.grab(?).componentJointMassSetting(?)#minMaxRotDriveForce", "Max. rot drive force applied when the trees weight #minMass")
	schema:register(XMLValueType.VECTOR_3, "vehicle.logGrab.grab(?).componentJointMassSetting(?)#maxMaxRotDriveForce", "Max. rot drive force applied when the trees weight #maxMass")
	schema:setXMLSpecializationType()

	local schemaSavegame = Vehicle.xmlSchemaSavegame
	local key = "vehicles.vehicle(?)." .. LogGrabExtension.SPEC_NAME

	schemaSavegame:register(XMLValueType.BOOL, key .. ".grab(?)#state", "Grab claw state")
end

function LogGrabExtension.registerEvents(vehicleType)
	SpecializationUtil.registerEvent(vehicleType, "onLogGrabMountedTreesChanged")
end

function LogGrabExtension.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "logGrabTriggerCallback", LogGrabExtension.logGrabTriggerCallback)
	SpecializationUtil.registerFunction(vehicleType, "updateLogGrabClawState", LogGrabExtension.updateLogGrabClawState)
	SpecializationUtil.registerFunction(vehicleType, "mountSplitShape", LogGrabExtension.mountSplitShape)
	SpecializationUtil.registerFunction(vehicleType, "unmountSplitShape", LogGrabExtension.unmountSplitShape)
	SpecializationUtil.registerFunction(vehicleType, "getIsLogGrabClawStateChangeAllowed", LogGrabExtension.getIsLogGrabClawStateChangeAllowed)
	SpecializationUtil.registerFunction(vehicleType, "setLogGrabClawState", LogGrabExtension.setLogGrabClawState)
end

function LogGrabExtension.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "setComponentJointFrame", LogGrabExtension.setComponentJointFrame)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getMovingToolMoveValue", LogGrabExtension.getMovingToolMoveValue)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "onDelimbTree", LogGrabExtension.onDelimbTree)
end

function LogGrabExtension.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", LogGrabExtension)
	SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", LogGrabExtension)
	SpecializationUtil.registerEventListener(vehicleType, "onDelete", LogGrabExtension)
	SpecializationUtil.registerEventListener(vehicleType, "onReadStream", LogGrabExtension)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", LogGrabExtension)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", LogGrabExtension)
	SpecializationUtil.registerEventListener(vehicleType, "onCutTree", LogGrabExtension)
	SpecializationUtil.registerEventListener(vehicleType, "onTurnedOn", LogGrabExtension)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", LogGrabExtension)
	SpecializationUtil.registerEventListener(vehicleType, "onLogGrabMountedTreesChanged", LogGrabExtension)
	SpecializationUtil.registerEventListener(vehicleType, "onFoldStateChanged", LogGrabExtension)
	SpecializationUtil.registerEventListener(vehicleType, "onFoldTimeChanged", LogGrabExtension)
end

function LogGrabExtension:onLoad(savegame)
	self.spec_logGrabExtension = self["spec_" .. LogGrabExtension.SPEC_NAME]
	local spec = self.spec_logGrabExtension
	spec.grabs = {}

	self.xmlFile:iterate("vehicle.logGrab.grab", function (_, grabKey)
		local entry = {
			claws = {}
		}

		self.xmlFile:iterate(grabKey .. ".claw", function (_, clawKey)
			local clawData = {
				componentJoint = self.xmlFile:getValue(clawKey .. "#componentJoint"),
				dampingFactor = self.xmlFile:getValue(clawKey .. "#dampingFactor", 20),
				axis = self.xmlFile:getValue(clawKey .. "#axis", 1),
				direction = {
					0,
					0,
					0
				}
			}
			clawData.direction[clawData.axis] = 1
			local componentJoint = self.componentJoints[clawData.componentJoint]

			if componentJoint ~= nil then
				clawData.jointActor0 = componentJoint.jointNode
				clawData.jointActor1 = componentJoint.jointNodeActor1

				if componentJoint.jointNodeActor1 == componentJoint.jointNode then
					local actor1Reference = createTransformGroup("jointNodeActor1Reference")
					local component2 = self.components[componentJoint.componentIndices[2]]

					link(component2.node, actor1Reference)
					setWorldTranslation(actor1Reference, getWorldTranslation(componentJoint.jointNode))
					setWorldRotation(actor1Reference, getWorldRotation(componentJoint.jointNode))

					clawData.jointActor1 = actor1Reference
				end
			end

			clawData.rotationOffsetThreshold = self.xmlFile:getValue(clawKey .. "#rotationOffsetThreshold", 10)
			clawData.rotationOffsetInverted = self.xmlFile:getValue(clawKey .. "#rotationOffsetInverted", false)
			clawData.rotationOffsetTime = self.xmlFile:getValue(clawKey .. "#rotationOffsetTime", 1000)
			clawData.rotationOffsetTimer = 0
			clawData.rotationChangedTimer = 0
			clawData.currentOffset = 0
			clawData.lastClawState = false
			clawData.movingTools = {}

			self.xmlFile:iterate(clawKey .. ".movingTool", function (_, movingToolKey)
				local movingToolData = {
					node = self.xmlFile:getValue(movingToolKey .. "#node", nil, self.components, self.i3dMappings)
				}

				if movingToolData.node ~= nil then
					movingToolData.direction = self.xmlFile:getValue(movingToolKey .. "#direction", 1)
					movingToolData.closeDirection = self.xmlFile:getValue(movingToolKey .. "#closeDirection")

					table.insert(clawData.movingTools, movingToolData)
				end
			end)
			table.insert(entry.claws, clawData)
		end)

		entry.clawAnimation = {
			state = false,
			name = self.xmlFile:getValue(grabKey .. ".clawAnimation#name"),
			speedScale = self.xmlFile:getValue(grabKey .. ".clawAnimation#speedScale", 1),
			initialState = self.xmlFile:getValue(grabKey .. ".clawAnimation#initialState", true),
			lockTime = self.xmlFile:getValue(grabKey .. ".clawAnimation#lockTime", 1),
			inputAction = InputAction[self.xmlFile:getValue(grabKey .. ".clawAnimation#inputAction", "IMPLEMENT_EXTRA2")] or InputAction.IMPLEMENT_EXTRA2,
			controlGroupIndex = self.xmlFile:getValue(grabKey .. ".clawAnimation#controlGroupIndex"),
			textPos = self.xmlFile:getValue(grabKey .. ".clawAnimation#textPos", "action_foldBenchPos", self.customEnvironment, false),
			textNeg = self.xmlFile:getValue(grabKey .. ".clawAnimation#textNeg", "action_foldBenchNeg", self.customEnvironment, false),
			foldMinLimit = self.xmlFile:getValue(grabKey .. ".clawAnimation#foldMinLimit", 0),
			foldMaxLimit = self.xmlFile:getValue(grabKey .. ".clawAnimation#foldMaxLimit", 0),
			openDuringFolding = self.xmlFile:getValue(grabKey .. ".clawAnimation#openDuringFolding", false),
			closeDuringFolding = self.xmlFile:getValue(grabKey .. ".clawAnimation#closeDuringFolding", false)
		}
		entry.lockAnimation = {
			state = false,
			name = self.xmlFile:getValue(grabKey .. ".lockAnimation#name"),
			speedScale = self.xmlFile:getValue(grabKey .. ".lockAnimation#speedScale", 1)
		}
		entry.lockAnimation.unlockSpeedScale = self.xmlFile:getValue(grabKey .. ".lockAnimation#unlockSpeedScale", -entry.lockAnimation.speedScale)
		entry.jointNode = self.xmlFile:getValue(grabKey .. "#jointNode", nil, self.components, self.i3dMappings)
		entry.jointRoot = self.xmlFile:getValue(grabKey .. "#jointRoot", nil, self.components, self.i3dMappings)
		entry.lockAllAxis = self.xmlFile:getValue(grabKey .. "#lockAllAxis", false)
		entry.limitYAxis = self.xmlFile:getValue(grabKey .. "#limitYAxis", false)
		entry.rotLimit = self.xmlFile:getValue(grabKey .. "#rotLimit", 10)
		entry.unmountOnTreeCut = self.xmlFile:getValue(grabKey .. "#unmountOnTreeCut", false)
		entry.triggerNode = self.xmlFile:getValue(grabKey .. ".trigger#node", nil, self.components, self.i3dMappings)

		if entry.triggerNode ~= nil then
			addTrigger(entry.triggerNode, "logGrabTriggerCallback", self)
		end

		entry.pendingDynamicMountShapes = {}
		entry.dynamicMountedShapes = {}
		entry.jointLimitsOpen = false
		entry.treeDetectionNode = self.xmlFile:getValue(grabKey .. ".treeDetection#node", nil, self.components, self.i3dMappings)
		entry.treeDetectionNodeSizeY = self.xmlFile:getValue(grabKey .. ".treeDetection#sizeY", 2)
		entry.treeDetectionNodeSizeZ = self.xmlFile:getValue(grabKey .. ".treeDetection#sizeZ", 2)
		entry.componentJointLimits = {}

		self.xmlFile:iterate(grabKey .. ".componentJointLimit", function (_, limitKey)
			local componentJointLimit = {
				jointIndex = self.xmlFile:getValue(limitKey .. "#jointIndex")
			}

			if componentJointLimit.jointIndex ~= nil then
				componentJointLimit.joint = self.componentJoints[componentJointLimit.jointIndex]
				componentJointLimit.limitActive = self.xmlFile:getValue(limitKey .. "#limitActive", nil, true)
				componentJointLimit.limitInactive = self.xmlFile:getValue(limitKey .. "#limitInactive", nil, true)

				if componentJointLimit.joint ~= nil and componentJointLimit.limitActive ~= nil and componentJointLimit.limitInactive ~= nil then
					componentJointLimit.isActive = false

					table.insert(entry.componentJointLimits, componentJointLimit)
				end
			end
		end)

		entry.componentJointMassSettings = {}

		self.xmlFile:iterate(grabKey .. ".componentJointMassSetting", function (_, limitKey)
			local componentJointMassSetting = {
				jointIndex = self.xmlFile:getValue(limitKey .. "#jointIndex")
			}

			if componentJointMassSetting.jointIndex ~= nil then
				componentJointMassSetting.joint = self.componentJoints[componentJointMassSetting.jointIndex]
				componentJointMassSetting.minMass = self.xmlFile:getValue(limitKey .. "#minMass", 0)
				componentJointMassSetting.maxMass = self.xmlFile:getValue(limitKey .. "#maxMass", 1)
				componentJointMassSetting.minMaxRotDriveForce = self.xmlFile:getValue(limitKey .. "#minMaxRotDriveForce", nil, true)
				componentJointMassSetting.maxMaxRotDriveForce = self.xmlFile:getValue(limitKey .. "#maxMaxRotDriveForce", nil, true)
				componentJointMassSetting.maxRotDriveForce = {
					0,
					0,
					0
				}

				if componentJointMassSetting.joint ~= nil and componentJointMassSetting.minMaxRotDriveForce ~= nil and componentJointMassSetting.maxMaxRotDriveForce ~= nil then
					table.insert(entry.componentJointMassSettings, componentJointMassSetting)
				end
			end
		end)

		entry.componentLimitsDirty = false
		entry.lastGrabChangeTime = -math.huge

		table.insert(spec.grabs, entry)
	end)
end

function LogGrabExtension:onPostLoad(savegame)
	local spec = self.spec_logGrabExtension

	for i = 1, #spec.grabs do
		local grab = spec.grabs[i]

		if grab.clawAnimation.name ~= nil then
			local state = grab.clawAnimation.initialState

			if savegame ~= nil and not savegame.resetVehicles then
				local grabKey = savegame.key .. "." .. LogGrabExtension.SPEC_NAME .. string.format(".grab(%d)", i - 1)
				state = savegame.xmlFile:getValue(grabKey .. "#state", state)
			end

			if state then
				grab.clawAnimation.state = true

				self:playAnimation(grab.clawAnimation.name, 1, 0, true)
				AnimatedVehicle.updateAnimationByName(self, grab.clawAnimation.name, 9999999, true)
			end
		end

		for j = 1, #grab.claws do
			local clawData = grab.claws[j]

			for ti = #clawData.movingTools, 1, -1 do
				local movingToolData = clawData.movingTools[ti]
				movingToolData.movingTool = self:getMovingToolByNode(movingToolData.node)

				if movingToolData.movingTool == nil then
					table.remove(clawData.movingTools, ti)
				end
			end
		end
	end
end

function LogGrabExtension:onDelete()
	local spec = self.spec_logGrabExtension

	if spec.grabs ~= nil then
		for i = 1, #spec.grabs do
			local grab = spec.grabs[i]

			if grab.triggerNode ~= nil then
				removeTrigger(grab.triggerNode)
			end
		end
	end
end

function LogGrabExtension:saveToXMLFile(xmlFile, key, usedModNames)
	local spec = self.spec_logGrabExtension

	for i = 1, #spec.grabs do
		local grab = spec.grabs[i]

		if grab.clawAnimation.name ~= nil then
			local grabKey = key .. string.format(".grab(%d)", i - 1)

			xmlFile:setValue(grabKey .. "#state", grab.clawAnimation.state)
		end
	end
end

function LogGrabExtension:onReadStream(streamId, connection)
	local spec = self.spec_logGrabExtension

	for i = 1, #spec.grabs do
		local grab = spec.grabs[i]

		if grab.clawAnimation.name ~= nil then
			local state = streamReadBool(streamId)

			self:setLogGrabClawState(i, state, true)
		end
	end
end

function LogGrabExtension:onWriteStream(streamId, connection)
	local spec = self.spec_logGrabExtension

	for i = 1, #spec.grabs do
		local grab = spec.grabs[i]

		if grab.clawAnimation.name ~= nil then
			streamWriteBool(streamId, grab.clawAnimation.state)
		end
	end
end

function LogGrabExtension:onUpdateTick(dt)
	if self.isServer then
		local spec = self.spec_logGrabExtension

		for i = 1, #spec.grabs do
			local grab = spec.grabs[i]
			local isGrabClosed = true

			if grab.clawAnimation.name == nil then
				for j = 1, #grab.claws do
					local claw = grab.claws[j]
					local clawState = self:updateLogGrabClawState(claw, dt)

					if g_time - grab.lastGrabChangeTime > 2500 then
						clawState = claw.lastClawState
					end

					if grab.unmountOnTreeCut and self.spec_woodHarvester ~= nil and self.spec_woodHarvester.attachedSplitShape ~= nil then
						clawState = false
					end

					if not clawState then
						isGrabClosed = false
					end

					claw.lastClawState = clawState
				end
			elseif grab.clawAnimation.state then
				if self:getIsAnimationPlaying(grab.clawAnimation.name) then
					local clawsClosed = true

					for j = 1, #grab.claws do
						if not self:updateLogGrabClawState(grab.claws[j], dt, true) then
							clawsClosed = false
						end
					end

					if clawsClosed then
						self:stopAnimation(grab.clawAnimation.name)
					end
				end

				if self:getIsAnimationPlaying(grab.clawAnimation.name) and self:getAnimationTime(grab.clawAnimation.name) < grab.clawAnimation.lockTime then
					isGrabClosed = false
				end
			elseif self:getAnimationTime(grab.clawAnimation.name) < grab.clawAnimation.lockTime then
				isGrabClosed = false
			end

			for shape, _ in pairs(grab.pendingDynamicMountShapes) do
				if not entityExists(shape) then
					grab.pendingDynamicMountShapes[shape] = nil
				end
			end

			if isGrabClosed then
				for shape, _ in pairs(grab.pendingDynamicMountShapes) do
					if grab.dynamicMountedShapes[shape] == nil then
						local jointIndex, jointTransform = self:mountSplitShape(grab, shape)

						if jointIndex ~= nil then
							grab.dynamicMountedShapes[shape] = {
								jointIndex = jointIndex,
								jointTransform = jointTransform
							}
							grab.pendingDynamicMountShapes[shape] = nil
						end
					end
				end

				if not grab.jointLimitsOpen and next(grab.dynamicMountedShapes) ~= nil then
					grab.jointLimitsOpen = true

					for j = 1, #grab.claws do
						local claw = grab.claws[j]
						local componentJoint = self.componentJoints[claw.componentJoint]

						if componentJoint ~= nil then
							for axis = 1, 3 do
								setJointRotationLimitSpring(componentJoint.jointIndex, axis - 1, componentJoint.rotLimitSpring[axis], componentJoint.rotLimitDamping[axis] * claw.dampingFactor)
							end
						end
					end
				end
			else
				for shapeId, shapeData in pairs(grab.dynamicMountedShapes) do
					self:unmountSplitShape(grab, shapeId, shapeData.jointIndex, shapeData.jointTransform, false)
				end

				if grab.jointLimitsOpen then
					grab.jointLimitsOpen = false

					for j = 1, #grab.claws do
						local claw = grab.claws[j]
						local componentJoint = self.componentJoints[claw.componentJoint]

						if componentJoint ~= nil then
							for axis = 1, 3 do
								setJointRotationLimitSpring(componentJoint.jointIndex, axis - 1, componentJoint.rotLimitSpring[axis], componentJoint.rotLimitDamping[axis])
							end
						end
					end
				end
			end

			if grab.lockAnimation.name ~= nil then
				local state = isGrabClosed and next(grab.dynamicMountedShapes) ~= nil

				if state ~= grab.lockAnimation.state then
					grab.lockAnimation.state = state

					if state then
						self:playAnimation(grab.lockAnimation.name, grab.lockAnimation.speedScale, self:getAnimationTime(grab.lockAnimation.name))
					else
						self:playAnimation(grab.lockAnimation.name, grab.lockAnimation.unlockSpeedScale, self:getAnimationTime(grab.lockAnimation.name))
					end
				end
			end

			local clawAnimationRunning = grab.clawAnimation.name ~= nil and self:getIsAnimationPlaying(grab.clawAnimation.name)

			if grab.componentLimitsDirty or clawAnimationRunning then
				local isActive = next(grab.dynamicMountedShapes) ~= nil

				for j = 1, #grab.componentJointLimits do
					local componentJointLimit = grab.componentJointLimits[j]

					if componentJointLimit.isActive ~= isActive or clawAnimationRunning then
						componentJointLimit.isActive = isActive
						local alpha = next(grab.dynamicMountedShapes) ~= nil and 0 or 1

						if grab.clawAnimation.name ~= nil and (next(grab.dynamicMountedShapes) ~= nil or next(grab.pendingDynamicMountShapes)) then
							alpha = 1 - self:getAnimationTime(grab.clawAnimation.name)
						end

						local x, y, z = MathUtil.vector3Lerp(componentJointLimit.limitActive[1], componentJointLimit.limitActive[2], componentJointLimit.limitActive[3], componentJointLimit.limitInactive[1], componentJointLimit.limitInactive[2], componentJointLimit.limitInactive[3], alpha)

						self:setComponentJointRotLimit(componentJointLimit.joint, 0, -x, x)
						self:setComponentJointRotLimit(componentJointLimit.joint, 1, -y, y)
						self:setComponentJointRotLimit(componentJointLimit.joint, 2, -z, z)
					end
				end

				grab.componentLimitsDirty = false
			end
		end
	end
end

function LogGrabExtension:updateLogGrabClawState(claw, dt, ignoreTiming)
	local componentJoint = self.componentJoints[claw.componentJoint]

	if componentJoint ~= nil then
		local xOff, yOff, zOff = localRotationToLocal(claw.jointActor1, claw.jointActor0, 0, 0, 0)
		local currentOffset = 0

		if claw.axis == 1 then
			currentOffset = xOff
		elseif claw.axis == 2 then
			currentOffset = yOff
		elseif claw.axis == 3 then
			currentOffset = zOff
		end

		if claw.rotationOffsetInverted then
			currentOffset = -currentOffset
		end

		local fullyClosed = true
		local hasCloseDirectionDefined = false

		for ti = 1, #claw.movingTools do
			local movingToolData = claw.movingTools[ti]

			if movingToolData.closeDirection then
				local state = Cylindered.getMovingToolState(self, movingToolData.movingTool)

				if movingToolData.closeDirection > 0 then
					fullyClosed = fullyClosed and state > 0.99
				else
					fullyClosed = fullyClosed and state < 0.01
				end

				hasCloseDirectionDefined = true
			end
		end

		local grabClosed = claw.rotationOffsetThreshold < currentOffset
		grabClosed = grabClosed or hasCloseDirectionDefined and fullyClosed
		local x, y, z = getRotation(componentJoint.jointNode)
		local rotSum = x + y + z

		if grabClosed then
			claw.lastRotation = rotSum

			if claw.rotationOffsetTime < claw.rotationOffsetTimer or ignoreTiming then
				return true
			else
				claw.rotationOffsetTimer = claw.rotationOffsetTimer + dt
			end
		elseif claw.rotationOffsetTimer > 0 and not ignoreTiming then
			if claw.lastRotation ~= nil and rotSum ~= claw.lastRotation then
				claw.rotationOffsetTimer = 0
				claw.rotationChangedTimer = 750
				claw.lastRotation = nil
			else
				claw.rotationChangedTimer = math.max(claw.rotationChangedTimer - dt, 0)

				if claw.rotationChangedTimer <= 0 then
					claw.lastRotation = rotSum

					return true
				end
			end
		end

		claw.currentOffset = currentOffset
	end

	return false
end

function LogGrabExtension:onCutTree(radius, isNewTree)
	if self.isServer and radius > 0 and isNewTree then
		local spec = self.spec_logGrabExtension

		for i = 1, #spec.grabs do
			if self:getIsLogGrabClawStateChangeAllowed(i) then
				self:setLogGrabClawState(i, true)
			end
		end
	end
end

function LogGrabExtension:onTurnedOn()
	if self.isServer then
		local spec = self.spec_logGrabExtension

		for i = 1, #spec.grabs do
			if self:getIsLogGrabClawStateChangeAllowed(i) then
				self:setLogGrabClawState(i, false)
			end
		end
	end
end

function LogGrabExtension:onTurnedOff()
	if self.isServer then
		local spec = self.spec_logGrabExtension

		for i = 1, #spec.grabs do
			if self:getIsLogGrabClawStateChangeAllowed(i) then
				self:setLogGrabClawState(i, true)
			end
		end
	end
end

function LogGrabExtension:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	if self.isClient then
		local spec = self.spec_logGrabExtension

		self:clearActionEventsTable(spec.actionEvents)

		if isActiveForInputIgnoreSelection then
			for i = 1, #spec.grabs do
				local grab = spec.grabs[i]

				if grab.clawAnimation.name ~= nil and (grab.clawAnimation.controlGroupIndex == nil or self.spec_cylindered == nil or self.spec_cylindered.currentControlGroupIndex == grab.clawAnimation.controlGroupIndex) then
					local _, actionEventId = self:addPoweredActionEvent(spec.actionEvents, grab.clawAnimation.inputAction, self, LogGrabExtension.actionEventClawAnimation, false, true, false, true, i)

					g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)
					LogGrabExtension.updateActionEvents(self)
				end
			end
		end
	end
end

function LogGrabExtension:actionEventClawAnimation(actionName, inputValue, callbackState, isAnalog)
	if self:getIsLogGrabClawStateChangeAllowed(callbackState) then
		self:setLogGrabClawState(callbackState, nil)
	end
end

function LogGrabExtension:updateActionEvents()
	local spec = self.spec_logGrabExtension

	for i = 1, #spec.grabs do
		local grab = spec.grabs[i]
		local actionEvent = spec.actionEvents[grab.clawAnimation.inputAction]

		if actionEvent ~= nil then
			g_inputBinding:setActionEventText(actionEvent.actionEventId, grab.clawAnimation.state and grab.clawAnimation.textNeg or grab.clawAnimation.textPos)
			g_inputBinding:setActionEventActive(actionEvent.actionEventId, self:getIsLogGrabClawStateChangeAllowed(i))
		end
	end
end

function LogGrabExtension:setComponentJointFrame(superFunc, jointDesc, anchorActor)
	superFunc(self, jointDesc, anchorActor)

	local spec = self.spec_logGrabExtension

	for i = 1, #spec.grabs do
		local grab = spec.grabs[i]

		for j = 1, #grab.claws do
			local claw = grab.claws[j]
			local componentJoint = self.componentJoints[claw.componentJoint]

			if jointDesc == componentJoint then
				grab.lastGrabChangeTime = g_time
			end
		end
	end
end

function LogGrabExtension:getMovingToolMoveValue(superFunc, movingTool)
	local move = superFunc(self, movingTool)
	local spec = self.spec_logGrabExtension

	for i = 1, #spec.grabs do
		local grab = spec.grabs[i]

		for j = 1, #grab.claws do
			local claw = grab.claws[j]

			for ti = 1, #claw.movingTools do
				local movingToolData = claw.movingTools[ti]

				if movingToolData.movingTool == movingTool and claw.rotationOffsetThreshold < claw.currentOffset and MathUtil.sign(move) == movingToolData.direction then
					move = 0
				end
			end
		end
	end

	return move
end

function LogGrabExtension:onDelimbTree(superFunc, state, ...)
	local spec = self.spec_logGrabExtension

	for i = 1, #spec.grabs do
		if spec.grabs[i].clawAnimation.state then
			self:setLogGrabClawState(i, false, true)
		end
	end

	return superFunc(self, state, ...)
end

function LogGrabExtension:mountSplitShape(grab, shapeId)
	local constr = JointConstructor.new()

	constr:setActors(grab.jointRoot, shapeId)

	local jointTransform = createTransformGroup("dynamicMountJoint")
	local cx, cy, cz = getWorldTranslation(grab.treeDetectionNode)
	local nx, ny, nz = localDirectionToWorld(grab.treeDetectionNode, 1, 0, 0)
	local yx, yy, yz = localDirectionToWorld(grab.treeDetectionNode, 0, 1, 0)
	local minY, maxY, minZ, maxZ = testSplitShape(shapeId, cx, cy, cz, nx, ny, nz, yx, yy, yz, grab.treeDetectionNodeSizeY, grab.treeDetectionNodeSizeZ)

	if minY ~= nil then
		link(grab.jointNode, jointTransform)

		local x, y, z = localToWorld(grab.treeDetectionNode, 0, (minY + maxY) * 0.5, (minZ + maxZ) * 0.5)

		setWorldTranslation(jointTransform, x, y, z)
		constr:setRotationLimit(0, -grab.rotLimit, grab.rotLimit)
		constr:setRotationLimit(1, -grab.rotLimit, grab.rotLimit)
		constr:setRotationLimit(2, -grab.rotLimit, grab.rotLimit)
	else
		link(grab.jointNode, jointTransform)
		setTranslation(jointTransform, 0, 0, 0)
		constr:setRotationLimit(0, 0, 0)
		constr:setRotationLimit(1, 0, 0)
		constr:setRotationLimit(2, 0, 0)
	end

	constr:setJointTransforms(jointTransform, jointTransform)

	if not grab.lockAllAxis then
		if grab.limitYAxis then
			constr:setTranslationLimit(1, true, -0.1, 2)
			constr:setTranslationLimit(2, false, 0, 0)
		else
			constr:setTranslationLimit(1, false, 0, 0)
			constr:setTranslationLimit(2, false, 0, 0)
		end

		constr:setEnableCollision(true)
	end

	local springForce = 7500
	local springDamping = 1500

	constr:setRotationLimitSpring(springForce, springDamping, springForce, springDamping, springForce, springDamping)
	constr:setTranslationLimitSpring(springForce, springDamping, springForce, springDamping, springForce, springDamping)

	grab.componentLimitsDirty = true

	g_messageCenter:publish(MessageType.TREE_SHAPE_MOUNTED, shapeId, self)
	SpecializationUtil.raiseEvent(self, "onLogGrabMountedTreesChanged", grab)

	return constr:finalize(), jointTransform
end

function LogGrabExtension:unmountSplitShape(grab, shapeId, jointIndex, jointTransform, isDeleting)
	removeJoint(jointIndex)
	delete(jointTransform)

	grab.dynamicMountedShapes[shapeId] = nil

	if isDeleting ~= nil and isDeleting then
		grab.pendingDynamicMountShapes[shapeId] = nil
	else
		grab.pendingDynamicMountShapes[shapeId] = true
	end

	grab.componentLimitsDirty = true

	SpecializationUtil.raiseEvent(self, "onLogGrabMountedTreesChanged", grab)
end

function LogGrabExtension:onLogGrabMountedTreesChanged(grab)
	if self.isServer then
		local mass = 0

		for shapeId, _ in pairs(grab.dynamicMountedShapes) do
			if entityExists(shapeId) then
				mass = mass + getMass(shapeId)
			end
		end

		for i = 1, #grab.componentJointMassSettings do
			local setting = grab.componentJointMassSettings[i]
			local alpha = MathUtil.inverseLerp(setting.minMass, setting.maxMass, mass)
			setting.maxRotDriveForce[1], setting.maxRotDriveForce[1], setting.maxRotDriveForce[3] = MathUtil.vector3ArrayLerp(setting.minMaxRotDriveForce, setting.maxMaxRotDriveForce, alpha)
			local jointDesc = setting.joint

			for axis = 1, 3 do
				local pos = jointDesc.rotDriveRotation[axis] or 0
				local vel = jointDesc.rotDriveVelocity[axis] or 0

				setJointAngularDrive(jointDesc.jointIndex, axis - 1, jointDesc.rotDriveRotation[axis] ~= nil, jointDesc.rotDriveVelocity[axis] ~= nil, jointDesc.rotDriveSpring[axis], jointDesc.rotDriveDamping[axis], setting.maxRotDriveForce[axis], pos, vel)
			end
		end
	end
end

function LogGrabExtension:onFoldStateChanged(direction, moveToMiddle)
	local spec = self.spec_logGrabExtension

	for i = 1, #spec.grabs do
		local grab = spec.grabs[i]

		if grab.clawAnimation.openDuringFolding then
			if direction ~= self.spec_foldable.turnOnFoldDirection then
				self:setLogGrabClawState(i, false, true)
			end
		elseif grab.clawAnimation.closeDuringFolding and direction ~= self.spec_foldable.turnOnFoldDirection then
			self:setLogGrabClawState(i, true, true)
		end
	end
end

function LogGrabExtension:onFoldTimeChanged(time)
	LogGrabExtension.updateActionEvents(self)
end

function LogGrabExtension:getIsLogGrabClawStateChangeAllowed(grabIndex)
	local spec = self.spec_logGrabExtension
	local grab = spec.grabs[grabIndex]

	if grab ~= nil and self.getFoldAnimTime ~= nil then
		local t = self:getFoldAnimTime()

		if t < grab.clawAnimation.foldMinLimit or grab.clawAnimation.foldMaxLimit < t then
			return false
		end
	end

	return true
end

function LogGrabExtension:setLogGrabClawState(grabIndex, state, noEventSend)
	local spec = self.spec_logGrabExtension
	local grab = spec.grabs[grabIndex]

	if grab ~= nil then
		if state == nil then
			state = not grab.clawAnimation.state
		end

		grab.clawAnimation.state = state

		self:playAnimation(grab.clawAnimation.name, grab.clawAnimation.state and grab.clawAnimation.speedScale or -grab.clawAnimation.speedScale, self:getAnimationTime(grab.clawAnimation.name), true)
	end

	LogGrabExtension.updateActionEvents(self)
	LogGrabExtensionClawStateEvent.sendEvent(self, state, grabIndex, noEventSend)
end

function LogGrabExtension:logGrabTriggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	local spec = self.spec_logGrabExtension

	for i = 1, #spec.grabs do
		local grab = spec.grabs[i]

		if grab.triggerNode == triggerId then
			if onEnter then
				if getSplitType(otherActorId) ~= 0 then
					local rigidBodyType = getRigidBodyType(otherActorId)

					if (rigidBodyType == RigidBodyType.DYNAMIC or rigidBodyType == RigidBodyType.KINEMATIC) and grab.pendingDynamicMountShapes[otherActorId] == nil then
						grab.pendingDynamicMountShapes[otherActorId] = true
					end
				end
			elseif onLeave and getSplitType(otherActorId) ~= 0 then
				if grab.pendingDynamicMountShapes[otherActorId] ~= nil then
					grab.pendingDynamicMountShapes[otherActorId] = nil
				elseif grab.dynamicMountedShapes[otherActorId] ~= nil then
					self:unmountSplitShape(grab, otherActorId, grab.dynamicMountedShapes[otherActorId].jointIndex, grab.dynamicMountedShapes[otherActorId].jointTransform, true)
				end
			end
		end
	end
end

function LogGrabExtension:addNodeObjectMapping(superFunc, list)
	superFunc(self, list)

	local spec = self.spec_logGrabExtension

	for i = 1, #spec.grabs do
		local grab = spec.grabs[i]

		if grab.triggerNode ~= nil then
			list[grab.triggerNode] = self
		end
	end
end

function LogGrabExtension:removeNodeObjectMapping(superFunc, list)
	superFunc(self, list)

	local spec = self.spec_logGrabExtension

	for i = 1, #spec.grabs do
		local grab = spec.grabs[i]

		if grab.triggerNode ~= nil then
			list[grab.triggerNode] = nil
		end
	end
end

function LogGrabExtension:updateDebugValues(values)
	if self.isServer then
		local spec = self.spec_logGrabExtension

		for i = 1, #spec.grabs do
			local grab = spec.grabs[i]

			for j, claw in ipairs(grab.claws) do
				table.insert(values, {
					name = string.format("grab (%d) claw (%d):", i, j),
					value = string.format("current: %.2fdeg / threshold: %.2fdeg  (timer: %d)", math.deg(claw.currentOffset), math.deg(claw.rotationOffsetThreshold), claw.rotationOffsetTimer)
				})
			end

			for shapeId, _ in pairs(grab.dynamicMountedShapes) do
				if entityExists(shapeId) then
					table.insert(values, {
						name = string.format("grab (%d) mounted:", i),
						value = string.format("%s - %d", getName(shapeId), shapeId)
					})
				end
			end

			for shapeId, _ in pairs(grab.pendingDynamicMountShapes) do
				if entityExists(shapeId) then
					table.insert(values, {
						name = string.format("grab (%d) pending:", i),
						value = string.format("%s - %d", getName(shapeId), shapeId)
					})
				end
			end
		end
	end
end
