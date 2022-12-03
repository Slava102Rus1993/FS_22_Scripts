InGameMenuMapFrameExtension = {
	MOD_NAME = g_currentModName,
	MOD_DIR = g_currentModDirectory,
	GUI_EXT_XML = g_currentModDirectory .. "gui/InGameMenuMapFrameExtension.xml"
}
local InGameMenuMapFrameExtension_mt = Class(InGameMenuMapFrameExtension)

function InGameMenuMapFrameExtension.new(customMt)
	local self = setmetatable({}, customMt or InGameMenuMapFrameExtension_mt)

	return self
end

function InGameMenuMapFrameExtension:unloadMapData()
end

function InGameMenuMapFrameExtension:delete()
end

function InGameMenuMapFrameExtension:update(dt)
end

function InGameMenuMapFrameExtension:overwriteGameFunctions(pfModule)
	pfModule:overwriteGameFunction(InGameMenuMapFrame, "onLoadMapFinished", function (superFunc, self)
		superFunc(self)

		pfModule.inGameMenuMapFrameExtension.inGameMenuMapFrame = self
		local xmlFile = loadXMLFile("Temp", InGameMenuMapFrameExtension.GUI_EXT_XML)

		if xmlFile ~= nil and xmlFile ~= 0 then
			if #self.elements > 0 then
				local mapFrame = self.elements[1]

				if mapFrame ~= nil and mapFrame.name == "ingameMenuMapOverview" then
					local controls = {
						FIELD_BUY_WINDOW = "fieldBuyInfoWindow",
						FIELD_BUY_HEADER = "fieldBuyHeader",
						FIELD_BUY_YIELD_PCT_BAR_POS = "yieldPercentageBarPos",
						FIELD_BUY_YIELD_PCT_BAR_NEG = "yieldPercentageBarNeg",
						FIELD_BUY_SOIL_NAME_TXT = "soilNameText",
						FIELD_BUY_YIELD_PCT_BAR_BASE = "yieldPercentageBarBase",
						FIELD_BUY_YIELD_PCT_TXT = "yieldPercentageText",
						FIELD_BUY_SOIL_PCT_BAR = "soilPercentageBar",
						FIELD_BUY_SOIL_PCT_TXT = "soilPercentageText"
					}

					for k, v in pairs(controls) do
						self.controlIDs[v] = nil
					end

					self:registerControls(controls)
					g_gui:loadGuiRec(xmlFile, "inGameMenuMapFrameExtension", mapFrame, self)
					self:exposeControlsAsFields("MapFrame")
					self:onGuiSetupFinished()

					if pfModule.additionalFieldBuyInfo ~= nil then
						pfModule.additionalFieldBuyInfo:setMapFrame(self)
					end

					self.precisionFarmingFieldBuyContainer = mapFrame.elements[#mapFrame.elements]

					self.precisionFarmingFieldBuyContainer:applyScreenAlignment()
					self.precisionFarmingFieldBuyContainer:updateAbsolutePosition()
				end
			end

			delete(xmlFile)
		end
	end)
	pfModule:overwriteGameFunction(InGameMenuMapFrame, "onClickSwitchMapMode", function (superFunc, self)
		if pfModule.additionalFieldBuyInfo ~= nil then
			pfModule.additionalFieldBuyInfo:onFarmlandSelectionChanged()
			self:resetUIDeadzones()
		end

		superFunc(self)
	end)
	pfModule:overwriteGameFunction(InGameMenuMapFrame, "onFrameOpen", function (superFunc, self)
		superFunc(self)

		self.ingameMap.onClickMapCallback = self.ingameMap.target.onClickMap
	end)
	pfModule:overwriteGameFunction(InGameMenuMapFrame, "onFrameClose", function (superFunc, self)
		superFunc(self)

		if pfModule.additionalFieldBuyInfo ~= nil then
			pfModule.additionalFieldBuyInfo:onFarmlandSelectionChanged()
			self:resetUIDeadzones()
		end
	end)
	pfModule:overwriteGameFunction(InGameMenuMapFrame, "onClickMap", function (superFunc, self, element, worldX, worldZ)
		local oldFarmland = self.selectedFarmland

		function self.farmlandValueText.setValue(text, price)
			local selectedFarmland = g_farmlandManager:getFarmlandAtWorldPosition(worldX, worldZ)

			if selectedFarmland.totalFieldArea ~= nil then
				text:setText(string.format("%s (%s / ha)", g_i18n:formatMoney(price, 0, true, false), g_i18n:formatMoney(price / selectedFarmland.totalFieldArea, 0, true, false)))
			else
				text:setText(g_i18n:formatMoney(price, 0, true, false))
			end

			text.parent:setSize(1, nil)
		end

		superFunc(self, element, worldX, worldZ)

		if self.selectedFarmland ~= oldFarmland and pfModule.additionalFieldBuyInfo ~= nil then
			pfModule.additionalFieldBuyInfo:onFarmlandSelectionChanged(self.selectedFarmland)
			self:resetUIDeadzones()
		end
	end)
	pfModule:overwriteGameFunction(InGameMenuMapFrame, "resetUIDeadzones", function (superFunc, self)
		superFunc(self)

		if self.fieldBuyInfoWindow ~= nil and self.fieldBuyInfoWindow:getIsVisible() then
			self.ingameMap:addCursorDeadzone(self.fieldBuyInfoWindow.absPosition[1], self.fieldBuyInfoWindow.absPosition[2], self.fieldBuyInfoWindow.size[1], self.fieldBuyInfoWindow.size[2])
		end
	end)
	pfModule:overwriteGameFunction(MapOverlayGenerator, "buildSoilStateMapOverlay", function (superFunc, _self, soilStateFilter)
		soilStateFilter[MapOverlayGenerator.SOIL_STATE_INDEX.NEEDS_LIME] = false
		soilStateFilter[MapOverlayGenerator.SOIL_STATE_INDEX.FERTILIZED] = false

		superFunc(_self, soilStateFilter)
	end)
	pfModule:overwriteGameFunction(MapOverlayGenerator, "getDisplaySoilStates", function (superFunc, _self)
		local displayValues = superFunc(_self)
		displayValues[MapOverlayGenerator.SOIL_STATE_INDEX.FERTILIZED].isActive = false
		displayValues[MapOverlayGenerator.SOIL_STATE_INDEX.NEEDS_LIME].isActive = false

		return displayValues
	end)
end
