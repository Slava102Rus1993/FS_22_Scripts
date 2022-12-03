PHMap = {
	MOD_NAME = g_currentModName,
	NUM_BITS = 5
}
local PHMap_mt = Class(PHMap, ValueMap)

function PHMap.new(pfModule, customMt)
	local self = ValueMap.new(pfModule, customMt or PHMap_mt)
	self.name = "pHMap"
	self.id = "PH_MAP"
	self.label = "ui_mapOverviewPH"
	self.densityMapModifiersInitialize = {}
	self.densityMapModifiersHarvest = {}
	self.densityMapModifiersSpray = {}
	self.densityMapModifiersResetLock = {}
	self.densityMapModifiersFieldInfo = {}
	self.lastActualValue = -1
	self.lastTargetValue = -1
	self.lastRegularValue = -1
	self.minimapGradientUVs = {
		GuiUtils.getUVs({
			194,
			11,
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
	self.minimapLabelName = g_i18n:getText("ui_mapOverviewPH", PHMap.MOD_NAME)

	return self
end

function PHMap:initialize()
	PHMap:superClass().initialize(self)

	self.densityMapModifiersInitialize = {}
	self.densityMapModifiersHarvest = {}
	self.densityMapModifiersSpray = {}
	self.densityMapModifiersResetLock = {}
	self.densityMapModifiersFieldInfo = {}
	self.lastActualValue = -1
	self.lastTargetValue = -1
	self.lastRegularValue = -1
end

function PHMap:loadFromXML(xmlFile, key, baseDirectory, configFileName, mapFilename)
	key = key .. ".pHMap"
	self.firstChannel = getXMLInt(xmlFile, key .. ".bitVectorMap#firstChannel") or 1
	self.numChannels = getXMLInt(xmlFile, key .. ".bitVectorMap#numChannels") or 4
	self.maxValue = getXMLInt(xmlFile, key .. ".bitVectorMap#maxValue") or 2^self.numChannels - 1
	self.sizeX = 1024
	self.sizeY = 1024
	self.bitVectorMap, self.newBitVectorMap = self:loadSavedBitVectorMap("phMap", "precisionFarming_phMap.grle", self.numChannels, self.sizeX)

	self:addBitVectorMapToSync(self.bitVectorMap)
	self:addBitVectorMapToSave(self.bitVectorMap, "precisionFarming_phMap.grle")
	self:addBitVectorMapToDelete(self.bitVectorMap)

	self.noiseFilename = getXMLString(xmlFile, key .. ".noiseMap#filename")
	self.noiseNumChannels = getXMLInt(xmlFile, key .. ".noiseMap#numChannels") or 2
	self.noiseResolution = getXMLInt(xmlFile, key .. ".noiseMap#resolution") or 1024
	self.noiseMaxValue = 2^self.noiseNumChannels - 1
	self.bitVectorMapNoise = createBitVectorMap("pHNoiseMap")

	if self.noiseFilename ~= nil then
		self.noiseFilename = Utils.getFilename(self.noiseFilename, baseDirectory)

		if not loadBitVectorMapFromFile(self.bitVectorMapNoise, self.noiseFilename, self.noiseNumChannels) then
			Logging.xmlWarning(configFileName, "Error while loading pH noise map '%s'", self.noiseFilename)

			self.noiseFilename = nil
		end
	end

	if self.noiseFilename == nil then
		loadBitVectorMapNew(self.bitVectorMapNoise, self.noiseResolution, self.noiseResolution, self.noiseNumChannels, false)
	end

	self:addBitVectorMapToDelete(self.bitVectorMapNoise)

	self.bitVectorMapPHStateChange = self:loadSavedBitVectorMap("pHLockStateMap", "precisionFarming_pHLockStateMap.grle", 2, self.noiseResolution)

	self:addBitVectorMapToSave(self.bitVectorMapPHStateChange, "precisionFarming_pHLockStateMap.grle")
	self:addBitVectorMapToDelete(self.bitVectorMapPHStateChange)

	self.bitVectorMapPHInitMask = self:loadSavedBitVectorMap("pHInitMaskMap", "pHInitMaskMap.grle", 1, self.noiseResolution)

	self:addBitVectorMapToDelete(self.bitVectorMapPHInitMask)

	self.outdatedLabel = g_i18n:convertText(getXMLString(xmlFile, key .. ".texts#outdatedLabel") or "$l10n_ui_precisionFarming_outdatedData", PHMap.MOD_NAME)
	self.pHValues = {}
	self.pHValuesToDisplay = {}
	local i = 0

	while true do
		local baseKey = string.format("%s.pHValues.pHValue(%d)", key, i)

		if not hasXMLProperty(xmlFile, baseKey) then
			break
		end

		local pHValue = {
			value = getXMLInt(xmlFile, baseKey .. "#value") or 0,
			maxDisplayValue = self.maxValue,
			realValue = getXMLFloat(xmlFile, baseKey .. "#realValue") or 0,
			color = string.getVectorN(getXMLString(xmlFile, baseKey .. "#color"), 3) or {
				0,
				0,
				0
			},
			colorBlind = string.getVectorN(getXMLString(xmlFile, baseKey .. "#colorBlind"), 3) or {
				0,
				0,
				0
			},
			showOnHud = Utils.getNoNil(getXMLBool(xmlFile, baseKey .. "#showOnHud"), true)
		}

		table.insert(self.pHValues, pHValue)

		if pHValue.showOnHud then
			if #self.pHValuesToDisplay > 0 then
				self.pHValuesToDisplay[#self.pHValuesToDisplay].maxDisplayValue = pHValue.value - 1
			end

			table.insert(self.pHValuesToDisplay, pHValue)
		end

		i = i + 1
	end

	self.pHValuePerState = getXMLFloat(xmlFile, key .. ".pHValues#pHValuePerState") or 0.125
	self.valueTransformations = {}
	i = 0

	while true do
		local baseKey = string.format("%s.valueTransformations.valueTransformation(%d)", key, i)

		if not hasXMLProperty(xmlFile, baseKey) then
			break
		end

		local valueTransformation = {
			soilTypeIndex = getXMLInt(xmlFile, baseKey .. "#soilTypeIndex") or 1,
			baseRange = string.getVectorN(getXMLString(xmlFile, baseKey .. ".baseValue#range"), self.noiseMaxValue + 1)
		}

		if valueTransformation.baseRange ~= nil then
			valueTransformation.optimalValue = getXMLInt(xmlFile, baseKey .. ".optimalValue#value") or 1
			valueTransformation.decreasePerHarvest = getXMLInt(xmlFile, baseKey .. ".decreasePerHarvest#value") or 1
			valueTransformation.regularOffset = getXMLFloat(xmlFile, baseKey .. ".regularOffset#value") or 1

			table.insert(self.valueTransformations, valueTransformation)
		else
			Logging.xmlWarning(configFileName, "Invalid base pH range for '%s'", baseKey)
		end

		i = i + 1
	end

	self.regularLimeUsage = getXMLFloat(xmlFile, key .. ".valueTransformations#regularUsage") or 3000
	self.yieldCurve = AnimCurve.new(linearInterpolator1)
	i = 0

	while true do
		local baseKey = string.format("%s.yieldMappings.yieldMapping(%d)", key, i)

		if not hasXMLProperty(xmlFile, baseKey) then
			break
		end

		local levelDifference = getXMLInt(xmlFile, baseKey .. "#levelDifference") or 0
		local yieldFactor = getXMLFloat(xmlFile, baseKey .. "#yieldFactor") or 1

		self.yieldCurve:addKeyframe({
			yieldFactor,
			time = levelDifference
		})

		i = i + 1
	end

	self.levelDifferenceColors = {}
	i = 0

	while true do
		local baseKey = string.format("%s.levelDifferenceColors.levelDifferenceColor(%d)", key, i)

		if not hasXMLProperty(xmlFile, baseKey) then
			break
		end

		local levelDifferenceColor = {
			levelDifference = getXMLInt(xmlFile, baseKey .. "#levelDifference") or 0,
			color = string.getVectorN(getXMLString(xmlFile, baseKey .. "#color"), 3) or {
				0,
				0,
				0
			},
			colorBlind = string.getVectorN(getXMLString(xmlFile, baseKey .. "#colorBlind"), 3) or {
				0,
				0,
				0
			}
		}
		levelDifferenceColor.color[4] = 1
		levelDifferenceColor.colorBlind[4] = 1
		levelDifferenceColor.additionalText = g_i18n:convertText(getXMLString(xmlFile, baseKey .. "#text"), PHMap.MOD_NAME)

		table.insert(self.levelDifferenceColors, levelDifferenceColor)

		i = i + 1
	end

	self.limeUsage = {
		usagePerState = getXMLFloat(xmlFile, key .. ".limeUsage#usagePerState") or 730
	}
	self.minimapGradientLabelName = string.format("pH %.2f - %.2f", self:getMinMaxValue())
	self.coverMap = g_precisionFarming.coverMap
	self.soilMap = g_precisionFarming.soilMap

	return true
end

local function worldCoordsToLocalCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, size, terrainSize)
	return size * (startWorldX + terrainSize * 0.5) / terrainSize, size * (startWorldZ + terrainSize * 0.5) / terrainSize, size * (widthWorldX + terrainSize * 0.5) / terrainSize, size * (widthWorldZ + terrainSize * 0.5) / terrainSize, size * (heightWorldX + terrainSize * 0.5) / terrainSize, size * (heightWorldZ + terrainSize * 0.5) / terrainSize
end

function PHMap:setInitialState(soilBitVector, soilTypeFirstChannel, soilTypeNumChannels, coverChannel, farmlandMask)
	local modifier = self.densityMapModifiersInitialize.modifier
	local soilFilter = self.densityMapModifiersInitialize.soilFilter
	local noiseFilter = self.densityMapModifiersInitialize.noiseFilter
	local pHInitModifier = self.densityMapModifiersInitialize.pHInitModifier
	local pHInitMaskFilter = self.densityMapModifiersInitialize.pHInitMaskFilter

	if modifier == nil or soilFilter == nil or noiseFilter == nil or pHInitModifier == nil or pHInitMaskFilter == nil then
		self.densityMapModifiersInitialize.modifier = DensityMapModifier.new(self.bitVectorMap, self.firstChannel, self.numChannels)
		modifier = self.densityMapModifiersInitialize.modifier
		self.densityMapModifiersInitialize.soilFilter = DensityMapFilter.new(soilBitVector, soilTypeFirstChannel, soilTypeNumChannels)
		soilFilter = self.densityMapModifiersInitialize.soilFilter
		self.densityMapModifiersInitialize.noiseFilter = DensityMapFilter.new(self.bitVectorMapNoise, 0, self.noiseNumChannels)
		noiseFilter = self.densityMapModifiersInitialize.noiseFilter
		self.densityMapModifiersInitialize.pHInitModifier = DensityMapModifier.new(self.bitVectorMapPHInitMask, 0, 1)
		pHInitModifier = self.densityMapModifiersInitialize.pHInitModifier
		self.densityMapModifiersInitialize.pHInitMaskFilter = DensityMapFilter.new(self.bitVectorMapPHInitMask, 0, 1)
		pHInitMaskFilter = self.densityMapModifiersInitialize.pHInitMaskFilter

		pHInitMaskFilter:setValueCompareParams(DensityValueCompareType.EQUAL, 1)
	end

	for i = 1, #self.valueTransformations do
		local valueTransformation = self.valueTransformations[i]

		soilFilter:setValueCompareParams(DensityValueCompareType.EQUAL, valueTransformation.soilTypeIndex - 1)

		if farmlandMask ~= nil then
			pHInitModifier:executeSet(0)
			pHInitModifier:executeSet(1, soilFilter, farmlandMask)
		end

		for j = 1, self.noiseMaxValue + 1 do
			noiseFilter:setValueCompareParams(DensityValueCompareType.EQUAL, j - 1)

			if farmlandMask ~= nil then
				modifier:executeSet(valueTransformation.baseRange[j], pHInitMaskFilter, noiseFilter)
			else
				modifier:executeSet(valueTransformation.baseRange[j], soilFilter, noiseFilter)
			end
		end
	end

	self:setMinimapRequiresUpdate(true)
end

function PHMap:onHarvestCoverUpdate(fruitFilter, harvestLockFilter, fruitIndex, fruitUsed, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, useMinForageState)
	if fruitUsed then
		local soilMap = self.soilMap

		if soilMap ~= nil and soilMap.bitVectorMap ~= nil then
			local modifier = self.densityMapModifiersHarvest.modifier
			local modifierTempLock = self.densityMapModifiersHarvest.modifierTempLock
			local soilFilter = self.densityMapModifiersHarvest.soilFilter
			local phFilter = self.densityMapModifiersHarvest.phFilter
			local tempLockFilter = self.densityMapModifiersHarvest.tempLockFilter

			if modifier == nil or modifierTempLock == nil or tempLockFilter == nil or soilFilter == nil or phFilter == nil then
				self.densityMapModifiersHarvest.modifier = DensityMapModifier.new(self.bitVectorMap, self.firstChannel, self.numChannels)
				modifier = self.densityMapModifiersHarvest.modifier

				modifier:setPolygonRoundingMode(DensityRoundingMode.INCLUSIVE)

				self.densityMapModifiersHarvest.soilFilter = DensityMapFilter.new(soilMap.bitVectorMap, soilMap.typeFirstChannel, soilMap.typeNumChannels)
				soilFilter = self.densityMapModifiersHarvest.soilFilter
				self.densityMapModifiersHarvest.phFilter = DensityMapFilter.new(self.bitVectorMap, self.firstChannel, self.numChannels)
				phFilter = self.densityMapModifiersHarvest.phFilter

				phFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 2, self.maxValue)

				self.densityMapModifiersHarvest.modifierTempLock = DensityMapModifier.new(self.bitVectorMapPHStateChange, 0, 1)
				modifierTempLock = self.densityMapModifiersHarvest.modifierTempLock

				modifierTempLock:setPolygonRoundingMode(DensityRoundingMode.INCLUSIVE)

				self.densityMapModifiersHarvest.tempLockFilter = DensityMapFilter.new(self.bitVectorMapPHStateChange, 0, 1)
				tempLockFilter = self.densityMapModifiersHarvest.tempLockFilter

				tempLockFilter:setValueCompareParams(DensityValueCompareType.EQUAL, 1)
			end

			modifier:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)
			modifierTempLock:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)

			local pHMapChanged = false

			for i = 1, #self.valueTransformations do
				local valueTransformation = self.valueTransformations[i]

				soilFilter:setValueCompareParams(DensityValueCompareType.EQUAL, valueTransformation.soilTypeIndex - 1)
				modifierTempLock:executeSet(1, fruitFilter, harvestLockFilter)

				local acc, numPixels, _ = modifier:executeAdd(-valueTransformation.decreasePerHarvest, tempLockFilter, soilFilter, phFilter)

				if numPixels > 0 then
					self.lastActualValue = acc / numPixels
					self.lastTargetValue = valueTransformation.optimalValue
					self.lastRegularValue = valueTransformation.optimalValue - valueTransformation.decreasePerHarvest * 1.5 * valueTransformation.regularOffset
					pHMapChanged = true
				end

				modifierTempLock:executeSet(0)
			end

			if pHMapChanged then
				self:setMinimapRequiresUpdate(true)
			end

			return pHMapChanged
		end
	end

	return false
end

function PHMap:updateSprayArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, sprayTypeIndex, automaticallyAdjusted, manualSprayRate)
	local coverMap = self.coverMap
	local soilMap = self.soilMap

	if coverMap ~= nil and coverMap.bitVectorMap ~= nil and soilMap ~= nil and soilMap.bitVectorMap ~= nil then
		local desc = g_sprayTypeManager:getSprayTypeByIndex(sprayTypeIndex)

		if desc ~= nil and desc.isLime then
			local modifier = self.densityMapModifiersSpray.modifier
			local soilFilter = self.densityMapModifiersSpray.soilFilter
			local phFilter = self.densityMapModifiersSpray.phFilter
			local maskFilter = self.densityMapModifiersSpray.maskFilter
			local modifierLock = self.densityMapModifiersSpray.modifierLock
			local lockFilter = self.densityMapModifiersSpray.lockFilter
			local sprayTypeFilter = self.densityMapModifiersSpray.sprayTypeFilter

			if modifier == nil or soilFilter == nil or phFilter == nil or maskFilter == nil or modifierLock == nil or lockFilter == nil or sprayTypeFilter == nil then
				self.densityMapModifiersSpray.modifier = DensityMapModifier.new(self.bitVectorMap, self.firstChannel, self.numChannels)
				modifier = self.densityMapModifiersSpray.modifier

				modifier:setPolygonRoundingMode(DensityRoundingMode.INCLUSIVE)

				self.densityMapModifiersSpray.soilFilter = DensityMapFilter.new(soilMap.bitVectorMap, soilMap.typeFirstChannel, soilMap.typeNumChannels)
				soilFilter = self.densityMapModifiersSpray.soilFilter
				self.densityMapModifiersSpray.phFilter = DensityMapFilter.new(self.bitVectorMap, self.firstChannel, self.numChannels)
				phFilter = self.densityMapModifiersSpray.phFilter
				self.densityMapModifiersSpray.maskFilter = DensityMapFilter.new(coverMap.bitVectorMap, coverMap.firstChannel, coverMap.numChannels)
				maskFilter = self.densityMapModifiersSpray.maskFilter

				maskFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 1, coverMap.maxValue)

				self.densityMapModifiersSpray.modifierLock = DensityMapModifier.new(self.bitVectorMapPHStateChange, 1, 1)
				modifierLock = self.densityMapModifiersSpray.modifierLock

				modifierLock:setPolygonRoundingMode(DensityRoundingMode.INCLUSIVE)

				self.densityMapModifiersSpray.lockFilter = DensityMapFilter.new(self.bitVectorMapPHStateChange, 1, 1)
				lockFilter = self.densityMapModifiersSpray.lockFilter

				lockFilter:setValueCompareParams(DensityValueCompareType.EQUAL, 0)

				local fieldGroundSystem = g_currentMission.fieldGroundSystem
				local sprayTypeMapId, sprayTypeFirstChannel, sprayTypeNumChannels = fieldGroundSystem:getDensityMapData(FieldDensityMap.SPRAY_TYPE)
				self.densityMapModifiersSpray.sprayTypeFilter = DensityMapFilter.new(sprayTypeMapId, sprayTypeFirstChannel, sprayTypeNumChannels)
				sprayTypeFilter = self.densityMapModifiersSpray.sprayTypeFilter

				sprayTypeFilter:setValueCompareParams(DensityValueCompareType.GREATER, 0)
			end

			startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ = worldCoordsToLocalCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, self.sizeX, g_currentMission.terrainSize)

			modifier:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)
			maskFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 1, coverMap.maxValue)

			local _, unlockedPixels, _ = modifier:executeGet(maskFilter)

			if unlockedPixels == 0 and automaticallyAdjusted then
				automaticallyAdjusted = false
				manualSprayRate = 4
			end

			local numPixelsChanged = 0
			local phLevelDifference = 0
			local numSoilsChanged = 0
			local phLevelActual = 0
			local phLevelTarget = 0
			local soilTypeIndex = 0

			if automaticallyAdjusted then
				for i = 1, #self.valueTransformations do
					local valueTransformation = self.valueTransformations[i]

					soilFilter:setValueCompareParams(DensityValueCompareType.EQUAL, valueTransformation.soilTypeIndex - 1)
					phFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 1, valueTransformation.optimalValue - 1)

					local acc, numPixels, _ = modifier:executeSet(valueTransformation.optimalValue, soilFilter, phFilter, maskFilter)

					if numPixels > 0 then
						local difference = valueTransformation.optimalValue - acc / numPixels
						numPixelsChanged = numPixelsChanged + numPixels
						phLevelDifference = phLevelDifference + difference
						phLevelActual = phLevelActual + acc / numPixels
						phLevelTarget = phLevelTarget + valueTransformation.optimalValue
						numSoilsChanged = numSoilsChanged + 1
						soilTypeIndex = valueTransformation.soilTypeIndex
					end
				end
			else
				modifierLock:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)
				sprayTypeFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 0, desc.sprayGroundType - 1)
				modifierLock:executeSet(0, sprayTypeFilter)
				sprayTypeFilter:setValueCompareParams(DensityValueCompareType.GREATER, desc.sprayGroundType)
				modifierLock:executeSet(0, sprayTypeFilter)
				sprayTypeFilter:setValueCompareParams(DensityValueCompareType.EQUAL, desc.sprayGroundType)
				modifierLock:executeSet(1, sprayTypeFilter)

				if unlockedPixels > 0 then
					maskFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 0, 1)
					modifierLock:executeSet(1, maskFilter)
				end

				local acc, numPixels = modifier:executeGet(lockFilter)

				if numPixels > 0 then
					local currentState = acc / numPixels
					manualSprayRate = math.min(manualSprayRate, self.maxValue - currentState)

					if manualSprayRate > 0 then
						phFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 1, self.maxValue - manualSprayRate)
						modifier:executeAdd(manualSprayRate, lockFilter, phFilter)

						numPixelsChanged = numPixelsChanged + numPixels
						phLevelDifference = phLevelDifference + manualSprayRate
						phLevelActual = phLevelActual + currentState
						phLevelTarget = phLevelTarget + currentState + manualSprayRate
						numSoilsChanged = numSoilsChanged + 1

						if unlockedPixels == 0 then
							phLevelActual = 0
							phLevelTarget = manualSprayRate
							numSoilsChanged = 1
						end
					end
				end
			end

			if numSoilsChanged > 0 then
				phLevelDifference = phLevelDifference / numSoilsChanged
				phLevelActual = math.floor(phLevelActual / numSoilsChanged)
				phLevelTarget = math.floor(phLevelTarget / numSoilsChanged)

				self:setMinimapRequiresUpdate(true)
			end

			return numPixelsChanged, phLevelDifference, phLevelActual, phLevelTarget, soilTypeIndex, automaticallyAdjusted
		end
	end

	return 0
end

function PHMap:postUpdateSprayArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, sprayTypeIndex, automaticallyAdjusted, manualSprayRate)
	local soilMap = self.soilMap

	if soilMap ~= nil and soilMap.bitVectorMap ~= nil then
		local desc = g_sprayTypeManager:getSprayTypeByIndex(sprayTypeIndex)

		if desc ~= nil and desc.isLime then
			local modifierLock = self.densityMapModifiersSpray.modifierLock
			local sprayTypeFilter = self.densityMapModifiersSpray.sprayTypeFilter

			if modifierLock ~= nil and sprayTypeFilter ~= nil then
				startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ = worldCoordsToLocalCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, self.sizeX, g_currentMission.terrainSize)

				if not automaticallyAdjusted then
					modifierLock:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)
					modifierLock:setPolygonRoundingMode(DensityRoundingMode.INCLUSIVE)
					modifierLock:executeSet(0)
					sprayTypeFilter:setValueCompareParams(DensityValueCompareType.EQUAL, desc.sprayGroundType)
					modifierLock:executeSet(1, sprayTypeFilter)
				end
			end
		end
	end

	return 0
end

function PHMap:getLevelAtWorldPos(x, z)
	x = (x + g_currentMission.terrainSize * 0.5) / g_currentMission.terrainSize * self.sizeX
	z = (z + g_currentMission.terrainSize * 0.5) / g_currentMission.terrainSize * self.sizeY

	if self.coverMap:getIsUncoveredAtBitVectorPos(x, z) then
		return getBitVectorMapPoint(self.bitVectorMap, x, z, self.firstChannel, self.numChannels)
	end

	return 0
end

function PHMap:getLimeUsage(workingWidth, lastSpeed, statesChanged, dt)
	local literPerHectar = self:getLimeUsageByStateChange(statesChanged)
	local litersPerUpdate = literPerHectar * lastSpeed / 3600 / (10000 / workingWidth) * dt
	local regularUsage = self.regularLimeUsage * lastSpeed / 3600 / (10000 / workingWidth) * dt

	return litersPerUpdate, literPerHectar, regularUsage
end

function PHMap:getLimeUsageByStateChange(statesChanged)
	return self.limeUsage.usagePerState * statesChanged
end

function PHMap:getPhValueFromChangedStates(statesChanged)
	return statesChanged * self.pHValuePerState
end

function PHMap:getPhValueFromInternalValue(internal)
	for i = 1, #self.pHValues do
		local pHValue = self.pHValues[i]

		if pHValue.value == math.floor(internal) then
			return pHValue.realValue
		end
	end

	return 0
end

function PHMap:getNearestPhValueFromValue(value)
	local minDifference = 100
	local minValue = 0

	if value > 0 then
		for i = 1, #self.pHValues do
			local pHValue = self.pHValues[i].realValue
			local difference = math.abs(value - pHValue)

			if difference < minDifference then
				minDifference = difference
				minValue = pHValue
			end
		end
	end

	return minValue
end

function PHMap:getOptimalPHValueForSoilTypeIndex(soilTypeIndex)
	for i = 1, #self.valueTransformations do
		local valueTransformation = self.valueTransformations[i]

		if valueTransformation.soilTypeIndex == soilTypeIndex then
			return valueTransformation.optimalValue
		end
	end

	return 0
end

function PHMap:getMinMaxValue()
	if #self.pHValues > 0 then
		return self.pHValues[1].realValue, self.pHValues[#self.pHValues].realValue, #self.pHValues
	end

	return 0, 1, 0
end

function PHMap:updateLastPhValues()
	local actual = self.lastActualValue
	local target = self.lastTargetValue
	local regular = self.lastRegularValue
	self.lastActualValue = -1
	self.lastTargetValue = -1
	self.lastRegularValue = -1

	return actual, target, regular
end

function PHMap:getYieldFactorByLevelDifference(difference)
	return self.yieldCurve:get(difference)
end

function PHMap:buildOverlay(overlay, filter, isColorBlindMode, isMinimap)
	resetDensityMapVisualizationOverlay(overlay)
	setOverlayColor(overlay, 1, 1, 1, 1)

	local coverMap = self.coverMap

	if coverMap ~= nil then
		local coverMask = bitShiftLeft(2^(coverMap.numChannels - 1) - 1, 1)

		for i = 1, #self.pHValuesToDisplay do
			local pHValue = self.pHValuesToDisplay[i]

			if filter[i] then
				local color = pHValue.color

				if isColorBlindMode then
					color = pHValue.colorBlind
				end

				if pHValue.value ~= pHValue.maxDisplayValue then
					for v = pHValue.value, pHValue.maxDisplayValue do
						setDensityMapVisualizationOverlayStateColor(overlay, self.bitVectorMap, coverMap.bitVectorMap, coverMask, self.firstChannel, self.numChannels, v, color[1], color[2], color[3])
					end
				else
					setDensityMapVisualizationOverlayStateColor(overlay, self.bitVectorMap, coverMap.bitVectorMap, coverMask, self.firstChannel, self.numChannels, pHValue.value, color[1], color[2], color[3])
				end
			end
		end
	end
end

function PHMap:getDisplayValues()
	if self.valuesToDisplay == nil then
		self.valuesToDisplay = {}

		for i = 1, #self.pHValuesToDisplay do
			local pHValue = self.pHValuesToDisplay[i]
			local yieldValueToDisplay = {
				colors = {}
			}
			yieldValueToDisplay.colors[true] = {
				pHValue.colorBlind
			}
			yieldValueToDisplay.colors[false] = {
				pHValue.color
			}
			yieldValueToDisplay.description = string.format("%.2f", pHValue.realValue)

			table.insert(self.valuesToDisplay, yieldValueToDisplay)
		end

		local yieldValueToDisplay = {
			colors = {}
		}
		yieldValueToDisplay.colors[true] = {
			{
				0,
				0,
				0
			}
		}
		yieldValueToDisplay.colors[false] = {
			{
				0,
				0,
				0
			}
		}
		yieldValueToDisplay.description = self.outdatedLabel

		table.insert(self.valuesToDisplay, yieldValueToDisplay)
	end

	return self.valuesToDisplay
end

function PHMap:getValueFilter()
	if self.valueFilter == nil or self.valueFilterEnabled == nil then
		self.valueFilter = {}
		self.valueFilterEnabled = {}
		local numValues = #self.pHValuesToDisplay

		for i = 1, numValues + 1 do
			table.insert(self.valueFilter, true)
			table.insert(self.valueFilterEnabled, i <= numValues)
		end
	end

	return self.valueFilter, self.valueFilterEnabled
end

function PHMap:getMinimapZoomFactor()
	return 3
end

function PHMap:collectFieldInfos(fieldInfoDisplayExtension)
	local name = g_i18n:getText("fieldInfo_phValue", PHMap.MOD_NAME)

	fieldInfoDisplayExtension:addFieldInfo(name, self, self.updateFieldInfoDisplay, 2, self.getFieldInfoYieldChange)
end

function PHMap:getAllowCoverage()
	return true
end

function PHMap:getHelpLinePage()
	return 4
end

function PHMap:getRequiresAdditionalActionButton(farmlandId)
	if self.soilMap ~= nil then
		return self.soilMap:getRequiresAdditionalActionButton(farmlandId)
	end

	return false
end

function PHMap:getAdditionalActionButtonText()
	if self.soilMap ~= nil then
		return self.soilMap:getAdditionalActionButtonText()
	end
end

function PHMap:onAdditionalActionButtonPressed(farmlandId)
	if self.soilMap ~= nil then
		return self.soilMap:onAdditionalActionButtonPressed(farmlandId)
	end
end

function PHMap:updateFieldInfoDisplay(fieldInfo, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, isColorBlindMode)
	fieldInfo.pHFactor = 0
	local coverMap = self.coverMap
	local soilMap = self.soilMap

	if coverMap ~= nil and coverMap.bitVectorMap ~= nil and soilMap ~= nil and soilMap.bitVectorMap ~= nil then
		local modifier = self.densityMapModifiersFieldInfo.modifier
		local soilModifier = self.densityMapModifiersFieldInfo.soilModifier
		local coverFilter = self.densityMapModifiersFieldInfo.coverFilter
		local soilFilter = self.densityMapModifiersFieldInfo.soilFilter

		if modifier == nil or soilModifier == nil or coverFilter == nil or soilFilter == nil then
			self.densityMapModifiersFieldInfo.modifier = DensityMapModifier.new(self.bitVectorMap, self.firstChannel, self.numChannels)
			modifier = self.densityMapModifiersFieldInfo.modifier
			self.densityMapModifiersFieldInfo.soilModifier = DensityMapModifier.new(soilMap.bitVectorMap, soilMap.typeFirstChannel, soilMap.typeNumChannels)
			soilModifier = self.densityMapModifiersFieldInfo.soilModifier
			self.densityMapModifiersFieldInfo.coverFilter = DensityMapFilter.new(coverMap.bitVectorMap, coverMap.firstChannel, coverMap.numChannels)
			coverFilter = self.densityMapModifiersFieldInfo.coverFilter

			coverFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 1, coverMap.maxValue)

			self.densityMapModifiersFieldInfo.soilFilter = DensityMapFilter.new(soilMap.bitVectorMap, soilMap.typeFirstChannel, soilMap.typeNumChannels)
			soilFilter = self.densityMapModifiersFieldInfo.soilFilter
		end

		startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ = worldCoordsToLocalCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, self.sizeX, g_currentMission.terrainSize)

		modifier:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)
		soilModifier:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)

		local acc, numPixels, _ = soilModifier:executeGet(coverFilter)
		local soilTypeIndex = math.floor(acc / numPixels) + 1

		for i = 1, #self.valueTransformations do
			local valueTransformation = self.valueTransformations[i]

			if valueTransformation.soilTypeIndex == soilTypeIndex then
				soilFilter:setValueCompareParams(DensityValueCompareType.EQUAL, soilTypeIndex - 1)

				acc, numPixels, _ = modifier:executeGet(coverFilter, soilFilter)

				if numPixels > 0 then
					local phValue = math.floor(acc / numPixels)
					local color, additionalText = nil
					local levelDifference = math.abs(valueTransformation.optimalValue - phValue)

					for j = 1, #self.levelDifferenceColors do
						local levelDifferenceColor = self.levelDifferenceColors[j]

						if levelDifferenceColor.levelDifference <= levelDifference then
							if isColorBlindMode then
								color = levelDifferenceColor.colorBlind
							else
								color = levelDifferenceColor.color
							end

							additionalText = levelDifferenceColor.additionalText
						end
					end

					fieldInfo.pHFactor = self:getYieldFactorByLevelDifference(phValue - valueTransformation.optimalValue)

					return string.format("%.3f / %.3f", self:getPhValueFromInternalValue(phValue), self:getPhValueFromInternalValue(valueTransformation.optimalValue)), color, additionalText
				end
			end
		end
	end

	return nil
end

function PHMap:getFieldInfoYieldChange(fieldInfo)
	return fieldInfo.pHFactor or 0, 0.2
end

function PHMap:drawYieldDebug(pHActualValue, pHTargetValue)
	if self.debugGraph == nil then
		self.debugGraph = Graph.new(#self.yieldCurve.keyframes, 0.45, 0.05, 0.2, 0.15, 0, 100, false, "%", Graph.STYLE_LINES)

		self.debugGraph:setHorizontalLine(10, true, 1, 1, 1, 1)
		self.debugGraph:setVerticalLine(0.1, false, 1, 1, 1, 1)
		self.debugGraph:setColor(0, 1, 0, 1)
	end

	local minTime = math.huge
	local maxTime = -math.huge

	for i = 1, #self.yieldCurve.keyframes do
		local keyframe = self.yieldCurve.keyframes[i]
		local value = self.yieldCurve:get(keyframe.time)

		self.debugGraph:setValue(i, value * 100)

		minTime = math.min(keyframe.time, minTime)
		maxTime = math.max(keyframe.time, maxTime)
	end

	self.debugGraph:draw()

	if minTime ~= math.huge then
		local x = self.debugGraph.left + MathUtil.inverseLerp(minTime, maxTime, pHActualValue - pHTargetValue) * self.debugGraph.width

		setOverlayColor(self.debugGraph.overlayHLine, 1, 0, 0, 1)
		renderOverlay(self.debugGraph.overlayHLine, x, self.debugGraph.bottom, 1 / g_screenWidth, self.debugGraph.height)
		setOverlayColor(self.debugGraph.overlayHLine, 1, 1, 1, 1)
	end
end

function PHMap:overwriteGameFunctions(pfModule)
	PHMap:superClass().overwriteGameFunctions(self, pfModule)
end
