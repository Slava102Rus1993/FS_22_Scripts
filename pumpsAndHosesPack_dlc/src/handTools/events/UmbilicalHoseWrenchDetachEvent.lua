UmbilicalHoseWrenchDetachEvent = {}
local UmbilicalHoseWrenchDetachEvent_mt = Class(UmbilicalHoseWrenchDetachEvent, Event)

InitEventClass(UmbilicalHoseWrenchDetachEvent, "UmbilicalHoseWrenchDetachEvent")

function UmbilicalHoseWrenchDetachEvent.emptyNew()
	local self = Event.new(UmbilicalHoseWrenchDetachEvent_mt)

	return self
end

function UmbilicalHoseWrenchDetachEvent.new(player, connectorType)
	local self = UmbilicalHoseWrenchDetachEvent.emptyNew()
	self.player = player
	self.connectorType = connectorType

	return self
end

function UmbilicalHoseWrenchDetachEvent:readStream(streamId, connection)
	self.player = NetworkUtil.readNodeObject(streamId)
	self.connectorType = streamReadUIntN(streamId, 2) + 1

	self:run(connection)
end

function UmbilicalHoseWrenchDetachEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.player)
	streamWriteUIntN(streamId, self.connectorType - 1, 2)
end

function UmbilicalHoseWrenchDetachEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.player)
	end

	local currentTool = self.player.baseInformation.currentHandtool

	if currentTool ~= nil and currentTool.detachUmbilicalHose ~= nil then
		currentTool:detachUmbilicalHose(self.connectorType, true)
	end
end

function UmbilicalHoseWrenchDetachEvent.sendEvent(player, connectorType, noEventSend)
	local currentTool = player.baseInformation.currentHandtool

	if currentTool == nil or currentTool.detachUmbilicalHose == nil then
		return
	end

	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(UmbilicalHoseWrenchDetachEvent.new(player, connectorType), nil, , player)
		else
			g_client:getServerConnection():sendEvent(UmbilicalHoseWrenchDetachEvent.new(player, connectorType))
		end
	end
end
