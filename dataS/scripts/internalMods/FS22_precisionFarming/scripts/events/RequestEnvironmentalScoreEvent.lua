RequestEnvironmentalScoreEvent = {}
local RequestEnvironmentalScoreEvent_mt = Class(RequestEnvironmentalScoreEvent, Event)

InitEventClass(RequestEnvironmentalScoreEvent, "RequestEnvironmentalScoreEvent")

function RequestEnvironmentalScoreEvent:emptyNew()
	local self = Event.new(RequestEnvironmentalScoreEvent_mt)

	return self
end

function RequestEnvironmentalScoreEvent.new(farmId)
	local self = RequestEnvironmentalScoreEvent:emptyNew()
	self.farmId = farmId

	return self
end

function RequestEnvironmentalScoreEvent:readStream(streamId, connection)
	self.farmId = streamReadUIntN(streamId, FarmManager.FARM_ID_SEND_NUM_BITS)

	self:run(connection)
end

function RequestEnvironmentalScoreEvent:writeStream(streamId, connection)
	streamWriteUIntN(streamId, self.farmId, FarmManager.FARM_ID_SEND_NUM_BITS)
end

function RequestEnvironmentalScoreEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(EnvironmentalScoreEvent.new(self.farmId), false, nil, , true, {
			connection
		})
	end
end
