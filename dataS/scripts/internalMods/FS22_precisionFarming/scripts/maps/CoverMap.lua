CoverMap = {
	MOD_NAME = g_currentModName
}
local CoverMap_mt = Class(CoverMap, ValueMap)

function CoverMap.new(pfModule, customMt)
	local self = ValueMap.new(pfModule, customMt or CoverMap_mt)
	self.name = "coverMap"

	addConsoleCommand("pfUncoverField", "Uncovers given field", "debugUncoverField", self)
	addConsoleCommand("pfUncoverAll", "Uncovers all fields", "debugUncoverAll", self)
	addConsoleCommand("pfReduceCoverState", "Reduces cover State for given field", "debugReduceCoverStateField", self)
	addConsoleCommand("pfReduceCoverStateAll", "Reduces cover State for all fields", "debugReduceCoverStateAll", self)
	addConsoleCommand("pfPrepareField", "Sets nitrogen and pH to the optimal levels", "debugPrepareField", self)

	return self
end

function CoverMap:initialize()
	CoverMap:superClass().initialize(self)

	self.densityMapModifiersAnalyse = {}
	self.densityMapModifiersUncover = {}
	self.densityMapModifiersUncoverFarmland = {}
	self.densityMapModifiersFarmlandState = {}
	self.densityMapModifiersUpdate = {}
	self.densityMapModifiersResetLock = {}
end

function CoverMap:delete()
	removeConsoleCommand("pfUncoverField")
	removeConsoleCommand("pfUncoverAll")
	removeConsoleCommand("pfReduceCoverState")
	removeConsoleCommand("pfReduceCoverStateAll")
	removeConsoleCommand("pfPrepareField")
	CoverMap:superClass().delete(self)
end

function CoverMap:loadFromXML(xmlFile, key, baseDirectory, configFileName, mapFilename)
	key = key .. ".coverMap"
	self.sizeX = getXMLInt(xmlFile, key .. "#sizeX") or 1024
	self.sizeY = getXMLInt(xmlFile, key .. "#sizeY") or 1024
	self.lockChannel = getXMLInt(xmlFile, key .. "#lockChannel") or 0
	self.firstChannel = getXMLInt(xmlFile, key .. "#firstChannel") or 1
	self.numChannels = getXMLInt(xmlFile, key .. "#numChannels") or 4
	self.maxValue = 2^self.numChannels - 1
	self.maxValue = getXMLInt(xmlFile, key .. "#maxValue") or self.maxValue
	self.sampledValue = self.maxValue + 1
	self.bitVectorMap = self:loadSavedBitVectorMap("coverMap", "precisionFarming_coverMap.grle", self.firstChannel + self.numChannels, self.sizeX)

	self:addBitVectorMapToSync(self.bitVectorMap)
	self:addBitVectorMapToSave(self.bitVectorMap, "precisionFarming_coverMap.grle")
	self:addBitVectorMapToDelete(self.bitVectorMap)

	self.bitVectorMapSoilSampleFarmId = self:loadSavedBitVectorMap("soilSampleFarmIdMap", "precisionFarming_soilSampleFarmIdMap.grle", 4, self.sizeX)

	self:addBitVectorMapToSave(self.bitVectorMapSoilSampleFarmId, "precisionFarming_soilSampleFarmIdMap.grle")
	self:addBitVectorMapToDelete(self.bitVectorMapSoilSampleFarmId)

	self.bitVectorMapTempHarvestLock = self:loadSavedBitVectorMap("bitVectorMapTempHarvestLock", "bitVectorMapTempHarvestLock.grle", 1, self.sizeX)

	self:addBitVectorMapToDelete(self.bitVectorMapTempHarvestLock)

	self.soilMap = g_precisionFarming.soilMap

	return true
end

local function worldCoordsToLocalCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, size, terrainSize)
	return size * (startWorldX + terrainSize * 0.5) / terrainSize, size * (startWorldZ + terrainSize * 0.5) / terrainSize, size * (widthWorldX + terrainSize * 0.5) / terrainSize, size * (widthWorldZ + terrainSize * 0.5) / terrainSize, size * (heightWorldX + terrainSize * 0.5) / terrainSize, size * (heightWorldZ + terrainSize * 0.5) / terrainSize
end

function CoverMap:overwriteGameFunctions(pfModule)
	CoverMap:superClass().overwriteGameFunctions(self, pfModule)
end

function CoverMap:getShowInMenu()
	return false
end

function CoverMap:analyseArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, state, farmId, farmlandId)
	local modifier = self.densityMapModifiersAnalyse.modifier
	local maskFilter = self.densityMapModifiersAnalyse.maskFilter
	local modifierFarmIdMap = self.densityMapModifiersAnalyse.modifierFarmIdMap

	if modifier == nil or maskFilter == nil or modifierFarmIdMap == nil then
		self.densityMapModifiersAnalyse.modifier = DensityMapModifier.new(self.bitVectorMap, self.firstChannel, self.numChannels)
		modifier = self.densityMapModifiersAnalyse.modifier
		local fieldGroundSystem = g_currentMission.fieldGroundSystem
		local groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels = fieldGroundSystem:getDensityMapData(FieldDensityMap.GROUND_TYPE)
		self.densityMapModifiersAnalyse.maskFilter = DensityMapFilter.new(groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels)
		maskFilter = self.densityMapModifiersAnalyse.maskFilter

		maskFilter:setValueCompareParams(DensityValueCompareType.GREATER, 0)

		self.densityMapModifiersAnalyse.modifierFarmIdMap = DensityMapModifier.new(self.bitVectorMapSoilSampleFarmId, 0, 4)
		modifierFarmIdMap = self.densityMapModifiersAnalyse.modifierFarmIdMap
	end

	startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ = worldCoordsToLocalCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, self.sizeX, g_currentMission.terrainSize)

	modifier:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)
	modifierFarmIdMap:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)

	local _, area, totalArea = modifier:executeSet(state or self.sampledValue, maskFilter)

	modifierFarmIdMap:executeSet(farmId, maskFilter)
	self.soilMap:onAnalyseArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, state, farmId)

	return area, totalArea
end

function CoverMap:uncoverAnalysedArea(farmId)
	local modifier = self.densityMapModifiersUncover.modifier
	local maskFilter = self.densityMapModifiersUncover.maskFilter
	local farmIdFilter = self.densityMapModifiersUncover.farmIdFilter

	if modifier == nil or maskFilter == nil then
		self.densityMapModifiersUncover.modifier = DensityMapModifier.new(self.bitVectorMap, self.firstChannel, self.numChannels)
		modifier = self.densityMapModifiersUncover.modifier

		modifier:setParallelogramDensityMapCoords(0, 0, 0, self.sizeY, self.sizeX, 0, DensityCoordType.POINT_POINT_POINT)

		self.densityMapModifiersUncover.maskFilter = DensityMapFilter.new(self.bitVectorMap, self.firstChannel, self.numChannels)
		maskFilter = self.densityMapModifiersUncover.maskFilter

		maskFilter:setValueCompareParams(DensityValueCompareType.EQUAL, self.sampledValue)

		self.densityMapModifiersUncover.farmIdFilter = DensityMapFilter.new(self.bitVectorMapSoilSampleFarmId, 0, 4)
		farmIdFilter = self.densityMapModifiersUncover.farmIdFilter
	end

	if farmId ~= nil then
		farmIdFilter:setValueCompareParams(DensityValueCompareType.EQUAL, farmId)
	else
		farmIdFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 0, 15)
	end

	self.soilMap:onUncoverArea(maskFilter, farmIdFilter, farmId)
	modifier:executeSet(self.maxValue, maskFilter, farmIdFilter)
end

function CoverMap:uncoverFarmlandArea(farmlandId)
	local modifier = self.densityMapModifiersUncoverFarmland.modifier
	local maskFilter = self.densityMapModifiersUncoverFarmland.maskFilter
	local fieldFilter = self.densityMapModifiersUncoverFarmland.fieldFilter

	if modifier == nil or maskFilter == nil or fieldFilter == nil then
		self.densityMapModifiersUncoverFarmland.modifier = DensityMapModifier.new(self.bitVectorMap, self.firstChannel, self.numChannels)
		modifier = self.densityMapModifiersUncoverFarmland.modifier

		modifier:setParallelogramDensityMapCoords(0, 0, 0, self.sizeY, self.sizeX, 0, DensityCoordType.POINT_POINT_POINT)

		local farmlandManager = g_farmlandManager
		self.densityMapModifiersUncoverFarmland.maskFilter = DensityMapFilter.new(farmlandManager.localMap, 0, farmlandManager.numberOfBits)
		maskFilter = self.densityMapModifiersUncoverFarmland.maskFilter

		maskFilter:setValueCompareParams(DensityValueCompareType.EQUAL, farmlandId)

		local fieldGroundSystem = g_currentMission.fieldGroundSystem
		local groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels = fieldGroundSystem:getDensityMapData(FieldDensityMap.GROUND_TYPE)
		self.densityMapModifiersAnalyse.fieldFilter = DensityMapFilter.new(groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels)
		fieldFilter = self.densityMapModifiersAnalyse.fieldFilter

		fieldFilter:setValueCompareParams(DensityValueCompareType.GREATER, 0)
	end

	maskFilter:setValueCompareParams(DensityValueCompareType.EQUAL, farmlandId)
	self.soilMap:onUncoverArea(maskFilter, fieldFilter, nil)
	modifier:executeSet(self.maxValue, maskFilter, fieldFilter)
end

function CoverMap:getFarmlandSampleState(farmlandId)
	local modifier = self.densityMapModifiersFarmlandState.modifier
	local coverFilter = self.densityMapModifiersFarmlandState.coverFilter
	local maskFilter = self.densityMapModifiersFarmlandState.maskFilter
	local fieldFilter = self.densityMapModifiersFarmlandState.fieldFilter

	if modifier == nil or coverFilter == nil or maskFilter == nil or fieldFilter == nil then
		self.densityMapModifiersFarmlandState.modifier = DensityMapModifier.new(self.bitVectorMap, self.firstChannel, self.numChannels)
		modifier = self.densityMapModifiersFarmlandState.modifier

		modifier:setParallelogramDensityMapCoords(0, 0, 0, self.sizeY, self.sizeX, 0, DensityCoordType.POINT_POINT_POINT)

		self.densityMapModifiersFarmlandState.coverFilter = DensityMapFilter.new(self.bitVectorMap, self.firstChannel, self.numChannels)
		coverFilter = self.densityMapModifiersFarmlandState.coverFilter

		coverFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 2, self.maxValue + 1)

		local farmlandManager = g_farmlandManager
		self.densityMapModifiersFarmlandState.maskFilter = DensityMapFilter.new(farmlandManager.localMap, 0, farmlandManager.numberOfBits)
		maskFilter = self.densityMapModifiersFarmlandState.maskFilter

		maskFilter:setValueCompareParams(DensityValueCompareType.EQUAL, farmlandId)

		local fieldGroundSystem = g_currentMission.fieldGroundSystem
		local groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels = fieldGroundSystem:getDensityMapData(FieldDensityMap.GROUND_TYPE)
		self.densityMapModifiersAnalyse.fieldFilter = DensityMapFilter.new(groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels)
		fieldFilter = self.densityMapModifiersAnalyse.fieldFilter

		fieldFilter:setValueCompareParams(DensityValueCompareType.GREATER, 0)
	end

	maskFilter:setValueCompareParams(DensityValueCompareType.EQUAL, farmlandId)

	local _, areaField, _ = modifier:executeGet(maskFilter, fieldFilter)
	local _, areaSampled, _ = modifier:executeGet(coverFilter, maskFilter, fieldFilter)

	if areaField > 0 then
		return areaSampled / areaField
	end

	return 0
end

function CoverMap:updateCoverArea(fruitTypes, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, useMinForageState)
	local modifier = self.densityMapModifiersUpdate.modifier
	local lockModifier = self.densityMapModifiersUpdate.lockModifier
	local lockFilter = self.densityMapModifiersUpdate.lockFilter
	local fruitFilter = self.densityMapModifiersUpdate.fruitFilter
	local lockChannelFilter = self.densityMapModifiersUpdate.lockChannelFilter
	local coverStateFilter = self.densityMapModifiersUpdate.coverStateFilter

	if modifier == nil or lockModifier == nil or lockFilter == nil or fruitFilter == nil or lockChannelFilter == nil or coverStateFilter == nil then
		self.densityMapModifiersUpdate.modifier = DensityMapModifier.new(self.bitVectorMap, self.firstChannel, self.numChannels)
		modifier = self.densityMapModifiersUpdate.modifier

		modifier:setPolygonRoundingMode(DensityRoundingMode.INCLUSIVE)

		self.densityMapModifiersUpdate.lockModifier = DensityMapModifier.new(self.bitVectorMapTempHarvestLock, 0, 1)
		lockModifier = self.densityMapModifiersUpdate.lockModifier

		lockModifier:setPolygonRoundingMode(DensityRoundingMode.INCLUSIVE)

		self.densityMapModifiersUpdate.lockFilter = DensityMapFilter.new(self.bitVectorMapTempHarvestLock, 0, 1)
		lockFilter = self.densityMapModifiersUpdate.lockFilter
		self.densityMapModifiersUpdate.fruitFilter = DensityMapFilter.new(modifier)
		fruitFilter = self.densityMapModifiersUpdate.fruitFilter
		self.densityMapModifiersUpdate.lockChannelFilter = DensityMapFilter.new(self.bitVectorMap, self.lockChannel, 1)
		lockChannelFilter = self.densityMapModifiersUpdate.lockChannelFilter

		lockChannelFilter:setValueCompareParams(DensityValueCompareType.EQUAL, 0)

		self.densityMapModifiersUpdate.coverStateFilter = DensityMapFilter.new(self.bitVectorMap, self.firstChannel, self.numChannels)
		coverStateFilter = self.densityMapModifiersUpdate.coverStateFilter

		coverStateFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 2, self.maxValue)
	end

	local widthDirX, widthDirY = MathUtil.vector2Normalize(startWorldX - widthWorldX, startWorldZ - widthWorldZ)
	local heightDirX, heightDirY = MathUtil.vector2Normalize(startWorldX - heightWorldX, startWorldZ - heightWorldZ)
	local extensionLength = g_currentMission.terrainSize / self.sizeX * 2
	local extendedStartWorldX = startWorldX + widthDirX * extensionLength + heightDirX * extensionLength
	local extendedStartWorldZ = startWorldZ + widthDirY * extensionLength + heightDirY * extensionLength
	local extendedWidthWorldX = widthWorldX - widthDirX * extensionLength + heightDirX * extensionLength
	local extendedWidthWorldZ = widthWorldZ - widthDirY * extensionLength + heightDirY * extensionLength
	local extendedHeightWorldX = heightWorldX - heightDirX * extensionLength + widthDirX * extensionLength
	local extendedHeightWorldZ = heightWorldZ - heightDirY * extensionLength + widthDirY * extensionLength
	startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ = worldCoordsToLocalCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, self.sizeX, g_currentMission.terrainSize)
	extendedStartWorldX, extendedStartWorldZ, extendedWidthWorldX, extendedWidthWorldZ, extendedHeightWorldX, extendedHeightWorldZ = worldCoordsToLocalCoords(extendedStartWorldX, extendedStartWorldZ, extendedWidthWorldX, extendedWidthWorldZ, extendedHeightWorldX, extendedHeightWorldZ, self.sizeX, g_currentMission.terrainSize)

	modifier:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)
	lockModifier:setParallelogramDensityMapCoords(extendedStartWorldX, extendedStartWorldZ, extendedWidthWorldX, extendedWidthWorldZ, extendedHeightWorldX, extendedHeightWorldZ, DensityCoordType.POINT_POINT_POINT)
	lockModifier:executeSet(1)

	local usedFruitIndex = nil
	local numFruitTypes = 0

	for _, fruitIndex in pairs(fruitTypes) do
		local desc = g_fruitTypeManager:getFruitTypeByIndex(fruitIndex)

		if desc ~= nil and desc.terrainDataPlaneId ~= nil then
			fruitFilter:resetDensityMapAndChannels(desc.terrainDataPlaneId, desc.startStateChannel, desc.numStateChannels)
			fruitFilter:setValueCompareParams(DensityValueCompareType.EQUAL, desc.cutState)

			local _, numPixels = lockModifier:executeSet(0, fruitFilter)

			if numPixels > 0 then
				usedFruitIndex = fruitIndex
			end
		end

		numFruitTypes = numFruitTypes + 1
	end

	if numFruitTypes == 0 then
		lockModifier:executeSet(0)
	end

	modifier:setParallelogramDensityMapCoords(extendedStartWorldX, extendedStartWorldZ, extendedWidthWorldX, extendedWidthWorldZ, extendedHeightWorldX, extendedHeightWorldZ, DensityCoordType.POINT_POINT_POINT)
	modifier:setDensityMapChannels(self.lockChannel, 1)
	lockFilter:setValueCompareParams(DensityValueCompareType.EQUAL, 1)
	modifier:executeSet(0, lockFilter)
	modifier:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)
	modifier:setDensityMapChannels(self.firstChannel, self.numChannels)
	lockFilter:setValueCompareParams(DensityValueCompareType.EQUAL, 0)
	modifier:executeAdd(-1, lockFilter, lockChannelFilter, coverStateFilter)

	local _, pixelsToLock = modifier:executeGet(lockFilter, lockChannelFilter)
	local phMapUpdated = false
	local nMapUpdated = false

	if usedFruitIndex ~= nil then
		if self.pfModule.pHMap ~= nil then
			phMapUpdated = self.pfModule.pHMap:onHarvestCoverUpdate(lockFilter, lockChannelFilter, usedFruitIndex, pixelsToLock > 0, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, useMinForageState)
		end

		if self.pfModule.nitrogenMap ~= nil then
			nMapUpdated = self.pfModule.nitrogenMap:onHarvestCoverUpdate(lockFilter, lockChannelFilter, usedFruitIndex, pixelsToLock > 0, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, useMinForageState)
		end

		if self.pfModule.seedRateMap ~= nil then
			self.pfModule.seedRateMap:onHarvestCoverUpdate(lockFilter, lockChannelFilter, usedFruitIndex, pixelsToLock > 0, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, useMinForageState)
		end
	end

	modifier:setDensityMapChannels(self.lockChannel, 1)
	modifier:executeSet(1, lockFilter, lockChannelFilter)

	return phMapUpdated, nMapUpdated
end

function CoverMap:resetCoverLock(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
	local modifier = self.densityMapModifiersResetLock.modifier

	if modifier == nil then
		self.densityMapModifiersResetLock.modifier = DensityMapModifier.new(self.bitVectorMap, self.lockChannel, 1)
		modifier = self.densityMapModifiersResetLock.modifier
	end

	startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ = worldCoordsToLocalCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, self.sizeX, g_currentMission.terrainSize)

	modifier:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)
	modifier:executeSet(0)
end

function CoverMap:getNumCoverOverlays()
	return self.maxValue - 1
end

function CoverMap:buildCoverStateOverlay(overlay, index)
	local numOverlays = self:getNumCoverOverlays()

	resetDensityMapVisualizationOverlay(overlay)

	local alpha = (numOverlays - (index - 1)) / numOverlays

	setOverlayColor(overlay, 1, 1, 1, alpha)
	setDensityMapVisualizationOverlayStateColor(overlay, self.bitVectorMap, 0, 0, self.firstChannel, self.numChannels, index, 0, 0, 0)
end

function CoverMap:getIsUncoveredAtBitVectorPos(x, z, isWorldPos)
	if isWorldPos == true then
		x = (x + g_currentMission.terrainSize * 0.5) / g_currentMission.terrainSize * self.sizeX
		z = (z + g_currentMission.terrainSize * 0.5) / g_currentMission.terrainSize * self.sizeY
	end

	local coverValue = getBitVectorMapPoint(self.bitVectorMap, x, z, self.firstChannel, self.numChannels)

	if coverValue > 1 and coverValue <= self.maxValue then
		return true
	end

	return false
end

function CoverMap:debugReduceCoverStateField(fieldIndex)
	local field = g_fieldManager:getFieldByIndex(tonumber(fieldIndex))

	if field ~= nil and field.fieldDimensions ~= nil then
		local numDimensions = getNumOfChildren(field.fieldDimensions)

		for i = 1, numDimensions do
			local startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ = self:getCoordsFromFieldDimensions(field.fieldDimensions, i - 1)

			self:updateCoverArea({}, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, true)
		end

		for i = 1, numDimensions do
			local startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ = self:getCoordsFromFieldDimensions(field.fieldDimensions, i - 1)

			self:resetCoverLock(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
		end
	end

	self.pfModule:updatePrecisionFarmingOverlays()
end

function CoverMap:debugReduceCoverStateAll()
	for i = 1, #g_fieldManager.fields do
		self:debugReduceCoverStateField(i)
	end
end

function CoverMap:debugPrepareField(fieldIndex, resetState)
	local field = g_fieldManager:getFieldByIndex(tonumber(fieldIndex))

	if field ~= nil and field.fieldDimensions ~= nil then
		local numDimensions = getNumOfChildren(field.fieldDimensions)

		if resetState == nil or resetState == "true" then
			local farmlandId = field.farmland.id

			if farmlandId ~= nil then
				self.pfModule.soilMap:onFarmlandStateChanged(farmlandId, FarmlandManager.NO_OWNER_FARM_ID)
				self:debugUncoverField(tonumber(fieldIndex))
			end
		end

		for i = 1, numDimensions do
			local startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ = self:getCoordsFromFieldDimensions(field.fieldDimensions, i - 1)

			self.pfModule.nitrogenMap:updateCropSensorArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, true, false)
		end

		for i = 1, numDimensions do
			local startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ = self:getCoordsFromFieldDimensions(field.fieldDimensions, i - 1)

			self.pfModule.pHMap:updateSprayArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, SprayType.LIME, true, 0)
			self.pfModule.nitrogenMap:updateSprayArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, SprayType.FERTILIZER, SprayType.FERTILIZER, true, 0, 0, 0, 1)
		end

		for i = 1, numDimensions do
			local startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ = self:getCoordsFromFieldDimensions(field.fieldDimensions, i - 1)

			self.pfModule.pHMap:postUpdateSprayArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, SprayType.LIME, SprayType.LIME, true, 0)
			self.pfModule.nitrogenMap:postUpdateSprayArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, SprayType.FERTILIZER, SprayType.FERTILIZER, true, 0)
		end
	end

	self.pfModule:updatePrecisionFarmingOverlays()
end

function CoverMap:getCoordsFromFieldDimensions(fieldDimensions, index)
	local dimWidth = getChildAt(fieldDimensions, index)
	local dimStart = getChildAt(dimWidth, 0)
	local dimHeight = getChildAt(dimWidth, 1)
	local startWorldX, _, startWorldZ = getWorldTranslation(dimStart)
	local widthWorldX, _, widthWorldZ = getWorldTranslation(dimWidth)
	local heightWorldX, _, heightWorldZ = getWorldTranslation(dimHeight)

	return startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ
end

function CoverMap:debugUncoverField(fieldIndex)
	local field = g_fieldManager:getFieldByIndex(tonumber(fieldIndex))

	if field ~= nil and field.fieldDimensions ~= nil then
		local numDimensions = getNumOfChildren(field.fieldDimensions)

		for i = 1, numDimensions do
			local startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ = self:getCoordsFromFieldDimensions(field.fieldDimensions, i - 1)

			self:analyseArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, nil, g_farmlandManager:getFarmlandOwner(field.farmland.id), field.farmland.id)
		end

		self:uncoverAnalysedArea()
	end
end

function CoverMap:debugUncoverAll()
	for i = 1, #g_fieldManager.fields do
		self:debugUncoverField(i)
	end
end
