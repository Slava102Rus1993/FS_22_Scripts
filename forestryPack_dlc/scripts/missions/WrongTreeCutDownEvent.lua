local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

WrongTreeCutDownEvent = {
	CUSTOM_ENVIRONMENT = g_currentModName
}
local WrongTreeCutDownEvent_mt = Class(WrongTreeCutDownEvent, Event)

InitEventClass(WrongTreeCutDownEvent, "WrongTreeCutDownEvent")

function WrongTreeCutDownEvent.emptyNew()
	local self = Event.new(WrongTreeCutDownEvent_mt)

	return self
end

function WrongTreeCutDownEvent.new()
	local self = WrongTreeCutDownEvent.emptyNew()

	return self
end

function WrongTreeCutDownEvent:readStream(streamId, connection)
	self:run(connection)
end

function WrongTreeCutDownEvent:writeStream(streamId, connection)
end

function WrongTreeCutDownEvent:run(connection)
	g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_CRITICAL, g_i18n:getText("ingameNotification_wrongMissionTreeCutDown", WrongTreeCutDownEvent.CUSTOM_ENVIRONMENT))
end
