local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_kubotaPack" then
	return
end

Player.updateActionEvents = Utils.appendedFunction(Player.updateActionEvents, function (self)
	local enterActionState = self.inputInformation.registrationList[InputAction.ENTER].lastState

	if not enterActionState then
		local vehicle = g_currentMission.interactiveVehicleInRange

		if vehicle ~= nil and vehicle.getCanUsePassengerSeats ~= nil and vehicle:getCanUsePassengerSeats() then
			local index = vehicle:getClosestSeatIndex(self.rootNode)

			if index ~= nil then
				self:setInputState(InputAction.ENTER, true)

				local eventIdEnter = self.inputInformation.registrationList[InputAction.ENTER].eventId

				g_inputBinding:setActionEventText(eventIdEnter, vehicle.spec_enterablePassenger.texts.enterVehiclePassenger)
			end
		end
	else
		local vehicle = g_currentMission.interactiveVehicleInRange

		if vehicle ~= nil and vehicle.getCanUsePassengerSeats ~= nil and vehicle.spec_enterablePassenger.available then
			local eventIdEnter = self.inputInformation.registrationList[InputAction.ENTER].eventId

			g_inputBinding:setActionEventText(eventIdEnter, vehicle.spec_enterablePassenger.texts.enterVehicleDriver)
		end
	end
end)
Player.onInputEnter = Utils.appendedFunction(Player.onInputEnter, function (self, _, inputValue)
	if g_time > g_currentMission.lastInteractionTime + 200 then
		local vehicle = g_currentMission.interactiveVehicleInRange

		if vehicle ~= nil and not g_currentMission.accessHandler:canFarmAccess(self.farmId, vehicle) and vehicle.getCanUsePassengerSeats and vehicle:getCanUsePassengerSeats() then
			vehicle:interact()
		end
	end
end)
BaseMission.delete = Utils.prependedFunction(BaseMission.delete, function (self)
	if self.enteredPassengerVehicle ~= nil then
		self.enteredPassengerVehicle:leaveLocalPassengerSeat(false)
	end
end)
BaseMission.onEnterVehicle = Utils.prependedFunction(BaseMission.onEnterVehicle, function (self)
	if self.enteredPassengerVehicle ~= nil then
		self.enteredPassengerVehicle:leaveLocalPassengerSeat(false)
	end
end)
Enterable.onRegisterActionEvents = Utils.prependedFunction(Enterable.onRegisterActionEvents, function (self, isActiveForInput, isActiveForInputIgnoreSelection)
	local spec = self.spec_enterablePassenger

	if spec ~= nil then
		self:clearActionEventsTable(spec.actionEvents)
	end
end)
IngameMap.updatePlayerPosition = Utils.appendedFunction(IngameMap.updatePlayerPosition, function (self)
	if g_currentMission.enteredPassengerVehicle ~= nil then
		local playerPosX, _, playerPosZ = nil
		playerPosX, _, playerPosZ, self.playerRotation, self.playerVelocity = self:determineVehiclePosition(g_currentMission.enteredPassengerVehicle)
		self.normalizedPlayerPosX = MathUtil.clamp((playerPosX + self.worldCenterOffsetX) / self.worldSizeX, 0, 1)
		self.normalizedPlayerPosZ = MathUtil.clamp((playerPosZ + self.worldCenterOffsetZ) / self.worldSizeZ, 0, 1)
	end
end)
InGameMenuAIFrame.onSwitchVehicle = Utils.appendedFunction(InGameMenuAIFrame.onSwitchVehicle, function (self, _, _, direction)
	local allowedHotspots = InGameMenuAIFrame.HOTSPOT_SWITCH_CATEGORIES
	allowedHotspots[MapHotspot.CATEGORY_PLAYER] = allowedHotspots[MapHotspot.CATEGORY_PLAYER] or g_currentMission.enteredPassengerVehicle ~= nil
	local newHotspot = self.ingameMapBase:cycleVisibleHotspot(self.currentHotspot, allowedHotspots, direction)

	self:setMapSelectionItem(newHotspot)
end)
InGameMenuMapFrame.onSwitchVehicle = Utils.appendedFunction(InGameMenuMapFrame.onSwitchVehicle, function (self, _, _, direction)
	local allowedHotspots = InGameMenuAIFrame.HOTSPOT_SWITCH_CATEGORIES
	allowedHotspots[MapHotspot.CATEGORY_PLAYER] = allowedHotspots[MapHotspot.CATEGORY_PLAYER] or g_currentMission.enteredPassengerVehicle ~= nil

	if GS_IS_MOBILE_VERSION then
		allowedHotspots = InGameMenuMapFrame.PAGE_HOTSPOTS[self.currentPage]
	end

	local newHotspot = self.ingameMapBase:cycleVisibleHotspot(self.currentHotspot, allowedHotspots, direction)

	self:setMapSelectionItem(newHotspot)
end)
MessageType.PASSENGER_CHARACTER_CHANGED = nextMessageTypeId()
Player.setStyleAsync = Utils.appendedFunction(Player.setStyleAsync, function (self, style, callback, noEventSend)
	g_messageCenter:publish(MessageType.PASSENGER_CHARACTER_CHANGED, style, self.userId)
end)
