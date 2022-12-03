SuperCupCheckPointEvent = {}
local SuperCupCheckPointEvent_mt = Class(SuperCupCheckPointEvent, Event)

InitEventClass(SuperCupCheckPointEvent, "SuperCupCheckPointEvent")

function SuperCupCheckPointEvent.emptyNew()
	local self = Event.new(SuperCupCheckPointEvent_mt)

	return self
end

function SuperCupCheckPointEvent.new(object, isActive)
	local self = SuperCupCheckPointEvent.emptyNew()
	self.object = object
	self.isActive = isActive

	return self
end

function SuperCupCheckPointEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.isActive = streamReadBool(streamId)

	self:run(connection)
end

function SuperCupCheckPointEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteBool(streamId, self.isActive)
end

function SuperCupCheckPointEvent:run(connection)
	self.object:setIsActive(self.isActive, true)

	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end
end
