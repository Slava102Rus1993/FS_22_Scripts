ObjectLowerAction = {}
local ObjectLowerAction_mt = Class(ObjectLowerAction, CheckpointAction)

function ObjectLowerAction:new(checkpoint)
	local self = CheckpointAction:new(checkpoint, ObjectLowerAction_mt)
	self.didEnterOnHigherState = false

	return self
end

function ObjectLowerAction:reset()
	ObjectLowerAction:superClass().reset(self)

	self.didEnterOnHigherState = false
end

function ObjectLowerAction:checkIfObjectDidEnterLowered(object)
	if object ~= nil and object.getAllowsLowering ~= nil and object:getAllowsLowering() then
		local isLowered = object:getIsLowered()

		if not self.didEnterOnHigherState and not isLowered then
			self.didEnterOnHigherState = true
		end
	end
end

function ObjectLowerAction:validate(params)
	local object = unpack(params)

	if object ~= nil and object.getAllowsLowering ~= nil and object:getAllowsLowering() then
		local isLowered = object:getIsLowered()

		if self.didEnterOnHigherState and isLowered and not self.fulfilled then
			self.fulfilled = true
		end
	end
end

function ObjectLowerAction:checkpointTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	if onEnter and not self.didEnterOnHigherState then
		self:checkIfObjectDidEnterLowered(g_currentMission:getNodeObject(otherId))
	end
end
