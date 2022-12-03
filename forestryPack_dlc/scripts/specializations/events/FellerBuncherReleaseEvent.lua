local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

FellerBuncherReleaseEvent = {}
local FellerBuncherReleaseEvent_mt = Class(FellerBuncherReleaseEvent, Event)

InitEventClass(FellerBuncherReleaseEvent, "FellerBuncherReleaseEvent")

function FellerBuncherReleaseEvent.emptyNew()
	local self = Event.new(FellerBuncherReleaseEvent_mt)

	return self
end

function FellerBuncherReleaseEvent.new(object)
	local self = FellerBuncherReleaseEvent.emptyNew()
	self.object = object

	return self
end

function FellerBuncherReleaseEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)

	self:run(connection)
end

function FellerBuncherReleaseEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
end

function FellerBuncherReleaseEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end

	if self.object ~= nil and self.object:getIsSynchronized() then
		self.object:releaseMountedTrees(true)
	end
end

function FellerBuncherReleaseEvent.sendEvent(vehicle, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(FellerBuncherReleaseEvent.new(vehicle), nil, , vehicle)
		else
			g_client:getServerConnection():sendEvent(FellerBuncherReleaseEvent.new(vehicle))
		end
	end
end
