local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

TransportTreeCutEvent = {
	CUSTOM_ENVIRONMENT = g_currentModName
}
local TransportTreeCutEvent_mt = Class(TransportTreeCutEvent, Event)

InitEventClass(TransportTreeCutEvent, "TransportTreeCutEvent")

function TransportTreeCutEvent.emptyNew()
	local self = Event.new(TransportTreeCutEvent_mt)

	return self
end

function TransportTreeCutEvent.new()
	local self = TransportTreeCutEvent.emptyNew()

	return self
end

function TransportTreeCutEvent:readStream(streamId, connection)
	self:run(connection)
end

function TransportTreeCutEvent:writeStream(streamId, connection)
end

function TransportTreeCutEvent:run(connection)
	g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_CRITICAL, g_i18n:getText("ingameNotification_treeTransportCutWarning", TransportTreeCutEvent.CUSTOM_ENVIRONMENT))
end
