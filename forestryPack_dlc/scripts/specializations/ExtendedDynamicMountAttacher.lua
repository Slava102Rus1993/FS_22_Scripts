local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

ExtendedDynamicMountAttacher = {
	MOD_NAME = g_currentModName,
	SPEC_NAME = g_currentModName .. ".ExtendedDynamicMountAttacher",
	prerequisitesPresent = function (specializations)
		return true
	end,
	initSpecialization = function ()
		local schema = Vehicle.xmlSchema

		schema:setXMLSpecializationType("ExtendedDynamicMountAttacher")
		schema:register(XMLValueType.BOOL, "vehicle.dynamicMountAttacher#limitToKnownObjects", "Only mount objects that are defined with a lockPosition", false)
		schema:register(XMLValueType.STRING, "vehicle.dynamicMountAttacher.lockPosition(?).configuration(?)#name", "Name of configuration")
		schema:register(XMLValueType.INT, "vehicle.dynamicMountAttacher.lockPosition(?).configuration(?)#index", "Configuration index that needs to match to use the lock position")
		schema:register(XMLValueType.FLOAT, "vehicle.dynamicMountAttacher.lockPosition(?)#width", "Width of lock position (if defined, collision to other vehicles is checked during locking)")
		schema:register(XMLValueType.FLOAT, "vehicle.dynamicMountAttacher.lockPosition(?)#length", "Length of lock position (if defined, collision to other vehicles is checked during locking)")
		schema:register(XMLValueType.FLOAT, "vehicle.dynamicMountAttacher.lockPosition(?)#height", "Height of lock position (if defined, collision to other vehicles is checked during locking)")
		schema:register(XMLValueType.BOOL, Cylindered.MOVING_TOOL_XML_KEY .. "#isAllowedWhileDynamicMounted", "Moving tool movement is allowed while something is mounted to the dynamic mount attacher", true)
		schema:setXMLSpecializationType()
	end
}

function ExtendedDynamicMountAttacher.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "dynamicMountLockPositionOverlapCallback", ExtendedDynamicMountAttacher.dynamicMountLockPositionOverlapCallback)
end

function ExtendedDynamicMountAttacher.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "addDynamicMountedObject", ExtendedDynamicMountAttacher.addDynamicMountedObject)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "removeDynamicMountedObject", ExtendedDynamicMountAttacher.removeDynamicMountedObject)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "dynamicMountTriggerCallback", ExtendedDynamicMountAttacher.dynamicMountTriggerCallback)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "loadMovingToolFromXML", ExtendedDynamicMountAttacher.loadMovingToolFromXML)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsMovingToolActive", ExtendedDynamicMountAttacher.getIsMovingToolActive)
end

function ExtendedDynamicMountAttacher.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", ExtendedDynamicMountAttacher)
end

function ExtendedDynamicMountAttacher:onLoad(savegame)
	local spec = self.spec_dynamicMountAttacher
	spec.limitToKnownObjects = self.xmlFile:getValue("vehicle.dynamicMountAttacher#limitToKnownObjects", false)

	for i = 1, #spec.lockPositions do
		local lockPosition = spec.lockPositions[i]
		local key = string.format("vehicle.dynamicMountAttacher.lockPosition(%d)", i - 1)

		if self.xmlFile:hasProperty(key) then
			lockPosition.configurations = {}

			self.xmlFile:iterate(key .. ".configuration", function (_, configKey)
				local name = self.xmlFile:getValue(configKey .. "#name")
				local index = self.xmlFile:getValue(configKey .. "#index")

				if name ~= nil and index ~= nil then
					lockPosition.configurations[name] = index
				end
			end)

			lockPosition.width = self.xmlFile:getValue(key .. "#width")
			lockPosition.length = self.xmlFile:getValue(key .. "#length")
			lockPosition.height = self.xmlFile:getValue(key .. "#height")
			lockPosition.state = false
		end
	end

	spec.overlapBoxHasCollision = false
	spec.overlapBoxIgnoreVehicle = nil
end

function ExtendedDynamicMountAttacher:dynamicMountLockPositionOverlapCallback(transformId)
	if g_currentMission.nodeToObject[transformId] ~= nil or g_currentMission.players[transformId] ~= nil then
		local spec = self.spec_dynamicMountAttacher

		if g_currentMission.nodeToObject[transformId] ~= self and g_currentMission.nodeToObject[transformId] ~= spec.overlapBoxIgnoreVehicle then
			spec.overlapBoxHasCollision = true
		end
	end
end

function ExtendedDynamicMountAttacher:addDynamicMountedObject(superFunc, object)
	local spec = self.spec_dynamicMountAttacher

	if spec.dynamicMountedObjects[object] == nil then
		spec.dynamicMountedObjects[object] = object
		local lockedToPosition = false

		if object.getMountableLockPositions ~= nil then
			local lockPositions = object:getMountableLockPositions()

			for i = 1, #lockPositions do
				local position = lockPositions[i]

				if string.endsWith(self.configFileName, position.xmlFilename) then
					local jointNode = I3DUtil.indexToObject(self.components, position.jointNode, self.i3dMappings)

					if jointNode ~= nil then
						local x, y, z = localToWorld(jointNode, position.transOffset[1], position.transOffset[2], position.transOffset[3])
						local rx, ry, rz = localRotationToWorld(jointNode, position.rotOffset[1], position.rotOffset[2], position.rotOffset[3])

						self:lockDynamicMountedObject(object, x, y, z, rx, ry, rz)

						lockedToPosition = true

						break
					end
				end
			end
		end

		if not lockedToPosition then
			local minDistancePosition = nil
			local minDistance = math.huge

			for i = 1, #spec.lockPositions do
				local position = spec.lockPositions[i]

				if not position.state and object.configFileName ~= nil and string.endsWith(object.configFileName, position.xmlFilename) then
					local foundVehicle = true

					if next(position.configurations) ~= nil then
						for configName, configIndex in pairs(position.configurations) do
							foundVehicle = foundVehicle and (object.configurations == nil or object.configurations[configName] == configIndex)
						end
					end

					if foundVehicle then
						local distance = calcDistanceFrom(position.jointNode, object.rootNode)

						if distance < minDistance then
							minDistance = distance
							minDistancePosition = position
						end
					end
				end
			end

			if minDistancePosition ~= nil and minDistancePosition.width ~= nil and minDistancePosition.length ~= nil and minDistancePosition.height ~= nil then
				local x, y, z = getWorldTranslation(minDistancePosition.jointNode)
				local rx, ry, rz = getWorldRotation(minDistancePosition.jointNode)
				spec.overlapBoxHasCollision = false
				spec.overlapBoxIgnoreVehicle = object

				overlapBox(x, y, z, rx, ry, rz, minDistancePosition.width * 0.5, minDistancePosition.height * 0.5, minDistancePosition.length * 0.5, "dynamicMountLockPositionOverlapCallback", self, 5468288, true, false, true, false)

				if spec.overlapBoxHasCollision then
					minDistancePosition = nil
				end

				spec.overlapBoxIgnoreVehicle = nil
			end

			if minDistancePosition ~= nil then
				local x, y, z = getWorldTranslation(minDistancePosition.jointNode)
				local rx, ry, rz = getWorldRotation(minDistancePosition.jointNode)

				self:lockDynamicMountedObject(object, x, y, z, rx, ry, rz)
				ObjectChangeUtil.setObjectChanges(minDistancePosition.objectChanges, true, self, self.setMovingToolDirty)

				minDistancePosition.state = true
				minDistancePosition.object = object
			end
		end

		for _, info in pairs(spec.dynamicMountCollisionMasks) do
			setCollisionMask(info.node, info.mountedCollisionMask)
		end

		if spec.transferMass and object.setReducedComponentMass ~= nil then
			object:setReducedComponentMass(true)
			self:setMassDirty()
		end

		self:setDynamicMountAnimationState(true)
		self:raiseDirtyFlags(spec.dynamicMountedObjectsDirtyFlag)
	end
end

function ExtendedDynamicMountAttacher:removeDynamicMountedObject(superFunc, object, isDeleting)
	local spec = self.spec_dynamicMountAttacher
	spec.dynamicMountedObjects[object] = nil

	if isDeleting then
		spec.pendingDynamicMountObjects[object] = nil
	end

	for i = 1, #spec.lockPositions do
		local position = spec.lockPositions[i]

		if position.state and position.object == object then
			ObjectChangeUtil.setObjectChanges(spec.lockPositions[i].objectChanges, false, self, self.setMovingToolDirty)

			position.state = false
			position.object = nil
		end
	end

	if next(spec.dynamicMountedObjects) == nil and next(spec.pendingDynamicMountObjects) == nil then
		for _, info in pairs(spec.dynamicMountCollisionMasks) do
			setCollisionMask(info.node, info.unmountedCollisionMask)
		end
	end

	if spec.transferMass then
		self:setMassDirty()
	end

	self:setDynamicMountAnimationState(false)
	self:raiseDirtyFlags(spec.dynamicMountedObjectsDirtyFlag)
end

function ExtendedDynamicMountAttacher:dynamicMountTriggerCallback(superFunc, triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	local spec = self.spec_dynamicMountAttacher

	if spec.limitToKnownObjects then
		local object = g_currentMission:getNodeObject(otherActorId)

		if object ~= nil then
			local foundVehicle = false

			for i = 1, #spec.lockPositions do
				local position = spec.lockPositions[i]

				if not position.state and object.configFileName ~= nil and string.endsWith(object.configFileName, position.xmlFilename) then
					foundVehicle = true

					if next(position.configurations) ~= nil then
						for configName, configIndex in pairs(position.configurations) do
							foundVehicle = foundVehicle and (object.configurations == nil or object.configurations[configName] == configIndex)
						end
					end

					if foundVehicle then
						break
					end
				end
			end

			if not foundVehicle then
				return
			end
		end
	end

	return superFunc(self, triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
end

function ExtendedDynamicMountAttacher:loadMovingToolFromXML(superFunc, xmlFile, key, entry)
	if not superFunc(self, xmlFile, key, entry) then
		return false
	end

	entry.isAllowedWhileDynamicMounted = xmlFile:getValue(key .. "#isAllowedWhileDynamicMounted", true)

	return true
end

function ExtendedDynamicMountAttacher:getIsMovingToolActive(superFunc, movingTool)
	if not movingTool.isAllowedWhileDynamicMounted then
		if next(self.spec_dynamicMountAttacher.dynamicMountedObjects) ~= nil then
			return false
		end

		if self.spec_tensionBelts ~= nil and next(self.spec_tensionBelts.objectsToJoint) ~= nil then
			return false
		end
	end

	return superFunc(self, movingTool)
end
