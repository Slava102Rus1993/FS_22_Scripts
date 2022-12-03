UmbilicalHoseSpawnEvent = {}
local UmbilicalHoseSpawnEvent_mt = Class(UmbilicalHoseSpawnEvent, Event)

InitEventClass(UmbilicalHoseSpawnEvent, "UmbilicalHoseSpawnEvent")

function UmbilicalHoseSpawnEvent.emptyNew()
	local self = Event.new(UmbilicalHoseSpawnEvent_mt)

	return self
end

function UmbilicalHoseSpawnEvent.new(umbilicalHose, x, y, z)
	local self = UmbilicalHoseSpawnEvent.emptyNew()
	self.umbilicalHose = umbilicalHose
	self.x = x
	self.y = y
	self.z = z

	return self
end

function UmbilicalHoseSpawnEvent:readStream(streamId, connection)
	self.umbilicalHose = NetworkUtil.readNodeObject(streamId)
	self.x = streamReadFloat32(streamId)
	self.y = streamReadFloat32(streamId)
	self.z = streamReadFloat32(streamId)

	self:run(connection)
end

function UmbilicalHoseSpawnEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.umbilicalHose)
	streamWriteFloat32(streamId, self.x)
	streamWriteFloat32(streamId, self.y)
	streamWriteFloat32(streamId, self.z)
end

function UmbilicalHoseSpawnEvent:run(connection)
	if self.umbilicalHose ~= nil then
		self.umbilicalHose:addAtWorldPosition(self.x, self.y, self.z)
	end
end
