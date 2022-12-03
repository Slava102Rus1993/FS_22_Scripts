SuperCupDriverEvent = {}
local SuperCupDriverEvent_mt = Class(SuperCupDriverEvent, Event)

InitEventClass(SuperCupDriverEvent, "SuperCupDriverEvent")

function SuperCupDriverEvent.emptyNew()
	local self = Event.new(SuperCupDriverEvent_mt)

	return self
end

function SuperCupDriverEvent.new(object, allowDriving, networkObject)
	local self = SuperCupDriverEvent.emptyNew()
	self.object = object
	self.allowDriving = allowDriving
	self.networkObject = networkObject

	return self
end

function SuperCupDriverEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.networkObject = NetworkUtil.readNodeObject(streamId)
	self.allowDriving = streamReadBool(streamId)

	self:run(connection)
end

function SuperCupDriverEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	NetworkUtil.writeNodeObject(streamId, self.networkObject)
	streamWriteBool(streamId, self.allowDriving)
end

function SuperCupDriverEvent:run(connection)
	self.object:setAllowDriveSuperCup(self.allowDriving, self.networkObject, true)

	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end
end

function SuperCupDriverEvent.sendEvent(vehicle, allowDriving, networkObject, noEventSend)
	if not noEventSend then
		if g_server ~= nil then
			g_server:broadcastEvent(SuperCupDriverEvent.new(vehicle, allowDriving, networkObject), nil, , vehicle)
		else
			g_client:getServerConnection():sendEvent(SuperCupDriverEvent.new(vehicle, allowDriving, networkObject))
		end
	end
end
