local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

DeadwoodMissionTreeEvent = {
	CUSTOM_ENVIRONMENT = g_currentModName
}
local DeadwoodMissionTreeEvent_mt = Class(DeadwoodMissionTreeEvent, Event)

InitEventClass(DeadwoodMissionTreeEvent, "DeadwoodMissionTreeEvent")

function DeadwoodMissionTreeEvent.emptyNew()
	local self = Event.new(DeadwoodMissionTreeEvent_mt)

	return self
end

function DeadwoodMissionTreeEvent.new(mission)
	local self = DeadwoodMissionTreeEvent.emptyNew()
	self.mission = mission

	return self
end

function DeadwoodMissionTreeEvent:readStream(streamId, connection)
	self.mission = NetworkUtil.readNodeObject(streamId)

	self.mission:readDeadTreesStream(streamId)
	self.mission:raiseActive()
end

function DeadwoodMissionTreeEvent:writeStream(streamId, connection)
	assert(not connection:getIsServer(), "DeadwoodMissionTreeEvent is a server to client event")
	NetworkUtil.writeNodeObject(streamId, self.mission)
	self.mission:writeDeadTreesStream(streamId)
end
