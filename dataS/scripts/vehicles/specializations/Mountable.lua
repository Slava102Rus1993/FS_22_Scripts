Mountable = {
	prerequisitesPresent = function (specializations)
		return true
	end,
	initSpecialization = function ()
		local schema = Vehicle.xmlSchema

		schema:setXMLSpecializationType("Mountable")
		schema:register(XMLValueType.FLOAT, "vehicle.dynamicMount#forceLimitScale", "Force limit scale", 1)
		schema:register(XMLValueType.NODE_INDEX, "vehicle.dynamicMount#triggerNode", "Trigger node")
		schema:register(XMLValueType.NODE_INDEX, "vehicle.dynamicMount#jointNode", "Joint node")
		schema:register(XMLValueType.FLOAT, "vehicle.dynamicMount#triggerForceAcceleration", "Trigger force acceleration", 4)
		schema:register(XMLValueType.BOOL, "vehicle.dynamicMount#singleAxisFreeY", "Single axis free Y")
		schema:register(XMLValueType.BOOL, "vehicle.dynamicMount#singleAxisFreeX", "Single axis free X")
		schema:register(XMLValueType.FLOAT, "vehicle.dynamicMount#jointTransY", "Fixed Y translation of local placed joint", "not defined")
		schema:register(XMLValueType.BOOL, "vehicle.dynamicMount#jointLimitToRotY", "Local placed joint will only be adjusted on Y axis to the target mounter object. X and Z will be 0.", false)
		schema:register(XMLValueType.FLOAT, "vehicle.dynamicMount#additionalMountDistance", "Distance from root node to the object laying on top (normally height of object). If defined the mass of this object has influence in mounting.", 0)
		schema:register(XMLValueType.BOOL, "vehicle.dynamicMount#allowMassReduction", "Defines if mass can be reduced by the mount vehicle", true)
		schema:register(XMLValueType.STRING, "vehicle.dynamicMount.lockPosition(?)#xmlFilename", "XML filename of vehicle to lock on (needs to match only the end of the filename)")
		schema:register(XMLValueType.STRING, "vehicle.dynamicMount.lockPosition(?)#jointNode", "Joint node of other vehicle (path or i3dMapping name)", "vehicle root node")
		schema:register(XMLValueType.VECTOR_TRANS, "vehicle.dynamicMount.lockPosition(?)#transOffset", "Translation offset from joint node", "0 0 0")
		schema:register(XMLValueType.VECTOR_ROT, "vehicle.dynamicMount.lockPosition(?)#rotOffset", "Rotation offset from joint node", "0 0 0")
		schema:setXMLSpecializationType()
	end
}

function Mountable.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "getSupportsMountDynamic", Mountable.getSupportsMountDynamic)
	SpecializationUtil.registerFunction(vehicleType, "getSupportsMountKinematic", Mountable.getSupportsMountKinematic)
	SpecializationUtil.registerFunction(vehicleType, "onDynamicMountJointBreak", Mountable.onDynamicMountJointBreak)
	SpecializationUtil.registerFunction(vehicleType, "mountableTriggerCallback", Mountable.mountableTriggerCallback)
	SpecializationUtil.registerFunction(vehicleType, "mount", Mountable.mount)
	SpecializationUtil.registerFunction(vehicleType, "unmount", Mountable.unmount)
	SpecializationUtil.registerFunction(vehicleType, "mountKinematic", Mountable.mountKinematic)
	SpecializationUtil.registerFunction(vehicleType, "unmountKinematic", Mountable.unmountKinematic)
	SpecializationUtil.registerFunction(vehicleType, "mountDynamic", Mountable.mountDynamic)
	SpecializationUtil.registerFunction(vehicleType, "unmountDynamic", Mountable.unmountDynamic)
	SpecializationUtil.registerFunction(vehicleType, "getAdditionalMountingDistance", Mountable.getAdditionalMountingDistance)
	SpecializationUtil.registerFunction(vehicleType, "getAdditionalMountingMass", Mountable.getAdditionalMountingMass)
	SpecializationUtil.registerFunction(vehicleType, "additionalMountingMassRaycastCallback", Mountable.additionalMountingMassRaycastCallback)
	SpecializationUtil.registerFunction(vehicleType, "getMountObject", Mountable.getMountObject)
	SpecializationUtil.registerFunction(vehicleType, "getDynamicMountObject", Mountable.getDynamicMountObject)
	SpecializationUtil.registerFunction(vehicleType, "setReducedComponentMass", Mountable.setReducedComponentMass)
	SpecializationUtil.registerFunction(vehicleType, "getAllowComponentMassReduction", Mountable.getAllowComponentMassReduction)
	SpecializationUtil.registerFunction(vehicleType, "getDefaultAllowComponentMassReduction", Mountable.getDefaultAllowComponentMassReduction)
	SpecializationUtil.registerFunction(vehicleType, "getMountableLockPositions", Mountable.getMountableLockPositions)
end

function Mountable.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsActive", Mountable.getIsActive)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getOwner", Mountable.getOwner)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "findRootVehicle", Mountable.findRootVehicle)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsMapHotspotVisible", Mountable.getIsMapHotspotVisible)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getAdditionalComponentMass", Mountable.getAdditionalComponentMass)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "setWorldPositionQuaternion", Mountable.setWorldPositionQuaternion)
end

function Mountable.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", Mountable)
	SpecializationUtil.registerEventListener(vehicleType, "onDelete", Mountable)
	SpecializationUtil.registerEventListener(vehicleType, "onEnterVehicle", Mountable)
	SpecializationUtil.registerEventListener(vehicleType, "onPreAttach", Mountable)
end

function Mountable:onLoad(savegame)
	local spec = self.spec_mountable

	XMLUtil.checkDeprecatedXMLElements(self.xmlFile, "vehicle.dynamicMount#triggerIndex", "vehicle.dynamicMount#triggerNode")

	spec.dynamicMountJointIndex = nil
	spec.dynamicMountObject = nil
	spec.dynamicMountObjectActorId = nil
	spec.dynamicMountForceLimitScale = self.xmlFile:getValue("vehicle.dynamicMount#forceLimitScale", 1)
	spec.mountObject = nil
	spec.componentNode = self.rootNode
	spec.dynamicMountTriggerId = self.xmlFile:getValue("vehicle.dynamicMount#triggerNode", nil, self.components, self.i3dMappings)

	if spec.dynamicMountTriggerId ~= nil then
		if self.isServer then
			addTrigger(spec.dynamicMountTriggerId, "mountableTriggerCallback", self)
		end

		spec.componentNode = self:getParentComponent(spec.dynamicMountTriggerId)

		if spec.dynamicMountJointNodeDynamic == nil then
			spec.dynamicMountJointNodeDynamic = createTransformGroup("dynamicMountJointNodeDynamic")

			link(spec.componentNode, spec.dynamicMountJointNodeDynamic)
		end

		spec.dynamicMountJointTransY = self.xmlFile:getValue("vehicle.dynamicMount#jointTransY")
		spec.dynamicMountJointLimitToRotY = self.xmlFile:getValue("vehicle.dynamicMount#jointLimitToRotY", false)
	end

	spec.jointNode = self.xmlFile:getValue("vehicle.dynamicMount#jointNode", nil, self.components, self.i3dMappings)
	spec.dynamicMountTriggerForceAcceleration = self.xmlFile:getValue("vehicle.dynamicMount#triggerForceAcceleration", 4)
	spec.dynamicMountSingleAxisFreeY = self.xmlFile:getValue("vehicle.dynamicMount#singleAxisFreeY")
	spec.dynamicMountSingleAxisFreeX = self.xmlFile:getValue("vehicle.dynamicMount#singleAxisFreeX")
	spec.additionalMountDistance = self.xmlFile:getValue("vehicle.dynamicMount#additionalMountDistance", 0)
	spec.allowMassReduction = self.xmlFile:getValue("vehicle.dynamicMount#allowMassReduction", self:getDefaultAllowComponentMassReduction())
	spec.reducedComponentMass = false
	spec.lockPositions = {}

	self.xmlFile:iterate("vehicle.dynamicMount.lockPosition", function (index, key)
		local entry = {
			xmlFilename = self.xmlFile:getValue(key .. "#xmlFilename"),
			jointNode = self.xmlFile:getValue(key .. "#jointNode", "0>")
		}

		if entry.xmlFilename ~= nil and entry.jointNode ~= nil then
			entry.xmlFilename = entry.xmlFilename:gsub("$data", "data")
			entry.transOffset = self.xmlFile:getValue(key .. "#transOffset", "0 0 0", true)
			entry.rotOffset = self.xmlFile:getValue(key .. "#rotOffset", "0 0 0", true)

			table.insert(spec.lockPositions, entry)
		else
			Logging.xmlWarning(self.xmlFile, "Invalid lock position '%s'. Missing xmlFilename or jointNode!", key)
		end
	end)
end

function Mountable:onDelete()
	local spec = self.spec_mountable

	if spec.dynamicMountJointIndex ~= nil then
		removeJointBreakReport(spec.dynamicMountJointIndex)
		removeJoint(spec.dynamicMountJointIndex)
	end

	if spec.dynamicMountObject ~= nil then
		spec.dynamicMountObject:removeDynamicMountedObject(self, true)
	end

	if spec.dynamicMountTriggerId ~= nil then
		removeTrigger(spec.dynamicMountTriggerId)
	end
end

function Mountable:getSupportsMountDynamic()
	local spec = self.spec_mountable

	return spec.dynamicMountForceLimitScale ~= nil
end

function Mountable:getSupportsMountKinematic()
	return #self.components == 1
end

function Mountable:onDynamicMountJointBreak(jointIndex, breakingImpulse)
	local spec = self.spec_mountable

	if jointIndex == spec.dynamicMountJointIndex then
		self:unmountDynamic()
	end

	return false
end

function Mountable:mountableTriggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	local spec = self.spec_mountable

	if onEnter then
		if spec.mountObject == nil then
			local vehicle = g_currentMission.nodeToObject[otherActorId]

			if vehicle ~= nil and vehicle.spec_dynamicMountAttacher ~= nil then
				local dynamicMountAttacher = vehicle.spec_dynamicMountAttacher

				if dynamicMountAttacher ~= nil and dynamicMountAttacher.dynamicMountAttacherNode ~= nil then
					if spec.dynamicMountObjectActorId == nil then
						self:mountDynamic(vehicle, otherActorId, dynamicMountAttacher.dynamicMountAttacherNode, DynamicMountUtil.TYPE_FORK, spec.dynamicMountTriggerForceAcceleration * dynamicMountAttacher.dynamicMountAttacherForceLimitScale)

						spec.dynamicMountObjectTriggerCount = 1
					elseif otherActorId ~= spec.dynamicMountObjectActorId and spec.dynamicMountObjectTriggerCount == nil then
						self:unmountDynamic()
						self:mountDynamic(vehicle, otherActorId, dynamicMountAttacher.dynamicMountAttacherNode, DynamicMountUtil.TYPE_FORK, spec.dynamicMountTriggerForceAcceleration * dynamicMountAttacher.dynamicMountAttacherForceLimitScale)

						spec.dynamicMountObjectTriggerCount = 1
					elseif otherActorId == spec.dynamicMountObjectActorId and spec.dynamicMountObjectTriggerCount ~= nil then
						spec.dynamicMountObjectTriggerCount = spec.dynamicMountObjectTriggerCount + 1
					end
				end
			end
		end
	elseif onLeave and otherActorId == spec.dynamicMountObjectActorId and spec.dynamicMountObjectTriggerCount ~= nil then
		spec.dynamicMountObjectTriggerCount = spec.dynamicMountObjectTriggerCount - 1

		if spec.dynamicMountObjectTriggerCount == 0 then
			self:unmountDynamic()

			spec.dynamicMountObjectTriggerCount = nil
		end
	end
end

function Mountable:mount(object, node, x, y, z, rx, ry, rz)
	local spec = self.spec_mountable

	self:unmountDynamic(true)

	if spec.mountObject == nil then
		removeFromPhysics(spec.componentNode)
	end

	link(node, spec.componentNode)

	local wx, wy, wz = localToWorld(node, x, y, z)
	local wqx, wqy, wqz, wqw = mathEulerToQuaternion(localRotationToWorld(node, rx, ry, rz))

	self:setWorldPositionQuaternion(wx, wy, wz, wqx, wqy, wqz, wqw, 1, true)

	spec.mountObject = object
end

function Mountable:unmount()
	local spec = self.spec_mountable

	if spec.mountObject ~= nil then
		spec.mountObject = nil
		local x, y, z = getWorldTranslation(spec.componentNode)
		local qx, qy, qz, qw = getWorldQuaternion(spec.componentNode)

		link(getRootNode(), spec.componentNode)
		self:setWorldPositionQuaternion(x, y, z, qx, qy, qz, qw, 1, true)
		addToPhysics(spec.componentNode)
		self:setReducedComponentMass(false)

		return true
	end

	return false
end

function Mountable:mountKinematic(object, node, x, y, z, rx, ry, rz)
	local spec = self.spec_mountable

	self:unmountDynamic(true)
	removeFromPhysics(spec.componentNode)
	link(node, spec.componentNode)

	local wx, wy, wz = localToWorld(node, x, y, z)
	local wqx, wqy, wqz, wqw = mathEulerToQuaternion(localRotationToWorld(node, rx, ry, rz))

	self:setWorldPositionQuaternion(wx, wy, wz, wqx, wqy, wqz, wqw, 1, true)
	addToPhysics(spec.componentNode)

	if self.isServer then
		setRigidBodyType(spec.componentNode, RigidBodyType.KINEMATIC)

		self.components[1].isKinematic = true
		self.components[1].isDynamic = false
	end

	if object.getParentComponent ~= nil then
		local componentNode = object:getParentComponent(node)

		if getRigidBodyType(componentNode) == RigidBodyType.DYNAMIC then
			setPairCollision(componentNode, spec.componentNode, false)
		end
	end

	spec.mountObject = object
	spec.mountJointNode = node
end

function Mountable:unmountKinematic()
	local spec = self.spec_mountable

	if spec.mountObject ~= nil then
		if spec.mountObject.getParentComponent ~= nil then
			local componentNode = spec.mountObject:getParentComponent(spec.mountJointNode)

			if getRigidBodyType(componentNode) == RigidBodyType.DYNAMIC then
				setPairCollision(componentNode, spec.componentNode, true)
			end
		end

		spec.mountObject = nil
		spec.mountJointNode = nil
		local x, y, z = getWorldTranslation(spec.componentNode)
		local qx, qy, qz, qw = getWorldQuaternion(spec.componentNode)

		removeFromPhysics(spec.componentNode)
		link(getRootNode(), spec.componentNode)
		self:setWorldPositionQuaternion(x, y, z, qx, qy, qz, qw, 1, true)
		addToPhysics(spec.componentNode)

		if self.isServer then
			setRigidBodyType(spec.componentNode, RigidBodyType.DYNAMIC)

			self.components[1].isKinematic = false
			self.components[1].isDynamic = true
		end

		self:setReducedComponentMass(false)

		return true
	end

	return false
end

function Mountable:mountDynamic(object, objectActorId, jointNode, mountType, forceAcceleration)
	local spec = self.spec_mountable

	if not self:getSupportsMountDynamic() or spec.mountObject ~= nil then
		return false
	end

	local dynamicMountSpec = self.spec_dynamicMountAttacher

	if dynamicMountSpec ~= nil then
		for _, mountedObject in pairs(dynamicMountSpec.dynamicMountedObjects) do
			if mountedObject:isa(Vehicle) and mountedObject.rootVehicle == object.rootVehicle then
				return false
			end
		end
	end

	if object.rootVehicle == self.rootVehicle then
		return false
	end

	jointNode = spec.jointNode or jointNode

	if spec.dynamicMountTriggerId ~= nil then
		local x, y, z = nil

		if mountType == DynamicMountUtil.TYPE_FORK then
			local _, _, zOffset = worldToLocal(jointNode, localToWorld(spec.componentNode, getCenterOfMass(spec.componentNode)))
			x, y, z = localToLocal(jointNode, getParent(spec.dynamicMountJointNodeDynamic), 0, 0, zOffset)
		else
			x, y, z = localToLocal(jointNode, getParent(spec.dynamicMountJointNodeDynamic), 0, 0, 0)
		end

		y = spec.dynamicMountJointTransY or y

		setTranslation(spec.dynamicMountJointNodeDynamic, x, y, z)

		local rx, ry, rz = nil

		if spec.dynamicMountJointLimitToRotY then
			local dx, _, dz = localDirectionToLocal(jointNode, getParent(spec.dynamicMountJointNodeDynamic), 0, 0, 1)
			dx, dz = MathUtil.vector2Normalize(dx, dz)
			rz = 0
			ry = MathUtil.getYRotationFromDirection(dx, dz)
			rx = 0
		else
			rx, ry, rz = localRotationToLocal(jointNode, getParent(spec.dynamicMountJointNodeDynamic), 0, 0, 0)
		end

		setRotation(spec.dynamicMountJointNodeDynamic, rx, ry, rz)
	end

	local additionalWeight = self:getAdditionalMountingMass()
	local mass = self:getTotalMass()
	local massFactor = (additionalWeight + mass) / mass
	forceAcceleration = forceAcceleration * massFactor

	return DynamicMountUtil.mountDynamic(self, spec.componentNode, object, objectActorId, jointNode, mountType, forceAcceleration * spec.dynamicMountForceLimitScale, spec.dynamicMountJointNodeDynamic)
end

function Mountable:unmountDynamic(isDelete)
	DynamicMountUtil.unmountDynamic(self, isDelete)
	self:setReducedComponentMass(false)
end

function Mountable:getAdditionalMountingDistance()
	return self.spec_mountable.additionalMountDistance
end

function Mountable:getAdditionalMountingMass()
	local distance = self:getAdditionalMountingDistance()

	if distance > 0 then
		local spec = self.spec_mountable
		local x, y, z = getWorldTranslation(self.rootNode)
		spec.additionalMountingMass = 0

		raycastAll(x, y + 0.1, z, 0, 1, 0, "additionalMountingMassRaycastCallback", distance, self, CollisionFlag.DYNAMIC_OBJECT, false, false)

		return spec.additionalMountingMass
	end

	return 0
end

function Mountable:additionalMountingMassRaycastCallback(hitObjectId, x, y, z, distance, nx, ny, nz, subShapeIndex, shapeId, isLast)
	local vehicle = g_currentMission.nodeToObject[hitObjectId]

	if vehicle ~= self and vehicle ~= nil and vehicle:isa(Vehicle) and vehicle.getAdditionalMountingMass ~= nil then
		local spec = self.spec_mountable
		spec.additionalMountingMass = spec.additionalMountingMass + vehicle:getTotalMass()
		spec.additionalMountingMass = spec.additionalMountingMass + vehicle:getAdditionalMountingMass()

		return false
	end
end

function Mountable:getIsActive(superFunc)
	local isActive = false
	local spec = self.spec_mountable

	if spec.dynamicMountObject ~= nil and spec.dynamicMountObject.getIsActive ~= nil then
		isActive = spec.dynamicMountObject:getIsActive()
	end

	return superFunc(self) or isActive
end

function Mountable:getMountObject()
	local spec = self.spec_mountable

	return spec.mountObject
end

function Mountable:getDynamicMountObject()
	local spec = self.spec_mountable

	return spec.dynamicMountObject
end

function Mountable:setReducedComponentMass(state)
	local spec = self.spec_mountable

	if self:getAllowComponentMassReduction() then
		if spec.reducedComponentMass ~= state then
			spec.reducedComponentMass = state

			self:setMassDirty()
		end

		return true
	end

	return false
end

function Mountable:getAllowComponentMassReduction()
	return self.spec_mountable.allowMassReduction
end

function Mountable:getDefaultAllowComponentMassReduction()
	return false
end

function Mountable:getMountableLockPositions()
	return self.spec_mountable.lockPositions
end

function Mountable:getOwner(superFunc)
	local spec = self.spec_mountable

	if spec.dynamicMountObject ~= nil and spec.dynamicMountObject.getOwner ~= nil then
		return spec.dynamicMountObject:getOwner()
	end

	return superFunc(self)
end

function Mountable:findRootVehicle(superFunc)
	local spec = self.spec_mountable
	local rootAttacherVehicle = superFunc(self)

	if (rootAttacherVehicle == nil or rootAttacherVehicle == self) and spec.dynamicMountObject ~= nil and spec.dynamicMountObject.findRootVehicle ~= nil then
		rootAttacherVehicle = spec.dynamicMountObject:findRootVehicle()
	end

	if rootAttacherVehicle == nil then
		rootAttacherVehicle = self
	end

	return rootAttacherVehicle
end

function Mountable:getIsMapHotspotVisible(superFunc)
	if not superFunc(self) then
		return false
	end

	if self:getMountObject() ~= nil then
		return false
	end

	if self:getDynamicMountObject() ~= nil then
		return false
	end

	return true
end

function Mountable:getAdditionalComponentMass(superFunc, component)
	local additionalMass = superFunc(self, component)
	local spec = self.spec_mountable

	if spec.reducedComponentMass then
		additionalMass = -component.defaultMass + 0.1
	end

	return additionalMass
end

function Mountable:setWorldPositionQuaternion(superFunc, x, y, z, qx, qy, qz, qw, i, changeInterp)
	if not self.isServer then
		if self:getMountObject() == nil or i > 1 then
			return superFunc(self, x, y, z, qx, qy, qz, qw, i, changeInterp)
		end

		return
	end

	return superFunc(self, x, y, z, qx, qy, qz, qw, i, changeInterp)
end

function Mountable:onEnterVehicle(isControlling)
	self:unmountDynamic()
end

function Mountable:onPreAttach(attacherVehicle, inputJointDescIndex, jointDescIndex)
	self:unmountDynamic()
end
