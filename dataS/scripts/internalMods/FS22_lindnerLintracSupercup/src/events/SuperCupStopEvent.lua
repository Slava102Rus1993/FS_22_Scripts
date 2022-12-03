SuperCupStopEvent = {}
local SuperCupStopEvent_mt = Class(SuperCupStopEvent, Event)

InitEventClass(SuperCupStopEvent, "SuperCupStopEvent")

function SuperCupStopEvent.emptyNew()
	local self = Event.new(SuperCupStopEvent_mt)

	return self
end

function SuperCupStopEvent.new(object, playerUserId)
	local self = SuperCupStopEvent.emptyNew()
	self.object = object
	self.playerUserId = playerUserId

	return self
end

function SuperCupStopEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteInt8(streamId, self.playerUserId)
end

function SuperCupStopEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.playerUserId = streamReadInt8(streamId)

	self:run(connection)
end

function SuperCupStopEvent:run(connection)
	if not connection:getIsServer() then
		self.object.spec_superCup.superCup:onStopSuperCup(self.playerUserId)
	end
end
