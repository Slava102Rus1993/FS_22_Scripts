InGameMenuGeneralSettingsFrame = {}
local InGameMenuGeneralSettingsFrame_mt = Class(InGameMenuGeneralSettingsFrame, TabbedMenuFrameElement)
InGameMenuGeneralSettingsFrame.CONTROLS = {
	CHECKBOX_WOOD_HARVESTER_AUTO_CUT = "checkWoodHarvesterAutoCut",
	OPTION_VOICE_INPUT_SENSITIVITY = "multiVoiceInputSensitivity",
	CHECKBOX_USE_EASY_ARM_CONTROLER = "checkUseEasyArmControl",
	OPTION_REAL_BEACON_LIGHT = "multiRealBeaconLightBrightness",
	CHECKBOX_INVERT_Y_LOOK = "checkInvertYLook",
	CHECKBOX_AUTO_HELP = "checkAutoHelp",
	CHECKBOX_SHOW_MULTIPLAYER_NAMES = "checkShowMultiplayerNames",
	CHECKBOX_SHOW_FIELD_INFO = "checkShowFieldInfo",
	OPTION_VOLUME_RADIO = "multiRadioVolume",
	CHECKBOX_USE_MILES = "checkUseMiles",
	OPTION_MONEY_UNIT = "multiMoneyUnit",
	OPTION_VEHICLE_ARM_SENSITIVITY = "multiVehicleArmSensitivity",
	OPTION_HUD_SPEED_GAUGE = "multiHudSpeedGauge",
	OPTION_VOLUME_VEHICLE = "multiVehicleVolume",
	CHECKBOX_SHOW_HELP_TRIGGER = "checkShowHelpTrigger",
	OPTION_VOLUME_MASTER = "multiMasterVolume",
	OPTION_VOLUME_VOICE = "multiVolumeVoice",
	CHECKBOX_RESET_CAMERA = "checkResetCamera",
	CHECKBOX_SHOW_TRIGGER_MARKER = "checkShowTriggerMarker",
	CHECKBOX_IS_TRAIN_TABBABLE = "checkIsTrainTabbable",
	OPTION_INPUT_HELP_MODE = "multiInputHelpMode",
	OPTION_VOICE_MODE = "multiVoiceMode",
	SETTINGS_CONTAINER = "settingsContainer",
	BOX_LAYOUT = "boxLayout",
	CHECKBOX_IS_RADIO_VEHICLE_ONLY = "checkIsRadioVehicleOnly",
	CHECKBOX_ACTIVE_SUSPENSION_CAMERA = "checkActiveSuspensionCamera",
	CHECKBOX_IS_RADIO_ACTIVE = "checkIsRadioActive",
	CHECKBOX_USE_WORLD_CAMERA = "checkUseWorldCamera",
	OPTION_GEAR_SHIFT_MODE = "multiGearShiftMode",
	OPTION_VOLUME_VOICE_INPUT = "multiVolumeVoiceInput",
	CHECKBOX_USE_ACRE = "checkUseAcre",
	CHECKBOX_COLORBLIND_MODE = "checkColorBlindMode",
	OPTION_STEERING_SENSITIVITY = "multiSteeringSensitivity",
	OPTION_STEERING_BACK_SPEED = "multiSteeringBackSpeed",
	CHECKBOX_USE_FAHRENHEIT = "checkUseFahrenheit",
	OPTION_VOLUME_GUI = "multiVolumeGUI",
	OPTION_DIRECTION_CHANGE_MODE = "multiDirectionChangeMode",
	OPTION_VOLUME_ENVIRONMENT = "multiEnvironmentVolume",
	OPTION_CAMERA_SENSITIVITY = "multiCameraSensitivity",
	CHECKBOX_CAMERA_CHECK_COLLISION = "checkCameraCheckCollision"
}

function InGameMenuGeneralSettingsFrame.new(subclass_mt, settingsModel)
	local self = TabbedMenuFrameElement.new(nil, subclass_mt or InGameMenuGeneralSettingsFrame_mt)

	self:registerControls(InGameMenuGeneralSettingsFrame.CONTROLS)

	self.settingsModel = settingsModel
	self.checkboxMapping = {}
	self.optionMapping = {}

	return self
end

function InGameMenuGeneralSettingsFrame:copyAttributes(src)
	InGameMenuGeneralSettingsFrame:superClass().copyAttributes(self, src)

	self.settingsModel = src.settingsModel
end

function InGameMenuGeneralSettingsFrame:initialize()
	self.checkboxMapping[self.checkAutoHelp] = SettingsModel.SETTING.SHOW_HELP_MENU
	self.checkboxMapping[self.checkColorBlindMode] = SettingsModel.SETTING.USE_COLORBLIND_MODE
	self.checkboxMapping[self.checkUseMiles] = SettingsModel.SETTING.USE_MILES
	self.checkboxMapping[self.checkUseFahrenheit] = SettingsModel.SETTING.USE_FAHRENHEIT
	self.checkboxMapping[self.checkUseAcre] = SettingsModel.SETTING.USE_ACRE
	self.checkboxMapping[self.checkShowTriggerMarker] = SettingsModel.SETTING.SHOW_TRIGGER_MARKER
	self.checkboxMapping[self.checkShowHelpTrigger] = SettingsModel.SETTING.SHOW_HELP_TRIGGER
	self.checkboxMapping[self.checkShowFieldInfo] = SettingsModel.SETTING.SHOW_FIELD_INFO
	self.checkboxMapping[self.checkIsRadioVehicleOnly] = SettingsModel.SETTING.RADIO_VEHICLE_ONLY
	self.checkboxMapping[self.checkIsRadioActive] = SettingsModel.SETTING.RADIO_IS_ACTIVE
	self.checkboxMapping[self.checkResetCamera] = SettingsModel.SETTING.RESET_CAMERA
	self.checkboxMapping[self.checkActiveSuspensionCamera] = SettingsModel.SETTING.ACTIVE_SUSPENSION_CAMERA
	self.checkboxMapping[self.checkCameraCheckCollision] = SettingsModel.SETTING.CAMERA_CHECK_COLLISION
	self.checkboxMapping[self.checkUseWorldCamera] = SettingsModel.SETTING.USE_WORLD_CAMERA
	self.checkboxMapping[self.checkInvertYLook] = SettingsModel.SETTING.INVERT_Y_LOOK
	self.checkboxMapping[self.checkUseEasyArmControl] = SettingsModel.SETTING.EASY_ARM_CONTROL
	self.checkboxMapping[self.checkIsTrainTabbable] = SettingsModel.SETTING.IS_TRAIN_TABBABLE
	self.checkboxMapping[self.checkShowMultiplayerNames] = SettingsModel.SETTING.SHOW_MULTIPLAYER_NAMES
	self.checkboxMapping[self.checkWoodHarvesterAutoCut] = SettingsModel.SETTING.WOOD_HARVESTER_AUTO_CUT

	self.checkUseMiles:setTexts(self.settingsModel:getDistanceUnitTexts())
	self.checkUseFahrenheit:setTexts(self.settingsModel:getTemperatureUnitTexts())
	self.checkUseAcre:setTexts(self.settingsModel:getAreaUnitTexts())
	self.checkIsRadioVehicleOnly:setTexts(self.settingsModel:getRadioModeTexts())

	self.optionMapping[self.multiMoneyUnit] = SettingsModel.SETTING.MONEY_UNIT
	self.optionMapping[self.multiCameraSensitivity] = SettingsModel.SETTING.CAMERA_SENSITIVITY
	self.optionMapping[self.multiVehicleArmSensitivity] = SettingsModel.SETTING.VEHICLE_ARM_SENSITIVITY
	self.optionMapping[self.multiSteeringBackSpeed] = SettingsModel.SETTING.STEERING_BACK_SPEED
	self.optionMapping[self.multiSteeringSensitivity] = SettingsModel.SETTING.STEERING_SENSITIVITY
	self.optionMapping[self.multiMasterVolume] = SettingsModel.SETTING.VOLUME_MASTER
	self.optionMapping[self.multiVehicleVolume] = SettingsModel.SETTING.VOLUME_VEHICLE
	self.optionMapping[self.multiEnvironmentVolume] = SettingsModel.SETTING.VOLUME_ENVIRONMENT
	self.optionMapping[self.multiRadioVolume] = SettingsModel.SETTING.VOLUME_RADIO
	self.optionMapping[self.multiVolumeGUI] = SettingsModel.SETTING.VOLUME_GUI
	self.optionMapping[self.multiInputHelpMode] = SettingsModel.SETTING.INPUT_HELP_MODE
	self.optionMapping[self.multiDirectionChangeMode] = SettingsModel.SETTING.DIRECTION_CHANGE_MODE
	self.optionMapping[self.multiGearShiftMode] = SettingsModel.SETTING.GEAR_SHIFT_MODE
	self.optionMapping[self.multiHudSpeedGauge] = SettingsModel.SETTING.HUD_SPEED_GAUGE
	self.optionMapping[self.multiVolumeVoice] = SettingsModel.SETTING.VOLUME_VOICE
	self.optionMapping[self.multiVolumeVoiceInput] = SettingsModel.SETTING.VOLUME_VOICE_INPUT
	self.optionMapping[self.multiVoiceMode] = SettingsModel.SETTING.VOICE_MODE
	self.optionMapping[self.multiVoiceInputSensitivity] = SettingsModel.SETTING.VOICE_INPUT_SENSITIVITY
	self.optionMapping[self.multiRealBeaconLightBrightness] = SettingsModel.SETTING.REAL_BEACON_LIGHT_BRIGHTNESS

	self.multiMoneyUnit:setTexts(self.settingsModel:getMoneyUnitTexts())
	self.multiCameraSensitivity:setTexts(self.settingsModel:getCameraSensitivityTexts())
	self.multiVehicleArmSensitivity:setTexts(self.settingsModel:getVehicleArmSensitivityTexts())
	self.multiSteeringBackSpeed:setTexts(self.settingsModel:getSteeringBackSpeedTexts())
	self.multiSteeringSensitivity:setTexts(self.settingsModel:getSteeringSensitivityTexts())
	self.multiMasterVolume:setTexts(self.settingsModel:getAudioVolumeTexts())
	self.multiVehicleVolume:setTexts(self.settingsModel:getAudioVolumeTexts())
	self.multiEnvironmentVolume:setTexts(self.settingsModel:getAudioVolumeTexts())
	self.multiRadioVolume:setTexts(self.settingsModel:getAudioVolumeTexts())
	self.multiVolumeGUI:setTexts(self.settingsModel:getAudioVolumeTexts())
	self.multiVolumeVoice:setTexts(self.settingsModel:getAudioVolumeTexts())
	self.multiVolumeVoiceInput:setTexts(self.settingsModel:getRecordingVolumeTexts())
	self.multiVoiceMode:setTexts(self.settingsModel:getVoiceModeTexts())
	self.multiVoiceInputSensitivity:setTexts(self.settingsModel:getVoiceInputSensitivityTexts())
	self.multiInputHelpMode:setTexts(self.settingsModel:getInputHelpModeTexts())
	self.multiDirectionChangeMode:setTexts(self.settingsModel:getDirectionChangeModeTexts())
	self.multiGearShiftMode:setTexts(self.settingsModel:getGearShiftModeTexts())
	self.multiHudSpeedGauge:setTexts(self.settingsModel:getHudSpeedGaugeTexts())

	if GS_PLATFORM_PC then
		self.multiRealBeaconLightBrightness:setTexts(self.settingsModel:getRealBeaconLightBrightnessTexts())
	end

	if GS_IS_CONSOLE_VERSION then
		self.multiInputHelpMode:setVisible(false)
		self.multiSteeringBackSpeed:setVisible(false)
	end

	if GS_PLATFORM_TYPE == GS_PLATFORM_TYPE_GGP then
		self.multiInputHelpMode:setVisible(false)
	end
end

function InGameMenuGeneralSettingsFrame:onFrameOpen(element)
	InGameMenuGeneralSettingsFrame:superClass().onFrameOpen(self)
	self:updateGeneralSettings()

	local isMultiplayer = g_currentMission.missionDynamicInfo.isMultiplayer

	self.checkIsTrainTabbable:setVisible(not isMultiplayer)
	self.multiVolumeVoice:setVisible(isMultiplayer and not VoiceChatUtil.getIsVoiceRestricted())
	self.multiVoiceMode:setVisible(isMultiplayer)
	self.multiVolumeVoiceInput:setVisible(isMultiplayer and VoiceChatUtil.getHasRecordingDevice() and not VoiceChatUtil.getIsVoiceRestricted())
	self.checkShowMultiplayerNames:setVisible(isMultiplayer and not GS_IS_CONSOLE_VERSION)
	self.multiRealBeaconLightBrightness:setVisible(g_beaconLightManager:getNumOfLights() > 0)
	self.checkCameraCheckCollision:setVisible(g_modIsLoaded.FS22_disableVehicleCameraCollision)
	self.multiVoiceInputSensitivity:setVisible(isMultiplayer)
	self.boxLayout:invalidateLayout()

	if FocusManager:getFocusedElement() == nil then
		self:setSoundSuppressed(true)
		FocusManager:setFocus(self.boxLayout)
		self:setSoundSuppressed(false)
	end
end

function InGameMenuGeneralSettingsFrame:onFrameClose()
	InGameMenuGeneralSettingsFrame:superClass().onFrameClose(self)
	self.settingsModel:saveChanges(SettingsModel.SETTING_CLASS.SAVE_GAMEPLAY_SETTINGS)
end

function InGameMenuGeneralSettingsFrame:updateGeneralSettings()
	self.settingsModel:refresh()

	for element, settingsKey in pairs(self.checkboxMapping) do
		element:setIsChecked(self.settingsModel:getValue(settingsKey))
	end

	for element, settingsKey in pairs(self.optionMapping) do
		element:setState(self.settingsModel:getValue(settingsKey))
	end
end

function InGameMenuGeneralSettingsFrame:onClickCheckbox(state, checkboxElement)
	local settingsKey = self.checkboxMapping[checkboxElement]

	if settingsKey ~= nil then
		self.settingsModel:setValue(settingsKey, state == CheckedOptionElement.STATE_CHECKED)
		self.settingsModel:applyChanges(SettingsModel.SETTING_CLASS.SAVE_NONE)

		self.dirty = true
	else
		print("Warning: Invalid settings checkbox event or key configuration for element " .. checkboxElement:toString())
	end
end

function InGameMenuGeneralSettingsFrame:onClickMultiOption(state, optionElement)
	if optionElement == self.multiVoiceMode and VoiceChatUtil.getIsVoiceRestricted() then
		VoiceChatUtil.showVoiceRestrictedPopup()
		optionElement:setState(VoiceChatUtil.MODE.DISABLED)

		return
	end

	local settingsKey = self.optionMapping[optionElement]

	if settingsKey ~= nil then
		self.settingsModel:setValue(settingsKey, state)
		self.settingsModel:applyChanges(SettingsModel.SETTING_CLASS.SAVE_NONE)

		self.dirty = true
	else
		print("Warning: Invalid settings multi option event or key configuration for element " .. optionElement:toString())
	end

	if optionElement == self.multiRealBeaconLightBrightness then
		g_beaconLightManager:updateBeaconLights()
	end
end

function InGameMenuGeneralSettingsFrame:onClickNativeHelp()
	openNativeHelpMenu()
end
