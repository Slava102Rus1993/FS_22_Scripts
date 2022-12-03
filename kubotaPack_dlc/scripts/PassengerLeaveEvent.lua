local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_kubotaPack" then
	return
end

PassengerLeaveEvent = {}
local PassengerLeaveEvent_mt = Class(PassengerLeaveEvent, Event)

InitEventClass(PassengerLeaveEvent, "PassengerLeaveEvent")

function PassengerLeaveEvent.emptyNew()
	local self = Event.new(PassengerLeaveEvent_mt)

	return self
end

function PassengerLeaveEvent.new(object, seatIndex, isSeatSwitch)
	local self = PassengerLeaveEvent.emptyNew()
	self.object = object
	self.seatIndex = seatIndex
	self.isSeatSwitch = isSeatSwitch

	return self
end

function PassengerLeaveEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.seatIndex = streamReadUIntN(streamId, EnterablePassenger.SEAT_INDEX_SEND_NUM_BITS) + 1
	self.isSeatSwitch = streamReadBool(streamId)

	self:run(connection)
end

function PassengerLeaveEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteUIntN(streamId, MathUtil.clamp(self.seatIndex - 1, 0, 2^EnterablePassenger.SEAT_INDEX_SEND_NUM_BITS - 1), EnterablePassenger.SEAT_INDEX_SEND_NUM_BITS)
	streamWriteBool(streamId, self.isSeatSwitch)
end

function PassengerLeaveEvent:run(connection)
	if self.object ~= nil and self.object:getIsSynchronized() then
		if not connection:getIsServer() then
			g_server:broadcastEvent(PassengerLeaveEvent.new(self.object, self.seatIndex, self.isSeatSwitch), nil, connection, self.object)
		end

		self.object:leavePassengerSeat(false, self.seatIndex, self.isSeatSwitch)
	end
end
