PrecisionFarmingSettings = {
	MOD_NAME = g_currentModName
}
local PrecisionFarmingSettings_mt = Class(PrecisionFarmingSettings)

function PrecisionFarmingSettings.new(precisionFarming, customMt)
	local self = setmetatable({}, customMt or PrecisionFarmingSettings_mt)
	self.precisionFarming = precisionFarming
	self.elementsCreated = false
	self.settingsHeadline = g_i18n:getText("ui_header")
	self.settings = {}

	return self
end

function PrecisionFarmingSettings:addSetting(name, title, description, callback, callbackTarget, default, isCheckbox, optionTexts)
	local setting = {
		name = name,
		title = title,
		description = description
	}

	if default ~= nil then
		setting.state = default
	elseif isCheckbox then
		setting.state = false
	else
		setting.state = 0
	end

	setting.callback = callback
	setting.callbackTarget = callbackTarget
	setting.isCheckbox = isCheckbox
	setting.optionTexts = optionTexts
	setting.element = nil

	table.insert(self.settings, setting)
	self:loadSettings()
	self:onSettingChanged(setting)
end

function PrecisionFarmingSettings:onSettingChanged(setting)
	if setting.callback ~= nil and setting.callbackTarget == nil then
		setting.callback(setting.state)
	elseif setting.callback ~= nil and setting.callbackTarget ~= nil then
		setting.callback(setting.callbackTarget, setting.state)
	end

	self:saveSettings()
end

function PrecisionFarmingSettings:saveSettings()
	if g_savegameXML ~= nil then
		for i = 1, #self.settings do
			local setting = self.settings[i]

			if setting.isCheckbox then
				setXMLBool(g_savegameXML, string.format("gameSettings.precisionFarming.settings.%s#state", setting.name), setting.state)
			else
				setXMLInt(g_savegameXML, string.format("gameSettings.precisionFarming.settings.%s#state", setting.name), setting.state)
			end
		end
	end

	g_gameSettings:saveToXMLFile(g_savegameXML)
end

function PrecisionFarmingSettings:loadSettings()
	if g_savegameXML ~= nil then
		for i = 1, #self.settings do
			local setting = self.settings[i]

			if setting.isCheckbox then
				setting.state = Utils.getNoNil(getXMLBool(g_savegameXML, string.format("gameSettings.precisionFarming.settings.%s#state", setting.name)), setting.state)
			else
				setting.state = Utils.getNoNil(getXMLInt(g_savegameXML, string.format("gameSettings.precisionFarming.settings.%s#state", setting.name)), setting.state)
			end
		end
	end
end

function PrecisionFarmingSettings:onClickCheckbox(state, checkboxElement)
	for i = 1, #self.settings do
		local setting = self.settings[i]

		if setting.element == checkboxElement then
			setting.state = state == CheckedOptionElement.STATE_CHECKED

			self:onSettingChanged(setting)
		end
	end
end

function PrecisionFarmingSettings:onClickMultiOption(state, optionElement)
	for i = 1, #self.settings do
		local setting = self.settings[i]

		if setting.element == optionElement then
			setting.state = state

			self:onSettingChanged(setting)
		end
	end
end

function PrecisionFarmingSettings:overwriteGameFunctions(pfModule)
	pfModule:overwriteGameFunction(InGameMenuGeneralSettingsFrame, "onFrameOpen", function (superFunc, frame, element)
		superFunc(frame, element)

		if not self.elementsCreated then
			for i = 1, #frame.boxLayout.elements do
				local elem = frame.boxLayout.elements[i]

				if elem:isa(TextElement) then
					local header = elem:clone(frame.boxLayout)

					header:setText(self.settingsHeadline)
					header:reloadFocusHandling(true)

					break
				end
			end

			for i = 1, #self.settings do
				local setting = self.settings[i]

				if setting.isCheckbox then
					setting.element = frame.checkUseEasyArmControl:clone(frame.boxLayout)

					function setting.element.onClickCallback(_, ...)
						self:onClickCheckbox(...)
					end

					setting.element:reloadFocusHandling(true)
					setting.element:setIsChecked(setting.state)
				else
					setting.element = frame.multiRealBeaconLightBrightness:clone(frame.boxLayout)

					setting.element:setTexts(setting.optionTexts)

					function setting.element.onClickCallback(_, ...)
						self:onClickMultiOption(...)
					end

					setting.element:reloadFocusHandling(true)
					setting.element:setState(setting.state)
				end

				setting.element.elements[4]:setText(setting.title)
				setting.element.elements[6]:setText(setting.description)
			end

			frame.boxLayout:invalidateLayout()

			self.elementsCreated = true
		end
	end)
	pfModule:overwriteGameFunction(InGameMenuGameSettingsFrame, "onFrameOpen", function (superFunc, frame, element)
		if frame.checkLimeRequired ~= nil then
			frame.checkLimeRequired:setVisible(false)
			frame.checkLimeRequired.parent:invalidateLayout()
		end

		superFunc(frame, element)
	end)
end
