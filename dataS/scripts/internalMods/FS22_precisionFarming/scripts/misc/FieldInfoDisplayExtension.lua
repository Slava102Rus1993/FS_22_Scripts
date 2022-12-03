FieldInfoDisplayExtension = {
	MOD_NAME = g_currentModName
}
local FieldInfoDisplayExtension_mt = Class(FieldInfoDisplayExtension)

function FieldInfoDisplayExtension.new(precisionFarming, customMt)
	local self = setmetatable({}, customMt or FieldInfoDisplayExtension_mt)
	self.precisionFarming = precisionFarming
	self.fieldInfos = {}
	self.texts = {
		boxTitle = g_i18n:getText("ui_header"),
		expectedYield = g_i18n:getText("fieldInfo_expectedYield"),
		yieldPotential = g_i18n:getText("fieldInfo_yieldPotential")
	}

	return self
end

function FieldInfoDisplayExtension:loadFromXML(xmlFile, key, baseDirectory, configFileName, mapFilename)
	self.precisionFarming:collectFieldInfos(self)

	return true
end

function FieldInfoDisplayExtension:delete()
end

function FieldInfoDisplayExtension:addFieldInfo(text, object, updateFunc, prio, yieldChangeFunc)
	local fieldInfo = {
		text = text,
		object = object,
		updateFunc = updateFunc,
		yieldChangeFunc = yieldChangeFunc
	}

	table.insert(self.fieldInfos, fieldInfo)
end

function FieldInfoDisplayExtension:infoBoxAddData(data, box)
	for i = 1, #self.fieldInfos do
		local fieldInfo = self.fieldInfos[i]

		if fieldInfo.value ~= nil then
			if fieldInfo.additionalText ~= nil then
				box:addLine(string.format(fieldInfo.text .. " (%s)", fieldInfo.additionalText), fieldInfo.value, fieldInfo.color ~= nil, fieldInfo.color)
			else
				box:addLine(fieldInfo.text, fieldInfo.value, fieldInfo.color ~= nil, fieldInfo.color)
			end
		end
	end
end

function FieldInfoDisplayExtension:infoBoxAddYieldData(data, box)
	local fruitTypeIndex = data.fruitTypeMax
	local fruitGrowthState = data.fruitStateMax

	if fruitTypeIndex == nil then
		return
	end

	local fruitType = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)
	local maxGrowingState = fruitType.minHarvestingGrowthState - 1

	if fruitType.minPreparingGrowthState >= 0 then
		maxGrowingState = math.min(maxGrowingState, fruitType.minPreparingGrowthState - 1)
	end

	local isGrowing = false

	if fruitGrowthState > 0 and fruitGrowthState <= maxGrowingState then
		isGrowing = true
	elseif fruitType.minPreparingGrowthState >= 0 and fruitType.minPreparingGrowthState <= fruitGrowthState and fruitGrowthState <= fruitType.maxPreparingGrowthState then
		isGrowing = true
	elseif fruitType.minHarvestingGrowthState <= fruitGrowthState and fruitGrowthState <= fruitType.maxHarvestingGrowthState then
		isGrowing = true
	end

	if isGrowing then
		local plowFactor = data.plowFactor
		local weedFactor = data.weedFactor
		local stubbleFactor = data.stubbleFactor
		local rollerFactor = 1 - data.needsRollingFactor
		local missionInfo = g_currentMission.missionInfo

		if not missionInfo.plowingRequiredEnabled then
			plowFactor = 1
		end

		if not missionInfo.weedsEnabled then
			weedFactor = 1
		end

		local harvestMultiplier = 0
		harvestMultiplier = harvestMultiplier + plowFactor * 0.1
		harvestMultiplier = harvestMultiplier + weedFactor * 0.15
		harvestMultiplier = harvestMultiplier + stubbleFactor * 0.025
		harvestMultiplier = harvestMultiplier + rollerFactor * 0.025
		local yieldPotential = 1
		local yieldPotentialToHa = 0

		for i = 1, #self.fieldInfos do
			local fieldInfo = self.fieldInfos[i]

			if fieldInfo.yieldChangeFunc ~= nil then
				local factor, proportion, _yieldPotential, _yieldPotentialToHa = fieldInfo.yieldChangeFunc(fieldInfo.object, fieldInfo)
				harvestMultiplier = harvestMultiplier + factor * proportion
				yieldPotential = _yieldPotential or yieldPotential
				yieldPotentialToHa = _yieldPotentialToHa or yieldPotentialToHa
			end
		end

		if yieldPotential > 0 then
			harvestMultiplier = math.ceil(50 + harvestMultiplier * 50) / 100
			local expectedYield = harvestMultiplier * yieldPotential

			if yieldPotentialToHa ~= 0 then
				box:addLine(self.texts.expectedYield, string.format("%d %% | %.1f to/ha", expectedYield * 100, harvestMultiplier * yieldPotentialToHa))
				box:addLine(self.texts.yieldPotential, string.format("%d %% | %.1f to/ha", yieldPotential * 100, yieldPotentialToHa))
			else
				box:addLine(self.texts.expectedYield, string.format("%d %%", expectedYield * 100))
				box:addLine(self.texts.yieldPotential, string.format("%d %%", yieldPotential * 100))
			end
		end
	end
end

function FieldInfoDisplayExtension:overwriteGameFunctions(pfModule)
	pfModule:overwriteGameFunction(PlayerHUDUpdater, "new", function (superFunc, ...)
		local hudUpdater = superFunc(...)
		hudUpdater.precisionFarmingBox = g_currentMission.hud.infoDisplay:createBox(KeyValueInfoHUDBox)

		hudUpdater.precisionFarmingBox:setTitle(self.texts.boxTitle)

		return hudUpdater
	end)
	pfModule:overwriteGameFunction(PlayerHUDUpdater, "delete", function (superFunc, hudUpdater, ...)
		g_currentMission.hud.infoDisplay:destroyBox(hudUpdater.precisionFarmingBox)

		return superFunc(hudUpdater, ...)
	end)
	pfModule:overwriteGameFunction(PlayerHUDUpdater, "showFieldInfo", function (superFunc, hudUpdater)
		local data = hudUpdater.fieldData
		local box = hudUpdater.precisionFarmingBox

		if hudUpdater.fieldInfoNeedsRebuild then
			box:clear()
			box:setTitle(self.texts.boxTitle)
			self:infoBoxAddData(data, box)
			self:infoBoxAddYieldData(data, box)
		end

		superFunc(hudUpdater)
		box:showNextFrame()
	end)
	pfModule:overwriteGameFunction(PlayerHUDUpdater, "fieldAddLime", function (superFunc, hudUpdater, data, box)
	end)
	pfModule:overwriteGameFunction(PlayerHUDUpdater, "fieldAddFertilization", function (superFunc, hudUpdater, data, box)
	end)
	pfModule:overwriteGameFunction(PlayerHUDUpdater, "updateFieldInfo", function (superFunc, hudUpdater, posX, posZ, rotY)
		if hudUpdater.requestedFieldData then
			return
		end

		superFunc(hudUpdater, posX, posZ, rotY)

		local sizeX = 5
		local sizeZ = 5
		local distance = 2
		local dirX, dirZ = MathUtil.getDirectionFromYRotation(rotY)
		local sideX, _, sideZ = MathUtil.crossProduct(dirX, 0, dirZ, 0, 1, 0)
		local startWorldX = posX - sideX * sizeX * 0.5 - dirX * distance
		local startWorldZ = posZ - sideZ * sizeX * 0.5 - dirZ * distance
		local widthWorldX = posX + sideX * sizeX * 0.5 - dirX * distance
		local widthWorldZ = posZ + sideZ * sizeX * 0.5 - dirZ * distance
		local heightWorldX = posX - sideX * sizeX * 0.5 - dirX * (distance + sizeZ)
		local heightWorldZ = posZ - sideZ * sizeX * 0.5 - dirZ * (distance + sizeZ)
		local isColorBlindMode = g_gameSettings:getValue(GameSettings.SETTING.USE_COLORBLIND_MODE) or false

		for i = 1, #self.fieldInfos do
			local fieldInfo = self.fieldInfos[i]
			fieldInfo.value, fieldInfo.color, fieldInfo.additionalText = fieldInfo.updateFunc(fieldInfo.object, fieldInfo, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, isColorBlindMode)
		end
	end)
	pfModule:overwriteGameFunction(PlayerHUDUpdater, "fieldAddFruit", function (superFunc, hudUpdater, data, box)
		local fruitTypeIndex = data.fruitTypeMax
		local fruitGrowthState = data.fruitStateMax

		if fruitTypeIndex == nil then
			return
		end

		local fruitType = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)

		box:addLine(g_i18n:getText("statistic_fillType"), fruitType.fillType.title)

		local witheredState = fruitType.maxHarvestingGrowthState + 1

		if fruitType.maxPreparingGrowthState >= 0 then
			witheredState = fruitType.maxPreparingGrowthState + 1
		end

		local maxGrowingState = fruitType.minHarvestingGrowthState - 1

		if fruitType.minPreparingGrowthState >= 0 then
			maxGrowingState = math.min(maxGrowingState, fruitType.minPreparingGrowthState - 1)
		end

		local text = nil

		if fruitGrowthState == fruitType.cutState then
			text = g_i18n:getText("ui_growthMapCut")
		elseif fruitGrowthState == witheredState then
			text = g_i18n:getText("ui_growthMapWithered")
		elseif fruitGrowthState > 0 and fruitGrowthState <= maxGrowingState then
			text = g_i18n:getText("ui_growthMapGrowing")
		elseif fruitType.minPreparingGrowthState >= 0 and fruitType.minPreparingGrowthState <= fruitGrowthState and fruitGrowthState <= fruitType.maxPreparingGrowthState then
			text = g_i18n:getText("ui_growthMapReadyToPrepareForHarvest")
		elseif fruitType.minHarvestingGrowthState <= fruitGrowthState and fruitGrowthState <= fruitType.maxHarvestingGrowthState then
			text = g_i18n:getText("ui_growthMapReadyToHarvest")
		end

		if text ~= nil then
			box:addLine(g_i18n:getText("ui_mapOverviewGrowth"), text)
		end
	end)
end
