local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

YarderTowerFollowModeEvent = {}
local YarderTowerFollowModeEvent_mt = Class(YarderTowerFollowModeEvent, Event)

InitEventClass(YarderTowerFollowModeEvent, "YarderTowerFollowModeEvent")

function YarderTowerFollowModeEvent.emptyNew()
	local self = Event.new(YarderTowerFollowModeEvent_mt)

	return self
end

function YarderTowerFollowModeEvent.new(object, state)
	local self = YarderTowerFollowModeEvent.emptyNew()
	self.object = object
	self.state = state

	return self
end

function YarderTowerFollowModeEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.state = streamReadUIntN(streamId, 2)

	self:run(connection)
end

function YarderTowerFollowModeEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteUIntN(streamId, self.state, 2)
end

function YarderTowerFollowModeEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end

	if self.object ~= nil and self.object:getIsSynchronized() then
		self.object:setYarderCarriageFollowMode(self.state, connection, true)
	end
end

function YarderTowerFollowModeEvent.sendEvent(vehicle, state, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(YarderTowerFollowModeEvent.new(vehicle, state), nil, , vehicle)
		else
			g_client:getServerConnection():sendEvent(YarderTowerFollowModeEvent.new(vehicle, state))
		end
	end
end
