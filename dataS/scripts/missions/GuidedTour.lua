GuidedTour = {}
local GuidedTour_mt = Class(GuidedTour)

function GuidedTour.new(mission, customMt)
	local self = setmetatable({}, customMt or GuidedTour_mt)
	self.mission = mission
	self.isLoaded = false
	self.isRunning = false
	self.vehicles = {}
	self.iconFilename = nil
	self.steps = {}
	self.backgroundChecks = {}
	self.testBackgroundChecks = true
	self.finishedBackgroundChecks = {}

	return self
end

function GuidedTour:delete()
	g_messageCenter:unsubscribeAll(self)
	self:deleteIcon()
	self:deleteHotspot()
end

function GuidedTour:loadMapData(mapXmlFile, missionInfo, baseDirectory)
	self.missionInfo = missionInfo
	local filename = nil

	if missionInfo.scenario ~= nil then
		filename = missionInfo.scenario.configXMLFilename
	else
		filename = getXMLString(mapXmlFile, "map.guidedTour#filename")

		if filename == nil then
			self.missionInfo.guidedTourActive = false

			return
		end

		filename = Utils.getFilename(filename, baseDirectory)
	end

	local xmlFile = XMLFile.load("guidedTour", filename)

	if xmlFile == nil then
		self.missionInfo.guidedTourActive = false

		return
	end

	local iconFilename = xmlFile:getString("guidedTour.icon#filename")

	if iconFilename ~= nil then
		self.iconFilename = Utils.getFilename(iconFilename, baseDirectory)
	end

	if xmlFile:hasProperty("guidedTour.redirect") then
		local redirectText = xmlFile:getString("guidedTour.redirect#text")

		if redirectText == nil then
			Logging.warning("Guided tour redirect configuration is missing text attribute.")
		else
			self.redirectText = g_i18n:convertText(redirectText)
		end
	end

	self.startText = g_i18n:convertText(xmlFile:getString("guidedTour.header#startText", "$l10n_tour_text_start"))
	self.abortText = g_i18n:convertText(xmlFile:getString("guidedTour.header#abortText", "$l10n_tour_text_abort"))
	self.abortTitle = g_i18n:convertText(xmlFile:getString("guidedTour.header#abortTitle", "$l10n_tour_title_abort"))
	self.canAbort = xmlFile:getBool("guidedTour.header#tourCanAbort", true)
	self.allowTimeChange = xmlFile:getBool("guidedTour.header#allowTimeChange", false)

	xmlFile:iterate("guidedTour.step", function (index, key)
		local step = {
			activation = {},
			name = xmlFile:getString(key .. "#name")
		}

		table.insert(self.steps, step)
		self:loadStepContentsFromXML(xmlFile, key, step, baseDirectory)
	end)
	xmlFile:iterate("guidedTour.backgroundCheck", function (index, key)
		local name = xmlFile:getString(key .. "#name")

		if name == nil then
			Logging.error("Background checks need a 'name' attribute.")

			return
		end

		local step = {
			activation = {},
			name = name
		}

		table.insert(self.backgroundChecks, step)

		self.finishedBackgroundChecks[step.name] = false

		self:loadStepContentsFromXML(xmlFile, key, step, baseDirectory)
	end)
	xmlFile:delete()

	local stateItems = string.split(self.mission.missionInfo.guidedTourState, ";")

	for _, stepName in ipairs(stateItems) do
		if self.finishedBackgroundChecks[stepName] ~= nil then
			self.finishedBackgroundChecks[stepName] = true
		end
	end

	self.isLoaded = true

	if self.mission.missionDynamicInfo.isMultiplayer then
		self.missionInfo.guidedTourActive = false
	end

	if not self.mission:getIsTourSupported() then
		self.missionInfo.guidedTourActive = false
	end
end

function GuidedTour:loadStepContentsFromXML(xmlFile, key, step, baseDirectory)
	if xmlFile:hasProperty(key .. ".activation") then
		local iconPosition = xmlFile:getString(key .. ".activation.icon#position")

		if iconPosition ~= nil then
			local icon = {
				position = string.getVectorN(iconPosition, 2),
				targetIndicator = xmlFile:getBool(key .. ".activation.icon#targetIndicator", false)
			}
			step.activation.icon = icon
		end

		if xmlFile:hasProperty(key .. ".activation.check(0)") then
			step.activation.checks = {}

			self:loadChecksFromXML(xmlFile, key .. ".activation", step.activation.checks)
		end

		local triggerMarkerIndex = xmlFile:getInt(key .. ".activation.triggerMarker#index")

		if triggerMarkerIndex ~= nil then
			local triggerMarkerFilename = Utils.getFilename(xmlFile:getString(key .. ".activation.triggerMarker#filename"), baseDirectory)
			step.activation.triggerMarker = {
				filename = triggerMarkerFilename,
				index = triggerMarkerIndex,
				targetIndicator = xmlFile:getBool(key .. ".activation.triggerMarker#targetIndicator", false)
			}
		end

		step.isActivated = false
	else
		step.isActivated = true
	end

	if xmlFile:hasProperty(key .. ".dialog") then
		local dialog = {}
		step.dialog = dialog
		dialog.text = g_i18n:convertText(xmlFile:getString(key .. ".dialog#text"))
		dialog.inputs = {}

		xmlFile:iterate(key .. ".dialog.input", function (_, inputKey)
			local input = {
				action = xmlFile:getString(inputKey .. "#name"),
				action2 = xmlFile:getString(inputKey .. "#name2"),
				text = xmlFile:getString(inputKey .. "#text"),
				keyboardOnly = xmlFile:getBool(inputKey .. "#keyboardOnly", false),
				gamepadOnly = xmlFile:getBool(inputKey .. "#gamepadOnly", false)
			}

			table.insert(dialog.inputs, input)
		end)
	end

	if xmlFile:hasProperty(key .. ".mapHotspot") then
		step.mapHotspot = {
			vehicle = xmlFile:getString(key .. ".mapHotspot#vehicle"),
			targetIndicator = xmlFile:getBool(key .. ".mapHotspot#targetIndicator")
		}
		local position = xmlFile:getString(key .. ".mapHotspot#position")

		if position ~= nil then
			step.mapHotspot.position = string.getVectorN(position, 2)
		else
			step.mapHotspot.position = {
				0,
				0
			}
		end
	end

	if xmlFile:hasProperty(key .. ".goal") then
		step.goal = {
			checks = {}
		}

		self:loadChecksFromXML(xmlFile, key .. ".goal", step.goal.checks, baseDirectory)
	end
end

function GuidedTour:loadChecksFromXML(xmlFile, key, checks, baseDirectory)
	xmlFile:iterate(key .. ".check", function (_, checkKey)
		local check = {
			name = xmlFile:getString(checkKey .. "#name"),
			vehicle = xmlFile:getString(checkKey .. "#vehicle"),
			toVehicle = xmlFile:getString(checkKey .. "#toVehicle"),
			fillUnitIndex = xmlFile:getInt(checkKey .. "#fillUnit"),
			fillLevel = xmlFile:getInt(checkKey .. "#fillLevel"),
			value = xmlFile:getInt(checkKey .. "#value"),
			valueType = xmlFile:getString(checkKey .. "#valueType"),
			comparator = xmlFile:getString(checkKey .. "#comparator"),
			attribute = xmlFile:getString(checkKey .. "#attribute")
		}
		local filename = xmlFile:getString(checkKey .. "#filename")

		if filename ~= nil then
			check.filename = Utils.getFilename(filename, baseDirectory)
		end

		table.insert(checks, check)
	end)
end

function GuidedTour:getIsRunning()
	return self.isRunning
end

function GuidedTour:getCanAbort()
	return self.canAbort
end

function GuidedTour:getBlocksTimeChange()
	return self.isRunning and not self.allowTimeChange
end

function GuidedTour:updateMissionState()
	local str = ""

	for name, done in pairs(self.finishedBackgroundChecks) do
		if done then
			str = str .. name .. ";"
		end
	end

	self.mission.missionInfo.guidedTourState = str
end

function GuidedTour:addVehicle(vehicle, name)
	self.vehicles[name] = vehicle
end

function GuidedTour:removeVehicle(name)
	self.vehicles[name] = nil

	if self.isRunning then
		self:onFinished()
	end
end

function GuidedTour:abort()
	if self.missionInfo.guidedTourActive and self.canAbort then
		self.missionInfo.guidedTourActive = false
		local title = ""

		if self.isRunning then
			title = self.abortTitle

			self:onFinished()
		end

		if GS_IS_MOBILE_VERSION then
			g_gui:showInfoDialog({
				title = title,
				text = self.abortText
			})
		else
			self.mission.hud:showInGameMessage(title, self.abortText, -1)
		end
	end
end

function GuidedTour:onStarted()
	self.isRunning = true

	self:loadHotspot()

	if self.mission.helpIconsBase ~= nil then
		self.mission.helpIconsBase:showHelpIcons(false, true)
	end

	self:loadIcon()
end

function GuidedTour:onFinished()
	self.vehicles = {}

	self:deleteIcon()
	self:deleteHotspot()

	self.isRunning = false
	self.missionInfo.guidedTourActive = false

	if g_gameSettings:getValue("showHelpIcons") and self.mission.helpIconsBase ~= nil then
		self.mission.helpIconsBase:showHelpIcons(true, true)
	end

	g_messageCenter:publish(MessageType.MISSION_TOUR_FINISHED)
end

function GuidedTour:update(dt)
	if self.redirectText ~= nil then
		if self.missionInfo.guidedTourActive and not g_gui:getIsGuiVisible() and self.missionInfo.guidedTourStep == 0 then
			g_gui:showInfoDialog({
				title = "",
				text = self.redirectText
			})

			self.missionInfo.guidedTourStep = 1
		end

		return
	end

	if not self.isRunning and self.missionInfo.guidedTourActive and not g_gui:getIsGuiVisible() then
		if self.missionInfo.guidedTourStep == 0 then
			if self.canAbort then
				g_gui:showYesNoDialog({
					title = "",
					text = self.startText,
					callback = self.onReactToDialog,
					target = self
				})
			else
				self:onStarted()
			end
		else
			self:onStarted()
		end
	end

	if self.isRunning then
		if self.goalPredicate ~= nil then
			local goalAchieved = self.goalPredicate()

			if goalAchieved then
				self.goalAchievedCallback()
			end
		end

		if self.testBackgroundChecks then
			self:runBackgroundChecks()
		end
	end
end

function GuidedTour:onReactToDialog(yes)
	if yes then
		self:onStarted()
	else
		self:abort()
	end
end

function GuidedTour:onIconTrigger(_, _, onEnter)
	if onEnter and self.iconTriggerCallback ~= nil then
		self.iconTriggerCallback()
	end
end

function GuidedTour:onMessageClosed()
	if self.messageClosedCallback ~= nil then
		self.messageClosedCallback()
	end
end

function GuidedTour:runStep(index, fromTrigger, fromDialog)
	if index == 0 then
		index = 1
	end

	if index < self.missionInfo.guidedTourStep then
		return
	end

	if index > #self.steps then
		self:onFinished()

		return
	end

	self.missionInfo.guidedTourStep = index
	local step = self.steps[index]

	if step.activation ~= nil and step.activation.icon ~= nil and not fromTrigger then
		local icon = step.activation.icon
		local x, z = unpack(icon.position)

		self:setIcon(true, x, z, step.activation.icon.targetIndicator)

		function self.iconTriggerCallback()
			step.isActivated = true
			self.iconTriggerCallback = nil

			self:runStep(index, true, false)
		end

		return
	elseif step.activation ~= nil and step.activation.triggerMarker ~= nil and not fromTrigger then
		local placeable = self:findFirstPlaceable(step.activation.triggerMarker.filename)

		if placeable ~= nil then
			local x, _, z = placeable:getTriggerMarkerPosition(step.activation.triggerMarker.index)

			self:setIcon(true, x, z, step.activation.triggerMarker.targetIndicator, true)

			function self.iconTriggerCallback()
				step.isActivated = true
				self.iconTriggerCallback = nil

				self:runStep(index, true, false)
			end

			return
		else
			self:setIcon(false)
		end
	else
		self:setIcon(false)
	end

	if step.mapHotspot ~= nil then
		local x, z = unpack(step.mapHotspot.position)

		self:setHotspot(true, step.mapHotspot.targetIndicator, x, z, step.mapHotspot.vehicle)
	else
		self:setTargetIndicator(false)
	end

	if step.dialog ~= nil and not fromDialog then
		self:showDialog(step.dialog, function ()
			self:runStep(index, fromTrigger, true)
		end)

		return
	end

	if step.goal ~= nil then
		function self.goalPredicate()
			for _, check in ipairs(step.goal.checks) do
				if not self:performCheck(check) then
					return false
				end
			end

			return true
		end

		function self.goalAchievedCallback()
			self.goalPredicate = nil

			self:runStep(index + 1, false, false)
		end

		return
	else
		self:runStep(index + 1, false, false)
	end
end

function GuidedTour:runBackgroundChecks()
	for _, backgroundCheck in ipairs(self.backgroundChecks) do
		if not self.finishedBackgroundChecks[backgroundCheck.name] then
			local isActivated = true

			for _, check in ipairs(backgroundCheck.activation.checks) do
				if not self:performCheck(check) then
					isActivated = false

					break
				end
			end

			if isActivated then
				self.testBackgroundChecks = false
				self.finishedBackgroundChecks[backgroundCheck.name] = true

				self:updateMissionState()

				if backgroundCheck.dialog ~= nil then
					self:showDialog(backgroundCheck.dialog, function ()
						self.testBackgroundChecks = true
					end)
				end
			end
		end
	end
end

function GuidedTour:showDialog(dialog, callback)
	local controls = {}
	local useGamepadButtons = g_inputBinding:getInputHelpMode() == GS_INPUT_HELP_MODE_GAMEPAD

	for _, input in ipairs(dialog.inputs) do
		local action1 = InputAction[input.action]
		local action2 = input.action2 ~= nil and InputAction[input.action2] or nil

		if (not input.keyboardOnly or not useGamepadButtons) and (not input.gamepadOnly or useGamepadButtons) then
			table.insert(controls, g_inputDisplayManager:getControllerSymbolOverlays(action1, action2, g_i18n:convertText(input.text)))
		end
	end

	if self.mission.controlledVehicle ~= nil and self.mission.controlledVehicle.setCruiseControlState ~= nil then
		self.mission.controlledVehicle:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF)
	end

	function self.messageClosedCallback()
		self.messageClosedCallback = nil

		callback()
	end

	self.mission.hud:showInGameMessage(g_i18n:getText("ui_tour"), g_i18n:convertText(dialog.text), -1, controls, self.onMessageClosed, self)
end

function GuidedTour:loadIcon()
	if self.iconFilename ~= nil then
		g_i3DManager:loadI3DFileAsync(self.iconFilename, true, true, GuidedTour.onIconLoaded, self, nil)
	end
end

function GuidedTour:onIconLoaded(i3dNode, failedReason, args)
	if i3dNode ~= 0 then
		self.icon = i3dNode

		link(getRootNode(), self.icon)
		addTrigger(getChildAt(getChildAt(self.icon, 0), 0), "onIconTrigger", self)
		setWorldTranslation(self.icon, 0, -100, 0)
		g_messageCenter:publish(MessageType.MISSION_TOUR_STARTED)
		self:runStep(self.missionInfo.guidedTourStep, false, false)
	end
end

function GuidedTour:deleteIcon()
	if self.icon ~= nil then
		removeTrigger(getChildAt(getChildAt(self.icon, 0), 0))
		delete(self.icon)

		self.icon = nil
	end
end

function GuidedTour:setIcon(active, x, z, targetIndicator, extraGroundOffset)
	setVisibility(self.icon, active)

	if active then
		local y = getTerrainHeightAtWorldPos(self.mission.terrainRootNode, x, 0, z)

		if extraGroundOffset then
			y = y + 1.2
		end

		setWorldTranslation(self.icon, x, y, z)
	end

	self:setHotspot(active, targetIndicator, x, z)
end

function GuidedTour:loadHotspot()
	self.mapHotspot = TourHotspot.new()

	self.mission:addMapHotspot(self.mapHotspot)
end

function GuidedTour:deleteHotspot()
	if self.mapHotspot ~= nil then
		self.mission:removeMapHotspot(self.mapHotspot)
		self.mapHotspot:delete()

		self.mapHotspot = nil
	end
end

function GuidedTour:setHotspot(active, targetIndicator, x, z, vehicle)
	self.mapHotspot:setVisible(active)

	if active then
		if vehicle ~= nil then
			local _ = nil
			x, _, z = getWorldTranslation(self.vehicles[vehicle].rootNode)
		end

		self.mapHotspot:setWorldPosition(x, z)
	end

	self:setTargetIndicator(active and targetIndicator)
end

function GuidedTour:setTargetIndicator(active)
	if active then
		self.mission:setMapTargetHotspot(self.mapHotspot)
	else
		self.mission:setMapTargetHotspot(nil)
	end
end

function GuidedTour:performCheck(check)
	if check.name == "vehicleIsControlled" then
		return self.mission.controlledVehicle ~= nil and self.mission.controlledVehicle == self.vehicles[check.vehicle]
	elseif check.name == "vehicleIsMotorStarted" then
		local vehicle = self.vehicles[check.vehicle]

		if vehicle == nil or vehicle.getIsMotorStarted == nil then
			Logging.warning("Vehicle %s does not exist or has no motor", vehicle:getFullName())

			return false
		else
			return vehicle:getIsMotorStarted()
		end
	elseif check.name == "vehicleIsTurnedOn" then
		local vehicle = self.vehicles[check.vehicle]

		if vehicle == nil or vehicle.getIsTurnedOn == nil then
			Logging.warning("Vehicle %s does not exist or cannot be turned on", vehicle:getFullName())

			return false
		else
			return vehicle:getIsTurnedOn()
		end
	elseif check.name == "vehicleIsAIActive" then
		local vehicle = self.vehicles[check.vehicle]

		if vehicle == nil or vehicle.getIsAIActive == nil then
			Logging.warning("Vehicle %s does not exist or does not support AI", vehicle:getFullName())

			return false
		else
			return vehicle:getIsAIActive()
		end
	elseif check.name == "combineHasCutterAttached" then
		return self.vehicles[check.vehicle].spec_combine.numAttachedCutters > 0
	elseif check.name == "vehicleAttachedTo" then
		return self.vehicles[check.vehicle].rootVehicle == self.vehicles[check.toVehicle]
	elseif check.name == "playerIsWalking" then
		return self.mission.controlledVehicle == nil
	elseif check.name == "fillLevelAbove" then
		return check.fillLevel <= self.vehicles[check.vehicle]:getFillUnitFillLevel(check.fillUnitIndex)
	elseif check.name == "fillLevelBelow" then
		return self.vehicles[check.vehicle]:getFillUnitFillLevel(check.fillUnitIndex) <= check.fillLevel
	elseif check.name == "vehicle.isOwned" then
		return self:findFirstVehicle(check.filename) ~= nil
	elseif check.name == "vehicle.isNotOwned" then
		return self:findFirstVehicle(check.filename) == nil
	elseif check.name == "vehicle.isAnyControlled" then
		if check.filename == nil then
			return self.mission.controlledVehicle ~= nil
		else
			return self.mission.controlledVehicle ~= nil and self.mission.controlledVehicle.configFileName == check.filename
		end
	elseif check.name == "vehicle.fillLevel" then
		local vehicle = self:findFirstVehicle(check.filename)

		if vehicle == nil then
			return false
		end

		local totalFillLevel = 0
		local fillInfo = {
			addFillLevel = function (_, fillLevel, _)
				totalFillLevel = totalFillLevel + fillLevel
			end
		}

		vehicle:getFillLevelInformation(fillInfo)

		return self:performComparison(totalFillLevel, check.value, "number", check.comparator)
	elseif check.name == "stats.attribute" then
		return self:performComparison(self.mission:farmStats():getTotalValue(check.attribute), check.value, "number", check.comparator)
	elseif check.name == "money.above" then
		return check.value <= self.mission:getMoney()
	elseif check.name == "money.below" then
		return self.mission:getMoney() < check.value
	elseif check.name == "placeable.isPlaced" then
		return self:findFirstPlaceable(check.filename) ~= nil
	elseif check.name == "placeable.attribute" then
		local placeable = self:findFirstPlaceable(check.filename)

		return placeable ~= nil and self:performAttributeCheckOnObject(placeable, check)
	elseif check.name == "placeable.numAnimals" then
		local placeable = self:findFirstPlaceable(check.filename)

		return placeable ~= nil and self:performComparison(placeable:getNumOfAnimals(), check.value, "number", check.comparator)
	elseif check.name == "placeable.foodLevel" then
		local placeable = self:findFirstPlaceable(check.filename)

		return placeable ~= nil and self:performComparison(placeable:getTotalFood(), check.value, "number", check.comparator)
	elseif check.name == "placeable.animalPalletFillLevel" then
		local placeable = self:findFirstPlaceable(check.filename)

		return placeable ~= nil and self:performComparison(placeable.spec_husbandryPallets.fillLevel, check.value, "number", check.comparator)
	elseif check.name == "farm.attribute" then
		local farm = g_farmManager:getFarmById(self.mission:getFarmId())

		return self:performAttributeCheckOnObject(farm, check)
	elseif check.name == "time.period" then
		return self:performComparison(self.mission.environment.currentPeriod, check.value, "number", check.comparator)
	elseif check.name == "time.hour" then
		return self:performComparison(self.mission.environment.currentHour, check.value, "number", check.comparator)
	end

	return false
end

function GuidedTour:findFirstPlaceable(xmlFilename)
	local farmId = self.mission:getFarmId()

	for _, placeable in ipairs(self.mission.placeableSystem.placeables) do
		if placeable.configFileName == xmlFilename and placeable:getOwnerFarmId() == farmId then
			return placeable
		end
	end

	return nil
end

function GuidedTour:findFirstVehicle(xmlFilename)
	local farmId = self.mission:getFarmId()

	for _, vehicle in ipairs(self.mission.vehicles) do
		if vehicle.configFileName == xmlFilename and vehicle:getOwnerFarmId() == farmId then
			return vehicle
		end
	end

	return nil
end

function GuidedTour:performAttributeCheckOnObject(object, check)
	return false
end

function GuidedTour:performComparison(valueCheckWith, value, valueType, comparator)
	if type(valueCheckWith) ~= valueType then
		return false
	end

	if valueType == "number" then
		value = tonumber(value)

		if comparator == "lt" then
			return valueCheckWith < value
		elseif comparator == "lte" then
			return valueCheckWith <= value
		elseif comparator == "eq" then
			return valueCheckWith == value
		elseif comparator == "neq" then
			return valueCheckWith ~= value
		elseif comparator == "gt" then
			return value < valueCheckWith
		elseif comparator == "gte" then
			return value <= valueCheckWith
		end

		return false
	elseif valueType == "bool" then
		value = value == "true"

		return valueCheckWith == value
	elseif valueType == "string" then
		if comparator == "eq" then
			return valueCheckWith == value
		else
			return valueCheckWith ~= value
		end
	end
end

function GuidedTour:getPassedSteps()
	local dialogs = {}

	for index = 1, self.missionInfo.guidedTourStep do
		local step = self.steps[index]

		if step.dialog ~= nil and step.isActivated then
			table.insert(dialogs, step.dialog)
		end
	end

	return dialogs
end
