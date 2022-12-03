ToolCarrierStateEvent = {}
local ToolCarrierStateEvent_mt = Class(ToolCarrierStateEvent, Event)

InitEventClass(ToolCarrierStateEvent, "ToolCarrierStateEvent")

function ToolCarrierStateEvent.emptyNew()
	local self = Event.new(ToolCarrierStateEvent_mt)

	return self
end

function ToolCarrierStateEvent.new(object, state, force)
	local self = ToolCarrierStateEvent.emptyNew()
	self.object = object
	self.state = state
	self.force = force

	assert(ToolCarrier.MODE_START <= self.state and self.state <= ToolCarrier.MODE_TRANSPORT)

	return self
end

function ToolCarrierStateEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.state = streamReadUIntN(streamId, 2)
	self.force = streamReadBool(streamId)

	self:run(connection)
end

function ToolCarrierStateEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteUIntN(streamId, self.state, 2)
	streamWriteBool(streamId, self.force)
end

function ToolCarrierStateEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end

	self.object:setHeadlandState(self.state, self.force, true)
end

function ToolCarrierStateEvent.sendEvent(object, state, force, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(ToolCarrierStateEvent.new(object, state, force), nil, , object)
		else
			g_client:getServerConnection():sendEvent(ToolCarrierStateEvent.new(object, state, force))
		end
	end
end
