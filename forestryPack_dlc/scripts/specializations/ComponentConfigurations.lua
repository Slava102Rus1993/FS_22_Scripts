local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

ComponentConfigurations = {
	MOD_NAME = g_currentModName,
	SPEC_NAME = g_currentModName .. ".componentConfigurations",
	prerequisitesPresent = function (specializations)
		return true
	end,
	initSpecialization = function ()
		if g_iconGenerator == nil and g_configurationManager.configurations.usedComponents == nil then
			g_configurationManager:addConfigurationType("usedComponents", g_i18n:getText("shop_configuration"), "base", nil, , , ConfigurationUtil.SELECTOR_MULTIOPTION)
		end

		local schema = Vehicle.xmlSchema

		schema:setXMLSpecializationType("ComponentConfigurations")
		ObjectChangeUtil.registerObjectChangeXMLPaths(schema, "vehicle.base.usedComponentsConfigurations.usedComponentsConfiguration(?)")
		schema:register(XMLValueType.VECTOR_N, "vehicle.base.usedComponentsConfigurations.usedComponentsConfiguration(?)#usedIndices", "Indices of components that are loaded")
		schema:register(XMLValueType.VECTOR_N, "vehicle.base.usedComponentsConfigurations.usedComponentsConfiguration(?)#usedJointIndices", "Indices of component joints that are loaded")
		schema:setXMLSpecializationType()
	end
}

function ComponentConfigurations.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "getIsComponentAvailable", ComponentConfigurations.getIsComponentAvailable)
	SpecializationUtil.registerFunction(vehicleType, "getIsComponentJointAvailable", ComponentConfigurations.getIsComponentJointAvailable)
end

function ComponentConfigurations.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "addToPhysics", ComponentConfigurations.addToPhysics)
end

function ComponentConfigurations.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", ComponentConfigurations)
end

function ComponentConfigurations:onLoad(savegame)
	self.spec_componentConfigurations = self["spec_" .. ComponentConfigurations.SPEC_NAME]
	local spec = self.spec_componentConfigurations
	local configurationId = Utils.getNoNil(self.configurations.usedComponents, 1)
	local configKey = string.format("vehicle.base.usedComponentsConfigurations.usedComponentsConfiguration(%d)", configurationId - 1)

	ObjectChangeUtil.updateObjectChanges(self.xmlFile, "vehicle.base.usedComponentsConfigurations.usedComponentsConfiguration", configurationId, self.components, self)

	spec.usedIndices = self.xmlFile:getValue(configKey .. "#usedIndices", nil, true)
	spec.usedJointIndices = self.xmlFile:getValue(configKey .. "#usedJointIndices", nil, true)
	spec.loadCustomComponents = #spec.usedIndices > 0
	spec.loadCustomComponentJoints = #spec.usedJointIndices > 0
end

function ComponentConfigurations:getIsComponentAvailable(componentIndex)
	local spec = self.spec_componentConfigurations

	if spec.loadCustomComponents then
		for j = 1, #spec.usedIndices do
			if componentIndex == spec.usedIndices[j] then
				return true
			end
		end

		return false
	end

	return true
end

function ComponentConfigurations:getIsComponentJointAvailable(componentJointIndex)
	local spec = self.spec_componentConfigurations

	if spec.loadCustomComponentJoints then
		for j = 1, #spec.usedJointIndices do
			if componentJointIndex == spec.usedJointIndices[j] then
				return true
			end
		end

		return false
	end

	return true
end

function ComponentConfigurations:addToPhysics(superFunc)
	if not self.isAddedToPhysics then
		local lastMotorizedNode = nil

		for componentIndex, component in pairs(self.components) do
			if self:getIsComponentAvailable(componentIndex) then
				addToPhysics(component.node)
			else
				removeFromPhysics(component.node)

				component.initialTranslationOffset = {
					localToLocal(component.node, self.rootNode, 0, 0, 0)
				}
				component.initialRotationOffset = {
					localRotationToLocal(component.node, self.rootNode, 0, 0, 0)
				}
			end

			if component.motorized then
				if lastMotorizedNode ~= nil and self.isServer then
					addVehicleLink(lastMotorizedNode, component.node)
				end

				lastMotorizedNode = component.node
			end
		end

		self.isAddedToPhysics = true

		if self.isServer then
			for jointDescIndex, jointDesc in pairs(self.componentJoints) do
				if self:getIsComponentJointAvailable(jointDescIndex) then
					self:createComponentJoint(self.components[jointDesc.componentIndices[1]], self.components[jointDesc.componentIndices[2]], jointDesc)
				end
			end

			addWakeUpReport(self.rootNode, "onVehicleWakeUpCallback", self)
		end

		for _, collisionPair in pairs(self.collisionPairs) do
			setPairCollision(collisionPair.component1.node, collisionPair.component2.node, collisionPair.enabled)
		end

		self:setMassDirty()
	end

	superFunc(self)

	return true
end

Vehicle.saveToXMLFile = Utils.overwrittenFunction(Vehicle.saveToXMLFile, function (self, superFunc, xmlFile, key, usedModNames)
	if self.spec_componentConfigurations ~= nil then
		for componentIndex, component in pairs(self.components) do
			if not self:getIsComponentAvailable(componentIndex) then
				setWorldTranslation(component.node, localToWorld(self.rootNode, unpack(component.initialTranslationOffset)))
				setWorldRotation(component.node, localRotationToWorld(self.rootNode, unpack(component.initialRotationOffset)))
			end
		end
	end

	superFunc(self, xmlFile, key, usedModNames)
end)
