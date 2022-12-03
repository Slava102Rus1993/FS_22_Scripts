SuperCupStartEvent = {}
local SuperCupStartEvent_mt = Class(SuperCupStartEvent, Event)

InitEventClass(SuperCupStartEvent, "SuperCupStartEvent")

function SuperCupStartEvent.emptyNew()
	local self = Event.new(SuperCupStartEvent_mt)

	return self
end

function SuperCupStartEvent.new(object, playerUserId)
	local self = SuperCupStartEvent.emptyNew()
	self.object = object
	self.playerUserId = playerUserId

	return self
end

function SuperCupStartEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteInt8(streamId, self.playerUserId)
end

function SuperCupStartEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.playerUserId = streamReadInt8(streamId)

	self:run(connection)
end

function SuperCupStartEvent:run(connection)
	if not connection:getIsServer() then
		self.object.spec_superCup.superCup:onStartSuperCup(self.playerUserId)
	end
end
