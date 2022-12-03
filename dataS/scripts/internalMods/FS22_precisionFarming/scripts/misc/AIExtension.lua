AIExtension = {
	MOD_NAME = g_currentModName
}
local AIExtension_mt = Class(AIExtension)

function AIExtension.new(customMt)
	local self = setmetatable({}, customMt or AIExtension_mt)
	self.rtkStations = {}
	self.preciseModeActive = false

	return self
end

function AIExtension:loadFromXML(xmlFile, key, baseDirectory, configFileName, mapFilename)
	return true
end

function AIExtension:delete()
	self:setPreciseModeActive(false)
end

function AIExtension:overwriteGameFunctions(pfModule)
	pfModule:overwriteGameFunction(AIDriveStrategyStraight, "getDriveStraightData", function (superFunc, self, dt, vX, vY, vZ, distanceToTurn, distanceToEndOfField)
		local tX, tZ, allowedToDrive, maxSpeed, distanceToTurn = superFunc(self, dt, vX, vY, vZ, distanceToTurn, distanceToEndOfField)

		if not pfModule.aiExtension.preciseModeActive then
			self.randomLineOffset = self.randomLineOffset or 0

			if self.randomLineOffset ~= nil then
				self.randomLineOffset = self.randomLineOffset + dt
				local t = self.randomLineOffset / 2500
				local offsetPct = math.sin(t) * math.sin((t + 2) * 0.3) * 0.8 + math.cos(t * 5) * 0.2
				local offsetDistance = offsetPct * 0.15
				local dirX = self.vehicle.aiDriveDirection[1]
				local dirZ = self.vehicle.aiDriveDirection[2]
				local sideDirX = -dirZ
				local sideDirY = dirX
				tZ = tZ + sideDirY * offsetDistance
				tX = tX + sideDirX * offsetDistance
			end
		end

		return tX, tZ, allowedToDrive, maxSpeed, distanceToTurn
	end)
	pfModule:overwriteGameFunction(Sprayer, "setSprayerAITerrainDetailProhibitedRange", function (superFunc, vehicle, fillType)
		if vehicle:getUseSprayerAIRequirements() and vehicle.addAITerrainDetailProhibitedRange ~= nil then
			vehicle:clearAITerrainDetailProhibitedRange()
			vehicle:clearAIFruitRequirements()
			vehicle:clearAIFruitProhibitions()

			local sprayTypeDesc = g_sprayTypeManager:getSprayTypeByFillTypeIndex(fillType)

			if sprayTypeDesc ~= nil then
				if sprayTypeDesc.isHerbicide then
					local weedSystem = g_currentMission.weedSystem

					if weedSystem ~= nil then
						local weedMapId, weedFirstChannel, weedNumChannels = weedSystem:getDensityMapData()
						local replacementData = weedSystem:getHerbicideReplacements()

						if replacementData.weed ~= nil then
							local startState = -1
							local lastState = -1

							for sourceState, targetState in pairs(replacementData.weed.replacements) do
								if startState == -1 then
									startState = sourceState
								elseif sourceState ~= lastState + 1 then
									vehicle:addAIFruitRequirement(nil, startState, lastState, weedMapId, weedFirstChannel, weedNumChannels)

									startState = sourceState
								end

								lastState = sourceState
							end

							if startState ~= -1 then
								vehicle:addAIFruitRequirement(nil, startState, lastState, weedMapId, weedFirstChannel, weedNumChannels)
							end
						end
					end
				else
					local fieldGroundSystem = g_currentMission.fieldGroundSystem
					local _, sprayTypeFirstChannel, sprayTypeNumChannels = fieldGroundSystem:getDensityMapData(FieldDensityMap.SPRAY_TYPE)

					vehicle:addAITerrainDetailProhibitedRange(sprayTypeDesc.sprayGroundType, sprayTypeDesc.sprayGroundType, sprayTypeFirstChannel, sprayTypeNumChannels)
				end

				if sprayTypeDesc.isHerbicide or sprayTypeDesc.isFertilizer then
					for index, fruitType in pairs(g_fruitTypeManager:getFruitTypes()) do
						if fruitType.name:lower() ~= "grass" and fruitType.minHarvestingGrowthState ~= nil and fruitType.maxHarvestingGrowthState ~= nil and fruitType.weed == nil then
							vehicle:addAIFruitProhibitions(fruitType.index, fruitType.minHarvestingGrowthState, fruitType.maxHarvestingGrowthState)
						end
					end
				end
			end
		end
	end)
end

function AIExtension:setPreciseModeActive(state)
	self.preciseModeActive = state

	if state then
		AIVehicleUtil.AREA_OVERLAP = -0.175
	else
		AIVehicleUtil.AREA_OVERLAP = 0.26
	end
end

function AIExtension:registerRTKStation(station)
	self.rtkStations[station] = station

	self:setPreciseModeActive(true)
end

function AIExtension:unregisterRTKStation(station)
	self.rtkStations[station] = nil

	self:setPreciseModeActive(next(self.rtkStations) ~= nil)
end
