local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

LogGrabExtensionClawStateEvent = {}
local LogGrabExtensionClawStateEvent_mt = Class(LogGrabExtensionClawStateEvent, Event)

InitEventClass(LogGrabExtensionClawStateEvent, "LogGrabExtensionClawStateEvent")

function LogGrabExtensionClawStateEvent.emptyNew()
	local self = Event.new(LogGrabExtensionClawStateEvent_mt)

	return self
end

function LogGrabExtensionClawStateEvent.new(object, state, grabIndex)
	local self = LogGrabExtensionClawStateEvent.emptyNew()
	self.object = object
	self.state = state
	self.grabIndex = grabIndex

	return self
end

function LogGrabExtensionClawStateEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.state = streamReadBool(streamId)
	self.grabIndex = streamReadUIntN(streamId, LogGrabExtension.GRAB_INDEX_NUM_BITS)

	self:run(connection)
end

function LogGrabExtensionClawStateEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteBool(streamId, self.state)
	streamWriteUIntN(streamId, self.grabIndex, LogGrabExtension.GRAB_INDEX_NUM_BITS)
end

function LogGrabExtensionClawStateEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end

	if self.object ~= nil and self.object:getIsSynchronized() then
		self.object:setLogGrabClawState(self.grabIndex, self.state, true)
	end
end

function LogGrabExtensionClawStateEvent.sendEvent(vehicle, state, grabIndex, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(LogGrabExtensionClawStateEvent.new(vehicle, state, grabIndex), nil, , vehicle)
		else
			g_client:getServerConnection():sendEvent(LogGrabExtensionClawStateEvent.new(vehicle, state, grabIndex))
		end
	end
end
