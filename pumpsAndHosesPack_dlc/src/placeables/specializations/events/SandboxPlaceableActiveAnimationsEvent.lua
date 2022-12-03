SandboxPlaceableActiveAnimationsEvent = {}
local sandboxPlaceableActiveAnimationsEvent_mt = Class(SandboxPlaceableActiveAnimationsEvent, Event)

InitEventClass(SandboxPlaceableActiveAnimationsEvent, "SandboxPlaceableActiveAnimationsEvent")

function SandboxPlaceableActiveAnimationsEvent.emptyNew()
	local self = Event.new(sandboxPlaceableActiveAnimationsEvent_mt)

	return self
end

function SandboxPlaceableActiveAnimationsEvent.new(object, hasActiveAnimations)
	local self = SandboxPlaceableActiveAnimationsEvent.emptyNew()
	self.object = object
	self.hasActiveAnimations = hasActiveAnimations

	return self
end

function SandboxPlaceableActiveAnimationsEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.hasActiveAnimations = streamReadBool(streamId)

	self:run(connection)
end

function SandboxPlaceableActiveAnimationsEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteBool(streamId, self.hasActiveAnimations)
end

function SandboxPlaceableActiveAnimationsEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end

	self.object:setActiveAnimationsState(self.hasActiveAnimations, true)
end
