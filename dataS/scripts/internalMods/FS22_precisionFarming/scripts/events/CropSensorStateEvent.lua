CropSensorStateEvent = {}
local CropSensorStateEvent_mt = Class(CropSensorStateEvent, Event)

InitEventClass(CropSensorStateEvent, "CropSensorStateEvent")

function CropSensorStateEvent:emptyNew()
	local self = Event.new(CropSensorStateEvent_mt)

	return self
end

function CropSensorStateEvent.new(object, state)
	local self = CropSensorStateEvent:emptyNew()
	self.object = object
	self.state = state

	return self
end

function CropSensorStateEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.state = streamReadBool(streamId)

	self:run(connection)
end

function CropSensorStateEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteBool(streamId, self.state)
end

function CropSensorStateEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end

	if self.object ~= nil and self.object:getIsSynchronized() then
		self.object:setCropSensorActive(self.state, true)
	end
end

function CropSensorStateEvent.sendEvent(object, state, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(CropSensorStateEvent.new(object, state), nil, , object)
		else
			g_client:getServerConnection():sendEvent(CropSensorStateEvent.new(object, state))
		end
	end
end
