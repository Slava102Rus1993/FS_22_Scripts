UmbilicalHoseCreateEvent = {}
local UmbilicalHoseCreateEvent_mt = Class(UmbilicalHoseCreateEvent, Event)

InitEventClass(UmbilicalHoseCreateEvent, "UmbilicalHoseCreateEvent")

function UmbilicalHoseCreateEvent.emptyNew()
	local self = Event.new(UmbilicalHoseCreateEvent_mt)

	return self
end

function UmbilicalHoseCreateEvent.new(object, componentId, objectId)
	local self = UmbilicalHoseCreateEvent.emptyNew()
	self.object = object
	self.componentId = componentId
	self.objectId = objectId

	return self
end

function UmbilicalHoseCreateEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.componentId = streamReadUIntN(streamId, 2) + 1

	if streamReadBool(streamId) then
		self.objectId = NetworkUtil.readNodeObjectId(streamId)
	end

	self:run(connection)
end

function UmbilicalHoseCreateEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteUIntN(streamId, self.componentId - 1, 2)

	if streamWriteBool(streamId, self.objectId ~= nil) then
		NetworkUtil.writeNodeObjectId(streamId, self.objectId)
	end
end

function UmbilicalHoseCreateEvent:run(connection)
	if self.object ~= nil and self.object:getIsSynchronized() then
		self.object:createUmbilicalHose(self.componentId, self.objectId)
	end
end
