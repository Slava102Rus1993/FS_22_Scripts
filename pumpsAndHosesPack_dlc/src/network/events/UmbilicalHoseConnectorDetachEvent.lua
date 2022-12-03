UmbilicalHoseConnectorDetachEvent = {}
local UmbilicalHoseConnectorDetachEvent_mt = Class(UmbilicalHoseConnectorDetachEvent, Event)

InitEventClass(UmbilicalHoseConnectorDetachEvent, "UmbilicalHoseConnectorDetachEvent")

function UmbilicalHoseConnectorDetachEvent.emptyNew()
	local self = Event.new(UmbilicalHoseConnectorDetachEvent_mt)

	return self
end

function UmbilicalHoseConnectorDetachEvent.new(object, connectorType, deleteUmbilicalHose)
	local self = UmbilicalHoseConnectorDetachEvent.emptyNew()
	self.object = object
	self.connectorType = connectorType
	self.deleteUmbilicalHose = deleteUmbilicalHose

	return self
end

function UmbilicalHoseConnectorDetachEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.deleteUmbilicalHose = streamReadBool(streamId)
	self.connectorType = streamReadUIntN(streamId, 2) + 1

	self:run(connection)
end

function UmbilicalHoseConnectorDetachEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteBool(streamId, self.deleteUmbilicalHose)
	streamWriteUIntN(streamId, self.connectorType - 1, 2)
end

function UmbilicalHoseConnectorDetachEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end

	if self.object ~= nil and self.object.detachUmbilicalHose ~= nil then
		self.object:detachUmbilicalHose(self.connectorType, self.deleteUmbilicalHose, true)
	end
end

function UmbilicalHoseConnectorDetachEvent.sendEvent(object, connectorType, deleteUmbilicalHose, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(UmbilicalHoseConnectorDetachEvent.new(object, connectorType, deleteUmbilicalHose), nil, , object)
		else
			g_client:getServerConnection():sendEvent(UmbilicalHoseConnectorDetachEvent.new(object, connectorType, deleteUmbilicalHose))
		end
	end
end
