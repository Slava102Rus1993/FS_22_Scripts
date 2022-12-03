SoilMap = {
	MOD_NAME = g_currentModName,
	MOD_DIR = g_currentModDirectory,
	GUI_ELEMENTS = g_currentModDirectory .. "gui/ui_elements.png",
	SAMPLING_RADIUS = 35,
	SAMPLING_PROVIDER_MULTIPLIER = 1.75
}

source(g_currentModDirectory .. "scripts/gui/SoilSampleYesNoDialog.lua")

local SoilMap_mt = Class(SoilMap, ValueMap)

function SoilMap.new(pfModule, customMt)
	local self = ValueMap.new(pfModule, customMt or SoilMap_mt)
	self.filename = "precisionFarming_soilMap.grle"
	self.name = "soilMap"
	self.id = "SOIL_MAP"
	self.label = "ui_mapOverviewSoilType"
	self.pendingSoilSamplesPerFarm = {}
	self.moneyChangeType = MoneyType.register("other", "info_samplesAnalysed", SoilMap.MOD_NAME)
	self.densityMapModifiersUncover = {}
	self.densityMapModifiersSellFarmland = {}
	self.densityMapModifiersFieldInfo = {}
	self.mapFrame = nil
	local width, height = getNormalizedScreenValues(85, 85)
	local samplingCircleOverlay = Overlay.new(SoilMap.GUI_ELEMENTS, 0, 0, width, height)

	samplingCircleOverlay:setUVs(GuiUtils.getUVs({
		3,
		67,
		122,
		122
	}))
	samplingCircleOverlay:setColor(0.1, 0.5, 0.1, 0.5)

	self.samplingCircleElement = HUDElement.new(samplingCircleOverlay)
	self.minimapSamplingState = false
	self.minimapUpdateTimer = 0
	self.minimapLabelName = g_i18n:getText("ui_mapOverviewSoilType", SoilMap.MOD_NAME)

	return self
end

function SoilMap:initialize()
	SoilMap:superClass().initialize(self)

	self.pendingSoilSamplesPerFarm = {}
	self.densityMapModifiersUncover = {}
	self.densityMapModifiersSellFarmland = {}
	self.densityMapModifiersFieldInfo = {}
	self.loadFilename = nil
	self.coverMap = self.pfModule.coverMap
	local soilSampleYesNoDialog = SoilSampleYesNoDialog.new()

	g_gui:loadGui(SoilMap.MOD_DIR .. "gui/SoilSampleYesNoDialog.xml", "SoilSampleYesNoDialog", soilSampleYesNoDialog)
end

function SoilMap:loadFromXML(xmlFile, key, baseDirectory, configFileName, mapFilename)
	key = key .. ".soilMap"
	local missionInfo = g_currentMission.missionInfo
	local savegameFilename = nil

	if missionInfo.savegameDirectory ~= nil then
		savegameFilename = missionInfo.savegameDirectory .. "/" .. self.filename
	end

	if savegameFilename ~= nil and fileExists(savegameFilename) then
		self.loadFilename = savegameFilename
	else
		local mapXMLFilename = Utils.getFilename(missionInfo.mapXMLFilename, g_currentMission.baseDirectory)
		self.mapXMLFile = loadXMLFile("MapXML", mapXMLFilename)

		if self.mapXMLFile ~= nil then
			local customSoilMap = getXMLString(self.mapXMLFile, "map.precisionFarming.soilMap#filename")

			if customSoilMap ~= nil then
				customSoilMap = Utils.getFilename(customSoilMap, g_currentMission.baseDirectory)

				if fileExists(customSoilMap) then
					self.loadFilename = customSoilMap
				end
			end

			delete(self.mapXMLFile)
		end

		local i = 0

		while true do
			local mapKey = string.format("%s.predefinedMaps.predefinedMap(%d)", key, i)

			if not hasXMLProperty(xmlFile, mapKey) then
				break
			end

			local filename = getXMLString(xmlFile, mapKey .. "#filename")

			if filename ~= nil then
				filename = Utils.getFilename(filename, baseDirectory)

				if fileExists(filename) then
					local isDefault = getXMLBool(xmlFile, mapKey .. "#isDefault")

					if isDefault ~= nil and isDefault and self.loadFilename == nil then
						self.loadFilename = filename
					end

					local mapIdentifier = getXMLString(xmlFile, mapKey .. "#mapIdentifier")

					if mapIdentifier ~= nil and mapFilename:find(mapIdentifier) ~= nil and self.loadFilename == nil then
						self.loadFilename = filename
					end
				else
					Logging.xmlWarning(configFileName, "Soil map '%s' could not be found", key)
				end
			else
				Logging.xmlWarning(configFileName, "Unknown filename in '%s'", key)
			end

			i = i + 1
		end
	end

	self.numChannels = getXMLInt(xmlFile, key .. ".bitVectorMap#numChannels") or 3
	self.bitVectorMap = createBitVectorMap("SoilMap")

	if self.loadFilename ~= nil then
		if not loadBitVectorMapFromFile(self.bitVectorMap, self.loadFilename, self.numChannels) then
			Logging.xmlWarning(configFileName, "Error while loading soil map '%s'", self.loadFilename)

			self.loadFilename = nil
		else
			local size, _ = getBitVectorMapSize(self.bitVectorMap)

			if size ~= 1024 then
				self.loadFilename = nil

				Logging.xmlWarning(configFileName, "Found soil map with wrong size '%s'. Soil map needs to be 1024x1024!", self.loadFilename)
			else
				Logging.info("Load soil map '%s'", self.loadFilename)
			end
		end
	end

	if self.loadFilename == nil then
		loadBitVectorMapNew(self.bitVectorMap, 1024, 1024, self.numChannels, false)
	end

	self:addBitVectorMapToSync(self.bitVectorMap)
	self:addBitVectorMapToSave(self.bitVectorMap, self.filename)
	self:addBitVectorMapToDelete(self.bitVectorMap)

	self.sizeX, self.sizeY = getBitVectorMapSize(self.bitVectorMap)
	self.typeFirstChannel = getXMLInt(xmlFile, key .. ".bitVectorMap#typeFirstChannel") or 0
	self.typeNumChannels = getXMLInt(xmlFile, key .. ".bitVectorMap#typeNumChannels") or 2
	self.coverChannel = getXMLInt(xmlFile, key .. ".bitVectorMap#coverChannel") or 2
	self.sampledColor = string.getVectorN(getXMLString(xmlFile, key .. ".sampling#sampledColor") or "0 0 0", 3)
	self.sampledColorBlind = string.getVectorN(getXMLString(xmlFile, key .. ".sampling#sampledColorBlind") or "0 0 0", 3)
	self.sampledText = g_i18n:convertText(getXMLString(xmlFile, key .. ".sampling#name"), SoilMap.MOD_NAME)
	self.pricePerSample = string.getVectorN(getXMLString(xmlFile, key .. ".sampling#pricePerSample") or "50 100 150", 3)
	self.analyseTimePerSample = (getXMLFloat(xmlFile, key .. ".sampling#analyseTimeSecPerSample") or 5) * 1000
	self.texts = {
		laboratoryIdle = g_i18n:convertText(getXMLString(xmlFile, key .. ".sampling.texts#idleText") or "$l10n_ui_laboratory_idle", SoilMap.MOD_NAME),
		laboratoryAnalyse = g_i18n:convertText(getXMLString(xmlFile, key .. ".sampling.texts#analyseText") or "$l10n_ui_laboratory_analyse", SoilMap.MOD_NAME),
		fieldInfoSoil = g_i18n:getText("fieldInfo_soil", SoilMap.MOD_NAME),
		fieldInfoNoData = g_i18n:getText("fieldInfo_noSoilDataFound", SoilMap.MOD_NAME),
		purchaseSoilMaps = g_i18n:getText("ui_purchaseSoilMaps", SoilMap.MOD_NAME)
	}
	self.soilTypes = {}
	local i = 0

	while true do
		local typeKey = string.format("%s.soilTypes.soilType(%d)", key, i)

		if not hasXMLProperty(xmlFile, typeKey) then
			break
		end

		local soilType = {
			name = g_i18n:convertText(getXMLString(xmlFile, typeKey .. "#name"), SoilMap.MOD_NAME),
			yieldPotential = getXMLFloat(xmlFile, typeKey .. "#yieldPotential") or 1,
			color = string.getVectorN(getXMLString(xmlFile, typeKey .. "#color"), 3) or {
				0,
				0,
				0
			},
			colorBlind = string.getVectorN(getXMLString(xmlFile, typeKey .. "#colorBlind"), 3) or {
				0,
				0,
				0
			}
		}

		table.insert(self.soilTypes, soilType)

		i = i + 1
	end

	self.pHMap = self.pfModule.pHMap
	self.nitrogenMap = self.pfModule.nitrogenMap

	g_farmlandManager:addStateChangeListener(self)

	return true
end

function SoilMap:initTerrain(mission, terrainId, filename)
	SoilMap:superClass().initTerrain(self, mission, terrainId, filename)

	if self.pHMap ~= nil and self.pHMap.newBitVectorMap then
		local startTime = getTimeSec()

		self.pHMap:setInitialState(self.bitVectorMap, self.typeFirstChannel, self.typeNumChannels, self.coverChannel)
		Logging.devInfo("Initialized pH Map in %d ms", (getTimeSec() - startTime) * 1000)
	end

	if self.nitrogenMap ~= nil and self.nitrogenMap.newBitVectorMap then
		local startTime = getTimeSec()

		self.nitrogenMap:setInitialState(self.bitVectorMap, self.typeFirstChannel, self.typeNumChannels, self.coverChannel)
		Logging.devInfo("Initialized nitrogen Map in %d ms", (getTimeSec() - startTime) * 1000)
	end
end

function SoilMap:delete()
	g_farmlandManager:removeStateChangeListener(self)
	self.samplingCircleElement:delete()
	SoilMap:superClass().delete(self)
end

function SoilMap:loadFromItemsXML(xmlFile, key)
	key = key .. ".soilMap"

	xmlFile:iterate(key .. "pendingSoilSamples", function (_, baseKey)
		local farmId = xmlFile:getInt(baseKey .. "#farmId")
		local timer = xmlFile:getFloat(baseKey .. "#timer", self.analyseTimePerSample)
		local toAnalyse = xmlFile:getInt(baseKey .. "#toAnalyse")
		local totalAnalysed = xmlFile:getInt(baseKey .. "#totalAnalysed")

		if farmId ~= nil and toAnalyse ~= nil and totalAnalysed ~= nil then
			self.pendingSoilSamplesPerFarm[farmId] = {
				toAnalyse = toAnalyse,
				totalAnalysed = totalAnalysed,
				timer = timer
			}
		end
	end)
end

function SoilMap:saveToXMLFile(xmlFile, key, usedModNames)
	key = key .. ".soilMap"
	local i = 0

	for farmId, data in pairs(self.pendingSoilSamplesPerFarm) do
		local baseKey = string.format("%s.pendingSoilSamples(%d)", key, i)

		xmlFile:setInt(baseKey .. "#farmId", farmId)
		xmlFile:setFloat(baseKey .. "#timer", data.timer)
		xmlFile:setInt(baseKey .. "#toAnalyse", data.toAnalyse)
		xmlFile:setInt(baseKey .. "#totalAnalysed", data.totalAnalysed)

		i = i + 1
	end
end

function SoilMap:update(dt)
	for farmId, data in pairs(self.pendingSoilSamplesPerFarm) do
		data.timer = data.timer - dt * g_currentMission.missionInfo.timeScale

		if data.timer <= 0 then
			data.toAnalyse = data.toAnalyse - 1

			if data.toAnalyse <= 0 then
				self.coverMap:uncoverAnalysedArea(farmId)

				local price = self:getPricePerSoilSample()
				price = price * data.totalAnalysed

				g_currentMission:addMoney(-price, farmId, self.moneyChangeType, true, true)

				self.pendingSoilSamplesPerFarm[farmId] = nil
			else
				data.timer = self.analyseTimePerSample
			end

			self:updateLaboratoryText()
		end
	end

	if self.minimapSamplingState then
		self.samplingCircleElement:setColor(0.5, 0.5, 0.1, IngameMap.alpha)
	end

	if self.minimapUpdateTimer > 0 then
		self.minimapUpdateTimer = self.minimapUpdateTimer - dt

		if self.minimapUpdateTimer <= 0 then
			self:setMinimapRequiresUpdate(true)
		end
	end
end

function SoilMap:setMapFrame(mapFrame)
	self.mapFrame = mapFrame

	self:updateLaboratoryText()
end

function SoilMap:updateLaboratoryText()
	if self.mapFrame ~= nil then
		local farmId = g_currentMission:getFarmId()

		if self.pendingSoilSamplesPerFarm[farmId] ~= nil then
			self.mapFrame.laboratoryInfoText:setText(string.format(self.texts.laboratoryAnalyse, self.pendingSoilSamplesPerFarm[farmId].totalAnalysed), true)
		else
			self.mapFrame.laboratoryInfoText:setText(self.texts.laboratoryIdle, true)
		end
	end
end

function SoilMap:sendSoilSamplesByFarm(farmId)
	for _, vehicle in pairs(g_currentMission.vehicles) do
		if SpecializationUtil.hasSpecialization(SoilSampler, vehicle.specializations) and vehicle:getOwnerFarmId() == farmId then
			vehicle:sendTakenSoilSamples()
		end
	end
end

function SoilMap:analyseSoilSamples(farmId, numSamples)
	if self.pendingSoilSamplesPerFarm[farmId] == nil then
		self.pendingSoilSamplesPerFarm[farmId] = {
			toAnalyse = numSamples,
			totalAnalysed = numSamples,
			timer = self.analyseTimePerSample
		}
	else
		self.pendingSoilSamplesPerFarm[farmId].toAnalyse = self.pendingSoilSamplesPerFarm[farmId].toAnalyse + numSamples
		self.pendingSoilSamplesPerFarm[farmId].totalAnalysed = self.pendingSoilSamplesPerFarm[farmId].totalAnalysed + numSamples
		self.pendingSoilSamplesPerFarm[farmId].timer = self.analyseTimePerSample
	end

	self:updateLaboratoryText()
end

local function worldCoordsToLocalCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, size, terrainSize)
	return size * (startWorldX + terrainSize * 0.5) / terrainSize, size * (startWorldZ + terrainSize * 0.5) / terrainSize, size * (widthWorldX + terrainSize * 0.5) / terrainSize, size * (widthWorldZ + terrainSize * 0.5) / terrainSize, size * (heightWorldX + terrainSize * 0.5) / terrainSize, size * (heightWorldZ + terrainSize * 0.5) / terrainSize
end

function SoilMap:onAnalyseArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, state, farmId)
	self.minimapUpdateTimer = 250
end

function SoilMap:onUncoverArea(maskFilter, farmIdFilter, farmId)
	local modifier = self.densityMapModifiersUncover.modifier

	if modifier == nil then
		self.densityMapModifiersUncover.modifier = DensityMapModifier.new(self.bitVectorMap, self.coverChannel, 1)
		modifier = self.densityMapModifiersUncover.modifier

		modifier:setParallelogramDensityMapCoords(0, 0, 0, self.sizeY, self.sizeX, 0, DensityCoordType.POINT_POINT_POINT)
	end

	modifier:executeSet(1, maskFilter, farmIdFilter)
	self.pfModule:updatePrecisionFarmingOverlays()
	self:setMinimapRequiresUpdate(true)
end

function SoilMap:onFarmlandStateChanged(farmlandId, farmId)
	if farmId == FarmlandManager.NO_OWNER_FARM_ID then
		local modifier = self.densityMapModifiersSellFarmland.modifier
		local modifierCover = self.densityMapModifiersSellFarmland.modifierCover
		local farmlandMask = self.densityMapModifiersSellFarmland.farmlandMask
		local farmlandManager = g_farmlandManager

		if modifier == nil or modifierCover == nil or farmlandMask == nil then
			self.densityMapModifiersSellFarmland.modifier = DensityMapModifier.new(self.bitVectorMap, self.coverChannel, 1)
			modifier = self.densityMapModifiersSellFarmland.modifier
			self.densityMapModifiersSellFarmland.modifierCover = DensityMapModifier.new(self.coverMap.bitVectorMap, self.coverMap.firstChannel, self.coverMap.numChannels)
			modifierCover = self.densityMapModifiersSellFarmland.modifierCover
			self.densityMapModifiersSellFarmland.farmlandMask = DensityMapFilter.new(farmlandManager.localMap, 0, farmlandManager.numberOfBits)
			farmlandMask = self.densityMapModifiersSellFarmland.farmlandMask
		end

		farmlandMask:setValueCompareParams(DensityValueCompareType.EQUAL, farmlandId)
		modifier:executeSet(0, farmlandMask)
		modifierCover:executeSet(0, farmlandMask)

		if self.pfModule.pHMap ~= nil then
			self.pfModule.pHMap:setInitialState(self.bitVectorMap, self.typeFirstChannel, self.typeNumChannels, self.coverChannel, farmlandMask)
		end

		if self.pfModule.nitrogenMap ~= nil then
			self.pfModule.nitrogenMap:setInitialState(self.bitVectorMap, self.typeFirstChannel, self.typeNumChannels, self.coverChannel, farmlandMask)
		end

		self.pfModule:updatePrecisionFarmingOverlays()
		self:setMinimapRequiresUpdate(true)
	end
end

function SoilMap:getTypeIndexAtWorldPos(x, z)
	x = (x + g_currentMission.terrainSize * 0.5) / g_currentMission.terrainSize * self.sizeX
	z = (z + g_currentMission.terrainSize * 0.5) / g_currentMission.terrainSize * self.sizeY

	if self.coverMap:getIsUncoveredAtBitVectorPos(x, z) then
		return getBitVectorMapPoint(self.bitVectorMap, x, z, self.typeFirstChannel, self.typeNumChannels) + 1
	end

	return 0
end

function SoilMap:buildOverlay(overlay, valueFilter, isColorBlindMode)
	resetDensityMapVisualizationOverlay(overlay)
	setOverlayColor(overlay, 1, 1, 1, 1)

	if self.coverMap ~= nil then
		local sampledColor = self.sampledColor

		if isColorBlindMode then
			sampledColor = self.sampledColorBlind
		end

		setDensityMapVisualizationOverlayStateColor(overlay, self.coverMap.bitVectorMap, 0, 0, self.coverMap.firstChannel, self.coverMap.numChannels, self.coverMap.sampledValue, sampledColor[1], sampledColor[2], sampledColor[3])
	end

	local coverMask = bitShiftLeft(1, self.coverChannel)
	local soilMapId = self.bitVectorMap

	for i = 1, #self.soilTypes do
		if valueFilter[i] then
			local soilType = self.soilTypes[i]
			local color = soilType.color

			if isColorBlindMode then
				color = soilType.colorBlind
			end

			setDensityMapVisualizationOverlayStateColor(overlay, soilMapId, soilMapId, coverMask, self.typeFirstChannel, self.typeNumChannels, i - 1, color[1], color[2], color[3])
		end
	end
end

function SoilMap:getDisplayValues()
	if self.valuesToDisplay == nil then
		self.valuesToDisplay = {}

		for i = 1, #self.soilTypes do
			local soilType = self.soilTypes[i]
			local soilTypeToDisplay = {
				colors = {}
			}
			soilTypeToDisplay.colors[true] = {
				{
					soilType.colorBlind[1],
					soilType.colorBlind[2],
					soilType.colorBlind[3]
				}
			}
			soilTypeToDisplay.colors[false] = {
				{
					soilType.color[1],
					soilType.color[2],
					soilType.color[3]
				}
			}
			soilTypeToDisplay.description = soilType.name

			table.insert(self.valuesToDisplay, soilTypeToDisplay)
		end

		local soilTypeToDisplay = {
			colors = {}
		}
		soilTypeToDisplay.colors[true] = {
			{
				self.sampledColorBlind[1],
				self.sampledColorBlind[2],
				self.sampledColorBlind[3]
			}
		}
		soilTypeToDisplay.colors[false] = {
			{
				self.sampledColor[1],
				self.sampledColor[2],
				self.sampledColor[3]
			}
		}
		soilTypeToDisplay.description = self.sampledText

		table.insert(self.valuesToDisplay, soilTypeToDisplay)
	end

	return self.valuesToDisplay
end

function SoilMap:getSoilTypeByIndex(soilTypeIndex)
	return self.soilTypes[soilTypeIndex]
end

function SoilMap:getYieldPotentialBySoilTypeIndex(soilTypeIndex)
	if self.soilTypes[soilTypeIndex] == nil then
		return 1
	end

	return self.soilTypes[soilTypeIndex].yieldPotential
end

function SoilMap:getValueFilter()
	if self.valueFilter == nil or self.valueFilterEnabled == nil then
		self.valueFilter = {}
		self.valueFilterEnabled = {}
		local numSoilTypes = #self.soilTypes

		for i = 1, numSoilTypes + 1 do
			table.insert(self.valueFilter, true)
			table.insert(self.valueFilterEnabled, i <= numSoilTypes)
		end
	end

	return self.valueFilter, self.valueFilterEnabled
end

function SoilMap:getMinimapValueFilter()
	if self.minimapValueFilter == nil then
		self.minimapValueFilter = {}

		for i = 1, #self.soilTypes + 1 do
			table.insert(self.minimapValueFilter, true)
		end
	end

	return self.minimapValueFilter, self.minimapValueFilter
end

function SoilMap:getMinimapAdditionalElement()
	return self.samplingCircleElement
end

function SoilMap:getMinimapZoomFactor()
	return 3
end

function SoilMap:getMinimapUpdateTimeLimit()
	return 5
end

function SoilMap:setMinimapSamplingState(state)
	self.minimapSamplingState = state

	if not state then
		self.samplingCircleElement:setColor(0.1, 0.5, 0.1, 0.5)
	end
end

function SoilMap:collectFieldInfos(fieldInfoDisplayExtension)
	fieldInfoDisplayExtension:addFieldInfo(self.texts.fieldInfoSoil, self, self.updateFieldInfoDisplay, 1)
end

function SoilMap:updateFieldInfoDisplay(fieldInfo, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
	local modifier = self.densityMapModifiersFieldInfo.modifier
	local maskFilter = self.densityMapModifiersFieldInfo.maskFilter

	if modifier == nil then
		self.densityMapModifiersFieldInfo.modifier = DensityMapModifier.new(self.bitVectorMap, self.typeFirstChannel, self.typeNumChannels)
		modifier = self.densityMapModifiersFieldInfo.modifier
		self.densityMapModifiersFieldInfo.maskFilter = DensityMapFilter.new(self.bitVectorMap, self.coverChannel, 1)
		maskFilter = self.densityMapModifiersFieldInfo.maskFilter

		maskFilter:setValueCompareParams(DensityValueCompareType.EQUAL, 1)
	end

	startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ = worldCoordsToLocalCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, self.sizeX, g_currentMission.terrainSize)

	modifier:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)

	local acc, numPixels, _ = modifier:executeGet(maskFilter)
	local soilTypeIndex = math.floor(acc / numPixels) + 1
	local soilType = self.soilTypes[soilTypeIndex]

	if soilType ~= nil then
		return soilType.name
	end

	return self.texts.fieldInfoNoData
end

function SoilMap:getHelpLinePage()
	return 2
end

function SoilMap:getRequiresAdditionalActionButton(farmlandId)
	return farmlandId ~= nil
end

function SoilMap:getAdditionalActionButtonText()
	return self.texts.purchaseSoilMaps
end

function SoilMap:onAdditionalActionButtonPressed(farmlandId)
	local fieldNumber, fieldArea = self.pfModule:getFarmlandFieldInfo(farmlandId)

	if fieldArea > 0 then
		local dialog = g_gui:showDialog("SoilSampleYesNoDialog")

		if dialog ~= nil then
			local numSamples = math.ceil(self:getNumSoilSamplesPerHa() * fieldArea)
			local price = self.pricePerSample[g_currentMission.missionInfo.economicDifficulty] or 0

			dialog.target:setData(fieldNumber, fieldArea, numSamples, price * numSamples, price * numSamples * (SoilMap.SAMPLING_PROVIDER_MULTIPLIER - 1))
			dialog.target:setCallback(self.onSoilSampleDialogCallback, self, farmlandId)
		end
	end
end

function SoilMap:onSoilSampleDialogCallback(yes, farmlandId)
	if yes then
		if g_server == nil and g_client ~= nil then
			g_client:getServerConnection():sendEvent(PurchaseSoilMapsEvent.new(farmlandId))
		else
			self:purchaseSoilMaps(farmlandId)
		end
	end
end

function SoilMap:getNumSoilSamplesPerHa()
	return 10000 / ((SoilMap.SAMPLING_RADIUS * 0.5)^2 * math.pi)
end

function SoilMap:purchaseSoilMaps(farmlandId)
	local fieldArea = 0
	local farmland = g_farmlandManager.farmlands[farmlandId]

	if farmland ~= nil then
		fieldArea = farmland.totalFieldArea or 0
	end

	if fieldArea > 0 then
		local numSamples = math.ceil(self:getNumSoilSamplesPerHa() * fieldArea)
		local farmId = g_farmlandManager:getFarmlandOwner(farmlandId)
		local price = self:getPricePerSoilSample()
		price = price * numSamples * SoilMap.SAMPLING_PROVIDER_MULTIPLIER

		g_currentMission:addMoney(-price, farmId, self.moneyChangeType, true, true)

		if self.pfModule.farmlandStatistics ~= nil then
			self.pfModule.farmlandStatistics:updateStatistic(farmlandId, "numSoilSamples", numSamples)
			self.pfModule.farmlandStatistics:updateStatistic(farmlandId, "soilSampleCosts", price)
		end

		if self.coverMap ~= nil then
			self.coverMap:uncoverFarmlandArea(farmlandId)
		end
	end
end

function SoilMap:getPricePerSoilSample()
	return self.pricePerSample[g_currentMission.missionInfo.economicDifficulty] or 0
end

function SoilMap:overwriteGameFunctions(pfModule)
	SoilMap:superClass().overwriteGameFunctions(self, pfModule)
end
