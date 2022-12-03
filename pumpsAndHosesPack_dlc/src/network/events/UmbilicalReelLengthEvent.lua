UmbilicalReelLengthEvent = {}
local UmbilicalReelLengthEvent_mt = Class(UmbilicalReelLengthEvent, Event)

InitEventClass(UmbilicalReelLengthEvent, "UmbilicalReelLengthEvent")

function UmbilicalReelLengthEvent.emptyNew()
	local self = Event.new(UmbilicalReelLengthEvent_mt)

	return self
end

function UmbilicalReelLengthEvent.new(object, reelId, isDelete, length, color)
	local self = UmbilicalReelLengthEvent.emptyNew()
	self.object = object
	self.reelId = reelId
	self.isDelete = isDelete
	self.length = length
	self.color = color

	return self
end

function UmbilicalReelLengthEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.reelId = streamReadUIntN(streamId, 2) + 1
	self.isDelete = streamReadBool(streamId)

	if not self.isDelete then
		self.length = streamReadFloat32(streamId)
		self.color = NetworkHelper.readCompressedLinearColor(streamId)
	end

	self:run(connection)
end

function UmbilicalReelLengthEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteUIntN(streamId, self.reelId - 1, 2)
	streamWriteBool(streamId, self.isDelete)

	if not self.isDelete then
		streamWriteFloat32(streamId, self.length)
		NetworkHelper.writeCompressedLinearColor(streamId, self.color)
	end
end

function UmbilicalReelLengthEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end

	if self.isDelete then
		self.object:removeReelHose(self.reelId, true)
	else
		self.object:addReelHose(self.reelId, self.length, self.color, true)
	end
end

function UmbilicalReelLengthEvent.sendEvent(object, reelId, isDelete, noEventSend, length, color)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(UmbilicalReelLengthEvent.new(object, reelId, isDelete, length, color), nil, , object)
		else
			g_client:getServerConnection():sendEvent(UmbilicalReelLengthEvent.new(object, reelId, isDelete, length, color))
		end
	end
end
