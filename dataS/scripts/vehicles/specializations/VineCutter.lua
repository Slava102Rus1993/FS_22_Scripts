VineCutter = {
	initSpecialization = function ()
		local schema = Vehicle.xmlSchema

		schema:setXMLSpecializationType("VineCutter")
		schema:register(XMLValueType.STRING, "vehicle.vineCutter#fruitType", "Fruit type")
		schema:setXMLSpecializationType()
	end,
	prerequisitesPresent = function (specializations)
		return SpecializationUtil.hasSpecialization(VineDetector, specializations)
	end
}

function VineCutter.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "getCombine", VineCutter.getCombine)
	SpecializationUtil.registerFunction(vehicleType, "harvestCallback", VineCutter.harvestCallback)
end

function VineCutter.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "doCheckSpeedLimit", VineCutter.doCheckSpeedLimit)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanStartVineDetection", VineCutter.getCanStartVineDetection)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsValidVinePlaceable", VineCutter.getIsValidVinePlaceable)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "handleVinePlaceable", VineCutter.handleVinePlaceable)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "clearCurrentVinePlaceable", VineCutter.clearCurrentVinePlaceable)
end

function VineCutter.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", VineCutter)
	SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", VineCutter)
	SpecializationUtil.registerEventListener(vehicleType, "onDraw", VineCutter)
	SpecializationUtil.registerEventListener(vehicleType, "onTurnedOff", VineCutter)
end

function VineCutter:onLoad(savegame)
	local spec = self.spec_vineCutter
	local fruitTypeName = self.xmlFile:getValue("vehicle.vineCutter#fruitType")
	local fruitType = g_fruitTypeManager:getFruitTypeByName(fruitTypeName)

	if fruitType ~= nil then
		spec.inputFruitTypeIndex = fruitType.index
	else
		spec.inputFruitTypeIndex = FruitType.GRAPE
	end

	spec.outputFillTypeIndex = g_fruitTypeManager:getFillTypeIndexByFruitTypeIndex(spec.inputFruitTypeIndex)
	spec.showFarmlandNotOwnedWarning = false
	spec.warningYouDontHaveAccessToThisLand = g_i18n:getText("warning_youDontHaveAccessToThisLand")
end

function VineCutter:onPostLoad(savegame)
	if self.addCutterToCombine ~= nil then
		self:addCutterToCombine(self)
	end
end

function VineCutter:onDraw(isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	local spec = self.spec_vineCutter

	if spec.showFarmlandNotOwnedWarning then
		g_currentMission:showBlinkingWarning(spec.warningYouDontHaveAccessToThisLand)
	end
end

function VineCutter:onTurnedOff()
	self:cancelVineDetection()

	local spec = self.spec_vineCutter

	if spec.lastHarvestingPlaceable ~= nil and spec.lastHarvestingNode ~= nil then
		spec.lastHarvestingPlaceable:setShakingFactor(spec.lastHarvestingNode, 0, 0, 0, 0)
	end

	spec.showFarmlandNotOwnedWarning = false
end

function VineCutter:getCanStartVineDetection(superFunc)
	if not superFunc(self) then
		return false
	end

	local isTurnedOn = self:getIsTurnedOn()

	if not isTurnedOn then
		return false
	end

	if self.movingDirection < 0 then
		return false
	end

	return true
end

function VineCutter:getIsValidVinePlaceable(superFunc, placeable)
	if not superFunc(self, placeable) then
		return false
	end

	local spec = self.spec_vineCutter

	if placeable:getVineFruitType() ~= spec.inputFruitTypeIndex then
		return false
	end

	return true
end

function VineCutter:handleVinePlaceable(superFunc, node, placeable, x, y, z, distance)
	local spec = self.spec_vineCutter
	spec.showFarmlandNotOwnedWarning = false

	if not superFunc(self, node, placeable, x, y, z, distance) then
		return false
	end

	local farmlandId = g_farmlandManager:getFarmlandIdAtWorldPosition(x, z)

	if farmlandId == nil then
		spec.showFarmlandNotOwnedWarning = true

		return false
	end

	if farmlandId == FarmlandManager.NOT_BUYABLE_FARM_ID then
		spec.showFarmlandNotOwnedWarning = true

		return false
	end

	local landOwner = g_farmlandManager:getFarmlandOwner(farmlandId)
	local farmId = self:getOwnerFarmId()
	local accessible = landOwner ~= 0 and g_currentMission.accessHandler:canFarmAccessOtherId(farmId, landOwner)

	if not accessible then
		spec.showFarmlandNotOwnedWarning = true

		return false
	end

	local combineVehicle, alternativeCombine, requiredFillType = self:getCombine()

	if combineVehicle == nil and requiredFillType ~= nil then
		combineVehicle = alternativeCombine
	end

	if combineVehicle == nil then
		return false
	end

	if placeable ~= nil then
		local startPosX, startPosY, startPosZ = self:getFirstVineHitPosition()
		local currentPosX, currentPosY, currentPosZ = self:getCurrentVineHitPosition()
		spec.currentCombineVehicle = combineVehicle
		spec.lastTouchedFarmlandFarmId = landOwner

		placeable:harvestVine(node, startPosX, startPosY, startPosZ, currentPosX, currentPosY, currentPosZ, self.harvestCallback, self)
		placeable:setShakingFactor(node, currentPosX, currentPosY, currentPosZ, 1)

		if spec.lastHarvestingNode ~= nil and spec.lastHarvestingNode ~= node then
			spec.lastHarvestingPlaceable:setShakingFactor(spec.lastHarvestingNode, currentPosX, currentPosY, currentPosZ, 0)
		end

		spec.lastHarvestingNode = node
		spec.lastHarvestingPlaceable = placeable

		return true
	end

	return false
end

function VineCutter:clearCurrentVinePlaceable(superFunc)
	superFunc(self)

	local spec = self.spec_vineCutter

	if spec.lastHarvestingPlaceable ~= nil and spec.lastHarvestingNode ~= nil then
		spec.lastHarvestingPlaceable:setShakingFactor(spec.lastHarvestingNode, 0, 0, 0, 0)
	end

	spec.lastHarvestingPlaceable = nil
	spec.lastHarvestingNode = nil
	spec.showFarmlandNotOwnedWarning = false
end

function VineCutter:harvestCallback(placeable, area, totalArea, weedFactor, sprayFactor, plowFactor, sectionLength)
	local spec = self.spec_vineCutter
	local limeFactor = 1
	local stubbleTillageFactor = 1
	local rollerFactor = 1
	local beeYieldBonusPerc = 0
	local multiplier = g_currentMission:getHarvestScaleMultiplier(spec.inputFruitTypeIndex, sprayFactor, plowFactor, limeFactor, weedFactor, stubbleTillageFactor, rollerFactor, beeYieldBonusPerc)
	local realArea = area * multiplier

	spec.currentCombineVehicle:addCutterArea(area, realArea, spec.inputFruitTypeIndex, spec.outputFillTypeIndex, 0, nil, spec.lastTouchedFarmlandFarmId, 1)

	local stats = g_currentMission:farmStats(spec.lastTouchedFarmlandFarmId)

	if spec.inputFruitTypeIndex == FruitType.GRAPE then
		stats:updateStats("harvestedGrapes", sectionLength)
	elseif spec.inputFruitTypeIndex == FruitType.OLIVE then
		stats:updateStats("harvestedOlives", sectionLength)
	else
		local ha = MathUtil.areaToHa(area, g_currentMission:getFruitPixelsToSqm())

		stats:updateStats("threshedHectares", ha)
		stats:updateStats("workedHectares", ha)
	end
end

function VineCutter:doCheckSpeedLimit(superFunc)
	return superFunc(self) or self:getIsTurnedOn()
end

function VineCutter:getCombine()
	local spec = self.spec_vineCutter

	if self.verifyCombine ~= nil then
		return self:verifyCombine(spec.inputFruitTypeIndex, spec.outputFillTypeIndex)
	elseif self.getAttacherVehicle ~= nil then
		local attacherVehicle = self:getAttacherVehicle()

		if attacherVehicle ~= nil and attacherVehicle.verifyCombine ~= nil then
			return attacherVehicle:verifyCombine(spec.inputFruitTypeIndex, spec.outputFillTypeIndex)
		end
	end

	return nil
end

function VineCutter.getDefaultSpeedLimit()
	return 5
end
