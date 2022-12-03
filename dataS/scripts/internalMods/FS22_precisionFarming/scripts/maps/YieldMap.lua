YieldMap = {
	MOD_NAME = g_currentModName
}
local YieldMap_mt = Class(YieldMap, ValueMap)

function YieldMap.new(pfModule, customMt)
	local self = ValueMap.new(pfModule, customMt or YieldMap_mt)
	self.filename = "precisionFarming_yieldMap.grle"
	self.name = "yieldMap"
	self.id = "YIELD_MAP"
	self.label = "ui_mapOverviewYield"
	self.densityMapModifiersYield = {}
	self.densityMapModifiersReset = {}
	self.minimapGradientUVs = {
		GuiUtils.getUVs({
			194,
			27,
			252,
			12
		})
	}
	self.minimapGradientColorBlindUVs = {
		GuiUtils.getUVs({
			194,
			43,
			252,
			12
		})
	}
	self.minimapLabelName = g_i18n:getText("ui_mapOverviewYield", YieldMap.MOD_NAME)
	self.yieldMapSelected = false
	self.selectedFarmland = nil
	self.selectedField = nil
	self.selectedFieldArea = nil

	return self
end

function YieldMap:initialize()
	YieldMap:superClass().initialize(self)

	self.densityMapModifiersYield = {}
	self.densityMapModifiersReset = {}
	self.yieldMapSelected = false
	self.selectedFarmland = nil
	self.selectedField = nil
	self.selectedFieldArea = nil
end

function YieldMap:delete()
	g_farmlandManager:removeStateChangeListener(self)
	YieldMap:superClass().delete(self)
end

function YieldMap:loadFromXML(xmlFile, key, baseDirectory, configFileName, mapFilename)
	key = key .. ".yieldMap"
	self.numChannels = getXMLInt(xmlFile, key .. ".bitVectorMap#numChannels") or 4
	self.maxValue = 2^self.numChannels - 1
	self.sizeX = getXMLInt(xmlFile, key .. ".bitVectorMap#sizeX") or 1024
	self.sizeY = getXMLInt(xmlFile, key .. ".bitVectorMap#sizeY") or 1024
	self.bitVectorMap = self:loadSavedBitVectorMap("YieldMap", self.filename, self.numChannels, self.sizeX)

	self:addBitVectorMapToSync(self.bitVectorMap)
	self:addBitVectorMapToSave(self.bitVectorMap, self.filename)
	self:addBitVectorMapToDelete(self.bitVectorMap)

	self.yieldValues = {}
	local i = 0

	while true do
		local baseKey = string.format("%s.yieldValues.yieldValue(%d)", key, i)

		if not hasXMLProperty(xmlFile, baseKey) then
			break
		end

		local yieldValue = {
			value = getXMLInt(xmlFile, baseKey .. "#value") or 0,
			displayValue = getXMLInt(xmlFile, baseKey .. "#displayValue") or 100,
			color = string.getVectorN(getXMLString(xmlFile, baseKey .. "#color"), 3),
			colorBlind = string.getVectorN(getXMLString(xmlFile, baseKey .. "#colorBlind"), 3)
		}
		yieldValue.showInMenu = yieldValue.color ~= nil and yieldValue.colorBlind ~= nil

		table.insert(self.yieldValues, yieldValue)

		i = i + 1
	end

	for j = 1, #self.yieldValues - 1 do
		if self.yieldValues[j].color == nil and j > 1 then
			local color1 = self.yieldValues[j - 1].color
			local color2 = self.yieldValues[j + 1].color

			if color1 ~= nil and color2 ~= nil then
				self.yieldValues[j].color = {
					(color1[1] + color2[1]) * 0.5,
					(color1[2] + color2[2]) * 0.5,
					(color1[3] + color2[3]) * 0.5
				}
			end

			local colorBlind1 = self.yieldValues[j - 1].colorBlind
			local colorBlind2 = self.yieldValues[j + 1].colorBlind

			if colorBlind1 ~= nil and colorBlind2 ~= nil then
				self.yieldValues[j].colorBlind = {
					(colorBlind1[1] + colorBlind2[1]) * 0.5,
					(colorBlind1[2] + colorBlind2[2]) * 0.5,
					(colorBlind1[3] + colorBlind2[3]) * 0.5
				}
			end
		end
	end

	self.minimapGradientLabelName = string.format("%d%% - %d%%", self:getMinMaxValue())
	self.sharedSoilStateMap = self.pfModule.sharedSoilStateMap

	g_farmlandManager:addStateChangeListener(self)

	return true
end

function YieldMap:update(dt)
end

local function worldCoordsToLocalCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, size, terrainSize)
	return math.floor(size * (startWorldX + terrainSize * 0.5) / terrainSize), math.floor(size * (startWorldZ + terrainSize * 0.5) / terrainSize), math.floor(size * (widthWorldX + terrainSize * 0.5) / terrainSize), math.floor(size * (widthWorldZ + terrainSize * 0.5) / terrainSize), math.floor(size * (heightWorldX + terrainSize * 0.5) / terrainSize), math.floor(size * (heightWorldZ + terrainSize * 0.5) / terrainSize)
end

function YieldMap:setAreaYield(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, yieldPercentage)
	local modifier = self.densityMapModifiersYield.modifier
	local maskFilter = self.densityMapModifiersYield.maskFilter

	if modifier == nil or maskFilter == nil then
		self.densityMapModifiersYield.modifier = DensityMapModifier.new(self.bitVectorMap, 0, self.numChannels)
		modifier = self.densityMapModifiersYield.modifier
		local fieldGroundSystem = g_currentMission.fieldGroundSystem
		local groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels = fieldGroundSystem:getDensityMapData(FieldDensityMap.GROUND_TYPE)
		self.densityMapModifiersYield.maskFilter = DensityMapFilter.new(groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels)
		maskFilter = self.densityMapModifiersYield.maskFilter

		maskFilter:setValueCompareParams(DensityValueCompareType.GREATER, 0)
	end

	startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ = worldCoordsToLocalCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, self.sizeX, g_currentMission.terrainSize)

	modifier:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)

	local internalYieldValue = self:getNearestInternalYieldValueFromValue(yieldPercentage / 2 * 100)

	modifier:executeSet(internalYieldValue, maskFilter)
	self:setMinimapRequiresUpdate(true)
end

function YieldMap:getNearestInternalYieldValueFromValue(value)
	local minDifference = 10000
	local minValue = 0

	if value > 0 then
		for i = 1, #self.yieldValues do
			local yieldValue = self.yieldValues[i].displayValue
			local difference = math.abs(value - yieldValue)

			if difference < minDifference then
				minDifference = difference
				minValue = self.yieldValues[i].value
			end
		end
	end

	return minValue
end

function YieldMap:resetFarmlandYieldArea(farmlandId)
	local modifier = self.densityMapModifiersReset.modifier
	local farmlandMask = self.densityMapModifiersReset.farmlandMask
	local farmlandManager = g_farmlandManager

	if modifier == nil or farmlandMask == nil then
		self.densityMapModifiersReset.modifier = DensityMapModifier.new(self.bitVectorMap, 0, self.numChannels)
		modifier = self.densityMapModifiersReset.modifier
		self.densityMapModifiersReset.farmlandMask = DensityMapFilter.new(farmlandManager.localMap, 0, farmlandManager.numberOfBits)
		farmlandMask = self.densityMapModifiersReset.farmlandMask
	end

	farmlandMask:setValueCompareParams(DensityValueCompareType.EQUAL, farmlandId)
	modifier:executeSet(0, farmlandMask)
	self:setMinimapRequiresUpdate(true)

	if g_server == nil and g_client ~= nil then
		g_client:getServerConnection():sendEvent(ResetYieldMapEvent.new(farmlandId))
	end
end

function YieldMap:buildOverlay(overlay, yieldFilter, isColorBlindMode)
	resetDensityMapVisualizationOverlay(overlay)
	setOverlayColor(overlay, 1, 1, 1, 1)

	local yieldMapId = self.bitVectorMap
	local filterIndex = 1

	for i = 1, #self.yieldValues do
		local yieldValue = self.yieldValues[i]

		if yieldFilter[filterIndex] then
			local r, g, b = nil

			if isColorBlindMode then
				b = yieldValue.colorBlind[3]
				g = yieldValue.colorBlind[2]
				r = yieldValue.colorBlind[1]
			else
				b = yieldValue.color[3]
				g = yieldValue.color[2]
				r = yieldValue.color[1]
			end

			setDensityMapVisualizationOverlayStateColor(overlay, yieldMapId, 0, 0, 0, self.numChannels, yieldValue.value, r, g, b)
		end

		if yieldValue.showInMenu then
			filterIndex = filterIndex + 1
		end
	end
end

function YieldMap:getMinimapZoomFactor()
	return 3
end

function YieldMap:getMinMaxValue()
	if #self.yieldValues > 0 then
		return self.yieldValues[1].displayValue, self.yieldValues[#self.yieldValues].displayValue, #self.yieldValues
	end

	return 0, 1, 0
end

function YieldMap:getDisplayValues()
	if self.valuesToDisplay == nil then
		self.valuesToDisplay = {}

		for i = 1, #self.yieldValues do
			local pct = (i - 1) / (#self.yieldValues - 1)
			local yieldValue = self.yieldValues[i]

			if yieldValue.showInMenu then
				local yieldValueToDisplay = {
					colors = {}
				}
				yieldValueToDisplay.colors[true] = {
					yieldValue.colorBlind or {
						pct * 0.9 + 0.1,
						pct * 0.9 + 0.1,
						0.1
					}
				}
				yieldValueToDisplay.colors[false] = {
					yieldValue.color
				}
				yieldValueToDisplay.description = string.format("%d%%", yieldValue.displayValue)

				table.insert(self.valuesToDisplay, yieldValueToDisplay)
			end
		end
	end

	return self.valuesToDisplay
end

function YieldMap:getValueFilter()
	if self.valueFilter == nil then
		self.valueFilter = {}

		for i = 1, #self.yieldValues do
			if self.yieldValues[i].showInMenu then
				table.insert(self.valueFilter, true)
			end
		end
	end

	return self.valueFilter
end

function YieldMap:onValueMapSelectionChanged(valueMap)
	self.yieldMapSelected = valueMap == self

	self:updateResetButton()
end

function YieldMap:onFarmlandSelectionChanged(farmlandId, fieldNumber, fieldArea)
	self.selectedFarmland = farmlandId
	self.selectedField = fieldNumber
	self.selectedFieldArea = fieldArea

	self:updateResetButton()
end

function YieldMap:onFarmlandStateChanged(farmlandId, farmId)
	if farmId == FarmlandManager.NO_OWNER_FARM_ID then
		self:resetFarmlandYieldArea(farmlandId)
	end
end

function YieldMap:setMapFrame(mapFrame)
	self.mapFrame = mapFrame

	self:updateResetButton()
end

function YieldMap:getIsResetButtonActive()
	return self.selectedFarmland ~= nil and self.selectedFieldArea ~= nil and self.selectedFieldArea > 0 and self.yieldMapSelected
end

function YieldMap:updateResetButton()
	self.mapFrame:updateAdditionalFunctionButton()
end

function YieldMap:onClickButtonResetYield()
	if self:getIsResetButtonActive() then
		local farmlandStatistics = g_precisionFarming.farmlandStatistics

		if farmlandStatistics ~= nil and farmlandStatistics.selectedFarmlandId ~= nil then
			self:resetFarmlandYieldArea(farmlandStatistics.selectedFarmlandId)
			g_precisionFarming:updatePrecisionFarmingOverlays()

			return true
		end
	end

	return false
end

function YieldMap:getHelpLinePage()
	return 6
end

function YieldMap:getRequiresAdditionalActionButton(farmlandId)
	return self:getIsResetButtonActive()
end

function YieldMap:getAdditionalActionButtonText()
	local text = nil

	if self.selectedField ~= nil and self.selectedField ~= 0 then
		text = string.format(g_i18n:getText("ui_resetYield", YieldMap.MOD_NAME), self.selectedField)
	else
		text = g_i18n:getText("ui_resetYieldAdditionalField", YieldMap.MOD_NAME)
	end

	return text
end

function YieldMap:onAdditionalActionButtonPressed()
	if self:getIsResetButtonActive() then
		local farmlandStatistics = g_precisionFarming.farmlandStatistics

		if farmlandStatistics ~= nil and farmlandStatistics.selectedFarmlandId ~= nil then
			self:resetFarmlandYieldArea(farmlandStatistics.selectedFarmlandId)
			g_precisionFarming:updatePrecisionFarmingOverlays()

			return true
		end
	end
end
