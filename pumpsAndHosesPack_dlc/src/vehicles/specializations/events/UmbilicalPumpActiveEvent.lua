UmbilicalPumpActiveEvent = {}
local UmbilicalPumpActiveEvent_mt = Class(UmbilicalPumpActiveEvent, Event)

InitEventClass(UmbilicalPumpActiveEvent, "UmbilicalPumpActiveEvent")

function UmbilicalPumpActiveEvent.emptyNew()
	local self = Event.new(UmbilicalPumpActiveEvent_mt)

	return self
end

function UmbilicalPumpActiveEvent.new(object, isActive)
	local self = UmbilicalPumpActiveEvent.emptyNew()
	self.object = object
	self.isActive = isActive

	return self
end

function UmbilicalPumpActiveEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.isActive = streamReadBool(streamId)

	self:run(connection)
end

function UmbilicalPumpActiveEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteBool(streamId, self.isActive)
end

function UmbilicalPumpActiveEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end

	self.object:setIsPumpActive(self.isActive, true)
end

function UmbilicalPumpActiveEvent.sendEvent(object, isActive, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(UmbilicalPumpActiveEvent.new(object, isActive), nil, , object)
		else
			g_client:getServerConnection():sendEvent(UmbilicalPumpActiveEvent.new(object, isActive))
		end
	end
end
