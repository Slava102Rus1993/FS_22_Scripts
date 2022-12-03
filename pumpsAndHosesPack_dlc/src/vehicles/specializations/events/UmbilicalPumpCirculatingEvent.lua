UmbilicalPumpCirculatingEvent = {}
local UmbilicalPumpCirculatingEvent_mt = Class(UmbilicalPumpCirculatingEvent, Event)

InitEventClass(UmbilicalPumpCirculatingEvent, "UmbilicalPumpCirculatingEvent")

function UmbilicalPumpCirculatingEvent.emptyNew()
	local self = Event.new(UmbilicalPumpCirculatingEvent_mt)

	return self
end

function UmbilicalPumpCirculatingEvent.new(object, pumpIsCirculating)
	local self = UmbilicalPumpCirculatingEvent.emptyNew()
	self.object = object
	self.pumpIsCirculating = pumpIsCirculating

	return self
end

function UmbilicalPumpCirculatingEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.pumpIsCirculating = streamReadBool(streamId)

	self:run(connection)
end

function UmbilicalPumpCirculatingEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteBool(streamId, self.pumpIsCirculating)
end

function UmbilicalPumpCirculatingEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end

	self.object:setIsPumpCirculating(self.pumpIsCirculating, true)
end

function UmbilicalPumpCirculatingEvent.sendEvent(object, pumpIsCirculating, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(UmbilicalPumpCirculatingEvent.new(object, pumpIsCirculating), nil, , object)
		else
			g_client:getServerConnection():sendEvent(UmbilicalPumpCirculatingEvent.new(object, pumpIsCirculating))
		end
	end
end
