local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

RollercoasterPassengerEnterResponseEvent = {}
local RollercoasterPassengerEnterResponseEvent_mt = Class(RollercoasterPassengerEnterResponseEvent, Event)

InitEventClass(RollercoasterPassengerEnterResponseEvent, "RollercoasterPassengerEnterResponseEvent")

function RollercoasterPassengerEnterResponseEvent.emptyNew()
	local self = Event.new(RollercoasterPassengerEnterResponseEvent_mt)

	return self
end

function RollercoasterPassengerEnterResponseEvent.new(rollercoaster, player, seatIndex)
	local self = RollercoasterPassengerEnterResponseEvent.emptyNew()
	self.rollercoaster = rollercoaster
	self.player = player
	self.seatIndex = seatIndex

	return self
end

function RollercoasterPassengerEnterResponseEvent:readStream(streamId, connection)
	self.rollercoaster = NetworkUtil.readNodeObject(streamId)
	self.player = NetworkUtil.readNodeObject(streamId)
	self.seatIndex = streamReadUIntN(streamId, PlaceableRollercoaster.SEAT_INDEX_NUM_BITS) + 1

	self:run(connection)
end

function RollercoasterPassengerEnterResponseEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.rollercoaster)
	NetworkUtil.writeNodeObject(streamId, self.player)
	streamWriteUIntN(streamId, self.seatIndex - 1, PlaceableRollercoaster.SEAT_INDEX_NUM_BITS)
end

function RollercoasterPassengerEnterResponseEvent:run(connection)
	if self.rollercoaster ~= nil and self.rollercoaster:getIsSynchronized() then
		self.rollercoaster:enterRide(self.seatIndex, self.player)
	end
end
