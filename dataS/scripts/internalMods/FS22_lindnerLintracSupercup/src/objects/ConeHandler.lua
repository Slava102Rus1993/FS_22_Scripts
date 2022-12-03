ConeHandler = {}
local ConeHandler_mt = Class(ConeHandler, Object)

InitObjectClass(ConeHandler, "ConeHandler")

function ConeHandler.registerXMLPaths(schema, basePath)
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".cone(?)#node", "the cone node")
end

function ConeHandler:new(nodeId, modDirectory, isServer, isClient, mt)
	local self = Object.new(isServer, isClient, mt or ConeHandler_mt)
	self.nodeId = nodeId
	self.modDirectory = modDirectory
	self.isServer = isServer
	self.isClient = isClient
	self.cones = {}
	self.activeCones = {}
	self.actionListeners = {}

	return self
end

function ConeHandler:delete()
	for _, cone in ipairs(self.cones) do
		self:destroyCone(cone)
	end
end

function ConeHandler:readStream(streamId, connection)
	for _, cone in ipairs(self.cones) do
		cone:readStream(streamId, connection)
	end

	ConeHandler:superClass().readStream(self, streamId, connection)
end

function ConeHandler:writeStream(streamId, connection)
	for _, cone in ipairs(self.cones) do
		cone:writeStream(streamId, connection)
	end

	ConeHandler:superClass().writeStream(self, streamId, connection)
end

function ConeHandler:loadFromXML(xmlFile, baseKey, components, i3dMappings)
	local i = 0

	while true do
		local key = ("%s.cones.cone(%d)"):format(baseKey, i)

		if not xmlFile:hasProperty(key) then
			break
		end

		local node = xmlFile:getValue(key .. "#node", nil, components, i3dMappings)

		if node ~= nil then
			self:spawnConeAt(node)
		end

		i = i + 1
	end
end

function ConeHandler:add(cone)
	table.insert(self.cones, cone)
end

function ConeHandler:spawnCone(x, y, z)
	local cone = Cone:new(self.isServer, self.isClient)

	cone:load(self.modDirectory .. "arena/cone.i3d")
	cone:link(self.nodeId)
	cone:setPosition(x, y, z)
	self:add(cone)

	return cone
end

function ConeHandler:spawnConeAt(node)
	local x, y, z = getWorldTranslation(node)

	self:spawnCone(x, y, z)
end

function ConeHandler:destroyCone(cone)
	cone:delete()
end

function ConeHandler:coneLostBall(cone)
	self:setLostBallCount(self.lostBallCount + 1)
	table.removeElement(self.activeCones, cone)
end

function ConeHandler:setLostBallCount(count, noEventSend)
	if count ~= self.lostBallCount then
		self.lostBallCount = count

		for _, actionListener in ipairs(self.actionListeners) do
			actionListener(count)
		end

		if self.isServer and not noEventSend then
			g_server:broadcastEvent(SuperCupPenaltyEvent.new(self, count), nil, , self)
		end
	end
end

function ConeHandler:getLostBallCount()
	return self.lostBallCount
end

function ConeHandler:reset()
	for _, cone in ipairs(self.cones) do
		cone:reset()
	end

	self:setLostBallCount(0)

	self.activeCones = table.copy(self.cones)
end

function ConeHandler:update(dt)
	for _, cone in ipairs(self.activeCones) do
		cone:update(dt)

		if cone.lostBall then
			self:coneLostBall(cone)
		end
	end
end

function ConeHandler:addActionListener(actionListener)
	SuperCupUtil.addToListIfNotExists(actionListener, self.actionListeners)
end

function ConeHandler:removeActionListener(actionListener)
	table.removeElement(self.actionListeners, actionListener)
end

function ConeHandler:getActionListeners()
	return self.actionListeners
end
