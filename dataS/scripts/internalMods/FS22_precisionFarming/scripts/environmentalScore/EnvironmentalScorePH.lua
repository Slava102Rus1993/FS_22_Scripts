EnvironmentalScorePH = {
	COMPRESSION = 1000
}
local EnvironmentalScorePH_mt = Class(EnvironmentalScorePH, EnvironmentalScoreValue)

function EnvironmentalScorePH.new(pfModule, customMt)
	local self = EnvironmentalScoreValue.new(pfModule, customMt or EnvironmentalScorePH_mt)
	self.xmlKey = "ph"

	return self
end

function EnvironmentalScorePH:loadFromXML(xmlFile, key, baseDirectory, configFileName, mapFilename)
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

		local phOffset = getXMLFloat(xmlFile, baseKey .. "#phOffset") or 0
		local score = getXMLFloat(xmlFile, baseKey .. "#score") or 0
		local pHMap = g_precisionFarming.pHMap

		if pHMap ~= nil then
			phOffset = phOffset / pHMap:getPhValueFromChangedStates(1)
		end

		self.scoreCurve:addKeyframe({
			score,
			time = phOffset
		})

		i = i + 1
	end

	return true
end

function EnvironmentalScorePH:update(dt)
end

function EnvironmentalScorePH:getScore(farmlandId)
	local farmlandData = self:getFarmlandData(farmlandId)

	if farmlandData.clientScore ~= nil then
		return farmlandData.clientScore
	end

	if farmlandData.harvestedArea > 0 then
		local averageOffset = farmlandData.phOffsetSum / farmlandData.harvestedArea * EnvironmentalScorePH.COMPRESSION

		return self.scoreCurve:get(averageOffset)
	end

	return 0.5
end

function EnvironmentalScorePH:initFarmlandData()
	return {
		phOffsetSum = 0,
		pendingReset = false,
		harvestedArea = 0
	}
end

function EnvironmentalScorePH:loadFarmlandData(data, xmlFile, key)
	data.harvestedArea = xmlFile:getFloat(key .. "#harvestedArea", data.harvestedArea)
	data.phOffsetSum = xmlFile:getFloat(key .. "#phOffsetSum", data.phOffsetSum)
	data.pendingReset = xmlFile:getBool(key .. "#pendingReset", data.pendingReset)
end

function EnvironmentalScorePH:saveFarmlandData(data, xmlFile, key)
	xmlFile:setFloat(key .. "#harvestedArea", data.harvestedArea)
	xmlFile:setFloat(key .. "#phOffsetSum", data.phOffsetSum)
	xmlFile:setBool(key .. "#pendingReset", data.pendingReset)
end

function EnvironmentalScorePH:readFarmlandDataFromStream(data, streamId, connection)
	local score = MathUtil.round(streamReadUIntN(streamId, 8) / 255, 2)
	data.clientScore = score
end

function EnvironmentalScorePH:writeFarmlandDataToStream(data, streamId, connection)
	local score = self:getScore(data.farmlandId)

	streamWriteUIntN(streamId, score * 255, 8)
end

function EnvironmentalScorePH:onHarvestScoreReset(farmlandId)
	local farmlandData = self:getFarmlandData(farmlandId)
	farmlandData.pendingReset = true
end

function EnvironmentalScorePH:addWorkedArea(farmlandId, area, nOffset)
	area = area / EnvironmentalScorePH.COMPRESSION
	nOffset = nOffset / EnvironmentalScorePH.COMPRESSION
	local farmlandData = self:getFarmlandData(farmlandId)

	if farmlandData.pendingReset then
		farmlandData.harvestedArea = 0
		farmlandData.phOffsetSum = 0
		farmlandData.pendingReset = false
	end

	farmlandData.harvestedArea = farmlandData.harvestedArea + area
	farmlandData.phOffsetSum = farmlandData.phOffsetSum + area * nOffset
end

function EnvironmentalScorePH:overwriteGameFunctions(pfModule)
	if g_server ~= nil then
		pfModule:overwriteGameFunction(HarvestExtension, "setLastScoringValues", function (superFunc, harvestExtension, area, farmlandId, nActual, nTarget, pHActual, pHTarget, ignoreOverfertilization)
			superFunc(harvestExtension, area, farmlandId, nActual, nTarget, pHActual, pHTarget, ignoreOverfertilization)

			if pHActual ~= nil and pHTarget ~= nil and area > 0 and farmlandId ~= nil then
				self:addWorkedArea(farmlandId, area, pHActual - pHTarget)
			end
		end)
	end
end
