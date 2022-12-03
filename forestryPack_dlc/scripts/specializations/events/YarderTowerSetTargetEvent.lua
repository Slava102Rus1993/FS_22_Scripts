local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

YarderTowerSetTargetEvent = {}
local YarderTowerSetTargetEvent_mt = Class(YarderTowerSetTargetEvent, Event)

InitEventClass(YarderTowerSetTargetEvent, "YarderTowerSetTargetEvent")

function YarderTowerSetTargetEvent.emptyNew()
	local self = Event.new(YarderTowerSetTargetEvent_mt)

	return self
end

function YarderTowerSetTargetEvent.new(object, state, x, y, z)
	local self = YarderTowerSetTargetEvent.emptyNew()
	self.object = object
	self.state = state
	self.x = x
	self.y = y
	self.z = z

	return self
end

function YarderTowerSetTargetEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.state = streamReadBool(streamId)

	if self.state then
		self.x = streamReadFloat32(streamId)
		self.y = streamReadFloat32(streamId)
		self.z = streamReadFloat32(streamId)
	end

	self:run(connection)
end

function YarderTowerSetTargetEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)

	if streamWriteBool(streamId, self.state) then
		streamWriteFloat32(streamId, self.x)
		streamWriteFloat32(streamId, self.y)
		streamWriteFloat32(streamId, self.z)
	end
end

function YarderTowerSetTargetEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end

	if self.object ~= nil and self.object:getIsSynchronized() then
		local spec = self.object.spec_yarderTower

		if self.x ~= nil then
			spec.mainRope.isValid = true
			spec.mainRope.target[3] = self.z
			spec.mainRope.target[2] = self.y
			spec.mainRope.target[1] = self.x
		end

		self.object:setYarderTargetActive(self.state, true)
	end
end

function YarderTowerSetTargetEvent.sendEvent(vehicle, state, x, y, z, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(YarderTowerSetTargetEvent.new(vehicle, state, x, y, z), nil, , vehicle)
		else
			g_client:getServerConnection():sendEvent(YarderTowerSetTargetEvent.new(vehicle, state, x, y, z))
		end
	end
end
