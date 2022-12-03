ManureSeparatorProcessingEvent = {}
local UmbilicalReelUnloadEvent_mt = Class(ManureSeparatorProcessingEvent, Event)

InitEventClass(ManureSeparatorProcessingEvent, "ManureSeparatorProcessingEvent")

function ManureSeparatorProcessingEvent.emptyNew()
	local self = Event.new(UmbilicalReelUnloadEvent_mt)

	return self
end

function ManureSeparatorProcessingEvent.new(object, isProcessing)
	local self = ManureSeparatorProcessingEvent.emptyNew()
	self.object = object
	self.isProcessing = isProcessing

	return self
end

function ManureSeparatorProcessingEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.isProcessing = streamReadBool(streamId)

	self:run(connection)
end

function ManureSeparatorProcessingEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteBool(streamId, self.isProcessing)
end

function ManureSeparatorProcessingEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end

	self.object:setIsProcessing(self.isProcessing, true)
end

function ManureSeparatorProcessingEvent.sendEvent(object, isProcessing, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(ManureSeparatorProcessingEvent.new(object, isProcessing), nil, , object)
		else
			g_client:getServerConnection():sendEvent(ManureSeparatorProcessingEvent.new(object, isProcessing))
		end
	end
end
