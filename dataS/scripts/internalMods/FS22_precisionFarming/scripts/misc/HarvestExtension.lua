HarvestExtension = {
	YIELD_DEBUG = false,
	MOD_NAME = g_currentModName
}
local HarvestExtension_mt = Class(HarvestExtension)

function HarvestExtension.new(pfModule, customMt)
	local self = setmetatable({}, customMt or HarvestExtension_mt)
	self.pfModule = pfModule
	self.debugValues = {
		regularNFactor = 0,
		rollerFactor = 0,
		seedRateYieldFactor = 0,
		yieldPotential = 0,
		plowFactor = 0,
		yieldFactor = 0,
		lastSeedRateFound = 0,
		nFactor = 0,
		nActualValue = 0,
		pHRegularValue = 0,
		yieldFactorRegular = 0,
		pHActualValue = 0,
		nRegularValue = 0,
		pHFactor = 0,
		ignoreOverfertilization = false,
		regularPHFactor = 0,
		weedFactor = 0,
		lastSeedRateTarget = 0,
		nTargetValue = 0,
		stubbleFactor = 0,
		pHTargetValue = 0
	}

	g_messageCenter:subscribe(MessageType.UNLOADING_STATIONS_CHANGED, self.onUnloadingStationsChanged, self)
	addConsoleCommand("pfShowYieldDebug", "Displayes precision farming yield debug", "toggleYieldDebug", self)

	return self
end

function HarvestExtension:delete()
	g_messageCenter:unsubscribeAll(self)
	removeConsoleCommand("pfShowYieldDebug")
end

function HarvestExtension:loadFromXML(xmlFile, key, baseDirectory, configFileName, mapFilename)
	return true
end

function HarvestExtension:toggleYieldDebug()
	HarvestExtension.YIELD_DEBUG = not HarvestExtension.YIELD_DEBUG
end

function HarvestExtension:update(dt)
end

function HarvestExtension:draw()
	if HarvestExtension.YIELD_DEBUG then
		local debugValues = self.debugValues
		local nitrogenMap = self.pfModule.nitrogenMap
		local pHMap = self.pfModule.pHMap
		local seedRateMap = self.pfModule.seedRateMap

		renderText(0.01, 0.42, 0.015, string.format("Nitrogen: Actual: %d | Target: %d | Regular: %d => Factor: %d%% | Regular Factor: %d%%", nitrogenMap:getNitrogenValueFromInternalValue(debugValues.nActualValue), nitrogenMap:getNitrogenValueFromInternalValue(debugValues.nTargetValue), nitrogenMap:getNitrogenValueFromInternalValue(debugValues.nRegularValue), debugValues.nFactor * 100, debugValues.regularNFactor * 100))
		renderText(0.01, 0.4, 0.015, string.format("Nitrogen: Yield Potential: %d%% | ignoreOverfertilization: %s", debugValues.yieldPotential * 100, debugValues.ignoreOverfertilization))
		renderText(0.01, 0.38, 0.015, string.format("Seed Rate: Yield: %d%% | Optimal Rate: %s | Found Rate: %s", debugValues.seedRateYieldFactor * 100, seedRateMap:getRateLabelByIndex(debugValues.lastSeedRateTarget), seedRateMap:getRateLabelByIndex(debugValues.lastSeedRateFound)))
		renderText(0.01, 0.36, 0.015, string.format("pH: Actual: %.3f | Target: %.3f | Regular: %.3f => Factor: %d%% | Regular Factor: %d%%", pHMap:getPhValueFromInternalValue(debugValues.pHActualValue), pHMap:getPhValueFromInternalValue(debugValues.pHTargetValue), pHMap:getPhValueFromInternalValue(debugValues.pHRegularValue), debugValues.pHFactor * 100, debugValues.regularPHFactor * 100))
		renderText(0.01, 0.34, 0.015, string.format("Plow Factor: %d%% | Weed Factor: %d%% | Stubble Factor: %d%% | Roller Factor: %d%%", debugValues.plowFactor * 100, debugValues.weedFactor * 100, debugValues.stubbleFactor * 100, debugValues.rollerFactor * 100))
		renderText(0.01, 0.32, 0.015, string.format("Yield: %d%% | Regular Yield: %d%%", debugValues.yieldFactor * debugValues.yieldPotential / 2 * 100, debugValues.yieldFactorRegular * debugValues.yieldPotential / 2 * 100))
		nitrogenMap:drawYieldDebug(debugValues.nActualValue, debugValues.nTargetValue)
		pHMap:drawYieldDebug(debugValues.pHActualValue, debugValues.pHTargetValue)
	end
end

function HarvestExtension:onUnloadingStationsChanged()
	self.unloadingStations = g_currentMission.storageSystem:getUnloadingStations()
end

function HarvestExtension:getYieldFromArea(combine, cutter, inputFruitType, realArea)
	local pixelToSqm = g_currentMission:getFruitPixelsToSqm()
	local literPerSqm = 1

	if inputFruitType ~= FruitType.UNKNOWN then
		local fruitDesc = g_fruitTypeManager:getFruitTypeByIndex(inputFruitType)
		literPerSqm = fruitDesc.literPerSqm
	end

	local sqm = realArea * pixelToSqm
	local yield = sqm * literPerSqm * combine.spec_combine.threshingScale
	local farmId = cutter:getLastTouchedFarmlandFarmId()

	if farmId ~= AccessHandler.EVERYONE then
		local damage = combine:getVehicleDamage()

		if damage > 0 then
			yield = yield * (1 - damage * Combine.DAMAGED_YIELD_REDUCTION)
		end
	end

	return yield
end

function HarvestExtension:getBestPriceForFillType(fillType)
	if self.unloadingStations == nil then
		self.unloadingStations = g_currentMission.storageSystem:getUnloadingStations()
	end

	local maxPrice = 0

	for _, unloadingStation in pairs(self.unloadingStations) do
		if unloadingStation.getEffectiveFillTypePrice ~= nil and unloadingStation:getIsFillTypeAllowed(fillType.index) and (unloadingStation.getAppearsOnStats == nil or unloadingStation:getAppearsOnStats()) then
			maxPrice = math.max(maxPrice, unloadingStation:getEffectiveFillTypePrice(fillType.index, ToolType.UNDEFINED))
		end
	end

	if maxPrice == 0 then
		maxPrice = fillType.pricePerLiter or 0
	end

	return maxPrice
end

function HarvestExtension:updateLatestFactors(pfModule, vehicle, requiresPHFactorUpdate, requiresNFactorUpdate)
	local nFactor = vehicle.lastNFactor or 0
	local regularNFactor = vehicle.lastRegularNFactor or 0
	local currentYieldPotential = vehicle.lastYieldPotential or 1

	if requiresNFactorUpdate then
		local nActualValue, nTargetValue, yieldPotential, nRegularValue, lastIgnoreOverfertilization = pfModule.nitrogenMap:updateLastNitrogenValues()

		if nActualValue > -1 and nTargetValue > -1 then
			nFactor = pfModule.nitrogenMap:getYieldFactorByLevelDifference(nActualValue - nTargetValue, lastIgnoreOverfertilization)
			vehicle.lastNFactor = nFactor
			vehicle.lastYieldPotential = yieldPotential
			currentYieldPotential = yieldPotential
			regularNFactor = pfModule.nitrogenMap:getYieldFactorByLevelDifference(nRegularValue - nTargetValue, lastIgnoreOverfertilization)
			vehicle.lastRegularNFactor = regularNFactor
			vehicle.lastNActualValue = nActualValue
			vehicle.lastNTargetValue = nTargetValue
			vehicle.lastIgnoreOverfertilization = lastIgnoreOverfertilization

			if HarvestExtension.YIELD_DEBUG then
				local debugValues = self.debugValues
				debugValues.nActualValue = nActualValue
				debugValues.nTargetValue = nTargetValue
				debugValues.yieldPotential = yieldPotential
				debugValues.nRegularValue = nRegularValue
				debugValues.ignoreOverfertilization = lastIgnoreOverfertilization
				debugValues.nFactor = nFactor
				debugValues.regularNFactor = regularNFactor
			end
		end
	end

	local pHFactor = vehicle.lastPHFactor or 0
	local regularPHFactor = vehicle.lastRegularPHFactor or 0

	if requiresPHFactorUpdate then
		local pHActualValue, pHTargetValue, pHRegularValue = pfModule.pHMap:updateLastPhValues()

		if pHActualValue > -1 and pHTargetValue > -1 and pHRegularValue > -1 then
			pHFactor = pfModule.pHMap:getYieldFactorByLevelDifference(pHActualValue - pHTargetValue)
			vehicle.lastPHFactor = pHFactor
			regularPHFactor = pfModule.pHMap:getYieldFactorByLevelDifference(pHRegularValue - pHTargetValue)
			vehicle.lastRegularPHFactor = regularPHFactor
			vehicle.lastPHActualValue = pHActualValue
			vehicle.lastPHTargetValue = pHTargetValue

			if HarvestExtension.YIELD_DEBUG then
				local debugValues = self.debugValues
				debugValues.pHFactor = pHFactor
				debugValues.regularPHFactor = regularPHFactor
				debugValues.pHActualValue = pHActualValue
				debugValues.pHTargetValue = pHTargetValue
				debugValues.pHRegularValue = pHRegularValue
			end
		end
	end

	local seedRateYieldFactor, lastSeedRateFound, lastSeedRateTarget = pfModule.seedRateMap:updateLastYieldValues()
	seedRateYieldFactor = seedRateYieldFactor or vehicle.lastSeedRateMultiplier or 1

	if seedRateYieldFactor ~= nil then
		currentYieldPotential = currentYieldPotential * seedRateYieldFactor
		vehicle.lastSeedRateMultiplier = seedRateYieldFactor

		if HarvestExtension.YIELD_DEBUG then
			local debugValues = self.debugValues
			debugValues.seedRateYieldFactor = seedRateYieldFactor
			debugValues.lastSeedRateFound = lastSeedRateFound or debugValues.lastSeedRateFound
			debugValues.lastSeedRateTarget = lastSeedRateTarget or debugValues.lastSeedRateTarget
		end
	end

	return nFactor, math.min(regularNFactor, nFactor), currentYieldPotential, pHFactor, math.min(regularPHFactor, pHFactor)
end

function HarvestExtension:preProcessMowerArea(vehicle, workArea, dt)
	local specMower = vehicle.spec_mower
	local pfModule = g_precisionFarming
	local xs, zs, xw, zw, xh, zh, _ = nil
	local requiresPHFactorUpdate = false
	local requiresNFactorUpdate = false
	xs, _, zs = getWorldTranslation(workArea.start)
	xw, _, zw = getWorldTranslation(workArea.width)
	xh, _, zh = getWorldTranslation(workArea.height)

	if specMower.pfFruitTypeConverters == nil then
		specMower.pfFruitTypeConverters = {}

		for fruitTypeIndex, _ in pairs(specMower.fruitTypeConverters) do
			table.insert(specMower.pfFruitTypeConverters, fruitTypeIndex)
		end
	end

	local phMapUpdated, nMapUpdated = pfModule.coverMap:updateCoverArea(specMower.pfFruitTypeConverters, xs, zs, xw, zw, xh, zh)
	requiresPHFactorUpdate = requiresPHFactorUpdate or phMapUpdated
	requiresNFactorUpdate = requiresNFactorUpdate or nMapUpdated

	if pfModule:getIsMaizePlusActive() then
		phMapUpdated, nMapUpdated = pfModule.coverMap:updateCoverArea(specMower.pfFruitTypeConverters, xs, zs, xw, zw, xh, zh, true)
		requiresPHFactorUpdate = requiresPHFactorUpdate or phMapUpdated
		requiresNFactorUpdate = requiresNFactorUpdate or nMapUpdated
	end

	local nFactor, regularNFactor, currentYieldPotential, pHFactor, regularPHFactor = self:updateLatestFactors(pfModule, vehicle, requiresPHFactorUpdate, requiresNFactorUpdate)
	self.replaceMowerMultiplierCurrentYieldPotential = currentYieldPotential
	self.replaceMowerMultiplierNFactor = nFactor
	self.replaceMowerMultiplierRegularNFactor = regularNFactor
	self.replaceMowerMultiplierPHFactor = pHFactor
	self.replaceMowerMultiplierRegularPHFactor = regularPHFactor
	self.replaceMowerMultiplier = true
end

function HarvestExtension:postProcessMowerArea(vehicle, workArea, dt, lastRealArea)
	local specMower = vehicle.spec_mower
	self.replaceMowerMultiplier = false
	local pfModule = g_precisionFarming
	local xs, zs, xw, zw, xh, zh, _ = nil
	xs, _, zs = getWorldTranslation(workArea.start)
	xw, _, zw = getWorldTranslation(workArea.width)
	xh, _, zh = getWorldTranslation(workArea.height)
	local farmlandId = g_farmlandManager:getFarmlandIdAtWorldPosition((xs + xw) * 0.5, (zs + zw) * 0.5)
	local mission = g_missionManager:getMissionAtWorldPosition(xs, zs) or g_missionManager:getMissionAtWorldPosition(xw, zw) or g_missionManager:getMissionAtWorldPosition(xh, zh)

	self:setLastScoringValues(lastRealArea, farmlandId, vehicle.lastNActualValue, vehicle.lastNTargetValue, vehicle.lastPHActualValue, vehicle.lastPHTargetValue, vehicle.lastIgnoreOverfertilization)

	if lastRealArea > 0 and self.replaceMowerNewMultiplier ~= nil and self.replaceMowerRegularMultiplier ~= nil and mission == nil then
		local rawPickupLiters = workArea.lastPickupLiters / self.replaceMowerNewMultiplier
		local regularPickupLiters = rawPickupLiters * self.replaceMowerRegularMultiplier
		local fillTypeIndex = nil
		local dropArea = vehicle:getDropArea(workArea)

		if dropArea ~= nil then
			fillTypeIndex = dropArea.fillType
		elseif specMower.fillUnitIndex ~= nil then
			fillTypeIndex = vehicle:getFillUnitFillType(specMower.fillUnitIndex)
		end

		if fillTypeIndex ~= nil and fillTypeIndex ~= FillType.UNKNOWN then
			if pfModule.yieldMap ~= nil then
				pfModule.yieldMap:setAreaYield(xs, zs, xw, zw, xh, zh, self.replaceMowerRegularMultiplier)
			end

			if HarvestExtension.YIELD_DEBUG then
				local debugValues = self.debugValues
				debugValues.yieldFactor = self.replaceMowerNewMultiplier
				debugValues.yieldFactorRegular = self.replaceMowerRegularMultiplier
			end

			local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
			local pickupWeight = workArea.lastPickupLiters * fillType.massPerLiter / FillTypeManager.MASS_SCALE
			local farmlandStatistics, _, _ = vehicle:getPFStatisticInfo()

			if farmlandStatistics ~= nil and farmlandId ~= nil then
				farmlandStatistics:updateStatistic(farmlandId, "yield", workArea.lastPickupLiters)
				farmlandStatistics:updateStatistic(farmlandId, "yieldWeight", pickupWeight)
				farmlandStatistics:updateStatistic(farmlandId, "yieldRegular", regularPickupLiters)

				local maxPrice = self:getBestPriceForFillType(fillType)

				farmlandStatistics:updateStatistic(farmlandId, "yieldBestPrice", maxPrice * workArea.lastPickupLiters)
			end
		end
	end
end

function HarvestExtension:setLastScoringValues(area, farmlandId, nActual, nTarget, pHActual, pHTarget, ignoreOverfertilization)
end

function HarvestExtension:overwriteGameFunctions(pfModule)
	pfModule:overwriteGameFunction(Cutter, "processCutterArea", function (superFunc, vehicle, workArea, dt)
		local specCutter = vehicle.spec_cutter
		local combine = specCutter.workAreaParameters.combineVehicle
		local xs, zs, xw, zw, xh, zh, _, farmlandId, mission = nil
		local requiresPHFactorUpdate = false
		local requiresNFactorUpdate = false

		if combine ~= nil then
			xs, _, zs = getWorldTranslation(workArea.start)
			xw, _, zw = getWorldTranslation(workArea.width)
			xh, _, zh = getWorldTranslation(workArea.height)
			local phMapUpdated, nMapUpdated = pfModule.coverMap:updateCoverArea(specCutter.workAreaParameters.fruitTypesToUse, xs, zs, xw, zw, xh, zh, specCutter.allowsForageGrowthState)
			requiresPHFactorUpdate = requiresPHFactorUpdate or phMapUpdated
			requiresNFactorUpdate = requiresNFactorUpdate or nMapUpdated
			farmlandId = g_farmlandManager:getFarmlandIdAtWorldPosition((xs + xw) * 0.5, (zs + zw) * 0.5)
			mission = g_missionManager:getMissionAtWorldPosition(xs, zs) or g_missionManager:getMissionAtWorldPosition(xw, zw) or g_missionManager:getMissionAtWorldPosition(xh, zh)
		end

		local nFactor, regularNFactor, currentYieldPotential, pHFactor, regularPHFactor = self:updateLatestFactors(pfModule, vehicle, requiresPHFactorUpdate, requiresNFactorUpdate)
		self.checkMultiplier = true
		local lastRealArea, lastArea = superFunc(vehicle, workArea, dt)
		self.checkMultiplier = false

		self:setLastScoringValues(lastRealArea, farmlandId, vehicle.lastNActualValue, vehicle.lastNTargetValue, vehicle.lastPHActualValue, vehicle.lastPHTargetValue, vehicle.lastIgnoreOverfertilization)

		if lastRealArea > 0 and self.lastMultiplier ~= nil and combine ~= nil and mission == nil then
			if vehicle.smoothedYieldFactor == nil then
				vehicle.smoothedYieldFactor = 0
			end

			vehicle.smoothedYieldFactor = vehicle.smoothedYieldFactor * 0.95 + self.lastWeedFactor * 0.05
			self.lastWeedFactor = vehicle.smoothedYieldFactor
			local inputFruitType = specCutter.workAreaParameters.lastFruitType
			lastRealArea = lastRealArea / self.lastMultiplier
			lastRealArea = lastRealArea * 1.05
			local defaultMultipliers = 0
			defaultMultipliers = defaultMultipliers + self.lastPlowFactor * 0.1
			defaultMultipliers = defaultMultipliers + self.lastWeedFactor * 0.15
			defaultMultipliers = defaultMultipliers + self.lastStubbleFactor * 0.025
			defaultMultipliers = defaultMultipliers + self.lastRollerFactor * 0.025
			local multiplier = 1
			multiplier = multiplier + nFactor * 0.5
			multiplier = multiplier + pHFactor * 0.2
			multiplier = multiplier + defaultMultipliers
			local regularMultiplier = 1
			regularMultiplier = regularMultiplier + regularNFactor * 0.5
			regularMultiplier = regularMultiplier + regularPHFactor * 0.2
			regularMultiplier = regularMultiplier + defaultMultipliers
			local regularRealArea = lastRealArea * regularMultiplier * currentYieldPotential
			specCutter.workAreaParameters.lastRealArea = lastRealArea * multiplier * currentYieldPotential

			if pfModule.yieldMap ~= nil then
				pfModule.yieldMap:setAreaYield(xs, zs, xw, zw, xh, zh, multiplier * currentYieldPotential)
			end

			if HarvestExtension.YIELD_DEBUG then
				local debugValues = self.debugValues
				debugValues.yieldFactor = multiplier
				debugValues.yieldFactorRegular = regularMultiplier
				debugValues.plowFactor = self.lastPlowFactor
				debugValues.weedFactor = self.lastWeedFactor
				debugValues.stubbleFactor = self.lastStubbleFactor
				debugValues.rollerFactor = self.lastRollerFactor
			end

			local fillTypeIndex = g_fruitTypeManager:getFillTypeIndexByFruitTypeIndex(inputFruitType)
			local conversionFactor = 1

			if specCutter.fruitTypeConverters[inputFruitType] ~= nil then
				fillTypeIndex = specCutter.fruitTypeConverters[inputFruitType].fillTypeIndex
				conversionFactor = specCutter.fruitTypeConverters[inputFruitType].conversionFactor
			end

			local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
			local yield = self:getYieldFromArea(combine, vehicle, inputFruitType, specCutter.workAreaParameters.lastRealArea) * conversionFactor
			local yieldWeight = yield * fillType.massPerLiter / FillTypeManager.MASS_SCALE
			local regularYield = self:getYieldFromArea(combine, vehicle, inputFruitType, regularRealArea) * conversionFactor
			local farmlandStatistics, _, _ = vehicle:getPFStatisticInfo()

			if farmlandStatistics ~= nil and farmlandId ~= nil then
				farmlandStatistics:updateStatistic(farmlandId, "yield", yield)
				farmlandStatistics:updateStatistic(farmlandId, "yieldWeight", yieldWeight)
				farmlandStatistics:updateStatistic(farmlandId, "yieldRegular", regularYield)

				local maxPrice = self:getBestPriceForFillType(fillType)

				farmlandStatistics:updateStatistic(farmlandId, "yieldBestPrice", maxPrice * yield)
			end
		end

		self.lastMultiplier = nil
		self.lastPlowFactor = nil
		self.lastWeedFactor = nil
		self.lastStubbleFactor = nil
		self.lastRollerFactor = nil

		return lastRealArea, lastArea
	end)
	pfModule:overwriteGameFunction(FSBaseMission, "getHarvestScaleMultiplier", function (superFunc, mission, fruitTypeIndex, sprayFactor, plowFactor, limeFactor, weedFactor, stubbleFactor, rollerFactor, beeYieldBonusPercentage)
		local multiplier = superFunc(mission, fruitTypeIndex, sprayFactor, plowFactor, limeFactor, weedFactor, stubbleFactor, rollerFactor, beeYieldBonusPercentage)

		if self.checkMultiplier then
			self.lastMultiplier = multiplier
			self.lastPlowFactor = plowFactor
			self.lastWeedFactor = weedFactor
			self.lastStubbleFactor = stubbleFactor
			self.lastRollerFactor = rollerFactor
		end

		if self.replaceMowerMultiplier then
			multiplier = 1
			multiplier = multiplier + plowFactor * 0.1
			multiplier = multiplier + weedFactor * 0.15
			multiplier = multiplier + stubbleFactor * 0.025
			multiplier = multiplier + rollerFactor * 0.025
			multiplier = multiplier + self.replaceMowerMultiplierRegularNFactor * 0.5
			multiplier = multiplier + self.replaceMowerMultiplierRegularPHFactor * 0.2
			multiplier = multiplier * self.replaceMowerMultiplierCurrentYieldPotential
			self.replaceMowerRegularMultiplier = multiplier
			multiplier = 1
			multiplier = multiplier + plowFactor * 0.1
			multiplier = multiplier + weedFactor * 0.15
			multiplier = multiplier + stubbleFactor * 0.025
			multiplier = multiplier + rollerFactor * 0.025
			multiplier = multiplier + self.replaceMowerMultiplierNFactor * 0.5
			multiplier = multiplier + self.replaceMowerMultiplierPHFactor * 0.2
			multiplier = multiplier * self.replaceMowerMultiplierCurrentYieldPotential
			self.replaceMowerNewMultiplier = multiplier
		end

		return multiplier
	end)
	pfModule:overwriteGameFunction(FSDensityMapUtil, "updateDestroyCommonArea", function (superFunc, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, limitToField, addFertilizerLock)
		pfModule.nitrogenMap:updateDestroyCommonArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
		superFunc(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, limitToField, addFertilizerLock)
		pfModule.nitrogenMap:postUpdateDestroyCommonArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
	end)
	pfModule:overwriteGameFunction(FSDensityMapUtil, "updateDiscHarrowArea", function (superFunc, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, createField, limitFruitDestructionToField, angle, blockedSprayTypeIndex)
		pfModule.nitrogenMap:updateDestroyCommonArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)

		local changedArea, totalArea = superFunc(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, createField, limitFruitDestructionToField, angle, blockedSprayTypeIndex)

		pfModule.nitrogenMap:postUpdateDestroyCommonArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)

		return changedArea, totalArea
	end)
	pfModule:overwriteGameFunction(FSDensityMapUtil, "updateDirectSowingArea", function (superFunc, fruitIndex, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, fieldGroundType, angle, growthState, blockedSprayTypeIndex)
		pfModule.nitrogenMap:updateDestroyCommonArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)

		local changedArea, totalArea = superFunc(fruitIndex, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, fieldGroundType, angle, growthState, blockedSprayTypeIndex)

		pfModule.nitrogenMap:postUpdateDestroyCommonArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)

		return changedArea, totalArea
	end)
	pfModule:overwriteGameFunction(FSDensityMapUtil, "getWeedFactor", function (superFunc, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, fruitIndex)
		local weedFactor = superFunc(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, fruitIndex)

		return weedFactor > 0 and 1 or 0
	end)
end
