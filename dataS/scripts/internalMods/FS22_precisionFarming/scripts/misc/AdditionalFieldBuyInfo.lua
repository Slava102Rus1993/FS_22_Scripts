AdditionalFieldBuyInfo = {
	MOD_NAME = g_currentModName
}
local AdditionalFieldBuyInfo_mt = Class(AdditionalFieldBuyInfo)

function AdditionalFieldBuyInfo.new(pfModule, customMt)
	local self = setmetatable({}, customMt or AdditionalFieldBuyInfo_mt)
	self.statistics = {}
	self.statisticsByFarmland = {}
	self.mapFrame = nil
	self.selectedFarmlandId = nil
	self.showTotal = false
	self.selectedField = 0
	self.selectedFieldSize = 0
	self.soilDistribution = {
		0,
		0,
		0,
		0
	}
	self.soilDistributionTarget = {
		0,
		0,
		0,
		0
	}
	self.yieldPotential = 0
	self.yieldPotentialTarget = 0
	self.doInterpolation = false
	self.pfModule = pfModule

	return self
end

function AdditionalFieldBuyInfo:loadFromXML(xmlFile, key, baseDirectory, configFileName, mapFilename)
	self.isColorBlindMode = g_gameSettings:getValue(GameSettings.SETTING.USE_COLORBLIND_MODE) or false

	g_messageCenter:subscribe(MessageType.SETTING_CHANGED[GameSettings.SETTING.USE_COLORBLIND_MODE], self.setColorBlindMode, self)

	return true
end

function AdditionalFieldBuyInfo:loadFromItemsXML(xmlFile, key)
end

function AdditionalFieldBuyInfo:saveToXMLFile(xmlFile, key, usedModNames)
end

function AdditionalFieldBuyInfo:delete()
	g_messageCenter:unsubscribeAll(self)
end

function AdditionalFieldBuyInfo:readInfoFromStream(farmlandId, streamId, connection)
	if streamReadBool(streamId) then
		self.selectedField = streamReadUIntN(streamId, 9)
		self.selectedFieldSize = streamReadFloat32(streamId)

		self.mapFrame.fieldBuyInfoWindow:setVisible(true)

		for i = 1, #self.soilDistributionTarget do
			self.soilDistribution[i] = 0
			self.soilDistributionTarget[i] = streamReadUIntN(streamId, 8) / 255
		end

		self.yieldPotentialTarget = streamReadUIntN(streamId, 8) / 255 * 1.25
		self.yieldPotential = 1
		self.doInterpolation = true

		self:updateUIValues()
	else
		self.mapFrame.fieldBuyInfoWindow:setVisible(false)
	end
end

function AdditionalFieldBuyInfo:writeInfoToStream(farmlandId, streamId, connection)
	local farmland = g_farmlandManager.farmlands[farmlandId]
	local fieldNumber, fieldArea = self:getFarmlandFieldInfo(farmlandId)
	local isValid = fieldArea > 0 and farmland.soilDistribution ~= nil

	if streamWriteBool(streamId, isValid) then
		streamWriteUIntN(streamId, fieldNumber, 9)
		streamWriteFloat32(streamId, fieldArea)

		for i = 1, #self.soilDistributionTarget do
			streamWriteUIntN(streamId, farmland.soilDistribution[i] * 255, 8)
		end

		streamWriteUIntN(streamId, farmland.yieldPotential / 1.25 * 255, 8)
	end
end

function AdditionalFieldBuyInfo:setColorBlindMode(isActive)
	if isActive ~= self.isColorBlindMode then
		self.isColorBlindMode = isActive

		self:updateSoilBars()
	end
end

function AdditionalFieldBuyInfo:update(dt)
	if self.doInterpolation then
		local dir = MathUtil.sign(self.yieldPotentialTarget - self.yieldPotential)
		local limit = dir == 1 and math.min or math.max
		self.yieldPotential = limit(self.yieldPotential + dt * 0.00025 * dir, self.yieldPotentialTarget)
		local finishedSoilBars = true

		for i = 1, #self.soilDistributionTarget do
			dir = MathUtil.sign(self.soilDistributionTarget[i] - self.soilDistribution[i])
			limit = dir == 1 and math.min or math.max
			self.soilDistribution[i] = limit(self.soilDistribution[i] + dt * 0.001 * dir, self.soilDistributionTarget[i])

			if self.soilDistribution[i] ~= self.soilDistributionTarget[i] then
				finishedSoilBars = false
			end
		end

		self:updateUIValues()

		if self.yieldPotential == self.yieldPotentialTarget and finishedSoilBars then
			self.doInterpolation = false
		end
	end
end

function AdditionalFieldBuyInfo:setMapFrame(mapFrame)
	self.mapFrame = mapFrame
	self.maxBarSize = self.maxBarSize or mapFrame.soilPercentageBar[1].size[1]

	mapFrame.fieldBuyInfoWindow:setVisible(false)
end

function AdditionalFieldBuyInfo:updateSoilBars()
	if self.pfModule.soilMap ~= nil then
		local soilTypes = self.pfModule.soilMap.soilTypes

		for i = 1, #soilTypes do
			local soilType = soilTypes[i]

			self.mapFrame.soilNameText[i]:setText(soilType.name)
			self.mapFrame.soilPercentageBar[i]:setImageColor(nil, unpack(self.isColorBlindMode and soilType.colorBlind or soilType.color))
		end
	end
end

function AdditionalFieldBuyInfo:updateUIValues()
	local mapFrame = self.mapFrame

	self:updateSoilBars()

	local text = nil

	if self.selectedField ~= 0 then
		text = string.format(g_i18n:getText("ui_economicAnalysisHeaderField", AdditionalFieldBuyInfo.MOD_NAME), self.selectedField, self.selectedFieldSize)
	else
		text = string.format(g_i18n:getText("ui_economicAnalysisHeaderAdditionalField", AdditionalFieldBuyInfo.MOD_NAME), self.selectedFieldSize)
	end

	mapFrame.fieldBuyHeader:setText(text)

	for i = 1, 4 do
		local offset = mapFrame.soilPercentageText[i].size[1] * 0.1
		local str = "~%d%%"

		if self.soilDistribution[i] == 0 then
			str = "%d%%"
			offset = 0
		end

		mapFrame.soilPercentageText[i]:setText(string.format(str, self.soilDistribution[i] * 100))
		mapFrame.soilPercentageBar[i]:setSize(self.maxBarSize * self.soilDistribution[i])
		mapFrame.soilPercentageText[i]:setPosition(mapFrame.soilPercentageBar[i].position[1] + mapFrame.soilPercentageBar[i].size[1] + offset)
	end

	if self.yieldPotential > 1 then
		mapFrame.yieldPercentageBarPos:setPosition(mapFrame.yieldPercentageBarBase.position[1] + mapFrame.yieldPercentageBarBase.size[1])
		mapFrame.yieldPercentageBarPos:setSize(mapFrame.yieldPercentageBarBase.size[1] * (self.yieldPotential - 1))
		mapFrame.yieldPercentageBarNeg:setSize(0)
	elseif self.yieldPotential < 1 then
		local barWidth = mapFrame.yieldPercentageBarBase.size[1] * math.abs(self.yieldPotential - 1)

		mapFrame.yieldPercentageBarNeg:setPosition(mapFrame.yieldPercentageBarBase.position[1] + mapFrame.yieldPercentageBarBase.size[1] - barWidth)
		mapFrame.yieldPercentageBarNeg:setSize(barWidth)
		mapFrame.yieldPercentageBarPos:setSize(0)
	else
		mapFrame.yieldPercentageBarNeg:setSize(0)
		mapFrame.yieldPercentageBarPos:setSize(0)
	end

	mapFrame.yieldPercentageText:setText(string.format("~%d%%", self.yieldPotential * 100))

	local maxWidth = mapFrame.yieldPercentageBarBase.position[1] + mapFrame.yieldPercentageBarBase.size[1] * 1.25 - mapFrame.yieldPercentageText.size[1]

	mapFrame.yieldPercentageText:setPosition(math.min(mapFrame.yieldPercentageBarBase.position[1] + mapFrame.yieldPercentageBarBase.size[1] * self.yieldPotential - mapFrame.yieldPercentageText.size[1] * 0.5, maxWidth))
end

function AdditionalFieldBuyInfo:onFarmlandSelectionChanged(selectedFarmland)
	if self.mapFrame ~= nil then
		if selectedFarmland ~= nil then
			if g_server ~= nil then
				local fieldNumber, fieldArea = self:getFarmlandFieldInfo(selectedFarmland.id)

				if fieldArea >= 0.01 then
					self.selectedField = fieldNumber
					self.selectedFieldSize = fieldArea

					self.mapFrame.fieldBuyInfoWindow:setVisible(true)

					if selectedFarmland.soilDistribution ~= nil then
						for i = 1, #self.soilDistributionTarget do
							self.soilDistribution[i] = 0
							self.soilDistributionTarget[i] = selectedFarmland.soilDistribution[i]
						end

						self.yieldPotentialTarget = selectedFarmland.yieldPotential
						self.yieldPotential = 1
						self.doInterpolation = true
					end

					self:updateUIValues()
				else
					self.mapFrame.fieldBuyInfoWindow:setVisible(false)
				end
			elseif g_server == nil and g_client ~= nil then
				g_client:getServerConnection():sendEvent(RequestFieldBuyInfoEvent.new(selectedFarmland.id))
			end
		else
			self.mapFrame.fieldBuyInfoWindow:setVisible(false)
		end
	end
end

function AdditionalFieldBuyInfo:getFarmlandFieldInfo(farmlandId)
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

function AdditionalFieldBuyInfo:updateFieldSoilDistributionData()
	local pfModule = self.pfModule
	local farmlandManager = g_farmlandManager

	if pfModule.soilMap ~= nil then
		local soilBitVectorMap = pfModule.soilMap.bitVectorMap

		if soilBitVectorMap ~= nil then
			local farmlandX, _ = getBitVectorMapSize(farmlandManager.localMap)
			local soilX, soilY = getBitVectorMapSize(soilBitVectorMap)
			local farmlandScale = farmlandX / soilX

			for x = 0, soilX - 1 do
				for y = 0, soilY - 1 do
					local worldX = x / (soilX - 1) * g_currentMission.terrainSize - g_currentMission.terrainSize * 0.5
					local worldZ = y / (soilY - 1) * g_currentMission.terrainSize - g_currentMission.terrainSize * 0.5
					local isOnField = getDensityAtWorldPos(g_currentMission.terrainDetailId, worldX, 0, worldZ) ~= 0

					if isOnField then
						local valueFarmland = getBitVectorMapPoint(farmlandManager.localMap, x * farmlandScale, y * farmlandScale, 0, farmlandManager.numberOfBits)
						local valueSoil = bitAND(getBitVectorMapPoint(soilBitVectorMap, x, y, 0, pfModule.soilMap.numChannels), 3)

						if valueFarmland > 0 then
							local farmland = farmlandManager.farmlands[valueFarmland]

							if farmland ~= nil then
								if farmland.totalFieldArea == nil then
									farmland.totalFieldArea = 0
								end

								farmland.totalFieldArea = farmland.totalFieldArea + 1

								if farmland.soilDistribution == nil then
									farmland.soilDistribution = {}

									for i = 1, #pfModule.soilMap.soilTypes do
										farmland.soilDistribution[i] = 0
									end
								end

								farmland.soilDistribution[valueSoil + 1] = farmland.soilDistribution[valueSoil + 1] + 1
							end
						end
					end
				end
			end

			local totalYieldPotentialPixels = 0
			local totalFarmlandPixels = 0

			for _, farmland in pairs(farmlandManager.farmlands) do
				farmland:updatePrice()

				if farmland.soilDistribution ~= nil then
					local soilSum = 0

					for i = 1, #farmland.soilDistribution do
						soilSum = soilSum + farmland.soilDistribution[i]
					end

					if soilSum > 0 then
						local yieldPotential = 0

						for i = 1, #farmland.soilDistribution do
							farmland.soilDistribution[i] = math.floor(farmland.soilDistribution[i] / soilSum * 100) / 100
							yieldPotential = yieldPotential + self.pfModule.soilMap:getYieldPotentialBySoilTypeIndex(i) * farmland.soilDistribution[i]
							self.soilDistribution[i] = 0
						end

						farmland.yieldPotential = MathUtil.clamp(yieldPotential, 0, 1.25)
						totalYieldPotentialPixels = totalYieldPotentialPixels + farmland.yieldPotential * soilSum
						totalFarmlandPixels = totalFarmlandPixels + soilSum
					end

					local pixelToSqm = g_currentMission.terrainSize / soilX
					farmland.totalFieldArea = farmland.totalFieldArea * pixelToSqm * pixelToSqm / 10000
				end
			end

			Logging.devInfo("Map Overall Yield Potential: %.3f", totalYieldPotentialPixels / totalFarmlandPixels)
		end
	end
end

function AdditionalFieldBuyInfo:overwriteGameFunctions(pfModule)
	pfModule:overwriteGameFunction(FarmlandManager, "loadFarmlandData", function (superFunc, farmlandManager, xmlFile)
		if not superFunc(farmlandManager, xmlFile) then
			return false
		end

		if g_currentMission.missionInfo.isValid then
			self:updateFieldSoilDistributionData()
		else
			self.delayedFieldSoilDistributionUpdate = true
		end

		return true
	end)
	pfModule:overwriteGameFunction(FieldManager, "setFieldPartitionStatus", function (superFunc, fieldManager, field, fieldPartitions, fieldPartitionIndex, fruitIndex, fieldState, growthState, sprayState, setSpray, plowState, weedState, limeState)
		superFunc(fieldManager, field, fieldPartitions, fieldPartitionIndex, fruitIndex, fieldState, growthState, sprayState, setSpray, plowState, weedState, limeState)

		field.pa_fieldInitialized = true

		if self.delayedFieldSoilDistributionUpdate then
			local readyForUpdate = true

			for _, _field in pairs(fieldManager.fields) do
				if _field:getIsAIActive() and _field.fieldMissionAllowed and not _field.farmland.isOwned and not _field.pa_fieldInitialized then
					readyForUpdate = false

					break
				end
			end

			if readyForUpdate then
				self.delayedFieldSoilDistributionUpdate = false

				self:updateFieldSoilDistributionData()
			end
		end
	end)
	pfModule:overwriteGameFunction(Farmland, "updatePrice", function (superFunc, farmland)
		superFunc(farmland)

		if farmland.yieldPotential ~= nil then
			farmland.price = farmland.price * farmland.yieldPotential
		end
	end)
end
