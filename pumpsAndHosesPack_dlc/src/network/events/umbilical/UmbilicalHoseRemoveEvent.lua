UmbilicalHoseRemoveEvent = {}
local UmbilicalHoseRemoveEvent_mt = Class(UmbilicalHoseRemoveEvent, Event)

InitEventClass(UmbilicalHoseRemoveEvent, "UmbilicalHoseRemoveEvent")

function UmbilicalHoseRemoveEvent.emptyNew()
	local self = Event.new(UmbilicalHoseRemoveEvent_mt)

	return self
end

function UmbilicalHoseRemoveEvent.new(umbilicalHose, atTail)
	local self = UmbilicalHoseRemoveEvent.emptyNew()
	self.umbilicalHose = umbilicalHose
	self.atTail = atTail

	return self
end

function UmbilicalHoseRemoveEvent:readStream(streamId, connection)
	self.umbilicalHose = NetworkUtil.readNodeObject(streamId)
	self.atTail = streamReadBool(streamId)

	self:run(connection)
end

function UmbilicalHoseRemoveEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.umbilicalHose)
	streamWriteBool(streamId, self.atTail)
end

function UmbilicalHoseRemoveEvent:run(connection)
	if self.umbilicalHose ~= nil then
		self.umbilicalHose:removeControlPoint(self.atTail)
	end
end
