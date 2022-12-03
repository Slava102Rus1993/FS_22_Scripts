Checkpoint = {}
local Checkpoint_mt = Class(Checkpoint, Object)

InitObjectClass(Checkpoint, "Checkpoint")

function Checkpoint.registerXMLPaths(schema, basePath)
	schema:register(XMLValueType.STRING, basePath .. ".checkpoint(?)#className", "the checkpoint classname")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".checkpoint(?)#triggerNode", "the checkpoint trigger node")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".checkpoint(?)#iconNode", "the checkpoint icon node")
end

function Checkpoint:new(nodeId, isServer, isClient, customMt)
	local self = Object.new(isServer, isClient, customMt or Checkpoint_mt)
	self.nodeId = nodeId
	self.isServer = isServer
	self.isClient = isClient
	self.isActive = false
	self.hasEntered = false
	self.hasEntered = false
	self.actionOnlyFulfillment = false

	return self
end

function Checkpoint:delete()
	if self.triggerNode ~= nil then
		removeTrigger(self.triggerNode)
	end
end

function Checkpoint:writeStream(streamId, connection)
end

function Checkpoint:readStream(streamId, connection)
end

function Checkpoint:writeUpdateStream(streamId, connection, dirtyMask)
end

function Checkpoint:readUpdateStream(streamId, timestamp, connection)
end

function Checkpoint:reset()
	self:setIsActive(false)

	self.hasEntered = false
	self.hasLeft = false
end

function Checkpoint:setIsActive(isActive, noEventSend)
	self.isActive = isActive

	if self.isServer and not noEventSend then
		g_server:broadcastEvent(SuperCupCheckPointEvent.new(self, isActive))
	end

	if self.iconNode ~= nil then
		setVisibility(self.iconNode, isActive)
	end
end

function Checkpoint:hasPassedCheckpoint()
	return self.hasEntered and self.hasLeft or self.actionOnlyFulfillment
end

function Checkpoint:loadFromXML(xmlFile, baseKey, components, i3dMappings)
	self.triggerNode = xmlFile:getValue(baseKey .. "#triggerNode", nil, components, i3dMappings)

	if self.triggerNode ~= nil then
		addTrigger(self.triggerNode, "checkpointTriggerCallback", self)
	end

	self.iconNode = xmlFile:getValue(baseKey .. "#iconNode", nil, components, i3dMappings)

	self:setIsActive(false, true)

	return true
end

function Checkpoint:checkpointTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	if self.isActive then
		if onEnter then
			self.hasEntered = true
		end

		if self.hasEntered and onLeave then
			self.hasLeft = true
		end
	end
end
