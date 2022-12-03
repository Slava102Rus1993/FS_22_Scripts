UmbilicalReelUnloadEvent = {}
local UmbilicalReelUnloadEvent_mt = Class(UmbilicalReelUnloadEvent, Event)

InitEventClass(UmbilicalReelUnloadEvent, "UmbilicalReelUnloadEvent")

function UmbilicalReelUnloadEvent.emptyNew()
	local self = Event.new(UmbilicalReelUnloadEvent_mt)

	return self
end

function UmbilicalReelUnloadEvent.new(object, isOverloading, overloadingDirection)
	local self = UmbilicalReelUnloadEvent.emptyNew()
	self.object = object

	return self
end

function UmbilicalReelUnloadEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)

	self:run(connection)
end

function UmbilicalReelUnloadEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
end

function UmbilicalReelUnloadEvent:run(connection)
	if not connection:getIsServer() and self.object ~= nil and self.object:getIsSynchronized() then
		self.object:unloadReel()
	end
end
