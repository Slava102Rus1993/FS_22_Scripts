EnvironmentalScoreSoilSample = {
	TYPE_NONE = 1,
	TYPE_SAMPLED = 2
}
local EnvironmentalScoreSoilSample_mt = Class(EnvironmentalScoreSoilSample, EnvironmentalScoreValue)

function EnvironmentalScoreSoilSample.new(pfModule, customMt)
	local self = EnvironmentalScoreValue.new(pfModule, customMt or EnvironmentalScoreSoilSample_mt)
	self.xmlKey = "soilSample"
	self.typeWeights = {
		[EnvironmentalScoreSoilSample.TYPE_NONE] = 0,
		[EnvironmentalScoreSoilSample.TYPE_SAMPLED] = 1
	}

	return self
end

function EnvironmentalScoreSoilSample:loadFromXML(xmlFile, key, baseDirectory, configFileName, mapFilename)
	if not EnvironmentalScoreTillage:superClass().loadFromXML(self, xmlFile, key, baseDirectory, configFileName, mapFilename) then
		return false
	end

	return true
end

function EnvironmentalScoreSoilSample:update(dt)
end

function EnvironmentalScoreSoilSample:getScore(farmlandId)
	local farmlandData = self:getFarmlandData(farmlandId)

	if farmlandData.clientScore ~= nil then
		return farmlandData.clientScore
	end

	if farmlandData.samplePercentage < 0 then
		return 0.5
	end

	return farmlandData.samplePercentage
end

function EnvironmentalScoreSoilSample:initFarmlandData()
	return {
		samplePercentage = -1
	}
end

function EnvironmentalScoreSoilSample:loadFarmlandData(data, xmlFile, key)
	data.samplePercentage = xmlFile:getFloat(key .. "#samplePercentage", data.samplePercentage)
end

function EnvironmentalScoreSoilSample:saveFarmlandData(data, xmlFile, key)
	xmlFile:setFloat(key .. "#samplePercentage", data.samplePercentage)
end

function EnvironmentalScoreSoilSample:readFarmlandDataFromStream(data, streamId, connection)
	local score = MathUtil.round(streamReadUIntN(streamId, 8) / 255, 2)
	data.clientScore = score
end

function EnvironmentalScoreSoilSample:writeFarmlandDataToStream(data, streamId, connection)
	local score = self:getScore(data.farmlandId)

	streamWriteUIntN(streamId, score * 255, 8)
end

function EnvironmentalScoreSoilSample:onHarvestScoreReset(farmlandId)
	self:updateFarmlandSampleState(farmlandId)
end

function EnvironmentalScoreSoilSample:updateFarmlandSampleState(farmlandId)
	local farmlandData = self:getFarmlandData(farmlandId)
	local percentage = self.pfModule.coverMap:getFarmlandSampleState(farmlandId)
	farmlandData.samplePercentage = MathUtil.clamp(percentage, 0, 1)
end

function EnvironmentalScoreSoilSample:overwriteGameFunctions(pfModule)
	if g_server ~= nil then
		pfModule:overwriteGameFunction(SoilSampler, "processSoilSampling", function (superFunc, vehicle, ...)
			superFunc(vehicle, ...)

			local spec = vehicle.spec_soilSampler

			if spec.coverMap ~= nil then
				local x, _, z = getWorldTranslation(spec.samplingNode)
				local farmlandId = g_farmlandManager:getFarmlandIdAtWorldPosition(x, z)

				self:updateFarmlandSampleState(farmlandId)
			end
		end)
		pfModule:overwriteGameFunction(CoverMap, "uncoverFarmlandArea", function (superFunc, coverMap, farmlandId)
			superFunc(coverMap, farmlandId)
			self:updateFarmlandSampleState(farmlandId)
		end)
		pfModule:overwriteGameFunction(CoverMap, "analyseArea", function (superFunc, coverMap, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, state, farmId, farmlandId)
			superFunc(coverMap, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, state, farmId, farmlandId)

			if farmlandId ~= nil then
				self:updateFarmlandSampleState(farmlandId)
			end
		end)
	end
end
