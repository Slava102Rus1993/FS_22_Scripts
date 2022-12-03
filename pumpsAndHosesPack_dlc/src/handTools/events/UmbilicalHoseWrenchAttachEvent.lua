UmbilicalHoseWrenchAttachEvent = {}
local UmbilicalHoseWrenchAttachEvent_mt = Class(UmbilicalHoseWrenchAttachEvent, Event)

InitEventClass(UmbilicalHoseWrenchAttachEvent, "UmbilicalHoseWrenchAttachEvent")

function UmbilicalHoseWrenchAttachEvent.emptyNew()
	local self = Event.new(UmbilicalHoseWrenchAttachEvent_mt)

	return self
end

function UmbilicalHoseWrenchAttachEvent.new(player, umbilicalHose, type, connectorType)
	local self = UmbilicalHoseWrenchAttachEvent.emptyNew()
	self.player = player
	self.umbilicalHose = umbilicalHose
	self.type = type
	self.connectorType = connectorType

	return self
end

function UmbilicalHoseWrenchAttachEvent:readStream(streamId, connection)
	self.player = NetworkUtil.readNodeObject(streamId)
	self.umbilicalHose = NetworkUtil.readNodeObject(streamId)
	self.type = streamReadUIntN(streamId, 2) + 1
	self.connectorType = streamReadUIntN(streamId, 2) + 1

	self:run(connection)
end

function UmbilicalHoseWrenchAttachEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.player)
	NetworkUtil.writeNodeObject(streamId, self.umbilicalHose)
	streamWriteUIntN(streamId, self.type - 1, 2)
	streamWriteUIntN(streamId, self.connectorType - 1, 2)
end

function UmbilicalHoseWrenchAttachEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.player)
	end

	local currentTool = self.player.baseInformation.currentHandtool

	if currentTool ~= nil and currentTool.attachUmbilicalHose ~= nil then
		currentTool:attachUmbilicalHose(self.umbilicalHose, self.type, self.connectorType, true)
	end
end

function UmbilicalHoseWrenchAttachEvent.sendEvent(player, umbilicalHose, type, connectorType, noEventSend)
	local currentTool = player.baseInformation.currentHandtool

	if currentTool == nil or currentTool.attachUmbilicalHose == nil then
		return
	end

	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(UmbilicalHoseWrenchAttachEvent.new(player, umbilicalHose, type, connectorType), nil, , player)
		else
			g_client:getServerConnection():sendEvent(UmbilicalHoseWrenchAttachEvent.new(player, umbilicalHose, type, connectorType))
		end
	end
end
