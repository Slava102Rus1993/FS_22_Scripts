UmbilicalReelInstantOverloadEvent = {}
local UmbilicalReelUnloadEvent_mt = Class(UmbilicalReelInstantOverloadEvent, Event)

InitEventClass(UmbilicalReelInstantOverloadEvent, "UmbilicalReelInstantOverloadEvent")

function UmbilicalReelInstantOverloadEvent.emptyNew()
	local self = Event.new(UmbilicalReelUnloadEvent_mt)

	return self
end

function UmbilicalReelInstantOverloadEvent.new(object, fromObject)
	local self = UmbilicalReelInstantOverloadEvent.emptyNew()
	self.object = object
	self.fromObject = fromObject

	return self
end

function UmbilicalReelInstantOverloadEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.fromObject = NetworkUtil.readNodeObject(streamId)

	self:run(connection)
end

function UmbilicalReelInstantOverloadEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	NetworkUtil.writeNodeObject(streamId, self.fromObject)
end

function UmbilicalReelInstantOverloadEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end

	self.object:overload(self.fromObject, true)
end

function UmbilicalReelInstantOverloadEvent.sendEvent(object, fromObject, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(UmbilicalReelInstantOverloadEvent.new(object, fromObject), nil, , object)
		else
			g_client:getServerConnection():sendEvent(UmbilicalReelInstantOverloadEvent.new(object, fromObject))
		end
	end
end
