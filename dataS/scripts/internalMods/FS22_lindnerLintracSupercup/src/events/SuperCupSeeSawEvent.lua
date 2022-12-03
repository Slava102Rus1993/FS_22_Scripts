SuperCupSeeSawEvent = {}
local SuperCupSeeSawEvent_mt = Class(SuperCupSeeSawEvent, Event)

InitEventClass(SuperCupSeeSawEvent, "SuperCupSeeSawEvent")

function SuperCupSeeSawEvent.emptyNew()
	local self = Event.new(SuperCupSeeSawEvent_mt)

	return self
end

function SuperCupSeeSawEvent.new(object, isActive, isForced)
	local self = SuperCupSeeSawEvent.emptyNew()
	self.object = object
	self.isActive = isActive
	self.isForced = isForced or false

	return self
end

function SuperCupSeeSawEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.isActive = streamReadBool(streamId)
	self.isForced = streamReadBool(streamId)

	self:run(connection)
end

function SuperCupSeeSawEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteBool(streamId, self.isActive)
	streamWriteBool(streamId, self.isForced)
end

function SuperCupSeeSawEvent:run(connection)
	self.object:setBeaconLightVisibility(self.isActive, self.isForced, true)

	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end
end
