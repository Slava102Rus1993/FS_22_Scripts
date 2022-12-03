local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

SawmillWoodTriggerStartAnimationEvent = {}
local SawmillWoodTriggerStartAnimationEvent_mt = Class(SawmillWoodTriggerStartAnimationEvent, Event)

InitEventClass(SawmillWoodTriggerStartAnimationEvent, "SawmillWoodTriggerStartAnimationEvent")

function SawmillWoodTriggerStartAnimationEvent.emptyNew()
	local self = Event.new(SawmillWoodTriggerStartAnimationEvent_mt)

	return self
end

function SawmillWoodTriggerStartAnimationEvent.new(object, clipIndex)
	local self = SawmillWoodTriggerStartAnimationEvent.emptyNew()
	self.object = object
	self.clipIndex = clipIndex

	return self
end

function SawmillWoodTriggerStartAnimationEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.clipIndex = streamReadUIntN(streamId, 3)

	self:run(connection)
end

function SawmillWoodTriggerStartAnimationEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteUIntN(streamId, self.clipIndex, 3)
end

function SawmillWoodTriggerStartAnimationEvent:run(connection)
	if self.object ~= nil then
		self.object:playAnimation(self.clipIndex)
	end
end
