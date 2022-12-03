FarmlandStatistic = {}
local FarmlandStatistic_mt = Class(FarmlandStatistic)

function FarmlandStatistic.new(farmlandId, customMt)
	local self = setmetatable({}, customMt or FarmlandStatistic_mt)
	self.farmlandId = farmlandId
	self.hasChanged = false
	self.periodCounter = FarmlandStatisticCounter.new()
	self.totalCounter = FarmlandStatisticCounter.new()

	return self
end

function FarmlandStatistic:loadFromItemsXML(xmlFile, key)
	if xmlFile:getInt(key .. "#farmlandId") == self.farmlandId then
		self.periodCounter:loadFromItemsXML(xmlFile, key .. ".periodCounter")
		self.totalCounter:loadFromItemsXML(xmlFile, key .. ".totalCounter")
	else
		Logging.warning("Failed to load FarmlandStatistic from items xml (%s)", key)
	end
end

function FarmlandStatistic:saveToXMLFile(xmlFile, key, usedModNames)
	xmlFile:setInt(key .. "#farmlandId", self.farmlandId)
	self.periodCounter:saveToXMLFile(xmlFile, key .. ".periodCounter", usedModNames)
	self.totalCounter:saveToXMLFile(xmlFile, key .. ".totalCounter", usedModNames)
end

function FarmlandStatistic:onReadStream(streamId, connection)
	self.periodCounter:onReadStream(streamId, connection)
	self.totalCounter:onReadStream(streamId, connection)
end

function FarmlandStatistic:onWriteStream(streamId, connection)
	self.periodCounter:onWriteStream(streamId, connection)
	self.totalCounter:onWriteStream(streamId, connection)
end

function FarmlandStatistic:reset(clearTotal)
	self.periodCounter:reset()

	if clearTotal then
		self.totalCounter:reset()
	end
end

function FarmlandStatistic:getValue(total, name)
	local counter = self.periodCounter

	if total then
		counter = self.totalCounter
	end

	if counter[name] ~= nil then
		return counter[name]
	end

	return 0
end

function FarmlandStatistic:updateStatistic(name, value)
	if self.periodCounter[name] ~= nil then
		self.periodCounter[name] = self.periodCounter[name] + value
	end

	if self.totalCounter[name] ~= nil then
		self.totalCounter[name] = self.totalCounter[name] + value
	end

	self.hasChanged = true
end
