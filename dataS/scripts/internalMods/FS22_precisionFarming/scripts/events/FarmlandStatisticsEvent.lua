FarmlandStatisticsEvent = {}
local FarmlandStatisticsEvent_mt = Class(FarmlandStatisticsEvent, Event)

InitEventClass(FarmlandStatisticsEvent, "FarmlandStatisticsEvent")

function FarmlandStatisticsEvent:emptyNew()
	local self = Event.new(FarmlandStatisticsEvent_mt)

	return self
end

function FarmlandStatisticsEvent.new(farmlandId)
	local self = FarmlandStatisticsEvent:emptyNew()
	self.farmlandId = farmlandId

	return self
end

function FarmlandStatisticsEvent:readStream(streamId, connection)
	self.farmlandId = streamReadUIntN(streamId, 8)
	local pfModule = g_precisionFarming

	if pfModule ~= nil and pfModule.farmlandStatistics ~= nil then
		pfModule.farmlandStatistics:readStatisticFromStream(self.farmlandId, streamId, connection)
	end
end

function FarmlandStatisticsEvent:writeStream(streamId, connection)
	streamWriteUIntN(streamId, self.farmlandId, 8)

	local pfModule = g_precisionFarming

	if pfModule ~= nil and pfModule.farmlandStatistics ~= nil then
		pfModule.farmlandStatistics:writeStatisticToStream(self.farmlandId, streamId, connection)
	end
end
