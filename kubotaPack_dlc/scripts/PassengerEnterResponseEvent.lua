local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_kubotaPack" then
	return
end

PassengerEnterResponseEvent = {}
local PassengerEnterResponseEvent_mt = Class(PassengerEnterResponseEvent, Event)

InitEventClass(PassengerEnterResponseEvent, "PassengerEnterResponseEvent")

function PassengerEnterResponseEvent.emptyNew()
	local self = Event.new(PassengerEnterResponseEvent_mt)

	return self
end

function PassengerEnterResponseEvent.new(id, isOwner, playerStyle, seatIndex, userId)
	local self = PassengerEnterResponseEvent.emptyNew()
	self.id = id
	self.isOwner = isOwner
	self.playerStyle = playerStyle
	self.seatIndex = seatIndex
	self.userId = userId

	return self
end

function PassengerEnterResponseEvent:readStream(streamId, connection)
	self.id = NetworkUtil.readNodeObjectId(streamId)
	self.isOwner = streamReadBool(streamId)

	if self.playerStyle == nil then
		self.playerStyle = PlayerStyle.new()
	end

	self.playerStyle:readStream(streamId, connection)

	self.seatIndex = streamReadUIntN(streamId, EnterablePassenger.SEAT_INDEX_SEND_NUM_BITS) + 1
	self.userId = streamReadInt32(streamId)

	self:run(connection)
end

function PassengerEnterResponseEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObjectId(streamId, self.id)
	streamWriteBool(streamId, self.isOwner)
	self.playerStyle:writeStream(streamId, connection)
	streamWriteUIntN(streamId, MathUtil.clamp(self.seatIndex - 1, 0, 2^EnterablePassenger.SEAT_INDEX_SEND_NUM_BITS - 1), EnterablePassenger.SEAT_INDEX_SEND_NUM_BITS)
	streamWriteInt32(streamId, self.userId)
end

function PassengerEnterResponseEvent:run(connection)
	local object = NetworkUtil.getObject(self.id)

	if object ~= nil and object:getIsSynchronized() then
		object:enterVehiclePassengerSeat(self.isOwner, self.seatIndex, self.playerStyle, self.userId)
	end
end
