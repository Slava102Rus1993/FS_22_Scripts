ExtendedSprayerAmountEvent = {}
local ExtendedSprayerAmountEvent_mt = Class(ExtendedSprayerAmountEvent, Event)

InitEventClass(ExtendedSprayerAmountEvent, "ExtendedSprayerAmountEvent")

function ExtendedSprayerAmountEvent:emptyNew()
	local self = Event.new(ExtendedSprayerAmountEvent_mt)

	return self
end

function ExtendedSprayerAmountEvent.new(object, automaticMode, manualValue)
	local self = ExtendedSprayerAmountEvent:emptyNew()
	self.object = object
	self.automaticMode = automaticMode
	self.manualValue = manualValue

	return self
end

function ExtendedSprayerAmountEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.automaticMode = streamReadBool(streamId)

	if not self.automaticMode then
		self.manualValue = streamReadUIntN(streamId, 5)
	end

	self:run(connection)
end

function ExtendedSprayerAmountEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)

	if not streamWriteBool(streamId, self.automaticMode) then
		streamWriteUIntN(streamId, self.manualValue, 5)
	end
end

function ExtendedSprayerAmountEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end

	if self.object ~= nil and self.object:getIsSynchronized() then
		self.object:setSprayAmountAutoMode(self.automaticMode, true)

		if not self.automaticMode then
			self.object:setSprayAmountManualValue(self.manualValue, true)
		end
	end
end

function ExtendedSprayerAmountEvent.sendEvent(object, automaticMode, manualValue, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(ExtendedSprayerAmountEvent.new(object, automaticMode, manualValue), nil, , object)
		else
			g_client:getServerConnection():sendEvent(ExtendedSprayerAmountEvent.new(object, automaticMode, manualValue))
		end
	end
end
