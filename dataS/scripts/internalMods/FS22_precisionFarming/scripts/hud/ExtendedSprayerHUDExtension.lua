ExtendedSprayerHUDExtension = {
	MOD_NAME = g_currentModName,
	MOD_DIR = g_currentModDirectory
}
ExtendedSprayerHUDExtension.GUI_ELEMENTS = ExtendedSprayerHUDExtension.MOD_DIR .. "gui/ui_elements.png"
local ExtendedSprayerHUDExtension_mt = Class(ExtendedSprayerHUDExtension, VehicleHUDExtension)

function ExtendedSprayerHUDExtension.new(vehicle, uiScale, uiTextColor, uiTextSize)
	local self = VehicleHUDExtension.new(ExtendedSprayerHUDExtension_mt, vehicle, uiScale, uiTextColor, uiTextSize)
	self.extendedSprayer = vehicle.spec_extendedSprayer
	self.validVehicle = self:getIsVehicleValid(vehicle)
	self.realVehicle = self.validVehicle and vehicle or nil
	self.pHGradientUVs = GuiUtils.getUVs(ExtendedSprayerHUDExtension.UV.PH_GRADIENT)
	self.pHGradientUVsInactive = GuiUtils.getUVs(ExtendedSprayerHUDExtension.UV.PH_GRADIENT)
	self.nGradientUVs = GuiUtils.getUVs(ExtendedSprayerHUDExtension.UV.N_GRADIENT)
	self.nGradientUVsInactive = GuiUtils.getUVs(ExtendedSprayerHUDExtension.UV.N_GRADIENT)
	self.colorBlindGradientUVs = GuiUtils.getUVs(ExtendedSprayerHUDExtension.UV.COLOR_BLIND_GRADIENT)
	self.colorBlindGradientUVsInactive = GuiUtils.getUVs(ExtendedSprayerHUDExtension.UV.COLOR_BLIND_GRADIENT)
	self.pixelSizeX, self.pixelSizeY = getNormalizedScreenValues(1 * uiScale, 1 * uiScale)
	local width, height = getNormalizedScreenValues(370 * uiScale, 8 * uiScale)
	self.gradient = Overlay.new(ExtendedSprayerHUDExtension.GUI_ELEMENTS, 0, 0, width, height)

	self.gradient:setUVs(self.pHGradientUVs)
	self.gradient:setColor(1, 1, 1, 1)
	self:addComponentForCleanup(self.gradient)

	self.gradientInactive = Overlay.new(ExtendedSprayerHUDExtension.GUI_ELEMENTS, 0, 0, width, height)

	self.gradientInactive:setUVs(self.pHGradientUVs)
	self.gradientInactive:setColor(0.4, 0.4, 0.4, 1)
	self:addComponentForCleanup(self.gradientInactive)

	width, height = getNormalizedScreenValues(3 * uiScale, 20 * uiScale)
	self.actualBar = Overlay.new(g_baseUIFilename, 0, 0, width, height)

	self.actualBar:setUVs(g_colorBgUVs)
	self.actualBar:setColor(unpack(ExtendedSprayerHUDExtension.COLOR.ACTUAL_BAR))
	self:addComponentForCleanup(self.actualBar)

	width, height = getNormalizedScreenValues(2.5 * uiScale, 5 * uiScale)
	self.targetBar = Overlay.new(ExtendedSprayerHUDExtension.GUI_ELEMENTS, 0, 0, width, height)

	self.targetBar:setUVs(GuiUtils.getUVs(ExtendedSprayerHUDExtension.UV.TARGET_BAR))
	self:addComponentForCleanup(self.targetBar)

	width, height = getNormalizedScreenValues(23 * uiScale, 29 * uiScale)
	self.targetFlag = Overlay.new(ExtendedSprayerHUDExtension.GUI_ELEMENTS, 0, 0, width, height)

	self.targetFlag:setUVs(GuiUtils.getUVs(ExtendedSprayerHUDExtension.UV.TARGET_FLAG))
	self:addComponentForCleanup(self.targetFlag)

	width, height = getNormalizedScreenValues(3 * uiScale, 14 * uiScale)
	self.setValueBar = Overlay.new(g_baseUIFilename, 0, 0, width, height)

	self.setValueBar:setUVs(g_colorBgUVs)
	self.setValueBar:setColor(unpack(ExtendedSprayerHUDExtension.COLOR.SET_VALUE_BAR_GOOD))
	self:addComponentForCleanup(self.setValueBar)

	width, height = getNormalizedScreenValues(430 * uiScale, 1 * uiScale)
	self.footerSeparationBar = Overlay.new(g_baseUIFilename, 0, 0, width, height)

	self.footerSeparationBar:setUVs(g_colorBgUVs)
	self.footerSeparationBar:setColor(unpack(ExtendedSprayerHUDExtension.COLOR.SEPARATOR_BAR))
	self:addComponentForCleanup(self.footerSeparationBar)

	local _, displayHeight = getNormalizedScreenValues(0, 130 * uiScale)
	self.displayHeight = displayHeight
	local _, additionalTextHeightOffset = getNormalizedScreenValues(0, 30 * uiScale)
	self.additionalTextHeightOffset = additionalTextHeightOffset
	local _, invalidHeightOffset = getNormalizedScreenValues(0, 60 * uiScale)
	self.invalidHeightOffset = invalidHeightOffset
	local _, noSetBarHeightOffset = getNormalizedScreenValues(0, 20 * uiScale)
	self.noSetBarHeightOffset = noSetBarHeightOffset
	self.additionalDisplayHeight = 0
	_, self.textHeightHeadline = getNormalizedScreenValues(0, 20 * uiScale)
	_, self.textHeight = getNormalizedScreenValues(0, 15 * uiScale)
	self.uiTextColor = uiTextColor
	self.gradientPosX, self.gradientPosY = getNormalizedScreenValues(0, -75 * uiScale)
	_, self.footerOffset = getNormalizedScreenValues(0, 9 * uiScale)
	self.actualPos = 0.34
	self.targetPos = 0.8
	self.actualValue = 0
	self.actualValueStr = "%.3f"
	self.setValue = 0
	self.targetValue = 0
	self.hasValidValues = false
	self.soilMap = g_precisionFarming.soilMap
	self.pHMap = g_precisionFarming.pHMap
	self.nitrogenMap = g_precisionFarming.nitrogenMap
	self.texts = {
		headline_ph_lime = g_i18n:getText("hudExtensionSprayer_headline_ph_lime", ExtendedSprayerHUDExtension.MOD_NAME),
		headline_n_solidFertilizer = g_i18n:getText("hudExtensionSprayer_headline_n_solidFertilizer", ExtendedSprayerHUDExtension.MOD_NAME),
		headline_n_liquidFertilizer = g_i18n:getText("hudExtensionSprayer_headline_n_liquidFertilizer", ExtendedSprayerHUDExtension.MOD_NAME),
		headline_n_slurryTanker = g_i18n:getText("hudExtensionSprayer_headline_n_slurryTanker", ExtendedSprayerHUDExtension.MOD_NAME),
		headline_n_manureSpreader = g_i18n:getText("hudExtensionSprayer_headline_n_manureSpreader", ExtendedSprayerHUDExtension.MOD_NAME),
		actualValue = g_i18n:getText("hudExtensionSprayer_actualValue", ExtendedSprayerHUDExtension.MOD_NAME),
		newValue = g_i18n:getText("hudExtensionSprayer_newValue", ExtendedSprayerHUDExtension.MOD_NAME),
		targetReached = g_i18n:getText("hudExtensionSprayer_targetReached", ExtendedSprayerHUDExtension.MOD_NAME),
		applicationRate = g_i18n:getText("hudExtensionSprayer_applicationRate", ExtendedSprayerHUDExtension.MOD_NAME),
		soilType = g_i18n:getText("hudExtensionSprayer_soilType", ExtendedSprayerHUDExtension.MOD_NAME),
		unknown = g_i18n:getText("hudExtensionSprayer_unknown", ExtendedSprayerHUDExtension.MOD_NAME),
		automaticShort = g_i18n:getText("hudExtensionSprayer_automaticShort", ExtendedSprayerHUDExtension.MOD_NAME),
		description_limeAuto = g_i18n:getText("hudExtensionSprayer_description_limeAuto", ExtendedSprayerHUDExtension.MOD_NAME),
		description_limeManual = g_i18n:getText("hudExtensionSprayer_description_limeManual", ExtendedSprayerHUDExtension.MOD_NAME),
		description_slurryAuto = g_i18n:getText("hudExtensionSprayer_description_slurryAuto", ExtendedSprayerHUDExtension.MOD_NAME),
		description_manureAuto = g_i18n:getText("hudExtensionSprayer_description_manureAuto", ExtendedSprayerHUDExtension.MOD_NAME),
		description_fertilizerAutoFruit = g_i18n:getText("hudExtensionSprayer_description_fertilizerAutoFruit", ExtendedSprayerHUDExtension.MOD_NAME),
		description_fertilizerAutoNoFruit = g_i18n:getText("hudExtensionSprayer_description_fertilizerAutoNoFruit", ExtendedSprayerHUDExtension.MOD_NAME),
		description_fertilizerAutoNoFruitDefault = g_i18n:getText("hudExtensionSprayer_description_fertilizerAutoNoFruitDefault", ExtendedSprayerHUDExtension.MOD_NAME),
		description_fertilizerManualFruit = g_i18n:getText("hudExtensionSprayer_description_fertilizerManualFruit", ExtendedSprayerHUDExtension.MOD_NAME),
		description_fertilizerManualNoFruit = g_i18n:getText("hudExtensionSprayer_description_fertilizerManualNoFruit", ExtendedSprayerHUDExtension.MOD_NAME),
		description_noFertilizerRequired = g_i18n:getText("hudExtensionSprayer_description_noFertilizerRequired", ExtendedSprayerHUDExtension.MOD_NAME),
		invalidValues = g_i18n:getText("hudExtensionSprayer_invalidValues", ExtendedSprayerHUDExtension.MOD_NAME)
	}
	self.actualValueStr = self.texts.unknown
	self.isColorBlindMode = g_gameSettings:getValue(GameSettings.SETTING.USE_COLORBLIND_MODE) or false

	g_messageCenter:subscribe(MessageType.SETTING_CHANGED[GameSettings.SETTING.USE_COLORBLIND_MODE], self.setColorBlindMode, self)

	return self
end

function ExtendedSprayerHUDExtension:delete()
	ExtendedSprayerHUDExtension:superClass().delete(self)
	g_messageCenter:unsubscribeAll(self)
end

function ExtendedSprayerHUDExtension:setColorBlindMode(isActive)
	if isActive ~= self.isColorBlindMode then
		self.isColorBlindMode = isActive

		self.pHMap:setMinimapRequiresUpdate(true)
		self.nitrogenMap:setMinimapRequiresUpdate(true)
	end
end

function ExtendedSprayerHUDExtension:getPriority()
	return 2
end

function ExtendedSprayerHUDExtension:canDraw()
	local vehicle = self.vehicle
	local spec = vehicle.spec_extendedSprayer

	if spec.attachStateChanged then
		spec.attachStateChanged = false
		local foundVehicle = false
		local vehicleList = vehicle.rootVehicle.childVehicles

		for i = 1, #vehicleList do
			local subVehicle = vehicleList[i]

			if self:getIsVehicleValid(subVehicle) then
				self.validVehicle = true
				self.realVehicle = subVehicle
				foundVehicle = true
			end
		end

		if not foundVehicle then
			self.validVehicle = false
			self.realVehicle = nil
		end
	end

	if not self.validVehicle or self.realVehicle == nil then
		return false
	end

	if not self.vehicle:getIsActiveForInput(true, true) then
		return false
	end

	if self.validVehicle then
		if not spec.isSlurryTanker and not spec.isManureSpreader then
			local sourceVehicle, sourceFillUnitIndex = self:getFillTypeSourceVehicle(self.vehicle)

			if sourceVehicle:getFillUnitFillLevel(sourceFillUnitIndex) <= 0 then
				return false
			end

			spec = self.realVehicle.spec_extendedSprayer

			if not spec.isLiming and not spec.isFertilizing then
				return false
			end
		end

		if vehicle ~= self.realVehicle then
			return false
		end
	end

	return true
end

function ExtendedSprayerHUDExtension:getFillTypeSourceVehicle(sprayer)
	if sprayer:getFillUnitFillLevel(sprayer:getSprayerFillUnitIndex()) <= 0 then
		local spec = sprayer.spec_sprayer

		for _, supportedSprayType in ipairs(spec.supportedSprayTypes) do
			for _, src in ipairs(spec.fillTypeSources[supportedSprayType]) do
				local vehicle = src.vehicle

				if vehicle:getFillUnitFillType(src.fillUnitIndex) == supportedSprayType and vehicle:getFillUnitFillLevel(src.fillUnitIndex) > 0 then
					return vehicle, src.fillUnitIndex
				end
			end
		end
	end

	return sprayer, sprayer:getSprayerFillUnitIndex()
end

function ExtendedSprayerHUDExtension:getIsVehicleValid(vehicle)
	if not SpecializationUtil.hasSpecialization(ExtendedSprayer, vehicle.specializations) then
		return false
	end

	if not SpecializationUtil.hasSpecialization(WorkArea, vehicle.specializations) then
		return false
	end

	if #vehicle.spec_workArea.workAreas == 0 then
		return false
	end

	if SpecializationUtil.hasSpecialization(ManureBarrel, vehicle.specializations) and vehicle.spec_manureBarrel.attachedTool ~= nil then
		return false
	end

	return true
end

function ExtendedSprayerHUDExtension:getDisplayHeight()
	return self:canDraw() and (self.displayHeight or 0) + (self.additionalDisplayHeight or 0)
end

function ExtendedSprayerHUDExtension:getHelpEntryCountReduction()
	return 0
end

local function formatDecimalNumber(n)
	if math.floor(n) == n then
		return string.format("%.1f", n)
	else
		return string.format("%s", n)
	end
end

local function renderDoubleText(x, y, textSize, text, maxWidth)
	if maxWidth ~= nil then
		while maxWidth < getTextWidth(textSize, text) do
			textSize = textSize * 0.98
		end
	end

	setTextColor(0, 0, 0, 1)
	renderText(x, y - 0.0015, textSize, text)
	setTextColor(1, 1, 1, 1)
	renderText(x, y, textSize, text)
end

function ExtendedSprayerHUDExtension:draw(leftPosX, rightPosX, posY)
	if not self:canDraw() then
		return
	end

	local upperPosY = posY + (self.displayHeight or 0) + (self.additionalDisplayHeight or 0)
	local vehicle = self.realVehicle
	local spec = vehicle.spec_extendedSprayer
	local headline = self.texts.headline_ph_lime
	local applicationRate = 0
	local applicationRateReal = 0
	local applicationRateStr = "%.2f t/ha"
	local changeBarText = ""
	local minValue = 0
	local maxValue = 0
	self.hasValidValues = false
	local soilTypeName = ""

	if spec.lastTouchedSoilType ~= 0 and self.soilMap ~= nil then
		local soilType = self.soilMap:getSoilTypeByIndex(spec.lastTouchedSoilType)

		if soilType ~= nil then
			soilTypeName = soilType.name
		end
	end

	local hasLimeLoaded = false
	local fillTypeDesc = nil
	local sourceVehicle, fillUnitIndex = self:getFillTypeSourceVehicle(self.vehicle)
	local sprayFillType = sourceVehicle:getFillUnitFillType(fillUnitIndex)
	fillTypeDesc = g_fillTypeManager:getFillTypeByIndex(sprayFillType)
	local massPerLiter = fillTypeDesc.massPerLiter / FillTypeManager.MASS_SCALE

	if sprayFillType == FillType.LIME then
		hasLimeLoaded = true
	end

	local descriptionText = ""
	local stepResolution = nil
	local enableZeroTargetFlag = false

	if hasLimeLoaded then
		self.gradientInactive:setUVs(self.isColorBlindMode and self.colorBlindGradientUVsInactive or self.pHGradientUVsInactive)
		self.gradient:setUVs(self.isColorBlindMode and self.colorBlindGradientUVs or self.pHGradientUVs)

		local pHChanged = 0
		applicationRate = spec.lastLitersPerHectar * massPerLiter

		if not spec.sprayAmountAutoMode then
			local requiredLitersPerHa = self.pHMap:getLimeUsageByStateChange(spec.sprayAmountManual)
			pHChanged = self.pHMap:getPhValueFromChangedStates(spec.sprayAmountManual)
			applicationRate = requiredLitersPerHa * massPerLiter

			if pHChanged > 0 then
				changeBarText = string.format("pH +%s", formatDecimalNumber(pHChanged))
			end
		end

		local pHActualInt = spec.phActualBuffer:get()
		local pHTargetInt = spec.phTargetBuffer:get()
		local pHActual = self.pHMap:getPhValueFromInternalValue(pHActualInt)
		local pHTarget = self.pHMap:getPhValueFromInternalValue(pHTargetInt)

		if pHActualInt ~= 0 and pHTargetInt ~= 0 then
			self.actualValue = pHActual
			self.setValue = pHActual + pHChanged
			self.targetValue = pHTarget

			if spec.sprayAmountAutoMode then
				pHChanged = self.targetValue - self.actualValue

				if pHChanged > 0 then
					changeBarText = string.format("pH +%s", formatDecimalNumber(pHChanged))
				end

				self.setValue = self.targetValue
			end

			self.actualValueStr = "pH %.3f"

			if soilTypeName ~= "" then
				if spec.sprayAmountAutoMode then
					descriptionText = string.format(self.texts.description_limeAuto, soilTypeName, formatDecimalNumber(pHTarget))
				else
					descriptionText = string.format(self.texts.description_limeManual, soilTypeName, formatDecimalNumber(pHTarget))
				end
			end

			self.hasValidValues = true
		end

		if self.pHMap ~= nil then
			minValue, maxValue = self.pHMap:getMinMaxValue()
		end

		stepResolution = spec.pHMap:getPhValueFromChangedStates(1)
	else
		self.gradientInactive:setUVs(self.isColorBlindMode and self.colorBlindGradientUVsInactive or self.nGradientUVsInactive)
		self.gradient:setUVs(self.isColorBlindMode and self.colorBlindGradientUVs or self.nGradientUVs)

		local litersPerHectar = spec.lastLitersPerHectar
		local nitrogenChanged = 0

		if not spec.sprayAmountAutoMode then
			litersPerHectar = self.nitrogenMap:getFertilizerUsageByStateChange(spec.sprayAmountManual, sprayFillType)
			nitrogenChanged = self.nitrogenMap:getNitrogenFromChangedStates(spec.sprayAmountManual)

			if nitrogenChanged > 0 then
				changeBarText = string.format("+%dkg N/ha", nitrogenChanged)
			end
		end

		if spec.isSolidFertilizerSprayer then
			headline = self.texts.headline_n_solidFertilizer
			applicationRateStr = "%d kg/ha"
			applicationRate = litersPerHectar * massPerLiter * 1000
		elseif spec.isLiquidFertilizerSprayer then
			headline = self.texts.headline_n_liquidFertilizer
			applicationRateStr = "%d l/ha"
			applicationRate = litersPerHectar
		elseif spec.isSlurryTanker then
			headline = self.texts.headline_n_slurryTanker
			applicationRateStr = "%.1f m³/ha"
			applicationRate = litersPerHectar / 1000

			if spec.sprayAmountAutoMode and soilTypeName ~= "" then
				descriptionText = string.format(self.texts.description_slurryAuto, soilTypeName)
			end
		elseif spec.isManureSpreader then
			headline = self.texts.headline_n_manureSpreader
			applicationRateStr = "%.1f t/ha"
			applicationRate = litersPerHectar * massPerLiter

			if spec.sprayAmountAutoMode and soilTypeName ~= "" then
				descriptionText = string.format(self.texts.description_manureAuto, soilTypeName)
			end
		end

		local nActualInt = spec.nActualBuffer:get()
		local nTargetInt = spec.nTargetBuffer:get()
		local nActual = self.nitrogenMap:getNitrogenValueFromInternalValue(nActualInt)
		local nTarget = self.nitrogenMap:getNitrogenValueFromInternalValue(nTargetInt)

		if nActualInt > 0 and nTargetInt > 0 then
			self.actualValue = nActual
			self.setValue = nActual + nitrogenChanged
			self.targetValue = nTarget

			if spec.sprayAmountAutoMode then
				nitrogenChanged = self.targetValue - self.actualValue

				if nitrogenChanged > 0 then
					changeBarText = string.format("+%dkg N/ha", nitrogenChanged)
				end

				self.setValue = self.targetValue
			end

			self.actualValueStr = "%dkg N/ha"
			local forcedFruitType = nil

			if vehicle.spec_sowingMachine ~= nil then
				forcedFruitType = vehicle.spec_sowingMachine.workAreaParameters.seedsFruitType
			end

			local fillType = g_fillTypeManager:getFillTypeByIndex(g_fruitTypeManager:getFillTypeIndexByFruitTypeIndex(forcedFruitType or spec.nApplyAutoModeFruitType))

			if fillType ~= nil and fillType ~= FillType.UNKNOWN and soilTypeName ~= "" then
				if nTarget > 0 then
					if spec.sprayAmountAutoMode then
						descriptionText = string.format(self.texts.description_fertilizerAutoFruit, fillType.title, soilTypeName)
					else
						descriptionText = string.format(self.texts.description_fertilizerManualFruit, fillType.title, soilTypeName)
					end
				else
					descriptionText = self.texts.description_noFertilizerRequired
					enableZeroTargetFlag = true
				end
			end

			if descriptionText == "" and soilTypeName ~= "" then
				if spec.sprayAmountAutoMode then
					descriptionText = string.format(self.texts.description_fertilizerAutoNoFruit, soilTypeName)

					if self.nitrogenMap ~= nil then
						local fruitTypeIndex = self.nitrogenMap:getFruitTypeIndexByFruitRequirementIndex(spec.nApplyAutoModeFruitRequirementDefaultIndex)

						if fruitTypeIndex ~= nil then
							local _fillType = g_fillTypeManager:getFillTypeByIndex(g_fruitTypeManager:getFillTypeIndexByFruitTypeIndex(fruitTypeIndex))

							if _fillType ~= nil then
								descriptionText = string.format(self.texts.description_fertilizerAutoNoFruitDefault, _fillType.title, soilTypeName)
							end
						end
					end
				else
					descriptionText = string.format(self.texts.description_fertilizerManualNoFruit, soilTypeName)
				end
			end

			self.hasValidValues = true
		end

		if self.nitrogenMap ~= nil then
			minValue, maxValue = self.nitrogenMap:getMinMaxValue()
			local nAmount = spec.lastNitrogenProportion

			if nAmount == 0 then
				nAmount = self.nitrogenMap:getNitrogenAmountFromFillType(sprayFillType)
			end

			if spec.isSlurryTanker then
				local str = " (~%skgN/m³)"

				if sourceVehicle:getIsUsingExactNitrogenAmount() then
					str = " (%skgN/m³)"
				end

				applicationRateStr = applicationRateStr .. string.format(str, MathUtil.round(nAmount * 1000, 1))
			else
				applicationRateStr = applicationRateStr .. string.format(" (%s%%%%N)", MathUtil.round(nAmount * 100, 1))
			end

			stepResolution = self.nitrogenMap:getNitrogenFromChangedStates(1)
		end
	end

	if spec.sprayAmountAutoMode then
		applicationRateStr = applicationRateStr .. string.format(" (%s)", self.texts.automaticShort)
		soilTypeName = ""
	end

	self.actualPos = math.min((self.actualValue - minValue) / (maxValue - minValue), 1)
	self.setValuePos = math.min((self.setValue - minValue) / (maxValue - minValue), 1)
	self.targetPos = math.min((self.targetValue - minValue) / (maxValue - minValue), 1)
	local centerX = leftPosX + (rightPosX - leftPosX) * 0.5

	setTextColor(unpack(self.uiTextColor))
	setTextBold(true)
	setTextAlignment(RenderText.ALIGN_CENTER)
	renderDoubleText(centerX, upperPosY - self.textHeightHeadline * 1.1, self.textHeightHeadline, headline)
	setTextBold(false)

	local gradientPosX = centerX - self.gradientInactive.width * 0.5 + self.gradientPosX
	local gradientPosY = upperPosY + self.gradientPosY

	if not self.hasValidValues then
		gradientPosY = gradientPosY + self.actualBar.height - self.gradientInactive.height + self.textHeight
	end

	self.gradientInactive:setPosition(gradientPosX, gradientPosY)
	self.gradientInactive:render()

	local gradientVisibilePos = 0

	if self.hasValidValues then
		gradientVisibilePos = self.actualPos
	end

	self.gradient:setPosition(gradientPosX, gradientPosY)
	self.gradient:setDimension(gradientVisibilePos * self.gradientInactive.width)

	self.gradient.uvs[5] = self.gradientInactive.uvs[1] + (self.gradientInactive.uvs[5] - self.gradientInactive.uvs[1]) * gradientVisibilePos
	self.gradient.uvs[7] = self.gradientInactive.uvs[3] + (self.gradientInactive.uvs[7] - self.gradientInactive.uvs[3]) * gradientVisibilePos

	self.gradient:setUVs(self.gradient.uvs)
	self.gradient:render()

	local labelMin, labelMax = nil

	if hasLimeLoaded then
		labelMin = string.format("pH\n%s", minValue)
		labelMax = string.format("pH\n%s", maxValue)
	else
		labelMin = string.format("%s\nkg/ha", minValue)
		labelMax = string.format("%s\nkg/ha", maxValue)
	end

	local widthDiff = (rightPosX - leftPosX - self.gradientInactive.width) * 0.425

	renderDoubleText(gradientPosX - widthDiff, gradientPosY + self.gradientInactive.height * 0.85, self.gradientInactive.height * 1.3, labelMin)
	renderDoubleText(gradientPosX + self.gradientInactive.width + widthDiff, gradientPosY + self.gradientInactive.height * 0.85, self.gradientInactive.height * 1.3, labelMax)

	local additionalChangeLineHeight = 0
	local changeBarRendered = false

	if self.hasValidValues then
		local targetBarX, targetBarY = nil
		local showFlag = self.targetPos ~= 0 or enableZeroTargetFlag

		if showFlag then
			targetBarX = gradientPosX + self.gradientInactive.width * self.targetPos - self.targetBar.width * 0.5
			targetBarY = gradientPosY

			self.targetBar:setPosition(targetBarX, targetBarY)
			self.targetBar:render()
			self.targetFlag:setPosition(targetBarX, targetBarY + self.targetBar.height)
			self.targetFlag:render()
		end

		local actualBarText = nil
		local actualBarTextOffset = self.actualBar.height + self.textHeight * 1.1
		local actualBarSkipFlagCollisionCheck = false

		if self.actualPos ~= self.targetPos then
			actualBarText = string.format(self.texts.actualValue, string.format(self.actualValueStr, self.actualValue))
		elseif (spec.sprayAmountAutoMode or self.targetPos == self.setValuePos) and self.targetPos ~= 0 then
			actualBarText = string.format(self.texts.targetReached, string.format(self.actualValueStr, self.actualValue))
			actualBarTextOffset = -self.textHeight * 0.7
			actualBarSkipFlagCollisionCheck = true
			changeBarRendered = true
		end

		if actualBarText ~= nil then
			local actualBarX = gradientPosX + self.gradientInactive.width * self.actualPos - self.actualBar.width * 0.5
			local actualBarY = gradientPosY + (self.gradientInactive.height - self.actualBar.height) * 0.5

			self.actualBar:setPosition(actualBarX, actualBarY)
			self.actualBar:render()

			local actualTextWidth = getTextWidth(self.textHeight * 0.7, actualBarText)
			actualBarX = math.max(math.min(actualBarX, rightPosX - actualTextWidth * 0.5), leftPosX + actualTextWidth * 0.5)

			if not actualBarSkipFlagCollisionCheck and showFlag then
				local rightTextBorder = actualBarX + actualTextWidth * 0.5

				if targetBarX < rightTextBorder and rightTextBorder < targetBarX + self.targetFlag.width * 0.5 then
					actualBarX = targetBarX - actualTextWidth * 0.5 - self.pixelSizeX
				end

				local leftTextBorder = actualBarX - actualTextWidth * 0.5

				if targetBarX < leftTextBorder and leftTextBorder < targetBarX + self.targetFlag.width * 0.5 or leftTextBorder < targetBarX and targetBarX < rightTextBorder then
					actualBarX = targetBarX + self.targetFlag.width + self.pixelSizeX + actualTextWidth * 0.5
				end
			end

			renderDoubleText(actualBarX, actualBarY + actualBarTextOffset, self.textHeight * 0.7, actualBarText)
		end

		if self.actualPos < self.setValuePos then
			local goodColor = ExtendedSprayerHUDExtension.COLOR.SET_VALUE_BAR_GOOD
			local badColor = ExtendedSprayerHUDExtension.COLOR.SET_VALUE_BAR_BAD
			local difference = math.min(math.abs(self.setValue - self.targetValue) / stepResolution / 3, 1)
			local differenceInv = 1 - difference
			local r = difference * badColor[1] + differenceInv * goodColor[1]
			local g = difference * badColor[2] + differenceInv * goodColor[2]
			local b = difference * badColor[3] + differenceInv * goodColor[3]
			local a = 1
			local setValueBarX = gradientPosX + self.gradientInactive.width * self.actualPos
			local setValueBarY = gradientPosY - self.gradientInactive.height - self.setValueBar.height

			self.setValueBar:setPosition(setValueBarX, setValueBarY)
			self.setValueBar:setDimension(self.gradientInactive.width * (math.min(self.setValuePos, 1) - self.actualPos))
			self.setValueBar:setColor(r, g, b, a)
			self.setValueBar:render()

			local setBarTextX = setValueBarX + self.setValueBar.width * 0.5
			local setBarTextY = setValueBarY + self.setValueBar.height * 0.2
			local setTextWidth = getTextWidth(self.setValueBar.height * 0.9, changeBarText)

			if setTextWidth > self.setValueBar.width * 0.95 then
				setBarTextY = setValueBarY - self.setValueBar.height
				additionalChangeLineHeight = self.setValueBar.height
			end

			renderDoubleText(setBarTextX, setBarTextY, self.setValueBar.height * 0.9, changeBarText)

			changeBarRendered = true
		end
	else
		descriptionText = self.texts.invalidValues
	end

	if descriptionText ~= "" and self.additionalDisplayHeight ~= 0 then
		setTextAlignment(RenderText.ALIGN_CENTER)
		renderDoubleText(centerX, posY + self.footerOffset + self.additionalTextHeightOffset - self.textHeight * 0.2, self.textHeight * 0.85, descriptionText, self.footerSeparationBar.width)
	end

	self.footerSeparationBar:setPosition(centerX - self.footerSeparationBar.width * 0.5, posY + self.footerOffset + self.textHeight * 1.2)
	self.footerSeparationBar:render()
	setTextAlignment(RenderText.ALIGN_LEFT)
	renderDoubleText(leftPosX, posY + self.footerOffset, self.textHeight, self.texts.applicationRate .. " " .. string.format(applicationRateStr, applicationRate, applicationRateReal))

	if soilTypeName ~= "" then
		setTextAlignment(RenderText.ALIGN_RIGHT)
		renderDoubleText(rightPosX, posY + self.footerOffset, self.textHeight, string.format(self.texts.soilType, soilTypeName))
	end

	self.additionalDisplayHeight = additionalChangeLineHeight

	if descriptionText ~= "" then
		self.additionalDisplayHeight = self.additionalDisplayHeight + self.additionalTextHeightOffset
	end

	if not self.hasValidValues then
		self.additionalDisplayHeight = self.additionalDisplayHeight - self.invalidHeightOffset
	elseif not changeBarRendered then
		self.additionalDisplayHeight = self.additionalDisplayHeight - self.noSetBarHeightOffset
	end

	return posY
end

ExtendedSprayerHUDExtension.COLOR = {
	TARGET_BAR = {
		1,
		1,
		1,
		1
	},
	ACTUAL_BAR = {
		0.601,
		0.01,
		0.01,
		1
	},
	SEPARATOR_BAR = {
		1,
		1,
		1,
		0.3
	},
	SET_VALUE_BAR_GOOD = {
		0.01,
		0.41,
		0.01,
		1
	},
	SET_VALUE_BAR_BAD = {
		0.61,
		0.01,
		0.01,
		1
	}
}
ExtendedSprayerHUDExtension.UV = {
	PH_GRADIENT = {
		194,
		11,
		252,
		12
	},
	N_GRADIENT = {
		194,
		27,
		252,
		12
	},
	COLOR_BLIND_GRADIENT = {
		194,
		43,
		252,
		12
	},
	TARGET_FLAG = {
		399,
		68,
		36,
		52
	},
	TARGET_BAR = {
		399,
		96,
		4,
		2
	}
}
