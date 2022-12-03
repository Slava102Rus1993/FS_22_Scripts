SettingsDeviceFrame = {}
local SettingsDeviceFrame_mt = Class(SettingsDeviceFrame, TabbedMenuFrameElement)
SettingsDeviceFrame.CONTROLS = {
	"titleElement",
	"settingsContainer",
	"layout",
	"sectionTemplate",
	"deadzoneTemplate",
	"sensitivityTemplate",
	"disclaimerLabel"
}

function SettingsDeviceFrame.new(target, custom_mt, settingsModel, l10n)
	local self = TabbedMenuFrameElement.new(target, custom_mt or SettingsDeviceFrame_mt)

	self:registerControls(SettingsDeviceFrame.CONTROLS)

	self.settingsModel = settingsModel
	self.l10n = l10n
	self.hasCustomMenuButtons = true
	self.stateBars = {}

	return self
end

function SettingsDeviceFrame:copyAttributes(src)
	SettingsDeviceFrame:superClass().copyAttributes(self, src)

	self.settingsModel = src.settingsModel
	self.l10n = src.l10n
	self.hasCustomMenuButtons = src.hasCustomMenuButtons
end

function SettingsDeviceFrame:initialize()
	self.sectionTemplate:unlinkElement()
	FocusManager:removeElement(self.sectionTemplate)
	self.deadzoneTemplate:unlinkElement()
	FocusManager:removeElement(self.deadzoneTemplate)
	self.sensitivityTemplate:unlinkElement()
	FocusManager:removeElement(self.sensitivityTemplate)

	self.backButtonInfo = {
		inputAction = InputAction.MENU_BACK
	}
	self.switchButtonInfo = {
		inputAction = InputAction.MENU_EXTRA_1,
		text = self.l10n:getText(SettingsDeviceFrame.L10N_SYMBOL.SWITCH_DEVICE),
		callback = function ()
			self:onSwitchDevice()
		end
	}
	self.applyButtonInfo = {
		inputAction = InputAction.MENU_ACCEPT,
		text = self.l10n:getText(SettingsDeviceFrame.L10N_SYMBOL.BUTTON_APPLY),
		callback = function ()
			self:onApplySettings()
		end
	}

	self:updateController()
end

function SettingsDeviceFrame:delete()
	self.sectionTemplate:delete()
	self.deadzoneTemplate:delete()
	self.sensitivityTemplate:delete()
	SettingsDeviceFrame:superClass().delete(self)
end

function SettingsDeviceFrame:onFrameOpen()
	self.settingsModel:initDeviceSettings()
	self.settingsModel:refresh()
	self:updateView()
	self.disclaimerLabel:setVisible(GS_PLATFORM_GGP)
end

function SettingsDeviceFrame:getMenuButtonInfo()
	local buttons = {}

	if self.settingsModel:hasChanges() then
		table.insert(buttons, self.applyButtonInfo)
	end

	table.insert(buttons, self.backButtonInfo)

	if self.settingsModel:getNumDevices() > 1 then
		table.insert(buttons, self.switchButtonInfo)
	end

	return buttons
end

function SettingsDeviceFrame:onApplySettings()
	self.settingsModel:saveChanges(SettingsModel.SETTING_CLASS.SAVE_ALL)
	g_gui:showInfoDialog({
		text = self.l10n:getText(SettingsDeviceFrame.L10N_SYMBOL.SAVING_FINISHED),
		dialogType = DialogElement.TYPE_INFO
	})
end

function SettingsDeviceFrame:onSwitchDevice()
	self.settingsModel:nextDevice()
	self:updateView()
end

function SettingsDeviceFrame:update(dt)
	SettingsDeviceFrame:superClass().update(self, dt)

	local numOfGamepads = getNumOfGamepads()

	if numOfGamepads ~= self.numOfGamepads then
		self:updateController()
	end

	self:updateGamepadInputStates()
end

function SettingsDeviceFrame:updateGamepadInputStates()
	for _, barInfo in pairs(self.stateBars) do
		local device = self.settingsModel.deviceSettings[self.settingsModel.currentDevice].device
		local gamepadIndex = device.internalId
		local deadzone = self.settingsModel:getCurrentDeviceDeadzoneValue(barInfo.axisIndex)
		local sensitivity = self.settingsModel:getCurrentDeviceSensitivityValue(barInfo.axisIndex)
		local neutralInput = 0
		local value = g_inputBinding:getGamepadAxisValue(gamepadIndex, barInfo.axisIndex, "", neutralInput, deadzone)
		value = value * sensitivity
		value = MathUtil.clamp(value, -1, 1)
		local bar = barInfo.element.elements[1]
		local boxSize = barInfo.element.absSize[1]

		bar:setSize(math.max(math.abs(value) * boxSize * 0.5, 2 / g_screenWidth))

		if value < 0 then
			bar:setPosition((1 - math.abs(value)) * boxSize * 0.5)
		else
			bar:setPosition(boxSize * 0.5)
		end

		barInfo.element:updateAbsolutePosition()
	end
end

function SettingsDeviceFrame:updateController()
	self.numOfGamepads = getNumOfGamepads()

	self.settingsModel:initDeviceSettings()
	self:updateView()
	self:setMenuButtonInfoDirty()
end

function SettingsDeviceFrame:updateView()
	local name = self.settingsModel:getCurrentDeviceName()

	if name == InputDevice.DEFAULT_DEVICE_NAMES.KB_MOUSE_DEFAULT then
		name = self.l10n:getText("ui_mouse")
	elseif self.l10n:hasText(name) then
		name = self.l10n:getText(name)
	end

	self.titleElement:setText(string.format("%s: %s", self.l10n:getText("ui_deviceConfiguration"), name))

	local firstOptionElement = nil

	function addSectionHeader(title, axis)
		local cell = self.sectionTemplate:clone(self.layout)

		cell:reloadFocusHandling(true)
		cell:getDescendantByName("title"):setText(title)

		local box = cell:getDescendantByName("box")

		box:setVisible(axis ~= nil)

		if axis ~= nil then
			table.insert(self.stateBars, {
				element = box,
				axisIndex = axis
			})
		end
	end

	for i = 1, #self.layout.elements do
		self.layout.elements[1]:delete()
	end

	self.stateBars = {}
	local isMouse = self.settingsModel:getIsDeviceMouse()

	if isMouse then
		addSectionHeader(self.l10n:getText("ui_mouse"))

		local optionElement = self.sensitivityTemplate:clone(self.layout)

		optionElement:reloadFocusHandling(true)
		optionElement:setTexts(self.settingsModel:getSensitivityTexts())
		optionElement:setState(self.settingsModel:getMouseSensitivityValue())

		function optionElement.onClickCallback(_, state)
			self.settingsModel:setMouseSensitivity(state)
			self:setMenuButtonInfoDirty()
		end

		if firstOptionElement == nil then
			firstOptionElement = optionElement
		end
	end

	local hasHeadTracking = g_gameSettings:getValue("isHeadTrackingEnabled") and isHeadTrackingAvailable()
	local isKeyboardAvailable = getIsKeyboardAvailable()
	local isHeadTrackingVisible = hasHeadTracking and (isMouse or not isKeyboardAvailable)

	if isHeadTrackingVisible then
		addSectionHeader(self.l10n:getText("setting_headTracking"))

		local optionElement = self.sensitivityTemplate:clone(self.layout)

		optionElement:reloadFocusHandling(true)
		optionElement:setTexts(self.settingsModel:getHeadTrackingSensitivityTexts())
		optionElement:setState(self.settingsModel:getHeadTrackingSensitivityValue())

		function optionElement.onClickCallback(_, state)
			self.settingsModel:setHeadTrackingSensitivity(state)
			self:setMenuButtonInfoDirty()
		end

		if firstOptionElement == nil then
			firstOptionElement = optionElement
		end
	end

	if not isMouse then
		local device = self.settingsModel.deviceSettings[self.settingsModel.currentDevice].device
		local gamepadIndex = device.internalId

		for axis = 0, Input.MAX_NUM_AXES - 1 do
			local hasDeadzone = self.settingsModel:getDeviceHasAxisDeadzone(axis)
			local hasSensitiviy = self.settingsModel:getDeviceHasAxisSensitivity(axis)

			if hasDeadzone or hasSensitiviy then
				local label = getGamepadAxisLabel(axis, gamepadIndex)
				local title = string.format(self.l10n:getText("setting_gamepadAxis"), axis + 1)

				if label ~= "" then
					title = title .. " (" .. label .. ")"
				end

				addSectionHeader(title, axis)

				if hasDeadzone then
					local optionElement = self.deadzoneTemplate:clone(self.layout)

					optionElement:reloadFocusHandling(true)
					optionElement:setTexts(self.settingsModel:getDeadzoneTexts())
					optionElement:setState(self.settingsModel:getDeviceAxisDeadzoneValue(axis))

					function optionElement.onClickCallback(_, state)
						self.settingsModel:setDeviceDeadzoneValue(axis, state)
						self:setMenuButtonInfoDirty()
					end

					if firstOptionElement == nil then
						firstOptionElement = optionElement
					end
				end

				if hasSensitiviy then
					local optionElement = self.sensitivityTemplate:clone(self.layout)

					optionElement:reloadFocusHandling(true)
					optionElement:setTexts(self.settingsModel:getSensitivityTexts())
					optionElement:setState(self.settingsModel:getDeviceAxisSensitivityValue(axis))

					function optionElement.onClickCallback(_, state)
						self.settingsModel:setDeviceSensitivityValue(axis, state)
						self:setMenuButtonInfoDirty()
					end

					if firstOptionElement == nil then
						firstOptionElement = optionElement
					end
				end
			end
		end
	end

	self.layout:scrollTo(0, true)
	self.layout:invalidateLayout()

	if firstOptionElement ~= nil then
		self.layout:scrollToMakeElementVisible(firstOptionElement)
		FocusManager:setFocus(firstOptionElement)

		firstOptionElement.forceFocusScrollToTop = true
	end
end

SettingsDeviceFrame.L10N_SYMBOL = {
	BUTTON_APPLY = "button_apply",
	SAVING_FINISHED = "ui_savingFinished",
	SWITCH_DEVICE = "ui_switchDevice"
}
