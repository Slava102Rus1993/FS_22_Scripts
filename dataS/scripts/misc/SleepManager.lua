SleepManager = {
	SLEEPING_TIME_SCALE = 5000,
	TIME_TO_ANSWER_REQUEST = 20000,
	TIME_TO_NEXT_REQUEST = 20000
}
local SleepManager_mt = Class(SleepManager, AbstractManager)

function SleepManager.new(customMt)
	local self = AbstractManager.new(customMt or SleepManager_mt)
	self.isSleeping = false
	self.wakeUpTime = 0
	self.previousCamera = nil
	self.previousInputContext = nil
	self.fallbackCamera = nil
	self.isRequestPending = false
	self.requestAnswer = true
	self.requestedTime = 0
	self.requestedTargetTime = 0

	return self
end

function SleepManager:loadMapData(xmlFile, missionInfo, baseDirectory)
	local width, height = getNormalizedScreenValues(128, 128)
	self.animationNumFrames = 16
	self.animationTimer = 0
	self.animationSpeed = 50
	self.animationOffset = 0
	self.animationFrameSize = 128
	self.animationRefSize = {
		2048,
		128
	}
	local xOffset, yOffset = getNormalizedScreenValues(-4, 0)
	self.animationOverlay = Overlay.new("dataS/menu/hud/sleep_animation.png", 0.5 + xOffset, 0.5 + yOffset, width, height)

	self.animationOverlay:setAlignment(Overlay.ALIGN_VERTICAL_MIDDLE, Overlay.ALIGN_HORIZONTAL_CENTER)
	self.animationOverlay:setUVs(GuiUtils.getUVs({
		0,
		0,
		self.animationFrameSize,
		self.animationFrameSize
	}, self.animationRefSize))
	self.animationOverlay:setColor(0.0742, 0.4341, 0.6939, 1)

	width, height = getNormalizedScreenValues(200, 200)
	self.animationBackgroundOverlay = Overlay.new("dataS/menu/hud/ui_elements.png", 0.5, 0.5, width, height)

	self.animationBackgroundOverlay:setAlignment(Overlay.ALIGN_VERTICAL_MIDDLE, Overlay.ALIGN_HORIZONTAL_CENTER)
	self.animationBackgroundOverlay:setUVs(GuiUtils.getUVs({
		294,
		390,
		100,
		100
	}, {
		1024,
		1024
	}))
	self.animationBackgroundOverlay:setColor(0, 0, 0, 0.75)
	g_messageCenter:subscribe(MessageType.USER_REMOVED, self.onUserRemoved, self)
end

function SleepManager:unloadMapData()
	g_messageCenter:unsubscribeAll(self)

	if self.fallbackCamera ~= nil then
		delete(self.fallbackCamera)

		self.fallbackCamera = nil
	end

	if self.animationOverlay ~= nil then
		self.animationOverlay:delete()

		self.animationOverlay = nil
	end

	if self.animationBackgroundOverlay ~= nil then
		self.animationBackgroundOverlay:delete()

		self.animationBackgroundOverlay = nil
	end
end

function SleepManager:update(dt)
	if g_currentMission:getIsServer() then
		if self.wakeUpTime < g_time and self.isSleeping then
			self:stopSleep()
		end

		if self.isRequestPending then
			if #self.userRequestIds == 0 then
				if self.requestAnswer then
					self:startSleep(self.requestedTargetTime)
					self:resetRequest()
				else
					g_server:broadcastEvent(SleepRequestDeniedEvent.new(self.requestDeniedUserId), g_dedicatedServer == nil)
					self:resetRequest()
				end
			elseif self.requestedTime + SleepManager.TIME_TO_ANSWER_REQUEST < g_time then
				g_server:broadcastEvent(SleepRequestTimeoutEvent.new(), false)
				self:resetRequest()
			end
		end
	end

	if self.isSleeping then
		self.animationTimer = self.animationTimer - dt

		if self.animationTimer < 0 then
			self.animationTimer = self.animationSpeed
			self.animationOffset = self.animationOffset + 1

			if self.animationOffset > self.animationNumFrames - 1 then
				self.animationOffset = 0
			end

			self.animationOverlay:setUVs(GuiUtils.getUVs({
				self.animationOffset * self.animationFrameSize,
				0,
				self.animationFrameSize,
				self.animationFrameSize
			}, self.animationRefSize))
		end
	end
end

function SleepManager:draw()
	if self.isSleeping then
		if self.animationBackgroundOverlay ~= nil then
			self.animationBackgroundOverlay:render()
		end

		if self.animationOverlay ~= nil then
			self.animationOverlay:render()
		end
	end
end

function SleepManager:onUserRemoved(user)
	if self.isRequestPending then
		for k, id in ipairs(self.userRequestIds) do
			if id == user:getId() then
				table.remove(self.userRequestIds, k)

				break
			end
		end
	end
end

function SleepManager:getCanSleep()
	return not self.isSleeping
end

function SleepManager:getIsSleeping()
	return self.isSleeping
end

function SleepManager:onSleepNotAllowed()
	g_gui:showInfoDialog({
		text = g_i18n:getText("ui_inGameSleepNotAllowed"),
		dialogType = DialogElement.TYPE_WARNING,
		target = self
	})
end

function SleepManager:onSleepRequestDenied(userId)
	local nickname = ""

	if userId > 0 then
		local user = g_currentMission.userManager:getUserByUserId(userId)

		if user ~= nil then
			nickname = string.format(" (%s)", user:getNickname())
		end
	end

	g_gui:showInfoDialog({
		text = g_i18n:getText("ui_inGameSleepRequestDenied") .. nickname,
		dialogType = DialogElement.TYPE_WARNING,
		target = self
	})
end

function SleepManager:onSleepRequestTimeout()
	g_gui:showInfoDialog({
		text = g_i18n:getText("ui_inGameSleepRequestTimeout"),
		dialogType = DialogElement.TYPE_WARNING,
		target = self
	})
end

function SleepManager:onSleepRequestPending()
	g_gui:showInfoDialog({
		text = g_i18n:getText("ui_inGameSleepRequestPending"),
		dialogType = DialogElement.TYPE_WARNING,
		target = self
	})
end

function SleepManager:onSleepRequest(userId, targetTime)
	local user = g_currentMission.userManager:getUserByUserId(userId)
	local name = "Unknown"

	if user ~= nil then
		name = user:getNickname()
	end

	g_gui:showYesNoDialog({
		text = string.format(g_i18n:getText("ui_inGameSleepRequest"), name),
		callback = self.onSleepRequestYesNo,
		target = self
	})
end

function SleepManager:onSleepRequestYesNo(yesNo)
	g_client:getServerConnection():sendEvent(SleepResponseEvent.new(yesNo))
end

function SleepManager:onSleepResponse(connection, answer)
	assert(g_currentMission:getIsServer(), "SleepManager:onSleepResponse is a server-only function")

	if not self.isRequestPending then
		return
	end

	self.requestAnswer = self.requestAnswer and answer
	local userId = g_currentMission.userManager:getUserIdByConnection(connection)

	if not answer and self.requestDeniedUserId == nil then
		self.requestDeniedUserId = userId
	end

	if userId ~= nil then
		for k, id in ipairs(self.userRequestIds) do
			if id == userId then
				table.remove(self.userRequestIds, k)

				break
			end
		end
	end
end

function SleepManager:showDialog()
	if g_currentMission.guidedTour:getBlocksTimeChange() then
		g_gui:showInfoDialog({
			text = g_i18n:getText("ui_inGameSleepNotAllowedDuringTour"),
			dialogType = DialogElement.TYPE_WARNING,
			target = self
		})
	elseif self:getCanSleep() then
		g_gui:showSleepDialog({
			text = g_i18n:getText("ui_inGameSleepTargetTime"),
			callback = self.sleepDialogYesNo,
			target = self
		})
	else
		g_gui:showInfoDialog({
			text = g_i18n:getText("ui_inGameSleepWrongTime"),
			dialogType = DialogElement.TYPE_WARNING,
			target = self
		})
	end
end

function SleepManager:sleepDialogYesNo(yes, targetTime)
	if yes then
		if g_currentMission:getIsServer() then
			self:startSleepRequest(g_currentMission.playerUserId, targetTime)
		else
			g_client:getServerConnection():sendEvent(SleepRequestEvent.new(g_currentMission.playerUserId, targetTime))
		end
	end
end

function SleepManager:startSleepRequest(userId, targetTime)
	assert(g_currentMission:getIsServer(), "SleepManager:startSleepRequest is a server-only function")

	local user = g_currentMission.userManager:getUserByUserId(userId)
	local userConnection = nil

	if user ~= nil then
		userConnection = user:getConnection()
	end

	if self.isRequestPending then
		if userConnection ~= nil then
			userConnection:sendEvent(SleepRequestPendingEvent.new())
		end

		return
	end

	local isInCoolDownPhase = g_time < self.requestedTime + SleepManager.TIME_TO_NEXT_REQUEST

	if isInCoolDownPhase or not self:getCanSleep() or g_currentMission.guidedTour:getBlocksTimeChange() then
		if userConnection ~= nil then
			userConnection:sendEvent(SleepNotAllowedEvent.new())
		end

		return
	end

	self.isRequestPending = true
	self.requestedTime = g_time
	self.requestedTargetTime = targetTime
	self.requestAnswer = true
	self.userRequestIds = {}

	for _, u in ipairs(g_currentMission.userManager:getUsers()) do
		if u:getId() ~= userId and (g_dedicatedServer == nil or u:getId() ~= g_currentMission:getServerUserId()) then
			table.insert(self.userRequestIds, u:getId())
		end
	end

	g_server:broadcastEvent(SleepRequestEvent.new(userId, targetTime), g_dedicatedServer == nil, userConnection)
end

function SleepManager:resetRequest()
	self.isRequestPending = false
	self.requestedTargetTime = 0
	self.requestAnswer = true
	self.requestDeniedUserId = nil
end

function SleepManager:startSleep(targetTime)
	g_currentMission.environment.weather.cloudUpdater:setSlowModeEnabled(true)

	if g_currentMission:getIsServer() then
		targetTime = targetTime * 1000 * 60 * 60
		local currentHour = g_currentMission.environment.dayTime + 1
		local duration = (targetTime - currentHour) % 86400000
		self.wakeUpTime = g_time + duration / SleepManager.SLEEPING_TIME_SCALE
		self.startTimeScale = g_currentMission.missionInfo.timeScale

		g_currentMission:setTimeScale(SleepManager.SLEEPING_TIME_SCALE)
		g_server:broadcastEvent(StartSleepStateEvent.new(targetTime), false)
	end

	self.isSleeping = true

	g_currentMission.hud:setIsVisible(false)

	g_currentMission.isPlayerFrozen = true

	g_inputBinding:setContext("SLEEPING", true)

	self.previousCamera = getCamera()
	local sleepCamera = self:getCamera()

	if sleepCamera ~= nil then
		local x, y, z = getWorldTranslation(sleepCamera)
		y = math.max(getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, y, z) + 60, y)

		setWorldTranslation(sleepCamera, x, y, z)
		setWorldRotation(sleepCamera, math.rad(80), 0, 0)
		setCamera(sleepCamera)
	end

	g_messageCenter:publish(MessageType.SLEEPING, true)
end

function SleepManager:stopSleep()
	g_currentMission.environment.weather.cloudUpdater:setSlowModeEnabled(false)

	if g_currentMission:getIsServer() then
		g_currentMission:setTimeScale(self.startTimeScale)
		g_server:broadcastEvent(StopSleepStateEvent.new(), false)
	end

	if self.previousCamera ~= nil and entityExists(self.previousCamera) then
		setCamera(self.previousCamera)
	elseif g_currentMission.controlPlayer and g_currentMission.player ~= nil then
		setCamera(g_currentMission.player.cameraNode)
	elseif g_currentMission.controlledVehicle ~= nil then
		local vehicleCamera = g_currentMission.controlledVehicle:getActiveCamera()

		if vehicleCamera ~= nil and vehicleCamera.cameraNode ~= nil then
			setCamera(vehicleCamera.cameraNode)
		end
	end

	self.previousCamera = nil

	if g_inputBinding:getContextName() == "SLEEPING" then
		g_inputBinding:revertContext(true)
	end

	g_currentMission.isPlayerFrozen = false

	g_currentMission.hud:setIsVisible(true)

	self.isSleeping = false

	g_messageCenter:publish(MessageType.SLEEPING, false)
end

function SleepManager:getCamera()
	return g_farmManager:getSleepCamera(g_currentMission.player.farmId) or self:getFallbackCamera()
end

function SleepManager:getFallbackCamera()
	if self.fallbackCamera == nil then
		self.fallbackCamera = createCamera("sleepingFallbackCamera", math.rad(60), 1, 10000)

		link(getRootNode(), self.fallbackCamera)
	end

	return self.fallbackCamera
end

g_sleepManager = SleepManager.new()
