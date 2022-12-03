SeedRateMap = {
	MOD_NAME = g_currentModName
}
local SeedRateMap_mt = Class(SeedRateMap, ValueMap)

function SeedRateMap.new(pfModule, customMt)
	local self = ValueMap.new(pfModule, customMt or SeedRateMap_mt)
	self.filename = "precisionFarming_seedRateMap.grle"
	self.name = "seedRateMap"
	self.id = "SEED_RATE_MAP"
	self.label = "ui_mapOverviewSeedRate"
	self.texts = {
		cropNameHeader = g_i18n:getText("ui_cropName", SeedRateMap.MOD_NAME),
		cropType1 = g_i18n:getText("ui_soilType_1", SeedRateMap.MOD_NAME),
		cropType2 = g_i18n:getText("ui_soilType_2", SeedRateMap.MOD_NAME),
		cropType3 = g_i18n:getText("ui_soilType_3", SeedRateMap.MOD_NAME),
		cropType4 = g_i18n:getText("ui_soilType_4", SeedRateMap.MOD_NAME)
	}
	self.densityMapModifiersSeedUpdate = {}
	self.densityMapModifiersHarvest = {}

	return self
end

function SeedRateMap:initialize()
	SeedRateMap:superClass().initialize(self)

	self.densityMapModifiersSeedUpdate = {}
	self.densityMapModifiersHarvest = {}
end

function SeedRateMap:loadFromXML(xmlFile, key, baseDirectory, configFileName, mapFilename)
	key = key .. ".seedRateMap"
	self.numChannels = getXMLInt(xmlFile, key .. ".bitVectorMap#numChannels") or 2
	self.maxValue = 2^self.numChannels - 1
	self.sizeX = getXMLInt(xmlFile, key .. ".bitVectorMap#sizeX") or 1024
	self.sizeY = getXMLInt(xmlFile, key .. ".bitVectorMap#sizeY") or 1024
	self.bitVectorMap = self:loadSavedBitVectorMap("SeedRateMap", self.filename, self.numChannels, self.sizeX)

	if g_maxModDescVersion > 64 then
		self:addBitVectorMapToSync(self.bitVectorMap)
	end

	self:addBitVectorMapToSave(self.bitVectorMap, self.filename)
	self:addBitVectorMapToDelete(self.bitVectorMap)

	self.rateValues = {}
	local i = 0

	while true do
		local baseKey = string.format("%s.rateValues.rateValue(%d)", key, i)

		if not hasXMLProperty(xmlFile, baseKey) then
			break
		end

		local rateValue = {
			value = getXMLInt(xmlFile, baseKey .. "#value") or 0,
			text = g_i18n:convertText(getXMLString(xmlFile, baseKey .. "#text"), SeedRateMap.MOD_NAME),
			color = string.getVectorN(getXMLString(xmlFile, baseKey .. "#color"), 3) or {
				0,
				0,
				0
			},
			colorBlind = string.getVectorN(getXMLString(xmlFile, baseKey .. "#colorBlind"), 3)
		}

		table.insert(self.rateValues, rateValue)

		i = i + 1
	end

	self.defaultSeedRate = MathUtil.round(#self.rateValues * 0.5)
	self.fruitTypes = {}
	i = 0

	while true do
		local baseKey = string.format("%s.fruitTypes.fruitType(%d)", key, i)

		if not hasXMLProperty(xmlFile, baseKey) then
			break
		end

		local fruitTypeName = getXMLString(xmlFile, baseKey .. "#name")

		if fruitTypeName ~= nil then
			local fruitTypeDesc = g_fruitTypeManager:getFruitTypeByName(fruitTypeName)

			if fruitTypeDesc ~= nil then
				local fruitType = {
					index = fruitTypeDesc.index,
					seedRates = self:getRateValues(xmlFile, baseKey .. ".seedRates#rates", #self.rateValues),
					seedUsages = self:getRateValues(xmlFile, baseKey .. ".seedRates#usages", #self.rateValues)
				}

				if fruitType.seedRates ~= nil and fruitType.seedUsages ~= nil then
					fruitType.soilTypes = {}
					local j = 0

					while true do
						local soilKey = string.format("%s.soilTypes.soilType(%d)", baseKey, j)

						if not hasXMLProperty(xmlFile, soilKey) then
							break
						end

						local soilType = {
							index = getXMLInt(xmlFile, soilKey .. "#index") or 1,
							yields = self:getRateValues(xmlFile, soilKey .. "#yields", #self.rateValues)
						}

						if soilType.yields ~= nil then
							soilType.bestYieldIndex = nil
							local maxYield = 0

							for j = 1, #soilType.yields do
								if maxYield < soilType.yields[j] then
									maxYield = soilType.yields[j]
									soilType.bestYieldIndex = j
								end
							end

							fruitType.soilTypes[soilType.index] = soilType
						else
							Logging.warning("Invalid yield definitions in '%s'", soilKey)
						end

						j = j + 1
					end

					self.fruitTypes[fruitTypeDesc.index] = fruitType
				else
					Logging.warning("Invalid seed rates or usages in '%s'", baseKey)
				end
			end
		end

		i = i + 1
	end

	return true
end

function SeedRateMap:getRateValues(xmlFile, key, numValues)
	local str = getXMLString(xmlFile, key)
	local values = str:split(" ")

	if #values == numValues then
		for i = 1, #values do
			values[i] = tonumber(values[i])
		end

		return values
	end

	return nil
end

function SeedRateMap:getRateLabelByIndex(index)
	local rate = self.rateValues[index]

	if rate ~= nil then
		return rate.text
	end

	return "unknown"
end

function SeedRateMap:update(dt)
end

local function worldCoordsToLocalCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, size, terrainSize)
	return math.floor(size * (startWorldX + terrainSize * 0.5) / terrainSize), math.floor(size * (startWorldZ + terrainSize * 0.5) / terrainSize), math.floor(size * (widthWorldX + terrainSize * 0.5) / terrainSize), math.floor(size * (widthWorldZ + terrainSize * 0.5) / terrainSize), math.floor(size * (heightWorldX + terrainSize * 0.5) / terrainSize), math.floor(size * (heightWorldZ + terrainSize * 0.5) / terrainSize)
end

function SeedRateMap:updateSeedArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, fruitTypeIndex, autoMode, manualSeedRate)
	local soilMap = self.pfModule.soilMap

	if soilMap ~= nil then
		local modifier = self.densityMapModifiersSeedUpdate.modifier
		local maskFilter = self.densityMapModifiersSeedUpdate.maskFilter
		local soilFilter = self.densityMapModifiersSeedUpdate.soilFilter

		if modifier == nil or maskFilter == nil or soilFilter == nil then
			self.densityMapModifiersSeedUpdate.modifier = DensityMapModifier.new(self.bitVectorMap, 0, self.numChannels)
			modifier = self.densityMapModifiersSeedUpdate.modifier
			local fieldGroundSystem = g_currentMission.fieldGroundSystem
			local groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels = fieldGroundSystem:getDensityMapData(FieldDensityMap.GROUND_TYPE)
			self.densityMapModifiersSeedUpdate.maskFilter = DensityMapFilter.new(groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels)
			maskFilter = self.densityMapModifiersSeedUpdate.maskFilter

			maskFilter:setValueCompareParams(DensityValueCompareType.GREATER, 0)

			self.densityMapModifiersSeedUpdate.soilFilter = DensityMapFilter.new(soilMap.bitVectorMap, soilMap.typeFirstChannel, soilMap.typeNumChannels)
			soilFilter = self.densityMapModifiersSeedUpdate.soilFilter
		end

		startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ = worldCoordsToLocalCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, self.sizeX, g_currentMission.terrainSize)

		modifier:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)

		local fruitTypeData = self.fruitTypes[fruitTypeIndex]

		if fruitTypeData ~= nil then
			if autoMode then
				local numPixelsChanged = 0
				local seedUsageSum = 0
				local seedRateSum = 0
				local seedRateIndexSum = 0

				for soilTypeIndex, soilTypeData in pairs(fruitTypeData.soilTypes) do
					if soilTypeData.bestYieldIndex ~= nil then
						soilFilter:setValueCompareParams(DensityValueCompareType.EQUAL, soilTypeIndex - 1)

						local _, numPixels, _ = modifier:executeSet(soilTypeData.bestYieldIndex, maskFilter, soilFilter)
						numPixelsChanged = numPixelsChanged + numPixels
						seedUsageSum = seedUsageSum + fruitTypeData.seedUsages[soilTypeData.bestYieldIndex] * numPixels
						seedRateSum = seedRateSum + fruitTypeData.seedRates[soilTypeData.bestYieldIndex] * numPixels
						seedRateIndexSum = seedRateIndexSum + soilTypeData.bestYieldIndex * numPixels
					end
				end

				if numPixelsChanged > 0 then
					return seedUsageSum / numPixelsChanged, seedRateSum / numPixelsChanged, MathUtil.round(seedRateIndexSum / numPixelsChanged)
				end
			else
				modifier:executeSet(manualSeedRate, maskFilter)

				return fruitTypeData.seedUsages[manualSeedRate], fruitTypeData.seedRates[manualSeedRate], manualSeedRate
			end
		else
			modifier:executeSet(self.defaultSeedRate, maskFilter)
		end
	end

	return 0
end

function SeedRateMap:onHarvestCoverUpdate(fruitFilter, sprayTypeFilter, fruitIndex, fruitUsed, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, useMinForageState)
	if fruitUsed then
		local soilMap = self.pfModule.soilMap

		if soilMap ~= nil and soilMap.bitVectorMap ~= nil then
			local modifier = self.densityMapModifiersHarvest.modifier
			local soilFilter = self.densityMapModifiersHarvest.soilFilter

			if modifier == nil or soilFilter == nil then
				self.densityMapModifiersHarvest.modifier = DensityMapModifier.new(self.bitVectorMap, 0, self.numChannels)
				modifier = self.densityMapModifiersHarvest.modifier

				modifier:setPolygonRoundingMode(DensityRoundingMode.INCLUSIVE)

				self.densityMapModifiersHarvest.soilFilter = DensityMapFilter.new(soilMap.bitVectorMap, soilMap.typeFirstChannel, soilMap.typeNumChannels)
				soilFilter = self.densityMapModifiersHarvest.soilFilter
			end

			local totalYield = 0
			local numTypes = 0
			local fruitTypeData = self.fruitTypes[fruitIndex]

			if fruitTypeData ~= nil then
				modifier:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)

				for soilTypeIndex, soilTypeData in pairs(fruitTypeData.soilTypes) do
					if soilTypeData.bestYieldIndex ~= nil then
						soilFilter:setValueCompareParams(DensityValueCompareType.EQUAL, soilTypeIndex - 1)

						local acc, numPixels, _ = modifier:executeGet(soilFilter)

						if numPixels > 0 then
							local state = MathUtil.round(acc / numPixels)

							if soilTypeData.yields[state] ~= nil then
								totalYield = totalYield + soilTypeData.yields[state]
								numTypes = numTypes + 1
								self.lastSeedRateFound = state
								self.lastSeedRateTarget = soilTypeData.bestYieldIndex
							end
						end
					end
				end
			end

			local yield = 1

			if numTypes > 0 then
				yield = totalYield / numTypes
			end

			self.lastSeedRateMultiplier = yield
		end
	end
end

function SeedRateMap:updateLastYieldValues()
	local lastSeedRateMultiplier = self.lastSeedRateMultiplier
	local lastSeedRateFound = self.lastSeedRateFound
	local lastSeedRateTarget = self.lastSeedRateTarget
	self.lastSeedRateMultiplier = nil
	self.lastSeedRateFound = nil
	self.lastSeedRateTarget = nil

	return lastSeedRateMultiplier, lastSeedRateFound, lastSeedRateTarget
end

function SeedRateMap:buildOverlay(overlay, seedRateFilter, isColorBlindMode)
	resetDensityMapVisualizationOverlay(overlay)
	setOverlayColor(overlay, 1, 1, 1, 1)

	local seedRateMapId = self.bitVectorMap

	for i = 1, #self.rateValues do
		if seedRateFilter[i] then
			local rateValue = self.rateValues[i]
			local r, g, b = nil

			if isColorBlindMode then
				b = rateValue.colorBlind[3]
				g = rateValue.colorBlind[2]
				r = rateValue.colorBlind[1]
			else
				b = rateValue.color[3]
				g = rateValue.color[2]
				r = rateValue.color[1]
			end

			setDensityMapVisualizationOverlayStateColor(overlay, seedRateMapId, 0, 0, 0, self.numChannels, rateValue.value, r, g, b)
		end
	end
end

function SeedRateMap:getDisplayValues()
	if self.valuesToDisplay == nil then
		self.valuesToDisplay = {}

		for i = 1, #self.rateValues do
			local rateValue = self.rateValues[i]
			local rateValueToDisplay = {
				colors = {}
			}
			rateValueToDisplay.colors[true] = {
				rateValue.colorBlind or rateValue.color
			}
			rateValueToDisplay.colors[false] = {
				rateValue.color
			}
			rateValueToDisplay.description = rateValue.text

			table.insert(self.valuesToDisplay, rateValueToDisplay)
		end
	end

	return self.valuesToDisplay
end

function SeedRateMap:getValueFilter()
	if self.valueFilter == nil then
		self.valueFilter = {}

		for i = 1, #self.rateValues do
			table.insert(self.valueFilter, true)
		end
	end

	return self.valueFilter
end

function SeedRateMap:getHelpLinePage()
	return 7
end

function SeedRateMap:getSeedRateByFruitTypeAndIndex(fruitTypeIndex, seedRateIndex)
	if fruitTypeIndex ~= nil then
		local fruitTypeData = self.fruitTypes[fruitTypeIndex]

		if fruitTypeData ~= nil then
			return fruitTypeData.seedRates[seedRateIndex]
		end
	end

	return 0
end

function SeedRateMap:getIsFruitTypeSupported(fruitTypeIndex)
	if fruitTypeIndex ~= nil then
		return self.fruitTypes[fruitTypeIndex] ~= nil
	end

	return false
end

function SeedRateMap:getOptimalSeedRateByFruitTypeAndSoiltype(fruitTypeIndex, soilTypeIndex)
	if fruitTypeIndex ~= nil then
		local fruitTypeData = self.fruitTypes[fruitTypeIndex]

		if fruitTypeData ~= nil then
			local soilType = fruitTypeData.soilTypes[soilTypeIndex]

			if soilType ~= nil then
				return soilType.bestYieldIndex
			end
		end
	end

	return nil
end

function SeedRateMap:createHelpMenuSeedRateTableRow(contentBox, template, isHeader, cropName, text1, text2, text3, text4)
	local row = template:clone(contentBox)

	if self.rowIndex % 2 == 0 then
		row:applyProfile("precisionFarmingSeedRateRowBackgroundAlternate")
	end

	if isHeader then
		row:getDescendantByName("cropName"):applyProfile("precisionFarmingSeedRateRowVehicleCellHeader")
		row:getDescendantByName("soil1"):applyProfile("precisionFarmingSeedRateRowAttributeCellHeader")
		row:getDescendantByName("soil2"):applyProfile("precisionFarmingSeedRateRowAttributeCellHeader")
		row:getDescendantByName("soil3"):applyProfile("precisionFarmingSeedRateRowAttributeCellHeader")
		row:getDescendantByName("soil4"):applyProfile("precisionFarmingSeedRateRowAttributeCellHeader")
	end

	row:getDescendantByName("cropName"):setText(cropName)
	row:getDescendantByName("soil1"):setText(text1)
	row:getDescendantByName("soil2"):setText(text2)
	row:getDescendantByName("soil3"):setText(text3)
	row:getDescendantByName("soil4"):setText(text4)
	row:applyScreenAlignment()
	row:updateAbsolutePosition()

	self.rowIndex = self.rowIndex + 1
end

function SeedRateMap:createHelpMenuSeedRateTable(contentBox, template)
	self.rowIndex = 0

	self:createHelpMenuSeedRateTableRow(contentBox, template, true, self.texts.cropNameHeader, self.texts.cropType1, self.texts.cropType2, self.texts.cropType3, self.texts.cropType4)

	for i = 1, #self.fruitTypes do
		local fruitType = self.fruitTypes[i]
		local fillType = g_fruitTypeManager:getFillTypeByFruitTypeIndex(fruitType.index)

		if fillType ~= nil then
			local title = fillType.title
			local bestYieldText = {
				"",
				"",
				"",
				""
			}

			for j = 1, #fruitType.soilTypes do
				local soilType = fruitType.soilTypes[j]

				if soilType.bestYieldIndex ~= nil then
					bestYieldText[j] = self:getRateLabelByIndex(soilType.bestYieldIndex)
				end
			end

			self:createHelpMenuSeedRateTableRow(contentBox, template, false, title, unpack(bestYieldText))
		end
	end
end
