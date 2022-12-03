local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

WoodContainerWrongLengthEvent = {}
local WoodContainerWrongLengthEvent_mt = Class(WoodContainerWrongLengthEvent, Event)

InitEventClass(WoodContainerWrongLengthEvent, "WoodContainerWrongLengthEvent")

function WoodContainerWrongLengthEvent.emptyNew()
	local self = Event.new(WoodContainerWrongLengthEvent_mt)

	return self
end

function WoodContainerWrongLengthEvent.new(object, state, x, y, z)
	local self = WoodContainerWrongLengthEvent.emptyNew()
	self.object = object

	return self
end

function WoodContainerWrongLengthEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)

	self:run(connection)
end

function WoodContainerWrongLengthEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
end

function WoodContainerWrongLengthEvent:run(connection)
	if self.object ~= nil and self.object:getIsSynchronized() and g_currentMission:getFarmId() == self.object:getOwnerFarmId() and calcDistanceFrom(getCamera(), self.object.rootNode) < 40 then
		local spec = self.object.spec_woodContainer

		g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_CRITICAL, string.format(spec.texts.warningWoodContainerWrongLength, spec.targetLength))
	end
end
