EnvironmentalScoreTillage = {
	TYPE_NONE = 0,
	TYPE_DEEP_CULTIVATION = 1,
	TYPE_FLAT_CULTIVATION = 2,
	TYPE_DIRECT_PLANTING = 3
}
local EnvironmentalScoreTillage_mt = Class(EnvironmentalScoreTillage, EnvironmentalScoreValue)

function EnvironmentalScoreTillage.new(pfModule, customMt)
	local self = EnvironmentalScoreValue.new(pfModule, customMt or EnvironmentalScoreTillage_mt)
	self.xmlKey = "tillage"
	self.typeWeights = {
		[EnvironmentalScoreTillage.TYPE_NONE] = 0.5,
		[EnvironmentalScoreTillage.TYPE_DEEP_CULTIVATION] = 0,
		[EnvironmentalScoreTillage.TYPE_FLAT_CULTIVATION] = 0.5,
		[EnvironmentalScoreTillage.TYPE_DIRECT_PLANTING] = 1
	}

	return self
end

function EnvironmentalScoreTillage:loadFromXML(xmlFile, key, baseDirectory, configFileName, mapFilename)
	if not EnvironmentalScoreTillage:superClass().loadFromXML(self, xmlFile, key, baseDirectory, configFileName, mapFilename) then
		return false
	end

	return true
end

function EnvironmentalScoreTillage:update(dt)
end

function EnvironmentalScoreTillage:getScore(farmlandId)
	local farmlandData = self:getFarmlandData(farmlandId)

	if farmlandData.clientScore ~= nil then
		return farmlandData.clientScore
	end

	local scorePct = 0

	if farmlandData.totalFieldArea > 0 then
		for i = 0, #farmlandData.workedAreaByType do
			scorePct = scorePct + math.min(farmlandData.workedAreaByType[i] / farmlandData.totalFieldArea, 1) * self.typeWeights[i]
		end
	else
		scorePct = self.typeWeights[EnvironmentalScoreTillage.TYPE_NONE]
	end

	return math.min(scorePct, 1)
end

function EnvironmentalScoreTillage:initFarmlandData()
	return {
		totalFieldArea = 0,
		workedAreaByType = {
			[EnvironmentalScoreTillage.TYPE_NONE] = math.huge,
			[EnvironmentalScoreTillage.TYPE_DEEP_CULTIVATION] = 0,
			[EnvironmentalScoreTillage.TYPE_FLAT_CULTIVATION] = 0,
			[EnvironmentalScoreTillage.TYPE_DIRECT_PLANTING] = 0
		}
	}
end

function EnvironmentalScoreTillage:loadFarmlandData(data, xmlFile, key)
	data.totalFieldArea = xmlFile:getFloat(key .. "#totalFieldArea", data.totalFieldArea)
	data.workedAreaByType[EnvironmentalScoreTillage.TYPE_NONE] = xmlFile:getFloat(key .. "#workedAreaNone", data.workedAreaByType[EnvironmentalScoreTillage.TYPE_NONE])
	data.workedAreaByType[EnvironmentalScoreTillage.TYPE_DEEP_CULTIVATION] = xmlFile:getFloat(key .. "#workedAreaDeep", data.workedAreaByType[EnvironmentalScoreTillage.TYPE_DEEP_CULTIVATION])
	data.workedAreaByType[EnvironmentalScoreTillage.TYPE_FLAT_CULTIVATION] = xmlFile:getFloat(key .. "#workedAreaFlat", data.workedAreaByType[EnvironmentalScoreTillage.TYPE_FLAT_CULTIVATION])
	data.workedAreaByType[EnvironmentalScoreTillage.TYPE_DIRECT_PLANTING] = xmlFile:getFloat(key .. "#workedAreaDirect", data.workedAreaByType[EnvironmentalScoreTillage.TYPE_DIRECT_PLANTING])
end

function EnvironmentalScoreTillage:saveFarmlandData(data, xmlFile, key)
	if data.workedAreaByType[EnvironmentalScoreTillage.TYPE_NONE] ~= math.huge then
		xmlFile:setFloat(key .. "#totalFieldArea", data.totalFieldArea)
		xmlFile:setFloat(key .. "#workedAreaNone", data.workedAreaByType[EnvironmentalScoreTillage.TYPE_NONE])
		xmlFile:setFloat(key .. "#workedAreaDeep", data.workedAreaByType[EnvironmentalScoreTillage.TYPE_DEEP_CULTIVATION])
		xmlFile:setFloat(key .. "#workedAreaFlat", data.workedAreaByType[EnvironmentalScoreTillage.TYPE_FLAT_CULTIVATION])
		xmlFile:setFloat(key .. "#workedAreaDirect", data.workedAreaByType[EnvironmentalScoreTillage.TYPE_DIRECT_PLANTING])
	end
end

function EnvironmentalScoreTillage:readFarmlandDataFromStream(data, streamId, connection)
	local score = MathUtil.round(streamReadUIntN(streamId, 8) / 255, 2)
	data.clientScore = score
end

function EnvironmentalScoreTillage:writeFarmlandDataToStream(data, streamId, connection)
	local score = self:getScore(data.farmlandId)

	streamWriteUIntN(streamId, score * 255, 8)
end

function EnvironmentalScoreTillage:addWorkedArea(farmlandId, area, type)
	local farmlandData = self:getFarmlandData(farmlandId)

	if farmlandData.workedAreaByType[EnvironmentalScoreTillage.TYPE_NONE] == math.huge then
		local farmland = g_farmlandManager:getFarmlandById(farmlandId)

		if farmland ~= nil and farmland.totalFieldArea ~= nil then
			farmlandData.totalFieldArea = farmland.totalFieldArea * 10000
			farmlandData.workedAreaByType[EnvironmentalScoreTillage.TYPE_NONE] = farmlandData.totalFieldArea
		end
	end

	local changedHa = MathUtil.areaToHa(area, g_currentMission:getFruitPixelsToSqm()) * 10000
	local toRemove = changedHa

	while toRemove > 0 do
		local changed = false

		for i = 0, #farmlandData.workedAreaByType - 1 do
			if i ~= type and farmlandData.workedAreaByType[i] > 0 and toRemove > 0 then
				local change = changedHa / (#farmlandData.workedAreaByType - 1)
				farmlandData.workedAreaByType[i] = math.max(farmlandData.workedAreaByType[i] - change, 0)
				toRemove = toRemove - change
				changed = true
			end
		end

		if not changed then
			break
		end
	end

	if toRemove > 0 then
		farmlandData.workedAreaByType[type] = farmlandData.workedAreaByType[type] - toRemove
	end

	farmlandData.workedAreaByType[type] = farmlandData.workedAreaByType[type] + changedHa
end

function EnvironmentalScoreTillage:overwriteGameFunctions(pfModule)
	if g_server ~= nil then
		pfModule:overwriteGameFunction(Cultivator, "processCultivatorArea", function (superFunc, vehicle, ...)
			local realArea, area = superFunc(vehicle, ...)

			if realArea > 0 and vehicle.getPFStatisticInfo ~= nil then
				local _, _, farmlandId = vehicle:getPFStatisticInfo()

				if farmlandId ~= nil then
					self:addWorkedArea(farmlandId, realArea, vehicle.spec_cultivator.useDeepMode and EnvironmentalScoreTillage.TYPE_DEEP_CULTIVATION or EnvironmentalScoreTillage.TYPE_FLAT_CULTIVATION)
				end
			end

			return realArea, area
		end)
		pfModule:overwriteGameFunction(SowingMachine, "processSowingMachineArea", function (superFunc, vehicle, ...)
			local realArea, area = superFunc(vehicle, ...)

			if realArea > 0 and vehicle.getPFStatisticInfo ~= nil then
				local _, _, farmlandId = vehicle:getPFStatisticInfo()

				if farmlandId ~= nil and vehicle.spec_sowingMachine.useDirectPlanting then
					self:addWorkedArea(farmlandId, realArea, EnvironmentalScoreTillage.TYPE_DIRECT_PLANTING)
				end
			end

			return realArea, area
		end)
		pfModule:overwriteGameFunction(FertilizingSowingMachine, "processSowingMachineArea", function (superFunc, vehicle, ...)
			local realArea, area = superFunc(vehicle, ...)

			if realArea > 0 and vehicle.getPFStatisticInfo ~= nil then
				local _, _, farmlandId = vehicle:getPFStatisticInfo()

				if farmlandId ~= nil and vehicle.spec_sowingMachine.useDirectPlanting then
					self:addWorkedArea(farmlandId, realArea, EnvironmentalScoreTillage.TYPE_DIRECT_PLANTING)
				end
			end

			return realArea, area
		end)
	end
end
