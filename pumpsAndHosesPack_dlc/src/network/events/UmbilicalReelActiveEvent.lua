UmbilicalReelActiveEvent = {}
local UmbilicalReelActiveEvent_mt = Class(UmbilicalReelActiveEvent, Event)

InitEventClass(UmbilicalReelActiveEvent, "UmbilicalReelActiveEvent")

function UmbilicalReelActiveEvent.emptyNew()
	local self = Event.new(UmbilicalReelActiveEvent_mt)

	return self
end

function UmbilicalReelActiveEvent.new(object, reelId, isActive, force)
	local self = UmbilicalReelActiveEvent.emptyNew()
	self.object = object
	self.reelId = reelId
	self.isActive = isActive
	self.force = force

	return self
end

function UmbilicalReelActiveEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.reelId = streamReadUIntN(streamId, 2) + 1
	self.isActive = streamReadBool(streamId)
	self.force = streamReadBool(streamId)

	self:run(connection)
end

function UmbilicalReelActiveEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteUIntN(streamId, self.reelId - 1, 2)
	streamWriteBool(streamId, self.isActive)
	streamWriteBool(streamId, self.force)
end

function UmbilicalReelActiveEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end

	self.object:setIsReelActive(self.reelId, self.isActive, self.force, true)
end

function UmbilicalReelActiveEvent.sendEvent(object, reelId, isActive, force, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(UmbilicalReelActiveEvent.new(object, reelId, isActive, force), nil, , object)
		else
			g_client:getServerConnection():sendEvent(UmbilicalReelActiveEvent.new(object, reelId, isActive, force))
		end
	end
end
