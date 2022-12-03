FinishState = {}
local FinishState_mt = Class(FinishState, AbstractState)

function FinishState:new(id, stateMachine, mission, isServer, isClient, superCup, vehicleList, trafficLight, hud, custom_mt)
	local self = AbstractState:new(id, stateMachine, custom_mt or FinishState_mt)
	self.isServer = isServer
	self.isClient = isClient
	self.superCup = superCup
	self.mission = mission
	self.vehicleList = vehicleList
	self.trafficLight = trafficLight
	self.hud = hud

	return self
end

function FinishState:delete()
	FinishState:superClass().delete(self)
end

function FinishState:onEnter(playerUserId, elapsedTime, penalty)
	self.trafficLight:reset()

	if self.isServer then
		for _, vehicle in ipairs(self.vehicleList) do
			if vehicle ~= nil and not vehicle.isDeleted then
				self.mission:removeVehicle(vehicle, false)
				vehicle:delete()
			end
		end
	end

	self.vehicleList = {}

	if elapsedTime ~= nil and penalty ~= nil then
		local user = self.mission.userManager:getUserByUserId(playerUserId)

		if user ~= nil then
			local score = {
				playerNickname = user:getNickname(),
				time = SuperCupUtil.millisecondsToClockString(elapsedTime),
				penalties = penalty,
				playerId = user:getId(),
				uuid = user:getUniqueUserId()
			}
			local scoreText = g_i18n:getText("info_score"):format(score.playerNickname, score.time, score.penalties)

			if self.mission.playerUserId == playerUserId then
				if self.isClient then
					g_gui:showInfoDialog({
						dialogType = DialogElement.TYPE_INFO,
						text = scoreText
					})
				end
			elseif self.mission.player.farmId == self.superCup.farmId then
				self.mission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK, scoreText)
			end

			self.superCup:saveResult(score)
		end
	end

	self.hud:setIsActive(false)
	FinishState:superClass().onEnter(self)
end
