ParkAction = {}
local ParkAction_mt = Class(ParkAction, CheckpointAction)

function ParkAction:new(checkpoint)
	local self = CheckpointAction:new(checkpoint, ParkAction_mt)
	checkpoint.actionOnlyFulfillment = true
	self.vehicleToPark = nil

	return self
end

function ParkAction:reset()
	ParkAction:superClass().reset(self)

	self.vehicleToPark = nil
end

function ParkAction:validate(params)
	local object = unpack(params)

	if object ~= nil and object == self.vehicleToPark and object.getAttacherVehicle ~= nil and object:getAttacherVehicle() == nil then
		self.fulfilled = true
	end
end

function ParkAction:checkpointTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	if onEnter and self.vehicleToPark == nil then
		local object = g_currentMission:getNodeObject(otherId)

		if object ~= nil then
			self.vehicleToPark = object
		end
	end
end
