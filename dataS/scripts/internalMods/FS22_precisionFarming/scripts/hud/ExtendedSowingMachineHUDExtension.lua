ExtendedSowingMachineHUDExtension = {
	MOD_NAME = g_currentModName,
	MOD_DIR = g_currentModDirectory
}
ExtendedSowingMachineHUDExtension.GUI_ELEMENTS = ExtendedSowingMachineHUDExtension.MOD_DIR .. "gui/ui_elements.png"
local ExtendedSowingMachineHUDExtension_mt = Class(ExtendedSowingMachineHUDExtension, VehicleHUDExtension)

function ExtendedSowingMachineHUDExtension.new(vehicle, uiScale, uiTextColor, uiTextSize)
	local self = VehicleHUDExtension.new(ExtendedSowingMachineHUDExtension_mt, vehicle, uiScale, uiTextColor, uiTextSize)
	self.extendedSowingMachine = vehicle.spec_extendedSowingMachine
	local _ = nil
	_, self.displayHeight = getNormalizedScreenValues(0, 41 * uiScale)
	self.uiTextColor = uiTextColor
	_, self.textHeightHeadline = getNormalizedScreenValues(0, 20 * uiScale)
	_, self.textOffsetHeadline = getNormalizedScreenValues(0, 3 * uiScale)
	self.textMaxWidthHeadline, _ = getNormalizedScreenValues(190 * uiScale, 0)
	self.rateTextOffsetX, self.rateTextHeight = getNormalizedScreenValues(330 * uiScale, 15 * uiScale)
	_, self.rateTextOffsetY = getNormalizedScreenValues(0 * uiScale, 10 * uiScale)
	self.modeTextOffsetX, self.modeTextHeight = getNormalizedScreenValues(230 * uiScale, 15 * uiScale)
	_, self.modeTextOffset = getNormalizedScreenValues(0, 2 * uiScale)
	self.naTextOffsetX, self.naTextHeight = getNormalizedScreenValues(290 * uiScale, 12 * uiScale)
	_, self.naTextOffset = getNormalizedScreenValues(0, 1 * uiScale)
	self.dotEmptyUVs = GuiUtils.getUVs(ExtendedSowingMachineHUDExtension.UV.DOT_EMPTY)
	self.dotFilledUVs = GuiUtils.getUVs(ExtendedSowingMachineHUDExtension.UV.DOT_FILLED)
	self.dotFillUVs = GuiUtils.getUVs(ExtendedSowingMachineHUDExtension.UV.DOT_FILL)
	self.dots = {}
	local dotWidth, dotHeight = getNormalizedScreenValues(12 * uiScale, 12 * uiScale)

	for i = 1, 3 do
		local dotOverlay = Overlay.new(ExtendedSowingMachineHUDExtension.GUI_ELEMENTS, 0, 0, dotWidth, dotHeight)

		dotOverlay:setUVs(self.dotEmptyUVs)
		dotOverlay:setColor(1, 1, 1, 1)
		table.insert(self.dots, dotOverlay)
		self:addComponentForCleanup(dotOverlay)
	end

	self.dotsFullWidth, _ = getNormalizedScreenValues(35 * uiScale, 0 * uiScale)
	self.seedsOverlayUVs = {
		GuiUtils.getUVs(ExtendedSowingMachineHUDExtension.UV.SEEDS[1]),
		GuiUtils.getUVs(ExtendedSowingMachineHUDExtension.UV.SEEDS[2]),
		GuiUtils.getUVs(ExtendedSowingMachineHUDExtension.UV.SEEDS[3])
	}
	local width, height = getNormalizedScreenValues(30 * uiScale, 30 * uiScale)
	self.seedsOverlay = Overlay.new(ExtendedSowingMachineHUDExtension.GUI_ELEMENTS, 0, 0, width, height)

	self.seedsOverlay:setUVs(self.seedsOverlayUVs[1])
	self.seedsOverlay:setColor(1, 1, 1, 1)
	self:addComponentForCleanup(self.seedsOverlay)

	self.seedOverlayOffsetX, _ = getNormalizedScreenValues(0 * uiScale, 0)
	width, height = getNormalizedScreenValues(9 * uiScale, 4 * uiScale)
	self.recommendOverlay = Overlay.new(ExtendedSowingMachineHUDExtension.GUI_ELEMENTS, 0, 0, width, height)

	self.recommendOverlay:setUVs(GuiUtils.getUVs(ExtendedSowingMachineHUDExtension.UV.BAR))
	self.recommendOverlay:setColor(0.25, 0.25, 0.25, 1)
	self:addComponentForCleanup(self.recommendOverlay)

	_, self.recommendOverlayOffsetY = getNormalizedScreenValues(0, 0 * uiScale)
	self.texts = {
		headline = g_i18n:getText("hudExtensionSowingMachine_headline", ExtendedSowingMachineHUDExtension.MOD_NAME),
		seedRate = g_i18n:getText("hudExtensionSowingMachine_seedRate", ExtendedSowingMachineHUDExtension.MOD_NAME),
		auto = g_i18n:getText("hudExtensionSowingMachine_auto", ExtendedSowingMachineHUDExtension.MOD_NAME),
		notAvailable = g_i18n:getText("hudExtensionSowingMachine_notAvailable", ExtendedSowingMachineHUDExtension.MOD_NAME)
	}
	self.seedRateMap = g_precisionFarming.seedRateMap
	self.isColorBlindMode = g_gameSettings:getValue(GameSettings.SETTING.USE_COLORBLIND_MODE) or false

	g_messageCenter:subscribe(MessageType.SETTING_CHANGED[GameSettings.SETTING.USE_COLORBLIND_MODE], self.setColorBlindMode, self)

	return self
end

function ExtendedSowingMachineHUDExtension:delete()
	ExtendedSowingMachineHUDExtension:superClass().delete(self)
	g_messageCenter:unsubscribeAll(self)
end

function ExtendedSowingMachineHUDExtension:setColorBlindMode(isActive)
	if isActive ~= self.isColorBlindMode then
		self.isColorBlindMode = isActive
	end
end

function ExtendedSowingMachineHUDExtension:getPriority()
	return 1
end

function ExtendedSowingMachineHUDExtension:canDraw()
	if not self.vehicle:getIsActiveForInput(true, true) then
		return false
	end

	return true
end

function ExtendedSowingMachineHUDExtension:getDisplayHeight()
	return self:canDraw() and self.displayHeight or 0
end

function ExtendedSowingMachineHUDExtension:getHelpEntryCountReduction()
	return self:canDraw() and 1 or 0
end

local function formatDecimalNumber(n)
	if math.floor(n) == n then
		return string.format("%.1f", n)
	else
		return string.format("%s", n)
	end
end

local function renderDoubleText(x, y, textSize, text, maxWidth)
	if maxWidth ~= nil then
		while maxWidth < getTextWidth(textSize, text) do
			textSize = textSize * 0.98
		end
	end

	setTextColor(0, 0, 0, 1)
	renderText(x, y - 0.0015, textSize, text)
	setTextColor(1, 1, 1, 1)
	renderText(x, y, textSize, text)
end

function ExtendedSowingMachineHUDExtension:draw(leftPosX, rightPosX, posY)
	if not self:canDraw() then
		return
	end

	setTextColor(unpack(self.uiTextColor))
	setTextBold(true)
	setTextAlignment(RenderText.ALIGN_LEFT)
	setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
	renderDoubleText(leftPosX, posY + self.displayHeight * 0.55, self.textHeightHeadline, self.texts.headline, self.textMaxWidthHeadline)
	setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
	setTextBold(false)

	local spec = self.extendedSowingMachine
	local seedsFruitType = self.vehicle.spec_sowingMachine.workAreaParameters.seedsFruitType
	local lastSeedRate = spec.lastSeedRate
	local lastSeedRateIndex = spec.lastSeedRateIndex

	if not spec.seedRateAutoMode then
		lastSeedRateIndex = spec.manualSeedRate
		lastSeedRate = self.seedRateMap:getSeedRateByFruitTypeAndIndex(seedsFruitType, lastSeedRateIndex)
	end

	local isSupported = self.seedRateMap:getIsFruitTypeSupported(seedsFruitType)

	if isSupported then
		setTextAlignment(RenderText.ALIGN_CENTER)

		local currentRatePosX = leftPosX + self.rateTextOffsetX
		local currentRatePosY = posY + self.displayHeight * 0.5 - self.rateTextHeight * 0.5 + self.rateTextOffsetY

		renderDoubleText(currentRatePosX, currentRatePosY, self.rateTextHeight, string.format(self.texts.seedRate, lastSeedRate))

		for i = 1, #self.dots do
			local dotOverlay = self.dots[i]
			local dotPosX = currentRatePosX + (i / 2 - 1) * self.dotsFullWidth - dotOverlay.width * 0.5
			local dotPosY = currentRatePosY - dotOverlay.height * 1.5

			dotOverlay:setPosition(dotPosX, dotPosY)

			if lastSeedRateIndex < i then
				dotOverlay:setUVs(self.dotEmptyUVs)
				dotOverlay:setColor(1, 1, 1, 0.4)
				dotOverlay:render()
			else
				dotOverlay:setUVs(self.dotFilledUVs)
				dotOverlay:setColor(1, 1, 1, 0.4)
				dotOverlay:render()

				local displayValues = self.seedRateMap:getDisplayValues()
				local displayValue = displayValues[lastSeedRateIndex]
				local color = displayValue.colors[self.isColorBlindMode][1]

				dotOverlay:setUVs(self.dotFillUVs)
				dotOverlay:setColor(color[1], color[2], color[3], 1)
				dotOverlay:render()
			end

			if not spec.seedRateAutoMode and spec.seedRateRecommendation ~= nil and i <= spec.seedRateRecommendation then
				self.recommendOverlay:setPosition(dotPosX + dotOverlay.width * 0.5 - self.recommendOverlay.width * 0.5, dotPosY - self.recommendOverlay.height + self.recommendOverlayOffsetY)
				self.recommendOverlay:render()
			end
		end

		if spec.seedRateAutoMode then
			setTextAlignment(RenderText.ALIGN_CENTER)
			setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
			renderDoubleText(leftPosX + self.modeTextOffsetX, posY + self.displayHeight * 0.52, self.modeTextHeight, self.texts.auto)
		end
	else
		local fillType = g_fillTypeManager:getFillTypeByIndex(g_fruitTypeManager:getFillTypeIndexByFruitTypeIndex(seedsFruitType))

		if fillType ~= nil then
			setTextAlignment(RenderText.ALIGN_CENTER)
			setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
			renderDoubleText(leftPosX + self.naTextOffsetX, posY + self.displayHeight * 0.52, self.naTextHeight, string.format(self.texts.notAvailable, fillType.title))
		end
	end

	local uvIndex = lastSeedRateIndex

	if uvIndex == 0 or not isSupported then
		uvIndex = 2
	end

	self.seedsOverlay:setUVs(self.seedsOverlayUVs[math.max(math.min(uvIndex, 3), 1)])
	self.seedsOverlay:setPosition(rightPosX - self.seedsOverlay.width, posY + self.displayHeight * 0.5 - self.seedsOverlay.height * 0.5)
	self.seedsOverlay:render()
	setTextAlignment(RenderText.ALIGN_LEFT)
	setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)

	return posY
end

ExtendedSowingMachineHUDExtension.COLOR = {}
ExtendedSowingMachineHUDExtension.UV = {
	SEEDS = {
		{
			454,
			5,
			52,
			53
		},
		{
			582,
			5,
			52,
			53
		},
		{
			646,
			5,
			52,
			53
		}
	},
	DOT_EMPTY = {
		517,
		5,
		19,
		19
	},
	DOT_FILLED = {
		517,
		28,
		19,
		19
	},
	DOT_FILL = {
		538,
		5,
		19,
		19
	},
	BAR = {
		541,
		27,
		13,
		5
	}
}
