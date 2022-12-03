ShopConfigScreenExtension = {
	MOD_NAME = g_currentModName,
	MOD_DIR = g_currentModDirectory,
	GUI_EXT_XML = g_currentModDirectory .. "gui/ShopConfigScreenExtension.xml",
	HEADER_SIZE = 0.05555555555555555
}
local ShopConfigScreenExtension_mt = Class(ShopConfigScreenExtension)

function ShopConfigScreenExtension.new(customMt)
	local self = setmetatable({}, customMt or ShopConfigScreenExtension_mt)

	return self
end

function ShopConfigScreenExtension:unloadMapData()
end

function ShopConfigScreenExtension:delete()
end

function ShopConfigScreenExtension:update(dt)
end

function ShopConfigScreenExtension:overwriteGameFunctions(pfModule)
	pfModule:overwriteGameFunction(ShopConfigScreen, "loadMapData", function (superFunc, self, ...)
		superFunc(self, ...)

		local xmlFile = loadXMLFile("Temp", ShopConfigScreenExtension.GUI_EXT_XML)

		if xmlFile ~= nil and xmlFile ~= 0 then
			if #self.elements > 0 then
				local rootElement = self.elements[1].elements[3]
				local controls = {
					INFO_WINDOW = "precisionFarmingInfoWindow",
					INFO_HEADER = "precisionFarmingInfoHeader",
					INFO_TEXT = "precisionFarmingInfoText"
				}

				for k, v in pairs(controls) do
					self.controlIDs[v] = nil
				end

				self:registerControls(controls)
				g_gui:loadGuiRec(xmlFile, "shopConfigScreenExtension", rootElement, self)
				self:exposeControlsAsFields("MapFrame")
				self:onGuiSetupFinished()

				self.precisionFarmingInfoContainer = rootElement.elements[#rootElement.elements]

				self.precisionFarmingInfoContainer:applyScreenAlignment()
				self.precisionFarmingInfoContainer:updateAbsolutePosition()

				self.precisionFarmingTexts = {
					cropSensorHeader = g_i18n:getText("shopInfo_cropSensorHeader", ShopConfigScreenExtension.MOD_NAME),
					cropSensorText = g_i18n:getText("shopInfo_cropSensorText", ShopConfigScreenExtension.MOD_NAME),
					manureSensorHeader = g_i18n:getText("shopInfo_manureSensorHeader", ShopConfigScreenExtension.MOD_NAME),
					manureSensorText = g_i18n:getText("shopInfo_manureSensorText", ShopConfigScreenExtension.MOD_NAME),
					weedSpotSprayHeader = g_i18n:getText("shopInfo_weedSpotSprayHeader", ShopConfigScreenExtension.MOD_NAME),
					weedSpotSprayText = g_i18n:getText("shopInfo_weedSpotSprayText", ShopConfigScreenExtension.MOD_NAME)
				}
				self.pfShopConfigurations = {
					cropSensor = {
						lastIndex = 1,
						lastChangeTime = 0,
						title = g_i18n:getText("shopInfo_cropSensorHeader", ShopConfigScreenExtension.MOD_NAME),
						text = g_i18n:getText("shopInfo_cropSensorText", ShopConfigScreenExtension.MOD_NAME)
					},
					manureSensor = {
						lastIndex = 1,
						lastChangeTime = 0,
						title = g_i18n:getText("shopInfo_manureSensorHeader", ShopConfigScreenExtension.MOD_NAME),
						text = g_i18n:getText("shopInfo_manureSensorText", ShopConfigScreenExtension.MOD_NAME)
					},
					weedSpotSpray = {
						lastIndex = 1,
						lastChangeTime = 0,
						title = g_i18n:getText("shopInfo_weedSpotSprayHeader", ShopConfigScreenExtension.MOD_NAME),
						text = g_i18n:getText("shopInfo_weedSpotSprayText", ShopConfigScreenExtension.MOD_NAME)
					}
				}
			end

			delete(xmlFile)
		end
	end)
	pfModule:overwriteGameFunction(ShopConfigScreen, "onOpen", function (superFunc, self, ...)
		superFunc(self, ...)

		self.pfLastCropSensorConfigurationIndex = nil
		self.pfLastManureSensorConfigurationIndex = nil
		self.pfLastWeedSpotSpraySensorConfigurationIndex = nil

		if self.pfShopConfigurations ~= nil then
			for _, configData in pairs(self.pfShopConfigurations) do
				configData.lastIndex = 1
				configData.lastChangeTime = 0
			end
		end
	end)
	pfModule:overwriteGameFunction(ShopConfigScreen, "loadCurrentConfiguration", function (superFunc, self, ...)
		superFunc(self, ...)

		if self.configurations ~= nil and self.pfShopConfigurations ~= nil then
			for configName, configData in pairs(self.pfShopConfigurations) do
				local index = self.configurations[configName]

				if index ~= nil and configData.lastIndex ~= index then
					configData.lastIndex = index
					configData.lastChangeTime = g_time
				end
			end

			local configDataToShow = nil
			local maxTime = 0

			for configName, configData in pairs(self.pfShopConfigurations) do
				local index = self.configurations[configName]

				if index ~= nil and index > 1 and maxTime < configData.lastChangeTime then
					maxTime = configData.lastChangeTime
					configDataToShow = configData
				end
			end

			if configDataToShow == nil then
				for configName, configData in pairs(self.pfShopConfigurations) do
					local index = self.configurations[configName]

					if index ~= nil and index > 1 then
						configDataToShow = configData

						break
					end
				end
			end

			self.precisionFarmingInfoWindow:setVisible(configDataToShow ~= nil)

			if configDataToShow ~= nil then
				self.precisionFarmingInfoHeader:setText(configDataToShow.title)
				self.precisionFarmingInfoText:setText(configDataToShow.text)

				local height = self.precisionFarmingInfoText:getTextHeight(true) + ShopConfigScreenExtension.HEADER_SIZE

				self.precisionFarmingInfoWindow:setSize(nil, height)
			end
		end
	end)
end
