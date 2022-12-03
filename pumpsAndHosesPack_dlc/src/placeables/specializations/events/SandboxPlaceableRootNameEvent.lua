SandboxPlaceableRootNameEvent = {}
local sandboxPlaceableRootNameEvent_mt = Class(SandboxPlaceableRootNameEvent, Event)

InitEventClass(SandboxPlaceableRootNameEvent, "SandboxPlaceableRootNameEvent")

function SandboxPlaceableRootNameEvent.emptyNew()
	local self = Event.new(sandboxPlaceableRootNameEvent_mt)

	return self
end

function SandboxPlaceableRootNameEvent.new(placeable, rootName)
	local self = SandboxPlaceableRootNameEvent.emptyNew()
	self.placeable = placeable
	self.resetName = rootName == nil
	self.rootName = rootName or ""

	return self
end

function SandboxPlaceableRootNameEvent:readStream(streamId, connection)
	self.placeable = NetworkUtil.readNodeObject(streamId)
	self.resetName = streamReadBool(streamId)

	if not self.resetName then
		self.rootName = streamReadString(streamId)
	end

	self:run(connection)
end

function SandboxPlaceableRootNameEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.placeable)

	if not streamWriteBool(streamId, self.resetName) then
		streamWriteString(streamId, self.rootName)
	end
end

function SandboxPlaceableRootNameEvent:run(connection)
	if self.placeable ~= nil then
		self.placeable:setSandboxRootName(self.rootName, true)

		if not connection:getIsServer() then
			g_server:broadcastEvent(self, false)
		end
	end
end

function SandboxPlaceableRootNameEvent.sendEvent(placeable, rootName, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_currentMission:getIsServer() then
			g_server:broadcastEvent(SandboxPlaceableRootNameEvent.new(placeable, rootName), false)
		else
			g_client:getServerConnection():sendEvent(SandboxPlaceableRootNameEvent.new(placeable, rootName))
		end
	end
end
