local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

RollercoasterStateEvent = {}
local RollercoasterStateEvent_mt = Class(RollercoasterStateEvent, Event)

InitEventClass(RollercoasterStateEvent, "RollercoasterStateEvent")

function RollercoasterStateEvent.emptyNew()
	local self = Event.new(RollercoasterStateEvent_mt)

	return self
end

function RollercoasterStateEvent.new(rollercoaster, stateIndex)
	local self = RollercoasterStateEvent.emptyNew()
	self.rollercoaster = rollercoaster
	self.stateIndex = stateIndex

	return self
end

function RollercoasterStateEvent:readStream(streamId, connection)
	self.rollercoaster = NetworkUtil.readNodeObject(streamId)
	self.stateIndex = streamReadUInt8(streamId)

	self:run(connection)
end

function RollercoasterStateEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.rollercoaster)
	streamWriteUInt8(streamId, self.stateIndex)
end

function RollercoasterStateEvent:run(connection)
	if self.rollercoaster ~= nil and self.rollercoaster:getIsSynchronized() then
		self.rollercoaster:setState(self.stateIndex)
	end
end
