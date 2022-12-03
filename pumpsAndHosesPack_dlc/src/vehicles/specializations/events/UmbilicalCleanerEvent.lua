UmbilicalCleanerEvent = {}
local UmbilicalCleanerEvent_mt = Class(UmbilicalCleanerEvent, Event)

InitEventClass(UmbilicalCleanerEvent, "UmbilicalCleanerEvent")

function UmbilicalCleanerEvent.emptyNew()
	local self = Event.new(UmbilicalCleanerEvent_mt)

	return self
end

function UmbilicalCleanerEvent.new(object, isPressurised, umbilicalHose)
	local self = UmbilicalCleanerEvent.emptyNew()
	self.object = object
	self.isPressurised = isPressurised
	self.umbilicalHose = umbilicalHose

	return self
end

function UmbilicalCleanerEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.isPressurised = streamReadBool(streamId)

	if streamReadBool(streamId) then
		self.umbilicalHose = NetworkUtil.readNodeObject(streamId)
	end

	self:run(connection)
end

function UmbilicalCleanerEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteBool(streamId, self.isPressurised)
	streamWriteBool(streamId, self.umbilicalHose ~= nil)

	if self.umbilicalHose ~= nil then
		NetworkUtil.writeNodeObject(streamId, self.umbilicalHose)
	end
end

function UmbilicalCleanerEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end

	self.object:setIsPressurised(self.isPressurised, self.umbilicalHose, true)
end

function UmbilicalCleanerEvent.sendEvent(object, isPressurised, umbilicalHose, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(UmbilicalCleanerEvent.new(object, isPressurised, umbilicalHose), nil, , object)
		else
			g_client:getServerConnection():sendEvent(UmbilicalCleanerEvent.new(object, isPressurised, umbilicalHose))
		end
	end
end
