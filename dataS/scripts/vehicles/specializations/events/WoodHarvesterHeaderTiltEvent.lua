WoodHarvesterHeaderTiltEvent = {}
local WoodHarvesterHeaderTiltEvent_mt = Class(WoodHarvesterHeaderTiltEvent, Event)

InitStaticEventClass(WoodHarvesterHeaderTiltEvent, "WoodHarvesterHeaderTiltEvent", EventIds.EVENT_WOODHARVESTER_HEADER_TILT)

function WoodHarvesterHeaderTiltEvent.emptyNew()
	local self = Event.new(WoodHarvesterHeaderTiltEvent_mt)

	return self
end

function WoodHarvesterHeaderTiltEvent.new(object, state)
	local self = WoodHarvesterHeaderTiltEvent.emptyNew()
	self.object = object
	self.state = state

	return self
end

function WoodHarvesterHeaderTiltEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.state = streamReadBool(streamId)

	self:run(connection)
end

function WoodHarvesterHeaderTiltEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteBool(streamId, self.state)
end

function WoodHarvesterHeaderTiltEvent:run(connection)
	if self.object ~= nil and self.object:getIsSynchronized() then
		self.object:setWoodHarvesterTiltState(self.state, true)
	end
end

function WoodHarvesterHeaderTiltEvent.sendEvent(object, state, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(WoodHarvesterHeaderTiltEvent.new(object, state), nil, , object)
		else
			g_client:getServerConnection():sendEvent(WoodHarvesterHeaderTiltEvent.new(object, state))
		end
	end
end
