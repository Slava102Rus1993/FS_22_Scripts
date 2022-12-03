UmbilicalReelOverloadEvent = {}
local UmbilicalReelOverloadEvent_mt = Class(UmbilicalReelOverloadEvent, Event)

InitEventClass(UmbilicalReelOverloadEvent, "UmbilicalReelOverloadEvent")

function UmbilicalReelOverloadEvent.emptyNew()
	local self = Event.new(UmbilicalReelOverloadEvent_mt)

	return self
end

function UmbilicalReelOverloadEvent.new(object, targetObject, isOverloading, overloadingDirection)
	local self = UmbilicalReelOverloadEvent.emptyNew()
	self.object = object
	self.targetObject = targetObject
	self.isOverloading = isOverloading
	self.overloadingDirection = overloadingDirection

	return self
end

function UmbilicalReelOverloadEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.targetObject = NetworkUtil.readNodeObject(streamId)
	self.isOverloading = streamReadBool(streamId)
	local isWinding = streamReadBool(streamId)
	self.overloadingDirection = isWinding and UmbilicalReel.WIND_DIRECTION or UmbilicalReel.UNWIND_DIRECTION

	self:run(connection)
end

function UmbilicalReelOverloadEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	NetworkUtil.writeNodeObject(streamId, self.targetObject)
	streamWriteBool(streamId, self.isOverloading)
	streamWriteBool(streamId, self.overloadingDirection == UmbilicalReel.WIND_DIRECTION)
end

function UmbilicalReelOverloadEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end

	self.object:setIsOverloading(self.targetObject, self.isOverloading, self.overloadingDirection, true)
end

function UmbilicalReelOverloadEvent.sendEvent(object, targetObject, isOverloading, overloadingDirection, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(UmbilicalReelOverloadEvent.new(object, targetObject, isOverloading, overloadingDirection), nil, , object)
		else
			g_client:getServerConnection():sendEvent(UmbilicalReelOverloadEvent.new(object, targetObject, isOverloading, overloadingDirection))
		end
	end
end
