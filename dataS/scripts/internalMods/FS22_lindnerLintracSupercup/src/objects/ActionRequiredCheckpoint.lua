ActionRequiredCheckpoint = {}
local ActionRequiredCheckpoint_mt = Class(ActionRequiredCheckpoint, Checkpoint)

function ActionRequiredCheckpoint.registerXMLPaths(schema, basePath)
	schema:register(XMLValueType.STRING, basePath .. ".checkpoint(?)#actionClass", "the checkpoint action classname")
	schema:register(XMLValueType.FLOAT, basePath .. ".checkpoint(?)#vehicleDistance", "the vehicle interaction distance")
	Seesaw.registerXMLPaths(schema, basePath .. ".checkpoint(?).seesaw")
end

function ActionRequiredCheckpoint:new(nodeId, isServer, isClient, action)
	local self = Checkpoint:new(nodeId, isServer, isClient, ActionRequiredCheckpoint_mt)
	self.action = action
	self.object = nil

	return self
end

function ActionRequiredCheckpoint:delete()
	ActionRequiredCheckpoint:superClass().delete(self)

	if self.action ~= nil then
		self.action:delete()
	end
end

function ActionRequiredCheckpoint:writeStream(streamId, connection)
	ActionRequiredCheckpoint:superClass().writeStream(self, streamId, connection)

	if self.action ~= nil then
		self.action:writeStream(streamId, connection)
	end
end

function ActionRequiredCheckpoint:readStream(streamId, connection)
	ActionRequiredCheckpoint:superClass().readStream(self, streamId, connection)

	if self.action ~= nil then
		self.action:readStream(streamId, connection)
	end
end

function ActionRequiredCheckpoint:writeUpdateStream(streamId, connection, dirtyMask)
	ActionRequiredCheckpoint:superClass().writeUpdateStream(self, streamId, connection, dirtyMask)

	if self.action ~= nil then
		self.action:writeUpdateStream(streamId, connection, dirtyMask)
	end
end

function ActionRequiredCheckpoint:readUpdateStream(streamId, timestamp, connection)
	ActionRequiredCheckpoint:superClass().readUpdateStream(self, streamId, timestamp, connection)

	if self.action ~= nil then
		self.action:readUpdateStream(streamId, timestamp, connection)
	end
end

function ActionRequiredCheckpoint:reset()
	ActionRequiredCheckpoint:superClass().reset(self)

	if self.action ~= nil then
		self.action:reset()
	end
end

function ActionRequiredCheckpoint:loadFromXML(xmlFile, baseKey, components, i3dMappings)
	if not ActionRequiredCheckpoint:superClass().loadFromXML(self, xmlFile, baseKey, components, i3dMappings) then
		return false
	end

	local actionClassName = xmlFile:getValue(baseKey .. "#actionClass", "CheckpointAction")
	local actionClass = SuperCupUtil.getClassObject(actionClassName)

	if actionClass ~= nil then
		local action = actionClass:new(self)

		if action:loadFromXML(xmlFile, baseKey, components, i3dMappings) then
			self:setRequiredAction(action)
		end
	end

	return true
end

function ActionRequiredCheckpoint:setRequiredAction(action)
	self.action = action
end

function ActionRequiredCheckpoint:hasPassedCheckpoint()
	if self.action ~= nil then
		self.action:validate({
			self.object
		})

		if not self.action:isFulfilled() then
			return false
		end
	end

	if not ActionRequiredCheckpoint:superClass().hasPassedCheckpoint(self) then
		return false
	end

	return true
end

function ActionRequiredCheckpoint:checkpointTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	ActionRequiredCheckpoint:superClass().checkpointTriggerCallback(self, triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)

	if self.action ~= nil and self.action.checkpointTriggerCallback ~= nil then
		self.action:checkpointTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	end

	if self.isActive and otherId ~= 0 then
		if onEnter then
			local object = g_currentMission:getNodeObject(otherId)
			self.object = object
		elseif onLeave then
			self.object = nil
		end
	end
end
