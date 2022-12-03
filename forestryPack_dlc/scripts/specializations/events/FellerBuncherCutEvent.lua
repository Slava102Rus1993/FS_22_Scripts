local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

FellerBuncherCutEvent = {}
local FellerBuncherCutEvent_mt = Class(FellerBuncherCutEvent, Event)

InitEventClass(FellerBuncherCutEvent, "FellerBuncherCutEvent")

function FellerBuncherCutEvent.emptyNew()
	local self = Event.new(FellerBuncherCutEvent_mt)

	return self
end

function FellerBuncherCutEvent.new(object)
	local self = FellerBuncherCutEvent.emptyNew()
	self.object = object

	return self
end

function FellerBuncherCutEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)

	self:run(connection)
end

function FellerBuncherCutEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
end

function FellerBuncherCutEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end

	if self.object ~= nil and self.object:getIsSynchronized() then
		self.object:cutTree(true)
	end
end

function FellerBuncherCutEvent.sendEvent(vehicle, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(FellerBuncherCutEvent.new(vehicle), nil, , vehicle)
		else
			g_client:getServerConnection():sendEvent(FellerBuncherCutEvent.new(vehicle))
		end
	end
end
