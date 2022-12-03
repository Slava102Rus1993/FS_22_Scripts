SuperCupPenaltyEvent = {}
local SuperCupPenaltyEvent_mt = Class(SuperCupPenaltyEvent, Event)

InitEventClass(SuperCupPenaltyEvent, "SuperCupPenaltyEvent")

function SuperCupPenaltyEvent.emptyNew()
	local self = Event.new(SuperCupPenaltyEvent_mt)

	return self
end

function SuperCupPenaltyEvent.new(object, count)
	local self = SuperCupPenaltyEvent.emptyNew()
	self.object = object
	self.count = count

	return self
end

function SuperCupPenaltyEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.count = streamReadInt32(streamId)

	self:run(connection)
end

function SuperCupPenaltyEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteInt32(streamId, self.count)
end

function SuperCupPenaltyEvent:run(connection)
	self.object:setLostBallCount(self.count, true)

	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end
end
