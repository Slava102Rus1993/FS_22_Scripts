local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_vermeerPack" then
	return
end

BaleCounterResetEvent = {}
local BaleCounterResetEvent_mt = Class(BaleCounterResetEvent, Event)

InitEventClass(BaleCounterResetEvent, "BaleCounterResetEvent")

function BaleCounterResetEvent.emptyNew()
	local self = Event.new(BaleCounterResetEvent_mt)

	return self
end

function BaleCounterResetEvent.new(object)
	local self = BaleCounterResetEvent.emptyNew()
	self.object = object

	return self
end

function BaleCounterResetEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)

	self:run(connection)
end

function BaleCounterResetEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
end

function BaleCounterResetEvent:run(connection)
	if self.object ~= nil and self.object:getIsSynchronized() then
		self.object:doBaleCounterReset(true)
	end
end

function BaleCounterResetEvent.sendEvent(vehicle, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(BaleCounterResetEvent.new(vehicle), nil, , vehicle)
		else
			g_client:getServerConnection():sendEvent(BaleCounterResetEvent.new(vehicle))
		end
	end
end
