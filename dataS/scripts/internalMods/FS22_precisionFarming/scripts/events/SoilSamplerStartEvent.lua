SoilSamplerStartEvent = {}
local SoilSamplerStartEvent_mt = Class(SoilSamplerStartEvent, Event)

InitEventClass(SoilSamplerStartEvent, "SoilSamplerStartEvent")

function SoilSamplerStartEvent:emptyNew()
	local self = Event.new(SoilSamplerStartEvent_mt)

	return self
end

function SoilSamplerStartEvent.new(object)
	local self = SoilSamplerStartEvent:emptyNew()
	self.object = object

	return self
end

function SoilSamplerStartEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)

	self:run(connection)
end

function SoilSamplerStartEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
end

function SoilSamplerStartEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end

	if self.object ~= nil and self.object:getIsSynchronized() then
		self.object:startSoilSampling(true)
	end
end

function SoilSamplerStartEvent.sendEvent(object, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(SoilSamplerStartEvent.new(object), nil, , object)
		else
			g_client:getServerConnection():sendEvent(SoilSamplerStartEvent.new(object))
		end
	end
end
