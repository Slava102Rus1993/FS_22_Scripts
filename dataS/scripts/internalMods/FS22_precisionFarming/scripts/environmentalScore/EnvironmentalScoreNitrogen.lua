EnvironmentalScoreNitrogen = {
	COMPRESSION = 1000
}
local EnvironmentalScoreNitrogen_mt = Class(EnvironmentalScoreNitrogen, EnvironmentalScoreValue)

function EnvironmentalScoreNitrogen.new(pfModule, customMt)
	local self = EnvironmentalScoreValue.new(pfModule, customMt or EnvironmentalScoreNitrogen_mt)
	self.xmlKey = "nitrogen"

	return self
end

function EnvironmentalScoreNitrogen:loadFromXML(xmlFile, key, baseDirectory, configFileName, mapFilename)
	if not EnvironmentalScoreTillage:superClass().loadFromXML(self, xmlFile, key, baseDirectory, configFileName, mapFilename) then
		return false
	end

	self.scoreCurve = AnimCurve.new(linearInterpolator1)
	local i = 0

	while true do
		local baseKey = string.format("%s.scoreMapping.scoreValue(%d)", key, i)

		if not hasXMLProperty(xmlFile, baseKey) then
			break
		end

		local nOffset = getXMLFloat(xmlFile, baseKey .. "#nOffset") or 0
		local score = getXMLFloat(xmlFile, baseKey .. "#score") or 0
		local nitrogenMap = g_precisionFarming.nitrogenMap

		if nitrogenMap ~= nil then
			nOffset = nOffset / nitrogenMap:getNitrogenFromChangedStates(1)
		end

		self.scoreCurve:addKeyframe({
			score,
			time = nOffset
		})

		i = i + 1
	end

	return true
end

function EnvironmentalScoreNitrogen:update(dt)
end

function EnvironmentalScoreNitrogen:getScore(farmlandId)
	local farmlandData = self:getFarmlandData(farmlandId)

	if farmlandData.clientScore ~= nil then
		return farmlandData.clientScore
	end

	if farmlandData.harvestedArea > 0 then
		local averageOffset = farmlandData.nOffsetSum / farmlandData.harvestedArea * EnvironmentalScoreNitrogen.COMPRESSION

		return self.scoreCurve:get(averageOffset)
	else
		return 0.5
	end
end

function EnvironmentalScoreNitrogen:initFarmlandData()
	return {
		nOffsetSum = 0,
		pendingReset = false,
		harvestedArea = 0
	}
end

function EnvironmentalScoreNitrogen:loadFarmlandData(data, xmlFile, key)
	data.harvestedArea = xmlFile:getFloat(key .. "#harvestedArea", data.harvestedArea)
	data.nOffsetSum = xmlFile:getFloat(key .. "#nOffsetSum", data.nOffsetSum)
	data.pendingReset = xmlFile:getBool(key .. "#pendingReset", data.pendingReset)
end

function EnvironmentalScoreNitrogen:saveFarmlandData(data, xmlFile, key)
	xmlFile:setFloat(key .. "#harvestedArea", data.harvestedArea)
	xmlFile:setFloat(key .. "#nOffsetSum", data.nOffsetSum)
	xmlFile:setBool(key .. "#pendingReset", data.pendingReset)
end

function EnvironmentalScoreNitrogen:readFarmlandDataFromStream(data, streamId, connection)
	local score = MathUtil.round(streamReadUIntN(streamId, 8) / 255, 2)
	data.clientScore = score
end

function EnvironmentalScoreNitrogen:writeFarmlandDataToStream(data, streamId, connection)
	local score = self:getScore(data.farmlandId)

	streamWriteUIntN(streamId, score * 255, 8)
end

function EnvironmentalScoreNitrogen:onHarvestScoreReset(farmlandId)
	local farmlandData = self:getFarmlandData(farmlandId)
	farmlandData.pendingReset = true
end

function EnvironmentalScoreNitrogen:addWorkedArea(farmlandId, area, nOffset)
	area = area / EnvironmentalScoreNitrogen.COMPRESSION
	nOffset = nOffset / EnvironmentalScoreNitrogen.COMPRESSION
	local farmlandData = self:getFarmlandData(farmlandId)

	if farmlandData.pendingReset then
		farmlandData.harvestedArea = 0
		farmlandData.nOffsetSum = 0
		farmlandData.pendingReset = false
	end

	farmlandData.harvestedArea = farmlandData.harvestedArea + area
	farmlandData.nOffsetSum = farmlandData.nOffsetSum + area * nOffset
end

function EnvironmentalScoreNitrogen:overwriteGameFunctions(pfModule)
	if g_server ~= nil then
		pfModule:overwriteGameFunction(HarvestExtension, "setLastScoringValues", function (superFunc, harvestExtension, area, farmlandId, nActual, nTarget, pHActual, pHTarget, ignoreOverfertilization)
			superFunc(harvestExtension, area, farmlandId, nActual, nTarget, pHActual, pHTarget, ignoreOverfertilization)

			if nActual ~= nil and nTarget ~= nil and area > 0 and farmlandId ~= nil then
				local difference = nActual - nTarget

				if ignoreOverfertilization then
					difference = math.min(difference, 0)
				end

				self:addWorkedArea(farmlandId, area, difference)
			end
		end)
	end
end
