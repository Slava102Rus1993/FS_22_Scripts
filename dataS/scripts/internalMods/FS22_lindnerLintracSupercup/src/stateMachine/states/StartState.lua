StartState = {
	COUNT_DOWN_TIME = 10000,
	COUNT_DOWN_THRESHOLD = 5000
}
local StartState_mt = Class(StartState, AbstractState)

function StartState:new(id, stateMachine, mission, isServer, coneHandler, trafficLight, hud, custom_mt)
	local self = AbstractState:new(id, stateMachine, custom_mt or StartState_mt)
	self.mission = mission
	self.isServer = isServer
	self.coneHandler = coneHandler
	self.trafficLight = trafficLight
	self.hud = hud
	self.timer = Timer:new(StartState.COUNT_DOWN_TIME, function ()
		self:startSuperCup()
	end)
	self.playerUserId = nil
	self.playerFarmId = nil

	return self
end

function StartState:delete()
	StartState:superClass().delete(self)
end

function StartState:onEnter(playerUserId, vehicleId)
	self.playerUserId = playerUserId
	local player = self.mission.player
	self.playerFarmId = player.farmId

	if playerUserId == self.mission.playerUserId then
		local vehicle = NetworkUtil.getObject(vehicleId)
		local playerStyle = player:getStyle()

		g_client:getServerConnection():sendEvent(VehicleEnterRequestEvent.new(vehicle, playerStyle, player.farmId))
	end

	StartState:superClass().onEnter(self)
	self.hud:setIsActive(false)
	self.coneHandler:reset()
	self.trafficLight:reset()
	self.timer:start()
end

function StartState:onExit()
	StartState:superClass().onExit(self)

	if self.timer:isRunning() then
		self.timer:clear()
	end
end

function StartState:onUpdate(dt)
	if self.timer:isRunning() then
		local elapsedTime = self.timer:getElapsedTime()

		if elapsedTime < StartState.COUNT_DOWN_THRESHOLD then
			local seconds = math.floor(elapsedTime * 0.001 + 1)

			if seconds ~= self.lastText then
				self.lastText = seconds

				if seconds == 3 then
					self.trafficLight:next()
				end

				self.hud:playCountdownSample()
			end
		else
			self.lastText = g_i18n:getText("info_getReady")
		end

		if self.hud:canInteractWithFarm(self.playerFarmId) then
			self.hud:drawTextElement({
				textSize = 0.04,
				y = 0.85,
				bold = true,
				x = 0.5,
				text = tostring(self.lastText)
			})
		end
	end
end

function StartState:startSuperCup()
	self.hud:playGoSample()

	if self.isServer then
		self.stateMachine:transition(SuperCup.STATES.RUN, {
			self.playerUserId
		})
	end
end
