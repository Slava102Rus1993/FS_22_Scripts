SetupState = {}
local SetupState_mt = Class(SetupState, AbstractState)

function SetupState:new(id, stateMachine, mission, checkpoints, vehicles, vehicleList, custom_mt)
	local self = AbstractState:new(id, stateMachine, custom_mt or SetupState_mt)
	self.isServer = mission:getIsServer()
	self.mission = mission
	self.checkpoints = checkpoints
	self.vehicles = vehicles
	self.vehicleList = vehicleList
	self.runVehicle = nil
	self.spawnTimer = nil
	self.playerUserId = nil

	return self
end

function SetupState:delete()
	SetupState:superClass().delete(self)

	if self.spawnTimer ~= nil then
		self.spawnTimer:delete()
	end
end

function SetupState:onEnter(playerUserId)
	self.playerUserId = playerUserId

	SetupState:superClass().onEnter(self)

	for _, checkpoint in ipairs(self.checkpoints) do
		checkpoint:reset()
	end

	if self.isServer then
		self:spawn()
	end
end

function SetupState:onExit()
	SetupState:superClass().onExit(self)

	if self.spawnTimer ~= nil then
		self.spawnTimer:clear()
	end
end

function SetupState:spawn()
	self:spawnVehicles(function ()
		self.spawnTimer = Timer.schedule(1000, function ()
			local vehicleId = NetworkUtil.getObjectId(self.runVehicle)

			self.stateMachine:transition(SuperCup.STATES.START, {
				self.playerUserId,
				vehicleId
			})
		end)
	end)
end

function SetupState:spawnVehicles(callBack)
	local player = self.mission.userIdToPlayer[self.playerUserId]
	local farmId = player.farmId or AccessHandler.EVERYONE
	local vehiclesToSpawn = Queue.fromList(table.copy(self.vehicles))

	if vehiclesToSpawn:isEmpty() then
		callBack()

		return
	end

	local function loadFinished(self, vehicle, state, args)
		if state == VehicleLoadingUtil.VEHICLE_LOAD_OK then
			vehicle.isVehicleSaved = false

			if vehicle.getIsEnterable ~= nil then
				self.runVehicle = vehicle
			end

			table.insert(self.vehicleList, vehicle)
		else
			Logging.xmlWarning(nil, "Could not spawn super cup vehicle!")

			return
		end

		local queue = unpack(args)

		if not queue:isEmpty() then
			self:spawnVehicleAtNode(queue:pop(), loadFinished, vehiclesToSpawn, farmId)
		else
			callBack()
		end
	end

	self:spawnVehicleAtNode(vehiclesToSpawn:pop(), loadFinished, vehiclesToSpawn, farmId)
end

function SetupState:spawnVehicleAtNode(vehicle, loadFinished, queue, farmId)
	local x, y, z = getWorldTranslation(vehicle.node)
	local _, by, _ = getRotation(vehicle.baseNode)
	local _, vy, _ = getRotation(vehicle.node)
	local rotCorrection = by - vy

	return VehicleLoadingUtil.loadVehicle(vehicle.filename, {
		x = x,
		y = y,
		z = z,
		yRot = rotCorrection + vehicle.rotation
	}, true, 0, Vehicle.PROPERTY_STATE_OWNED, farmId, nil, , loadFinished, self, {
		queue
	})
end
