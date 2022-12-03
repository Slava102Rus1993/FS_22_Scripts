InputHelpDisplayExtension = {
	MOD_NAME = g_currentModName,
	MOD_DIR = g_currentModDirectory
}
local InputHelpDisplayExtension_mt = Class(InputHelpDisplayExtension)

function InputHelpDisplayExtension.new(precisionFarming, customMt)
	local self = setmetatable({}, customMt or InputHelpDisplayExtension_mt)
	self.isEnabled = true
	self.isActive = false
	self.stateInitialized = false
	self.precisionFarming = precisionFarming
	self.headline = g_i18n:getText("ui_header"):upper()

	self.precisionFarming:addSetting("inputHelpDisplay", g_i18n:getText("settingTitle_inputHelpDisplay"), g_i18n:getText("settingDescription_inputHelpDisplay"), self.onInputHelpDisplaySettingChanged, self, self.isEnabled, true)

	local _ = nil
	self.inputHelpWidth, _ = getNormalizedScreenValues(InputHelpDisplay.SIZE.HEADER[1] * g_gameSettings:getValue("uiScale"), 0)
	self.highPrioActions = {
		"PRECISIONFARMING_SEED_RATE",
		"PRECISIONFARMING_SEED_RATE_MODE",
		"PRECISIONFARMING_SPRAY_AMOUNT",
		"PRECISIONFARMING_SPRAY_AMOUNT_MODE"
	}

	return self
end

function InputHelpDisplayExtension:onInputHelpDisplaySettingChanged(state)
	self.isEnabled = state
end

function InputHelpDisplayExtension:unloadMapData()
end

function InputHelpDisplayExtension:delete()
end

function InputHelpDisplayExtension:update(dt)
end

function InputHelpDisplayExtension:getInputHelpBasePosition()
	local alpha = 1
	local vehicleSchema = g_currentMission.hud.vehicleSchema

	if not vehicleSchema.animation:getFinished() then
		alpha = math.min(vehicleSchema.animation.elapsedTime / vehicleSchema.animation.totalDuration, 1)
	elseif not vehicleSchema.isDocked then
		alpha = 0
	end

	local xOffset = (1 - alpha) * self.inputHelpWidth
	local posX, posY = InputHelpDisplay.getBackgroundPosition()

	return posX - xOffset, posY
end

function InputHelpDisplayExtension:drawVehicleHUDExtensions(inputHelpDisplay)
	local extensionsHeight = inputHelpDisplay:getAvailableHeight()

	if extensionsHeight > 0 then
		local leftPosX, posY = self:getInputHelpBasePosition()
		local width = inputHelpDisplay:getWidth()
		posY = posY + inputHelpDisplay.frameOffsetY
		local usedHeight = 0

		for _, extension in pairs(inputHelpDisplay.vehicleHudExtensions) do
			if extension:isa(ExtendedSowingMachineHUDExtension) or extension:isa(ExtendedSprayerHUDExtension) then
				local extHeight = extension:getDisplayHeight()

				if extension:canDraw() and extensionsHeight >= usedHeight + extHeight then
					posY = posY - extHeight - inputHelpDisplay.entryOffsetY

					inputHelpDisplay.extensionBg:setPosition(leftPosX, posY)
					inputHelpDisplay.extensionBg:setDimension(width, extHeight)
					inputHelpDisplay.extensionBg:render()
					extension:draw(leftPosX + inputHelpDisplay.extraTextOffsetX, leftPosX + width + inputHelpDisplay.helpTextOffsetX, posY)

					usedHeight = usedHeight + extHeight
				end
			end
		end

		return usedHeight ~= 0
	end

	return false
end

function InputHelpDisplayExtension:drawControlsLabel(inputHelpDisplay)
	setTextBold(true)
	setTextColor(unpack(InputHelpDisplay.COLOR.CONTROLS_LABEL))
	setTextAlignment(RenderText.ALIGN_LEFT)

	local baseX, baseY = self:getInputHelpBasePosition()
	local frameX = baseX + inputHelpDisplay.frameOffsetX
	local frameTopY = baseY + inputHelpDisplay.frameOffsetY
	local posX = frameX + inputHelpDisplay.controlsLabelOffsetX
	local posY = frameTopY + inputHelpDisplay.controlsLabelOffsetY

	renderText(posX, posY, inputHelpDisplay.controlsLabelTextSize, self.headline)
end

function InputHelpDisplayExtension:overwriteGameFunctions(pfModule)
	pfModule:overwriteGameFunction(InputHelpDisplay, "draw", function (superFunc, inputHelpDisplay)
		superFunc(inputHelpDisplay)

		if not inputHelpDisplay:getVisible() then
			local vehicleSchema = g_currentMission.hud.vehicleSchema
			self.isActive = false

			if self.isEnabled then
				inputHelpDisplay:updateHUDExtensions()

				if self:drawVehicleHUDExtensions(inputHelpDisplay) then
					self:drawControlsLabel(inputHelpDisplay)

					self.isActive = true

					if not vehicleSchema.isDocked and vehicleSchema.animation:getFinished() then
						vehicleSchema:setDocked(true, true)
					end
				end
			end

			if not self.isActive and vehicleSchema.isDocked and vehicleSchema.animation:getFinished() then
				vehicleSchema:setDocked(false, true)
			end
		end
	end)
	pfModule:overwriteGameFunction(InputDisplayManager, "sortEventHelpElementsGamepad", function (superFunc, helpElem1, helpElem2)
		local prio1 = 0
		local prio2 = 0

		for i = 1, #self.highPrioActions do
			local actionName = self.highPrioActions[i]

			if helpElem1.actionName == actionName then
				prio1 = 1
			end

			if helpElem2.actionName == actionName then
				prio2 = 1
			end
		end

		if prio1 ~= 0 or prio2 ~= 0 then
			return prio2 < prio1
		end

		return superFunc(helpElem1, helpElem2)
	end)
end
