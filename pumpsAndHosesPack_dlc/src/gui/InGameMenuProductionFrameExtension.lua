function InGameMenuProductionFrame:updateUtilization(hasPoints)
	local function updateDetailUtilizationBoxBoxHeight(utilizationBoxHeight, frameThickness)
		if self.detailsBox.backupSize ~= nil then
			local detailsBoxHeight = self.detailsBox.backupSize[2]

			if utilizationBoxHeight ~= nil and utilizationBoxHeight > 0 then
				detailsBoxHeight = detailsBoxHeight - utilizationBoxHeight

				if frameThickness ~= nil then
					detailsBoxHeight = detailsBoxHeight - frameThickness
				end
			end

			self.detailsBox:setSize(self.detailsBox.backupSize[1], detailsBoxHeight)
		end
	end

	if not self.createdSandboxUtilization then
		self.detailsBox.backupSize = {
			self.detailsBox.size[1],
			self.detailsBox.size[2]
		}
		self.utilizationBox = BitmapElement.new(self.detailsBox)

		self.utilizationBox:applyProfile("ingameMenuProductionStorageBox", true)

		self.utilizationBox.id = "utilizationBox"

		self.detailsBox:addElement(self.utilizationBox)
		self.utilizationBox:updateScreenAlign(InGameMenuMapUtil.CONTEXT_BOX_ORIENTATION.BOTTOM_LEFT)

		local maxSizeX = 0
		local maxSizeY = 0
		local typeThickness = GuiUtils.getNormalizedValues("110px", self.detailsBox.outputSize)
		self.utilizationTypes = {}

		for i, name in pairs({
			"TORCH",
			"POWERPLANT",
			"BUNKER",
			"FERMENTER"
		}) do
			local boxElement = nil
			boxElement, _, maxSizeY = self:createUtilizationBoxElement(maxSizeX, maxSizeY, self.utilizationBox.size[1], typeThickness[1], name, self.utilizationBox)

			if boxElement.alternateBackgroundLoaded then
				if i % 2 == 0 then
					boxElement:setImageColor(GuiOverlay.STATE_NORMAL, unpack(boxElement.alternateBackgroundColor))
				else
					boxElement:setImageColor(GuiOverlay.STATE_NORMAL, unpack(boxElement.backgroundColor))
				end
			end

			boxElement:applyScreenAlignment()
			table.addElement(self.utilizationTypes, boxElement)
		end

		self.utilizationHeader = self.recipeText:clone()
		self.utilizationHeader.id = "utilizationHeader"

		self.utilizationBox:addElement(self.utilizationHeader)

		local text = g_i18n:getText("ui_sandboxUtilization"):format("Sandbox")

		self.utilizationHeader:setText(text)

		self.utilizationHeader.textBold = true

		self.utilizationHeader:setPosition(maxSizeX + 0.01, maxSizeY)

		maxSizeY = maxSizeY + self.utilizationHeader:getTextHeight()
		local frameThickness = GuiUtils.getNormalizedValues("25px 15px", self.detailsBox.outputSize)
		maxSizeY = maxSizeY + frameThickness[2]
		self.utilizationBox.maxSizeY = maxSizeY
		self.utilizationBox.frameThickness = frameThickness[1] / 2
		local y = self.detailsBox.position[2]

		self.utilizationBox:setSize(self.detailsBox.size[1], maxSizeY)
		self.utilizationBox:setPosition(nil, y - maxSizeY - self.utilizationBox.frameThickness)

		self.createdSandboxUtilization = true
	end

	local hasSandboxPoint = hasPoints and self.selectedProductionPoint ~= nil and self.selectedProductionPoint.owningPlaceable ~= nil and self.selectedProductionPoint.owningPlaceable.isSandboxPlaceable ~= nil and self.selectedProductionPoint.owningPlaceable:isSandboxPlaceable()

	if self.utilizationBox ~= nil then
		self.utilizationBox:setVisible(hasSandboxPoint)

		if hasSandboxPoint then
			updateDetailUtilizationBoxBoxHeight(self.utilizationBox.maxSizeY, self.utilizationBox.frameThickness)
			self:updateUtilizationOverviews()
		else
			updateDetailUtilizationBoxBoxHeight()
		end
	else
		updateDetailUtilizationBoxBoxHeight()
	end
end

function InGameMenuProductionFrame:createUtilizationBoxElement(x, y, sizeX, sizeY, typeName, parent)
	local boxElement = BitmapElement.new(self.detailsBox)

	boxElement:applyProfile("ingameMenuProductionStorageBox", true)

	boxElement.id = typeName

	parent:addElement(boxElement)
	boxElement:updateScreenAlign(InGameMenuMapUtil.CONTEXT_BOX_ORIENTATION.BOTTOM_LEFT)

	if not boxElement.alternateBackgroundLoaded then
		boxElement.backgroundColor = table.copy(GuiOverlay.getOverlayColor(boxElement.overlay, GuiOverlay.STATE_NORMAL))
		boxElement.alternateBackgroundColor = GuiUtils.getColorArray("0.3140 0.8069 1.0000 0.08")
		boxElement.alternateBackgroundLoaded = true
	end

	boxElement:setPosition(x, y)
	boxElement:setSize(sizeX, sizeY)

	local leftBorder = sizeX * 0.05
	local rightBorder = sizeX * 0.86 + leftBorder
	local typeText = self.recipeText:clone()
	typeText.id = "typeText"

	boxElement:addElement(typeText)
	typeText:applyProfile("ingameMenuProductionStorageTitle", true)
	typeText:updateScreenAlign(InGameMenuMapUtil.CONTEXT_BOX_ORIENTATION.TOP_LEFT)
	typeText:setPosition(leftBorder, nil)

	local text = g_i18n:getText(SandboxPlaceable.TYPE_NAME_TO_I18N_MAPPING[typeName])

	typeText:setText(text)

	local percentage = self.recipeText:clone()
	percentage.id = "percentage"

	boxElement:addElement(percentage)
	percentage:applyProfile("ingameMenuProductionStorageLevel", true)
	percentage:setFormat(TextElement.FORMAT.PERCENTAGE)
	percentage:setValue(0)

	local utilizationText = self.recipeText:clone()
	utilizationText.id = "utilizationText"

	boxElement:addElement(utilizationText)
	utilizationText:applyProfile("ingameMenuProductionStorageMode", true)
	utilizationText:updateScreenAlign(InGameMenuMapUtil.CONTEXT_BOX_ORIENTATION.BOTTOM_LEFT)
	utilizationText:setPosition(leftBorder, -sizeY * 0.01)

	text = SandboxPlaceable.UTILIZATION_STATE_TO_I18N_MAPPING[SandboxPlaceable.UTILIZATION_STATE.UNKNOWN]

	utilizationText:setText(text)

	local sourceBar = self.storageList.cellDatabase.outputCell:getAttribute("bar")
	local barBackgroundElement = sourceBar:clone()

	barBackgroundElement:applyProfile("ingameMenuProductionStorageBarBackground", true)
	boxElement:addElement(barBackgroundElement)
	barBackgroundElement:updateScreenAlign(InGameMenuMapUtil.CONTEXT_BOX_ORIENTATION.BOTTOM_LEFT)
	barBackgroundElement:setPosition(leftBorder, sizeY * 0.38)
	barBackgroundElement:setSize(rightBorder, nil)

	local barElement = sourceBar:clone()
	barElement.id = "visualBar"

	barBackgroundElement:addElement(barElement)
	self:setUtilizationStatusBarValue(barElement, 0, SandboxPlaceable.UTILIZATION_STATE.UNKNOWN)

	return boxElement, x + boxElement.absSize[1], y + boxElement.absSize[2]
end

function InGameMenuProductionFrame:getElementById(element, id, recursive)
	local result = nil

	for i = 1, #element.elements do
		if element.elements[i].id == id then
			result = element.elements[i]

			break
		end

		if recursive and result == nil then
			result = self:getElementById(element.elements[i], id, recursive)

			if result ~= nil then
				break
			end
		end
	end

	return result
end

function InGameMenuProductionFrame:updateUtilizationOverviews()
	for _, utilizationBox in ipairs(self.utilizationTypes) do
		if utilizationBox.id ~= nil and self.selectedProductionPoint ~= nil and self.selectedProductionPoint.owningPlaceable ~= nil and self.selectedProductionPoint.owningPlaceable.getUtilizationPercentage ~= nil then
			local productionPointPlaceable = self.selectedProductionPoint.owningPlaceable

			if not productionPointPlaceable:isSandboxRoot() then
				productionPointPlaceable = productionPointPlaceable:getSandboxRootPlaceable()
			end

			local sandboxType = nil

			for type, name in pairs(SandboxPlaceable.TYPE_NAME) do
				if name == utilizationBox.id:upper() then
					sandboxType = type

					break
				end
			end

			if productionPointPlaceable ~= nil and sandboxType ~= nil then
				local text = g_i18n:getText("ui_sandboxUtilization"):format(productionPointPlaceable:getSandboxRootName(false))

				self.utilizationHeader:setText(text)

				local mergedPlaceables = productionPointPlaceable:getMergedPlaceables()
				local mergedPlaceable = mergedPlaceables[sandboxType]
				local percentage = 0
				local specificMessage, forcedUtilizationState = nil

				if mergedPlaceable ~= nil then
					percentage, specificMessage, forcedUtilizationState = mergedPlaceable:getUtilizationPercentage()
				else
					specificMessage = g_i18n:getText("sandboxUtilization_typeRequired")
				end

				local utilizationState = SandboxPlaceable.UTILIZATION_STATE.RUNNING_BAD

				if percentage > 1 then
					utilizationState = SandboxPlaceable.UTILIZATION_STATE.RUNNING_LIMIT
				elseif percentage >= 0.75 and percentage <= 1 then
					utilizationState = SandboxPlaceable.UTILIZATION_STATE.RUNNING_PERFECT
				elseif percentage > 0.25 and percentage < 0.75 then
					utilizationState = SandboxPlaceable.UTILIZATION_STATE.RUNNING_OK
				end

				if forcedUtilizationState ~= nil then
					utilizationState = forcedUtilizationState

					if utilizationState == SandboxPlaceable.UTILIZATION_STATE.RUNNING_NOT then
						percentage = 0
					end
				end

				if type ~= SandboxPlaceable.TYPE_TORCH then
					percentage = math.min(percentage, 1)
				end

				local percentageElement = self:getElementById(utilizationBox, "percentage", true)

				if percentageElement ~= nil then
					percentageElement:setValue(percentage)
				end

				local visualBarElement = self:getElementById(utilizationBox, "visualBar", true)

				if visualBarElement ~= nil then
					self:setUtilizationStatusBarValue(visualBarElement, percentage, utilizationState)
				end

				local utilizationTextElement = self:getElementById(utilizationBox, "utilizationText", true)

				if utilizationTextElement ~= nil then
					text = g_i18n:getText(SandboxPlaceable.UTILIZATION_STATE_TO_I18N_MAPPING[utilizationState])

					if specificMessage ~= nil and specificMessage ~= "" then
						text = specificMessage
					end

					utilizationTextElement:setText(text)
				end
			end
		end
	end
end

function InGameMenuProductionFrame:setUtilizationStatusBarValue(statusBarElement, value, utilizationState)
	local profile = "workshopStatusBarWarning"

	if utilizationState == SandboxPlaceable.UTILIZATION_STATE.UNKNOWN then
		value = 0
	elseif utilizationState == SandboxPlaceable.UTILIZATION_STATE.RUNNING_PERFECT then
		profile = "workshopStatusBar"
	elseif utilizationState == SandboxPlaceable.UTILIZATION_STATE.RUNNING_BAD or utilizationState == SandboxPlaceable.UTILIZATION_STATE.RUNNING_LIMIT then
		profile = "workshopStatusBarDanger"
	end

	statusBarElement:applyProfile(profile)

	local fullWidth = statusBarElement.parent.absSize[1] - statusBarElement.margin[1] * 2
	local minSize = 0

	if statusBarElement.startSize ~= nil then
		minSize = statusBarElement.startSize[1] + statusBarElement.endSize[1]
	end

	statusBarElement:setSize(math.max(minSize, fullWidth * math.min(1, value)), nil)
end

function InGameMenuProductionFrame:updateUtilizationMenuButtons()
	if self.buyLiquidManureButtonInfo == nil then
		self.buyLiquidManureButtonInfo = {
			profile = "buttonExtra1",
			inputAction = InputAction.MENU_EXTRA_1,
			text = g_i18n:getText("ui_buy"),
			callback = function ()
				self:onButtonBuyFillType()
			end
		}
	end

	if FocusManager:getFocusedElement() ~= self.productionList then
		local _, productionPoint = self:getSelectedProduction()
		local _, isInput = self:getSelectedStorageFillType()

		if isInput and productionPoint.owningPlaceable.isSandboxRoot ~= nil and productionPoint.owningPlaceable:isSandboxRoot() then
			table.insert(self.menuButtonInfo, self.buyLiquidManureButtonInfo)
		end
	end

	self:setMenuButtonInfoDirty()
end

function InGameMenuProductionFrame:onButtonBuyFillType()
	local _, productionPoint = self:getSelectedProduction()
	local fillType, isInput = self:getSelectedStorageFillType()

	if fillType ~= FillType.UNKNOWN and isInput then
		local data = {}

		for _, storage in pairs(productionPoint.unloadingStation.targetStorages) do
			for sfillType in pairs(storage:getFillLevels()) do
				if sfillType == fillType then
					if data[fillType] == nil then
						data[fillType] = 0
					end

					data[fillType] = data[fillType] + storage:getFreeCapacity(fillType)
				end
			end
		end

		g_gui:showRefillDialog({
			data = data,
			priceFactor = PlaceableSilo.REFILL_PRICE_FACTOR * EconomyManager.getPriceMultiplier(),
			callback = productionPoint.owningPlaceable.refillAmount,
			target = productionPoint.owningPlaceable
		})
	end

	self.storageList:reloadData()
end

function InGameMenuProductionFrame:inject_populateCellForItemInSection(superFunc, list, section, index, cell)
	superFunc(self, list, section, index, cell)

	if cell:getAttribute("outputMode") ~= nil then
		local _, productionPoint = self:getSelectedProduction()
		local fillType = nil

		if section == 1 then
			fillType = self.selectedProductionPoint.inputFillTypeIdsArray[index]
		else
			fillType = self.selectedProductionPoint.outputFillTypeIdsArray[index]
		end

		if fillType ~= FillType.UNKNOWN then
			local outputMode = productionPoint:getOutputDistributionMode(fillType)

			if outputMode == ProductionPoint.OUTPUT_MODE.AUTO_DISTRIBUTION then
				local outputModeText = g_i18n:getText("ui_production_output_auto_distribution")

				cell:getAttribute("outputMode"):setText(outputModeText)
			end
		end
	end
end

function InGameMenuProductionFrame:inject_getTitleForSectionHeader(superFunc, list, section)
	if list == self.productionList then
		local productionPoint = self:getProductionPoints()[section]

		if productionPoint.owningPlaceable.isSandboxPlaceable ~= nil and productionPoint.owningPlaceable:isSandboxPlaceable() then
			local sandboxRootName = productionPoint.owningPlaceable:getSandboxRootName(false)
			local typeName = productionPoint.owningPlaceable:getSandboxTypeName()
			typeName = g_i18n:getText(SandboxPlaceable.TYPE_NAME_TO_I18N_MAPPING[typeName])

			if sandboxRootName ~= nil and typeName ~= nil then
				return ("%s: %s"):format(sandboxRootName, typeName)
			end
		end
	end

	return superFunc(self, list, section)
end
