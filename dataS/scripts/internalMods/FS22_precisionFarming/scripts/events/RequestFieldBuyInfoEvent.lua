RequestFieldBuyInfoEvent = {}
local RequestFieldBuyInfoEvent_mt = Class(RequestFieldBuyInfoEvent, Event)

InitEventClass(RequestFieldBuyInfoEvent, "RequestFieldBuyInfoEvent")

function RequestFieldBuyInfoEvent:emptyNew()
	local self = Event.new(RequestFieldBuyInfoEvent_mt)

	return self
end

function RequestFieldBuyInfoEvent.new(farmlandId)
	local self = RequestFieldBuyInfoEvent:emptyNew()
	self.farmlandId = farmlandId

	return self
end

function RequestFieldBuyInfoEvent:readStream(streamId, connection)
	self.farmlandId = streamReadUIntN(streamId, g_farmlandManager.numberOfBits)

	self:run(connection)
end

function RequestFieldBuyInfoEvent:writeStream(streamId, connection)
	streamWriteUIntN(streamId, self.farmlandId, g_farmlandManager.numberOfBits)
end

function RequestFieldBuyInfoEvent:run(connection)
	if not connection:getIsServer() and not connection:getIsServer() then
		g_server:broadcastEvent(AdditionalFieldBuyInfoEvent.new(self.farmlandId), false, nil, , true, {
			connection
		})
	end
end
