SandboxPlaceableRootStateEvent = {}
local sandboxPlaceableRootStateEvent_mt = Class(SandboxPlaceableRootStateEvent, Event)

InitEventClass(SandboxPlaceableRootStateEvent, "SandboxPlaceableRootStateEvent")

function SandboxPlaceableRootStateEvent.emptyNew()
	local self = Event.new(sandboxPlaceableRootStateEvent_mt)

	return self
end

function SandboxPlaceableRootStateEvent.new(object, rootState)
	local self = SandboxPlaceableRootStateEvent.emptyNew()
	self.object = object
	self.rootState = rootState

	return self
end

function SandboxPlaceableRootStateEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.rootState = streamReadBool(streamId)

	self:run(connection)
end

function SandboxPlaceableRootStateEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteBool(streamId, self.rootState)
end

function SandboxPlaceableRootStateEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end

	self.object:setSandboxRootState(self.rootState, true)
end

function SandboxPlaceableRootStateEvent.sendEvent(object, rootState, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(SandboxPlaceableRootStateEvent.new(object, rootState), nil, , object)
		else
			g_client:getServerConnection():sendEvent(SandboxPlaceableRootStateEvent.new(object, rootState))
		end
	end
end
