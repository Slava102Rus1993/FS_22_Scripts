TreeSaplingPallet = {
	prerequisitesPresent = function (specializations)
		return true
	end,
	initSpecialization = function ()
		g_configurationManager:addConfigurationType("treeSaplingType", g_i18n:getText("configuration_treeType"), "treeSaplingPallet", nil, , , ConfigurationUtil.SELECTOR_MULTIOPTION)

		local schema = Vehicle.xmlSchema

		schema:setXMLSpecializationType("TreeSaplingPallet")
		schema:register(XMLValueType.INT, "vehicle.treeSaplingPallet#fillUnitIndex", "Index of the saplings fill unit", 1)
		schema:register(XMLValueType.STRING, "vehicle.treeSaplingPallet#treeType", "Tree Type Name", "spruce1")
		schema:register(XMLValueType.STRING, "vehicle.treeSaplingPallet#filename", "Custom tree sapling i3d file")
		schema:register(XMLValueType.INT, "vehicle.treeSaplingPallet.treeSaplingTypeConfigurations.treeSaplingTypeConfiguration(?)#fillUnitIndex", "Index of the saplings fill unit", 1)
		schema:register(XMLValueType.STRING, "vehicle.treeSaplingPallet.treeSaplingTypeConfigurations.treeSaplingTypeConfiguration(?)#treeType", "Tree Type Name", "spruce1")
		schema:register(XMLValueType.STRING, "vehicle.treeSaplingPallet.treeSaplingTypeConfigurations.treeSaplingTypeConfiguration(?)#filename", "Custom tree sapling i3d file")
		schema:register(XMLValueType.NODE_INDEX, "vehicle.treeSaplingPallet.saplingNodes.saplingNode(?)#node", "Sapling link node")
		schema:register(XMLValueType.BOOL, "vehicle.treeSaplingPallet.saplingNodes.saplingNode(?)#randomize", "Randomize rotation and scale of saplings", true)
		schema:register(XMLValueType.NODE_INDEX, "vehicle.treeSaplingPallet.treeSaplingTypeConfigurations.treeSaplingTypeConfiguration(?).saplingNodes.saplingNode(?)#node", "Sapling link node")
		schema:register(XMLValueType.BOOL, "vehicle.treeSaplingPallet.treeSaplingTypeConfigurations.treeSaplingTypeConfiguration(?).saplingNodes.saplingNode(?)#randomize", "Randomize rotation and scale of saplings", true)
		ObjectChangeUtil.registerObjectChangeXMLPaths(schema, "vehicle.treeSaplingPallet.treeSaplingTypeConfigurations.treeSaplingTypeConfiguration(?)")
		schema:setXMLSpecializationType()
	end
}

function TreeSaplingPallet.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "onTreeSaplingLoaded", TreeSaplingPallet.onTreeSaplingLoaded)
	SpecializationUtil.registerFunction(vehicleType, "getTreeType", TreeSaplingPallet.getTreeType)
	SpecializationUtil.registerFunction(vehicleType, "updateTreeSaplingPalletNodes", TreeSaplingPallet.updateTreeSaplingPalletNodes)
end

function TreeSaplingPallet.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "showInfo", TreeSaplingPallet.showInfo)
end

function TreeSaplingPallet.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", TreeSaplingPallet)
	SpecializationUtil.registerEventListener(vehicleType, "onLoadFinished", TreeSaplingPallet)
	SpecializationUtil.registerEventListener(vehicleType, "onDelete", TreeSaplingPallet)
	SpecializationUtil.registerEventListener(vehicleType, "onFillUnitFillLevelChanged", TreeSaplingPallet)
end

function TreeSaplingPallet:onLoad(savegame)
	local spec = self.spec_treeSaplingPallet
	local treeSaplingTypeConfigurationId = Utils.getNoNil(self.configurations.treeSaplingType, 1)
	local baseKey = string.format("vehicle.treeSaplingPallet.treeSaplingTypeConfigurations.treeSaplingTypeConfiguration(%d)", treeSaplingTypeConfigurationId - 1)

	ObjectChangeUtil.updateObjectChanges(self.xmlFile, "vehicle.treeSaplingPallet.treeSaplingTypeConfigurations.treeSaplingTypeConfiguration", treeSaplingTypeConfigurationId, self.components, self)

	if not self.xmlFile:hasProperty(baseKey) then
		baseKey = "vehicle.treeSaplingPallet"
	end

	spec.fillUnitIndex = self.xmlFile:getValue(baseKey .. "#fillUnitIndex", 1)
	spec.treeTypeName = self.xmlFile:getValue(baseKey .. "#treeType", "spruce1")
	spec.treeTypeDesc = g_treePlantManager:getTreeTypeDescFromName(spec.treeTypeName)
	spec.saplingNodes = {}
	spec.treeTypeFilename = g_treePlantManager:getTreeTypeFilename(spec.treeTypeDesc, 1)

	if spec.treeTypeFilename ~= nil then
		local treeTypeFilename = self.xmlFile:getValue(baseKey .. "#filename")

		if treeTypeFilename ~= nil then
			treeTypeFilename = Utils.getFilename(treeTypeFilename, self.baseDirectory)
		else
			treeTypeFilename = spec.treeTypeFilename
		end

		local nodeKey = baseKey .. ".saplingNodes.saplingNode"

		if not self.xmlFile:hasProperty(nodeKey) then
			nodeKey = "vehicle.treeSaplingPallet.saplingNodes.saplingNode"
		end

		self.xmlFile:iterate(nodeKey, function (_, key)
			local entry = {
				node = self.xmlFile:getValue(key .. "#node", nil, self.components, self.i3dMappings)
			}

			if entry.node ~= nil then
				if self.xmlFile:getValue(key .. "#randomize", true) then
					setRotation(entry.node, 0, math.random(0, math.pi * 2), 0)
					setScale(entry.node, 1, math.random(90, 110) / 100, 1)
				end

				entry.sharedLoadRequestId = self:loadSubSharedI3DFile(treeTypeFilename, false, false, self.onTreeSaplingLoaded, self, {
					entry = entry
				})

				table.insert(spec.saplingNodes, entry)
			end
		end)
	end

	if spec.treeTypeDesc ~= nil then
		spec.infoBoxLineTitle = g_i18n:getText("configuration_treeType", self.customEnvironment)
		spec.infoBoxLineValue = g_i18n:getText(self.spec_treeSaplingPallet.treeTypeDesc.nameI18N, self.customEnvironment)
	end
end

function TreeSaplingPallet:onLoadFinished()
	self:updateTreeSaplingPalletNodes()
end

function TreeSaplingPallet:onDelete()
	local spec = self.spec_treeSaplingPallet

	if spec.saplingNodes ~= nil then
		for i = 1, #spec.saplingNodes do
			local entry = spec.saplingNodes[i]

			if entry.sharedLoadRequestId ~= nil then
				g_i3DManager:releaseSharedI3DFile(entry.sharedLoadRequestId)
			end
		end

		spec.saplingNodes = {}
	end
end

function TreeSaplingPallet:onTreeSaplingLoaded(i3dNode, failedReason, args)
	if i3dNode ~= 0 then
		local entry = args.entry

		link(entry.node, getChildAt(i3dNode, 0))
		delete(i3dNode)
	end
end

function TreeSaplingPallet:getTreeType()
	return self.spec_treeSaplingPallet.treeTypeName
end

function TreeSaplingPallet:updateTreeSaplingPalletNodes()
	local spec = self.spec_treeSaplingPallet
	local fillLevel = self:getFillUnitFillLevel(spec.fillUnitIndex)
	local capacity = self:getFillUnitCapacity(spec.fillUnitIndex)

	for i = 1, #spec.saplingNodes do
		local saplingNode = spec.saplingNodes[i]

		setVisibility(saplingNode.node, i <= MathUtil.round(fillLevel))
		I3DUtil.setShaderParameterRec(saplingNode.node, "hideByIndex", capacity - fillLevel, 0, 0, 0)
	end
end

function TreeSaplingPallet:onFillUnitFillLevelChanged(fillUnitIndex, fillLevelDelta, fillTypeIndex, toolType, fillPositionData, appliedDelta)
	self:updateTreeSaplingPalletNodes()
end

function TreeSaplingPallet:showInfo(superFunc, box)
	local spec = self.spec_treeSaplingPallet

	if spec.infoBoxLineTitle ~= nil then
		box:addLine(spec.infoBoxLineTitle, spec.infoBoxLineValue)
	end

	superFunc(self, box)
end
