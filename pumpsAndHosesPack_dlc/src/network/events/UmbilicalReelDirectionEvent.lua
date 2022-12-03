UmbilicalReelDirectionEvent = {}
local UmbilicalReelDirectionEvent_mt = Class(UmbilicalReelDirectionEvent, Event)

InitEventClass(UmbilicalReelDirectionEvent, "UmbilicalReelDirectionEvent")

function UmbilicalReelDirectionEvent.emptyNew()
	local self = Event.new(UmbilicalReelDirectionEvent_mt)

	return self
end

function UmbilicalReelDirectionEvent.new(object, direction)
	local self = UmbilicalReelDirectionEvent.emptyNew()
	self.object = object
	self.direction = direction

	return self
end

function UmbilicalReelDirectionEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.direction = streamReadFloat32(streamId)

	self:run(connection)
end

function UmbilicalReelDirectionEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteFloat32(streamId, self.direction)
end

function UmbilicalReelDirectionEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end

	self.object:setReelDirection(self.direction, true)
end

function UmbilicalReelDirectionEvent.sendEvent(object, direction, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(UmbilicalReelDirectionEvent.new(object, direction), nil, , object)
		else
			g_client:getServerConnection():sendEvent(UmbilicalReelDirectionEvent.new(object, direction))
		end
	end
end
