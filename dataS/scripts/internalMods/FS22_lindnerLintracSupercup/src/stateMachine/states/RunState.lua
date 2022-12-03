RunState = {
	PENALTY_TIME = 5000
}
local RunState_mt = Class(RunState, AbstractState)

function RunState:new(id, stateMachine, mission, isServer, coneHandler, trafficLight, checkpoints, hud, vehicleList, object, custom_mt)
	local self = AbstractState:new(id, stateMachine, custom_mt or RunState_mt)

	function self.action(count)
		self:onPenaltyCountChanged(count)
	end

	self.mission = mission
	self.isServer = isServer
	self.coneHandler = coneHandler
	self.trafficLight = trafficLight
	self.checkpoints = checkpoints
	self.hud = hud
	self.vehicleList = vehicleList
	self.object = object
	self.playerUserId = nil
	self.queue = Queue:new()
	self.timer = Timer:new()

	self.timer:setIsStopWatch(true)

	return self
end

function RunState:delete()
	RunState:superClass().delete(self)
end

function RunState:onEnter(playerUserId)
	self.playerUserId = playerUserId

	RunState:superClass().onEnter(self)
	self.trafficLight:next()

	if self.isServer then
		for _, vehicle in ipairs(self.vehicleList) do
			if vehicle.setAllowDriveSuperCup ~= nil then
				vehicle:setAllowDriveSuperCup(true, self.object)
			end
		end
	end

	self.coneHandler:addActionListener(self.action)

	local player = self.mission.player

	if self.hud:canInteractWithFarm(player.farmId) then
		self.hud:setIsActive(true)
		self.hud:setTimer(self.timer)
		self.hud:setPenaltyPoints(0)
	end

	self.timer:start()

	if self.isServer then
		self.queue = Queue.fromList(table.copy(self.checkpoints))
		self.currentCheckpoint = self.queue:pop()

		if self.currentCheckpoint ~= nil then
			self.currentCheckpoint:setIsActive(true)
		end
	end
end

function RunState:onExit()
	RunState:superClass().onExit(self)
	self.coneHandler:removeActionListener(self.action)
	self.timer:stop()
end

function RunState:onUpdate(dt)
	self.coneHandler:update(dt)

	if self.isServer then
		if self.currentCheckpoint ~= nil then
			if self.currentCheckpoint:hasPassedCheckpoint() then
				self.currentCheckpoint:setIsActive(false)

				self.currentCheckpoint = self.queue:pop()

				if self.currentCheckpoint ~= nil then
					self.currentCheckpoint:setIsActive(true)
				end
			end
		else
			self.stateMachine:transition(SuperCup.STATES.FINISHED, {
				self.playerUserId,
				self.timer:getElapsedTime(),
				self.coneHandler:getLostBallCount()
			})
		end
	end
end

function RunState:onPenaltyCountChanged(count)
	self.timer.elapsedDelay = self.timer.elapsedDelay + RunState.PENALTY_TIME

	self.hud:setPenaltyPoints(count)
end
