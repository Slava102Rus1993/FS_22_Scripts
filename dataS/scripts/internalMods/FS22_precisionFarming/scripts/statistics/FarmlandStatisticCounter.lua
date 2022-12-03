FarmlandStatisticCounter = {}
local FarmlandStatisticCounter_mt = Class(FarmlandStatisticCounter)

function FarmlandStatisticCounter.new(customMt)
	local self = setmetatable({}, customMt or FarmlandStatisticCounter_mt)

	self:reset()

	return self
end

function FarmlandStatisticCounter:loadFromItemsXML(xmlFile, key)
	self.numSoilSamples = xmlFile:getInt(key .. "#numSoilSamples", self.numSoilSamples)
	self.soilSampleCosts = xmlFile:getFloat(key .. "#soilSampleCosts", self.soilSampleCosts)
	self.usedLime = xmlFile:getFloat(key .. "#usedLime", self.usedLime)
	self.usedLimeRegular = xmlFile:getFloat(key .. "#usedLimeRegular", self.usedLimeRegular)
	self.usedMineralFertilizer = xmlFile:getFloat(key .. "#usedMineralFertilizer", self.usedMineralFertilizer)
	self.usedMineralFertilizerRegular = xmlFile:getFloat(key .. "#usedMineralFertilizerRegular", self.usedMineralFertilizerRegular)
	self.usedLiquidFertilizer = xmlFile:getFloat(key .. "#usedLiquidFertilizer", self.usedLiquidFertilizer)
	self.usedLiquidFertilizerRegular = xmlFile:getFloat(key .. "#usedLiquidFertilizerRegular", self.usedLiquidFertilizerRegular)
	self.usedManure = xmlFile:getFloat(key .. "#usedManure", self.usedManure)
	self.usedManureRegular = xmlFile:getFloat(key .. "#usedManureRegular", self.usedManureRegular)
	self.usedLiquidManure = xmlFile:getFloat(key .. "#usedLiquidManure", self.usedLiquidManure)
	self.usedLiquidManureRegular = xmlFile:getFloat(key .. "#usedLiquidManureRegular", self.usedLiquidManureRegular)
	self.usedSeeds = xmlFile:getFloat(key .. "#usedSeeds", self.usedSeeds)
	self.usedSeedsRegular = xmlFile:getFloat(key .. "#usedSeedsRegular", self.usedSeedsRegular)
	self.usedHerbicide = xmlFile:getFloat(key .. "#usedHerbicide", self.usedHerbicide)
	self.usedHerbicideRegular = xmlFile:getFloat(key .. "#usedHerbicideRegular", self.usedHerbicideRegular)
	self.yield = xmlFile:getFloat(key .. "#yield", self.yield)
	self.yieldRegular = xmlFile:getFloat(key .. "#yieldRegular", self.yieldRegular)
	self.yieldWeight = xmlFile:getFloat(key .. "#yieldWeight", self.yieldWeight)
	self.yieldBestPrice = xmlFile:getFloat(key .. "#yieldBestPrice", self.yieldBestPrice)
	self.usedFuel = xmlFile:getFloat(key .. "#usedFuel", self.usedFuel)
	self.vehicleCosts = xmlFile:getFloat(key .. "#vehicleCosts", self.vehicleCosts)
	self.helperCosts = xmlFile:getFloat(key .. "#helperCosts", self.helperCosts)
end

function FarmlandStatisticCounter:saveToXMLFile(xmlFile, key, usedModNames)
	xmlFile:setInt(key .. "#numSoilSamples", self.numSoilSamples)
	xmlFile:setFloat(key .. "#soilSampleCosts", self.soilSampleCosts)
	xmlFile:setFloat(key .. "#usedLime", self.usedLime)
	xmlFile:setFloat(key .. "#usedLimeRegular", self.usedLimeRegular)
	xmlFile:setFloat(key .. "#usedMineralFertilizer", self.usedMineralFertilizer)
	xmlFile:setFloat(key .. "#usedMineralFertilizerRegular", self.usedMineralFertilizerRegular)
	xmlFile:setFloat(key .. "#usedLiquidFertilizer", self.usedLiquidFertilizer)
	xmlFile:setFloat(key .. "#usedLiquidFertilizerRegular", self.usedLiquidFertilizerRegular)
	xmlFile:setFloat(key .. "#usedManure", self.usedManure)
	xmlFile:setFloat(key .. "#usedManureRegular", self.usedManureRegular)
	xmlFile:setFloat(key .. "#usedLiquidManure", self.usedLiquidManure)
	xmlFile:setFloat(key .. "#usedLiquidManureRegular", self.usedLiquidManureRegular)
	xmlFile:setFloat(key .. "#usedSeeds", self.usedSeeds)
	xmlFile:setFloat(key .. "#usedSeedsRegular", self.usedSeedsRegular)
	xmlFile:setFloat(key .. "#usedHerbicide", self.usedHerbicide)
	xmlFile:setFloat(key .. "#usedHerbicideRegular", self.usedHerbicideRegular)
	xmlFile:setFloat(key .. "#yield", self.yield)
	xmlFile:setFloat(key .. "#yieldRegular", self.yieldRegular)
	xmlFile:setFloat(key .. "#yieldWeight", self.yieldWeight)
	xmlFile:setFloat(key .. "#yieldBestPrice", self.yieldBestPrice)
	xmlFile:setFloat(key .. "#usedFuel", self.usedFuel)
	xmlFile:setFloat(key .. "#vehicleCosts", self.vehicleCosts)
	xmlFile:setFloat(key .. "#helperCosts", self.helperCosts)
end

function FarmlandStatisticCounter:reset()
	self.numSoilSamples = 0
	self.soilSampleCosts = 0
	self.usedLime = 0
	self.usedLimeRegular = 0
	self.usedMineralFertilizer = 0
	self.usedMineralFertilizerRegular = 0
	self.usedLiquidFertilizer = 0
	self.usedLiquidFertilizerRegular = 0
	self.usedManure = 0
	self.usedManureRegular = 0
	self.usedLiquidManure = 0
	self.usedLiquidManureRegular = 0
	self.usedSeeds = 0
	self.usedSeedsRegular = 0
	self.usedHerbicide = 0
	self.usedHerbicideRegular = 0
	self.yield = 0
	self.yieldRegular = 0
	self.yieldWeight = 0
	self.yieldBestPrice = 0
	self.usedFuel = 0
	self.vehicleCosts = 0
	self.helperCosts = 0
end

function FarmlandStatisticCounter:onReadStream(streamId, connection)
	self.numSoilSamples = streamReadUIntN(streamId, 16)
	self.soilSampleCosts = streamReadFloat32(streamId)
	self.usedLime = streamReadFloat32(streamId)
	self.usedLimeRegular = streamReadFloat32(streamId)
	self.usedMineralFertilizer = streamReadFloat32(streamId)
	self.usedMineralFertilizerRegular = streamReadFloat32(streamId)
	self.usedLiquidFertilizer = streamReadFloat32(streamId)
	self.usedLiquidFertilizerRegular = streamReadFloat32(streamId)
	self.usedManure = streamReadFloat32(streamId)
	self.usedManureRegular = streamReadFloat32(streamId)
	self.usedLiquidManure = streamReadFloat32(streamId)
	self.usedLiquidManureRegular = streamReadFloat32(streamId)
	self.usedSeeds = streamReadFloat32(streamId)
	self.usedSeedsRegular = streamReadFloat32(streamId)
	self.usedHerbicide = streamReadFloat32(streamId)
	self.usedHerbicideRegular = streamReadFloat32(streamId)
	self.yield = streamReadFloat32(streamId)
	self.yieldRegular = streamReadFloat32(streamId)
	self.yieldWeight = streamReadFloat32(streamId)
	self.yieldBestPrice = streamReadFloat32(streamId)
	self.usedFuel = streamReadFloat32(streamId)
	self.vehicleCosts = streamReadFloat32(streamId)
	self.helperCosts = streamReadFloat32(streamId)
end

function FarmlandStatisticCounter:onWriteStream(streamId, connection)
	streamWriteUIntN(streamId, self.numSoilSamples, 16)
	streamWriteFloat32(streamId, self.soilSampleCosts)
	streamWriteFloat32(streamId, self.usedLime)
	streamWriteFloat32(streamId, self.usedLimeRegular)
	streamWriteFloat32(streamId, self.usedMineralFertilizer)
	streamWriteFloat32(streamId, self.usedMineralFertilizerRegular)
	streamWriteFloat32(streamId, self.usedLiquidFertilizer)
	streamWriteFloat32(streamId, self.usedLiquidFertilizerRegular)
	streamWriteFloat32(streamId, self.usedManure)
	streamWriteFloat32(streamId, self.usedManureRegular)
	streamWriteFloat32(streamId, self.usedLiquidManure)
	streamWriteFloat32(streamId, self.usedLiquidManureRegular)
	streamWriteFloat32(streamId, self.usedSeeds)
	streamWriteFloat32(streamId, self.usedSeedsRegular)
	streamWriteFloat32(streamId, self.usedHerbicide)
	streamWriteFloat32(streamId, self.usedHerbicideRegular)
	streamWriteFloat32(streamId, self.yield)
	streamWriteFloat32(streamId, self.yieldRegular)
	streamWriteFloat32(streamId, self.yieldWeight)
	streamWriteFloat32(streamId, self.yieldBestPrice)
	streamWriteFloat32(streamId, self.usedFuel)
	streamWriteFloat32(streamId, self.vehicleCosts)
	streamWriteFloat32(streamId, self.helperCosts)
end
