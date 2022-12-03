CutterDensityHeightPickupFix = {
	prerequisitesPresent = function (specializations)
		return SpecializationUtil.hasSpecialization(Cutter, specializations)
	end
}

function CutterDensityHeightPickupFix.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "processPickupCutterArea", CutterDensityHeightPickupFix.processPickupCutterArea)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getAllowCutterAIFruitRequirements", CutterDensityHeightPickupFix.getAllowCutterAIFruitRequirements)
end

function CutterDensityHeightPickupFix.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", CutterDensityHeightPickupFix)
end

function CutterDensityHeightPickupFix:onLoad(savegame)
	local spec = self.spec_cutter

	if spec.fruitTypes ~= nil then
		for _, fruitTypeIndex in ipairs(spec.fruitTypes) do
			local fillType = g_fruitTypeManager:getFillTypeIndexByFruitTypeIndex(fruitTypeIndex)

			if fillType ~= nil then
				self:setAIDensityHeightTypeRequirements(fillType)
			end
		end
	end
end

function CutterDensityHeightPickupFix:processPickupCutterArea(superFunc, workArea, dt)
	local spec = self.spec_cutter

	if spec.workAreaParameters.combineVehicle ~= nil then
		local sx, sy, sz = getWorldTranslation(workArea.start)
		local wx, wy, wz = getWorldTranslation(workArea.width)
		local hx, hy, hz = getWorldTranslation(workArea.height)
		local lsx, lsy, lsz, lex, ley, lez, lineRadius = DensityMapHeightUtil.getLineByAreaDimensions(sx, sy, sz, wx, wy, wz, hx, hy, hz)

		for _, fruitType in ipairs(spec.workAreaParameters.fruitTypesToUse) do
			local fruitDesc = g_fruitTypeManager:getFruitTypeByIndex(fruitType)
			local fillTypeIndex = g_fruitTypeManager:getWindrowFillTypeIndexByFruitTypeIndex(fruitType)

			if fillTypeIndex == nil then
				fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fruitDesc.name)
			end

			if fillTypeIndex ~= nil then
				local pickedUpLiters = -DensityMapHeightUtil.tipToGroundAroundLine(self, -math.huge, fillTypeIndex, lsx, lsy, lsz, lex, ley, lez, lineRadius, lineRadius, nil, false, nil)

				if self.isServer and pickedUpLiters > 0 then
					local literPerSqm = fruitDesc.literPerSqm
					local lastCutterArea = pickedUpLiters / (g_currentMission:getFruitPixelsToSqm() * literPerSqm)

					if fruitType ~= spec.currentInputFruitType then
						spec.currentInputFruitType = fruitType
						spec.currentOutputFillType = g_fruitTypeManager:getFillTypeIndexByFruitTypeIndex(spec.currentInputFruitType)
					end

					spec.useWindrow = true
					spec.currentInputFillType = fillTypeIndex
					spec.workAreaParameters.lastFruitType = fruitType
					spec.workAreaParameters.lastRealArea = spec.workAreaParameters.lastRealArea + lastCutterArea
					spec.workAreaParameters.lastThreshedArea = spec.workAreaParameters.lastThreshedArea + lastCutterArea
					spec.workAreaParameters.lastStatsArea = spec.workAreaParameters.lastStatsArea + lastCutterArea
					spec.workAreaParameters.lastArea = spec.workAreaParameters.lastArea + lastCutterArea
					spec.stoneLastState = FSDensityMapUtil.getStoneArea(sx, sz, wx, wz, hx, hz)
					spec.isWorking = true

					break
				end
			end
		end
	end

	return spec.workAreaParameters.lastRealArea, spec.workAreaParameters.lastArea
end

function CutterDensityHeightPickupFix:getAllowCutterAIFruitRequirements(superFunc)
	return false
end
