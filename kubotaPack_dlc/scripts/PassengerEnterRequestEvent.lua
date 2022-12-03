local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_kubotaPack" then
	return
end

PassengerEnterRequestEvent = {}
local PassengerEnterRequestEvent_mt = Class(PassengerEnterRequestEvent, Event)

InitEventClass(PassengerEnterRequestEvent, "PassengerEnterRequestEvent")

function PassengerEnterRequestEvent.emptyNew()
	local self = Event.new(PassengerEnterRequestEvent_mt)

	return self
end

function PassengerEnterRequestEvent.new(object, playerStyle, seatIndex)
	local self = PassengerEnterRequestEvent.emptyNew()
	self.object = object
	self.objectId = NetworkUtil.getObjectId(self.object)
	self.seatIndex = seatIndex
	self.playerStyle = playerStyle

	return self
end

function PassengerEnterRequestEvent:readStream(streamId, connection)
	self.objectId = NetworkUtil.readNodeObjectId(streamId)
	self.seatIndex = streamReadUIntN(streamId, EnterablePassenger.SEAT_INDEX_SEND_NUM_BITS) + 1

	if self.playerStyle == nil then
		self.playerStyle = PlayerStyle.new()
	end

	self.playerStyle:readStream(streamId, connection)

	self.object = NetworkUtil.getObject(self.objectId)

	self:run(connection)
end

function PassengerEnterRequestEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObjectId(streamId, self.objectId)
	streamWriteUIntN(streamId, MathUtil.clamp(self.seatIndex - 1, 0, 2^EnterablePassenger.SEAT_INDEX_SEND_NUM_BITS - 1), EnterablePassenger.SEAT_INDEX_SEND_NUM_BITS)
	self.playerStyle:writeStream(streamId, connection)
end

function PassengerEnterRequestEvent:run(connection)
	if self.object ~= nil and self.object:getIsSynchronized() and self.object:getIsPassengerSeatIndexAvailable(self.seatIndex) then
		local userId = g_currentMission.userManager:getUserIdByConnection(connection)

		g_server:broadcastEvent(PassengerEnterResponseEvent.new(self.objectId, false, self.playerStyle, self.seatIndex, userId), true, connection, self.object, false, nil, true)
		connection:sendEvent(PassengerEnterResponseEvent.new(self.objectId, true, self.playerStyle, self.seatIndex, userId))
	end
end
