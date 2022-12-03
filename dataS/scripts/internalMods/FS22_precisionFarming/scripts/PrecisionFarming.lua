PrecisionFarming = {
	MOD_NAME = g_currentModName,
	BASE_DIRECTORY = g_currentModDirectory
}

source(PrecisionFarming.BASE_DIRECTORY .. "scripts/events/AdditionalFieldBuyInfoEvent.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/events/CropSensorStateEvent.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/events/ExtendedSowingMachineRateEvent.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/events/ExtendedSprayerAmountEvent.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/events/ExtendedSprayerDefaultFruitTypeEvent.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/events/FarmlandStatisticsEvent.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/events/FarmlandStatisticsResetEvent.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/events/PurchaseSoilMapsEvent.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/events/RequestFarmlandStatisticsEvent.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/events/RequestFieldBuyInfoEvent.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/events/ResetYieldMapEvent.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/events/SoilSamplerStartEvent.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/events/SoilSamplerSendEvent.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/maps/ValueMap.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/maps/SoilMap.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/maps/YieldMap.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/maps/PHMap.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/maps/NitrogenMap.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/maps/SeedRateMap.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/maps/CoverMap.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/gui/PrecisionFarmingGUI.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/gui/InGameMenuPFFrame.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/gui/InGameMenuMapFrameExtension.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/gui/InGameMenuExtension.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/gui/ShopConfigScreenExtension.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/hud/InGameMapExtension.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/hud/InputHelpDisplayExtension.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/misc/AdditionalFieldBuyInfo.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/misc/AdditionalSpecializations.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/misc/AIExtension.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/misc/CropSensorLinkageData.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/misc/ExtendedWeedControl.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/misc/FieldInfoDisplayExtension.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/misc/HarvestExtension.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/misc/HelplineExtension.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/misc/ManureSensorLinkageData.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/misc/PrecisionFarmingDebug.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/misc/PrecisionFarmingSettings.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/misc/UsageBuffer.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/environmentalScore/EnvironmentalScore.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/statistics/FarmlandStatistics.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/statistics/FarmlandStatistic.lua")
source(PrecisionFarming.BASE_DIRECTORY .. "scripts/statistics/FarmlandStatisticCounter.lua")

local PrecisionFarming_mt = Class(PrecisionFarming)

function PrecisionFarming.new(customMt)
	local self = setmetatable({}, customMt or PrecisionFarming_mt)
	self.overwrittenGameFunctions = {}
	self.valueMaps = {}
	self.visualizationOverlays = {}
	self.precisionFarmingSettings = PrecisionFarmingSettings.new(self)

	self:registerValueMap(SoilMap.new(self))
	self:registerValueMap(PHMap.new(self))
	self:registerValueMap(NitrogenMap.new(self))
	self:registerValueMap(YieldMap.new(self))
	self:registerValueMap(SeedRateMap.new(self))
	self:registerValueMap(CoverMap.new(self))

	self.inGameMenuMapFrameExtension = InGameMenuMapFrameExtension.new()
	self.inputHelpDisplayExtension = InputHelpDisplayExtension.new(self)
	self.shopConfigScreenExtension = ShopConfigScreenExtension.new()
	self.inGameMenuExtension = InGameMenuExtension.new()
	self.inGameMapExtension = InGameMapExtension.new(self)
	self.aiExtension = AIExtension.new()
	self.fieldInfoDisplayExtension = FieldInfoDisplayExtension.new(self)
	self.harvestExtension = HarvestExtension.new(self)
	self.helplineExtension = HelplineExtension.new(self)
	self.farmlandStatistics = FarmlandStatistics.new(self)
	self.additionalFieldBuyInfo = AdditionalFieldBuyInfo.new(self)
	self.cropSensorLinkageData = CropSensorLinkageData.new(self)
	self.environmentalScore = EnvironmentalScore.new(self)
	self.extendedWeedControl = ExtendedWeedControl.new(self)
	self.manureSensorLinkageData = ManureSensorLinkageData.new(self)
	self.precisionFarmingDebug = PrecisionFarmingDebug.new(self)
	self.firstTimeRun = false
	self.firstTimeRunDelay = 2000

	return self
end

function PrecisionFarming:initialize()
	for i = 1, #self.valueMaps do
		self.valueMaps[i]:initialize(self)
		self.valueMaps[i]:overwriteGameFunctions(self)
	end

	self.inGameMenuMapFrameExtension:overwriteGameFunctions(self)
	self.inputHelpDisplayExtension:overwriteGameFunctions(self)
	self.shopConfigScreenExtension:overwriteGameFunctions(self)
	self.inGameMenuExtension:overwriteGameFunctions(self)
	self.inGameMapExtension:overwriteGameFunctions(self)
	self.aiExtension:overwriteGameFunctions(self)
	self.fieldInfoDisplayExtension:overwriteGameFunctions(self)
	self.harvestExtension:overwriteGameFunctions(self)
	self.helplineExtension:overwriteGameFunctions(self)
	self.farmlandStatistics:overwriteGameFunctions(self)
	self.additionalFieldBuyInfo:overwriteGameFunctions(self)
	self.cropSensorLinkageData:overwriteGameFunctions(self)
	self.environmentalScore:overwriteGameFunctions(self)
	self.extendedWeedControl:overwriteGameFunctions(self)
	self.manureSensorLinkageData:overwriteGameFunctions(self)
	self.precisionFarmingSettings:overwriteGameFunctions(self)
end

function PrecisionFarming:loadMap(filename)
	if g_modIsLoaded[PrecisionFarming.MOD_NAME] then
		if not Utils.getNoNil(getXMLBool(g_savegameXML, "gameSettings.precisionFarming#initialized"), false) then
			self.firstTimeRun = true

			setXMLBool(g_savegameXML, "gameSettings.precisionFarming#initialized", true)
			g_gameSettings:saveToXMLFile(g_savegameXML)
		end

		self.mapFilename = filename
		self.configFileName = Utils.getFilename("PrecisionFarming.xml", PrecisionFarming.BASE_DIRECTORY)
		local xmlFile = loadXMLFile("ConfigXML", self.configFileName)

		for i = 1, #self.valueMaps do
			self.valueMaps[i]:loadFromXML(xmlFile, "precisionFarming", PrecisionFarming.BASE_DIRECTORY, self.configFileName, filename)
		end

		for i = 1, #self.valueMaps do
			self.valueMaps[i]:postLoad(xmlFile, "precisionFarming", PrecisionFarming.BASE_DIRECTORY, self.configFileName, filename)
		end

		self.aiExtension:loadFromXML(xmlFile, "precisionFarming.aiExtension", PrecisionFarming.BASE_DIRECTORY, self.configFileName, filename)
		self.fieldInfoDisplayExtension:loadFromXML(xmlFile, "precisionFarming.fieldInfoDisplayExtension", PrecisionFarming.BASE_DIRECTORY, self.configFileName, filename)
		self.harvestExtension:loadFromXML(xmlFile, "precisionFarming.harvestExtension", PrecisionFarming.BASE_DIRECTORY, self.configFileName, filename)
		self.helplineExtension:loadFromXML(xmlFile, "precisionFarming.helplineExtension", PrecisionFarming.BASE_DIRECTORY, self.configFileName, filename)
		self.farmlandStatistics:loadFromXML(xmlFile, "precisionFarming.farmlandStatistics", PrecisionFarming.BASE_DIRECTORY, self.configFileName, filename)
		self.additionalFieldBuyInfo:loadFromXML(xmlFile, "precisionFarming.additionalFieldBuyInfo", PrecisionFarming.BASE_DIRECTORY, self.configFileName, filename)
		self.cropSensorLinkageData:loadFromXML(xmlFile, "precisionFarming.cropSensorLinkageData", PrecisionFarming.BASE_DIRECTORY, self.configFileName, filename)
		self.manureSensorLinkageData:loadFromXML(xmlFile, "precisionFarming.manureSensorLinkageData", PrecisionFarming.BASE_DIRECTORY, self.configFileName, filename)
		self.environmentalScore:loadFromXML(xmlFile, "precisionFarming.environmentalScore", PrecisionFarming.BASE_DIRECTORY, self.configFileName, filename)
		self.extendedWeedControl:loadFromXML(xmlFile, "precisionFarming.extendedWeedControl", PrecisionFarming.BASE_DIRECTORY, self.configFileName, filename)
		delete(xmlFile)
	end
end

function PrecisionFarming:unloadMapData()
	self.inGameMenuMapFrameExtension:unloadMapData()
	self.inputHelpDisplayExtension:unloadMapData()
	self.shopConfigScreenExtension:unloadMapData()
	self.inGameMenuExtension:unloadMapData()
	self.inGameMapExtension:unloadMapData()
	self.extendedWeedControl:unloadMapData()
end

function PrecisionFarming:initTerrain(mission, terrainId, filename)
	for i = 1, #self.valueMaps do
		self.valueMaps[i]:initTerrain(mission, terrainId, filename)
	end
end

function PrecisionFarming:deleteMap()
	if g_modIsLoaded[PrecisionFarming.MOD_NAME] then
		for i = #self.visualizationOverlays, 1, -1 do
			resetDensityMapVisualizationOverlay(self.visualizationOverlays[i])

			self.visualizationOverlays[i] = nil
		end

		for i = 1, #self.valueMaps do
			self.valueMaps[i]:delete()
		end

		self.inGameMenuMapFrameExtension:delete()
		self.inputHelpDisplayExtension:delete()
		self.shopConfigScreenExtension:delete()
		self.inGameMenuExtension:delete()
		self.inGameMapExtension:delete()
		self.aiExtension:delete()
		self.fieldInfoDisplayExtension:delete()
		self.harvestExtension:delete()
		self.helplineExtension:delete()
		self.farmlandStatistics:delete()
		self.additionalFieldBuyInfo:delete()
		self.cropSensorLinkageData:delete()
		self.manureSensorLinkageData:delete()
		self.environmentalScore:delete()

		for i = #self.overwrittenGameFunctions, 1, -1 do
			local reference = self.overwrittenGameFunctions[i]
			reference.object[reference.funcName] = reference.oldFunc
			self.overwrittenGameFunctions[i] = nil
		end
	end
end

function PrecisionFarming:loadFromItemsXML(xmlFile, key)
	for i = #self.valueMaps, 1, -1 do
		self.valueMaps[i]:loadFromItemsXML(xmlFile, key)
	end

	self.farmlandStatistics:loadFromItemsXML(xmlFile, key)
	self.additionalFieldBuyInfo:loadFromItemsXML(xmlFile, key)
	self.environmentalScore:loadFromItemsXML(xmlFile, key)
end

function PrecisionFarming:saveToXMLFile(xmlFile, key, usedModNames)
	for i = 1, #self.valueMaps do
		self.valueMaps[i]:saveToXMLFile(xmlFile, key, usedModNames)
	end

	self.farmlandStatistics:saveToXMLFile(xmlFile, key, usedModNames)
	self.additionalFieldBuyInfo:saveToXMLFile(xmlFile, key, usedModNames)
	self.environmentalScore:saveToXMLFile(xmlFile, key, usedModNames)
end

function PrecisionFarming:addSetting(...)
	self.precisionFarmingSettings:addSetting(...)
end

function PrecisionFarming:registerVisualizationOverlay(overlay)
	table.insert(self.visualizationOverlays, overlay)
end

function PrecisionFarming:update(dt)
	if g_modIsLoaded[PrecisionFarming.MOD_NAME] then
		for i = 1, #self.valueMaps do
			self.valueMaps[i]:update(dt)
		end

		self.inGameMenuMapFrameExtension:update(dt)
		self.inputHelpDisplayExtension:update(dt)
		self.shopConfigScreenExtension:update(dt)
		self.inGameMenuExtension:update(dt)
		self.inGameMapExtension:update(dt)
		self.farmlandStatistics:update(dt)
		self.additionalFieldBuyInfo:update(dt)
		self.harvestExtension:update(dt)
		self.environmentalScore:update(dt)

		if self.firstTimeRun then
			self.firstTimeRunDelay = math.max(self.firstTimeRunDelay - dt, 0)

			if self.firstTimeRunDelay == 0 and self.helplineExtension:getAllowFirstTimeEvent() then
				self.helplineExtension:onFirstTimeRun()

				self.firstTimeRun = false
			end
		end
	end
end

function PrecisionFarming:draw()
	if g_modIsLoaded[PrecisionFarming.MOD_NAME] then
		self.harvestExtension:draw()
	end
end

function PrecisionFarming:registerValueMap(object)
	table.insert(self.valueMaps, object)

	self[object.name] = object
	object.valueMapIndex = #self.valueMaps
end

function PrecisionFarming:getValueMaps()
	return self.valueMaps
end

function PrecisionFarming:getValueMap(index)
	return self.valueMaps[index]
end

function PrecisionFarming:updatePrecisionFarmingOverlays()
	self.inGameMenuExtension:updatePrecisionFarmingOverlays()
	self.inGameMapExtension:updatePrecisionFarmingOverlays()
end

function PrecisionFarming:onValueMapSelectionChanged(valueMap)
	self.yieldMap:onValueMapSelectionChanged(valueMap)
end

function PrecisionFarming:onFarmlandSelectionChanged(farmlandId, fieldNumber, fieldArea)
	self.yieldMap:onFarmlandSelectionChanged(farmlandId, fieldNumber, fieldArea)
end

function PrecisionFarming:collectFieldInfos(fieldInfoDisplayExtension)
	for i = 1, #self.valueMaps do
		self.valueMaps[i]:collectFieldInfos(fieldInfoDisplayExtension)
	end
end

function PrecisionFarming:getIsMaizePlusActive()
	return g_modIsLoaded.FS22_MaizePlus
end

function PrecisionFarming:getCropSensorLinkageData(configFileName)
	return self.cropSensorLinkageData:getCropSensorLinkageData(configFileName)
end

function PrecisionFarming:getClonedCropSensorNode(typeName)
	return self.cropSensorLinkageData:getClonedCropSensorNode(typeName)
end

function PrecisionFarming:getManureSensorLinkageData(configFileName)
	return self.manureSensorLinkageData:getManureSensorLinkageData(configFileName)
end

function PrecisionFarming:getClonedManureSensorNode(typeName)
	return self.manureSensorLinkageData:getClonedManureSensorNode(typeName)
end

function PrecisionFarming:getFarmlandFieldInfo(farmlandId)
	local fieldNumber = 0
	local fieldArea = 0
	local farmland = g_farmlandManager.farmlands[farmlandId]

	if farmland ~= nil then
		fieldArea = farmland.totalFieldArea or 0
	end

	local fields = g_fieldManager:getFields()

	if fields ~= nil then
		for _, field in pairs(fields) do
			if field.farmland ~= nil and field.farmland.id == farmlandId then
				fieldNumber = field.fieldId

				break
			end
		end
	end

	return fieldNumber, fieldArea
end

function PrecisionFarming:overwriteGameFunction(object, funcName, newFunc)
	if object == nil then
		Logging.error("Failed to overwrite '%s'", funcName)
		printCallstack()

		return
	end

	local oldFunc = object[funcName]

	if oldFunc ~= nil then
		object[funcName] = function (...)
			return newFunc(oldFunc, ...)
		end
	end

	local reference = {
		object = object,
		funcName = funcName,
		oldFunc = oldFunc
	}

	table.insert(self.overwrittenGameFunctions, reference)
end

g_precisionFarming = PrecisionFarming.new()

addModEventListener(g_precisionFarming)

local function validateTypes(self)
	if self.typeName == "vehicle" and g_modIsLoaded[PrecisionFarming.MOD_NAME] and g_iconGenerator == nil then
		g_precisionFarming:initialize()
	end
end

TypeManager.validateTypes = Utils.prependedFunction(TypeManager.validateTypes, validateTypes)

local function save(itemsSystem, xmlFilename, usedModNames)
	if g_modIsLoaded[PrecisionFarming.MOD_NAME] then
		local xmlFilename = g_currentMission.missionInfo.savegameDirectory .. "/precisionFarming.xml"
		local xmlFile = XMLFile.create("precisionFarmingXML", xmlFilename, "precisionFarming")

		if xmlFile ~= nil then
			g_precisionFarming:saveToXMLFile(xmlFile, "precisionFarming", usedModNames)
			xmlFile:save()
			xmlFile:delete()
		end
	end
end

ItemSystem.save = Utils.prependedFunction(ItemSystem.save, save)

local function loadItems(itemsSystem, xmlFilename, ...)
	if g_modIsLoaded[PrecisionFarming.MOD_NAME] then
		local savegameDirectory = g_currentMission.missionInfo.savegameDirectory

		if savegameDirectory ~= nil then
			local xmlFilename = g_currentMission.missionInfo.savegameDirectory .. "/precisionFarming.xml"

			if fileExists(xmlFilename) then
				local xmlFile = XMLFile.load("precisionFarmingXML", xmlFilename)

				if xmlFile ~= nil then
					g_precisionFarming:loadFromItemsXML(xmlFile, "precisionFarming")
					xmlFile:delete()
				end
			end
		end
	end
end

ItemSystem.loadItems = Utils.prependedFunction(ItemSystem.loadItems, loadItems)

local function unloadMapData(mission, xmlFilename)
	if g_modIsLoaded[PrecisionFarming.MOD_NAME] then
		g_precisionFarming:unloadMapData()
	end
end

Gui.unloadMapData = Utils.prependedFunction(Gui.unloadMapData, unloadMapData)

local function postInitTerrain(mission, terrainId, filename)
	if g_modIsLoaded[PrecisionFarming.MOD_NAME] then
		g_precisionFarming:initTerrain(mission, terrainId, filename)
	end
end

FSBaseMission.initTerrain = Utils.appendedFunction(FSBaseMission.initTerrain, postInitTerrain)
