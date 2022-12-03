FarmlandStatistics = {
	MOD_NAME = g_currentModName
}
local FarmlandStatistics_mt = Class(FarmlandStatistics)

function FarmlandStatistics.new(pfModule, customMt)
	local self = setmetatable({}, customMt or FarmlandStatistics_mt)
	self.statistics = {}
	self.statisticsByFarmland = {}
	self.mapFrame = nil
	self.selectedFarmlandId = nil
	self.showTotal = false
	self.updateValuesTimer = 0
	self.updateValuesInterval = 1000
	self.updateValuesIntervalMultiplayer = 5000
	self.pfModule = pfModule
	self.lastInputHelpMode = g_inputBinding:getInputHelpMode()

	return self
end

function FarmlandStatistics:loadFromXML(xmlFile, key, baseDirectory, configFileName, mapFilename)
	g_farmlandManager:addStateChangeListener(self)

	return true
end

function FarmlandStatistics:loadFromItemsXML(xmlFile, key)
	key = key .. ".farmlandStatistics"

	for i = 1, #self.statistics do
		local statistic = self.statistics[i]
		local statKey = string.format("%s.farmlandStatistic(%d)", key, i - 1)

		if not xmlFile:hasProperty(statKey) then
			break
		end

		statistic:loadFromItemsXML(xmlFile, statKey)
	end
end

function FarmlandStatistics:saveToXMLFile(xmlFile, key, usedModNames)
	key = key .. ".farmlandStatistics"

	for i = 1, #self.statistics do
		local statistic = self.statistics[i]
		local statKey = string.format("%s.farmlandStatistic(%d)", key, i - 1)

		statistic:saveToXMLFile(xmlFile, statKey, usedModNames)
	end
end

function FarmlandStatistics:delete()
	g_farmlandManager:removeStateChangeListener(self)

	self.statistics = {}
	self.statisticsByFarmland = {}
	self.selectedFarmlandId = nil
	self.showTotal = false
end

function FarmlandStatistics:update(dt)
	if self.selectedFarmlandId ~= nil then
		local interval = g_server ~= nil and self.updateValuesInterval or self.updateValuesIntervalMultiplayer
		self.updateValuesTimer = self.updateValuesTimer + dt

		if interval < self.updateValuesTimer then
			local statistic = self.statisticsByFarmland[self.selectedFarmlandId]

			if statistic ~= nil then
				if g_server ~= nil then
					if statistic.hasChanged then
						self:openStatistics(self.selectedFarmlandId)

						statistic.hasChanged = false
					end
				elseif g_server == nil and g_client ~= nil then
					g_client:getServerConnection():sendEvent(RequestFarmlandStatisticsEvent.new(self.selectedFarmlandId))
				end
			end

			self.updateValuesTimer = 0
		end

		local inputHelpMode = g_inputBinding:getInputHelpMode()

		if inputHelpMode ~= self.lastInputHelpMode then
			self.lastInputHelpMode = inputHelpMode

			self:updateButtonIcons()
		end
	end
end

function FarmlandStatistics:readStatisticFromStream(farmlandId, streamId, connection)
	if streamReadBool(streamId) then
		local totalFieldArea = streamReadFloat32(streamId)
		local farmland = g_farmlandManager.farmlands[farmlandId]

		if farmland ~= nil then
			farmland.totalFieldArea = totalFieldArea
		end
	end

	local statistic = self.statisticsByFarmland[farmlandId]

	if statistic ~= nil then
		statistic:onReadStream(streamId, connection)
	end

	self.selectedFarmlandId = farmlandId

	self:openStatistics(farmlandId, true)
	self.pfModule:updatePrecisionFarmingOverlays()
end

function FarmlandStatistics:writeStatisticToStream(farmlandId, streamId, connection)
	local farmland = g_farmlandManager.farmlands[farmlandId]

	if streamWriteBool(streamId, farmland ~= nil) then
		streamWriteFloat32(streamId, farmland.totalFieldArea or 0)
	end

	local statistic = self.statisticsByFarmland[farmlandId]

	if statistic ~= nil then
		statistic:onWriteStream(streamId, connection)
	end
end

function FarmlandStatistics:setMapFrame(mapFrame)
	self.mapFrame = mapFrame

	mapFrame.economicAnalysisWindow:setVisible(false)
	self:updateButtonIcons()
end

function FarmlandStatistics:updateButtonIcons()
	PrecisionFarmingGUI.updateButtonOnInputHelpChange(self.mapFrame.buttonSwitchValues, "ingameMenuPrecisionFarmingStatsSwitchButtonConsole", "ingameMenuPrecisionFarmingStatsSwitchButton")
	PrecisionFarmingGUI.updateButtonOnInputHelpChange(self.mapFrame.buttonResetStats, "ingameMenuPrecisionFarmingStatsResetButtonConsole", "ingameMenuPrecisionFarmingStatsResetButton")

	if self.mapFrame.buttonSwitchValues.inputActionName == nil then
		local uvs = self.showTotal and FarmlandStatistics.UV.TOTAL or FarmlandStatistics.UV.PERIOD

		self.mapFrame.buttonSwitchValues:setImageUVs(nil, GuiUtils.getUVs(uvs))
	end
end

function FarmlandStatistics:onClickButtonResetStats()
	if self.selectedFarmlandId ~= nil then
		self:resetStatistic(self.selectedFarmlandId, false)

		if g_server == nil and g_client ~= nil then
			g_client:getServerConnection():sendEvent(FarmlandStatisticsResetEvent.new(self.selectedFarmlandId))
		end

		self:openStatistics(self.selectedFarmlandId)
	end
end

function FarmlandStatistics:onClickButtonSwitchValues()
	self.showTotal = not self.showTotal

	if self.selectedFarmlandId ~= nil then
		self:openStatistics(self.selectedFarmlandId)
	end

	if self.mapFrame ~= nil then
		self.mapFrame.buttonResetStats:setDisabled(self.showTotal)
	end
end

function FarmlandStatistics:onClickMapFarmland(farmlandId)
	if farmlandId == self.selectedFarmlandId then
		self.selectedFarmlandId = nil

		self:closeStatistics()
		self.pfModule:onFarmlandSelectionChanged(nil, )

		return
	else
		local ownerFarmId = g_farmlandManager:getFarmlandOwner(farmlandId)

		if ownerFarmId ~= FarmlandManager.NO_OWNER_FARM_ID and ownerFarmId == g_currentMission:getFarmId() then
			self.selectedFarmlandId = farmlandId
			self.updateValuesTimer = 0

			self:openStatistics(farmlandId)
			self.pfModule:updatePrecisionFarmingOverlays()
		end
	end
end

function FarmlandStatistics:onMenuCancel()
	if self.selectedFarmlandId ~= nil then
		self:onClickMapFarmland(self.selectedFarmlandId)

		return true
	end

	return false
end

function FarmlandStatistics:onMenuActivate()
	if self.selectedFarmlandId ~= nil then
		self:onClickButtonSwitchValues()

		return true
	end

	return false
end

function FarmlandStatistics:onClickSwitchMapMode()
	if self.selectedFarmlandId ~= nil and not self.showTotal then
		self:onClickButtonResetStats()

		return true
	end

	return false
end

function FarmlandStatistics:getSelectedFarmland()
	if self.selectedFarmlandId ~= nil then
		return self.selectedFarmlandId
	end
end

function FarmlandStatistics:openStatistics(farmlandId, noEventSend)
	local mapFrame = self.mapFrame
	local statistic = self.statisticsByFarmland[farmlandId]

	if statistic ~= nil then
		local fieldNumber, fieldArea = self:getFarmlandFieldInfo(farmlandId)

		if fieldArea >= 0.01 then
			self:updateButtonIcons()
			mapFrame.economicAnalysisWindow:setVisible(true)
			mapFrame.laboratoryWindow:setVisible(false)
			mapFrame.envScoreWindow:setVisible(false)
			mapFrame:resetUIDeadzones()

			local text = nil

			if fieldNumber ~= 0 then
				text = string.format(g_i18n:getText("ui_economicAnalysisHeaderField"), fieldNumber, fieldArea)
			else
				text = string.format(g_i18n:getText("ui_economicAnalysisHeaderAdditionalField"), fieldArea)
			end

			mapFrame.economicAnalysisHeaderField:setText(text)
			mapFrame.economicAnalysisHeaderValues:setText(g_i18n:getText(self.showTotal and "ui_economicAnalysisHeaderValuesTotal" or "ui_economicAnalysisHeaderValuesPeriod"))
			mapFrame.buttonSwitchValues:setText(g_i18n:getText(self.showTotal and "ui_economicAnalysisButtonPeriod" or "ui_economicAnalysisButtonTotal"))

			local function setChangePercentageElement(element, value, valueRegular, cost, inversePercentageColor)
				local pct = 0

				if value ~= valueRegular then
					local direction = nil
					local pctText = ""

					if valueRegular ~= 0 then
						pct = math.floor(-100 * (1 - value / valueRegular))

						if pct ~= 0 then
							local str = pct <= 0 and "(%d%%)" or "(+%d%%)"
							pctText = string.format(str, pct)
							direction = pct > 0
						end
					elseif math.floor(cost or 0) > 0 then
						pctText = string.format("(+%s)", g_i18n:formatMoney(cost))
						pct = 100
						direction = true
					else
						pctText = ""
					end

					if inversePercentageColor == true then
						direction = not direction
					end

					element:applyProfile(direction and "ingameMenuPrecisionFarmingStatsChangeNeg" or "ingameMenuPrecisionFarmingStatsChangePos", true)
					element:setText(pctText)
					element:applyScreenAlignment()
				else
					element:setText("")
				end

				return pct
			end

			local function buildValueDisplay(mapFrame, statistic, index, showTotal, name, nameRegular, fillTypeIndex, showWeight, showValue, showCost, showDetailedLiters, unitStr, cost, weight, inversePercentageColor)
				if unitStr == nil then
					unitStr = " l"
				elseif unitStr:len() > 0 then
					unitStr = " " .. unitStr
				end

				local value = statistic:getValue(showTotal, name)
				local valueRegular = value

				if nameRegular ~= nil then
					if type(nameRegular) == "string" then
						valueRegular = statistic:getValue(showTotal, nameRegular)
					elseif type(nameRegular) == "number" then
						valueRegular = nameRegular
					end
				end

				cost = cost or self:getFillLevelPrice(value, fillTypeIndex)
				weight = weight or self:getFillLevelWeight(value, fillTypeIndex)

				if showValue then
					local valueText = "%d" .. unitStr

					if showDetailedLiters then
						valueText = "%.1f" .. unitStr
					else
						value = MathUtil.round(value)
					end

					if showWeight then
						valueText = valueText .. " | %.1f t"
					end

					mapFrame.statAmountText[index]:setText(string.format(valueText, value, weight))
				else
					mapFrame.statAmountText[index]:setText("")
				end

				if showCost == nil or showCost then
					mapFrame.statCostText[index]:setText(g_i18n:formatMoney(cost))
				else
					mapFrame.statCostText[index]:setText("")
				end

				local percentageIncrease = setChangePercentageElement(mapFrame.statPercentageText[index], value, valueRegular, cost, inversePercentageColor)

				if showCost == false then
					percentageIncrease = 0
				end

				return math.max(math.floor(cost)), math.max(math.floor(cost * (-percentageIncrease * 0.01 + 1)), 0)
			end

			local totalCosts = 0
			local totalRegularCosts = 0
			local costs, regularCosts = nil
			costs, regularCosts = buildValueDisplay(mapFrame, statistic, 1, self.showTotal, "numSoilSamples", 0, "soilSamples", false, true, true, false, "", statistic:getValue(self.showTotal, "soilSampleCosts"))
			totalCosts = totalCosts + costs
			totalRegularCosts = totalRegularCosts + regularCosts
			costs, regularCosts = buildValueDisplay(mapFrame, statistic, 2, self.showTotal, "usedLime", "usedLimeRegular", FillType.LIME, true, true, true, false)
			totalCosts = totalCosts + costs
			totalRegularCosts = totalRegularCosts + regularCosts
			costs, regularCosts = buildValueDisplay(mapFrame, statistic, 3, self.showTotal, "usedMineralFertilizer", "usedMineralFertilizerRegular", FillType.FERTILIZER, true, true, true, false)
			totalCosts = totalCosts + costs
			totalRegularCosts = totalRegularCosts + regularCosts
			costs, regularCosts = buildValueDisplay(mapFrame, statistic, 4, self.showTotal, "usedLiquidFertilizer", "usedLiquidFertilizerRegular", FillType.LIQUIDFERTILIZER, false, true, true, false)
			totalCosts = totalCosts + costs
			totalRegularCosts = totalRegularCosts + regularCosts

			buildValueDisplay(mapFrame, statistic, 5, self.showTotal, "usedManure", "usedManureRegular", FillType.MANURE, true, true, false, false)
			buildValueDisplay(mapFrame, statistic, 6, self.showTotal, "usedLiquidManure", "usedLiquidManureRegular", FillType.LIQUIDMANURE, false, true, false, false)

			costs, regularCosts = buildValueDisplay(mapFrame, statistic, 7, self.showTotal, "usedSeeds", "usedSeedsRegular", FillType.SEEDS, true, true, true, false)
			totalCosts = totalCosts + costs
			totalRegularCosts = totalRegularCosts + regularCosts
			costs, regularCosts = buildValueDisplay(mapFrame, statistic, 8, self.showTotal, "usedHerbicide", "usedHerbicideRegular", FillType.HERBICIDE, false, true, true, false)
			totalCosts = totalCosts + costs
			totalRegularCosts = totalRegularCosts + regularCosts
			costs, regularCosts = buildValueDisplay(mapFrame, statistic, 9, self.showTotal, "usedFuel", nil, FillType.DIESEL, false, true, true, true)
			totalCosts = totalCosts + costs
			totalRegularCosts = totalRegularCosts + regularCosts
			costs, regularCosts = buildValueDisplay(mapFrame, statistic, 10, self.showTotal, "vehicleCosts", nil, 0, false, false, true, false)
			totalCosts = totalCosts + costs
			totalRegularCosts = totalRegularCosts + regularCosts
			costs, regularCosts = buildValueDisplay(mapFrame, statistic, 11, self.showTotal, "helperCosts", nil, 0, false, false, true, false)
			totalCosts = totalCosts + costs
			totalRegularCosts = totalRegularCosts + regularCosts
			local yieldWeight = statistic:getValue(self.showTotal, "yieldWeight")
			local yieldBestPrice = statistic:getValue(self.showTotal, "yieldBestPrice")

			buildValueDisplay(mapFrame, statistic, 12, self.showTotal, "yield", "yieldRegular", 0, true, true, true, false, nil, yieldBestPrice, yieldWeight, true)

			local earningsIncreasePct = statistic:getValue(self.showTotal, "yield") / math.max(statistic:getValue(self.showTotal, "yieldRegular"), 0.01)
			local earningsIncrease = yieldBestPrice - yieldBestPrice / math.max(earningsIncreasePct, 0.01)
			local costIncrease = totalRegularCosts - totalCosts

			setChangePercentageElement(mapFrame.statTotalCostPercentageText, totalCosts, 0, math.abs(costIncrease), false)
			setChangePercentageElement(mapFrame.statTotalEarningsPercentageText, yieldBestPrice, 0, earningsIncrease, true)
			setChangePercentageElement(mapFrame.statTotalPercentageText, yieldBestPrice, 0, costIncrease - earningsIncrease, false)

			local totalEarnings = yieldBestPrice
			local result = totalEarnings - totalCosts

			mapFrame.statTotalCostText:setText(g_i18n:formatMoney(totalCosts))
			mapFrame.statTotalEarningsText:setText(g_i18n:formatMoney(totalEarnings))
			mapFrame.statTotalText:setText(g_i18n:formatMoney(result))
		else
			self.selectedFarmlandId = nil

			self:closeStatistics()
		end

		self.pfModule:onFarmlandSelectionChanged(farmlandId, fieldNumber, fieldArea)
	end

	if not noEventSend and g_server == nil and g_client ~= nil then
		g_client:getServerConnection():sendEvent(RequestFarmlandStatisticsEvent.new(farmlandId))
	end
end

function FarmlandStatistics:buildOverlay(overlay)
	setOverlayColor(overlay, 1, 1, 1, 0.3)
	resetDensityMapVisualizationOverlay(overlay)

	if self.selectedFarmlandId ~= nil then
		local _, fieldArea = self:getFarmlandFieldInfo(self.selectedFarmlandId)

		if fieldArea > 0 then
			local map = g_farmlandManager:getLocalMap()

			setDensityMapVisualizationOverlayStateColor(overlay, map, 0, 0, 0, getBitVectorMapNumChannels(map), self.selectedFarmlandId, unpack(MapOverlayGenerator.COLOR.FIELD_SELECTED))
		end
	end
end

function FarmlandStatistics:getFarmlandFieldInfo(farmlandId)
	return self.pfModule:getFarmlandFieldInfo(farmlandId)
end

function FarmlandStatistics:closeStatistics()
	local mapFrame = self.mapFrame

	mapFrame.economicAnalysisWindow:setVisible(false)
	mapFrame.laboratoryWindow:setVisible(true)
	mapFrame.envScoreWindow:setVisible(true)
	mapFrame:resetUIDeadzones()
	self.pfModule:updatePrecisionFarmingOverlays()
end

function FarmlandStatistics:updateStatistic(farmlandId, name, value)
	local statistic = self.statisticsByFarmland[farmlandId]

	if statistic ~= nil then
		statistic:updateStatistic(name, value)
	end
end

function FarmlandStatistics:resetStatistic(farmlandId, reloadValues, clearTotal)
	local statistic = self.statisticsByFarmland[farmlandId]

	if statistic ~= nil then
		statistic:reset(clearTotal)
	end

	if reloadValues and self.selectedFarmlandId ~= nil then
		self:openStatistics(self.selectedFarmlandId)
	end
end

function FarmlandStatistics:getFillLevelWeight(fillLevel, fillTypeIndex)
	local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)

	if fillType ~= nil then
		return fillLevel * fillType.massPerLiter / FillTypeManager.MASS_SCALE
	end

	return fillLevel
end

function FarmlandStatistics:getFillLevelPrice(fillLevel, fillTypeIndex)
	if fillTypeIndex == "soilSamples" then
		local price = self.pfModule.soilMap.pricePerSample[g_currentMission.missionInfo.economicDifficulty] or 0

		return fillLevel * price
	end

	local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)

	if fillType ~= nil then
		return fillLevel * fillType.pricePerLiter
	end

	return fillLevel
end

function FarmlandStatistics:onFarmlandStateChanged(farmlandId, farmId)
	if farmId == FarmlandManager.NO_OWNER_FARM_ID then
		self:resetStatistic(farmlandId, nil, true)
	end
end

function FarmlandStatistics:overwriteGameFunctions(pfModule)
	pfModule:overwriteGameFunction(FarmlandManager, "loadFarmlandData", function (superFunc, farmlandManager, xmlFile)
		if not superFunc(farmlandManager, xmlFile) then
			return false
		end

		local farmlands = g_farmlandManager:getFarmlands()

		if farmlands ~= nil then
			for id, farmland in pairs(farmlands) do
				local statistic = FarmlandStatistic.new(id)
				self.statisticsByFarmland[id] = statistic

				table.insert(self.statistics, statistic)
			end
		end

		return true
	end)
end

FarmlandStatistics.UV = {
	TOTAL = {
		128,
		64,
		64,
		64
	},
	PERIOD = {
		256,
		64,
		64,
		64
	}
}
