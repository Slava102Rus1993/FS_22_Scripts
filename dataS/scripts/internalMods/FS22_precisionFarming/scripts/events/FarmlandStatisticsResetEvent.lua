FarmlandStatisticsResetEvent = {}
local FarmlandStatisticsResetEvent_mt = Class(FarmlandStatisticsResetEvent, Event)

InitEventClass(FarmlandStatisticsResetEvent, "FarmlandStatisticsResetEvent")

function FarmlandStatisticsResetEvent:emptyNew()
	local self = Event.new(FarmlandStatisticsResetEvent_mt)

	return self
end

function FarmlandStatisticsResetEvent.new(farmlandId)
	local self = FarmlandStatisticsResetEvent:emptyNew()
	self.farmlandId = farmlandId

	return self
end

function FarmlandStatisticsResetEvent:readStream(streamId, connection)
	self.farmlandId = streamReadUIntN(streamId, 8)
	local pfModule = g_precisionFarming

	if pfModule ~= nil and pfModule.farmlandStatistics ~= nil then
		pfModule.farmlandStatistics:resetStatistic(self.farmlandId, true)
	end
end

function FarmlandStatisticsResetEvent:writeStream(streamId, connection)
	streamWriteUIntN(streamId, self.farmlandId, 8)
end
