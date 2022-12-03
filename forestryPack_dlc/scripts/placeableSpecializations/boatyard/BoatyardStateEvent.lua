local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

BoatyardStateEvent = {}
local BoatyardStateEvent_mt = Class(BoatyardStateEvent, Event)

InitEventClass(BoatyardStateEvent, "BoatyardStateEvent")

function BoatyardStateEvent.emptyNew()
	local self = Event.new(BoatyardStateEvent_mt)

	return self
end

function BoatyardStateEvent.new(boatyard, stateIndex)
	local self = BoatyardStateEvent.emptyNew()
	self.boatyard = boatyard
	self.stateIndex = stateIndex

	return self
end

function BoatyardStateEvent:readStream(streamId, connection)
	self.boatyard = NetworkUtil.readNodeObject(streamId)
	self.stateIndex = streamReadUInt8(streamId)

	self:run(connection)
end

function BoatyardStateEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.boatyard)
	streamWriteUInt8(streamId, self.stateIndex)
end

function BoatyardStateEvent:run(connection)
	if self.boatyard ~= nil then
		self.boatyard:setState(self.stateIndex)
	end
end
