SandboxPlaceable = {
	MOD_DIRECTORY = g_currentModDirectory,
	MOD_NAME = g_currentModName,
	TYPE_UNKNOWN = 0,
	TYPE_FERMENTER = 1,
	TYPE_POWERPLANT = 2,
	TYPE_SILO = 3,
	TYPE_BUNKER = 4,
	TYPE_TORCH = 5
}
SandboxPlaceable.TYPE_NAME = {
	[SandboxPlaceable.TYPE_UNKNOWN] = "UNKNOWN",
	[SandboxPlaceable.TYPE_FERMENTER] = "FERMENTER",
	[SandboxPlaceable.TYPE_POWERPLANT] = "POWERPLANT",
	[SandboxPlaceable.TYPE_SILO] = "SILO",
	[SandboxPlaceable.TYPE_BUNKER] = "BUNKER",
	[SandboxPlaceable.TYPE_TORCH] = "TORCH"
}
SandboxPlaceable.TYPE_NAME_TO_I18N_MAPPING = {
	SILO = "sandboxType_silos",
	TORCH = "sandboxType_torchs",
	BUNKER = "sandboxType_bunkers",
	FERMENTER = "sandboxType_fermenters",
	POWERPLANT = "sandboxType_powerplants",
	UNKNOWN = "UNKNOWN TYPE NAME"
}
SandboxPlaceable.UTILIZATION_STATE = {
	UNKNOWN = 0,
	RUNNING_NOT = 1,
	RUNNING_LIMIT = 2,
	RUNNING_PERFECT = 3,
	RUNNING_OK = 4,
	RUNNING_BAD = 5
}
SandboxPlaceable.UTILIZATION_STATE_TO_I18N_MAPPING = {
	[SandboxPlaceable.UTILIZATION_STATE.UNKNOWN] = "UNKNOWN UTILIZATION STATE",
	[SandboxPlaceable.UTILIZATION_STATE.RUNNING_NOT] = "sandboxUtilization_notRunning",
	[SandboxPlaceable.UTILIZATION_STATE.RUNNING_LIMIT] = "sandboxUtilization_limitedRunning",
	[SandboxPlaceable.UTILIZATION_STATE.RUNNING_PERFECT] = "sandboxUtilization_perfectRunning",
	[SandboxPlaceable.UTILIZATION_STATE.RUNNING_OK] = "sandboxUtilization_okRunning",
	[SandboxPlaceable.UTILIZATION_STATE.RUNNING_BAD] = "sandboxUtilization_badRunning"
}
SandboxPlaceable.PRIORITY_FATAL = -1
SandboxPlaceable.PRIORITY_LOW = 0
SandboxPlaceable.PRIORITY_NORMAL = 1
SandboxPlaceable.PRIORITY_HIGH = 2
SandboxPlaceable.SHOP_INFO_HEIGHT = 14
SandboxPlaceable.SHOP_INFO_TEXT_OFFSET = 2
SandboxPlaceable.SHOP_INFO_DOT_OFFSET = -0.3
SandboxPlaceable.SHOP_INFO_COLOR_LINE = {
	0.0227,
	0.5346,
	0.8519,
	1
}
SandboxPlaceable.SHOP_INFO_COLOR_TEXT = {
	1,
	1,
	1,
	1
}
SandboxPlaceable.SHOP_INFO_COLOR_DOT = {
	0.0227,
	0.5346,
	0.8519,
	1
}
SandboxPlaceable.SHOP_INFO_COLOR_ROOT_DOT = {
	0.0227,
	0.5346,
	0.8519,
	1
}

function SandboxPlaceable.prerequisitesPresent(specializations)
	return SpecializationUtil.hasSpecialization(PlaceablePlacement, specializations)
end

function SandboxPlaceable.registerXMLPaths(schema, basePath)
	schema:setXMLSpecializationType("Sandbox")
	schema:register(XMLValueType.BOOL, basePath .. ".sandbox#requiresSandboxRoot", "Placeable requires a sandbox root to be placed", false)
	schema:register(XMLValueType.BOOL, basePath .. ".sandbox#canBeRoot", "Placeable can be a root", false)
	schema:register(XMLValueType.FLOAT, basePath .. ".sandbox#radius", "Radius of placeable root area", 150)
	schema:register(XMLValueType.STRING, basePath .. ".sandbox#type", "Type of sandbox placeable", "UNKNOWN")
	schema:register(XMLValueType.STRING, basePath .. ".sandbox#name", "Name of sandbox root", "BGA")
	schema:register(XMLValueType.STRING, basePath .. ".sandbox#priority", "Priority of sandbox placeable", "NORMAL")
	schema:register(XMLValueType.STRING, basePath .. ".sandbox.distributionsPerFillType.fillType(?)#name", "Name of distributed fillType")
	schema:register(XMLValueType.STRING, basePath .. ".sandbox.distributionsPerFillType.fillType(?)#litersPerMinute", "Liters per minute of distributing fillType")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".sandbox#feedingPipesRefNode", "Reference node for feeding pipes")
	schema:register(XMLValueType.FLOAT, basePath .. ".sandbox#fermenterSize", "Size of fermenter")
	schema:setXMLSpecializationType()
end

function SandboxPlaceable.registerSavegameXMLPaths(schema, basePath)
	schema:setXMLSpecializationType("Sandbox")
	schema:register(XMLValueType.BOOL, basePath .. "#isRoot", "Root state of sandbox placeable.")
	schema:register(XMLValueType.INT, basePath .. ".child(?)#placeableId", "Placeable id of child sandbox placeable.")
	schema:register(XMLValueType.STRING, basePath .. "#sandboxRootName", "Name prefix of sandbox root placeable.")
	schema:setXMLSpecializationType()
end

function SandboxPlaceable.registerEvents(placeableType)
	SpecializationUtil.registerEvent(placeableType, "onFinalizeSandbox")
	SpecializationUtil.registerEvent(placeableType, "onSandboxRootChanged")
	SpecializationUtil.registerEvent(placeableType, "onSandboxPlaceableAdded")
	SpecializationUtil.registerEvent(placeableType, "onSandboxPlaceableRemoved")
	SpecializationUtil.registerEvent(placeableType, "onUpdateSandboxPlaceable")
end

function SandboxPlaceable.registerFunctions(placeableType)
	SpecializationUtil.registerFunction(placeableType, "onGuiChanged", SandboxPlaceable.onGuiChanged)
	SpecializationUtil.registerFunction(placeableType, "drawSandboxOverview", SandboxPlaceable.drawSandboxOverview)
	SpecializationUtil.registerFunction(placeableType, "setSandboxRootPlaceable", SandboxPlaceable.setSandboxRootPlaceable)
	SpecializationUtil.registerFunction(placeableType, "getSandboxRootPlaceable", SandboxPlaceable.getSandboxRootPlaceable)
	SpecializationUtil.registerFunction(placeableType, "isSandboxPlaceable", SandboxPlaceable.isSandboxPlaceable)
	SpecializationUtil.registerFunction(placeableType, "isSandboxRoot", SandboxPlaceable.isSandboxRoot)
	SpecializationUtil.registerFunction(placeableType, "setSandboxRootState", SandboxPlaceable.setSandboxRootState)
	SpecializationUtil.registerFunction(placeableType, "canBeSandboxRoot", SandboxPlaceable.canBeSandboxRoot)
	SpecializationUtil.registerFunction(placeableType, "finalizeSandboxRoot", SandboxPlaceable.finalizeSandboxRoot)
	SpecializationUtil.registerFunction(placeableType, "addSandboxPlaceableChild", SandboxPlaceable.addSandboxPlaceableChild)
	SpecializationUtil.registerFunction(placeableType, "removeSandboxPlaceableChild", SandboxPlaceable.removeSandboxPlaceableChild)
	SpecializationUtil.registerFunction(placeableType, "getSandboxPlaceables", SandboxPlaceable.getSandboxPlaceables)
	SpecializationUtil.registerFunction(placeableType, "getPlaceableChildren", SandboxPlaceable.getPlaceableChildren)
	SpecializationUtil.registerFunction(placeableType, "getPlaceableChildrenbyType", SandboxPlaceable.getPlaceableChildrenbyType)
	SpecializationUtil.registerFunction(placeableType, "getSandboxPriority", SandboxPlaceable.getSandboxPriority)
	SpecializationUtil.registerFunction(placeableType, "getPlaceableChildrenbyPriority", SandboxPlaceable.getPlaceableChildrenbyPriority)
	SpecializationUtil.registerFunction(placeableType, "getSandboxRootInRange", SandboxPlaceable.getSandboxRootInRange)
	SpecializationUtil.registerFunction(placeableType, "addStandaloneSandboxChildrenInRange", SandboxPlaceable.addStandaloneSandboxChildrenInRange)
	SpecializationUtil.registerFunction(placeableType, "getSandboxType", SandboxPlaceable.getSandboxType)
	SpecializationUtil.registerFunction(placeableType, "getSandboxTypeName", SandboxPlaceable.getSandboxTypeName)
	SpecializationUtil.registerFunction(placeableType, "getDistibutionPerFillType", SandboxPlaceable.getDistibutionPerFillType)
	SpecializationUtil.registerFunction(placeableType, "getFeedingPipeParams", SandboxPlaceable.getFeedingPipeParams)
	SpecializationUtil.registerFunction(placeableType, "getSandboxRootName", SandboxPlaceable.getSandboxRootName)
	SpecializationUtil.registerFunction(placeableType, "setSandboxRootName", SandboxPlaceable.setSandboxRootName)
	SpecializationUtil.registerFunction(placeableType, "getUtilizationPercentage", SandboxPlaceable.getUtilizationPercentage)
end

function SandboxPlaceable.registerOverwrittenFunctions(placeableType)
	SpecializationUtil.registerOverwrittenFunction(placeableType, "getName", SandboxPlaceable.getName)
	SpecializationUtil.registerOverwrittenFunction(placeableType, "getCanBePlacedAt", SandboxPlaceable.getCanBePlacedAt)
	SpecializationUtil.registerOverwrittenFunction(placeableType, "getHasOverlap", SandboxPlaceable.getHasOverlap)
end

function SandboxPlaceable.registerEventListeners(placeableType)
	SpecializationUtil.registerEventListener(placeableType, "onLoad", SandboxPlaceable)
	SpecializationUtil.registerEventListener(placeableType, "onPreDelete", SandboxPlaceable)
	SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", SandboxPlaceable)
	SpecializationUtil.registerEventListener(placeableType, "onWriteStream", SandboxPlaceable)
	SpecializationUtil.registerEventListener(placeableType, "onReadStream", SandboxPlaceable)
	SpecializationUtil.registerEventListener(placeableType, "onUpdate", SandboxPlaceable)
	SpecializationUtil.registerEventListener(placeableType, "onUpdateSandboxPlaceable", SandboxPlaceable)
	SpecializationUtil.registerEventListener(placeableType, "onSandboxPlaceableAdded", SandboxPlaceable)
	SpecializationUtil.registerEventListener(placeableType, "onSandboxPlaceableRemoved", SandboxPlaceable)
end

function SandboxPlaceable:onLoad(savegame)
	self.spec_sandboxPlaceable = self[("spec_%s.sandboxPlaceable"):format(SandboxPlaceable.MOD_NAME)]
	local spec = self.spec_sandboxPlaceable
	spec.canBeRoot = self.xmlFile:getValue("placeable.sandbox#canBeRoot", false)
	spec.requiresSandboxRoot = self.xmlFile:getValue("placeable.sandbox#requiresSandboxRoot", spec.canBeRoot)
	spec.sandboxRadius = self.xmlFile:getValue("placeable.sandbox#radius", 150)
	spec.feedingPipesRefNode = self.xmlFile:getValue("placeable.sandbox#feedingPipesRefNode", nil, self.components, self.i3dMappings)
	spec.fermenterSize = self.xmlFile:getValue("placeable.sandbox#fermenterSize")
	local typeName = self.xmlFile:getValue("placeable.sandbox#type", "UNKNOWN")

	if typeName == "UNKNOWN" and self.typeName == "silo" and self.spec_silo ~= nil and self.spec_silo.unloadingStation ~= nil then
		for _, fillTypeIndex in pairs({
			FillType.LIQUIDMANURE,
			FillType.DIGESTATE
		}) do
			if self.spec_silo.unloadingStation:getIsFillTypeSupported(fillTypeIndex) then
				typeName = self.typeName

				break
			end
		end
	end

	typeName = "TYPE_" .. typeName:upper()
	local type = SandboxPlaceable[typeName]

	if type == nil then
		Logging.xmlWarning(self.xmlFile, "Unable to find type '%s' for sandbox placeable 'placeable.sandbox#type'", typeName)

		return false
	end

	spec.type = type
	local priorityName = self.xmlFile:getValue("placeable.sandbox#priority", "NORMAL")
	priorityName = "PRIORITY_" .. priorityName:upper()
	local priority = SandboxPlaceable[priorityName]

	if priority == nil then
		Logging.xmlWarning(self.xmlFile, "Unable to find priority '%s' for sandbox placeable 'placeable.sandbox#priority'", priorityName)

		return false
	end

	spec.priority = priority
	spec.rootName = self.xmlFile:getValue("placeable.sandbox#name", "BGA")
	spec.sandboxRootName = ""
	spec.sandboxRootState = false
	spec.sandboxPlaceableRoot = nil
	spec.sandboxChildren = {}
	spec.sandboxChildrenByType = {}
	spec.sandboxChildrenByPriority = {}
	spec.sandboxPlaceablesToSelf = {}
	spec.distributionsPerFillType = {}

	self.xmlFile:iterate("placeable.sandbox.distributionsPerFillType.fillType", function (_, fillTypeKey)
		local name = self.xmlFile:getValue(fillTypeKey .. "#name")
		local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(name)

		if fillTypeIndex ~= nil then
			local litersPerMinute = self.xmlFile:getValue(fillTypeKey .. "#litersPerMinute", math.huge)
			spec.distributionsPerFillType[fillTypeIndex] = litersPerMinute
		else
			Logging.xmlError(xmlFile, "Unable to load fillType '%s' for '%s'", name, fillTypeKey)
		end
	end)
	g_messageCenter:subscribe(MessageType.GUI_BEFORE_OPEN, self.onGuiChanged, self)
end

function SandboxPlaceable:onPreDelete()
	local spec = self.spec_sandboxPlaceable

	if spec == nil then
		return
	end

	if self:isSandboxRoot() then
		SpecializationUtil.raiseEvent(self, "onSandboxPlaceableRemoved", self)
		g_currentMission.placeableSystem:releaseRootNameIndex(spec.rootName, self)

		local newRoot = nil

		for _, placeable in pairs(spec.sandboxChildren) do
			if placeable.spec_sandboxPlaceable.canBeRoot then
				newRoot = placeable

				break
			end
		end

		local warning = g_i18n:getText("infoDialog_noNewSandboxRootFound")

		if newRoot ~= nil then
			newRoot:setSandboxRootState(true)
			self:setSandboxRootName(spec.rootName)

			for _, placeable in pairs(spec.sandboxChildren) do
				if placeable ~= newRoot then
					placeable:setSandboxRootPlaceable(newRoot)
					newRoot:addSandboxPlaceableChild(placeable)
				end
			end

			warning = g_i18n:getText("infoDialog_sandboxRootBuildingChanged")
		else
			for _, placeable in pairs(spec.sandboxChildren) do
				placeable:setSandboxRootPlaceable(nil)
			end
		end

		if g_gui.showInfoDialog ~= nil and not g_currentMission.isExitingGame and g_currentMission.lastConstructionScreenOpenTime ~= -1 then
			g_gui:showInfoDialog({
				text = warning,
				buttonAction = InputAction.MENU_ACCEPT,
				okText = g_i18n:getText("button_ok")
			})
		end
	elseif spec.sandboxPlaceableRoot ~= nil then
		spec.sandboxPlaceableRoot:removeSandboxPlaceableChild(self)
	end
end

function SandboxPlaceable:onFinalizePlacement()
	if self.isLoadedFromSavegame then
		return
	end

	local isMultiplayerClient = g_currentMission.missionDynamicInfo.isMultiplayer and g_currentMission.missionDynamicInfo.isClient

	if not g_currentMission.isMissionStarted and isMultiplayerClient then
		return
	end

	local spec = self.spec_sandboxPlaceable
	local farmId = self:getOwnerFarmId()
	local x, y, z = getWorldTranslation(self.rootNode)
	local _, _, nearestSandboxRoot = self:getSandboxRootInRange(x, y, z, farmId)

	if nearestSandboxRoot ~= nil then
		self:setSandboxRootPlaceable(nearestSandboxRoot)
		nearestSandboxRoot:addSandboxPlaceableChild(self)
	elseif self:canBeSandboxRoot() then
		self:setSandboxRootState(true)
		self:setSandboxRootName(spec.rootName)
		self:addStandaloneSandboxChildrenInRange(farmId)

		if not g_currentMission.isExitingGame and g_currentMission.isMissionStarted and g_gui.showInfoDialog ~= nil and g_currentMission.lastConstructionScreenOpenTime ~= -1 then
			g_gui:showInfoDialog({
				text = g_i18n:getText("infoDialog_sandboxRootBuildingCreated"),
				buttonAction = InputAction.MENU_ACCEPT,
				okText = g_i18n:getText("button_ok")
			})
		end
	end
end

function SandboxPlaceable:onReadStream(streamId, connection)
	local spec = self.spec_sandboxPlaceable
	local isRoot = streamReadBool(streamId)

	self:setSandboxRootState(isRoot, true)

	if isRoot then
		local numChildren = streamReadInt8(streamId)

		for i = 1, numChildren do
			local child = NetworkUtil.readNodeObject(streamId)

			child:setSandboxRootPlaceable(self)
			self:addSandboxPlaceableChild(child)
		end

		if streamReadBool(streamId) then
			self:setSandboxRootName(streamReadString(streamId), true)
		end
	end
end

function SandboxPlaceable:onWriteStream(streamId, connection)
	local spec = self.spec_sandboxPlaceable
	local isRoot = self:isSandboxRoot()

	streamWriteBool(streamId, isRoot)

	if isRoot then
		streamWriteInt8(streamId, #spec.sandboxChildren)

		for _, child in ipairs(spec.sandboxChildren) do
			NetworkUtil.writeNodeObject(streamId, child)
		end

		local rootname = self:getSandboxRootName(true)

		if streamWriteBool(streamId, rootname ~= nil and rootname ~= "") then
			streamWriteString(streamId, rootname)
		end
	end
end

function SandboxPlaceable:loadFromXMLFile(xmlFile, key)
	local spec = self.spec_sandboxPlaceable
	local isRoot = xmlFile:getValue(key .. "#isRoot")

	if isRoot ~= nil then
		self:setSandboxRootState(isRoot, true)

		if isRoot then
			xmlFile:iterate(key .. ".child", function (index, childKey)
				local placeableId = xmlFile:getValue(childKey .. "#placeableId")

				if spec.sandboxPlaceablesToSelf[placeableId] == nil then
					spec.sandboxPlaceablesToSelf[placeableId] = true
				else
					Logging.xmlWarning(xmlFile, "Placeable id '%s' already added to sandbox root, ignoring it!", placeableId)
				end
			end)

			local sandboxRootName = xmlFile:getValue(key .. "#sandboxRootName")

			self:setSandboxRootName(sandboxRootName, true)
		end
	end
end

function SandboxPlaceable:saveToXMLFile(xmlFile, key, usedModNames)
	local spec = self.spec_sandboxPlaceable
	local isRoot = self:isSandboxRoot()

	if isRoot ~= nil then
		xmlFile:setValue(key .. "#isRoot", isRoot)

		if isRoot then
			for i = 1, #spec.sandboxChildren do
				local child = spec.sandboxChildren[i]
				local childKey = string.format("%s.child(%i)", key, i - 1)

				xmlFile:setValue(childKey .. "#placeableId", child.currentSavegameId)
			end

			xmlFile:setValue(key .. "#sandboxRootName", self:getSandboxRootName(true))
		end
	end
end

function SandboxPlaceable:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	if self:isSandboxPlaceable() then
		if g_gui.currentGuiName == "ShopMenu" or g_gui.currentGuiName == "ConstructionScreen" then
			self:raiseActive()
		end

		if g_currentMission.lastConstructionScreenOpenTime ~= -1 then
			self:drawSandboxOverview()
		end
	end
end

function SandboxPlaceable:onUpdateSandboxPlaceable(dt)
	local spec = self.spec_sandboxPlaceable

	if not self:isSandboxRoot() then
		return
	end

	for _, children in ipairs(spec.sandboxChildren) do
		SpecializationUtil.raiseEvent(children, "onUpdateSandboxPlaceable", dt)
	end
end

function SandboxPlaceable:onSandboxPlaceableAdded(placeable)
	local spec = self.spec_sandboxPlaceable

	if not self:isSandboxRoot() then
		return
	end

	for _, children in ipairs(spec.sandboxChildren) do
		SpecializationUtil.raiseEvent(children, "onSandboxPlaceableAdded", placeable)
	end
end

function SandboxPlaceable:onSandboxPlaceableRemoved(placeable)
	local spec = self.spec_sandboxPlaceable

	if not self:isSandboxRoot() then
		return
	end

	for _, children in ipairs(spec.sandboxChildren) do
		SpecializationUtil.raiseEvent(children, "onSandboxPlaceableRemoved", placeable)
	end
end

function SandboxPlaceable:onGuiChanged()
	if self:isSandboxPlaceable() and g_gui.currentGuiName == "ShopMenu" or g_gui.currentGuiName == "ConstructionScreen" then
		self:raiseActive()
	end
end

function SandboxPlaceable:drawSandboxOverview()
	local spec = self.spec_sandboxPlaceable
	local offsetY = SandboxPlaceable.SHOP_INFO_HEIGHT
	local dotOffset = SandboxPlaceable.SHOP_INFO_DOT_OFFSET
	local x, y, z = getWorldTranslation(self.rootNode)

	if not g_currentMission.manure.isDebug and (self:getSandboxType() == SandboxPlaceable.TYPE_SILO and self:getSandboxRootPlaceable() == nil or self:getOwnerFarmId() ~= g_currentMission:getFarmId()) then
		return
	end

	if self:isSandboxRoot() then
		Utils.renderTextAtWorldPosition(x, y + offsetY + dotOffset, z, ".", getCorrectTextSize(0.1), 0, SandboxPlaceable.SHOP_INFO_COLOR_ROOT_DOT)

		for _, placeable in pairs(spec.sandboxChildren) do
			if placeable.rootNode ~= nil then
				local px, py, pz = getWorldTranslation(placeable.rootNode)
				local r, g, b = unpack(SandboxPlaceable.SHOP_INFO_COLOR_LINE)

				drawDebugLine(x, y + offsetY, z, r, g, b, px, py + offsetY, pz, r, g, b)
			end
		end
	else
		drawDebugPoint(x, y + offsetY, z, unpack(SandboxPlaceable.SHOP_INFO_COLOR_DOT))
	end

	local renderText = ""

	local function addRenderText(text, ...)
		renderText = ("%s%s\n"):format(renderText, text):format(...)
	end

	addRenderText("%s", self:getName())

	if g_currentMission.manure.isDebug then
		local isRoot = self:isSandboxRoot()

		addRenderText("Root: %s", tostring(isRoot))

		if isRoot then
			addRenderText("Children: %d", #self.spec_sandboxPlaceable.sandboxChildren)
		end

		addRenderText("Type: %s", self:getSandboxTypeName())

		local farmId = g_currentMission:getFarmId()

		addRenderText("currentMission:farmId: %s", tostring(farmId))

		farmId = self:getOwnerFarmId()

		addRenderText("Owner:farmId: %s", tostring(farmId))

		if self.getMergedPlaceables ~= nil then
			local mergedPlaceables = self:getMergedPlaceables()

			for type, mergedPlaceable in pairs(mergedPlaceables) do
				addRenderText("mergedPlaceables:")
				addRenderText("     mergedPlaceable: %s", mergedPlaceable:getName())
				addRenderText("     type: %s", type)
			end
		end
	end

	Utils.renderTextAtWorldPosition(x, y + offsetY + SandboxPlaceable.SHOP_INFO_TEXT_OFFSET, z, renderText, getCorrectTextSize(0.015), 0, SandboxPlaceable.SHOP_INFO_COLOR_TEXT)
end

function SandboxPlaceable:setSandboxRootPlaceable(rootPlaceable)
	local spec = self.spec_sandboxPlaceable
	spec.sandboxPlaceableRoot = rootPlaceable

	self:setSandboxRootState(rootPlaceable == nil and self:canBeSandboxRoot())
end

function SandboxPlaceable:getSandboxRootPlaceable()
	local spec = self.spec_sandboxPlaceable

	return spec.sandboxPlaceableRoot
end

function SandboxPlaceable:isSandboxPlaceable()
	return self:getSandboxType() ~= SandboxPlaceable.TYPE_UNKNOWN
end

function SandboxPlaceable:isSandboxRoot()
	local spec = self.spec_sandboxPlaceable

	if spec ~= nil then
		return spec.sandboxRootState
	end

	return false
end

function SandboxPlaceable:setSandboxRootState(rootState, noEventSend)
	local spec = self.spec_sandboxPlaceable

	if rootState ~= spec.sandboxRootState then
		SandboxPlaceableRootStateEvent.sendEvent(self, rootState, noEventSend)

		spec.sandboxRootState = rootState

		SpecializationUtil.raiseEvent(self, "onSandboxRootChanged", rootState)
	end
end

function SandboxPlaceable:canBeSandboxRoot()
	local spec = self.spec_sandboxPlaceable

	return spec.canBeRoot and spec.sandboxPlaceableRoot == nil
end

function SandboxPlaceable:finalizeSandboxRoot()
	local spec = self.spec_sandboxPlaceable

	if self:isSandboxRoot() then
		for placeableId, value in pairs(spec.sandboxPlaceablesToSelf) do
			if value and placeableId ~= nil then
				local placeable = g_currentMission.placeableSystem:getPlaceableBySavegameId(placeableId)

				if placeable ~= nil and placeable.isSandboxPlaceable ~= nil then
					placeable:setSandboxRootPlaceable(self)
					self:addSandboxPlaceableChild(placeable)
				end
			end
		end

		table.clear(spec.sandboxPlaceablesToSelf)

		local placeables = self:getSandboxPlaceables()

		for _, placeable in ipairs(placeables) do
			SpecializationUtil.raiseEvent(placeable, "onFinalizeSandbox")
		end
	end
end

function SandboxPlaceable:addSandboxPlaceableChild(placeable)
	local spec = self.spec_sandboxPlaceable

	if placeable ~= nil and placeable:isSandboxPlaceable() and self:isSandboxRoot() then
		table.addElement(spec.sandboxChildren, placeable)

		local type = placeable:getSandboxType()

		if spec.sandboxChildrenByType[type] == nil then
			spec.sandboxChildrenByType[type] = {}
		end

		table.addElement(spec.sandboxChildrenByType[type], placeable)

		local prio = placeable:getSandboxPriority()

		if spec.sandboxChildrenByPriority[prio] == nil then
			spec.sandboxChildrenByPriority[prio] = {}
		end

		table.addElement(spec.sandboxChildrenByPriority[prio], placeable)
		SpecializationUtil.raiseEvent(self, "onSandboxPlaceableAdded", placeable)
	end
end

function SandboxPlaceable:removeSandboxPlaceableChild(placeable)
	local spec = self.spec_sandboxPlaceable

	table.removeElement(spec.sandboxChildren, placeable)

	local type = placeable:getSandboxType()

	if spec.sandboxChildrenByType[type] ~= nil then
		table.removeElement(spec.sandboxChildrenByType[type], placeable)
	end

	local prio = placeable:getSandboxPriority()

	if spec.sandboxChildrenByPriority[prio] ~= nil then
		table.removeElement(spec.sandboxChildrenByPriority[prio], placeable)
	end

	SpecializationUtil.raiseEvent(self, "onSandboxPlaceableRemoved", placeable)
end

function SandboxPlaceable:getSandboxPlaceables()
	local spec = self.spec_sandboxPlaceable
	local placeables = {}

	if self:isSandboxRoot() then
		table.addElement(placeables, self)

		for _, placeable in ipairs(spec.sandboxChildren) do
			table.addElement(placeables, placeable)
		end
	elseif spec.sandboxPlaceableRoot ~= nil then
		return spec.sandboxPlaceableRoot:getSandboxPlaceables()
	end

	return placeables
end

function SandboxPlaceable:getPlaceableChildren()
	local spec = self.spec_sandboxPlaceable

	if self:isSandboxRoot() then
		return spec.sandboxChildren
	end

	return {}
end

function SandboxPlaceable:getPlaceableChildrenbyType(type)
	local spec = self.spec_sandboxPlaceable

	if self:isSandboxRoot() and spec.sandboxChildrenByType[type] ~= nil then
		return spec.sandboxChildrenByType[type]
	end

	return {}
end

function SandboxPlaceable:getSandboxPriority()
	local spec = self.spec_sandboxPlaceable

	return spec.priority
end

function SandboxPlaceable:getPlaceableChildrenbyPriority(priority)
	local spec = self.spec_sandboxPlaceable

	if self:isSandboxRoot() and spec.sandboxChildrenByPriority[priority] ~= nil then
		return spec.sandboxChildrenByPriority[priority]
	end

	return {}
end

function SandboxPlaceable:getSandboxRootInRange(x, y, z, farmId)
	local sandboxPlaceables = g_currentMission.placeableSystem:getSandboxPlaceables(farmId)
	local nearestRootPlaceable = nil
	local nearestDistance = math.huge

	for _, placeable in pairs(sandboxPlaceables) do
		if placeable:isSandboxRoot() then
			local px, py, pz = getWorldTranslation(placeable.rootNode)
			local distance = MathUtil.vector3Length(x - px, y - py, z - pz)

			if distance < placeable.spec_sandboxPlaceable.sandboxRadius and distance < nearestDistance then
				nearestDistance = distance
				nearestRootPlaceable = placeable
			end
		end
	end

	if nearestRootPlaceable == nil and not self:canBeSandboxRoot() then
		return false, g_i18n:getText("warning_noSandboxRootFound")
	end

	return true, nil, nearestRootPlaceable
end

function SandboxPlaceable:addStandaloneSandboxChildrenInRange(farmId)
	local spec = self.spec_sandboxPlaceable
	local sandboxPlaceables = g_currentMission.placeableSystem:getSandboxPlaceables(farmId)

	for _, placeable in pairs(sandboxPlaceables) do
		if not placeable:isSandboxRoot() and placeable:getSandboxRootPlaceable() == nil then
			local x, y, z = getWorldTranslation(self.rootNode)
			local px, py, pz = getWorldTranslation(placeable.rootNode)
			local distance = MathUtil.vector3Length(x - px, y - py, z - pz)

			if distance < spec.sandboxRadius then
				placeable:setSandboxRootPlaceable(self)
				self:addSandboxPlaceableChild(placeable)
			end
		end
	end
end

function SandboxPlaceable:getSandboxType()
	local spec = self.spec_sandboxPlaceable

	return spec.type
end

function SandboxPlaceable:getSandboxTypeName()
	local spec = self.spec_sandboxPlaceable

	return SandboxPlaceable.TYPE_NAME[spec.type]
end

function SandboxPlaceable:getDistibutionPerFillType(fillTypeIndex)
	local spec = self.spec_sandboxPlaceable

	if spec.distributionsPerFillType[fillTypeIndex] ~= nil then
		return spec.distributionsPerFillType[fillTypeIndex]
	end

	return 0
end

function SandboxPlaceable:getFeedingPipeParams()
	local spec = self.spec_sandboxPlaceable

	return spec.feedingPipesRefNode or self.rootNode, spec.fermenterSize or 0
end

function SandboxPlaceable:getSandboxRootName(stripped)
	local spec = self.spec_sandboxPlaceable
	local rootName = ""
	local root = self:isSandboxRoot() and self or spec.sandboxPlaceableRoot

	if root ~= nil and root.spec_sandboxPlaceable.sandboxRootName ~= nil and root.spec_sandboxPlaceable.sandboxRootName ~= "" then
		rootName = root.spec_sandboxPlaceable.sandboxRootName

		if stripped ~= nil and stripped then
			local lastOccurrence = rootName:findLast("%(")

			if lastOccurrence > 0 then
				local tempName = rootName:sub(1, lastOccurrence - 1)
				tempName = tempName:trim()

				if g_currentMission.placeableSystem.rootNameIndex[tempName] ~= nil then
					rootName = tempName
				end
			end
		end
	end

	return rootName
end

function SandboxPlaceable:setSandboxRootName(rootName, noEventSend)
	local spec = self.spec_sandboxPlaceable

	if self:isSandboxRoot() then
		if rootName ~= spec.sandboxRootName then
			if rootName == nil then
				rootName = ""
			end

			local placeableSystem = g_currentMission.placeableSystem

			if placeableSystem.specificSandboxRootNameUsed ~= nil and placeableSystem.specificSandboxRootNameUsed[rootName] then
				if not g_currentMission.isExitingGame and g_currentMission.isMissionStarted and g_gui.showInfoDialog ~= nil and g_currentMission.lastConstructionScreenOpenTime ~= -1 then
					g_gui:showInfoDialog({
						text = g_i18n:getText("warning_specificNameAlreadyUsed"),
						buttonAction = InputAction.MENU_ACCEPT,
						okText = g_i18n:getText("button_ok")
					})
				end

				return
			end

			local isNumericName = false
			local lastName = self:getSandboxRootName(true)

			if placeableSystem.rootNameIndex ~= nil and placeableSystem.rootNameIndex[lastName] ~= nil then
				placeableSystem:releaseRootNameIndex(lastName, self)
			end

			if rootName == spec.rootName or rootName == nil or rootName == "" then
				local num = placeableSystem:getNextFreeRootNameIndex(spec.rootName, self)
				rootName = ("%s (%d) "):format(spec.rootName, num)
				isNumericName = true
			end

			if rootName ~= "" and not isNumericName and placeableSystem.specificSandboxRootNameUsed ~= nil then
				if placeableSystem.specificSandboxRootNameUsed[lastName] then
					placeableSystem.specificSandboxRootNameUsed[lastName] = nil
				end

				placeableSystem.specificSandboxRootNameUsed[rootName] = true
			end

			SandboxPlaceableRootNameEvent.sendEvent(self, rootName, noEventSend)

			spec.sandboxRootName = rootName

			g_messageCenter:publish(MessageType.UNLOADING_STATIONS_CHANGED)
			g_messageCenter:publish(MessageType.LOADING_STATIONS_CHANGED)
		end
	else
		spec.sandboxRootName = ""
	end
end

function SandboxPlaceable:getUtilizationPercentage()
	return 0, nil
end

function SandboxPlaceable:getName(superFunc, stripped)
	local name = superFunc(self)

	if stripped ~= nil and stripped then
		return name
	end

	local sandboxRootName = self:getSandboxRootName()

	if sandboxRootName == "" then
		return name
	end

	return ("%s: %s"):format(sandboxRootName, name)
end

function SandboxPlaceable:getCanBePlacedAt(superFunc, x, y, z, farmId)
	local canBePlaced, errorMessage = superFunc(self, x, y, z, farmId)

	if not canBePlaced then
		return false, errorMessage
	end

	local spec = self.spec_sandboxPlaceable

	if spec.requiresSandboxRoot then
		canBePlaced, errorMessage = self:getSandboxRootInRange(x, y, z, farmId)
	end

	return canBePlaced, errorMessage
end

function SandboxPlaceable:getHasOverlap(superFunc, x, y, z, rotY, checkFunc)
	local function nodeIsSandboxInfoTrigger(hitObjectId)
		if hitObjectId ~= g_currentMission.terrainRootNode then
			local farmId = g_currentMission:getFarmId()
			local sandboxPlaceables = g_currentMission.placeableSystem:getSandboxPlaceables(farmId)

			for _, sandboxPlaceable in pairs(sandboxPlaceables) do
				if sandboxPlaceable.spec_infoTrigger ~= nil and sandboxPlaceable.spec_infoTrigger.infoTrigger ~= nil and sandboxPlaceable.spec_infoTrigger.infoTrigger == hitObjectId then
					return false
				end
			end

			return true
		end

		return false
	end

	return superFunc(self, x, y, z, rotY, nodeIsSandboxInfoTrigger)
end
