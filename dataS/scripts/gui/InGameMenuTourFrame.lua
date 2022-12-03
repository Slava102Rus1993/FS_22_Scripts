InGameMenuTourFrame = {}
local InGameMenuTourFrame_mt = Class(InGameMenuTourFrame, TabbedMenuFrameElement)
InGameMenuTourFrame.CONTROLS = {
	"headerText",
	"contentItem",
	"controlItem",
	"layout"
}

function InGameMenuTourFrame.new(subclass_mt)
	local self = InGameMenuTourFrame:superClass().new(nil, subclass_mt or InGameMenuTourFrame_mt)

	self:registerControls(InGameMenuTourFrame.CONTROLS)

	self.hasCustomMenuButtons = true

	return self
end

function InGameMenuTourFrame:delete()
	self.contentItem:delete()
	self.controlItem:delete()
	InGameMenuTourFrame:superClass().delete(self)
end

function InGameMenuTourFrame:initialize()
	self.contentItem:unlinkElement()
	self.controlItem:unlinkElement()

	self.abortButton = {
		profile = "buttonCancel",
		inputAction = InputAction.MENU_CANCEL,
		text = g_i18n:getText("button_abortTour"),
		callback = function ()
			self:onButtonCancel()
		end
	}
end

function InGameMenuTourFrame:onFrameOpen()
	InGameMenuTourFrame:superClass().onFrameOpen(self)
	self:updateContents()
	self.layout:registerActionEvents()
	self:updateMenuButtons()
end

function InGameMenuTourFrame:onFrameClose()
	self.layout:removeActionEvents()
	InGameMenuTourFrame:superClass().onFrameClose(self)
end

function InGameMenuTourFrame:updateMenuButtons()
	self.menuButtonInfo = {
		{
			inputAction = InputAction.MENU_BACK
		}
	}
	local tour = g_currentMission.guidedTour

	if tour ~= nil and tour:getIsRunning() and tour:getCanAbort() then
		table.insert(self.menuButtonInfo, self.abortButton)
	end

	self:setMenuButtonInfoDirty()
end

function InGameMenuTourFrame:onButtonCancel()
	local tour = g_currentMission.guidedTour

	if tour ~= nil and tour:getIsRunning() and tour:getCanAbort() then
		g_gui:showYesNoDialog({
			title = "",
			text = g_i18n:getText("tour_abort_question"),
			callback = self.onAbortTourAnswer,
			target = self
		})
	end
end

function InGameMenuTourFrame:onAbortTourAnswer(yes)
	if yes then
		local tour = g_currentMission.guidedTour

		if tour ~= nil and tour:getIsRunning() and tour:getCanAbort() then
			tour:abort()
			g_gui:changeScreen(nil)
		end
	end
end

function InGameMenuTourFrame:updateContents()
	self.headerText:setLocaKey("ui_tour")

	for i = #self.layout.elements, 1, -1 do
		self.layout.elements[i]:delete()
	end

	self.layout:invalidateLayout()

	local steps = g_currentMission.guidedTour:getPassedSteps()
	local _, offsetYBottomTop = getNormalizedScreenValues(0, 60)
	local _, offsetYTextInput = getNormalizedScreenValues(0, 30)

	for index, step in ipairs(steps) do
		local row = self.contentItem:clone(self.layout)
		local textElement = row:getDescendantByName("text")
		local controlsElement = row:getDescendantByName("controls")
		local profile = "tourMenuItem"

		if index == #steps then
			profile = "tourMenuItemCurrent"
		elseif index % 2 == 1 then
			profile = "tourMenuItemAlt"
		end

		row:applyProfile(profile)
		textElement:setText(g_i18n:convertText(step.text))

		local height = textElement:getTextHeight()

		textElement:setSize(nil, height)

		height = height + offsetYBottomTop
		local useGamepadButtons = g_inputBinding:getInputHelpMode() == GS_INPUT_HELP_MODE_GAMEPAD
		local numVisibleControls = 0

		for _, input in ipairs(step.inputs) do
			local action1 = InputAction[input.action]
			local action2 = input.action2 ~= nil and InputAction[input.action2] or nil

			if (not input.keyboardOnly or not useGamepadButtons) and (not input.gamepadOnly or useGamepadButtons) then
				local controlItem = self.controlItem:clone(controlsElement)
				numVisibleControls = numVisibleControls + 1

				if numVisibleControls == 1 then
					controlItem:applyProfile("tourMenuItemControlsItemFirst")
				end

				local glyph = controlItem:getDescendantByName("glyph")

				glyph:applyProfile("tourMenuItemControlsGlyph")
				glyph:setActions({
					action1,
					action2
				})

				local text = controlItem:getDescendantByName("text")

				text:setText(g_i18n:convertText(input.text))
			end
		end

		controlsElement:setVisible(numVisibleControls > 0)

		if numVisibleControls > 0 then
			controlsElement:setSize(nil, numVisibleControls * controlsElement.elements[1].absSize[2])
			controlsElement:invalidateLayout()

			height = height + controlsElement.absSize[2] + offsetYTextInput
		end

		row:setSize(nil, height)
	end

	self.layout:invalidateLayout()
	self.layout:scrollToEnd()
end
