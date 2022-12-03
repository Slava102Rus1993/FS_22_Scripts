RequestFarmlandStatisticsEvent = {}
local RequestFarmlandStatisticsEvent_mt = Class(RequestFarmlandStatisticsEvent, Event)

InitEventClass(RequestFarmlandStatisticsEvent, "RequestFarmlandStatisticsEvent")

function RequestFarmlandStatisticsEvent:emptyNew()
	local self = Event.new(RequestFarmlandStatisticsEvent_mt)

	return self
end

function RequestFarmlandStatisticsEvent.new(farmlandId)
	local self = RequestFarmlandStatisticsEvent:emptyNew()
	self.farmlandId = farmlandId

	return self
end

function RequestFarmlandStatisticsEvent:readStream(streamId, connection)
	self.farmlandId = streamReadUIntN(streamId, 8)

	self:run(connection)
end

function RequestFarmlandStatisticsEvent:writeStream(streamId, connection)
	streamWriteUIntN(streamId, self.farmlandId, 8)
end

function RequestFarmlandStatisticsEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(FarmlandStatisticsEvent.new(self.farmlandId), false, nil, , true, {
			connection
		})
	end
end
