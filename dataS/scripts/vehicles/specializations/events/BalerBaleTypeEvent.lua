BalerBaleTypeEvent = {
	BALE_TYPE_SEND_NUM_BITS = 4
}
BalerBaleTypeEvent.MAX_NUM_BALE_TYPES = 2^BalerBaleTypeEvent.BALE_TYPE_SEND_NUM_BITS - 1
local BalerBaleTypeEvent_mt = Class(BalerBaleTypeEvent, Event)

InitEventClass(BalerBaleTypeEvent, "BalerBaleTypeEvent")

function BalerBaleTypeEvent.emptyNew()
	return Event.new(BalerBaleTypeEvent_mt)
end

function BalerBaleTypeEvent.new(object, baleTypeIndex, force)
	local self = BalerBaleTypeEvent.emptyNew()
	self.object = object
	self.baleTypeIndex = baleTypeIndex
	self.force = force

	return self
end

function BalerBaleTypeEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.baleTypeIndex = streamReadUIntN(streamId, BalerBaleTypeEvent.BALE_TYPE_SEND_NUM_BITS)
	self.force = streamReadBool(streamId)

	self:run(connection)
end

function BalerBaleTypeEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteUIntN(streamId, self.baleTypeIndex, BalerBaleTypeEvent.BALE_TYPE_SEND_NUM_BITS)
	streamWriteBool(streamId, Utils.getNoNil(self.force, false))
end

function BalerBaleTypeEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end

	if self.object ~= nil and self.object:getIsSynchronized() then
		self.object:setBaleTypeIndex(self.baleTypeIndex, self.force, true)
	end
end

function BalerBaleTypeEvent.sendEvent(object, baleTypeIndex, force, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(BalerBaleTypeEvent.new(object, baleTypeIndex, force), nil, , object)
		else
			g_client:getServerConnection():sendEvent(BalerBaleTypeEvent.new(object, baleTypeIndex, force))
		end
	end
end
