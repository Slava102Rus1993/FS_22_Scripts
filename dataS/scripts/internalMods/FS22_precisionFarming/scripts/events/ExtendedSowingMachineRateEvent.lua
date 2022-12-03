ExtendedSowingMachineRateEvent = {}
local ExtendedSowingMachineRateEvent_mt = Class(ExtendedSowingMachineRateEvent, Event)

InitEventClass(ExtendedSowingMachineRateEvent, "ExtendedSowingMachineRateEvent")

function ExtendedSowingMachineRateEvent:emptyNew()
	local self = Event.new(ExtendedSowingMachineRateEvent_mt)

	return self
end

function ExtendedSowingMachineRateEvent.new(object, automaticMode, manualValue)
	local self = ExtendedSowingMachineRateEvent:emptyNew()
	self.object = object
	self.automaticMode = automaticMode
	self.manualValue = manualValue

	return self
end

function ExtendedSowingMachineRateEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.automaticMode = streamReadBool(streamId)

	if not self.automaticMode then
		self.manualValue = streamReadUIntN(streamId, 2)
	end

	self:run(connection)
end

function ExtendedSowingMachineRateEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)

	if not streamWriteBool(streamId, self.automaticMode) then
		streamWriteUIntN(streamId, self.manualValue, 2)
	end
end

function ExtendedSowingMachineRateEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end

	if self.object ~= nil and self.object:getIsSynchronized() then
		self.object:setSeedRateAutoMode(self.automaticMode, true)

		if not self.automaticMode then
			self.object:setManualSeedRate(self.manualValue, true)
		end
	end
end

function ExtendedSowingMachineRateEvent.sendEvent(object, automaticMode, manualValue, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(ExtendedSowingMachineRateEvent.new(object, automaticMode, manualValue), nil, , object)
		else
			g_client:getServerConnection():sendEvent(ExtendedSowingMachineRateEvent.new(object, automaticMode, manualValue))
		end
	end
end
