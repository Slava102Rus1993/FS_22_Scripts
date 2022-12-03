UmbilicalHoseConnectorAttachEvent = {}
local UmbilicalHoseConnectorAttachEvent_mt = Class(UmbilicalHoseConnectorAttachEvent, Event)

InitEventClass(UmbilicalHoseConnectorAttachEvent, "UmbilicalHoseConnectorAttachEvent")

function UmbilicalHoseConnectorAttachEvent.emptyNew()
	local self = Event.new(UmbilicalHoseConnectorAttachEvent_mt)

	return self
end

function UmbilicalHoseConnectorAttachEvent.new(object, umbilicalHose, type, connectorType, createGuide)
	local self = UmbilicalHoseConnectorAttachEvent.emptyNew()
	self.object = object
	self.umbilicalHose = umbilicalHose
	self.type = type
	self.connectorType = connectorType
	self.createGuide = createGuide

	return self
end

function UmbilicalHoseConnectorAttachEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.umbilicalHose = NetworkUtil.readNodeObject(streamId)
	self.type = streamReadUIntN(streamId, 2) + 1
	self.connectorType = streamReadUIntN(streamId, 2) + 1
	self.createGuide = streamReadBool(streamId)

	self:run(connection)
end

function UmbilicalHoseConnectorAttachEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	NetworkUtil.writeNodeObject(streamId, self.umbilicalHose)
	streamWriteUIntN(streamId, self.type - 1, 2)
	streamWriteUIntN(streamId, self.connectorType - 1, 2)
	streamWriteBool(streamId, self.createGuide)
end

function UmbilicalHoseConnectorAttachEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end

	if self.object ~= nil and self.object.attachUmbilicalHose ~= nil then
		self.object:attachUmbilicalHose(self.umbilicalHose, self.type, self.connectorType, self.createGuide, true)
	end
end

function UmbilicalHoseConnectorAttachEvent.sendEvent(object, umbilicalHose, type, connectorType, createGuide, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(UmbilicalHoseConnectorAttachEvent.new(object, umbilicalHose, type, connectorType, createGuide), nil, , object)
		else
			g_client:getServerConnection():sendEvent(UmbilicalHoseConnectorAttachEvent.new(object, umbilicalHose, type, connectorType, createGuide))
		end
	end
end
