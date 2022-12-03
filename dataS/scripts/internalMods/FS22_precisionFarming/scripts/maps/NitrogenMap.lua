NitrogenMap = {
	MOD_NAME = g_currentModName,
	NUM_BITS = 4,
	DEBUG_N_OFFSET_MAP = false
}
local NitrogenMap_mt = Class(NitrogenMap, ValueMap)

function NitrogenMap.new(pfModule, customMt)
	local self = ValueMap.new(pfModule, customMt or NitrogenMap_mt)
	self.name = "nitrogenMap"
	self.id = "N_MAP"
	self.label = "ui_mapOverviewNitrogen"
	self.densityMapModifiersInitialize = {}
	self.densityMapModifiersHarvest = {}
	self.densityMapModifiersSpray = {}
	self.densityMapModifiersDestroyFruit = {}
	self.densityMapModifiersStrawChopper = {}
	self.densityMapModifiersCropSensor = {}
	self.densityMapModifiersResetLock = {}
	self.densityMapModifiersFieldInfo = {}
	self.densityMapModifiersFruitCheck = {}
	self.lastActualValue = -1
	self.lastTargetValue = -1
	self.lastYieldPotential = -1
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
	self.minimapLabelName = g_i18n:getText("ui_mapOverviewNitrogen", NitrogenMap.MOD_NAME)
	self.minimapLabelNameMission = g_i18n:getText("ui_growthMapFertilized")

	return self
end

function NitrogenMap:initialize()
	NitrogenMap:superClass().initialize(self)

	self.densityMapModifiersInitialize = {}
	self.densityMapModifiersHarvest = {}
	self.densityMapModifiersSpray = {}
	self.densityMapModifiersDestroyFruit = {}
	self.densityMapModifiersStrawChopper = {}
	self.densityMapModifiersCropSensor = {}
	self.densityMapModifiersResetLock = {}
	self.densityMapModifiersFieldInfo = {}
	self.densityMapModifiersFruitCheck = {}
	self.lastActualValue = -1
	self.lastTargetValue = -1
	self.lastYieldPotential = -1
end

function NitrogenMap:loadFromXML(xmlFile, key, baseDirectory, configFileName, mapFilename)
	key = key .. ".nitrogenMap"
	self.firstChannel = getXMLInt(xmlFile, key .. ".bitVectorMap#firstChannel") or 1
	self.numChannels = getXMLInt(xmlFile, key .. ".bitVectorMap#numChannels") or 4
	self.maxValue = getXMLInt(xmlFile, key .. ".bitVectorMap#maxValue") or 2^self.numChannels - 1
	self.sizeX = 1024
	self.sizeY = 1024
	self.bitVectorMap, self.newBitVectorMap = self:loadSavedBitVectorMap("nitrogenMap", "precisionFarming_nitrogenMap.grle", self.numChannels, self.sizeX)

	self:addBitVectorMapToSync(self.bitVectorMap)
	self:addBitVectorMapToSave(self.bitVectorMap, "precisionFarming_nitrogenMap.grle")
	self:addBitVectorMapToDelete(self.bitVectorMap)

	self.noiseFilename = getXMLString(xmlFile, key .. ".noiseMap#filename")
	self.noiseNumChannels = getXMLInt(xmlFile, key .. ".noiseMap#numChannels") or 2
	self.noiseResolution = getXMLInt(xmlFile, key .. ".noiseMap#resolution") or 1024
	self.noiseMaxValue = 2^self.noiseNumChannels - 1
	self.bitVectorMapNoise = createBitVectorMap("nitrogenNoiseMap")

	if self.noiseFilename ~= nil then
		self.noiseFilename = Utils.getFilename(self.noiseFilename, baseDirectory)

		if not loadBitVectorMapFromFile(self.bitVectorMapNoise, self.noiseFilename, self.noiseNumChannels) then
			Logging.xmlWarning(xmlFile, "Error while loading pH noise map '%s'", self.noiseFilename)

			self.noiseFilename = nil
		end
	end

	if self.noiseFilename == nil then
		loadBitVectorMapNew(self.bitVectorMapNoise, self.noiseResolution, self.noiseResolution, self.noiseNumChannels, false)
	end

	self:addBitVectorMapToDelete(self.bitVectorMapNoise)

	self.bitVectorMapNOffset, self.bitVectorMapNOffsetIsNew = self:loadSavedBitVectorMap("nOffsetMap", "precisionFarming_nOffsetMap.grle", 4, self.noiseResolution)

	self:addBitVectorMapToSave(self.bitVectorMapNOffset, "precisionFarming_nOffsetMap.grle")
	self:addBitVectorMapToDelete(self.bitVectorMapNOffset)

	self.nOffsetIndexToOffset = {
		-5,
		-4,
		-3,
		-2,
		-1,
		0,
		1,
		2
	}
	self.bitVectorMapNStateChange = self:loadSavedBitVectorMap("nLockStateMap", "precisionFarming_nLockStateMap.grle", 2, self.noiseResolution)

	self:addBitVectorMapToSave(self.bitVectorMapNStateChange, "precisionFarming_nLockStateMap.grle")
	self:addBitVectorMapToDelete(self.bitVectorMapNStateChange)

	self.bitVectorMapNInitMask = self:loadSavedBitVectorMap("nInitMaskMap", "nInitMaskMap.grle", 1, self.noiseResolution)

	self:addBitVectorMapToDelete(self.bitVectorMapNInitMask)

	self.bitVectorMapNFruitFilterMask = self:loadSavedBitVectorMap("nFruitFilterMask", "nFruitFilterMask.grle", 1, self.noiseResolution)

	self:addBitVectorMapToDelete(self.bitVectorMapNFruitFilterMask)

	self.bitVectorMapNFruitDestroyMask = self:loadSavedBitVectorMap("nFruitDestroyMask", "nFruitDestroyMask.grle", 2, self.noiseResolution)

	self:addBitVectorMapToDelete(self.bitVectorMapNFruitDestroyMask)

	self.bitVectorMapChoppedStrawMask = self:loadSavedBitVectorMap("choppedStrawMask", "choppedStrawMask.grle", 2, self.noiseResolution)

	self:addBitVectorMapToDelete(self.bitVectorMapChoppedStrawMask)

	self.amountPerState = getXMLFloat(xmlFile, key .. ".nitrogenValues#amountPerState") or 5
	self.nitrogenValues = {}
	self.numVisualValues = 0
	local i = 0

	while true do
		local baseKey = string.format("%s.nitrogenValues.nitrogenValue(%d)", key, i)

		if not hasXMLProperty(xmlFile, baseKey) then
			break
		end

		local nitrogenValue = {
			value = getXMLInt(xmlFile, baseKey .. "#value") or 0,
			realValue = getXMLFloat(xmlFile, baseKey .. "#realValue") or 0,
			showOnHud = Utils.getNoNil(getXMLBool(xmlFile, baseKey .. "#showOnHud"), true),
			color = string.getVectorN(getXMLString(xmlFile, baseKey .. "#color"), 3),
			colorBlind = string.getVectorN(getXMLString(xmlFile, baseKey .. "#colorBlind"), 3)
		}

		table.insert(self.nitrogenValues, nitrogenValue)

		nitrogenValue.index = #self.nitrogenValues
		nitrogenValue.filterIndex = self.numVisualValues + 1

		if nitrogenValue.showOnHud then
			self.numVisualValues = self.numVisualValues + 1
		end

		i = i + 1
	end

	local lastOnHud = nil

	for l = 1, #self.nitrogenValues do
		local nitrogenValue = self.nitrogenValues[l]

		if not nitrogenValue.showOnHud then
			if lastOnHud ~= nil then
				nitrogenValue.filterIndex = lastOnHud.filterIndex
				local nextOnHud = nil

				for j = l + 1, #self.nitrogenValues do
					local nextNitrogenValue = self.nitrogenValues[j]

					if nextNitrogenValue.showOnHud then
						nextOnHud = nextNitrogenValue

						break
					end
				end

				if nextOnHud ~= nil then
					local numValues = nextOnHud.index - lastOnHud.index
					local r = lastOnHud.color[1] + (nextOnHud.color[1] - lastOnHud.color[1]) / numValues * (l - lastOnHud.index)
					local g = lastOnHud.color[2] + (nextOnHud.color[2] - lastOnHud.color[2]) / numValues * (l - lastOnHud.index)
					local b = lastOnHud.color[3] + (nextOnHud.color[3] - lastOnHud.color[3]) / numValues * (l - lastOnHud.index)
					nitrogenValue.color = {
						r,
						g,
						b
					}
					r = lastOnHud.colorBlind[1] + (nextOnHud.colorBlind[1] - lastOnHud.colorBlind[1]) / numValues * (l - lastOnHud.index)
					g = lastOnHud.colorBlind[2] + (nextOnHud.colorBlind[2] - lastOnHud.colorBlind[2]) / numValues * (l - lastOnHud.index)
					b = lastOnHud.colorBlind[3] + (nextOnHud.colorBlind[3] - lastOnHud.colorBlind[3]) / numValues * (l - lastOnHud.index)
					nitrogenValue.colorBlind = {
						r,
						g,
						b
					}
				end
			end
		else
			lastOnHud = nitrogenValue
		end
	end

	self.initialValues = {}
	i = 0

	while true do
		local baseKey = string.format("%s.initialValues.initialValue(%d)", key, i)

		if not hasXMLProperty(xmlFile, baseKey) then
			break
		end

		local initialValue = {
			soilTypeIndex = getXMLInt(xmlFile, baseKey .. "#soilTypeIndex") or 1,
			baseRange = string.getVectorN(getXMLString(xmlFile, baseKey .. "#baseValueRange"), self.noiseMaxValue + 1)
		}

		for j = 1, #initialValue.baseRange do
			initialValue.baseRange[j] = MathUtil.round(initialValue.baseRange[j] / self.amountPerState)
		end

		table.insert(self.initialValues, initialValue)

		i = i + 1
	end

	self.initialSprayLevelBonus = {
		string.getVector(getXMLString(xmlFile, key .. ".initialValues#sprayLevelBonus") or "0 0")
	}

	for j = 1, #self.initialSprayLevelBonus do
		self.initialSprayLevelBonus[j] = MathUtil.round(self.initialSprayLevelBonus[j] / self.amountPerState)
	end

	self.fertilizerUsage = {
		nAmounts = {}
	}
	i = 0

	while true do
		local baseKey = string.format("%s.fertilizerUsage.nAmount(%d)", key, i)

		if not hasXMLProperty(xmlFile, baseKey) then
			break
		end

		local fillTypeName = getXMLString(xmlFile, baseKey .. "#fillType")

		if fillTypeName ~= nil then
			local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeName)

			if fillTypeIndex ~= nil and fillTypeIndex ~= FillType.UNKNOWN then
				local nAmount = {
					fillTypeIndex = fillTypeIndex,
					amount = getXMLFloat(xmlFile, baseKey .. "#amount") or 1
				}

				table.insert(self.fertilizerUsage.nAmounts, nAmount)
			else
				Logging.xmlWarning(xmlFile, "Invalid fill type for nitrogen fertilizer amount '%s'", baseKey)
			end
		else
			Logging.xmlWarning(xmlFile, "Invalid fill type for nitrogen fertilizer amount '%s'", baseKey)
		end

		i = i + 1
	end

	self.fruitRequirements = {}
	self.registeredFruitRequirements = {}

	self:loadFruitRequirementsFromXML(configFileName, xmlFile, key)

	local missionInfo = g_currentMission.missionInfo
	local mapXMLFilename = Utils.getFilename(missionInfo.mapXMLFilename, g_currentMission.baseDirectory)
	local mapXMLFile = loadXMLFile("MapXML", mapXMLFilename)

	if mapXMLFile ~= nil then
		self:loadFruitRequirementsFromXML(missionInfo.mapXMLFilename, mapXMLFile, "map.precisionFarming")
		delete(mapXMLFile)
	end

	for _, fruitType in ipairs(g_fruitTypeManager:getFruitTypes()) do
		if self.registeredFruitRequirements[fruitType.index] == nil then
			local fruitRequirement = {
				fruitTypeName = fruitType.name,
				fruitType = fruitType,
				bySoilType = self.fruitRequirements[1].bySoilType,
				averageTargetLevel = self.fruitRequirements[1].averageTargetLevel or 0
			}

			table.insert(self.fruitRequirements, fruitRequirement)
			Logging.devInfo("Use default Nitrogen requirements for fruitType '%s'", fruitType.name)
		end
	end

	self.yieldCurve = AnimCurve.new(linearInterpolator1)
	i = 0

	while true do
		local baseKey = string.format("%s.yieldMappings.yieldMapping(%d)", key, i)

		if not hasXMLProperty(xmlFile, baseKey) then
			break
		end

		local difference = (getXMLInt(xmlFile, baseKey .. "#difference") or 0) / self.amountPerState
		local yieldFactor = getXMLFloat(xmlFile, baseKey .. "#yieldFactor") or 1

		self.yieldCurve:addKeyframe({
			yieldFactor,
			time = difference
		})

		i = i + 1
	end

	self.applicationRates = {}
	i = 0

	while true do
		local baseKey = string.format("%s.applicationRates.applicationRate(%d)", key, i)

		if not hasXMLProperty(xmlFile, baseKey) then
			break
		end

		local fillTypeName = getXMLString(xmlFile, baseKey .. "#fillType")

		if fillTypeName ~= nil then
			local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeName)

			if fillTypeIndex ~= nil and fillTypeIndex ~= FillType.UNKNOWN then
				local applicationRate = {
					fillTypeIndex = fillTypeIndex,
					autoAdjustToFruit = Utils.getNoNil(getXMLBool(xmlFile, baseKey .. "#autoAdjustToFruit"), false),
					regularRate = getXMLFloat(xmlFile, baseKey .. "#regularRate"),
					ratesBySoilType = {}
				}
				local j = 0

				while true do
					local soilKey = string.format("%s.soil(%d)", baseKey, j)

					if not hasXMLProperty(xmlFile, soilKey) then
						break
					end

					local rateBySoil = {
						soilTypeIndex = getXMLInt(xmlFile, soilKey .. "#soilTypeIndex") or 1,
						rate = (getXMLInt(xmlFile, soilKey .. "#rate") or 5) / self.amountPerState
					}

					table.insert(applicationRate.ratesBySoilType, rateBySoil)

					j = j + 1
				end

				table.insert(self.applicationRates, applicationRate)
			else
				Logging.xmlWarning(xmlFile, "Invalid fill type for nitrogen application rate '%s'", baseKey)
			end
		else
			Logging.xmlWarning(xmlFile, "Invalid fill type for nitrogen application rate '%s'", baseKey)
		end

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
			levelDifference = (getXMLInt(xmlFile, baseKey .. "#levelDifference") or 0) / self.amountPerState,
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
		levelDifferenceColor.additionalText = g_i18n:convertText(getXMLString(xmlFile, baseKey .. "#text"), NitrogenMap.MOD_NAME)

		table.insert(self.levelDifferenceColors, levelDifferenceColor)

		i = i + 1
	end

	self.cropSensorFruitTypes = {}
	local fruitTypesStr = getXMLString(xmlFile, key .. ".cropSensor#fruitTypes")

	if fruitTypesStr ~= nil then
		local fruitTypes = fruitTypesStr:split(" ")

		for j = 1, #fruitTypes do
			local fruitType = g_fruitTypeManager:getFruitTypeByName(fruitTypes[j])

			if fruitType ~= nil then
				table.insert(self.cropSensorFruitTypes, fruitType)
			else
				Logging.xmlWarning(xmlFile, "Invalid fruit type '%s' for crop sensor '%s'", fruitTypes[j], key)
			end
		end
	end

	self.choppedStrawStateChange = (getXMLInt(xmlFile, key .. ".choppedStraw#increase") or 25) / self.amountPerState
	self.catchCropsStateChange = (getXMLInt(xmlFile, key .. ".catchCrops#increase") or 25) / self.amountPerState
	self.outdatedLabel = g_i18n:convertText(getXMLString(xmlFile, key .. ".texts#outdatedLabel") or "$l10n_ui_precisionFarming_outdatedData", NitrogenMap.MOD_NAME)
	self.minimapGradientLabelName = string.format("%d - %d kg/ha", self:getMinMaxValue())
	self.coverMap = g_precisionFarming.coverMap
	self.soilMap = g_precisionFarming.soilMap

	return true
end

function NitrogenMap:loadFruitRequirementsFromXML(configFileName, xmlFile, key)
	local i = 0

	while true do
		local baseKey = string.format("%s.fruitRequirements.fruitRequirement(%d)", key, i)

		if not hasXMLProperty(xmlFile, baseKey) then
			break
		end

		local isOverwrittenRequirement = false
		local fruitRequirement = {
			fruitTypeName = getXMLString(xmlFile, baseKey .. "#fruitTypeName")
		}

		if fruitRequirement.fruitTypeName ~= nil then
			for j = 1, #self.fruitRequirements do
				local _fruitRequirement = self.fruitRequirements[j]

				if _fruitRequirement.fruitTypeName:lower() == fruitRequirement.fruitTypeName:lower() then
					fruitRequirement = _fruitRequirement
					isOverwrittenRequirement = true
				end
			end

			fruitRequirement.alwaysAllowFertilization = Utils.getNoNil(getXMLBool(xmlFile, baseKey .. "#alwaysAllowFertilization"), Utils.getNoNil(fruitRequirement.alwaysAllowFertilization, false))
			fruitRequirement.ignoreOverfertilization = Utils.getNoNil(getXMLBool(xmlFile, baseKey .. "#ignoreOverfertilization"), false)
			fruitRequirement.availableAsDefaultRate = Utils.getNoNil(getXMLBool(xmlFile, baseKey .. "#availableAsDefaultRate"), true)
			fruitRequirement.requiresDefaultMode = Utils.getNoNil(getXMLBool(xmlFile, baseKey .. "#requiresDefaultMode"), false)
			local fruitType = g_fruitTypeManager:getFruitTypeByName(fruitRequirement.fruitTypeName)

			if fruitType ~= nil then
				fruitRequirement.fruitType = fruitType
				fruitRequirement.bySoilType = fruitRequirement.bySoilType or {}
				local j = 0

				while true do
					local soilKey = string.format("%s.soil(%d)", baseKey, j)

					if not hasXMLProperty(xmlFile, soilKey) then
						break
					end

					local soilSettings = {
						soilTypeIndex = getXMLInt(xmlFile, soilKey .. "#soilTypeIndex") or 1
					}
					local isOverwrittenSoilType = false

					for l = 1, #fruitRequirement.bySoilType do
						local _soilSettings = fruitRequirement.bySoilType[l]

						if _soilSettings.soilTypeIndex == soilSettings.soilTypeIndex then
							soilSettings = _soilSettings
							isOverwrittenSoilType = true
						end
					end

					local targetLevel = getXMLInt(xmlFile, soilKey .. "#targetLevel")

					if targetLevel ~= nil then
						local _, internalTarget = self:getNearestNitrogenValueFromValue(targetLevel)
						targetLevel = internalTarget
					end

					soilSettings.targetLevel = targetLevel or soilSettings.targetLevel or 0
					local reduction = getXMLInt(xmlFile, soilKey .. "#reduction")

					if reduction ~= nil then
						reduction = math.floor(reduction / self.amountPerState)
					end

					soilSettings.reduction = reduction or soilSettings.reduction or 0
					soilSettings.yieldPotential = getXMLFloat(xmlFile, soilKey .. "#yieldPotential") or soilSettings.yieldPotential or 1

					if not isOverwrittenSoilType then
						table.insert(fruitRequirement.bySoilType, soilSettings)
					end

					j = j + 1
				end

				fruitRequirement.averageTargetLevel = 0
				local numSettings = #fruitRequirement.bySoilType

				if numSettings > 0 then
					local targetLevelSum = 0

					for l = 1, numSettings do
						local soilSettings = fruitRequirement.bySoilType[l]
						targetLevelSum = targetLevelSum + soilSettings.targetLevel
					end

					fruitRequirement.averageTargetLevel = targetLevelSum / numSettings
				end

				if not isOverwrittenRequirement then
					table.insert(self.fruitRequirements, fruitRequirement)

					self.registeredFruitRequirements[fruitType.index] = true
				end
			end
		else
			Logging.xmlWarning(configFileName, "Invalid fruit type for nitrogen fruitRequirement '%s'", baseKey)
		end

		i = i + 1
	end
end

function NitrogenMap:postLoad(xmlFile, key, baseDirectory, configFileName, mapFilename)
	if self.bitVectorMapNOffsetIsNew then
		local startTime = getTimeSec()
		local modifier = DensityMapModifier.new(self.bitVectorMapNOffset, 0, 3)
		local filter = PerlinNoiseFilter.new(self.bitVectorMapNOffset, 7, 1, 0.5, math.random(0, 1000))
		local numValues = 8
		local range = 10000

		for i = 1, numValues do
			local min = (i - 1) / numValues * range
			local max = i / numValues * range

			filter:setValueCompareParams(DensityValueCompareType.BETWEEN, min, max)
			modifier:executeSet(i - 1, filter)
		end

		Logging.devInfo("Initialized Nitrogen Offset Map in %dms", (getTimeSec() - startTime) * 1000)
	else
		local modifier = DensityMapModifier.new(self.bitVectorMap, self.firstChannel, self.numChannels)
		local filter = DensityMapFilter.new(self.bitVectorMap, self.firstChannel, self.numChannels)

		filter:setValueCompareParams(DensityValueCompareType.GREATER, self.maxValue)
		modifier:executeSet(math.floor(self.maxValue * 0.75), filter)
	end

	return true
end

local function worldCoordsToLocalCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, size, terrainSize)
	return size * (startWorldX + terrainSize * 0.5) / terrainSize, size * (startWorldZ + terrainSize * 0.5) / terrainSize, size * (widthWorldX + terrainSize * 0.5) / terrainSize, size * (widthWorldZ + terrainSize * 0.5) / terrainSize, size * (heightWorldX + terrainSize * 0.5) / terrainSize, size * (heightWorldZ + terrainSize * 0.5) / terrainSize
end

function NitrogenMap:setInitialState(soilBitVector, soilTypeFirstChannel, soilTypeNumChannels, coverChannel, farmlandMask)
	local modifier = self.densityMapModifiersInitialize.modifier
	local soilFilter = self.densityMapModifiersInitialize.soilFilter
	local noiseFilter = self.densityMapModifiersInitialize.noiseFilter
	local nInitModifier = self.densityMapModifiersInitialize.nInitModifier
	local nInitMaskFilter = self.densityMapModifiersInitialize.nInitMaskFilter
	local sprayLevelFilter = self.densityMapModifiersInitialize.sprayLevelFilter
	local maxSprayLevel = self.densityMapModifiersInitialize.maxSprayLevel

	if modifier == nil or soilFilter == nil or noiseFilter == nil or nInitModifier == nil or nInitMaskFilter == nil or sprayLevelFilter == nil or maxSprayLevel == nil then
		self.densityMapModifiersInitialize.modifier = DensityMapModifier.new(self.bitVectorMap, self.firstChannel, self.numChannels)
		modifier = self.densityMapModifiersInitialize.modifier
		self.densityMapModifiersInitialize.soilFilter = DensityMapFilter.new(soilBitVector, soilTypeFirstChannel, soilTypeNumChannels)
		soilFilter = self.densityMapModifiersInitialize.soilFilter
		self.densityMapModifiersInitialize.noiseFilter = DensityMapFilter.new(self.bitVectorMapNoise, 0, self.noiseNumChannels)
		noiseFilter = self.densityMapModifiersInitialize.noiseFilter
		self.densityMapModifiersInitialize.nInitModifier = DensityMapModifier.new(self.bitVectorMapNInitMask, 0, 1)
		nInitModifier = self.densityMapModifiersInitialize.nInitModifier
		self.densityMapModifiersInitialize.nInitMaskFilter = DensityMapFilter.new(self.bitVectorMapNInitMask, 0, 1)
		nInitMaskFilter = self.densityMapModifiersInitialize.nInitMaskFilter

		nInitMaskFilter:setValueCompareParams(DensityValueCompareType.EQUAL, 1)

		local sprayMapId, sprayLevelFirstChannel, sprayLevelNumChannels = g_currentMission.fieldGroundSystem:getDensityMapData(FieldDensityMap.SPRAY_LEVEL)
		self.densityMapModifiersInitialize.sprayLevelFilter = DensityMapFilter.new(sprayMapId, sprayLevelFirstChannel, sprayLevelNumChannels)
		sprayLevelFilter = self.densityMapModifiersInitialize.sprayLevelFilter
		self.densityMapModifiersInitialize.maxSprayLevel = g_currentMission.fieldGroundSystem:getMaxValue(FieldDensityMap.SPRAY_LEVEL)
		maxSprayLevel = self.densityMapModifiersInitialize.maxSprayLevel
	end

	for i = 1, #self.initialValues do
		local initialValue = self.initialValues[i]

		soilFilter:setValueCompareParams(DensityValueCompareType.NOTEQUAL, initialValue.soilTypeIndex - 1)

		local filter = soilFilter

		if farmlandMask ~= nil then
			nInitModifier:executeSet(0)
			nInitModifier:executeSet(1, farmlandMask, soilFilter)

			filter = nInitMaskFilter
		end

		for j = 1, self.noiseMaxValue + 1 do
			noiseFilter:setValueCompareParams(DensityValueCompareType.EQUAL, j - 1)
			modifier:executeSet(initialValue.baseRange[j], filter, noiseFilter)
		end
	end

	for sprayLevel = 1, maxSprayLevel do
		sprayLevelFilter:setValueCompareParams(DensityValueCompareType.EQUAL, sprayLevel)
		modifier:executeAdd(self.initialSprayLevelBonus[sprayLevel] or 0, sprayLevelFilter, farmlandMask)
	end

	self:setMinimapRequiresUpdate(true)
end

function NitrogenMap:onHarvestCoverUpdate(fruitFilter, sprayTypeFilter, fruitIndex, fruitUsed, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, useMinForageState)
	if fruitUsed then
		local coverMap = self.coverMap
		local soilMap = self.soilMap

		if coverMap ~= nil and coverMap.bitVectorMap ~= nil and soilMap ~= nil and soilMap.bitVectorMap ~= nil then
			local modifier = self.densityMapModifiersHarvest.modifier
			local modifierLock = self.densityMapModifiersHarvest.modifierLock
			local soilFilter = self.densityMapModifiersHarvest.soilFilter
			local nFilter = self.densityMapModifiersHarvest.nFilter
			local lockFilter = self.densityMapModifiersHarvest.lockFilter
			local coverFilter = self.densityMapModifiersHarvest.coverFilter
			local modifierOffsetMeasured = self.densityMapModifiersHarvest.modifierOffsetMeasured

			if modifier == nil or modifierLock == nil or lockFilter == nil or soilFilter == nil or nFilter == nil or coverFilter == nil or modifierOffsetMeasured == nil then
				self.densityMapModifiersHarvest.modifier = DensityMapModifier.new(self.bitVectorMap, self.firstChannel, self.numChannels)
				modifier = self.densityMapModifiersHarvest.modifier

				modifier:setPolygonRoundingMode(DensityRoundingMode.INCLUSIVE)

				self.densityMapModifiersHarvest.soilFilter = DensityMapFilter.new(soilMap.bitVectorMap, soilMap.typeFirstChannel, soilMap.typeNumChannels)
				soilFilter = self.densityMapModifiersHarvest.soilFilter
				self.densityMapModifiersHarvest.nFilter = DensityMapFilter.new(self.bitVectorMap, self.firstChannel, self.numChannels)
				nFilter = self.densityMapModifiersHarvest.nFilter

				nFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 1, self.maxValue)

				self.densityMapModifiersHarvest.modifierLock = DensityMapModifier.new(self.bitVectorMapNStateChange, 0, 1)
				modifierLock = self.densityMapModifiersHarvest.modifierLock

				modifierLock:setPolygonRoundingMode(DensityRoundingMode.INCLUSIVE)

				self.densityMapModifiersHarvest.lockFilter = DensityMapFilter.new(self.bitVectorMapNStateChange, 0, 1)
				lockFilter = self.densityMapModifiersHarvest.lockFilter

				lockFilter:setValueCompareParams(DensityValueCompareType.EQUAL, 1)

				self.densityMapModifiersHarvest.coverFilter = DensityMapFilter.new(coverMap.bitVectorMap, coverMap.firstChannel, coverMap.numChannels)
				coverFilter = self.densityMapModifiersHarvest.coverFilter

				coverFilter:setValueCompareParams(DensityValueCompareType.GREATER, 1)

				self.densityMapModifiersHarvest.modifierOffsetMeasured = DensityMapModifier.new(self.bitVectorMapNOffset, 3, 1)
				modifierOffsetMeasured = self.densityMapModifiersHarvest.modifierOffsetMeasured
			end

			modifier:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)
			modifierLock:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)
			modifierOffsetMeasured:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)
			self:updateCropSensorArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, true, true, sprayTypeFilter, fruitFilter)
			modifierOffsetMeasured:executeSet(0, fruitFilter, sprayTypeFilter)

			local nMapChanged = false

			for i = 1, #self.fruitRequirements do
				local fruitRequirement = self.fruitRequirements[i]

				if fruitRequirement.fruitType.index == fruitIndex then
					for j = 1, #fruitRequirement.bySoilType do
						local soilSettings = fruitRequirement.bySoilType[j]

						soilFilter:setValueCompareParams(DensityValueCompareType.EQUAL, soilSettings.soilTypeIndex - 1)
						modifierLock:executeSet(1, fruitFilter, sprayTypeFilter)
						coverFilter:setValueCompareParams(DensityValueCompareType.GREATER, 1)

						local _, unlockedPixels = modifierLock:executeGet(coverFilter)

						if unlockedPixels > 0 then
							coverFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 0, 1)
							modifierLock:executeSet(0, coverFilter)
						end

						local acc, numPixels, _ = modifier:executeGet(lockFilter, soilFilter, nFilter)

						if numPixels > 0 then
							local state = acc / numPixels

							if soilSettings.reduction > 1 then
								modifierLock:executeSet(1, fruitFilter, sprayTypeFilter)
								modifier:executeSet(math.max(state - soilSettings.reduction, 1), lockFilter, soilFilter, nFilter)
							end

							self.lastActualValue = state
							self.lastTargetValue = soilSettings.targetLevel
							self.lastYieldPotential = soilSettings.yieldPotential
							self.lastIgnoreOverfertilization = fruitRequirement.ignoreOverfertilization
							self.lastRegularNValue = fruitRequirement.averageTargetLevel
							nMapChanged = true
						end

						modifierLock:executeSet(0)
					end
				end
			end

			if nMapChanged then
				self:setMinimapRequiresUpdate(true)
			end

			return nMapChanged
		end
	end

	return false
end

local function applyAutomaticSprayRateForFruitType(fruitRequirement, modifier, fruitFilter, soilFilter, nFilter, tempFruitModifier, tempFruitFilter, maskFilter, offFieldFilter, ignoreFruitFilter)
	local numPixelsChanged = 0
	local autoFruitTypeIndex = FruitType.UNKNOWN
	local autoSoilTypeIndex = 0
	local foundLevel = 0
	local targetLevel = 0
	local numChangedTypes = 0
	local appliedAutoFruitTypeRate = false
	local fruitDesc = fruitRequirement.fruitType

	if fruitDesc == nil or fruitDesc.terrainDataPlaneId == 0 or fruitDesc.weed ~= nil then
		return appliedAutoFruitTypeRate, foundLevel, targetLevel, numChangedTypes, numPixelsChanged, autoFruitTypeIndex, autoSoilTypeIndex
	end

	if not ignoreFruitFilter then
		tempFruitModifier:executeSet(0)
		fruitFilter:resetDensityMapAndChannels(fruitDesc.terrainDataPlaneId, fruitDesc.startStateChannel, fruitDesc.numStateChannels)

		if fruitRequirement.alwaysAllowFertilization then
			fruitFilter:setValueCompareParams(DensityValueCompareType.GREATER, 0)
		else
			fruitFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 1, fruitDesc.minHarvestingGrowthState)
		end

		tempFruitModifier:executeSet(1, fruitFilter)
		tempFruitModifier:executeSet(0, offFieldFilter)

		local _, numPixels, _ = tempFruitModifier:executeGet(tempFruitFilter)

		if numPixels > 0 then
			tempFruitModifier:executeSet(1, fruitFilter)
		elseif not fruitRequirement.alwaysAllowFertilization then
			fruitFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, fruitDesc.minHarvestingGrowthState, fruitDesc.maxHarvestingGrowthState)

			_, numPixels, _ = modifier:executeGet(fruitFilter)

			if numPixels > 0 then
				return true, foundLevel, targetLevel, numChangedTypes, numPixelsChanged, autoFruitTypeIndex, autoSoilTypeIndex
			end
		end
	else
		tempFruitModifier:executeSet(1)
	end

	maskFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 0, 1)
	tempFruitModifier:executeSet(0, maskFilter)

	local _, numPixels, _ = modifier:executeGet(tempFruitFilter)

	if numPixels > 0 then
		for j = 1, #fruitRequirement.bySoilType do
			local soilSettings = fruitRequirement.bySoilType[j]

			soilFilter:setValueCompareParams(DensityValueCompareType.EQUAL, soilSettings.soilTypeIndex - 1)
			nFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 1, soilSettings.targetLevel - 1)

			local acc = nil
			acc, numPixels, _ = modifier:executeGet(tempFruitFilter, soilFilter, nFilter)

			if numPixels > 0 then
				local state = acc / numPixels
				foundLevel = foundLevel + state
				targetLevel = targetLevel + soilSettings.targetLevel
				numPixelsChanged = numPixelsChanged + numPixels
				numChangedTypes = numChangedTypes + 1

				modifier:executeSet(math.max(state, soilSettings.targetLevel), tempFruitFilter, soilFilter, nFilter)

				autoFruitTypeIndex = fruitDesc.index
				autoSoilTypeIndex = soilSettings.soilTypeIndex
				appliedAutoFruitTypeRate = true
			else
				_, numPixels, _ = modifier:executeGet(tempFruitFilter, soilFilter)

				if numPixels > 0 then
					appliedAutoFruitTypeRate = true
				end
			end
		end
	end

	return appliedAutoFruitTypeRate, foundLevel, targetLevel, numChangedTypes, numPixelsChanged, autoFruitTypeIndex, autoSoilTypeIndex
end

function NitrogenMap:updateSprayArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, sprayTypeIndex, lockSprayTypeIndex, automaticallyAdjusted, manualSprayRate, forcedFruitType, nitrogenLevelOffset, defaultNitrogenRequirementIndex)
	local coverMap = self.coverMap
	local soilMap = self.soilMap

	if coverMap ~= nil and coverMap.bitVectorMap ~= nil and soilMap ~= nil and soilMap.bitVectorMap ~= nil then
		local lockGroundType = 0
		local lockDesc = g_sprayTypeManager:getSprayTypeByIndex(lockSprayTypeIndex)

		if lockDesc ~= nil then
			lockGroundType = lockDesc.sprayGroundType
		end

		local desc = g_sprayTypeManager:getSprayTypeByIndex(sprayTypeIndex)

		if desc ~= nil and desc.isFertilizer then
			local modifier = self.densityMapModifiersSpray.modifier
			local soilFilter = self.densityMapModifiersSpray.soilFilter
			local nFilter = self.densityMapModifiersSpray.nFilter
			local maskFilter = self.densityMapModifiersSpray.maskFilter
			local fruitFilter = self.densityMapModifiersSpray.fruitFilter
			local modifierLock = self.densityMapModifiersSpray.modifierLock
			local lockFilter = self.densityMapModifiersSpray.lockFilter
			local sprayTypeFilter = self.densityMapModifiersSpray.sprayTypeFilter
			local offFieldFilter = self.densityMapModifiersSpray.offFieldFilter
			local tempFruitModifier = self.densityMapModifiersSpray.tempFruitModifier
			local tempFruitFilter = self.densityMapModifiersSpray.tempFruitFilter

			if modifier == nil or soilFilter == nil or nFilter == nil or maskFilter == nil or fruitFilter == nil or modifierLock == nil or lockFilter == nil or sprayTypeFilter == nil or offFieldFilter == nil or tempFruitModifier == nil or tempFruitFilter == nil then
				self.densityMapModifiersSpray.modifier = DensityMapModifier.new(self.bitVectorMap, self.firstChannel, self.numChannels)
				modifier = self.densityMapModifiersSpray.modifier

				modifier:setPolygonRoundingMode(DensityRoundingMode.INCLUSIVE)

				self.densityMapModifiersSpray.soilFilter = DensityMapFilter.new(soilMap.bitVectorMap, soilMap.typeFirstChannel, soilMap.typeNumChannels)
				soilFilter = self.densityMapModifiersSpray.soilFilter
				self.densityMapModifiersSpray.nFilter = DensityMapFilter.new(self.bitVectorMap, self.firstChannel, self.numChannels)
				nFilter = self.densityMapModifiersSpray.nFilter
				self.densityMapModifiersSpray.maskFilter = DensityMapFilter.new(coverMap.bitVectorMap, coverMap.firstChannel, coverMap.numChannels)
				maskFilter = self.densityMapModifiersSpray.maskFilter

				maskFilter:setValueCompareParams(DensityValueCompareType.GREATER, 1)

				self.densityMapModifiersSpray.fruitFilter = DensityMapFilter.new(modifier)
				fruitFilter = self.densityMapModifiersSpray.fruitFilter
				self.densityMapModifiersSpray.modifierLock = DensityMapModifier.new(self.bitVectorMapNStateChange, 1, 1)
				modifierLock = self.densityMapModifiersSpray.modifierLock

				modifierLock:setPolygonRoundingMode(DensityRoundingMode.INCLUSIVE)

				self.densityMapModifiersSpray.lockFilter = DensityMapFilter.new(self.bitVectorMapNStateChange, 1, 1)
				lockFilter = self.densityMapModifiersSpray.lockFilter

				lockFilter:setValueCompareParams(DensityValueCompareType.EQUAL, 0)

				local fieldGroundSystem = g_currentMission.fieldGroundSystem
				local sprayTypeMapId, sprayTypeFirstChannel, sprayTypeNumChannels = fieldGroundSystem:getDensityMapData(FieldDensityMap.SPRAY_TYPE)
				local groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels = fieldGroundSystem:getDensityMapData(FieldDensityMap.GROUND_TYPE)
				self.densityMapModifiersSpray.sprayTypeFilter = DensityMapFilter.new(sprayTypeMapId, sprayTypeFirstChannel, sprayTypeNumChannels)
				sprayTypeFilter = self.densityMapModifiersSpray.sprayTypeFilter

				sprayTypeFilter:setValueCompareParams(DensityValueCompareType.GREATER, 0)

				self.densityMapModifiersSpray.offFieldFilter = DensityMapFilter.new(groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels)
				offFieldFilter = self.densityMapModifiersSpray.offFieldFilter

				offFieldFilter:setValueCompareParams(DensityValueCompareType.EQUAL, 0)

				self.densityMapModifiersSpray.tempFruitModifier = DensityMapModifier.new(self.bitVectorMapNFruitFilterMask, 0, 1)
				tempFruitModifier = self.densityMapModifiersSpray.tempFruitModifier

				tempFruitModifier:setPolygonRoundingMode(DensityRoundingMode.INCLUSIVE)

				self.densityMapModifiersSpray.tempFruitFilter = DensityMapFilter.new(self.bitVectorMapNFruitFilterMask, 0, 1)
				tempFruitFilter = self.densityMapModifiersSpray.tempFruitFilter

				tempFruitFilter:setValueCompareParams(DensityValueCompareType.EQUAL, 1)
			end

			startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ = worldCoordsToLocalCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, self.sizeX, g_currentMission.terrainSize)

			modifier:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)
			modifierLock:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)
			tempFruitModifier:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)

			local numPixelsChanged = 0
			local autoFruitTypeIndex = FruitType.UNKNOWN
			local autoSoilTypeIndex = 0
			local foundLevel = 0
			local targetLevel = 0
			local numChangedTypes = 0

			sprayTypeFilter:setValueCompareParams(DensityValueCompareType.NOTEQUAL, lockGroundType)
			modifierLock:executeSet(0, sprayTypeFilter)
			sprayTypeFilter:setValueCompareParams(DensityValueCompareType.EQUAL, lockGroundType)
			modifierLock:executeSet(1, sprayTypeFilter)
			sprayTypeFilter:setValueCompareParams(DensityValueCompareType.EQUAL, 0)
			maskFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 1, coverMap.maxValue)

			local _, unlockedPixels, _ = modifier:executeGet(maskFilter)

			if unlockedPixels == 0 and automaticallyAdjusted then
				automaticallyAdjusted = false

				for i = 1, #self.applicationRates do
					local applicationRate = self.applicationRates[i]

					if applicationRate.fillTypeIndex == desc.fillType.index then
						manualSprayRate = applicationRate.regularRate / self.amountPerState
					end
				end
			elseif unlockedPixels > 0 then
				maskFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 0, 1)
				modifierLock:executeSet(1, maskFilter)
				maskFilter:setValueCompareParams(DensityValueCompareType.EQUAL, coverMap.maxValue + 1)
				modifierLock:executeSet(1, maskFilter)
			end

			for ai = 1, #self.applicationRates do
				local applicationRate = self.applicationRates[ai]

				if applicationRate.fillTypeIndex == desc.fillType.index then
					local appliedAutoFruitTypeRate = false

					if applicationRate.autoAdjustToFruit and automaticallyAdjusted and forcedFruitType == nil then
						for i = 1, #self.fruitRequirements do
							local fruitRequirement = self.fruitRequirements[i]
							local _appliedAutoFruitTypeRate, _foundLevel, _targetLevel, _numChangedTypes, _numPixelsChanged, _autoFruitTypeIndex, _autoSoilTypeIndex = applyAutomaticSprayRateForFruitType(fruitRequirement, modifier, fruitFilter, soilFilter, nFilter, tempFruitModifier, tempFruitFilter, maskFilter, offFieldFilter, false)
							appliedAutoFruitTypeRate = appliedAutoFruitTypeRate or _appliedAutoFruitTypeRate
							foundLevel = foundLevel + _foundLevel
							targetLevel = targetLevel + _targetLevel
							numPixelsChanged = numPixelsChanged + _numPixelsChanged
							numChangedTypes = numChangedTypes + _numChangedTypes

							if _autoFruitTypeIndex ~= FruitType.UNKNOWN then
								autoFruitTypeIndex = _autoFruitTypeIndex
							end

							if _autoSoilTypeIndex > 0 then
								autoSoilTypeIndex = _autoSoilTypeIndex
							end
						end
					end

					if applicationRate.autoAdjustToFruit and not appliedAutoFruitTypeRate and automaticallyAdjusted then
						local fruitRequirement = self.fruitRequirements[defaultNitrogenRequirementIndex or 1] or self.fruitRequirements[1]

						if forcedFruitType ~= nil then
							for i = 1, #self.fruitRequirements do
								if self.fruitRequirements[i].fruitType.index == forcedFruitType then
									fruitRequirement = self.fruitRequirements[i]
								end
							end

							autoFruitTypeIndex = forcedFruitType
						end

						local _, _foundLevel, _targetLevel, _numChangedTypes, _numPixelsChanged, _, _autoSoilTypeIndex = applyAutomaticSprayRateForFruitType(fruitRequirement, modifier, fruitFilter, soilFilter, nFilter, tempFruitModifier, tempFruitFilter, maskFilter, offFieldFilter, true)
						foundLevel = foundLevel + _foundLevel
						targetLevel = targetLevel + _targetLevel
						numPixelsChanged = numPixelsChanged + _numPixelsChanged
						numChangedTypes = numChangedTypes + _numChangedTypes

						if _autoSoilTypeIndex > 0 then
							autoSoilTypeIndex = _autoSoilTypeIndex
						end
					end

					if not applicationRate.autoAdjustToFruit and automaticallyAdjusted then
						for i = 1, #applicationRate.ratesBySoilType do
							local rateBySoilType = applicationRate.ratesBySoilType[i]
							local rate = rateBySoilType.rate + nitrogenLevelOffset

							soilFilter:setValueCompareParams(DensityValueCompareType.EQUAL, rateBySoilType.soilTypeIndex - 1)
							nFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, self.maxValue - rate + 1, self.maxValue)

							local acc, numPixels, _ = modifier:executeSet(self.maxValue, lockFilter, soilFilter, nFilter)

							if numPixels > 0 then
								local state = acc / numPixels
								foundLevel = foundLevel + state
								targetLevel = targetLevel + self.maxValue
								numPixelsChanged = numPixelsChanged + numPixels
								numChangedTypes = numChangedTypes + 1
								autoSoilTypeIndex = rateBySoilType.soilTypeIndex
							end

							nFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 1, self.maxValue - rate)

							acc, numPixels, _ = modifier:executeGet(lockFilter, soilFilter, nFilter)

							if numPixels > 0 then
								local state = acc / numPixels
								foundLevel = foundLevel + state
								targetLevel = targetLevel + state + rateBySoilType.rate
								numPixelsChanged = numPixelsChanged + numPixels
								numChangedTypes = numChangedTypes + 1

								modifier:executeAdd(rate, lockFilter, soilFilter, nFilter)

								autoSoilTypeIndex = rateBySoilType.soilTypeIndex
							end
						end

						break
					end

					if not automaticallyAdjusted then
						local acc, numPixels, _ = modifier:executeGet(lockFilter)

						if numPixels > 0 then
							local currentState = acc / numPixels
							local rate = manualSprayRate + nitrogenLevelOffset

							nFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, self.maxValue - rate + 1, self.maxValue)
							modifier:executeSet(self.maxValue, lockFilter, nFilter)
							nFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 1, self.maxValue - rate)
							modifier:executeAdd(rate, lockFilter, nFilter)

							foundLevel = foundLevel + currentState
							targetLevel = targetLevel + math.min(currentState + manualSprayRate, self.maxValue)
							numPixelsChanged = numPixelsChanged + numPixels
							numChangedTypes = numChangedTypes + 1

							if unlockedPixels == 0 then
								foundLevel = 0
								targetLevel = rate
								numChangedTypes = 1
							end
						end
					end

					break
				end
			end

			foundLevel = math.floor(foundLevel / numChangedTypes)
			targetLevel = math.floor(targetLevel / numChangedTypes)
			local changeLevel = targetLevel - foundLevel

			if numPixelsChanged > 0 then
				self:setMinimapRequiresUpdate(true)
			end

			return numPixelsChanged, autoFruitTypeIndex, autoSoilTypeIndex, foundLevel, targetLevel, changeLevel, automaticallyAdjusted
		end
	end

	return 0
end

function NitrogenMap:postUpdateSprayArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, sprayTypeIndex, lockSprayTypeIndex, automaticallyAdjusted, manualSprayRate)
	local soilMap = self.soilMap

	if soilMap ~= nil and soilMap.bitVectorMap ~= nil then
		local lockGroundType = 0
		local lockDesc = g_sprayTypeManager:getSprayTypeByIndex(lockSprayTypeIndex)

		if lockDesc ~= nil then
			lockGroundType = lockDesc.sprayGroundType
		end

		local desc = g_sprayTypeManager:getSprayTypeByIndex(sprayTypeIndex)

		if desc ~= nil and desc.isFertilizer then
			local modifierLock = self.densityMapModifiersSpray.modifierLock
			local sprayTypeFilter = self.densityMapModifiersSpray.sprayTypeFilter

			if modifierLock ~= nil and sprayTypeFilter ~= nil then
				startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ = worldCoordsToLocalCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, self.sizeX, g_currentMission.terrainSize)

				modifierLock:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)
				modifierLock:setPolygonRoundingMode(DensityRoundingMode.INCLUSIVE)
				modifierLock:executeSet(0)
				sprayTypeFilter:setValueCompareParams(DensityValueCompareType.EQUAL, lockGroundType)
				modifierLock:executeSet(1, sprayTypeFilter)
			end
		end
	end

	return 0
end

function NitrogenMap:updateDestroyCommonArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
	local soilMap = self.soilMap

	if soilMap ~= nil and soilMap.bitVectorMap ~= nil then
		local modifier = self.densityMapModifiersDestroyFruit.modifier
		local nFilter = self.densityMapModifiersDestroyFruit.nFilter
		local fruitFilter = self.densityMapModifiersDestroyFruit.fruitFilter
		local modifierLock = self.densityMapModifiersDestroyFruit.modifierLock
		local lockFilter = self.densityMapModifiersDestroyFruit.lockFilter
		local fruitIndices = self.densityMapModifiersDestroyFruit.fruitIndices

		if modifier == nil or nFilter == nil or fruitFilter == nil or modifierLock == nil or lockFilter == nil or fruitIndices == nil then
			self.densityMapModifiersDestroyFruit.modifier = DensityMapModifier.new(self.bitVectorMap, self.firstChannel, self.numChannels)
			modifier = self.densityMapModifiersDestroyFruit.modifier

			modifier:setPolygonRoundingMode(DensityRoundingMode.INCLUSIVE)

			self.densityMapModifiersDestroyFruit.nFilter = DensityMapFilter.new(self.bitVectorMap, self.firstChannel, self.numChannels)
			nFilter = self.densityMapModifiersDestroyFruit.nFilter

			nFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 0, self.maxValue - 1)

			self.densityMapModifiersDestroyFruit.fruitFilter = DensityMapFilter.new(modifier)
			fruitFilter = self.densityMapModifiersDestroyFruit.fruitFilter
			self.densityMapModifiersDestroyFruit.modifierLock = DensityMapModifier.new(self.bitVectorMapNFruitDestroyMask, 0, 2)
			modifierLock = self.densityMapModifiersDestroyFruit.modifierLock

			modifierLock:setPolygonRoundingMode(DensityRoundingMode.INCLUSIVE)

			self.densityMapModifiersDestroyFruit.lockFilter = DensityMapFilter.new(self.bitVectorMapNFruitDestroyMask, 0, 2)
			lockFilter = self.densityMapModifiersDestroyFruit.lockFilter

			lockFilter:setValueCompareParams(DensityValueCompareType.EQUAL, 1)

			self.densityMapModifiersDestroyFruit.fruitIndices = {}
			fruitIndices = self.densityMapModifiersDestroyFruit.fruitIndices

			for i = 1, 15 do
				fruitIndices[i] = {
					terrainDataPlaneId = 0,
					index = 0,
					active = false
				}
			end
		end

		startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ = worldCoordsToLocalCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, self.sizeX, g_currentMission.terrainSize)

		modifierLock:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)

		for i = 1, 15 do
			fruitIndices[i].active = false
		end

		modifierLock:executeSet(0)

		for index, desc in pairs(g_fruitTypeManager:getFruitTypes()) do
			if desc.weed == nil and desc.terrainDataPlaneId ~= nil then
				fruitFilter:resetDensityMapAndChannels(desc.terrainDataPlaneId, desc.startStateChannel, desc.numStateChannels)
				fruitFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 2, desc.numGrowthStates)

				local _, numPixels = modifierLock:executeSet(1, fruitFilter)

				if numPixels > 0 then
					for i = 1, 15 do
						if not fruitIndices[i].active then
							fruitIndices[i].index = index
							fruitIndices[i].terrainDataPlaneId = desc.terrainDataPlaneId
							fruitIndices[i].active = true

							break
						end
					end
				end
			end
		end
	end

	return 0
end

function NitrogenMap:postUpdateDestroyCommonArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
	local soilMap = self.soilMap

	if soilMap ~= nil and soilMap.bitVectorMap ~= nil then
		local modifier = self.densityMapModifiersDestroyFruit.modifier
		local nFilter = self.densityMapModifiersDestroyFruit.nFilter
		local fruitFilter = self.densityMapModifiersDestroyFruit.fruitFilter
		local modifierLock = self.densityMapModifiersDestroyFruit.modifierLock
		local lockFilter = self.densityMapModifiersDestroyFruit.lockFilter
		local fruitIndices = self.densityMapModifiersDestroyFruit.fruitIndices
		startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ = worldCoordsToLocalCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, self.sizeX, g_currentMission.terrainSize)

		modifier:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)

		for i = 1, 15 do
			if fruitIndices[i].active then
				local desc = g_fruitTypeManager:getFruitTypeByIndex(fruitIndices[i].index)

				fruitFilter:resetDensityMapAndChannels(fruitIndices[i].terrainDataPlaneId, desc.startStateChannel, desc.numStateChannels)
				fruitFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 2, desc.numGrowthStates)
				modifierLock:executeSet(2, fruitFilter)
			else
				break
			end
		end

		nFilter:setValueCompareParams(DensityValueCompareType.EQUAL, self.maxValue - self.catchCropsStateChange)
		modifier:executeSet(self.maxValue, lockFilter, nFilter)
		nFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 0, self.maxValue - self.catchCropsStateChange)
		modifier:executeAdd(self.catchCropsStateChange, lockFilter, nFilter)
	end

	return 0
end

function NitrogenMap:preUpdateStrawChopperArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, strawGroundType)
	local modifier = self.densityMapModifiersStrawChopper.modifier
	local nFilter = self.densityMapModifiersStrawChopper.nFilter
	local maskModifier = self.densityMapModifiersStrawChopper.maskModifier
	local maskFilter = self.densityMapModifiersStrawChopper.maskFilter
	local sprayTypeFilter = self.densityMapModifiersStrawChopper.sprayTypeFilter

	if modifier == nil or nFilter == nil or maskModifier == nil or maskFilter == nil or sprayTypeFilter == nil then
		self.densityMapModifiersStrawChopper.modifier = DensityMapModifier.new(self.bitVectorMap, self.firstChannel, self.numChannels)
		self.densityMapModifiersStrawChopper.nFilter = DensityMapFilter.new(self.bitVectorMap, self.firstChannel, self.numChannels)
		nFilter = self.densityMapModifiersStrawChopper.nFilter
		self.densityMapModifiersStrawChopper.maskModifier = DensityMapModifier.new(self.bitVectorMapChoppedStrawMask, 0, 1)
		maskModifier = self.densityMapModifiersStrawChopper.maskModifier
		self.densityMapModifiersStrawChopper.maskFilter = DensityMapFilter.new(self.bitVectorMapChoppedStrawMask, 0, 1)
		maskFilter = self.densityMapModifiersStrawChopper.maskFilter

		maskFilter:setValueCompareParams(DensityValueCompareType.EQUAL, 1)

		local terrainRootNode = g_currentMission.terrainRootNode
		local fieldGroundSystem = g_currentMission.fieldGroundSystem
		local sprayTypeMapId, sprayTypeFirstChannel, sprayTypeNumChannels = fieldGroundSystem:getDensityMapData(FieldDensityMap.SPRAY_TYPE)
		self.densityMapModifiersStrawChopper.sprayTypeFilter = DensityMapFilter.new(sprayTypeMapId, sprayTypeFirstChannel, sprayTypeNumChannels, terrainRootNode)
		sprayTypeFilter = self.densityMapModifiersStrawChopper.sprayTypeFilter

		sprayTypeFilter:setValueCompareParams(DensityValueCompareType.NOTEQUAL, strawGroundType)
	end

	startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ = worldCoordsToLocalCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, self.sizeX, g_currentMission.terrainSize)

	maskModifier:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)
	maskModifier:executeSet(1)
	sprayTypeFilter:setValueCompareParams(DensityValueCompareType.EQUAL, strawGroundType)
	maskModifier:executeSet(0, sprayTypeFilter)
	nFilter:setValueCompareParams(DensityValueCompareType.GREATER, self.maxValue - self.choppedStrawStateChange)
	maskModifier:executeSet(0, nFilter)
end

function NitrogenMap:postUpdateStrawChopperArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, strawGroundType)
	local modifier = self.densityMapModifiersStrawChopper.modifier
	local maskFilter = self.densityMapModifiersStrawChopper.maskFilter
	local sprayTypeFilter = self.densityMapModifiersStrawChopper.sprayTypeFilter

	sprayTypeFilter:setValueCompareParams(DensityValueCompareType.EQUAL, strawGroundType)

	startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ = worldCoordsToLocalCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, self.sizeX, g_currentMission.terrainSize)

	modifier:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)
	modifier:executeAdd(self.choppedStrawStateChange, maskFilter, sprayTypeFilter)
end

function NitrogenMap:updateCropSensorArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, ignoreFruitFilter, localSpace, changeFilter, changeFilter2)
	local modifierMeasured = self.densityMapModifiersCropSensor.modifierMeasured
	local measuredFilter = self.densityMapModifiersCropSensor.measuredFilter
	local nModifier = self.densityMapModifiersCropSensor.nModifier
	local nFilter = self.densityMapModifiersCropSensor.nFilter
	local offsetFilter = self.densityMapModifiersCropSensor.offsetFilter
	local tempFruitModifier = self.densityMapModifiersCropSensor.tempFruitModifier
	local tempFruitFilter = self.densityMapModifiersCropSensor.tempFruitFilter
	local fruitFilter = self.densityMapModifiersCropSensor.fruitFilter

	if modifierMeasured == nil or measuredFilter == nil or nModifier == nil or nFilter == nil or offsetFilter == nil or tempFruitModifier == nil or tempFruitFilter == nil or fruitFilter == nil then
		self.densityMapModifiersCropSensor.modifierMeasured = DensityMapModifier.new(self.bitVectorMapNOffset, 3, 1)
		modifierMeasured = self.densityMapModifiersCropSensor.modifierMeasured
		self.densityMapModifiersCropSensor.measuredFilter = DensityMapFilter.new(self.bitVectorMapNOffset, 3, 1)
		measuredFilter = self.densityMapModifiersCropSensor.measuredFilter

		measuredFilter:setValueCompareParams(DensityValueCompareType.EQUAL, 0)

		self.densityMapModifiersCropSensor.nModifier = DensityMapModifier.new(self.bitVectorMap, self.firstChannel, self.numChannels)
		nModifier = self.densityMapModifiersCropSensor.nModifier
		self.densityMapModifiersCropSensor.nFilter = DensityMapFilter.new(self.bitVectorMap, self.firstChannel, self.numChannels)
		nFilter = self.densityMapModifiersCropSensor.nFilter

		nFilter:setValueCompareParams(DensityValueCompareType.GREATER, self.maxValue)

		self.densityMapModifiersCropSensor.offsetFilter = DensityMapFilter.new(self.bitVectorMapNOffset, 0, 3)
		offsetFilter = self.densityMapModifiersCropSensor.offsetFilter
		self.densityMapModifiersCropSensor.tempFruitModifier = DensityMapModifier.new(self.bitVectorMapNFruitFilterMask, 0, 1)
		tempFruitModifier = self.densityMapModifiersCropSensor.tempFruitModifier

		tempFruitModifier:setPolygonRoundingMode(DensityRoundingMode.INCLUSIVE)

		self.densityMapModifiersCropSensor.tempFruitFilter = DensityMapFilter.new(self.bitVectorMapNFruitFilterMask, 0, 1)
		tempFruitFilter = self.densityMapModifiersCropSensor.tempFruitFilter

		tempFruitFilter:setValueCompareParams(DensityValueCompareType.EQUAL, 1)

		self.densityMapModifiersCropSensor.fruitFilter = DensityMapFilter.new(self.bitVectorMapNFruitFilterMask, 0, 1)
		fruitFilter = self.densityMapModifiersCropSensor.fruitFilter

		fruitFilter:setValueCompareParams(DensityValueCompareType.EQUAL, 1)
	end

	if localSpace ~= true then
		startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ = worldCoordsToLocalCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, self.sizeX, g_currentMission.terrainSize)
	end

	modifierMeasured:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)
	nModifier:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)
	tempFruitModifier:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)

	if changeFilter == nil then
		if ignoreFruitFilter ~= true then
			tempFruitModifier:executeSet(0)

			for i = 1, #self.cropSensorFruitTypes do
				local fruitType = self.cropSensorFruitTypes[i]

				if fruitType.terrainDataPlaneId ~= nil then
					fruitFilter:resetDensityMapAndChannels(fruitType.terrainDataPlaneId, fruitType.startStateChannel, fruitType.numStateChannels)
					fruitFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 1, fruitType.minHarvestingGrowthState)
					tempFruitModifier:executeSet(1, fruitFilter)
				end
			end
		else
			tempFruitModifier:executeSet(1)
		end

		measuredFilter:setValueCompareParams(DensityValueCompareType.EQUAL, 1)
		tempFruitModifier:executeSet(0, measuredFilter)

		changeFilter = tempFruitFilter
	else
		tempFruitModifier:executeSet(0)
		tempFruitModifier:executeSet(1, changeFilter, changeFilter2)
		measuredFilter:setValueCompareParams(DensityValueCompareType.EQUAL, 1)
		tempFruitModifier:executeSet(0, measuredFilter)

		changeFilter = tempFruitFilter
	end

	for i = 1, #self.nOffsetIndexToOffset do
		local nOffset = self.nOffsetIndexToOffset[i]

		offsetFilter:setValueCompareParams(DensityValueCompareType.EQUAL, i - 1)
		nFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, math.max(1 - nOffset, 1), self.maxValue - nOffset)

		local _, changedArea, _ = nModifier:executeAdd(nOffset, nFilter, offsetFilter, changeFilter)

		if changedArea > 0 then
			self:setMinimapRequiresUpdate(true)
		end
	end

	measuredFilter:setValueCompareParams(DensityValueCompareType.EQUAL, 0)
	modifierMeasured:executeSet(1, measuredFilter, changeFilter)
end

function NitrogenMap:getLevelAtWorldPos(x, z)
	x = (x + g_currentMission.terrainSize * 0.5) / g_currentMission.terrainSize * self.sizeX
	z = (z + g_currentMission.terrainSize * 0.5) / g_currentMission.terrainSize * self.sizeY

	if self.coverMap:getIsUncoveredAtBitVectorPos(x, z) then
		return getBitVectorMapPoint(self.bitVectorMap, x, z, self.firstChannel, self.numChannels)
	end

	return 0
end

function NitrogenMap:getTargetLevelAtWorldPos(x, z, size, forcedFruitType, fillType, nLevel, defaultNitrogenRequirementIndex)
	local soilMap = self.soilMap

	if soilMap ~= nil and soilMap.bitVectorMap ~= nil then
		size = size or 1
		local modifierFruit = self.densityMapModifiersFruitCheck.modifierFruit

		if modifierFruit == nil then
			local fieldGroundSystem = g_currentMission.fieldGroundSystem
			local sprayTypeMapId, sprayTypeFirstChannel, sprayTypeNumChannels = fieldGroundSystem:getDensityMapData(FieldDensityMap.SPRAY_TYPE)
			self.densityMapModifiersFruitCheck.modifierFruit = DensityMapModifier.new(sprayTypeMapId, sprayTypeFirstChannel, sprayTypeNumChannels)
			modifierFruit = self.densityMapModifiersFruitCheck.modifierFruit
		end

		local lx = (x + g_currentMission.terrainSize * 0.5) / g_currentMission.terrainSize * soilMap.sizeX
		local lz = (z + g_currentMission.terrainSize * 0.5) / g_currentMission.terrainSize * soilMap.sizeY

		if self.coverMap:getIsUncoveredAtBitVectorPos(lx, lz) then
			local soilTypeIndex = getBitVectorMapPoint(soilMap.bitVectorMap, lx, lz, soilMap.typeFirstChannel, soilMap.typeNumChannels) + 1

			if fillType ~= nil and fillType ~= FillType.UNKNOWN then
				for i = 1, #self.applicationRates do
					local applicationRate = self.applicationRates[i]

					if applicationRate.fillTypeIndex == fillType and not applicationRate.autoAdjustToFruit then
						for j = 1, #applicationRate.ratesBySoilType do
							local rateBySoilType = applicationRate.ratesBySoilType[j]

							if rateBySoilType.soilTypeIndex == soilTypeIndex then
								return (nLevel or 0) + rateBySoilType.rate, soilTypeIndex, FruitType.UNKNOWN
							end
						end
					end
				end
			end

			local halfSize = size * 0.5
			local startWorldX = x + halfSize
			local startWorldZ = z + halfSize
			local widthWorldX = x - halfSize
			local widthWorldZ = z + halfSize
			local heightWorldX = x + halfSize
			local heightWorldZ = z - halfSize

			modifierFruit:setParallelogramWorldCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)

			local foundFruitTypeIndex = forcedFruitType

			if foundFruitTypeIndex == nil then
				for index, desc in pairs(g_fruitTypeManager:getFruitTypes()) do
					if desc.weed == nil and desc.terrainDataPlaneId ~= nil then
						modifierFruit:resetDensityMapAndChannels(desc.terrainDataPlaneId, desc.startStateChannel, desc.numStateChannels)

						local acc, numPixels, _ = modifierFruit:executeGet()

						if numPixels > 0 then
							local state = math.floor(acc / numPixels)
							local allowCutState = false

							for i = 1, #self.fruitRequirements do
								if self.fruitRequirements[i].fruitType.index == index then
									allowCutState = self.fruitRequirements[i].alwaysAllowFertilization
								end
							end

							if state >= 0 and state ~= desc.cutState or allowCutState then
								foundFruitTypeIndex = index

								break
							end
						end
					end
				end
			end

			local fruitRequirement = nil

			if foundFruitTypeIndex ~= nil then
				for i = 1, #self.fruitRequirements do
					if self.fruitRequirements[i].fruitType.index == foundFruitTypeIndex then
						fruitRequirement = self.fruitRequirements[i]

						break
					end
				end
			else
				fruitRequirement = self.fruitRequirements[defaultNitrogenRequirementIndex or 1] or self.fruitRequirements[1]
			end

			if fruitRequirement ~= nil then
				for j = 1, #fruitRequirement.bySoilType do
					local soilSettings = fruitRequirement.bySoilType[j]

					if soilSettings.soilTypeIndex == soilTypeIndex then
						return soilSettings.targetLevel, soilTypeIndex, foundFruitTypeIndex
					end
				end
			end

			return 0, soilTypeIndex, FruitType.UNKNOWN
		end
	end

	return 0, 0, FruitType.UNKNOWN
end

function NitrogenMap:getNOffsetDataAtWorldPos(x, z)
	x = (x + g_currentMission.terrainSize * 0.5) / g_currentMission.terrainSize * self.sizeX
	z = (z + g_currentMission.terrainSize * 0.5) / g_currentMission.terrainSize * self.sizeY

	if self.coverMap:getIsUncoveredAtBitVectorPos(x, z) then
		local isLocked = getBitVectorMapPoint(self.bitVectorMapNOffset, x, z, 3, 1) == 1
		local offsetValue = getBitVectorMapPoint(self.bitVectorMapNOffset, x, z, 0, 3)
		local nOffsetValue = self.nOffsetIndexToOffset[offsetValue + 1] * self.amountPerState

		return isLocked, nOffsetValue
	end

	return false, -1
end

function NitrogenMap:getFertilizerUsage(workingWidth, lastSpeed, statesChanged, fillTypeIndex, dt, sprayAmountAutoMode, nApplyAutoModeFruitType, actualNitrogen, nitrogenUsageLevelOffset)
	local requiredLitersPerHa, _, nitrogenProportion = self:getFertilizerUsageByStateChange(statesChanged, fillTypeIndex, nitrogenUsageLevelOffset or 0)
	local litersPerUpdate = requiredLitersPerHa * lastSpeed / 3600 / (10000 / workingWidth) * dt
	local regularUsage = 0

	if requiredLitersPerHa > 0 then
		if nApplyAutoModeFruitType ~= nil and nApplyAutoModeFruitType ~= FruitType.UNKNOWN then
			for i = 1, #self.fruitRequirements do
				local fruitRequirement = self.fruitRequirements[i]

				if fruitRequirement.fruitType.index == nApplyAutoModeFruitType then
					local _, internalActualNitrogen = self:getNearestNitrogenValueFromValue(actualNitrogen)
					local requiredLitersPerHaReg, _, _ = self:getFertilizerUsageByStateChange(math.max(fruitRequirement.averageTargetLevel - internalActualNitrogen, 0), fillTypeIndex)
					regularUsage = requiredLitersPerHaReg * lastSpeed / 3600 / (10000 / workingWidth) * dt
				end
			end
		else
			for i = 1, #self.applicationRates do
				local applicationRate = self.applicationRates[i]

				if applicationRate.fillTypeIndex == fillTypeIndex then
					local requiredLitersPerHaReg, _, _ = self:getFertilizerUsageByNitrogenAmount(applicationRate.regularRate, fillTypeIndex)
					regularUsage = requiredLitersPerHaReg * lastSpeed / 3600 / (10000 / workingWidth) * dt
				end
			end
		end
	end

	return litersPerUpdate, requiredLitersPerHa, regularUsage, nitrogenProportion
end

function NitrogenMap:getFertilizerUsageByStateChange(statesChanged, fillTypeIndex, nitrogenUsageLevelOffset)
	local requiredNAmount = statesChanged * self.amountPerState
	local nAmountOffset = (nitrogenUsageLevelOffset or 0) * self.amountPerState

	return self:getFertilizerUsageByNitrogenAmount(requiredNAmount, fillTypeIndex, nAmountOffset)
end

function NitrogenMap:getFertilizerUsageByNitrogenAmount(nitrogenAmount, fillTypeIndex, nAmountOffset)
	local requiredLitersPerHa = 0
	local requiredMassPerHa = 0
	local nitrogenProportion = 0

	for i = 1, #self.fertilizerUsage.nAmounts do
		local nAmount = self.fertilizerUsage.nAmounts[i]

		if nAmount.fillTypeIndex == fillTypeIndex then
			local fillTypeDesc = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
			local massPerLiter = fillTypeDesc.massPerLiter / FillTypeManager.MASS_SCALE

			if fillTypeIndex ~= FillType.LIQUIDMANURE then
				if fillTypeDesc ~= nil then
					requiredLitersPerHa = nitrogenAmount / (massPerLiter * 1000) / nAmount.amount
					requiredMassPerHa = requiredLitersPerHa * massPerLiter
					nitrogenProportion = nAmount.amount
				end
			else
				local nOffsetPct = 1

				if nitrogenAmount > 0 and nAmountOffset ~= nil then
					local realNAmount = nitrogenAmount + nAmountOffset
					nOffsetPct = realNAmount / nitrogenAmount
				end

				requiredLitersPerHa = nitrogenAmount / (nAmount.amount * nOffsetPct)
				requiredMassPerHa = requiredLitersPerHa * massPerLiter
				nitrogenProportion = nAmount.amount * nOffsetPct
			end
		end
	end

	return requiredLitersPerHa, requiredMassPerHa, nitrogenProportion
end

function NitrogenMap:getNextFruitRequirementIndex(index)
	index = index + 1

	if index > #self.fruitRequirements then
		index = 1
	end

	if self.fruitRequirements[index] ~= nil and not self.fruitRequirements[index].availableAsDefaultRate then
		return self:getNextFruitRequirementIndex(index)
	end

	return index
end

function NitrogenMap:getFruitTypeIndexByFruitRequirementIndex(index)
	if self.fruitRequirements[index] ~= nil then
		return self.fruitRequirements[index].fruitType.index
	end

	return nil
end

function NitrogenMap:getFruitTypeRequirementRequiresDefaultMode(index)
	for i = 1, #self.fruitRequirements do
		local fruitRequirement = self.fruitRequirements[i]

		if fruitRequirement.fruitType.index == index and fruitRequirement.requiresDefaultMode then
			return true
		end
	end

	return false
end

function NitrogenMap:getNitrogenAmountFromFillType(fillTypeIndex)
	for i = 1, #self.fertilizerUsage.nAmounts do
		local nAmount = self.fertilizerUsage.nAmounts[i]

		if nAmount.fillTypeIndex == fillTypeIndex then
			return nAmount.amount
		end
	end

	return 0
end

function NitrogenMap:getNitrogenFromChangedStates(statesChanged)
	return statesChanged * self.amountPerState
end

function NitrogenMap:getMinMaxValue()
	if self.nitrogenValues ~= nil and #self.nitrogenValues > 0 then
		return self.nitrogenValues[1].realValue, self.nitrogenValues[#self.nitrogenValues].realValue, #self.nitrogenValues
	end

	return 0, 1, 0
end

function NitrogenMap:getNitrogenValueFromInternalValue(internal)
	for i = 1, #self.nitrogenValues do
		local nitrogenValue = self.nitrogenValues[i]

		if nitrogenValue.value == math.floor(internal) then
			return nitrogenValue.realValue
		end
	end

	return 0
end

function NitrogenMap:getNearestNitrogenValueFromValue(value)
	local minDifference = 1000
	local minValue = 0
	local minInternal = 0

	for i = 1, #self.nitrogenValues do
		local pHValue = self.nitrogenValues[i].realValue
		local difference = math.abs(value - pHValue)

		if difference < minDifference then
			minDifference = difference
			minValue = pHValue
			minInternal = self.nitrogenValues[i].value
		end
	end

	return minValue, minInternal
end

function NitrogenMap:updateLastNitrogenValues()
	local actual = self.lastActualValue
	local target = self.lastTargetValue
	local yieldPotential = self.lastYieldPotential
	local ignoreOverfertilization = self.lastIgnoreOverfertilization
	local regularNLevel = self.lastRegularNValue
	self.lastActualValue = -1
	self.lastTargetValue = -1
	self.lastYieldPotential = -1
	self.lastIgnoreOverfertilization = nil
	self.lastRegularNValue = -1

	return actual, target, yieldPotential, regularNLevel, ignoreOverfertilization
end

function NitrogenMap:getYieldFactorByLevelDifference(difference, ignoreOverfertilization)
	if difference > 0 and ignoreOverfertilization == true then
		difference = 0
	end

	return self.yieldCurve:get(difference)
end

function NitrogenMap:buildOverlay(overlay, filter, isColorBlindMode, isMinimap)
	resetDensityMapVisualizationOverlay(overlay)
	setOverlayColor(overlay, 1, 1, 1, 1)

	if not isMinimap or not self.minimapMissionState then
		local coverMap = self.coverMap

		if coverMap ~= nil then
			local coverMask = bitShiftLeft(2^(coverMap.numChannels - 1) - 1, 1)

			for i = 1, #self.nitrogenValues do
				local nitrogenValue = self.nitrogenValues[i]

				if filter[nitrogenValue.filterIndex] then
					local color = nitrogenValue.color

					if isColorBlindMode then
						color = nitrogenValue.colorBlind
					end

					if color ~= nil then
						setDensityMapVisualizationOverlayStateColor(overlay, self.bitVectorMap, coverMap.bitVectorMap, coverMask, self.firstChannel, self.numChannels, nitrogenValue.value, color[1], color[2], color[3])
					end
				end
			end
		end
	else
		local inGameMenuMapFrame = self.pfModule.inGameMenuMapFrameExtension.inGameMenuMapFrame

		if inGameMenuMapFrame ~= nil then
			local sprayMapId, sprayLevelFirstChannel, sprayLevelNumChannels = g_currentMission.fieldGroundSystem:getDensityMapData(FieldDensityMap.SPRAY_LEVEL)
			local mapOverlayGenerator = inGameMenuMapFrame.mapOverlayGenerator

			if mapOverlayGenerator ~= nil then
				local colors = mapOverlayGenerator.displaySoilStates[MapOverlayGenerator.SOIL_STATE_INDEX.FERTILIZED].colors[isColorBlindMode]
				local maxSprayLevel = bitShiftLeft(1, sprayLevelNumChannels) - 1

				for level = 1, maxSprayLevel do
					local color = colors[math.min(level, #colors)]

					setDensityMapVisualizationOverlayStateColor(overlay, sprayMapId, 0, 0, sprayLevelFirstChannel, sprayLevelNumChannels, level, color[1], color[2], color[3])
				end
			end
		end
	end

	if NitrogenMap.DEBUG_N_OFFSET_MAP then
		resetDensityMapVisualizationOverlay(overlay)
		setOverlayColor(overlay, 1, 1, 1, 1)
		setDensityMapVisualizationOverlayStateColor(overlay, self.bitVectorMapNOffset, 0, 0, 0, 3, 0, 1, 0, 0)
		setDensityMapVisualizationOverlayStateColor(overlay, self.bitVectorMapNOffset, 0, 0, 0, 3, 1, 0.8, 0.2, 0)
		setDensityMapVisualizationOverlayStateColor(overlay, self.bitVectorMapNOffset, 0, 0, 0, 3, 2, 0.6, 0.4, 0)
		setDensityMapVisualizationOverlayStateColor(overlay, self.bitVectorMapNOffset, 0, 0, 0, 3, 3, 0.4, 0.6, 0)
		setDensityMapVisualizationOverlayStateColor(overlay, self.bitVectorMapNOffset, 0, 0, 0, 3, 4, 0.2, 0.8, 0)
		setDensityMapVisualizationOverlayStateColor(overlay, self.bitVectorMapNOffset, 0, 0, 0, 3, 5, 0, 1, 0)
		setDensityMapVisualizationOverlayStateColor(overlay, self.bitVectorMapNOffset, 0, 0, 0, 3, 6, 0, 0.5, 0.5)
		setDensityMapVisualizationOverlayStateColor(overlay, self.bitVectorMapNOffset, 0, 0, 0, 3, 7, 0, 0, 1)
	end
end

function NitrogenMap:getDisplayValues()
	if self.valuesToDisplay == nil then
		self.valuesToDisplay = {}

		for i = 1, #self.nitrogenValues do
			local nitrogenValue = self.nitrogenValues[i]

			if nitrogenValue.showOnHud then
				local nValueToDisplay = {
					colors = {}
				}
				nValueToDisplay.colors[true] = {
					nitrogenValue.colorBlind
				}
				nValueToDisplay.colors[false] = {
					nitrogenValue.color
				}
				nValueToDisplay.description = string.format("%d kg/ha", nitrogenValue.realValue)

				table.insert(self.valuesToDisplay, nValueToDisplay)
			end
		end

		local nValueToDisplay = {
			colors = {}
		}
		nValueToDisplay.colors[true] = {
			{
				0,
				0,
				0
			}
		}
		nValueToDisplay.colors[false] = {
			{
				0,
				0,
				0
			}
		}
		nValueToDisplay.description = self.outdatedLabel

		table.insert(self.valuesToDisplay, nValueToDisplay)
	end

	return self.valuesToDisplay
end

function NitrogenMap:getValueFilter()
	if self.valueFilter == nil or self.valueFilterEnabled == nil then
		self.valueFilter = {}
		self.valueFilterEnabled = {}

		for i = 1, self.numVisualValues + 1 do
			table.insert(self.valueFilter, true)
			table.insert(self.valueFilterEnabled, i <= self.numVisualValues)
		end
	end

	return self.valueFilter, self.valueFilterEnabled
end

function NitrogenMap:getMinimapZoomFactor()
	return 3
end

function NitrogenMap:collectFieldInfos(fieldInfoDisplayExtension)
	local name = g_i18n:getText("fieldInfo_nValue", NitrogenMap.MOD_NAME)

	fieldInfoDisplayExtension:addFieldInfo(name, self, self.updateFieldInfoDisplay, 3, self.getFieldInfoYieldChange)
end

function NitrogenMap:getAllowCoverage()
	return true
end

function NitrogenMap:getHelpLinePage()
	return 5
end

function NitrogenMap:getRequiresAdditionalActionButton(farmlandId)
	if self.soilMap ~= nil then
		return self.soilMap:getRequiresAdditionalActionButton(farmlandId)
	end

	return false
end

function NitrogenMap:getAdditionalActionButtonText()
	if self.soilMap ~= nil then
		return self.soilMap:getAdditionalActionButtonText()
	end
end

function NitrogenMap:onAdditionalActionButtonPressed(farmlandId)
	if self.soilMap ~= nil then
		return self.soilMap:onAdditionalActionButtonPressed(farmlandId)
	end
end

function NitrogenMap:updateFieldInfoDisplay(fieldInfo, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, isColorBlindMode)
	fieldInfo.nFactor = 0
	fieldInfo.yieldPotential = 1
	fieldInfo.yieldPotentialToHa = 0
	local coverMap = self.coverMap
	local soilMap = self.soilMap

	if coverMap ~= nil and coverMap.bitVectorMap ~= nil and soilMap ~= nil and soilMap.bitVectorMap ~= nil then
		local modifier = self.densityMapModifiersFieldInfo.modifier
		local soilFilter = self.densityMapModifiersFieldInfo.soilFilter
		local coverFilter = self.densityMapModifiersFieldInfo.coverFilter
		local fruitFilter = self.densityMapModifiersFieldInfo.fruitFilter
		local tempFruitModifier = self.densityMapModifiersFieldInfo.tempFruitModifier
		local tempFruitFilter = self.densityMapModifiersFieldInfo.tempFruitFilter

		if modifier == nil or soilFilter == nil or coverFilter == nil or fruitFilter == nil or tempFruitModifier == nil or tempFruitFilter == nil then
			self.densityMapModifiersFieldInfo.modifier = DensityMapModifier.new(self.bitVectorMap, self.firstChannel, self.numChannels)
			modifier = self.densityMapModifiersFieldInfo.modifier
			self.densityMapModifiersFieldInfo.soilFilter = DensityMapFilter.new(soilMap.bitVectorMap, soilMap.typeFirstChannel, soilMap.typeNumChannels)
			soilFilter = self.densityMapModifiersFieldInfo.soilFilter
			self.densityMapModifiersFieldInfo.coverFilter = DensityMapFilter.new(coverMap.bitVectorMap, coverMap.firstChannel, coverMap.numChannels)
			coverFilter = self.densityMapModifiersFieldInfo.coverFilter

			coverFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 1, coverMap.maxValue)

			self.densityMapModifiersFieldInfo.fruitFilter = DensityMapFilter.new(modifier)
			fruitFilter = self.densityMapModifiersFieldInfo.fruitFilter
			self.densityMapModifiersFieldInfo.tempFruitModifier = DensityMapModifier.new(self.bitVectorMapNFruitFilterMask, 0, 1)
			tempFruitModifier = self.densityMapModifiersFieldInfo.tempFruitModifier

			tempFruitModifier:setPolygonRoundingMode(DensityRoundingMode.INCLUSIVE)

			self.densityMapModifiersFieldInfo.tempFruitFilter = DensityMapFilter.new(self.bitVectorMapNFruitFilterMask, 0, 1)
			tempFruitFilter = self.densityMapModifiersFieldInfo.tempFruitFilter

			tempFruitFilter:setValueCompareParams(DensityValueCompareType.EQUAL, 1)
		end

		startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ = worldCoordsToLocalCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, self.sizeX, g_currentMission.terrainSize)

		modifier:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)
		tempFruitModifier:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)

		for i = 1, #self.fruitRequirements do
			local fruitRequirement = self.fruitRequirements[i]
			local fruitDesc = fruitRequirement.fruitType

			if fruitDesc ~= nil and fruitDesc.terrainDataPlaneId ~= nil and fruitDesc.terrainDataPlaneId ~= 0 then
				tempFruitModifier:executeSet(0)
				fruitFilter:resetDensityMapAndChannels(fruitDesc.terrainDataPlaneId, fruitDesc.startStateChannel, fruitDesc.numStateChannels)

				if fruitRequirement.alwaysAllowFertilization then
					fruitFilter:setValueCompareParams(DensityValueCompareType.GREATER, 0)
				else
					fruitFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 1, fruitDesc.maxHarvestingGrowthState)
				end

				tempFruitModifier:executeSet(1, fruitFilter, coverFilter)

				for j = 1, #fruitRequirement.bySoilType do
					local soilSettings = fruitRequirement.bySoilType[j]

					soilFilter:setValueCompareParams(DensityValueCompareType.EQUAL, soilSettings.soilTypeIndex - 1)

					local acc, numPixels, totalPixels = modifier:executeGet(tempFruitFilter, soilFilter)

					if numPixels > totalPixels * 0.3 then
						local nLevel = math.floor(acc / numPixels)
						local actualLevelReal = self:getNitrogenValueFromInternalValue(nLevel)
						local targetLevelReal = self:getNitrogenValueFromInternalValue(soilSettings.targetLevel)
						local color, additionalText = nil
						local levelDifference = soilSettings.targetLevel - nLevel

						if fruitRequirement.ignoreOverfertilization then
							levelDifference = math.max(levelDifference, 0)
						end

						if targetLevelReal == 0 then
							levelDifference = 0
						end

						levelDifference = math.abs(levelDifference)

						for li = 1, #self.levelDifferenceColors do
							local levelDifferenceColor = self.levelDifferenceColors[li]

							if levelDifferenceColor.levelDifference <= levelDifference then
								if isColorBlindMode then
									color = levelDifferenceColor.colorBlind
								else
									color = levelDifferenceColor.color
								end

								additionalText = levelDifferenceColor.additionalText
							end
						end

						fieldInfo.yieldPotential = soilSettings.yieldPotential
						fieldInfo.nFactor = self:getYieldFactorByLevelDifference(nLevel - soilSettings.targetLevel, fruitRequirement.ignoreOverfertilization)
						local fillType = g_fruitTypeManager:getFillTypeByFruitTypeIndex(fruitDesc.index)

						if fillType ~= nil then
							fieldInfo.yieldPotentialToHa = soilSettings.yieldPotential * fruitDesc.literPerSqm * 10000 * fillType.massPerLiter / FillTypeManager.MASS_SCALE * 2
						end

						return string.format("%d / %d kg/ha", actualLevelReal, targetLevelReal), color, additionalText
					end
				end
			end
		end

		local acc, numPixels, _ = modifier:executeGet(coverFilter)

		if numPixels > 0 then
			local nLevel = math.floor(acc / numPixels)

			return string.format("%d kg/ha", self:getNitrogenValueFromInternalValue(nLevel))
		end
	end

	return nil
end

function NitrogenMap:getFieldInfoYieldChange(fieldInfo)
	return fieldInfo.nFactor or 0, 0.5, fieldInfo.yieldPotential or 1, fieldInfo.yieldPotentialToHa or 0
end

function NitrogenMap:drawYieldDebug(nActualValue, nTargetValue)
	if self.debugGraph == nil then
		self.debugGraph = Graph.new(#self.yieldCurve.keyframes, 0.2, 0.05, 0.2, 0.15, 0, 100, false, "%", Graph.STYLE_LINES)

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
		local x = self.debugGraph.left + MathUtil.inverseLerp(minTime, maxTime, nActualValue - nTargetValue) * self.debugGraph.width

		setOverlayColor(self.debugGraph.overlayHLine, 1, 0, 0, 1)
		renderOverlay(self.debugGraph.overlayHLine, x, self.debugGraph.bottom, 1 / g_screenWidth, self.debugGraph.height)
		setOverlayColor(self.debugGraph.overlayHLine, 1, 1, 1, 1)
	end
end

function NitrogenMap:overwriteGameFunctions(pfModule)
	NitrogenMap:superClass().overwriteGameFunctions(self, pfModule)
	pfModule:overwriteGameFunction(FertilizingSowingMachine, "processSowingMachineArea", function (superFunc, vehicle, superFunc2, workArea, dt)
		local spec = vehicle.spec_fertilizingSowingMachine
		local specSowingMachine = vehicle.spec_sowingMachine
		local specSpray = vehicle.spec_sprayer
		local sprayerParams = specSpray.workAreaParameters
		local sowingParams = specSowingMachine.workAreaParameters

		if not sowingParams.isActive then
			return superFunc(vehicle, superFunc2, workArea, dt)
		end

		if not sowingParams.canFruitBePlanted then
			return superFunc(vehicle, superFunc2, workArea, dt)
		end

		if sprayerParams.sprayFillLevel <= 0 or spec.needsSetIsTurnedOn and not vehicle:getIsTurnedOn() then
			return superFunc(vehicle, superFunc2, workArea, dt)
		end

		if vehicle.preProcessExtUnderRootFertilizerArea ~= nil then
			vehicle:preProcessExtUnderRootFertilizerArea(workArea, dt)
		end

		local changedArea, totalArea = superFunc(vehicle, superFunc2, workArea, dt)

		if vehicle.postProcessExtUnderRootFertilizerArea ~= nil then
			vehicle:postProcessExtUnderRootFertilizerArea(workArea, dt, changedArea, totalArea)
		end

		return changedArea, totalArea
	end)
	pfModule:overwriteGameFunction(FertilizingCultivator, "processCultivatorArea", function (superFunc, vehicle, superFunc2, workArea, dt)
		local spec = vehicle.spec_fertilizingCultivator
		local specSpray = vehicle.spec_sprayer
		local sprayerParams = specSpray.workAreaParameters

		if sprayerParams.sprayFillLevel <= 0 or spec.needsSetIsTurnedOn and not vehicle:getIsTurnedOn() then
			return superFunc(vehicle, superFunc2, workArea, dt)
		end

		if vehicle.preProcessExtUnderRootFertilizerArea ~= nil then
			vehicle:preProcessExtUnderRootFertilizerArea(workArea, dt)
		end

		local changedArea, totalArea = superFunc(vehicle, superFunc2, workArea, dt)

		if vehicle.postProcessExtUnderRootFertilizerArea ~= nil then
			vehicle:postProcessExtUnderRootFertilizerArea(workArea, dt, changedArea, totalArea)
		end

		return changedArea, totalArea
	end)
	pfModule:overwriteGameFunction(Combine, "processCombineChopperArea", function (superFunc, vehicle, workArea)
		local spec = vehicle.spec_combine

		if not spec.isSwathActive then
			local litersToDrop = spec.workAreaParameters.litersToDrop
			local strawRatio = spec.workAreaParameters.strawRatio
			local strawGroundType = spec.workAreaParameters.strawGroundType

			if litersToDrop > 0 and strawRatio > 0 and strawRatio > 0.5 and strawGroundType ~= nil then
				local xs, _, zs = getWorldTranslation(workArea.start)
				local xw, _, zw = getWorldTranslation(workArea.width)
				local xh, _, zh = getWorldTranslation(workArea.height)

				self:preUpdateStrawChopperArea(xs, zs, xw, zw, xh, zh, strawGroundType)

				local lastRealArea, lastArea = superFunc(vehicle, workArea)

				self:postUpdateStrawChopperArea(xs, zs, xw, zw, xh, zh, strawGroundType)

				return lastRealArea, lastArea
			end
		end

		return superFunc(vehicle, workArea)
	end)
end
