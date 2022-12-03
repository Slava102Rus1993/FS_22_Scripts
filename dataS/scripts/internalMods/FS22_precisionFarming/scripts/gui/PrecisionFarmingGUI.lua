PrecisionFarmingGUI = {
	MOD_NAME = g_currentModName,
	MOD_DIR = g_currentModDirectory,
	GUI_ELEMENTS = g_currentModDirectory .. "gui/ui_elements.png",
	GUI_ELEMENTS_SIZE = {
		1024,
		1024
	},
	updateButtonOnInputHelpChange = function (element, profileGamepad, profile)
		if element ~= nil then
			local useGamepadButtons = g_inputBinding:getInputHelpMode() == GS_INPUT_HELP_MODE_GAMEPAD

			GuiOverlay.deleteOverlay(element.icon)

			element.hasLoadedInputGlyph = false
			element.inputActionName = nil
			element.keyDisplayText = nil

			element:applyProfile(useGamepadButtons and profileGamepad or profile)

			if element.inputActionName ~= nil then
				element:loadInputGlyph(true)
			end
		end
	end
}

function PrecisionFarmingGUI.initializeGui()
	g_gui:loadProfiles(PrecisionFarmingGUI.MOD_DIR .. "gui/guiProfiles.xml")

	for _, profile in pairs(g_gui.profiles) do
		for name, value in pairs(profile.values) do
			if (name == "imageFilename" or name == "iconFilename") and value == "g_pfUIElements" then
				profile.values[name] = PrecisionFarmingGUI.GUI_ELEMENTS
				profile.values.imageSize = PrecisionFarmingGUI.GUI_ELEMENTS_SIZE[1] .. " " .. PrecisionFarmingGUI.GUI_ELEMENTS_SIZE[2]
			end
		end
	end
end

if g_gui ~= nil then
	PrecisionFarmingGUI.initializeGui()
end
