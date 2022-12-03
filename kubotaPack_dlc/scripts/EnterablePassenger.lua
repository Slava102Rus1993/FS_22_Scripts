local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_kubotaPack" then
	return
end

EnterablePassenger = {
	SEAT_INDEX_SEND_NUM_BITS = 4,
	MOD_NAME = g_currentModName,
	SPEC_NAME = g_currentModName .. ".enterablePassenger",
	prerequisitesPresent = function (specializations)
		return SpecializationUtil.hasSpecialization(Enterable, specializations)
	end
}

function EnterablePassenger.initSpecialization()
	g_configurationManager:addConfigurationType("enterablePassenger", g_i18n:getText("configuration_design"), "enterable", nil, , , ConfigurationUtil.SELECTOR_MULTIOPTION)

	local schema = Vehicle.xmlSchema

	schema:setXMLSpecializationType("EnterablePassenger")
	EnterablePassenger.registerXMLPaths("vehicle.enterable.passengerSeats", schema)
	EnterablePassenger.registerXMLPaths("vehicle.enterable.enterablePassengerConfigurations.enterablePassengerConfiguration(?)", schema)
	schema:setXMLSpecializationType()
end

function EnterablePassenger.registerXMLPaths(basePath, schema)
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".passengerSeat(?)#node", "Seat reference node to calculate entering distance to")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".passengerSeat(?)#exitPoint", "Player spawn point when leaving the vehicle")
	schema:register(XMLValueType.INT, basePath .. ".passengerSeat(?)#outdoorCameraIndex", "Index of regular outdoor camera if it should be available as well")
	schema:register(XMLValueType.FLOAT, basePath .. ".passengerSeat(?)#nicknameOffset", "Nickname rendering offset", 1.5)
	VehicleCamera.registerCameraXMLPaths(schema, basePath .. ".passengerSeat(?).camera(?)")
	VehicleCharacter.registerCharacterXMLPaths(schema, basePath .. ".passengerSeat(?).characterNode")
end

function EnterablePassenger.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "getClosestSeatIndex", EnterablePassenger.getClosestSeatIndex)
	SpecializationUtil.registerFunction(vehicleType, "getIsPassengerSeatAvailable", EnterablePassenger.getIsPassengerSeatAvailable)
	SpecializationUtil.registerFunction(vehicleType, "getIsPassengerSeatIndexAvailable", EnterablePassenger.getIsPassengerSeatIndexAvailable)
	SpecializationUtil.registerFunction(vehicleType, "getFirstAvailablePassengerSeat", EnterablePassenger.getFirstAvailablePassengerSeat)
	SpecializationUtil.registerFunction(vehicleType, "getPlayerNameBySeatIndex", EnterablePassenger.getPlayerNameBySeatIndex)
	SpecializationUtil.registerFunction(vehicleType, "getCanUsePassengerSeats", EnterablePassenger.getCanUsePassengerSeats)
	SpecializationUtil.registerFunction(vehicleType, "enterVehiclePassengerSeat", EnterablePassenger.enterVehiclePassengerSeat)
	SpecializationUtil.registerFunction(vehicleType, "leaveLocalPassengerSeat", EnterablePassenger.leaveLocalPassengerSeat)
	SpecializationUtil.registerFunction(vehicleType, "leavePassengerSeat", EnterablePassenger.leavePassengerSeat)
	SpecializationUtil.registerFunction(vehicleType, "copyEnterableActiveCameraIndex", EnterablePassenger.copyEnterableActiveCameraIndex)
	SpecializationUtil.registerFunction(vehicleType, "setPassengerActiveCameraIndex", EnterablePassenger.setPassengerActiveCameraIndex)
	SpecializationUtil.registerFunction(vehicleType, "enablePassengerActiveCamera", EnterablePassenger.enablePassengerActiveCamera)
	SpecializationUtil.registerFunction(vehicleType, "setPassengerSeatCharacter", EnterablePassenger.setPassengerSeatCharacter)
	SpecializationUtil.registerFunction(vehicleType, "updatePassengerSeatCharacter", EnterablePassenger.updatePassengerSeatCharacter)
	SpecializationUtil.registerFunction(vehicleType, "onPassengerUserRemoved", EnterablePassenger.onPassengerUserRemoved)
	SpecializationUtil.registerFunction(vehicleType, "onPassengerPlayerStyleChanged", EnterablePassenger.onPassengerPlayerStyleChanged)
end

function EnterablePassenger.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "interact", EnterablePassenger.interact)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsEnterable", EnterablePassenger.getIsEnterable)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getExitNode", EnterablePassenger.getExitNode)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsInUse", EnterablePassenger.getIsInUse)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getDeactivateOnLeave", EnterablePassenger.getDeactivateOnLeave)
end

function EnterablePassenger.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", EnterablePassenger)
	SpecializationUtil.registerEventListener(vehicleType, "onDelete", EnterablePassenger)
	SpecializationUtil.registerEventListener(vehicleType, "onReadStream", EnterablePassenger)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", EnterablePassenger)
	SpecializationUtil.registerEventListener(vehicleType, "onPostUpdate", EnterablePassenger)
	SpecializationUtil.registerEventListener(vehicleType, "onDrawUIInfo", EnterablePassenger)
	SpecializationUtil.registerEventListener(vehicleType, "onSetBroken", EnterablePassenger)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", EnterablePassenger)
end

function EnterablePassenger:onLoad(savegame)
	self.spec_enterablePassenger = self["spec_" .. EnterablePassenger.SPEC_NAME]
	local spec = self.spec_enterablePassenger
	spec.currentSeatIndex = 1
	spec.passengerEntered = false
	local baseKey = "vehicle.enterable.passengerSeats"
	local configIndex = self.configurations.enterablePassenger

	if configIndex ~= nil then
		local configKey = string.format("vehicle.enterable.enterablePassengerConfigurations.enterablePassengerConfiguration(%d)", configIndex - 1)

		if self.xmlFile:hasProperty(configKey) then
			baseKey = configKey
		end
	end

	spec.passengerSeats = {}

	self.xmlFile:iterate(baseKey .. ".passengerSeat", function (_, key)
		local seatEntry = {
			node = self.xmlFile:getValue(key .. "#node", nil, self.components, self.i3dMappings),
			exitPoint = self.xmlFile:getValue(key .. "#exitPoint", nil, self.components, self.i3dMappings)
		}

		if seatEntry.node ~= nil then
			seatEntry.cameras = {}
			seatEntry.camIndex = 1
			local outdoorCameraIndex = self.xmlFile:getValue(key .. "#outdoorCameraIndex")

			if outdoorCameraIndex ~= nil then
				local specEnterable = self.spec_enterable

				if specEnterable.cameras ~= nil and specEnterable.cameras[outdoorCameraIndex] ~= nil then
					table.insert(seatEntry.cameras, specEnterable.cameras[outdoorCameraIndex])
				end
			end

			self.xmlFile:iterate(key .. ".camera", function (index, cameraKey)
				local camera = VehicleCamera.new(self)

				if camera:loadFromXML(self.xmlFile, cameraKey, nil, index) then
					table.insert(seatEntry.cameras, camera)
				end
			end)

			seatEntry.nicknameOffset = self.xmlFile:getValue(key .. "#nicknameOffset", 1.5)
			seatEntry.vehicleCharacter = VehicleCharacter.new(self)

			if seatEntry.vehicleCharacter ~= nil and not seatEntry.vehicleCharacter:load(self.xmlFile, key .. ".characterNode") then
				seatEntry.vehicleCharacter = nil
			end

			seatEntry.isUsed = false
			seatEntry.playerStyle = nil
			seatEntry.userId = nil

			table.insert(spec.passengerSeats, seatEntry)
		else
			Logging.xmlWarning(self.xmlFile, "Missing node for '%s'", key)
		end
	end)

	spec.available = #spec.passengerSeats > 0 and g_currentMission.missionDynamicInfo.isMultiplayer
	spec.texts = {
		enterVehicleDriver = string.format("%s (%s)", g_i18n:getText("button_enterVehicle"), g_i18n:getText("passengerSeat_driver")),
		enterVehiclePassenger = string.format("%s (%s)", g_i18n:getText("button_enterVehicle"), g_i18n:getText("passengerSeat_passenger")),
		switchSeatDriver = g_i18n:getText("passengerSeat_switchSeatDriver"),
		switchSeatPassenger = g_i18n:getText("passengerSeat_switchSeatPassenger"),
		switchNextSeat = g_i18n:getText("passengerSeat_switchNextSeat")
	}
	spec.minEnterDistance = 3

	if spec.available then
		g_messageCenter:subscribe(MessageType.USER_REMOVED, self.onPassengerUserRemoved, self)
		g_messageCenter:subscribe(MessageType.PASSENGER_CHARACTER_CHANGED, self.onPassengerPlayerStyleChanged, self)
	end
end

function EnterablePassenger:onDelete()
	self:leaveLocalPassengerSeat(false, true)

	local spec = self.spec_enterablePassenger

	for seatIndex = 1, #spec.passengerSeats do
		local passengerSeat = spec.passengerSeats[seatIndex]

		if passengerSeat.isUsed then
			self:leavePassengerSeat(false, seatIndex)
		end
	end
end

function EnterablePassenger:onReadStream(streamId, connection)
	local spec = self.spec_enterablePassenger

	for seatIndex = 1, #spec.passengerSeats do
		if streamReadBool(streamId) then
			local playerStyle = PlayerStyle.new()

			playerStyle:readStream(streamId, connection)

			local userId = streamReadInt32(streamId)

			self:enterVehiclePassengerSeat(false, seatIndex, playerStyle, userId)
		end
	end
end

function EnterablePassenger:onWriteStream(streamId, connection)
	local spec = self.spec_enterablePassenger

	for seatIndex = 1, #spec.passengerSeats do
		local passengerSeat = spec.passengerSeats[seatIndex]

		if streamWriteBool(streamId, passengerSeat.isUsed) then
			passengerSeat.playerStyle:writeStream(streamId, connection)
			streamWriteInt32(streamId, passengerSeat.userId)
		end
	end
end

function EnterablePassenger:onPostUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	local spec = self.spec_enterablePassenger

	if spec.available and self.isClient then
		local specEnterable = self.spec_enterable

		if specEnterable.activeCamera ~= nil then
			specEnterable.activeCamera:update(dt)
		end

		EnterablePassenger.updateActionEvents(self)

		if spec.passengerEntered then
			self:raiseActive()
		end

		self:updatePassengerSeatCharacter(dt)
	end
end

function EnterablePassenger:onDrawUIInfo()
	local spec = self.spec_enterablePassenger

	if spec.available then
		local visible = not g_gui:getIsGuiVisible() and not g_noHudModeEnabled and g_gameSettings:getValue(GameSettings.SETTING.SHOW_MULTIPLAYER_NAMES)

		if self.isClient and visible then
			for seatIndex = 1, #spec.passengerSeats do
				local passengerSeat = spec.passengerSeats[seatIndex]

				if passengerSeat.isUsed and (not spec.passengerEntered or seatIndex ~= spec.currentSeatIndex) then
					local distance = calcDistanceFrom(passengerSeat.node, getCamera())

					if distance < 100 then
						local x, y, z = getWorldTranslation(passengerSeat.node)
						y = y + passengerSeat.nicknameOffset

						Utils.renderTextAtWorldPosition(x, y, z, self:getPlayerNameBySeatIndex(seatIndex), getCorrectTextSize(0.02), 0)
					end
				end
			end
		end
	end
end

function EnterablePassenger:onSetBroken()
	self:leaveLocalPassengerSeat(false)
end

function EnterablePassenger:interact(superFunc)
	if self.interactionFlag == Vehicle.INTERACTION_FLAG_ENTERABLE then
		if self:getCanUsePassengerSeats() then
			local seatIndex = self:getClosestSeatIndex(g_currentMission.player.rootNode)

			g_client:getServerConnection():sendEvent(PassengerEnterRequestEvent.new(self, g_currentMission.player:getStyle(), seatIndex))
		else
			superFunc(self)
		end
	else
		superFunc(self)
	end
end

function EnterablePassenger:getIsEnterable(superFunc)
	local spec = self.spec_enterablePassenger

	if spec.available then
		return not self:getCanUsePassengerSeats() and superFunc(self)
	end

	return superFunc(self)
end

function EnterablePassenger:getExitNode(superFunc)
	local spec = self.spec_enterablePassenger

	if spec.available and spec.passengerEntered then
		local currentSeat = spec.passengerSeats[spec.currentSeatIndex]

		if currentSeat ~= nil and currentSeat.exitPoint ~= nil then
			return currentSeat.exitPoint
		end
	end

	return superFunc(self)
end

function EnterablePassenger:getIsInUse(superFunc, connection)
	local spec = self.spec_enterablePassenger

	if spec.available then
		for seatIndex = 1, #spec.passengerSeats do
			local passengerSeat = spec.passengerSeats[seatIndex]

			if passengerSeat.isUsed then
				return true
			end
		end
	end

	return superFunc(self, connection)
end

function EnterablePassenger:getDeactivateOnLeave(superFunc, connection)
	local spec = self.spec_enterablePassenger

	if spec.available then
		for seatIndex = 1, #spec.passengerSeats do
			local passengerSeat = spec.passengerSeats[seatIndex]

			if passengerSeat.isUsed then
				return false
			end
		end
	end

	return superFunc(self, connection)
end

function EnterablePassenger:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	local spec = self.spec_enterablePassenger

	if spec.available then
		if spec.passengerEntered then
			local actionEventId, _ = nil
			_, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.ENTER, self, EnterablePassenger.actionEventLeave, false, true, false, true, nil)

			g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_HIGH)
			g_inputBinding:setActionEventTextVisibility(actionEventId, false)

			local currentSeat = spec.passengerSeats[spec.currentSeatIndex]

			if currentSeat ~= nil and #currentSeat.cameras > 0 then
				_, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.CAMERA_SWITCH, self, EnterablePassenger.actionEventCameraSwitch, false, true, false, true, nil)

				g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)
				g_inputBinding:setActionEventTextVisibility(actionEventId, true)
			end

			_, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.CAMERA_ZOOM_IN, self, Enterable.actionEventCameraZoomIn, false, true, true, true, nil)

			g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)
			g_inputBinding:setActionEventTextVisibility(actionEventId, false)

			_, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.CAMERA_ZOOM_OUT, self, Enterable.actionEventCameraZoomOut, false, true, true, true, nil)

			g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)
			g_inputBinding:setActionEventTextVisibility(actionEventId, false)

			_, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.SWITCH_SEAT, self, EnterablePassenger.actionEventSwitchSeat, false, true, false, true, nil)

			g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)
		elseif self:getIsEntered() and self:getIsActiveForInput(true, true) then
			local _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.SWITCH_SEAT, self, EnterablePassenger.actionEventSwitchSeat, false, true, false, true, nil)

			g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)
		end

		EnterablePassenger.updateActionEvents(self)
	end
end

function EnterablePassenger:actionEventLeave(actionName, inputValue, callbackState, isAnalog, isMouse)
	local spec = self.spec_enterablePassenger

	if spec.passengerEntered then
		g_client:getServerConnection():sendEvent(PassengerLeaveEvent.new(self, spec.currentSeatIndex, false))
		self:leavePassengerSeat(true, spec.currentSeatIndex)
	end
end

function EnterablePassenger:actionEventCameraSwitch(actionName, inputValue, callbackState, isAnalog, isMouse)
	local spec = self.spec_enterablePassenger

	if spec.passengerEntered then
		self:setPassengerActiveCameraIndex()
	end
end

function EnterablePassenger:actionEventSwitchSeat(actionName, inputValue, callbackState, isAnalog, isMouse)
	local spec = self.spec_enterablePassenger
	local enterFirstAvailableSeat = true

	if spec.passengerEntered then
		local nextSeatIndex = self:getFirstAvailablePassengerSeat(spec.currentSeatIndex)

		if nextSeatIndex ~= nil then
			self:copyEnterableActiveCameraIndex(nextSeatIndex)
			g_client:getServerConnection():sendEvent(PassengerEnterRequestEvent.new(self, g_currentMission.player:getStyle(), nextSeatIndex))

			enterFirstAvailableSeat = false
		elseif not self:getIsControlled() and g_currentMission.accessHandler:canPlayerAccess(self) then
			self:copyEnterableActiveCameraIndex()
			g_currentMission:requestToEnterVehicle(self)

			enterFirstAvailableSeat = false
		end
	end

	if enterFirstAvailableSeat then
		local seatIndex = self:getFirstAvailablePassengerSeat()

		if seatIndex ~= nil then
			self:copyEnterableActiveCameraIndex(seatIndex)
			g_client:getServerConnection():sendEvent(PassengerEnterRequestEvent.new(self, g_currentMission.player:getStyle(), seatIndex))
		end
	end
end

function EnterablePassenger:updateActionEvents()
	local spec = self.spec_enterablePassenger
	local switchSeatEvent = spec.actionEvents[InputAction.SWITCH_SEAT]

	if switchSeatEvent ~= nil then
		local isActive = false

		if spec.passengerEntered then
			local nextSeatIndex = self:getFirstAvailablePassengerSeat(spec.currentSeatIndex)

			if nextSeatIndex ~= nil then
				g_inputBinding:setActionEventText(switchSeatEvent.actionEventId, spec.texts.switchNextSeat)

				isActive = true
			elseif not self:getIsControlled() and g_currentMission.accessHandler:canPlayerAccess(self) then
				g_inputBinding:setActionEventText(switchSeatEvent.actionEventId, spec.texts.switchSeatDriver)

				isActive = true
			end
		end

		if not isActive then
			local seatIndex = self:getFirstAvailablePassengerSeat()

			if seatIndex ~= nil then
				g_inputBinding:setActionEventText(switchSeatEvent.actionEventId, spec.texts.switchSeatPassenger)

				isActive = true
			end
		end

		g_inputBinding:setActionEventActive(switchSeatEvent.actionEventId, isActive)
	end
end

function EnterablePassenger:getClosestSeatIndex(playerNode)
	local spec = self.spec_enterablePassenger
	local minDistance = math.huge
	local minIndex = nil

	for i = 1, #spec.passengerSeats do
		local passengerSeat = spec.passengerSeats[i]

		if self:getIsPassengerSeatAvailable(passengerSeat) then
			local distance = calcDistanceFrom(playerNode, passengerSeat.node)

			if distance < spec.minEnterDistance and distance < minDistance then
				minDistance = distance
				minIndex = i
			end
		end
	end

	return minIndex
end

function EnterablePassenger:getIsPassengerSeatAvailable(passengerSeat)
	return not passengerSeat.isUsed
end

function EnterablePassenger:getIsPassengerSeatIndexAvailable(seatIndex)
	local spec = self.spec_enterablePassenger
	local passengerSeat = spec.passengerSeats[seatIndex]

	if passengerSeat ~= nil then
		return self:getIsPassengerSeatAvailable(passengerSeat)
	end

	return false
end

function EnterablePassenger:getFirstAvailablePassengerSeat(startIndex)
	local spec = self.spec_enterablePassenger

	for i = startIndex or 1, #spec.passengerSeats do
		local passengerSeat = spec.passengerSeats[i]

		if self:getIsPassengerSeatAvailable(passengerSeat) then
			return i
		end
	end

	return nil
end

function EnterablePassenger:getPlayerNameBySeatIndex(seatIndex)
	local spec = self.spec_enterablePassenger
	local passengerSeat = spec.passengerSeats[seatIndex]

	if passengerSeat ~= nil then
		local user = g_currentMission.userManager:getUserByUserId(passengerSeat.userId)

		if user ~= nil then
			return user:getNickname()
		end
	end

	return ""
end

function EnterablePassenger:getCanUsePassengerSeats()
	if self.spec_enterable.isBroken then
		return false
	end

	if self:getIsControlled() then
		return true
	end

	if not g_currentMission.accessHandler:canPlayerAccess(self) then
		return true
	end

	return false
end

function EnterablePassenger:enterVehiclePassengerSeat(isOwner, seatIndex, playerStyle, userId)
	local spec = self.spec_enterablePassenger

	if isOwner then
		if g_currentMission.controlPlayer then
			g_currentMission.player:onLeave()
		elseif g_currentMission.controlledVehicle ~= nil and g_currentMission.controlledVehicle.spec_enterable.controllerUserId == userId then
			g_client:getServerConnection():sendEvent(VehicleLeaveEvent.new(g_currentMission.controlledVehicle))
			g_currentMission.controlledVehicle:leaveVehicle()
		end

		if spec.passengerEntered then
			self:leaveLocalPassengerSeat(true)
		end

		local oldContext = g_inputBinding:getContextName()

		g_inputBinding:setContext(Vehicle.INPUT_CONTEXT_NAME, true, false)
		g_currentMission:registerActionEvents()
		g_currentMission:registerPauseActionEvents()

		spec.currentSeatIndex = seatIndex
		spec.passengerEntered = true

		self:enablePassengerActiveCamera()
		self:setPassengerSeatCharacter(seatIndex, playerStyle)
		self:requestActionEventUpdate()

		if g_gui:getIsGuiVisible() and oldContext ~= Vehicle.INPUT_CONTEXT_NAME then
			g_inputBinding:setContext(oldContext, false, false)
		end

		g_currentMission.controlPlayer = false
		g_currentMission.enteredPassengerVehicle = self

		g_currentMission.hud:setControlledVehicle(self)
		g_currentMission.hud:setIsControllingPlayer(false)

		if self.spec_enterable.playerHotspot ~= nil then
			self.spec_enterable.playerHotspot:setOwnerFarmId(g_currentMission:getFarmId())
			g_currentMission:addMapHotspot(self.spec_enterable.playerHotspot)
		end
	else
		self:setPassengerSeatCharacter(seatIndex, playerStyle)
	end

	local isEmpty = true

	for i = 1, #spec.passengerSeats do
		if spec.passengerSeats[i].isUsed then
			isEmpty = false

			break
		end
	end

	if isEmpty and not self:getIsControlled() then
		self:activate()
	end

	local currentSeat = spec.passengerSeats[seatIndex]

	if currentSeat ~= nil then
		currentSeat.isUsed = true
		currentSeat.playerStyle = playerStyle
		currentSeat.userId = userId
	end
end

function EnterablePassenger:leaveLocalPassengerSeat(isSeatSwitch, noEventSend)
	local spec = self.spec_enterablePassenger

	if spec.passengerEntered then
		if noEventSend ~= true then
			g_client:getServerConnection():sendEvent(PassengerLeaveEvent.new(self, spec.currentSeatIndex, isSeatSwitch))
		end

		self:leavePassengerSeat(true, spec.currentSeatIndex, isSeatSwitch)
	end
end

function EnterablePassenger:leavePassengerSeat(isOwner, seatIndex, isSeatSwitch)
	local spec = self.spec_enterablePassenger

	if isOwner then
		local specEnterable = self.spec_enterable

		if specEnterable.activeCamera ~= nil and spec.passengerEntered then
			specEnterable.activeCamera:onDeactivate()
			g_soundManager:setIsIndoor(false)
			g_currentMission.ambientSoundSystem:setIsIndoor(false)
			g_currentMission.activatableObjectsSystem:deactivate(Vehicle.INPUT_CONTEXT_NAME)
			g_depthOfFieldManager:reset()

			specEnterable.activeCamera = nil
		end

		self:setMirrorVisible(false)
		self:setPassengerSeatCharacter(seatIndex, nil)

		if not isSeatSwitch then
			g_inputBinding:resetActiveActionBindings()

			local prevContext = g_inputBinding:getContextName()
			local isVehicleContext = prevContext == BaseMission.INPUT_CONTEXT_VEHICLE
			local isInMenu = g_gui:getIsGuiVisible()

			if isInMenu then
				g_inputBinding:beginActionEventsModification(Player.INPUT_CONTEXT_NAME, true)
			else
				g_inputBinding:setContext(Player.INPUT_CONTEXT_NAME, true, isVehicleContext)
			end

			g_currentMission:registerActionEvents()

			g_currentMission.controlPlayer = true
			g_currentMission.enteredPassengerVehicle = nil

			g_currentMission.player:moveToExitPoint(self)
		end

		spec.currentSeatIndex = 1
		spec.passengerEntered = false

		if not isSeatSwitch then
			g_currentMission.player:onEnter(true)
			g_currentMission.player:onLeaveVehicle()

			g_currentMission.controlledVehicle = nil

			g_currentMission.hud:setIsControllingPlayer(true)
			g_currentMission.hud:setControlledVehicle(nil)

			local isInMenu = g_gui:getIsGuiVisible()

			if isInMenu then
				g_inputBinding:endActionEventsModification(true)
				g_inputBinding:setPreviousContext(Gui.INPUT_CONTEXT_MENU, Player.INPUT_CONTEXT_NAME)
			end

			g_currentMission:registerPauseActionEvents()
		end

		if self.spec_enterable.playerHotspot ~= nil then
			g_currentMission:removeMapHotspot(self.spec_enterable.playerHotspot)
		end
	else
		self:setPassengerSeatCharacter(seatIndex, nil)
	end

	local currentSeat = spec.passengerSeats[seatIndex]

	if currentSeat ~= nil then
		currentSeat.isUsed = false
		currentSeat.playerStyle = nil
		currentSeat.userId = nil
	end

	if not self:getIsControlled() then
		local isEmpty = true

		for i = 1, #spec.passengerSeats do
			if spec.passengerSeats[i].isUsed then
				isEmpty = false

				break
			end
		end

		if isEmpty then
			self:deactivate()
		end
	end
end

function EnterablePassenger:copyEnterableActiveCameraIndex(seatIndex)
	local spec = self.spec_enterablePassenger
	local specEnterable = self.spec_enterable

	if specEnterable.activeCamera ~= nil then
		if seatIndex ~= nil then
			local passengerSeat = spec.passengerSeats[seatIndex]

			if passengerSeat ~= nil then
				local foundCamera = false

				for camIndex = 1, #passengerSeat.cameras do
					local camera = passengerSeat.cameras[camIndex]

					if camera == specEnterable.activeCamera then
						passengerSeat.camIndex = camIndex
						foundCamera = true
					end
				end

				if not foundCamera then
					for camIndex = 1, #passengerSeat.cameras do
						local camera = passengerSeat.cameras[camIndex]

						if camera.isInside == specEnterable.activeCamera.isInside then
							passengerSeat.camIndex = camIndex

							break
						end
					end
				end
			end
		else
			local passengerSeat = spec.passengerSeats[spec.currentSeatIndex]

			if passengerSeat ~= nil then
				local foundCamera = false

				for camIndex = 1, #specEnterable.cameras do
					local camera = specEnterable.cameras[camIndex]

					if camera == specEnterable.activeCamera then
						specEnterable.camIndex = camIndex
						foundCamera = true
					end
				end

				if not foundCamera then
					for camIndex = 1, #specEnterable.cameras do
						local camera = specEnterable.cameras[camIndex]

						if camera.isInside == specEnterable.activeCamera.isInside then
							specEnterable.camIndex = camIndex

							break
						end
					end
				end
			end
		end
	end
end

function EnterablePassenger:setPassengerActiveCameraIndex(cameraIndex, seatIndex)
	local spec = self.spec_enterablePassenger
	local currentSeat = spec.passengerSeats[seatIndex or spec.currentSeatIndex]

	if currentSeat ~= nil then
		currentSeat.camIndex = cameraIndex or currentSeat.camIndex + 1

		if currentSeat.camIndex > #currentSeat.cameras then
			currentSeat.camIndex = 1
		end
	end

	self:enablePassengerActiveCamera()
end

function EnterablePassenger:enablePassengerActiveCamera()
	local spec = self.spec_enterablePassenger
	local specEnterable = self.spec_enterable

	if specEnterable.activeCamera ~= nil then
		specEnterable.activeCamera:onDeactivate()
	end

	local currentSeat = spec.passengerSeats[spec.currentSeatIndex]

	if currentSeat ~= nil then
		local activeCamera = currentSeat.cameras[currentSeat.camIndex]
		specEnterable.activeCamera = activeCamera

		activeCamera:onActivate()

		if activeCamera.isInside then
			g_depthOfFieldManager:setManipulatedParams(nil, 0.6, nil, , )
		else
			g_depthOfFieldManager:reset()
		end

		self:setMirrorVisible(activeCamera.useMirror)
		g_currentMission.environmentAreaSystem:setReferenceNode(activeCamera.cameraNode)
	end

	self:updatePassengerSeatCharacter(99999)
	self:raiseActive()
end

function EnterablePassenger:setPassengerSeatCharacter(seatIndex, playerStyle)
	local spec = self.spec_enterablePassenger
	local currentSeat = spec.passengerSeats[seatIndex]

	if currentSeat ~= nil and currentSeat.vehicleCharacter ~= nil then
		currentSeat.vehicleCharacter:unloadCharacter()

		if playerStyle ~= nil then
			currentSeat.vehicleCharacter:loadCharacter(playerStyle, self, EnterablePassenger.vehiclePassengerCharacterLoaded, {
				currentSeat
			})
		end
	end
end

function EnterablePassenger:updatePassengerSeatCharacter(dt)
	local spec = self.spec_enterablePassenger
	local currentSeat = spec.passengerSeats[spec.currentSeatIndex]

	if currentSeat ~= nil and currentSeat.vehicleCharacter ~= nil then
		currentSeat.vehicleCharacter:updateVisibility()
		currentSeat.vehicleCharacter:update(dt)
	end
end

function EnterablePassenger:onPassengerUserRemoved()
	if self.isServer then
		local spec = self.spec_enterablePassenger

		for seatIndex = 1, #spec.passengerSeats do
			local passengerSeat = spec.passengerSeats[seatIndex]

			if passengerSeat.isUsed then
				local user = g_currentMission.userManager:getUserByUserId(passengerSeat.userId)

				if user == nil then
					g_server:broadcastEvent(PassengerLeaveEvent.new(self, seatIndex, false), nil, , self)
					self:leavePassengerSeat(false, seatIndex)
				end
			end
		end
	end
end

function EnterablePassenger:onPassengerPlayerStyleChanged(style, userId)
	local spec = self.spec_enterablePassenger

	for seatIndex = 1, #spec.passengerSeats do
		local passengerSeat = spec.passengerSeats[seatIndex]

		if passengerSeat.userId == userId then
			self:setPassengerSeatCharacter(seatIndex, style)
		end
	end
end

function EnterablePassenger:vehiclePassengerCharacterLoaded(success, arguments)
	if success then
		local currentSeat = arguments[1]

		if currentSeat ~= nil then
			currentSeat.vehicleCharacter:updateVisibility()
			currentSeat.vehicleCharacter:updateIKChains()
		end
	end
end
