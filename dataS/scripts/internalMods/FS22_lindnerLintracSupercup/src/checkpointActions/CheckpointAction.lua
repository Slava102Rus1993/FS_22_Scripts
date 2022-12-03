CheckpointAction = {}
local CheckpointAction_mt = Class(CheckpointAction)

function CheckpointAction:new(checkpoint, mt)
	local self = setmetatable({}, mt or CheckpointAction_mt)
	self.checkpoint = checkpoint
	self.fulfilled = false

	return self
end

function CheckpointAction:delete()
end

function CheckpointAction:writeStream(streamId, connection)
end

function CheckpointAction:readStream(streamId, connection)
end

function CheckpointAction:writeUpdateStream(streamId, connection, dirtyMask)
end

function CheckpointAction:readUpdateStream(streamId, timestamp, connection)
end

function CheckpointAction:reset()
	self.fulfilled = false
end

function CheckpointAction:loadFromXML(xmlFile, baseKey, components, i3dMappings)
	return true
end

function CheckpointAction:isFulfilled()
	return self.fulfilled
end
