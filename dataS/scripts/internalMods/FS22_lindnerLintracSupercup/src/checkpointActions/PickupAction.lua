PickupAction = {}
local PickupAction_mt = Class(PickupAction, CheckpointAction)

function PickupAction:new(checkpoint)
	local self = CheckpointAction:new(checkpoint, PickupAction_mt)
	checkpoint.actionOnlyFulfillment = true
	self.vehicleToPickup = nil

	return self
end

function PickupAction:reset()
	PickupAction:superClass().reset(self)

	self.vehicleToPickup = nil
end

function PickupAction:loadFromXML(xmlFile, baseKey, components, i3dMappings)
	self.distanceThreshold = xmlFile:getValue(baseKey .. "#vehicleDistance", 2)

	return true
end

function PickupAction:validate(params)
	local object = unpack(params)

	if object == nil then
		local vehicleNode = self.vehicleToPickup.rootNode

		if self.distanceThreshold < calcDistanceFrom(self.checkpoint.triggerNode, vehicleNode) and self.vehicleToPickup.getAttacherVehicle ~= nil and self.vehicleToPickup:getAttacherVehicle() ~= nil then
			self.fulfilled = true
		end
	end
end

function PickupAction:checkpointTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	if onEnter and self.vehicleToPickup == nil then
		local object = g_currentMission:getNodeObject(otherId)

		if object ~= nil then
			self.vehicleToPickup = object
		end
	end
end
