local function inject_placeablesLoadFinished(placeableSystem, superFunc, loadingData)
	placeableSystem:finalizeSandboxRoots()
	superFunc(placeableSystem, loadingData)
end

local function inject_getProductionPointsForFarmId(productionChainManager, superFunc, farmId)
	local productionPoints = {}

	if productionChainManager.farmIds[farmId] ~= nil then
		for _, productionPoint in pairs(productionChainManager.farmIds[farmId].productionPoints) do
			if productionPoint.owningPlaceable ~= nil and productionPoint.owningPlaceable.isSandboxRoot ~= nil then
				if productionPoint.owningPlaceable:isSandboxRoot() then
					local placeablesToAdd = productionPoint.owningPlaceable:getMergedPlaceables()

					for _, placeable in ipairs(placeablesToAdd) do
						productionPoint = SandboxPlaceableProductionPoint.getPlaceableProductionPoint(placeable)

						if productionPoint ~= nil then
							table.insert(productionPoints, productionPoint)
						end
					end
				end
			else
				table.insert(productionPoints, productionPoint)
			end
		end
	end

	return productionPoints
end

local function unloadingStation_startFx(unloadingStation, superFunc, fillType)
	superFunc(unloadingStation, fillType)

	if unloadingStation.owningPlaceable ~= nil and unloadingStation.owningPlaceable.raiseActivationTime ~= nil then
		unloadingStation.owningPlaceable:raiseActivationTime(SandboxPlaceableBunker.RAISETIME_END_FILL)
	end
end

local function unloadingStation_registerXMLPaths(schema, basePath)
	schema:register(XMLValueType.STRING, basePath .. "#forcedFillTypeCategories", "Forced fill type categories")
	schema:register(XMLValueType.STRING, basePath .. "#forcedFillTypes", "List of forced fill types")
end

local function unloadingStation_load(unloadingStation, superFunc, components, xmlFile, key, customEnv, i3dMappings, rootNode)
	local loaded = superFunc(unloadingStation, components, xmlFile, key, customEnv, i3dMappings, rootNode)
	local forcedFillTypes = g_fillTypeManager:getFillTypesFromXML(xmlFile, key .. "#forcedFillTypeCategories", key .. "#forcedFillTypes", false)
	unloadingStation.forcedFillTypes = table.swap(forcedFillTypes)

	unloadingStation:updateSupportedFillTypes()

	return loaded
end

local function unloadingStation_updateSupportedFillTypes(unloadingStation)
	if unloadingStation.forcedFillTypes ~= nil then
		for forcedFillType in pairs(unloadingStation.forcedFillTypes) do
			unloadingStation.supportedFillTypes[forcedFillType] = true
		end
	end
end

local function inject_setPlaceable(self, placeable)
	if self.updateRenameSandboxButton ~= nil then
		self:updateRenameSandboxButton(placeable)
	end
end

local function inject_updateDetails(self)
	if self.updateUtilization ~= nil then
		local hasPoints = self.chainManager and #self:getProductionPoints() > 0

		self:updateUtilization(hasPoints)
	end
end

local function updateUtilizationMenuButtons(self)
	if self.updateUtilizationMenuButtons ~= nil then
		self:updateUtilizationMenuButtons()
	end
end

local function inject_registerAnimationNodesXMLPaths(schema, basePath)
	schema:setXMLSharedRegistration("AnimationNode", basePath)
	LinearAnimation.registerAnimationClassXMLPaths(schema, basePath .. ".animationNode(?)")
	schema:setXMLSharedRegistration()
end

local function inject_setDetailAttributes(self, storeItem, displayItem)
	if displayItem ~= nil then
		local sandboxProductionAttributeIndex, sandboxBunkerAttributeIndex = nil

		for index, attribute in ipairs(self.attrValue) do
			if attribute.text:startsWith("$SANDBOX_CON") then
				sandboxProductionAttributeIndex = index

				if displayItem.sandboxBunkerFillTypesIconFilenames == nil then
					break
				end
			elseif attribute.text:startsWith("table:") then
				sandboxBunkerAttributeIndex = index
			end
		end

		if sandboxProductionAttributeIndex ~= nil then
			local textParts = self.attrValue[sandboxProductionAttributeIndex].text:split("$1")

			if #textParts >= 0 then
				local fillType = g_fillTypeManager:getFillTypeByName(textParts[2]:trim())

				if fillType ~= nil then
					self:assignItemFillTypesData("constructionListAttributeIconInput", {
						fillType.hudOverlayFilename
					}, sandboxProductionAttributeIndex)

					local imageUVs = GuiUtils.getUVs("390px 294px 36px 36px")

					self.attrIcon[sandboxProductionAttributeIndex]:setImageUVs(nil, unpack(imageUVs))
					self.attrValue[sandboxProductionAttributeIndex]:setVisible(true)
					self.attrValue[sandboxProductionAttributeIndex]:setText(textParts[3])
					self.attrValue[sandboxProductionAttributeIndex]:updateAbsolutePosition()
				end
			end
		end

		if sandboxBunkerAttributeIndex ~= nil and displayItem.sandboxBunkerFillTypesIconFilenames ~= nil then
			self:assignItemFillTypesData("constructionListAttributeIconInput", displayItem.sandboxBunkerFillTypesIconFilenames, sandboxBunkerAttributeIndex)
			self.attrValue[sandboxBunkerAttributeIndex]:setText("")
		end
	end

	self.detailsAttributesLayout:invalidateLayout()
end

local function inject_makeDisplayItem(self, superFunc, storeItem, realItem, configurations, saleItem)
	local shopDisplayItem = superFunc(self, storeItem, realItem, configurations, saleItem)

	if shopDisplayItem ~= nil then
		local sandboxBunkerFillTypesSpec = self.storeManager:getSpecTypeByName("sandboxBunkerFillTypes")

		local function getIconFilenamesForSpec(spec, _storeItem, _realItem, _configurations)
			local iconFilenames = {}

			if spec ~= nil then
				local fillTypeIndicesList = spec.getValueFunc(_storeItem, _realItem, _configurations)

				if fillTypeIndicesList ~= nil then
					for _, fillTypeIndex in ipairs(fillTypeIndicesList) do
						local fillType = self.fillTypeManager:getFillTypeByIndex(fillTypeIndex)

						if fillType ~= nil then
							table.insert(iconFilenames, fillType.hudOverlayFilename)
						end
					end
				end
			end

			return iconFilenames
		end

		if storeItem.bundleInfo == nil then
			shopDisplayItem.sandboxBunkerFillTypesIconFilenames = getIconFilenamesForSpec(sandboxBunkerFillTypesSpec, storeItem, realItem)
		end
	end

	return shopDisplayItem
end

local function inject_addFillUnitFillLevel(unloadTrigger, superFunc, farmId, fillUnitIndex, fillLevelDelta, fillTypeIndex, toolType, fillPositionData, extraAttributes)
	local target = unloadTrigger:getTarget()

	if fillTypeIndex ~= FillType.DIGESTATE and fillTypeIndex ~= FillType.LIQUIDMANURE or target == nil or target.owningPlaceable == nil or target.owningPlaceable.isSandboxPlaceable == nil or target.owningPlaceable:getSandboxRootPlaceable() == nil then
		return superFunc(unloadTrigger, farmId, fillUnitIndex, fillLevelDelta, fillTypeIndex, toolType, fillPositionData, extraAttributes)
	end

	if fillTypeIndex == FillType.LIQUIDMANURE then
		local fillTypeConversion = unloadTrigger.fillTypeConversions[FillType.DIGESTATE]

		if fillTypeConversion ~= nil then
			local ratio = fillTypeConversion.ratio
			local applied = unloadTrigger.target:addFillLevelFromTool(farmId, fillLevelDelta / ratio, FillType.DIGESTATE, fillPositionData, toolType, extraAttributes or unloadTrigger.extraAttributes)

			return applied * ratio
		end
	end

	return unloadTrigger.target:addFillLevelFromTool(farmId, fillLevelDelta, fillTypeIndex, fillPositionData, toolType, extraAttributes or unloadTrigger.extraAttributes)
end

function pnh_overwrite_sandbox_init()
	pnh_overwrite.appendedFunction(AnimationManager, "registerAnimationNodesXMLPaths", inject_registerAnimationNodesXMLPaths)
	pnh_overwrite.appendedFunction(UnloadingStation, "registerXMLPaths", unloadingStation_registerXMLPaths)
end

function pnh_overwrite_sandbox()
	pnh_overwrite.overwrittenFunction(PlaceableSystem, "loadFinished", inject_placeablesLoadFinished)
	pnh_overwrite.appendedFunction(PlaceableSystem, "removePlaceable", PlaceableSystem.removeSandboxPlaceable)
	pnh_overwrite.appendedFunction(PlaceableSystem, "addPlaceable", PlaceableSystem.addSandboxPlaceable)
	pnh_overwrite.overwrittenFunction(ProductionChainManager, "getProductionPointsForFarmId", inject_getProductionPointsForFarmId)
	pnh_overwrite.overwrittenFunction(UnloadingStation, "startFx", unloadingStation_startFx)
	pnh_overwrite.overwrittenFunction(UnloadingStation, "load", unloadingStation_load)
	pnh_overwrite.appendedFunction(UnloadingStation, "updateSupportedFillTypes", unloadingStation_updateSupportedFillTypes)
	pnh_overwrite.appendedFunction(PlaceableInfoDialog, "setPlaceable", inject_setPlaceable)
	pnh_overwrite.appendedFunction(InGameMenuProductionFrame, "updateDetails", inject_updateDetails)
	pnh_overwrite.appendedFunction(InGameMenuProductionFrame, "updateMenuButtons", updateUtilizationMenuButtons)
	pnh_overwrite.overwrittenFunction(InGameMenuProductionFrame, "populateCellForItemInSection", InGameMenuProductionFrame.inject_populateCellForItemInSection)
	pnh_overwrite.overwrittenFunction(InGameMenuProductionFrame, "getTitleForSectionHeader", InGameMenuProductionFrame.inject_getTitleForSectionHeader)
	pnh_overwrite.appendedFunction(ConstructionScreen, "setDetailAttributes", inject_setDetailAttributes)
	pnh_overwrite.overwrittenFunction(ShopController, "makeDisplayItem", inject_makeDisplayItem)
	pnh_overwrite.overwrittenFunction(UnloadTrigger, "addFillUnitFillLevel", inject_addFillUnitFillLevel)
end
