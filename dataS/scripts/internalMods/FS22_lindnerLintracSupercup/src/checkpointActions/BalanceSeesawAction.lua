BalanceSeesawAction = {}
local BalanceSeesawAction_mt = Class(BalanceSeesawAction, CheckpointAction)

function BalanceSeesawAction:new(checkpoint)
	local self = CheckpointAction:new(checkpoint, BalanceSeesawAction_mt)
	checkpoint.actionOnlyFulfillment = true
	self.seesaw = Seesaw:new(checkpoint.nodeId, checkpoint.isServer, checkpoint.isClient)
	self.seesawTimer = Timer:new(5000, function ()
		self.fulfilled = true

		self.seesaw:setBeaconLightVisibility(false)
	end)

	return self
end

function BalanceSeesawAction:delete()
	BalanceSeesawAction:superClass().delete(self)
	self.seesaw:delete()
end

function BalanceSeesawAction:writeStream(streamId, connection)
	BalanceSeesawAction:superClass().writeStream(self, streamId, connection)
	NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.seesaw))
	self.seesaw:writeStream(streamId, connection)
	g_server:registerObjectInStream(connection, self.seesaw)
end

function BalanceSeesawAction:readStream(streamId, connection)
	BalanceSeesawAction:superClass().readStream(self, streamId, connection)

	local seesawId = NetworkUtil.readNodeObjectId(streamId)

	self.seesaw:readStream(streamId, connection)
	g_client:finishRegisterObject(self.seesaw, seesawId)
end

function BalanceSeesawAction:writeUpdateStream(streamId, connection, dirtyMask)
	BalanceSeesawAction:superClass().writeUpdateStream(self, streamId, connection, dirtyMask)
	self.seesaw:writeUpdateStream(streamId, connection, dirtyMask)
end

function BalanceSeesawAction:readUpdateStream(streamId, timestamp, connection)
	BalanceSeesawAction:superClass().readUpdateStream(self, streamId, timestamp, connection)
	self.seesaw:readUpdateStream(streamId, timestamp, connection)
end

function BalanceSeesawAction:reset()
	BalanceSeesawAction:superClass().reset(self)
	self.seesaw:reset()
end

function BalanceSeesawAction:loadFromXML(xmlFile, baseKey, components, i3dMappings)
	self.seesaw:loadFromXML(xmlFile, baseKey, components, i3dMappings)
	self.seesaw:register(true)

	return true
end

function BalanceSeesawAction:validate(params)
	if not self.fulfilled then
		local isSeesawHorizontal = self.seesaw:isHorizontal()

		self.seesaw:setBeaconLightVisibility(isSeesawHorizontal)

		if isSeesawHorizontal then
			if not self.seesawTimer:isRunning() then
				self.seesawTimer:start()
			end
		elseif self.seesawTimer:isRunning() then
			self.seesawTimer:clear()
		end
	end
end
